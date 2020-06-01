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

@implementation S7PostCheckoutHook

+ (NSString *)gitHookName {
    return @"post-checkout";
}

+ (NSString *)hookFileContents {
    return @"#!/bin/sh\n"
            "s7 post-checkout-hook \"$@\"";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: start post-checkout hook\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: finished post-checkout hook\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

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
        // is to compare actual config sha1 to the one saved in S7ControlFileName
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
    int showExitStatus = 0;
    NSString *fromConfigContents = [repo showFile:S7ConfigFileName atRevision:fromRevision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed? Or we are back to revision where there was no s7 yet
            fromConfigContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [fromRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    NSString *toConfigContents = [repo showFile:S7ConfigFileName atRevision:toRevision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed? Or we are back to revision where there was no s7 yet
            toConfigContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [toRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    S7Config *fromConfig = [[S7Config alloc] initWithContentsString:fromConfigContents];
    S7Config *toConfig = [[S7Config alloc] initWithContentsString:toConfigContents];

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
                            "⚠️ not removing repo '%s' because it has %s.\n",
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
//                if (NO == self.clean) {
                    anySubrepoContainedUncommittedChanges = YES;

                    fprintf(stderr,
                            " 🚨 uncommited local changes in subrepo '%s'\n",
                            subrepoDesc.path.fileSystemRepresentation);

                    continue;
//                }
//                else {
//                    const int resetExitStatus = [subrepoGit resetLocalChanges];
//                    if (0 != resetExitStatus) {
//                        fprintf(stderr,
//                                "failed to discard uncommited changes in subrepo '%s'\n",
//                                subrepoDesc.path.fileSystemRepresentation);
//                        return resetExitStatus;
//                    }
//                }
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
        int gitExitStatus = [subrepoGit getCurrentBranch:&currentBranch];
        if (0 != gitExitStatus) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        NSString *currentRevision = nil;
        gitExitStatus = [subrepoGit getCurrentRevision:&currentRevision];
        if (0 != gitExitStatus) {
            // todo: log
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
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        NSString *currentBranchHeadRevision = nil;
        if (0 != [subrepoGit getCurrentRevision:&currentBranchHeadRevision]) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [subrepoDesc.revision isEqualToString:currentBranchHeadRevision]) {
            // todo: nil branch is not possible any more, but we are 'loosing' branch HEAD here
            // add safety here
//            if (nil == subrepoDesc.branch) {
//                fprintf(stdout,
//                        "checking out detached HEAD in subrepository '%s'\n",
//                        [subrepoDesc.path fileSystemRepresentation]);
//
//                fprintf(stdout,
//                        "check out a git branch if you intend to make changes\n");
//            }

            fprintf(stdout,
                    " checkout '%s' to %s\n",
                    subrepoDesc.path.fileSystemRepresentation,
                    [subrepoDesc.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);

            // I really hope that `reset` is always a good way to checkout a revision considering we are already
            // at the right branch.
            // I'm a bit confused, cause, for example, HG does `merge --ff` if we are going up, but their logic
            // is a bit different, so nevermind.
            // Life will show if I am right.
            //
            // Found an alternative – `git checkout -B branch revision`
            //
            [subrepoGit forceCheckoutExistingLocalBranch:subrepoDesc.branch revision:subrepoDesc.revision];
        }
    }

    if (anySubrepoContainedUncommittedChanges) {
        fprintf(stderr,
                "\033[31m"
                "\n"
                "  subrepos with uncommitted local changes were not updated\n"
                "  to prevent possible data loss\n"
                "  (use `s7 reset` to discard subrepo changes.\n"
                "   see `s7 help reset` for more info)\n"
                "\033[0m");
        return S7ExitCodeSubrepoHasLocalChanges;
    }

    return 0;
}

@end
