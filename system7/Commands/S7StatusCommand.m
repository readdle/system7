//
//  S7StatusCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7StatusCommand.h"

#import "Utils.h"
#import "S7Diff.h"

@implementation S7StatusCommand

+ (NSString *)commandName {
    return @"status";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    puts("s7 status [-n]");
    printCommandAliases(self);
    puts("");
    puts("show changed subrepos. By default, also prints main repo `git status`;");
    puts("");
    puts("  By default, also prints main repo `git status` (unless -n is passed).");
    puts("");
    puts("options:");
    puts("");
    puts(" -n    do not print main repo status along with subrepos' status");

}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    BOOL showMainRepoStatus = YES;
    for (NSString *argument in arguments) {
        if ([argument hasPrefix:@"-"]) {
            if ([argument isEqualToString:@"-n"]) {
                showMainRepoStatus = NO;
            }
            else {
                fprintf(stderr,
                        "option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeUnrecognizedOption;
            }
        }
        else {
            fprintf(stderr,
                    "redundant argument %s\n",
                    [argument cStringUsingEncoding:NSUTF8StringEncoding]);
            [[self class] printCommandHelp];
            return S7ExitCodeInvalidArgument;
        }
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];

    if (showMainRepoStatus) {
        [repo printStatus];
        puts("");
        puts("Subrepos status:");
    }

    BOOL foundAnyChanges = NO;
    const int exitStatus = [self printRepoStatus:repo foundAnyChanges:&foundAnyChanges];

    if (NO == foundAnyChanges) {
        puts("Everything up-to-date");
    }
    else {
        puts("");
    }

    return exitStatus;
}

