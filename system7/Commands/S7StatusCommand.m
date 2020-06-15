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
    puts("s7 status");
    printCommandAliases(self);
    puts("");
    puts("show changed subrepos");
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

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSString *, NSNumber * /* S7Status */> * _Nullable __autoreleasing * _Nonnull)ppStatus
{
    if (NO == [NSFileManager.defaultManager contentsEqualAtPath:S7ConfigFileName andPath:S7ControlFileName]) {
        return S7ExitCodeSubreposNotInSync;
    }

    NSString *lastCommittedRevision = nil;
    [repo getCurrentRevision:&lastCommittedRevision];

    S7Config *lastCommittedConfig = nil;
    int gitExitStatus = getConfig(repo, lastCommittedRevision, &lastCommittedConfig);
    if (0 != gitExitStatus) {
        return gitExitStatus;
    }

    S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

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

    for (S7SubrepoDescription *subrepoDesc in actualConfig.subrepoDescriptions) {
        NSString *subrepoPath = subrepoDesc.path;

        GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoPath];
        if (nil == subrepoGit) {
            fprintf(stderr, "error: '%s' is not a git repository\n", subrepoPath.fileSystemRepresentation);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        S7Status status = S7StatusUnchanged;

        if (stagedAddedSubrepos[subrepoPath]) {
            status |= S7StatusAdded;
        }

        if (stagedDeletedSubrepos[subrepoPath]) {
            status |= S7StatusRemoved;
        }

        if (stagedUpdatedSubrepos[subrepoPath]) {
            status |= S7StatusUpdatedAndRebound;
        }

        NSString *currentBranch = nil;
        BOOL isEmptyRepo = NO;
        BOOL isDetachedHEAD = NO;
        if (0 != [subrepoGit getCurrentBranch:&currentBranch isDetachedHEAD:&isDetachedHEAD isEmptyRepo:&isEmptyRepo]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (nil == currentBranch) {
            if (isDetachedHEAD) {
                status |= S7StatusDetachedHead;
            }
            else {
                fprintf(stderr,
                        "unexpected subrepo '%s' state. Failed to detect current branch.\n",
                        subrepoPath.fileSystemRepresentation);
                return S7ExitCodeGitOperationFailed;
            }
        }
        else {
            NSString *currentRevision = nil;
            if (0 != [subrepoGit getCurrentRevision:&currentRevision]) {
                return S7ExitCodeGitOperationFailed;
            }

            S7SubrepoDescription *currentSubrepoDesc = [[S7SubrepoDescription alloc]
                                                        initWithPath:subrepoPath
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

        result[subrepoPath] = @(status);
    }

    *ppStatus = result;

    return S7ExitCodeSuccess;
}

@end
