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

    NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
    const int exitStatus = [S7StatusCommand repo:repo calculateStatus:&status];
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

    BOOL foundAnyChanges = NO;

    NSSet<NSString *> *stagedAddedSubrepos = status[@(S7StatusAdded)];
    NSSet<NSString *> *stagedDeletedSubrepos = status[@(S7StatusRemoved)];
    NSSet<NSString *> *stagedUpdatedSubrepos = status[@(S7StatusUpdatedAndRebound)];

    if (stagedAddedSubrepos.count > 0 || stagedDeletedSubrepos.count > 0 || stagedUpdatedSubrepos.count > 0) {
        foundAnyChanges = YES;

        puts("Changes to be committed:");
        for (NSString *subrepoPath in stagedAddedSubrepos) {
            fprintf(stdout, " \033[32madded       %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }

        for (NSString *subrepoPath in stagedDeletedSubrepos) {
            fprintf(stdout, " \033[31mremoved     %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }

        for (NSString *subrepoPath in stagedUpdatedSubrepos) {
            fprintf(stdout, " \033[34mupdated     %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
    }

    NSSet<NSString *> *notStagedCommittedSubrepos = status[@(S7StatusHasNotReboundCommittedChanges)];
    NSSet<NSString *> *notStagedUncommittedChangesSubrepos = status[@(S7StatusHasUncommittedChanges)];
    NSSet<NSString *> *subreposInDetachedHEAD = status[@(S7StatusDetachedHead)];

    S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    BOOL foundAnyNotReboundChanges = NO;
    for (S7SubrepoDescription *subrepoDesc in actualConfig.subrepoDescriptions) {
        NSString *subrepoPath = subrepoDesc.path;

        const BOOL hasUncommitedChanges = [notStagedUncommittedChangesSubrepos containsObject:subrepoPath];
        const BOOL hasCommittedChangesNotReboundInMainRepo = [notStagedCommittedSubrepos containsObject:subrepoPath];
        const BOOL detachedHEAD = [subreposInDetachedHEAD containsObject:subrepoPath];

        if (NO == hasUncommitedChanges && NO == hasCommittedChangesNotReboundInMainRepo && NO == detachedHEAD) {
            continue;
        }

        if (NO == foundAnyNotReboundChanges) {
            foundAnyNotReboundChanges = YES;

            if (NO == foundAnyChanges) {
                foundAnyChanges = YES;
            }
            else {
                puts("");
            }

            puts("Subrepos not staged for commit:");
        }

        if (detachedHEAD) {
            fprintf(stdout, " \033[31;1mdetached HEAD %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else if (hasUncommitedChanges && hasCommittedChangesNotReboundInMainRepo) {
            fprintf(stdout, " \033[36mnot rebound commit(s) + uncommitted changes %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else if (hasUncommitedChanges) {
            fprintf(stdout, " \033[35muncommitted changes       %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
        else {
            NSAssert(hasCommittedChangesNotReboundInMainRepo, @"");
            fprintf(stdout, " \033[33;1mnot rebound commit(s)   %s\033[0m\n", subrepoPath.fileSystemRepresentation);
        }
    }

    if (NO == foundAnyChanges) {
        puts("Everything up-to-date");
    }
    else {
        puts("");
    }

    return S7ExitCodeSuccess;
}

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> * _Nullable __autoreleasing * _Nonnull)ppStatus {
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

    NSMutableDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> * status = [NSMutableDictionary new];

    if (stagedAddedSubrepos.count > 0) {
        status[@(S7StatusAdded)] = [NSSet setWithArray:stagedAddedSubrepos.allKeys];
    }

    if (stagedDeletedSubrepos.count > 0) {
        status[@(S7StatusRemoved)] = [NSSet setWithArray:stagedDeletedSubrepos.allKeys];
    }

    if (stagedUpdatedSubrepos.count > 0) {
        status[@(S7StatusUpdatedAndRebound)] = [NSSet setWithArray:stagedUpdatedSubrepos.allKeys];
    }

    NSMutableSet<NSString *> *subreposInDetachedHEAD = [NSMutableSet new];
    NSMutableSet<NSString *> *subreposWithUncommittedChanges = [NSMutableSet new];
    NSMutableSet<NSString *> *subreposWithCommittedNotReboundChanges = [NSMutableSet new];

    for (S7SubrepoDescription *subrepoDesc in actualConfig.subrepoDescriptions) {
        NSString *subrepoPath = subrepoDesc.path;

        GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoPath];
        if (nil == subrepoGit) {
            fprintf(stderr, "error: '%s' is not a git repository\n", subrepoPath.fileSystemRepresentation);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        NSString *currentBranch = nil;
        BOOL isEmptyRepo = NO;
        BOOL isDetachedHEAD = NO;
        if (0 != [subrepoGit getCurrentBranch:&currentBranch isDetachedHEAD:&isDetachedHEAD isEmptyRepo:&isEmptyRepo]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (nil == currentBranch) {
            if (isDetachedHEAD) {
                [subreposInDetachedHEAD addObject:subrepoPath];
            }
            else {
                fprintf(stderr,
                        "unexpected subrepo '%s' state. Failed to detect current branch.\n",
                        subrepoPath.fileSystemRepresentation);
                return S7ExitCodeGitOperationFailed;
            }
            continue;
        }

        NSString *currentRevision = nil;
        gitExitStatus = [subrepoGit getCurrentRevision:&currentRevision];
        if (0 != gitExitStatus) {
            return S7ExitCodeGitOperationFailed;
        }

        S7SubrepoDescription *currentSubrepoDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:subrepoPath
                                                    url:subrepoDesc.url
                                                    revision:currentRevision
                                                    branch:currentBranch];

        const BOOL hasCommittedChangesNotReboundInMainRepo = (NO == [currentSubrepoDesc isEqual:subrepoDesc]);
        const BOOL hasUncommitedChanges = [subrepoGit hasUncommitedChanges];

        if (hasUncommitedChanges) {
            [subreposWithUncommittedChanges addObject:subrepoPath];
        }

        if (hasCommittedChangesNotReboundInMainRepo) {
            [subreposWithCommittedNotReboundChanges addObject:subrepoPath];
        }
    }

    if (subreposWithUncommittedChanges.count > 0) {
        status[@(S7StatusHasUncommittedChanges)] = subreposWithUncommittedChanges;
    }

    if (subreposWithCommittedNotReboundChanges.count > 0) {
        status[@(S7StatusHasNotReboundCommittedChanges)] = subreposWithCommittedNotReboundChanges;
    }

    if (subreposInDetachedHEAD.count > 0) {
        status[@(S7StatusDetachedHead)] = subreposInDetachedHEAD;
    }

    *ppStatus = status;
    
    return S7ExitCodeSuccess;
}

@end
