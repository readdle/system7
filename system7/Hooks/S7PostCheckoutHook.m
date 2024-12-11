//
//  S7PostCheckoutHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostCheckoutHook.h"

#import "S7Diff.h"
#import "S7Utils.h"
#import "S7InitCommand.h"
#import "S7DeinitCommand.h"
#import "S7BootstrapCommand.h"
#import "S7SubrepoDescriptionConflict.h"
#import "S7Options.h"
#import "S7Logging.h"

static void (^_warnAboutDetachingCommitsHook)(NSString *topRevision, int numberOfCommits) = nil;

@implementation S7PostCheckoutHook

+ (NSString *)gitHookName {
    return @"post-checkout";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    logInfo("\ns7: post-checkout hook start\n");
    const int result = [self doRunWithArguments:arguments];
    logInfo("s7: post-checkout hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count < 3) {
        return S7ExitCodeMissingRequiredArgument;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        logError("s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    NSString *fromRevision = arguments[0];
    NSString *toRevision = arguments[1];
    BOOL branchSwitchFlag = [arguments[2] isEqualToString:@"1"];

    if (NO == branchSwitchFlag) {
        S7Config *lastSavedS7Config = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];

        // we don't know what file did user actually checkout (thank you, Linus)
        // if that's an unrelated file, then we don't care,
        // but if that's our .s7substate config, then we do care.
        // The only way to find out if config content has been changed,
        // is to compare actual config to S7ControlFileName
        //
        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        if ([actualConfig isEqual:lastSavedS7Config]) {
            return S7ExitCodeSuccess;
        }
    }

    if (NO == [repo isRevisionAvailableLocally:fromRevision] && NO == [fromRevision isEqualToString:[GitRepository nullRevision]]) {
        logError("FROM_REV %s is not available in this repository\n",
                [fromRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (NO == [repo isRevisionAvailableLocally:toRevision]) {
        logError("TO_REV %s is not available in this repository\n",
                [toRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (branchSwitchFlag && [fromRevision isEqualToString:toRevision]) {
        // Don't do anything to subrepos in case of branch switch that doesn't change the revision.
        // This is possible in two situations:
        //  1. you create an new branch with `git switch -c <branch-name>` or `git checkout -b <branch-name>`
        //  2. you switch between two branches that point to the same revision
        //
        // I've stumbled on the first scenario way too many times:
        //  - I've made some changes in subrepo. Made a branch in subrepo. Comitted it. Maybe even pushed
        //  - returned to the main repo. Made accompanying changes. And only then remembered that I hadn't
        //    created a new branch in the main repo. Created a new branch with `git checkout -b <branch-name>` and –
        //    shoot! – post-checkout hook reset subrepo to the state saved in .s7substate (I haven't rebound yet).
        //
        // I don't think (and keep fingers crossed) that the second scenario (switch between two branches
        // that point to the same revision) is that common. Hope I won't break someone's scenario and expectations
        // by changing introducing this behaviour. The other argument I have is – you are not running `git reset` –
        // you are switching branches, so you won't be surprised by Git keeping changes to other files (if possible),
        // so why would you be surprised that s7 would leave subrepos intact?
        //
        // There's no way to distinct a new branch from an existing branch switch scenarios in post-checkout hook:
        // in both cases the branch already exists by the time the hook is called. There's not environment variable
        // or argument that could help either.
        //
        return S7ExitCodeSuccess;
    }

    return [self.class checkoutSubreposForRepo:repo fromRevision:fromRevision toRevision:toRevision];
}

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                  fromRevision:(NSString *)fromRevision
                    toRevision:(NSString *)toRevision
{
    S7Config *fromConfig = nil;
    int showExitStatus = getConfig(repo, fromRevision, &fromConfig);
    if (0 != showExitStatus) {
        return showExitStatus;
    }

    S7Config *toConfig = nil;
    showExitStatus = getConfig(repo, toRevision, &toConfig);
    if (0 != showExitStatus) {
        return showExitStatus;
    }

    const int checkoutExitStatus = [self checkoutSubreposForRepo:repo fromConfig:fromConfig toConfig:toConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    NSString *configFileAbsolutePath = [repo.absolutePath stringByAppendingPathComponent:S7ConfigFileName];
    NSString *controlFileAbsolutePath = [repo.absolutePath stringByAppendingPathComponent:S7ControlFileName];

    if ([NSFileManager.defaultManager fileExistsAtPath:configFileAbsolutePath]) {
        if (0 != [toConfig saveToFileAtPath:controlFileAbsolutePath]) {
            logError("failed to save %s to disk.\n",
                     S7ControlFileName.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }
    }
    else {
        // switch to a pre-s7 state. Let's call deinit.
        // It will remove all untracked s7 system files, s7 hooks, merge driver, etc.
        //
        S7DeinitCommand *command = [S7DeinitCommand new];
        return [command runWithArguments:@[]];
    }

    return S7ExitCodeSuccess;
}

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                    fromConfig:(S7Config *)fromConfig
                      toConfig:(S7Config *)toConfig
{
    return [self checkoutSubreposForRepo:repo
                              fromConfig:fromConfig
                                toConfig:toConfig
                                   clean:NO];
}

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                    fromConfig:(S7Config *)fromConfig
                      toConfig:(S7Config *)toConfig
                         clean:(BOOL)clean
{
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = nil;
    NSDictionary<NSString *, S7SubrepoDescription *> *dummy = nil;
    diffConfigs(fromConfig,
                toConfig,
                &subreposToDelete,
                &dummy,
                &dummy);

    __block int exitCode = [self tryMovingSameOriginSubrepos:subreposToDelete.allValues
                                         ifPresentInSubrepos:toConfig.subrepoDescriptions
                                      parentRepoAbsolutePath:repo.absolutePath];

    const int deleteExitCode = [self
                                deleteSubrepos:subreposToDelete.allValues
                                parentRepoAbsolutePath:repo.absolutePath];
    if (S7ExitCodeSuccess != deleteExitCode) {
        exitCode = deleteExitCode;
    }

    NSMutableArray<S7SubrepoDescription *> *subreposToCheckout = [toConfig.subrepoDescriptions mutableCopy];
    NSMutableDictionary<S7SubrepoDescription *, GitRepository *> *subrepoDescToGit = nil;

    {
        NSIndexSet *corruptedSubrepoRepositoryIndices = nil;
        const int getGitReposExitCode = [self
                                         getGitRepositoriesForSubrepoDescriptions:subreposToCheckout
                                         subrepoDescToGit:&subrepoDescToGit
                                         corruptedSubrepoRepositoryIndices:&corruptedSubrepoRepositoryIndices
                                         parentRepoAbsolutePath:repo.absolutePath];
        if (S7ExitCodeSuccess != getGitReposExitCode) {
            exitCode = getGitReposExitCode;
        }

        if (corruptedSubrepoRepositoryIndices.count > 0) {
            NSAssert(S7ExitCodeSuccess != exitCode, @"");
            [subreposToCheckout removeObjectsAtIndexes:corruptedSubrepoRepositoryIndices];
        }
    }

    NSArray<S7SubrepoDescription *> *subreposWithNotCommittedLocalChanges = nil;
    NSArray<S7SubrepoDescription *> *subreposWithConflict = nil;

    {
        // checking for uncommitted changes is an expensive operation
        // as we must run real git command. We are running this check
        // on every subrepo, thus we have a heavy operation multiplied by
        // the amount of subrepos.
        // To optimize this, we run this check not sequentially,
        // but in parallel on all subrepos.
        // This speeds up checkout of 44 subrepos from ~3.5s to ~0.2s
        //
        // We run this check on all subrepos, as we chose to make sure that subrepos
        // are exactly in the state that is saved in .s7substate.
        // The only exception is a failure to update subrepo, or this very situation –
        // subrepo contains uncommitted changes, and we don't want to loose them.
        //
        //
        // There are alternative approaches.
        //
        // For example,– check only subrepos that we really
        // switch to a different state. That's the question of general
        // philosophy. I think that getting main repo with non-fitting subrepo
        // is not great. There're valid cases, when I would want to use this approach,
        // but for now I stick to the strictest one. Example of such case is the
        // checkout of a new branch or a "close relative" branch. Close relative is
        // impossible to deduce from code. New branch might be possible, and I want
        // to investigate it some day.
        //
        // Another approach is to checkout subrepos despite uncommitted changes, and rely on
        // the will of Git in a subrepo – it may keep changes, may generate conflict.
        // If subrepo is an s7 repo itself and it has uncommitted changes to its
        // .s7substate, then this would also affect subrepo's subrepos. I think,
        // this approach is not well predictable and less safe.
        //

        NSIndexSet *subreposWithUncommittedChangesIndices = nil;
        NSIndexSet *indicesOfSubreposWithConflict = nil;
        const int checkUncommittedChangesExitCode = [self
                                                     ensureSubreposHaveNoUncommitedChanges:subreposToCheckout
                                                     subrepoDescToGit:subrepoDescToGit
                                                     clean:clean
                                                     indicesOfSubreposWithUncommittedChanges:&subreposWithUncommittedChangesIndices
                                                     indicesOfSubreposWithConflict:&indicesOfSubreposWithConflict];
        if (S7ExitCodeSuccess != checkUncommittedChangesExitCode) {
            exitCode = checkUncommittedChangesExitCode;
        }

        if (subreposWithUncommittedChangesIndices.count > 0 || indicesOfSubreposWithConflict.count > 0) {
            NSMutableIndexSet *subrepoIndicesToRemove = [NSMutableIndexSet new];

            if (subreposWithUncommittedChangesIndices.count > 0) {
                subreposWithNotCommittedLocalChanges = [subreposToCheckout objectsAtIndexes:subreposWithUncommittedChangesIndices];
                [subrepoIndicesToRemove addIndexes:subreposWithUncommittedChangesIndices];
            }

            if (indicesOfSubreposWithConflict.count > 0) {
                subreposWithConflict = [subreposToCheckout objectsAtIndexes:indicesOfSubreposWithConflict];
                [subrepoIndicesToRemove addIndexes:indicesOfSubreposWithConflict];
            }

            [subreposToCheckout removeObjectsAtIndexes:subrepoIndicesToRemove];
        }
    }

    __auto_type recordFailingExitCode = ^(int operationExitCode) {
        NSCAssert(S7ExitCodeSuccess != operationExitCode, @"please, send only failures here!");
        if (S7ExitCodeSuccess != operationExitCode) {
            @synchronized (self) {
                exitCode = operationExitCode;
            }
        }
    };

    NSMutableArray<GitRepository *> *subreposToInit = [NSMutableArray new];

    dispatch_apply(subreposToCheckout.count, DISPATCH_APPLY_AUTO, ^(size_t i) {

        S7SubrepoDescription *subrepoDesc = subreposToCheckout[i];
        NSString *subrepoAbsolutePath = [repo.absolutePath stringByAppendingPathComponent:subrepoDesc.path];

        GitRepository *subrepoGit = subrepoDescToGit[subrepoDesc];

        logInfo("\033[34m>\033[0m \033[1mchecking out subrepo '%s'\033[0m\n",
                [subrepoDesc.path fileSystemRepresentation]);

        if (subrepoGit) {
            BOOL subrepoUrlChanged = NO;
            NSString *oldUrl = nil;
            const int checkExitCode = [self checkSubrepoUrlChanged:subrepoDesc
                                                        subrepoGit:subrepoGit
                                                        urlChanged:&subrepoUrlChanged
                                                            oldUrl:&oldUrl];
            if (S7ExitCodeSuccess != checkExitCode) {
                recordFailingExitCode(checkExitCode);

                return;
            }

            if (subrepoUrlChanged) {
                // for example, we have moved from an official github.com/airbnb/lottie
                // to our fork at github.com/readdle/lottie
                // We still clone it to Dependencies/Thirdparty/lottie,
                // but the remote is absolutely different.
                //
                logInfo("  detected that subrepo '%s' has migrated:\n"
                        "   from '%s'\n"
                        "   to '%s'\n"
                        "   removing an old version...\n",
                        [subrepoDesc.path fileSystemRepresentation],
                        [oldUrl cStringUsingEncoding:NSUTF8StringEncoding],
                        [subrepoDesc.url cStringUsingEncoding:NSUTF8StringEncoding]);

                NSError *error = nil;
                if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoAbsolutePath
                                                                   error:&error])
                {
                    logError("failed to remove old version of '%s' from disk. Error: %s\n",
                             subrepoDesc.path.fileSystemRepresentation,
                             [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

                    recordFailingExitCode(S7ExitCodeFileOperationFailed);

                    return;
                }

                subrepoGit = nil;
                subrepoDescToGit[subrepoDesc] = nil;
            }
        }

        if (nil == subrepoGit) {
            const int cloneExitCode = [self cloneSubrepo:subrepoDesc
                                  parentRepoAbsolutePath:repo.absolutePath
                                              subrepoGit:&subrepoGit];
            if (S7ExitCodeSuccess != cloneExitCode) {
                recordFailingExitCode(cloneExitCode);

                return;
            }

            NSAssert(subrepoGit, @"");

            subrepoDescToGit[subrepoDesc] = subrepoGit;

            if ([NSFileManager.defaultManager fileExistsAtPath:[subrepoAbsolutePath stringByAppendingPathComponent:S7ConfigFileName]]) {
                @synchronized (self) {
                    [subreposToInit addObject:subrepoGit];
                }
            }
        }

        BOOL shouldInitSubrepo = NO;
        const S7ExitCode checkoutExitCode = [self ensureSubrepoInTheRightState:subrepoDesc
                                                                    subrepoGit:subrepoGit
                                                                         clean:clean
                                                             shouldInitSubrepo:&shouldInitSubrepo];
        if (S7ExitCodeSuccess != checkoutExitCode) {
            recordFailingExitCode(checkoutExitCode);

            return;
        }

        if (shouldInitSubrepo) {
            @synchronized (self) {
                [subreposToInit addObject:subrepoGit];
            }
        }
    });

    const S7ExitCode initExitCode = [self initS7InSubrepos:subreposToInit];
    if (S7ExitCodeSuccess != initExitCode) {
        exitCode = initExitCode;
    }

    if (subreposWithNotCommittedLocalChanges.count > 0) {
        logError("\n"
                 "  Subrepos with uncommitted local changes were not updated\n"
                 "  to prevent possible data loss:\n\n");

        for (S7SubrepoDescription *subrepoDesc in subreposWithNotCommittedLocalChanges) {
            logError("    %s\n", [subrepoDesc.path fileSystemRepresentation]);
        }

        logError(
                "\n"
                ""
                "  Please check if that is something you still need.\n"
                "\n"
                "  If changes are not necessary, then you can either:\n"
                "\n"
                "   - Discard changes yourself.\n"
                "   - Use `s7 reset <repo(s)>`. It will nuke changes for you.\n"
                "     Please, read `s7 help reset` before using the `reset` command.\n"
                "\n");
    }

    if (subreposWithConflict.count > 0) {
        logError("\n"
                 "  Subrepos with merge conflict that must be resolved manually:\n");

        for (S7SubrepoDescription *subrepoDesc in subreposWithConflict) {
            logError("    %s\n", [subrepoDesc.path fileSystemRepresentation]);
        }
    }

    return exitCode;
}

+ (int)tryMovingSameOriginSubrepos:(NSArray<S7SubrepoDescription *> *)subrepos
               ifPresentInSubrepos:(NSArray<S7SubrepoDescription *> *)subreposToCheckout
            parentRepoAbsolutePath:(NSString *)parentRepoAbsolutePath
{
    if (subrepos.count == 0) {
        return S7ExitCodeSuccess;
    }
    
    NSMutableDictionary *const subrepoToURLMap = [NSMutableDictionary dictionaryWithCapacity:subreposToCheckout.count];
    for (S7SubrepoDescription *subrepo in subreposToCheckout) {
        subrepoToURLMap[subrepo.url] = subrepo;
    }
    
    S7ExitCode exitCode = S7ExitCodeSuccess;
    for (S7SubrepoDescription *subrepo in subrepos) {
        S7SubrepoDescription *const sameSubrepo = subrepoToURLMap[subrepo.url];
        if (sameSubrepo == nil) {
            continue;
        }
        
        NSError *error;
        [[NSFileManager defaultManager] moveItemAtPath:[parentRepoAbsolutePath stringByAppendingPathComponent:subrepo.path]
                                                toPath:[parentRepoAbsolutePath stringByAppendingPathComponent:sameSubrepo.path]
                                                 error:&error];
        if (error) {
            logError(" abort: failed to move subrepo '%s' to '%s'\n"
                     " error: %s\n",
                     [subrepo.path fileSystemRepresentation],
                     [sameSubrepo.path fileSystemRepresentation],
                     [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
            exitCode = S7ExitCodeFileOperationFailed;
        }
        else {
            logInfo("\033[34m>\033[0m \033[1msubrepo '%s' renamed to '%s'\033[0m\n",
                    [subrepo.path fileSystemRepresentation],
                    [sameSubrepo.path fileSystemRepresentation]);
        }
    }
    
    return exitCode;
}

+ (int)deleteSubrepos:(NSArray<S7SubrepoDescription *> *)subreposToDelete
    parentRepoAbsolutePath:(NSString *)parentRepoAbsolutePath
{
    int exitCode = S7ExitCodeSuccess;
    for (S7SubrepoDescription *subrepoToDelete in subreposToDelete) {
        NSString *subrepoRelativePath = subrepoToDelete.path;
        NSString *subrepoAbsolutePath = [parentRepoAbsolutePath stringByAppendingPathComponent:subrepoRelativePath];

        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoAbsolutePath isDirectory:&isDirectory] && isDirectory) {
            GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoAbsolutePath];
            if (subrepoGit) {
                const BOOL hasUnpushedCommits = [subrepoGit hasUnpushedCommits];
                const BOOL hasUncommitedChanges = [subrepoGit hasUncommitedChanges];
                if (hasUncommitedChanges || hasUnpushedCommits) {
                    const char *reason = NULL;
                    if (hasUncommitedChanges && hasUnpushedCommits) {
                        reason = "uncommitted and not pushed changes";
                    }
                    else if (hasUncommitedChanges) {
                        reason = "uncommitted changes";
                    }
                    else {
                        reason = "not pushed changes";
                    }

                    NSAssert(reason, @"");

                    logError("  not removing repo '%s' because it has %s.\n",
                             subrepoRelativePath.fileSystemRepresentation,
                             reason);
                    continue;
                }
            }

            logInfo("\033[31m>\033[0m \033[1mremoving subrepo '%s'\033[0m\n", subrepoRelativePath.fileSystemRepresentation);

            NSError *error = nil;
            if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoAbsolutePath error:&error]) {
                logError(" abort: failed to remove subrepo '%s' directory\n"
                         " error: %s\n",
                         [subrepoRelativePath fileSystemRepresentation],
                         [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                exitCode = S7ExitCodeFileOperationFailed;
            }
        }
    }

    return exitCode;
}

+ (int)getGitRepositoriesForSubrepoDescriptions:(NSArray<S7SubrepoDescription *> *)subrepoDescriptions
                               subrepoDescToGit:(NSMutableDictionary<S7SubrepoDescription *, GitRepository *> **)ppSubrepoDescToGit
              corruptedSubrepoRepositoryIndices:(NSIndexSet **)ppCorruptedSubrepoRepositoryIndices
                         parentRepoAbsolutePath:(NSString *)parentRepoAbsolutePath
{
    int exitCode = S7ExitCodeSuccess;

    NSMutableIndexSet *corruptedSubrepoRepositoryIndices = [NSMutableIndexSet new];
    NSMutableDictionary<S7SubrepoDescription *, GitRepository *> *subrepoDescToGit =
        [NSMutableDictionary dictionaryWithCapacity:subrepoDescriptions.count];

    for (NSUInteger i = 0; i < subrepoDescriptions.count; ++i) {
        S7SubrepoDescription *subrepoDesc = subrepoDescriptions[i];

        BOOL isDirectory = NO;
        NSString *subrepoAbsolutePath = [parentRepoAbsolutePath stringByAppendingPathComponent:subrepoDesc.path];
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoAbsolutePath isDirectory:&isDirectory] && isDirectory) {
            GitRepository *subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoAbsolutePath];
            if (nil == subrepoGit) {
                [corruptedSubrepoRepositoryIndices addIndex:i];
                exitCode = S7ExitCodeSubrepoIsNotGitRepository;
                continue;
            }

            subrepoGit.redirectOutputToMemory = YES;
            subrepoDescToGit[subrepoDesc] = subrepoGit;
        }
    }

    *ppSubrepoDescToGit = subrepoDescToGit;
    *ppCorruptedSubrepoRepositoryIndices = corruptedSubrepoRepositoryIndices;
    return exitCode;
}

+ (int)ensureSubreposHaveNoUncommitedChanges:(NSArray<S7SubrepoDescription *> *)subrepoDescriptions
                            subrepoDescToGit:(NSDictionary<S7SubrepoDescription *, GitRepository *> *)subrepoDescToGit
                                       clean:(BOOL)clean
     indicesOfSubreposWithUncommittedChanges:(NSIndexSet **)ppIndicesOfSubreposWithUncommittedChanges
               indicesOfSubreposWithConflict:(NSIndexSet **)ppIndicesOfSubreposWithConflict
{
    NSMutableIndexSet *indicesOfSubreposWithUncommittedChanges = [NSMutableIndexSet new];
    NSMutableIndexSet *indicesOfSubreposWithConflict = [NSMutableIndexSet new];

    dispatch_apply(subrepoDescriptions.count, DISPATCH_APPLY_AUTO, ^(size_t i) {
        S7SubrepoDescription *subrepoDesc = subrepoDescriptions[i];
        GitRepository *subrepoGit = subrepoDescToGit[subrepoDesc];

        NSCAssert(subrepoDesc, @"");

        if (NO == clean && [subrepoDesc isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
            logError("merge conflict in subrepo %s\n",
                    subrepoDesc.path.fileSystemRepresentation);

            @synchronized (self) {
                [indicesOfSubreposWithConflict addIndex:i];
            }

            return;
        }

        if (nil == subrepoGit) {
            // this subrepo is not cloned yet, so nothing to check
            return;
        }


        if (NO == [subrepoGit hasUncommitedChanges]) {
            return;
        }

        if (NO == clean) {
            logError("  uncommitted local changes in subrepo '%s'\n",
                     subrepoDesc.path.fileSystemRepresentation);

            @synchronized (self) {
                [indicesOfSubreposWithUncommittedChanges addIndex:i];
            }
        }
        else {
            const int resetExitStatus = [subrepoGit resetLocalChanges];
            if (0 != resetExitStatus) {
                logError("  failed to discard uncommitted changes in subrepo '%s'\n",
                         subrepoDesc.path.fileSystemRepresentation);

                @synchronized (self) {
                    [indicesOfSubreposWithUncommittedChanges addIndex:i];
                }
            }
        }
    });

    if (0 == indicesOfSubreposWithUncommittedChanges.count && 0 == indicesOfSubreposWithConflict.count) {
        return S7ExitCodeSuccess;
    }

    *ppIndicesOfSubreposWithUncommittedChanges = indicesOfSubreposWithUncommittedChanges;
    *ppIndicesOfSubreposWithConflict = indicesOfSubreposWithConflict;
    return S7ExitCodeSubrepoHasLocalChanges;
}

+ (int)checkSubrepoUrlChanged:(S7SubrepoDescription *)subrepoDesc
                   subrepoGit:(GitRepository *)subrepoGit
                   urlChanged:(BOOL *)urlChanged
                       oldUrl:(NSString **)oldUrl
{
    NSString *currentUrl = nil;
    if (0 != [subrepoGit getUrl:&currentUrl]) {
        return S7ExitCodeGitOperationFailed;
    }

    *urlChanged = ([currentUrl isEqualToString:subrepoDesc.url]) == NO;
    *oldUrl = currentUrl;

    return S7ExitCodeSuccess;
}

+ (int)ensureSubrepoInTheRightState:(S7SubrepoDescription *)expectedSubrepoStateDesc
                         subrepoGit:(GitRepository *)subrepoGit
                              clean:(BOOL)clean
                  shouldInitSubrepo:(BOOL *)shouldInitSubrepo
{
    NSAssert(subrepoGit.redirectOutputToMemory,
             @"not to produce soup in the output, we buffer every git command output, "
              "and, if necessary, can dump it out in coordinated manner, once the command is done.");

    NSString *currentBranch = nil;
    BOOL isEmptyRepo = NO;
    BOOL isDetachedHEAD = NO;
    if (0 != [subrepoGit getCurrentBranch:&currentBranch isDetachedHEAD:&isDetachedHEAD isEmptyRepo:&isEmptyRepo]) {
        return S7ExitCodeGitOperationFailed;
    }

    if (nil == currentBranch) {
        if (isDetachedHEAD) {
            currentBranch = @"HEAD";
        }
        else {
            NSAssert(NO, @"");
            logError("  unexpected subrepo '%s' state. Failed to detect current branch.\n",
                     expectedSubrepoStateDesc.path.fileSystemRepresentation);
            return S7ExitCodeGitOperationFailed;
        }
    }

    NSString *currentRevision = nil;
    if (0 != [subrepoGit getCurrentRevision:&currentRevision]) {
        return S7ExitCodeGitOperationFailed;
    }

    if (clean && isS7Repo(subrepoGit)) {
        // if subrepo is an s7 repo itself, then reset it's subrepos first
        // as otherwise checkout would refuse to reset sub-subrepos' content
        //
        S7Config *subConfigToResetTo = nil;
        const int getConfigExitStatus = getConfig(subrepoGit, expectedSubrepoStateDesc.revision, &subConfigToResetTo);
        if (S7ExitCodeSuccess != getConfigExitStatus) {
            return getConfigExitStatus;
        }

        const int checkoutExitStatus =
            [S7PostCheckoutHook checkoutSubreposForRepo:subrepoGit
                                             fromConfig:[S7Config emptyConfig]
                                               toConfig:subConfigToResetTo
                                                  clean:YES];

        if (S7ExitCodeSuccess != checkoutExitStatus) {
            return checkoutExitStatus;
        }
    }

    S7SubrepoDescription *actualSubrepoStateDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:expectedSubrepoStateDesc.path
                                                    url:expectedSubrepoStateDesc.url
                                                    revision:currentRevision
                                                    branch:currentBranch];
    if ([actualSubrepoStateDesc isEqual:expectedSubrepoStateDesc]) {
        // even if the subrepo _is_ in the right state,
        // if it's an s7 repo itself, it's subrepos might be not in the right state,
        // thus we must check them too
        //
        if (isS7Repo(subrepoGit)) {
            S7Config *subrepoConfig = nil;
            const int getConfigExitStatus = getConfig(subrepoGit, expectedSubrepoStateDesc.revision, &subrepoConfig);
            if (S7ExitCodeSuccess != getConfigExitStatus) {
                return getConfigExitStatus;
            }

            const int checkoutExitStatus = [S7PostCheckoutHook
                                            checkoutSubreposForRepo:subrepoGit
                                            fromConfig:subrepoConfig
                                            toConfig:subrepoConfig
                                            clean:clean];

            if (S7ExitCodeSuccess != checkoutExitStatus) {
                return checkoutExitStatus;
            }
        }

        return S7ExitCodeSuccess;
    }

    // pastey:
    // we used to fetch subrepo only if the necessary revision was not available locally.
    // This turned to lead to a bug described in case-pushOfNewBranchDoesntPushUnnecessarySubrepos.sh
    // In short, we failed to push main repo because a subrepo push was rejected. And that got
    // rejected 'cause local branch was behind remote branch. But in reality, remote branch
    // just was not updated (fetched), as we skipped this step due to `isRevisionAvailableLocally`
    // check.
    //
    // Initially, this check was added to reduce the amount of network calls / heavy operations
    // on branch switches in the main repo.
    //
    // I considered some alternative fixes to `case-pushOfNewBranchDoesntPushUnnecessarySubrepos.sh`,
    // but all of them are too heavy and make this code harder to understand.
    // If we notice that additional fetches become a problem, we will try to find a way to skip
    // fetch when possible. One option is to perform fetch only if local branch is ahead of remote.
    //
//    if (NO == [subrepoGit isRevisionAvailableLocally:expectedSubrepoStateDesc.revision]) {
        logInfo("  fetching '%s'\n",
                [expectedSubrepoStateDesc.path fileSystemRepresentation]);

        S7Options *options = [S7Options new];
        if (0 != [subrepoGit fetchWithFilter:options.filter]) {
            logError("  failed to fetch '%s':\n%s\n\n",
                     [expectedSubrepoStateDesc.path fileSystemRepresentation],
                     [subrepoGit.lastCommandStdErrOutput cStringUsingEncoding:NSUTF8StringEncoding]);

            return S7ExitCodeGitOperationFailed;
        }

        logInfo("  fetched '%s'\n",
                [expectedSubrepoStateDesc.path fileSystemRepresentation]);

        if (NO == [subrepoGit isRevisionAvailableLocally:expectedSubrepoStateDesc.revision]) {
            logError("  revision '%s' does not exist in '%s'\n",
                     [expectedSubrepoStateDesc.revision cStringUsingEncoding:NSUTF8StringEncoding],
                     [expectedSubrepoStateDesc.path fileSystemRepresentation]);

            return S7ExitCodeInvalidSubrepoRevision;
        }
//    }

    logInfo("  switching '%s' to %s\n",
            [expectedSubrepoStateDesc.path fileSystemRepresentation],
            [expectedSubrepoStateDesc.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);

    // `git checkout -B branch revision`
    // this also makes checkout recursive if subrepo is a S7 repo itself
    if (0 != [subrepoGit forceCheckoutLocalBranch:expectedSubrepoStateDesc.branch revision:expectedSubrepoStateDesc.revision]) {
        return S7ExitCodeGitOperationFailed;
    }

    const BOOL configFileExists = isS7Repo(subrepoGit);
    const BOOL controlFileExists = [NSFileManager.defaultManager fileExistsAtPath:[subrepoGit.absolutePath stringByAppendingPathComponent:S7ControlFileName]];
    if (configFileExists && NO == controlFileExists) {
        // handling the case when a nested subrepo is added to an existing subrepo
        *shouldInitSubrepo = YES;
    }

    if (0 != [subrepoGit ensureBranchIsTrackingCorrespondingRemoteBranchIfItExists:expectedSubrepoStateDesc.branch]) {
        return S7ExitCodeGitOperationFailed;
    }

    [self warnAboutDetachingIfNeeded:currentRevision subrepoDesc:expectedSubrepoStateDesc subrepoGit:subrepoGit];

    return S7ExitCodeSuccess;
}

+ (int)cloneSubrepo:(S7SubrepoDescription *)subrepoDesc
parentRepoAbsolutePath:(NSString *)parentRepoAbsolutePath
         subrepoGit:(GitRepository **)ppSubrepoGit
{
    logInfo("  cloning from '%s'\n",
            [subrepoDesc.url fileSystemRepresentation]);

    int cloneExitStatus = 0;

    NSString *subrepoAbsolutePath = [parentRepoAbsolutePath stringByAppendingPathComponent:subrepoDesc.path];

    // in case of clone, Git sends all output to stderr
    NSString *gitOutput = nil;

    S7Options *options = [S7Options new];
    GitRepository *subrepoGit = [GitRepository
                                 cloneRepoAtURL:subrepoDesc.url
                                 branch:subrepoDesc.branch
                                 bare:NO
                                 destinationPath:subrepoAbsolutePath
                                 filter:options.filter
                                 stdOutOutput:&gitOutput
                                 stdErrOutput:&gitOutput
                                 exitStatus:&cloneExitStatus];
    if (nil == subrepoGit || 0 != cloneExitStatus) {
        logError("  failed to clone '%s' with exact branch '%s'. Will retry to clone default branch and switch to the revision\n",
                 [subrepoDesc.path fileSystemRepresentation],
                 [subrepoDesc.branch cStringUsingEncoding:NSUTF8StringEncoding]);

        cloneExitStatus = 0;
        subrepoGit = [GitRepository
                      cloneRepoAtURL:subrepoDesc.url
                      branch:nil
                      bare:NO
                      destinationPath:subrepoAbsolutePath
                      filter:options.filter
                      stdOutOutput:&gitOutput
                      stdErrOutput:&gitOutput
                      exitStatus:&cloneExitStatus];

        if (nil == subrepoGit || 0 != cloneExitStatus) {
            logError("  failed to clone subrepo '%s':\n%s\n\n",
                     [subrepoDesc.path fileSystemRepresentation],
                     [gitOutput cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeGitOperationFailed;
        }
    }

    logInfo("  cloned subrepo '%s'\n", [subrepoDesc.path fileSystemRepresentation]);

    NSAssert(subrepoGit, @"");
    *ppSubrepoGit = subrepoGit;
    subrepoGit.redirectOutputToMemory = YES;

    return S7ExitCodeSuccess;
}

+ (void (^)(NSString * _Nonnull, int))warnAboutDetachingCommitsHook {
    return _warnAboutDetachingCommitsHook;
}

+ (void)setWarnAboutDetachingCommitsHook:(void (^)(NSString * _Nonnull, int))warnAboutDetachingCommitsHook {
    _warnAboutDetachingCommitsHook = warnAboutDetachingCommitsHook;
}

+ (void)warnAboutDetachingIfNeeded:(NSString *)currentRevision
                       subrepoDesc:(S7SubrepoDescription *)subrepoDesc
                        subrepoGit:(GitRepository *)subrepoGit
{
    int numberOfOrphanedCommits = 0;
    if (NO == [subrepoGit isRevisionDetached:currentRevision
                     numberOfOrphanedCommits:&numberOfOrphanedCommits])
    {
        return;
    }

    // say you've been working on main branch in subrepo. You've created commits 4–6.
    // someone else had been working on this subrepo, and created commit 7. They rebound
    // the subrepo and pushed.
    // Looks like this:
    //
    //    * 7 origin/main
    //    | * 6 main
    //    | * 5
    //    | * 4
    //     /
    //    * 3
    //    * 2
    //    * 1
    //
    // You pulled in main repo and now, your local main would be forced to revision 7
    //
    //    * 7  main -> origin/main
    //    | * 6  [nothing is pointing here]
    //    | * 5
    //    | * 4
    //     /
    //    * 3
    //    * 2
    //    * 1
    //
    // As no other branch is pointing to 6, then it will be "lost" somewhere in the guts
    // of git ref-log
    //
    // We warn user about this situation
    //

    logInfo("\033[33m"
            "Warning: you are leaving %d commit(s) behind, not connected to\n"
            "any of your pushed branches in %s:\n"
            "\n"
            "  %s detached\n"
            "\n"
            "If you want to keep it by creating a new branch, this may be a good time\n"
            "to do so with:\n"
            "\n"
            " git branch <new-branch-name> %s\n"
            "\n"
            "Detached commit hash was also saved to %s\n"
            "\033[0m",
            numberOfOrphanedCommits,
            subrepoDesc.path.fileSystemRepresentation,
            [currentRevision cStringUsingEncoding:NSUTF8StringEncoding],
            [currentRevision cStringUsingEncoding:NSUTF8StringEncoding],
            S7BakFileName.fileSystemRepresentation);

    if (_warnAboutDetachingCommitsHook) {
        _warnAboutDetachingCommitsHook(currentRevision, numberOfOrphanedCommits);
    }

    FILE *backupFile = fopen(S7BakFileName.fileSystemRepresentation, "a+");
    if (backupFile) {
        fprintf(backupFile,
                "%s %s detached commit %s\n",
                [[NSDate.date description] cStringUsingEncoding:NSUTF8StringEncoding],
                subrepoDesc.path.fileSystemRepresentation,
                [currentRevision cStringUsingEncoding:NSUTF8StringEncoding]);

        fclose(backupFile);
    }
}

+ (int)initS7InSubrepos:(NSArray<GitRepository *> *)subrepos {
    int result = S7ExitCodeSuccess;

    for (GitRepository *subrepoGit in subrepos) {
        NSAssert([NSFileManager.defaultManager fileExistsAtPath:[subrepoGit.absolutePath stringByAppendingPathComponent:S7ConfigFileName]], @"");

        S7InitCommand *initCommand = [S7InitCommand new];
        // do not automatically create .s7bootstrap in subrepos. This makes uncommitted local changes
        // in subrepos. Especially inconvenient when you switch to some old revision.
        // Let user decide which repo should contain .s7bootstrap, by explicit invocation of
        // `s7 init` and add of .s7bootstrap to the repo.
        //
        const int initExitStatus = [initCommand runWithArguments:@[ @"--no-bootstrap" ] inRepo:subrepoGit];

        if (0 != initExitStatus) {
            result = initExitStatus;
        }
    }

    return result;
}

@end
