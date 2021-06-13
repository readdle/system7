//
//  S7PostCheckoutHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostCheckoutHook.h"

#import "S7Diff.h"
#import "Utils.h"
#import "S7InitCommand.h"
#import "S7BootstrapCommand.h"

static void (^_warnAboutDetachingCommitsHook)(NSString *topRevision, int numberOfCommits) = nil;

@implementation S7PostCheckoutHook

+ (NSString *)gitHookName {
    return @"post-checkout";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "\ns7: post-checkout hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: post-checkout hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count < 3) {
        return S7ExitCodeMissingRequiredArgument;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    [self uninstallBootstrapInfection];

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
            return 0;
        }
    }

    if (NO == [repo isRevisionAvailableLocally:fromRevision] && NO == [fromRevision isEqualToString:[GitRepository nullRevision]]) {
        fprintf(stderr,
                "FROM_REV %s is not available in this repository\n",
                [fromRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (NO == [repo isRevisionAvailableLocally:toRevision]) {
        fprintf(stderr,
                "TO_REV %s is not available in this repository\n",
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

    if ([NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName]) {
        if (0 != [toConfig saveToFileAtPath:S7ControlFileName]) {
            fprintf(stderr,
                    "failed to save %s to disk.\n",
                    S7ControlFileName.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }
    }
    else if ([NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName]) {
        NSError *error = nil;
        if (NO == [NSFileManager.defaultManager removeItemAtPath:S7ControlFileName error:&error]) {
            fprintf(stderr, "failed to remove %s. Error: %s\n",
                    S7ControlFileName.fileSystemRepresentation,
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeFileOperationFailed;
        }
    }

    return 0;
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

    int exitCode = S7ExitCodeSuccess;

    const int deleteExitCode = [self deleteSubrepos:subreposToDelete.allValues];
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
                                         corruptedSubrepoRepositoryIndices:&corruptedSubrepoRepositoryIndices];
        if (S7ExitCodeSuccess != getGitReposExitCode) {
            exitCode = getGitReposExitCode;
        }

        if (corruptedSubrepoRepositoryIndices.count > 0) {
            NSAssert(S7ExitCodeSuccess != exitCode, @"");
            [subreposToCheckout removeObjectsAtIndexes:corruptedSubrepoRepositoryIndices];
        }
    }

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
        const int checkUncommittedChangesExitCode = [self
                                                     ensureSubreposHaveNoUncommitedChanges:subreposToCheckout
                                                     subrepoDescToGit:subrepoDescToGit
                                                     clean:clean
                                                     indicesOfSubreposWithUncommittedChanges:&subreposWithUncommittedChangesIndices];
        if (S7ExitCodeSuccess != checkUncommittedChangesExitCode) {
            exitCode = checkUncommittedChangesExitCode;
        }

        if (subreposWithUncommittedChangesIndices.count > 0) {
            fprintf(stderr,
                    "\033[31m"
                    "\n"
                    "  subrepos with uncommitted local changes were not updated\n"
                    "  to prevent possible data loss:\n\n");

            [subreposToCheckout
             enumerateObjectsAtIndexes:subreposWithUncommittedChangesIndices
             options:0
             usingBlock:^(S7SubrepoDescription * _Nonnull subrepoDesc, NSUInteger idx, BOOL * _Nonnull stop) {
                fprintf(stderr, "    %s\n", [subrepoDesc.path fileSystemRepresentation]);
             }];

            fprintf(stderr,
                    "\n"
                    "  Use `s7 reset` to discard subrepo changes.\n"
                    "  (see `s7 help reset` for more info)\n"
                    "\n"
                    "  Or you can run `git reset REV && git reset --hard REV`\n"
                    "  in subrepo yourself.\n"
                    "\033[0m");

            [subreposToCheckout removeObjectsAtIndexes:subreposWithUncommittedChangesIndices];
        }
    }

    NSMutableArray<GitRepository *> *subreposToInit = [NSMutableArray new];

    for (S7SubrepoDescription *subrepoDesc in subreposToCheckout) {
        GitRepository *subrepoGit = subrepoDescToGit[subrepoDesc];

        fprintf(stdout,
                "\033[34m>\033[0m \033[1mchecking out subrepo '%s'\033[0m\n",
                [subrepoDesc.path fileSystemRepresentation]);

        if (subrepoGit) {
            BOOL subrepoUrlChanged = NO;
            NSString *oldUrl = nil;
            const int checkExitCode = [self checkSubrepoUrlChanged:subrepoDesc
                                                        subrepoGit:subrepoGit
                                                        urlChanged:&subrepoUrlChanged
                                                            oldUrl:&oldUrl];
            if (S7ExitCodeSuccess != checkExitCode) {
                exitCode = checkExitCode;
                continue;
            }

            if (subrepoUrlChanged) {
                // for example, we have moved from an official github.com/airbnb/lottie
                // to our fork at github.com/readdle/lottie
                // We still clone it to Dependencies/Thirdparty/lottie,
                // but the remote is absolutely different.
                //
                fprintf(stdout,
                        " detected that subrepo '%s' has migrated:\n"
                        "  from '%s'\n"
                        "  to '%s'\n"
                        "  removing an old version...\n",
                        [subrepoDesc.path fileSystemRepresentation],
                        [oldUrl cStringUsingEncoding:NSUTF8StringEncoding],
                        [subrepoDesc.url cStringUsingEncoding:NSUTF8StringEncoding]);

                NSError *error = nil;
                if (NO == [[NSFileManager defaultManager] removeItemAtPath:subrepoDesc.path error:&error]) {
                    fprintf(stderr,
                            "\033[31m"
                            "failed to remove old version of '%s' from disk. Error: %s\n"
                            "\033[0m",
                            subrepoDesc.path.fileSystemRepresentation,
                            [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
                    exitCode = S7ExitCodeFileOperationFailed;
                    continue;
                }

                subrepoGit = nil;
                subrepoDescToGit[subrepoDesc] = nil;
            }
        }

        if (nil == subrepoGit) {
            const int cloneExitCode = [self cloneSubrepo:subrepoDesc subrepoGit:&subrepoGit];
            if (S7ExitCodeSuccess != cloneExitCode) {
                exitCode = cloneExitCode;
                continue;
            }

            NSAssert(subrepoGit, @"");

            subrepoDescToGit[subrepoDesc] = subrepoGit;

            if ([NSFileManager.defaultManager fileExistsAtPath:[subrepoDesc.path stringByAppendingPathComponent:S7ConfigFileName]]) {
                [subreposToInit addObject:subrepoGit];
            }
        }

        BOOL shouldInitSubrepo = NO;
        const S7ExitCode checkoutExitCode = [self ensureSubrepoInTheRightState:subrepoDesc
                                                                    subrepoGit:subrepoGit
                                                                         clean:clean
                                                             shouldInitSubrepo:&shouldInitSubrepo];
        if (S7ExitCodeSuccess != checkoutExitCode) {
            exitCode = checkoutExitCode;
            continue;
        }

        if (shouldInitSubrepo) {
            [subreposToInit addObject:subrepoGit];
        }
    }

    const S7ExitCode initExitCode = [self initS7InSubrepos:subreposToInit];
    if (S7ExitCodeSuccess != initExitCode) {
        exitCode = initExitCode;
    }

    return exitCode;
}

+ (int)deleteSubrepos:(NSArray<S7SubrepoDescription *> *)subreposToDelete {
    int exitCode = S7ExitCodeSuccess;
    for (S7SubrepoDescription *subrepoToDelete in subreposToDelete) {
        NSString *subrepoPath = subrepoToDelete.path;
        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoPath isDirectory:&isDirectory] && isDirectory) {
            GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoPath];
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

                    fprintf(stderr,
                            "⚠️  not removing repo '%s' because it has %s.\n",
                            subrepoPath.fileSystemRepresentation,
                            reason);
                    continue;
                }
            }

            fprintf(stdout, "\033[31m>\033[0m \033[1mremoving subrepo '%s'\033[0m\n", subrepoPath.fileSystemRepresentation);

            NSError *error = nil;
            if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoPath error:&error]) {
                fprintf(stderr,
                        " abort: failed to remove subrepo '%s' directory\n"
                        " error: %s\n",
                        [subrepoPath fileSystemRepresentation],
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
{
    int exitCode = S7ExitCodeSuccess;

    NSMutableIndexSet *corruptedSubrepoRepositoryIndices = [NSMutableIndexSet new];
    NSMutableDictionary<S7SubrepoDescription *, GitRepository *> *subrepoDescToGit = [NSMutableDictionary dictionaryWithCapacity:subrepoDescriptions.count];

    for (NSUInteger i = 0; i < subrepoDescriptions.count; ++i) {
        S7SubrepoDescription *subrepoDesc = subrepoDescriptions[i];

        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoDesc.path isDirectory:&isDirectory] && isDirectory) {
            GitRepository *subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoDesc.path];
            if (nil == subrepoGit) {
                [corruptedSubrepoRepositoryIndices addIndex:i];
                exitCode = S7ExitCodeSubrepoIsNotGitRepository;
                continue;
            }

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
{
    NSMutableIndexSet *indicesOfSubreposWithUncommittedChanges = [NSMutableIndexSet new];

    dispatch_apply(subrepoDescriptions.count, DISPATCH_APPLY_AUTO, ^(size_t i) {
        S7SubrepoDescription *subrepoDesc = subrepoDescriptions[i];
        GitRepository *subrepoGit = subrepoDescToGit[subrepoDesc];

        NSCAssert(subrepoDesc, @"");

        if (nil == subrepoGit) {
            // this subrepo is not cloned yet, so nothing to check
            return;
        }


        if (NO == [subrepoGit hasUncommitedChanges]) {
            return;
        }

        if (NO == clean) {
            @synchronized (self) {
                // use fprintf in synchronized to make sure output of several parallel operation doesn't get mixed
                fprintf(stderr,
                        "\033[31m"
                        "  uncommited local changes in subrepo '%s'\n"
                        "\033[0m",
                        subrepoDesc.path.fileSystemRepresentation);

                [indicesOfSubreposWithUncommittedChanges addIndex:i];
            }
        }
        else {
            const int resetExitStatus = [subrepoGit resetLocalChanges];
            if (0 != resetExitStatus) {
                @synchronized (self) {
                    fprintf(stderr,
                            "\033[31m"
                            "  failed to discard uncommited changes in subrepo '%s'\n"
                            "\033[0m",
                            subrepoDesc.path.fileSystemRepresentation);

                    [indicesOfSubreposWithUncommittedChanges addIndex:i];
                }
            }
        }
    });

    if (0 == indicesOfSubreposWithUncommittedChanges.count) {
        return S7ExitCodeSuccess;
    }

    *ppIndicesOfSubreposWithUncommittedChanges = indicesOfSubreposWithUncommittedChanges;
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

    *urlChanged = ([currentUrl isEqualToString:subrepoDesc.url]) == NO;;

    return S7ExitCodeSuccess;
}

+ (int)ensureSubrepoInTheRightState:(S7SubrepoDescription *)expectedSubrepoStateDesc
                         subrepoGit:(GitRepository *)subrepoGit
                              clean:(BOOL)clean
                  shouldInitSubrepo:(BOOL *)shouldInitSubrepo
{
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
            fprintf(stderr,
                    "\033[31m"
                    "  unexpected subrepo '%s' state. Failed to detect current branch.\n"
                    "\033[0m",
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
        if (0 != getConfigExitStatus) {
            return getConfigExitStatus;
        }

        const int checkoutExitStatus = executeInDirectory(expectedSubrepoStateDesc.path, ^int{
            return [S7PostCheckoutHook
                    checkoutSubreposForRepo:subrepoGit
                    fromConfig:[S7Config emptyConfig]
                    toConfig:subConfigToResetTo
                    clean:YES];
        });

        if (0 != checkoutExitStatus) {
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
        // if it's an s7 repo itself, it's subpores might be not in the right state,
        // thus we must check them too
        //
        if (isS7Repo(subrepoGit)) {
            S7Config *subrepoConfig = nil;
            const int getConfigExitStatus = getConfig(subrepoGit, expectedSubrepoStateDesc.revision, &subrepoConfig);
            if (0 != getConfigExitStatus) {
                return getConfigExitStatus;
            }

            const int checkoutExitStatus = executeInDirectory(expectedSubrepoStateDesc.path, ^int{
                return [S7PostCheckoutHook
                        checkoutSubreposForRepo:subrepoGit
                        fromConfig:subrepoConfig
                        toConfig:subrepoConfig
                        clean:clean];
            });

            if (S7ExitCodeSuccess != checkoutExitStatus) {
                return checkoutExitStatus;
            }
        }

        return S7ExitCodeSuccess;
    }

    if (NO == [subrepoGit isRevisionAvailableLocally:expectedSubrepoStateDesc.revision]) {
        fprintf(stdout,
                "\033[34m  >\033[0m fetching '%s'\n",
                [expectedSubrepoStateDesc.path fileSystemRepresentation]);

        if (0 != [subrepoGit fetch]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [subrepoGit isRevisionAvailableLocally:expectedSubrepoStateDesc.revision]) {
            fprintf(stderr,
                    "\033[31m"
                    "  revision '%s' does not exist in '%s'\n"
                    "\033[0m",
                    [expectedSubrepoStateDesc.revision cStringUsingEncoding:NSUTF8StringEncoding],
                    [expectedSubrepoStateDesc.path fileSystemRepresentation]);

            return S7ExitCodeInvalidSubrepoRevision;
        }
    }

    fprintf(stdout,
            "  switching to %s\n",
            [expectedSubrepoStateDesc.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);

    // `git checkout -B branch revision`
    // this also makes checkout recursive if subrepo is a S7 repo itself
    if (0 != [subrepoGit forceCheckoutLocalBranch:expectedSubrepoStateDesc.branch revision:expectedSubrepoStateDesc.revision]) {
        // TODO: raise flag and complain
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

+ (int)cloneSubrepo:(S7SubrepoDescription *)subrepoDesc subrepoGit:(GitRepository **)ppSubrepoGit {
    fprintf(stdout,
            "  cloning from '%s'\n",
            [subrepoDesc.url fileSystemRepresentation]);

    int cloneExitStatus = 0;
    GitRepository *subrepoGit = [GitRepository
                                 cloneRepoAtURL:subrepoDesc.url
                                 branch:subrepoDesc.branch
                                 bare:NO
                                 destinationPath:subrepoDesc.path
                                 exitStatus:&cloneExitStatus];
    if (nil == subrepoGit || 0 != cloneExitStatus) {
        fprintf(stderr,
                "⚠️  failed to clone '%s' with exact branch '%s'. Will retry to clone default branch and switch to the revision\n",
                [subrepoDesc.path fileSystemRepresentation],
                [subrepoDesc.branch cStringUsingEncoding:NSUTF8StringEncoding]);

        cloneExitStatus = 0;
        subrepoGit = [GitRepository
                      cloneRepoAtURL:subrepoDesc.url
                      destinationPath:subrepoDesc.path
                      exitStatus:&cloneExitStatus];

        if (nil == subrepoGit || 0 != cloneExitStatus) {
            fprintf(stderr,
                    "\033[31m"
                    "  failed to clone subrepo '%s'\n"
                    "\033[0m",
                    [subrepoDesc.path fileSystemRepresentation]);
            return S7ExitCodeGitOperationFailed;
        }
    }

    NSAssert(subrepoGit, @"");
    *ppSubrepoGit = subrepoGit;

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

    // say you've been working on master branch in subrepo. You've created commits 4–6.
    // someone else had been working on this subrepo, and created commit 7. They rebound
    // the subrepo and pushed.
    // Looks like this:
    //
    //    * 7 origin/master
    //    | * 6 master
    //    | * 5
    //    | * 4
    //     /
    //    * 3
    //    * 2
    //    * 1
    //
    // You pulled in main repo and now, your local master would be forced to revision 7
    //
    //    * 7  master -> origin/master
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

    fprintf(stdout,
            "\033[33m"
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

        const int initExitStatus =
        executeInDirectory(subrepoGit.absolutePath, ^int{
            S7InitCommand *initCommand = [S7InitCommand new];
            // do not automatically create .s7bootstrap in subrepos. This makes uncomitted local changes
            // in subrepos. Especially inconvinient when you switch to some old revision.
            // Let user decide which repo should contain .s7bootstrap, by explicit invocation of
            // `s7 init` and add of .s7bootstap to the repo.
            //
            return [initCommand runWithArguments:@[ @"--no-bootstrap" ]];
        });

        if (0 != initExitStatus) {
            result = initExitStatus;
        }
    }

    return result;
}

- (void)uninstallBootstrapInfection {
    // pastey:
    // Temporary hotfix to mitigate bootstrap hook infection spread.
    // This function is here to fix the consequences of bootstrap spread in innocent subrepos.
    // This function can be removed after Jan 7, 2021
    //
    NSString *hookFilePath = @".git/hooks/post-checkout";

    NSString *existingContents = [[NSString alloc] initWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];

    NSString *updatedContents = [existingContents stringByReplacingOccurrencesOfString:[[S7BootstrapCommand class] bootstrapCommandLine]
                                                                           withString:@""];

    if (NO == [updatedContents isEqualToString:existingContents]) {
        [updatedContents writeToFile:hookFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

@end
