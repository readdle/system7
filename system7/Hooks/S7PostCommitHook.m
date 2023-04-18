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
    fprintf(stdout, "s7: post-commit hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: post-commit hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7: post-commit hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
    }
    
    if (NO == [repo shouldExecutePostCommitHook]) {
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

@end
