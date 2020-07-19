//
//  S7PrePushHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PrePushHook.h"

#import "Utils.h"
#import "S7Diff.h"
#import "S7StatusCommand.h"

@implementation S7PrePushHook

// The command called from git `pre-push` hook.
// Means that git is pushing the main repo and we must take
// care of subrepos changed in pushed revisions.
//
// A hook script to verify what is about to be pushed. Called by "git push"
// after it has checked the remote status, but before anything has been
// pushed.  If this script exits with a non-zero status nothing will be pushed.
//
// This hook is called with the following parameters:
//
// $1 -- Name of the remote to which the push is being done
// $2 -- URL to which the push is being done
//
// If pushing without using a named remote those arguments will be equal.
//
// Information about the commits which are being pushed is supplied as lines to
// the standard input in the form:
//
//   <local ref> <local sha1> <remote ref> <remote sha1>
//
//
// I had several strategies of how we should push subrepos:
//  1. strictly current branch in a subrepo.
//     This is actually the way HG works with Git subrepos
//     and we never noticed.
//  2. all branches that have not pushed commits in a subrepo.
//     This is how HG works with HG subrepos.
//  3. only branches that were rebound in the main repo.
//     I.e. if a branch in subrepo was never mentioned in the main
//     repo .s7substate, then it won't be pushed.
//
// At first, I decided to use the second variant. Turned out there's no reliable way (I'm aware of)
// in Git to find out the list of branches that need to be pushed.
// I used `git log --branches --not --remotes --no-walk --decorate --pretty=format:%S` for some time,
// but turned out that it reports some behind branches from time to time (I haven't found an easy way
// to reproduce this). I could fix it by removing --no-walk, but I've found another scenario where
// even without --no-walk not all branches are listed – it you merge brances with fast-forward (they
// both point to the same commit), only one of branches is reported by `git log --branches --not --remotes`.
// I thought,– "alright – I can list .git/refs/heads and .git/refs/remotes, and build the list
// of branches to push by hand". Here comes a new problem – how do you distinct between the new local
// branch and a stale local branch which remote companion has been removed and pruned?
//
// All the problems of the second approach led to the 3rd solution.
//

@synthesize testStdinContents;

+ (NSString *)gitHookName {
    return @"pre-push";
}

+ (NSString *)hookFileContents {
    return hookFileContentsForHookNamed([self gitHookName]);
}

