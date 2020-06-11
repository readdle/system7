//
//  S7StatusCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7StatusCommand.h"

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
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    const BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (NO == configFileExists || isDirectory) {
        return S7ExitCodeNotS7Repo;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];

    NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
    const int exitStatus = [S7StatusCommand repo:repo calculateStatus:&status];
    if (0 != exitStatus) {
        if (S7ExitCodeSubreposNotInSync == exitStatus) {
            fprintf(stderr,
                    "\033[31m"
                    "Subrepos not in sync.\n"
                    "This might be the result of:\n"
                    " - interrupted update\n"
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

        const BOOL hasUncommitedChanges = [notStagedCommittedSubrepos containsObject:subrepoPath];
        const BOOL hasCommittedChangesNotReboundInMainRepo = [notStagedUncommittedChangesSubrepos containsObject:subrepoPath];
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

    return 0;
}

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> * _Nullable __autoreleasing * _Nonnull)ppStatus {
    if (NO == [NSFileManager.defaultManager contentsEqualAtPath:S7ConfigFileName andPath:S7ControlFileName]) {
        return S7ExitCodeSubreposNotInSync;
    }

    NSString *lastCommittedRevision = nil;
    [repo getCurrentRevision:&lastCommittedRevision];

    int gitExitStatus = 0;
    NSString *lastCommittedConfigContents = [repo showFile:S7ConfigFileName
                                                atRevision:lastCommittedRevision
                                                exitStatus:&gitExitStatus];
    if (0 != gitExitStatus) {
        if (128 == gitExitStatus) {
            lastCommittedConfigContents = @"";
        }
        else {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }
    }

    NSAssert(lastCommittedConfigContents, @"");

    S7Config *lastCommittedConfig = [[S7Config alloc] initWithContentsString:lastCommittedConfigContents];
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
        int gitExitStatus = [subrepoGit getCurrentBranch:&currentBranch];
        if (0 != gitExitStatus) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        if (nil == currentBranch) {
            // the only case getCurrentBranch will succeed (return 0), but leave branch name nil
            // is the detached HEAD
            [subreposInDetachedHEAD addObject:subrepoPath];
            continue;
        }

        NSString *currentRevision = nil;
        gitExitStatus = [subrepoGit getCurrentRevision:&currentRevision];
        if (0 != gitExitStatus) {
            // todo: log
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
    
    return 0;
}

@end
