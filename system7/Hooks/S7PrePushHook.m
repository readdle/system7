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
//     repo .s7substate, then it won't be pushed. This would require
//     too much hassle to determine – we would have to examine every
//     commit about to push, check it updates .s7substate and collect
//     branches for every subrepo. Fuck it
// I decided to stick to the second variant for now.
//

@synthesize testStdinContents;

+ (NSString *)gitHookName {
    return @"pre-push";
}

+ (NSString *)hookFileContents {
    return @"#!/bin/sh\n"
            "s7 pre-push-hook \"$@\" <&0";
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
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        // if we got here, then `pre-push` hook is installed, then `s7 init` had been called,
        // then this must be an s7 repo
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

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

- (int)handlePushInRepo:(GitRepository *)repo
               localRef:(NSString *)localRef
              localSha1:(NSString *)localSha1ToPush
              remoteRef:(NSString *)remoteRef
             remoteSha1:(NSString *)latestRemoteRevisionAtThisBranch
{
    if ([localSha1ToPush isEqualToString:[GitRepository nullRevision]]) {
        // ignore remote branch delete
        return 0;
    }

    if ([localRef hasPrefix:@"refs/tags/"]) {
        // ignore tag push. We won't do anything anyways, but why even try, if we can skip it right away
        return 0;
    }

    int gitExitStatus = 0;
    NSString *configContentsAtRevisionToPush = [repo showFile:S7ConfigFileName
                                                   atRevision:localSha1ToPush
                                                   exitStatus:&gitExitStatus];
    if (nil == configContentsAtRevisionToPush || 0 != gitExitStatus) {
        // there's .s7substate locally, but it's not in the commit we are trying to push,
        // so... we are confused. If s7 is "de-initialized", then it's OK, but then
        // this hook should have been removed too.
        //
        fprintf(stderr,
                "failed to retrieve latest committed .s7substate config at %s.\n"
                "Git exit status: %d\n",
                localSha1ToPush.fileSystemRepresentation,
                gitExitStatus);
        return S7ExitCodeNoCommittedS7Config;
    }

    S7Config *lastCommittedConfig = [[S7Config alloc] initWithContentsString:configContentsAtRevisionToPush];

    S7Config *lastPushedConfig = nil;
    gitExitStatus = getConfig(repo, latestRemoteRevisionAtThisBranch, &lastPushedConfig);
    if (0 != gitExitStatus) {
        return gitExitStatus;
    }

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

    for (S7SubrepoDescription *subrepoDesc in subreposToPush) {
        fprintf(stdout,
                " checking '%s' %s\n",
                subrepoDesc.path.fileSystemRepresentation,
                subrepoDesc.humanReadableRevisionAndBranchState.fileSystemRepresentation);

        GitRepository *subrepoGit = [GitRepository repoAtPath:subrepoDesc.path];
        if (nil == subrepoGit) {
            fprintf(stderr, "abort: '%s' is not a git repo\n", subrepoDesc.path.fileSystemRepresentation);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        if ([subrepoGit isRevision:subrepoDesc.revision knownAtRemoteBranch:subrepoDesc.branch]) {
            continue;
        }

        fprintf(stdout, " pushing...\n");

        // if subrepo is a s7 repo itself, pre-push hook in it will do the rest for us
        const int gitExitStatus = [subrepoGit pushAllBranchesNeedingPush];
        if (0 != gitExitStatus) {
            return gitExitStatus;
        }
    }

    return 0;
}

@end