- (int)printRepoStatus:(GitRepository *)repo foundAnyChanges:(BOOL *)foundAnyChanges {
    NSDictionary<NSString *, NSNumber * /* S7Status */> *subrepoPathToStatus = nil;
    const int exitStatus = [S7StatusCommand repo:repo calculateStatus:&subrepoPathToStatus];
    if (0 != exitStatus) {
        if (S7ExitCodeSubreposNotInSync == exitStatus) {
            fprintf(stderr,
                    "\033[31m"
                    "Subrepos not in sync.\n"
                    "This might be the result of:\n"
                    " - conflicting merge\n"
                    " - git reset\n"
                    "\n"
                    "`s7 checkout` might help you to make subrepos up-to-date.\n"
                    "\033[0m");
        }
        *foundAnyChanges = YES;
        return exitStatus;
    }

    // don't think that order really matters to end users, but it does matter in tests,
    // so let output be always sorted in some way
    NSArray<NSString *> *sortedSubrepoPaths = [subrepoPathToStatus.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    for (NSString *subrepoPath in sortedSubrepoPaths) {
        const S7Status status = subrepoPathToStatus[subrepoPath].unsignedIntegerValue;
        if (0 != (status & (S7StatusAdded | S7StatusRemoved | S7StatusUpdatedAndRebound))) {
            if (NO == *foundAnyChanges) {
                *foundAnyChanges = YES;
                puts("Changes to be committed:");
            }

            if (status & S7StatusAdded) {
                fprintf(stdout, " \033[32madded       %s\033[0m\n", subrepoPath.fileSystemRepresentation);
            }
            else if (status & S7StatusRemoved) {
                fprintf(stdout, " \033[31mremoved     %s\033[0m\n", subrepoPath.fileSystemRepresentation);
            }
            else if (status & S7StatusUpdatedAndRebound) {
                fprintf(stdout, " \033[34mupdated     %s\033[0m\n", subrepoPath.fileSystemRepresentation);
            }
        }
    }

    BOOL foundAnyNotReboundChanges = NO;
    for (NSString *subrepoPath in sortedSubrepoPaths) {
        const S7Status status = subrepoPathToStatus[subrepoPath].unsignedIntegerValue;

        if (0 == (status & (S7StatusDetachedHead | S7StatusHasUncommittedChanges | S7StatusHasNotReboundCommittedChanges))) {
            continue;
        }

        if (NO == foundAnyNotReboundChanges) {
            foundAnyNotReboundChanges = YES;

            if (NO == *foundAnyChanges) {
                *foundAnyChanges = YES;
            }
            else {
                puts("");
            }

            puts("Subrepos not staged for commit:");
        }

        if (S7StatusDetachedHead & status) {
            fprintf(stdout, " \033[31;1mdetached HEAD %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else if ((S7StatusHasUncommittedChanges & status) && (S7StatusHasNotReboundCommittedChanges & status)) {
            fprintf(stdout, " \033[36mnot rebound commit(s) + uncommitted changes %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else if (S7StatusHasUncommittedChanges & status) {
            fprintf(stdout, " \033[35muncommitted changes       %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else if (S7StatusHasNotReboundCommittedChanges & status) {
            fprintf(stdout, " \033[33;1mnot rebound commit(s)   %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
    }

    return S7ExitCodeSuccess;
}

+ (BOOL)areSubreposInSync {
    S7Config *mainConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
    return [mainConfig isEqual:controlConfig];
}

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSString *, NSNumber * /* S7Status */> * _Nullable __autoreleasing * _Nonnull)ppStatus
{
    if (NO == [self areSubreposInSync]) {
        return S7ExitCodeSubreposNotInSync;
    }

    NSString *lastCommittedRevision = nil;
    [repo getCurrentRevision:&lastCommittedRevision];

    S7Config *lastCommittedConfig = nil;
    int gitExitStatus = getConfig(repo, lastCommittedRevision, &lastCommittedConfig);
    if (0 != gitExitStatus) {
        return gitExitStatus;
    }

    S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:[repo.absolutePath stringByAppendingPathComponent:S7ConfigFileName]];

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *stagedAddedSubrepos = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *stagedDeletedSubrepos = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *stagedUpdatedSubrepos = nil;
    const int diffExitStatus = diffConfigs(lastCommittedConfig,
                                           actualConfig,
                                           &stagedDeletedSubrepos,
                                           &stagedUpdatedSubrepos,
                                           &stagedAddedSubrepos);
    if (0 != diffExitStatus) {
        return diffExitStatus;
    }

    NSMutableDictionary<NSString *, NSNumber * /* S7Status */> * result = [NSMutableDictionary new];

    for (NSString *subrepoPath in stagedDeletedSubrepos) {
        result[subrepoPath] = @(S7StatusRemoved);
    }

    __auto_type addResult = ^ void (NSString *subrepoPath, NSNumber *status) {
        @synchronized (self) {
            result[subrepoPath] = status;
        }
    };

    __block int error = 0;

    dispatch_apply(actualConfig.subrepoDescriptions.count, DISPATCH_APPLY_AUTO, ^(size_t i) {
        @synchronized (self) {
            if (0 != error) {
                return;
            }
        }

        S7SubrepoDescription *subrepoDesc = actualConfig.subrepoDescriptions[i];
        NSString *relativeSubrepoPath = subrepoDesc.path;
        
        NSString *absoluteSubrepoPath = [repo.absolutePath stringByAppendingPathComponent:relativeSubrepoPath];
        subrepoDesc = [[S7SubrepoDescription alloc] initWithPath:absoluteSubrepoPath
                                                             url:subrepoDesc.url
                                                        revision:subrepoDesc.revision
                                                          branch:subrepoDesc.branch];

        GitRepository *subrepoGit = [GitRepository repoAtPath:absoluteSubrepoPath];
        if (nil == subrepoGit) {
            @synchronized (self) {
                fprintf(stderr, "error: '%s' is not a git repository\n", relativeSubrepoPath.fileSystemRepresentation);
                error = S7ExitCodeSubrepoIsNotGitRepository;
            }
            return;
        }

        S7Status status = S7StatusUnchanged;

        if (stagedAddedSubrepos[relativeSubrepoPath]) {
            status |= S7StatusAdded;
        }

        if (stagedUpdatedSubrepos[relativeSubrepoPath]) {
            status |= S7StatusUpdatedAndRebound;
        }

        NSString *currentBranch = nil;
        BOOL isEmptyRepo = NO;
        BOOL isDetachedHEAD = NO;
        if (0 != [subrepoGit getCurrentBranch:&currentBranch isDetachedHEAD:&isDetachedHEAD isEmptyRepo:&isEmptyRepo]) {
            @synchronized (self) {
                error = S7ExitCodeGitOperationFailed;
            }
            return;
        }

        if (nil == currentBranch) {
            if (isDetachedHEAD) {
                status |= S7StatusDetachedHead;
            }
            else {
                @synchronized (self) {
                    fprintf(stderr,
                            "unexpected subrepo '%s' state. Failed to detect current branch.\n",
                            relativeSubrepoPath.fileSystemRepresentation);
                    error = S7ExitCodeGitOperationFailed;
                }
                return;
            }
        }
        else {
            NSString *currentRevision = nil;
            if (0 != [subrepoGit getCurrentRevision:&currentRevision]) {
                @synchronized (self) {
                    error = S7ExitCodeGitOperationFailed;
                }
                return;
            }

            S7SubrepoDescription *currentSubrepoDesc = [[S7SubrepoDescription alloc]
                                                        initWithPath:absoluteSubrepoPath
                                                        url:subrepoDesc.url
                                                        revision:currentRevision
                                                        branch:currentBranch];

            const BOOL hasCommittedChangesNotReboundInMainRepo = (NO == [currentSubrepoDesc isEqual:subrepoDesc]);
            if (hasCommittedChangesNotReboundInMainRepo) {
                status |= S7StatusHasNotReboundCommittedChanges;
            }

            if ([subrepoGit hasUncommitedChanges]) {
                status |= S7StatusHasUncommittedChanges;
            }
        }

        addResult(relativeSubrepoPath, @(status));

        if ([NSFileManager.defaultManager fileExistsAtPath:[absoluteSubrepoPath stringByAppendingPathComponent:S7ConfigFileName]]) {
            NSDictionary<NSString *, NSNumber *> *subrepoStatus = nil;
            const int subrepoStatusExitCode = [self repo:subrepoGit calculateStatus:&subrepoStatus];
            if (0 != subrepoStatusExitCode) {
                @synchronized (self) {
                    error = subrepoStatusExitCode;
                }
            }
            else {
                [subrepoStatus enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull subSubrepoPath, NSNumber * _Nonnull statusNumber, BOOL * _Nonnull stop) {
                    addResult([relativeSubrepoPath stringByAppendingPathComponent:subSubrepoPath], statusNumber);
                }];
            }
        }
    });

    if (0 != error) {
        return error;
    }

    *ppStatus = result;

    return S7ExitCodeSuccess;
}

@end
