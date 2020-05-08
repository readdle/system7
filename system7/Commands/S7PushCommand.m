//
//  S7PushCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PushCommand.h"

#import "S7Diff.h"

@implementation S7PushCommand

- (void)printCommandHelp {
    puts("s7 push [--hook]");
    puts("");
    puts("--hook      is the command called from git `pre-push` hook. Means we mustn't push the main repo itself");
}

- (int)pushRepoAtPath:(NSString *)repoPath pushMainRepo:(BOOL)pushMainRepo level:(NSUInteger)level {
    GitRepository *repo = [[GitRepository alloc] initWithRepoPath:repoPath];
    if (nil == repo) {
        return S7ExitCodeSubrepoIsNotGitRepository;
    }

    BOOL isDirectory = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:[repoPath stringByAppendingPathComponent:S7ConfigFileName]
                                           isDirectory:&isDirectory])
    {
        if (isDirectory) {
            fprintf(stderr,
                    "abort: %s is a directory!\n",
                    [S7ConfigFileName fileSystemRepresentation]);
            return 2;
        }

        int gitExitStatus = 0;

        NSString *currentRevision = nil;
        gitExitStatus = [repo getCurrentRevision:&currentRevision];
        if (0 != gitExitStatus) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        NSString *latestRemoteRevisionAtThisBranch = nil;
        gitExitStatus = [repo getLatestRemoteRevision:&latestRemoteRevisionAtThisBranch atBranch:@"master"];
        if (0 != gitExitStatus) {
            fprintf(stderr,
                    "failed to find the latest remote revision to compare current state to\n");
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [repo isRevisionAnAncestor:latestRemoteRevisionAtThisBranch toRevision:currentRevision]) {
            // todo: log
            return S7ExitCodeNonFastForwardPush;
        }

        NSString *lastCommittedConfigContents = [repo showFile:S7ConfigFileName atRevision:currentRevision exitStatus:&gitExitStatus];
        if (nil == lastCommittedConfigContents || 0 != gitExitStatus) {
            fprintf(stderr,
                    "failed to retrieve latest committed .s7substate config. Git exit status: %d\n",
                    gitExitStatus);
            return S7ExitCodeNoCommittedS7Config;
        }

        NSString *lastRemoteConfigContents = [repo showFile:S7ConfigFileName atRevision:latestRemoteRevisionAtThisBranch exitStatus:&gitExitStatus];
        if (nil == lastRemoteConfigContents || 0 != gitExitStatus) {
            if (128 == gitExitStatus) {
                // config didn't exist before. Consider that we've just initialized s7 and are about to push this
                lastRemoteConfigContents = @"";
            }
            else {
                fprintf(stderr,
                        "failed to retrieve latest pushed .s7substate config. Git exit status: %d\n",
                        gitExitStatus);
                return S7ExitCodeGitOperationFailed;
            }
        }

        S7Config *lastCommittedConfig = [[S7Config alloc] initWithContentsString:lastCommittedConfigContents];
        S7Config *lastPushedConfig = [[S7Config alloc] initWithContentsString:lastRemoteConfigContents];

        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = nil;
        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = nil;
        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = nil;
        const int diffExitStatus = diffConfigs(lastPushedConfig,
                                               lastCommittedConfig,
                                               &subreposToDelete,
                                               &subreposToUpdate,
                                               &subreposToAdd);
        if (0 != diffExitStatus) {
            return diffExitStatus;
        }

        NSArray<S7SubrepoDescription *> *subreposToPush = [subreposToUpdate.allValues arrayByAddingObjectsFromArray:subreposToAdd.allValues];

        NSMutableString *padding = [NSMutableString stringWithString:@""];
        for (NSUInteger i = 0; i < level; ++i) {
            [padding appendString:@"  "];
        }
        
        for (S7SubrepoDescription *subrepoDesc in subreposToPush) {
            fprintf(stdout,
                    "%spushing '%s'\n",
                    [padding cStringUsingEncoding:NSUTF8StringEncoding],
                    subrepoDesc.path.fileSystemRepresentation);
            [self pushRepoAtPath:subrepoDesc.path pushMainRepo:YES level:level + 1];
        }
    }

    if (0 == level) {
        fprintf(stdout, "\npushing main repo\n");
    }

    if (pushMainRepo) {
        const int gitExitStatus = [repo pushAll];
        if (0 != gitExitStatus) {
            return gitExitStatus;
        }
    }

    return 0;
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    BOOL pushMainRepo = YES;
    if (arguments.count > 0) {
        if ([arguments[0] isEqualToString:@"--hook"]) {
            // it's already pushing ;)
            pushMainRepo = NO;
        }
    }

    return [self pushRepoAtPath:@"." pushMainRepo:pushMainRepo level:0];
}

@end
