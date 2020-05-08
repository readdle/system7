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
#import "S7PushCommand.h"
#import "S7CheckoutCommand.h"

NS_ASSUME_NONNULL_BEGIN

void s7init(void) {
    S7InitCommand *initCommand = [S7InitCommand new];
    const int result = [initCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

GitRepository *s7add(NSString *subrepoPath, NSString *url) {
    S7AddCommand *addCommand = [S7AddCommand new];
    const int addResult = [addCommand runWithArguments:@[ subrepoPath, url ]];
    NSCAssert(0 == addResult, @"");

    GitRepository *subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoPath];
    NSCAssert(subrepoGit, @"");
    return subrepoGit;
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

void s7push(void) {
    S7PushCommand *pushCommand = [S7PushCommand new];
    const int result = [pushCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

int s7checkout(NSString *fromRevision, NSString *toRevision) {
    S7CheckoutCommand *checkoutCommand = [S7CheckoutCommand new];
    return [checkoutCommand runWithArguments:@[fromRevision, toRevision]];
}


NSString * commit(GitRepository *repo, NSString *fileName, NSString * _Nullable fileContents, NSString *commitMessage) {
    NSCParameterAssert(0 == [repo createFile:fileName withContents:fileContents]);
    NSCParameterAssert(0 == [repo add:@[ fileName ]]);
    NSCParameterAssert(0 == [repo commitWithMessage:commitMessage]);
    NSString *resultingRevision = nil;
    NSCParameterAssert(0 == [repo getCurrentRevision:&resultingRevision]);
    return resultingRevision;
}

NS_ASSUME_NONNULL_END
