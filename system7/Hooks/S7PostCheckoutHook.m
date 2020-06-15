//
//  S7PostCheckoutHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostCheckoutHook.h"

#import "S7Diff.h"
#import "S7InitCommand.h"
#import "Utils.h"

static void (^_warnAboutDetachingCommitsHook)(NSString *topRevision, int numberOfCommits) = nil;

@implementation S7PostCheckoutHook

+ (NSString *)gitHookName {
    return @"post-checkout";
}

+ (NSString *)hookFileContents {
    return @"#!/bin/sh\n"
            "s7 post-checkout-hook \"$@\"";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: post-checkout hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: post-checkout hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    if (arguments.count < 3) {
        return S7ExitCodeMissingRequiredArgument;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
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

    if (0 != [toConfig saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);

        return S7ExitCodeFileOperationFailed;
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
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = nil;
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = nil;
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = nil;
    diffConfigs(fromConfig,
                toConfig,
                &subreposToDelete,
                &subreposToUpdate,
                &subreposToAdd);

    for (S7SubrepoDescription *subrepoToDelete in subreposToDelete.allValues) {
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

            fprintf(stdout, "removing subrepo '%s'", subrepoPath.fileSystemRepresentation);

            NSError *error = nil;
            if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoPath error:&error]) {
                fprintf(stderr,
                        " abort: failed to remove subrepo '%s' directory\n"
                        " error: %s\n",
                        [subrepoPath fileSystemRepresentation],
                        [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                return S7ExitCodeFileOperationFailed;
            }
        }
    }

    BOOL anySubrepoContainedUncommittedChanges = NO;

    for (S7SubrepoDescription *subrepoDesc in toConfig.subrepoDescriptions) {
        GitRepository *subrepoGit = nil;

        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoDesc.path isDirectory:&isDirectory] && isDirectory) {
            fprintf(stdout,
                    " checking out subrepo '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation]);

            subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoDesc.path];
            if (nil == subrepoGit) {
                return S7ExitCodeSubrepoIsNotGitRepository;
            }

            if ([subrepoGit hasUncommitedChanges]) {
                if (NO == clean) {
                    anySubrepoContainedUncommittedChanges = YES;

                    fprintf(stderr,
                            "\033[31m"
                            " uncommited local changes in subrepo '%s'\n"
                            "\033[0m",
                            subrepoDesc.path.fileSystemRepresentation);

                    continue;
                }
                else {
                    const int resetExitStatus = [subrepoGit resetLocalChanges];
                    if (0 != resetExitStatus) {
                        fprintf(stderr,
                                "failed to discard uncommited changes in subrepo '%s'\n",
                                subrepoDesc.path.fileSystemRepresentation);
                        return resetExitStatus;
                    }
                }
            }
        }
        else {
            fprintf(stdout,
                    " cloning subrepo '%s' from '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation],
                    [subrepoDesc.url fileSystemRepresentation]);

            int cloneExitStatus = 0;
            subrepoGit = [GitRepository
                          cloneRepoAtURL:subrepoDesc.url
                          destinationPath:subrepoDesc.path
                          exitStatus:&cloneExitStatus];
            if (nil == subrepoGit || 0 != cloneExitStatus) {
                fprintf(stderr,
                        " failed to clone subrepo '%s'\n",
                        [subrepoDesc.path fileSystemRepresentation]);
                return S7ExitCodeGitOperationFailed;
            }

            if ([NSFileManager.defaultManager fileExistsAtPath:[subrepoDesc.path stringByAppendingPathComponent:S7ConfigFileName]]) {
                const int initExitStatus =
                executeInDirectory(subrepoDesc.path, ^int{
                    S7InitCommand *initCommand = [S7InitCommand new];
                    return [initCommand runWithArguments:@[]];
                });

                if (0 != initExitStatus) {
                    return initExitStatus;
                }
            }
        }

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
                        "unexpected subrepo '%s' state. Failed to detect current branch.\n",
                        subrepoDesc.path.fileSystemRepresentation);
                return S7ExitCodeGitOperationFailed;
            }
        }

        NSString *currentRevision = nil;
        if (0 != [subrepoGit getCurrentRevision:&currentRevision]) {
            return S7ExitCodeGitOperationFailed;
        }

        S7SubrepoDescription *currentSubrepoDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:subrepoDesc.path
                                                    url:subrepoDesc.url
                                                    revision:currentRevision
                                                    branch:currentBranch];
        if ([currentSubrepoDesc isEqual:subrepoDesc]) {
            continue;
        }

        if (NO == [subrepoGit isRevisionAvailableLocally:subrepoDesc.revision]) {
            fprintf(stdout,
                    " fetching '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation]);

            if (0 != [subrepoGit fetch]) {
                return S7ExitCodeGitOperationFailed;
            }
        }

        if (NO == [subrepoGit isRevisionAvailableLocally:subrepoDesc.revision]) {
            fprintf(stderr,
                    " revision '%s' does not exist in '%s'\n",
                    [subrepoDesc.revision cStringUsingEncoding:NSUTF8StringEncoding],
                    [subrepoDesc.path fileSystemRepresentation]);

            return S7ExitCodeInvalidSubrepoRevision;
        }

        if (0 != [subrepoGit checkoutRemoteTrackingBranch:subrepoDesc.branch]) {
            return S7ExitCodeGitOperationFailed;
        }

        NSString *currentBranchHeadRevision = nil;
        if (0 != [subrepoGit getCurrentRevision:&currentBranchHeadRevision]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [subrepoDesc.revision isEqualToString:currentBranchHeadRevision]) {
            fprintf(stdout,
                    " checkout '%s' to %s\n",
                    subrepoDesc.path.fileSystemRepresentation,
                    [subrepoDesc.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);

            // `git checkout -B branch revision`
            // this also makes checkout recursive if subrepo is a S7 repo itself
            [subrepoGit forceCheckoutExistingLocalBranch:subrepoDesc.branch revision:subrepoDesc.revision];
        }

        int numberOfOrphanedCommits = 0;
        if (NO == [subrepoGit isRevisionReachableFromAnyBranch:currentRevision
                                       numberOfOrphanedCommits:&numberOfOrphanedCommits])
        {
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
                    "Warning: you are leaving %2$d commit(s) behind, not connected to\n"
                    "any of your branches:\n"
                    "\n"
                    "  %1$s detached\n"
                    "\n"
                    "If you want to keep it by creating a new branch, this may be a good time\n"
                    "to do so with:\n"
                    "\n"
                    " git branch <new-branch-name> %1$s\n"
                    "\n"
                    "Detached commit hash was also saved to %3$s\n"
                    "\033[0m",
                    [currentRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    numberOfOrphanedCommits,
                    S7BakFileName.fileSystemRepresentation);

            if (_warnAboutDetachingCommitsHook) {
                _warnAboutDetachingCommitsHook(currentRevision, numberOfOrphanedCommits);
            }

            FILE *backupFile = fopen(S7BakFileName.fileSystemRepresentation, "a+");
            if (backupFile) {
                fprintf(backupFile,
                        "%s %s detached commit %s\n",
                        [NSDate.now description].fileSystemRepresentation,
                        subrepoDesc.path.fileSystemRepresentation,
                        currentRevision.fileSystemRepresentation);

                fclose(backupFile);
            }
        }
    }

    if (anySubrepoContainedUncommittedChanges) {
        fprintf(stderr,
                "\033[31m"
                "\n"
                "  subrepos with uncommitted local changes were not updated\n"
                "  to prevent possible data loss\n"
                "\n"
                "  Use `s7 reset` to discard subrepo changes.\n"
                "  (see `s7 help reset` for more info)\n"
                "\n"
                "  Or you can run `git reset REV && git reset --hard REV`\n"
                "  in subrepo yourself.\n"
                "\033[0m");
        return S7ExitCodeSubrepoHasLocalChanges;
    }

    return 0;
}

+ (void (^)(NSString * _Nonnull, int))warnAboutDetachingCommitsHook {
    return _warnAboutDetachingCommitsHook;
}

+ (void)setWarnAboutDetachingCommitsHook:(void (^)(NSString * _Nonnull, int))warnAboutDetachingCommitsHook {
    _warnAboutDetachingCommitsHook = warnAboutDetachingCommitsHook;
}

@end
