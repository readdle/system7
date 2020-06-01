//
//  TestUtils.c
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#include "TestUtils.h"

#import "S7InitCommand.h"
#import "S7AddCommand.h"
#import "S7RemoveCommand.h"
#import "S7RebindCommand.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"

NS_ASSUME_NONNULL_BEGIN

void s7init(void) {
    S7InitCommand *initCommand = [S7InitCommand new];
    const int result = [initCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

void s7init_deactivateHooks(void) {
    S7InitCommand *initCommand = [S7InitCommand new];

    // disable real hooks installed by `s7 init` to work in clear environment
    // and be able to test our implementation of hooks.
    // Otherwise, the real implementation of s7 installed on machine would be
    // called. It's out of test process and we won't be able to test it.

    initCommand.installFakeHooks = YES;
    const int result = [initCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

GitRepository *s7add_impl(NSString *subrepoPath, NSString *url, BOOL stage) {
    S7AddCommand *addCommand = [S7AddCommand new];
    NSArray<NSString *> *arguments = @[];
    if (stage) {
        arguments = [arguments arrayByAddingObject:@"--stage"];
    }
    arguments = [arguments arrayByAddingObjectsFromArray:@[ subrepoPath, url ]];

    const int addResult = [addCommand runWithArguments:arguments];
    NSCAssert(0 == addResult, @"");

    GitRepository *subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoPath];
    NSCAssert(subrepoGit, @"");
    return subrepoGit;
}

GitRepository *s7add(NSString *subrepoPath, NSString *url) {
    return s7add_impl(subrepoPath, url, NO);
}

GitRepository *s7add_stage(NSString *subrepoPath, NSString *url) {
    return s7add_impl(subrepoPath, url, YES);
}

void s7remove(NSString *subrepoPath) {
    S7RemoveCommand *rebindCommand = [S7RemoveCommand new];
    const int result = [rebindCommand runWithArguments:@[subrepoPath]];
    NSCAssert(0 == result, @"");
}

void s7rebind(void) {
    S7RebindCommand *rebindCommand = [S7RebindCommand new];
    const int result = [rebindCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

void s7rebind_with_stage(void) {
    S7RebindCommand *rebindCommand = [S7RebindCommand new];
    const int result = [rebindCommand runWithArguments:@[ @"--stage" ]];
    NSCAssert(0 == result, @"");
}

void s7rebind_specific(NSString *subrepoPath) {
    S7RebindCommand *rebindCommand = [S7RebindCommand new];
    const int result = [rebindCommand runWithArguments:@[ subrepoPath ]];
    NSCAssert(0 == result, @"");
}

int s7push_currentBranch(GitRepository *repo) {
    NSString *currentBranchName = nil;
    if (0 != [repo getCurrentBranch:&currentBranchName]) {
        return 1;
    }

    NSCAssert(currentBranchName.length > 0, @"");

    NSString *currentRevision = nil;
    if (0 != [repo getCurrentRevision:&currentRevision]) {
        return 2;
    }

    NSString *lastPushedRevisionAtThisBranch = nil;
    if (0 != [repo getLatestRemoteRevision:&lastPushedRevisionAtThisBranch atBranch:currentBranchName]) {
        if ([repo isBranchTrackingRemoteBranch:currentBranchName]) {
            return 3;
        }
        else {
            lastPushedRevisionAtThisBranch = [GitRepository nullRevision];
        }
    }

    return s7push(repo, currentBranchName, currentRevision, lastPushedRevisionAtThisBranch);
}

int s7push(GitRepository *repo, NSString *branch, NSString *localSha1ToPush, NSString *remoteSha1LastPushed) {
    S7PrePushHook *prePushHook = [S7PrePushHook new];

    prePushHook.testStdinContents = [NSString stringWithFormat:@"refs/heads/%@ %@ refs/heads/%@ %@",
                                     branch,
                                     localSha1ToPush,
                                     branch,
                                     remoteSha1LastPushed];

    const int prePushHookExitStatus = [prePushHook runWithArguments:@[]];
    if (0 != prePushHookExitStatus) {
        return prePushHookExitStatus;
    }

    return [repo pushBranch:branch];
}

int s7checkout(NSString *fromRevision, NSString *toRevision) {
    S7PostCheckoutHook *checkoutCommand = [S7PostCheckoutHook new];
    return [checkoutCommand runWithArguments:@[fromRevision, toRevision, @"1"]];
}


NSString * commit(GitRepository *repo, NSString *fileName, NSString * _Nullable fileContents, NSString *commitMessage) {
    NSCParameterAssert(repo);
    NSCParameterAssert(0 == [repo createFile:fileName withContents:fileContents]);
    NSCParameterAssert(0 == [repo add:@[ fileName ]]);
    NSCParameterAssert(0 == [repo commitWithMessage:commitMessage]);
    NSString *resultingRevision = nil;
    NSCParameterAssert(0 == [repo getCurrentRevision:&resultingRevision]);
    return resultingRevision;
}

NS_ASSUME_NONNULL_END
