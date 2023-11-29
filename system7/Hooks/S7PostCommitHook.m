//
//  S7PostCommitHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostCommitHook.h"

#import "S7PostCheckoutHook.h"

@implementation S7PostCommitHook

+ (NSString *)gitHookName {
    return @"post-commit";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    logInfo("s7: post-commit hook start\n");
    const int result = [self doRunWithArguments:arguments];
    logInfo("s7: post-commit hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        logError("s7: post-commit hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
    }
    
    if ([S7PostCommitHook shouldSkipExecutionInRepo:repo]) {
        return 0;
    }

    if (self.hookWillUpdateSubrepos) {
        self.hookWillUpdateSubrepos();
    }

    S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
    S7Config *postMergeConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:repo fromConfig:controlConfig toConfig:postMergeConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    return [postMergeConfig saveToFileAtPath:S7ControlFileName];
}

+ (BOOL)shouldSkipExecutionInRepo:(GitRepository *)repo {
    // If revision is reverted or cherry-picked, post-commit is our only chanse to update substate.
    // During merge post-merge hook is not called when merge is interrupted, although commit is
    // recorded as a merge commit. During successful merge only post-merge is called.
    return ([repo isCurrentRevisionMerge] || [repo isCurrentRevisionCherryPickOrRevert]) == NO;
}

@end