- (NSString *)stdinContents {
    if (self.testStdinContents) {
        return self.testStdinContents;
    }

    NSData *stdinData = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
    return [[NSString alloc] initWithData:stdinData encoding:NSUTF8StringEncoding];
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: pre-push hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: pre-push hook complete\n\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    GitRepository *repo = [[GitRepository alloc] initWithRepoPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }


    NSString *stdinStringContent = [[self stdinContents] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (0 == stdinStringContent.length) {
        // user is playing with `git push` on an up-to-date repo
        return 0;
    }

    // pastey:
    // I had such idea,–
    // "disallow git push if there're uncommitted changes in subrepos.
    //  Or committed, but not pushed, and current revision in subrepo
    //  is not in sync with .s7substate"
    //
    // I even implemented it, but decided not to publish.
    //  1. I thought HG behaves like this, but that's not true
    //  2. I think such behavior break too many normal flows.
    //     Eg. I've made some changes in a subrepo, then made an unrelated
    //     fix in main repo and want to push it. Should we prohibit this?
    //     I don't think so.
    //     Say you've made a huge refactoring touching many subrepos, you've
    //     rebound some of subrepos and want to commit/push them separetly,
    //     I think this must be allowed.
    //
//    NSDictionary<NSNumber *, NSSet<NSString *> *> *status = nil;
//    const int statusExitCode = [S7StatusCommand repo:repo calculateStatus:&status];
//    if (0 != statusExitCode) {
//        return statusExitCode;
//    }
//
//    if (status.count > 0) {
//        fprintf(stderr, "some subrepos have not rebound/committed changes:\n");
//        NSSet<NSString *> *dirtySubreposSet = [NSSet new];
//        for (NSSet<NSString *> *subrepoPaths in status.allValues) {
//            dirtySubreposSet = [dirtySubreposSet setByAddingObjectsFromSet:subrepoPaths];
//        }
//
//        for (NSString *subrepoPath in dirtySubreposSet) {
//            fprintf(stderr, " %s\n", subrepoPath.fileSystemRepresentation);
//        }
//
//        return S7ExitCodeSubrepoHasNotReboundChanges;
//    }

    NSArray<NSString *> *stdinLines = [stdinStringContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in stdinLines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (0 == trimmedLine.length) {
            continue;
        }

        // Information about the commits which are being pushed is supplied as lines to
        // the standard input in the form:
        //
        //   <local ref> <local sha1> <remote ref> <remote sha1>
        //
        NSArray<NSString *> *lineComponents = [trimmedLine componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (4 != lineComponents.count) {
            fprintf(stderr,
                    "failed to parse git `pre-push` stdin contents. \nLine: '%s'. \nFull stdin contents: '%s'",
                    [trimmedLine cStringUsingEncoding:NSUTF8StringEncoding],
                    [stdinStringContent cStringUsingEncoding:NSUTF8StringEncoding]);
            NSAssert(NO, @"git got mad?");

            return S7ExitCodeGitOperationFailed;
        }


        NSString *localRef = lineComponents[0];
        NSString *localSha1 = lineComponents[1];
        NSString *remoteRef = lineComponents[2];
        NSString *remoteSha1 = lineComponents[3];

        const int exitStatus = [self handlePushInRepo:repo
                                             localRef:localRef
                                            localSha1:localSha1
                                            remoteRef:remoteRef
                                           remoteSha1:remoteSha1];
        if (0 != exitStatus) {
            return exitStatus;
        }
    }

    return 0;
}

- (int)calculateSubreposToPushFromMainRepo:(GitRepository *)repo
          latestRemoteRevisionAtThisBranch:(NSString *)latestRemoteRevisionAtThisBranch
                           localSha1ToPush:(NSString *)localSha1ToPush
                            subreposToPush:(NSMutableDictionary<NSString *,NSMutableArray<S7SubrepoDescription *> *> **)ppSubreposToPush
{
    S7Config *lastPushedConfig = nil;
    int gitExitStatus = getConfig(repo, latestRemoteRevisionAtThisBranch, &lastPushedConfig);
    if (0 != gitExitStatus) {
        return gitExitStatus;
    }

    NSString *logFromRevision = latestRemoteRevisionAtThisBranch;
    if ([latestRemoteRevisionAtThisBranch isEqualToString:[GitRepository nullRevision]]) {
        logFromRevision = @"origin";
    }

    NSArray<NSString *> *allRevisionsChangingConfigSinceLastPush = [repo
                                                                    logRevisionsOfFile:S7ConfigFileName
                                                                    fromRef:logFromRevision
                                                                    toRef:localSha1ToPush
                                                                    exitStatus:&gitExitStatus];
    if (0 != gitExitStatus) {
        return S7ExitCodeGitOperationFailed;
    }

    if (0 == allRevisionsChangingConfigSinceLastPush.count) {
        fprintf(stdout, " found no changes to subrepos in commits being pushed.\n");
        return S7ExitCodeSuccess;
    }

    NSMutableSet<NSString *> *aggregatedSubreposToDeletePaths = [NSMutableSet new];
    NSMutableDictionary<NSString *, NSMutableArray<S7SubrepoDescription *> *> *aggregatedSubreposToAdd = [NSMutableDictionary new];
    NSMutableDictionary<NSString *, NSMutableArray<S7SubrepoDescription *> *> *aggregatedSubreposToUpdate = [NSMutableDictionary new];

    S7Config *prevConfig = lastPushedConfig;

    __auto_type addSubreposToAggregatedMap = ^ void (NSDictionary<NSString *, S7SubrepoDescription *> *source,
                                                     NSMutableDictionary<NSString *, NSMutableArray<S7SubrepoDescription *> *> *destination)
    {
        [source
         enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull subrepoPath,
                                             S7SubrepoDescription * _Nonnull subrepoDesc,
                                             BOOL * _Nonnull _)
         {
            NSMutableArray<S7SubrepoDescription *> *descriptions = destination[subrepoPath];
            if (nil == descriptions) {
                descriptions = [NSMutableArray new];
                destination[subrepoPath] = descriptions;
            }

            [descriptions addObject:subrepoDesc];
        }];
    };

    for (NSString *revisionChangingConfig in allRevisionsChangingConfigSinceLastPush) {
        S7Config *configAtRevision = nil;
        gitExitStatus = getConfig(repo, revisionChangingConfig, &configAtRevision);
        if (0 != gitExitStatus) {
            return gitExitStatus;
        }

        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = nil;
        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = nil;
        NSDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = nil;
        const int diffExitStatus = diffConfigs(prevConfig,
                                               configAtRevision,
                                               &subreposToDelete,
                                               &subreposToUpdate,
                                               &subreposToAdd);
        if (0 != diffExitStatus) {
            return diffExitStatus;
        }

        prevConfig = configAtRevision;

        if (subreposToDelete.count > 0) {
            [aggregatedSubreposToDeletePaths addObjectsFromArray:subreposToDelete.allKeys];
            [aggregatedSubreposToAdd removeObjectsForKeys:subreposToDelete.allKeys];
            [aggregatedSubreposToUpdate removeObjectsForKeys:subreposToDelete.allKeys];
        }

        if (subreposToAdd.count > 0) {
            [aggregatedSubreposToDeletePaths minusSet:[NSSet setWithArray:subreposToAdd.allKeys]];

            addSubreposToAggregatedMap(subreposToAdd, aggregatedSubreposToAdd);
        }

        if (subreposToUpdate.count > 0) {
#ifdef DEBUG
            for (NSString *subrepoPath in subreposToUpdate) {
                NSAssert(NO == [aggregatedSubreposToDeletePaths containsObject:subrepoPath], @"");
            }
#endif
            addSubreposToAggregatedMap(subreposToUpdate, aggregatedSubreposToUpdate);
        }
    }

    NSMutableDictionary<NSString *, NSMutableArray<S7SubrepoDescription *> *> *subreposToPush =
        [aggregatedSubreposToUpdate mutableCopy];
    [aggregatedSubreposToAdd
     enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull subrepoPath,
                                         NSMutableArray<S7SubrepoDescription *> * _Nonnull addDescriptions,
                                         BOOL * _Nonnull _)
     {
        NSMutableArray<S7SubrepoDescription *> *updateDescriptions = subreposToPush[subrepoPath];
        if (updateDescriptions) {
            [updateDescriptions addObjectsFromArray:addDescriptions];
        }
        else {
            subreposToPush[subrepoPath] = addDescriptions;
        }
    }];

    *ppSubreposToPush = subreposToPush;

    return S7ExitCodeSuccess;
}

- (int)handlePushInRepo:(GitRepository *)repo
               localRef:(NSString *)localRef
              localSha1:(NSString *)localSha1ToPush
              remoteRef:(NSString *)remoteRef
             remoteSha1:(NSString *)latestRemoteRevisionAtThisBranch
{
    fprintf(stdout, " processing '%s' -> '%s' push\n",
            [localRef cStringUsingEncoding:NSUTF8StringEncoding],
            [remoteRef cStringUsingEncoding:NSUTF8StringEncoding]);

    if ([localSha1ToPush isEqualToString:[GitRepository nullRevision]]) {
        fprintf(stdout, " remote branch delete. Nothing to do here.\n");
        return S7ExitCodeSuccess;
    }

    if ([localRef hasPrefix:@"refs/tags/"]) {
        // ignore tag push. We won't do anything anyways, but why even try, if we can skip it right away
        fprintf(stdout, " tag push. Nothing to do here.\n");
        return S7ExitCodeSuccess;
    }

    int gitExitStatus = 0;
    NSString *configContentsAtRevisionToPush = [repo showFile:S7ConfigFileName
                                                   atRevision:localSha1ToPush
                                                   exitStatus:&gitExitStatus];
    if (nil == configContentsAtRevisionToPush || 0 != gitExitStatus) {
        // there's no .s7substate in the commit we are trying to push,
        // this means there's no s7 at this branch, so we shouldn't do
        // anything here
        //
        // If there was s7 before, then there're two ways user could go:
        //  1. 's7 rm' all subrepos. rm wouldn't do anything if subrepo changes were not pushed,
        //     so user would be forced to push subrepo changes before rm
        //  2. user decided to pull the trigger and killed subrepos and .s7substate in
        //     a rude way. If they did this, there's no way we can help them 🤷‍♂️
        fprintf(stdout, " not s7 branch. Nothing to do here.\n");
        return S7ExitCodeSuccess;
    }

    NSMutableDictionary<NSString *,NSMutableArray<S7SubrepoDescription *> *> * subreposToPush = nil;
    const int exitStatus = [self calculateSubreposToPushFromMainRepo:repo
                                    latestRemoteRevisionAtThisBranch:latestRemoteRevisionAtThisBranch
                                                     localSha1ToPush:localSha1ToPush
                                                      subreposToPush:&subreposToPush];
    if (0 != exitStatus) {
        return exitStatus;
    }

    for (NSString *subrepoPath in subreposToPush) {
        fprintf(stdout,
                " checking '%s' ... ",
                subrepoPath.fileSystemRepresentation);
        // flush here 'cause next commands (for example, -isRevision:knownAtRemoteBranch:)
        // may spawn some output to stderr, and user sees the soup of 'checking' and
        // 'error: blah-blah...'
        fflush(stdout);

        GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoPath];
        if (nil == subrepoGit) {
            fprintf(stderr, "\nabort: '%s' is not a git repo\n", subrepoPath.fileSystemRepresentation);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        NSMutableSet<NSString *> *branchesToPush = [NSMutableSet new];

        for (S7SubrepoDescription *subrepoDesc in subreposToPush[subrepoPath]) {
            NSString *branch = subrepoDesc.branch;
            if ([branchesToPush containsObject:branch]) {
                continue;
            }

            if ([subrepoGit isRevision:subrepoDesc.revision knownAtRemoteBranch:branch]) {
                continue;
            }

            [branchesToPush addObject:branch];
        }

        if (branchesToPush.count > 0) {
            fprintf(stdout, "\n"); // close the 'checking...'

            for (NSString *branch in branchesToPush) {
                fprintf(stdout, "  pushing '%s'...\n", [branch cStringUsingEncoding:NSUTF8StringEncoding]);

                // if subrepo is a s7 repo itself, pre-push hook in it will do the rest for us
                const int gitExitStatus = [subrepoGit pushBranch:branch];
                if (0 != gitExitStatus) {
                    return gitExitStatus;
                }
            }

            fprintf(stdout, " success\n");
        }
        else {
            fprintf(stdout, " already pushed.\n");
        }
    }

    return S7ExitCodeSuccess;
}

@end
