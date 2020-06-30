//
//  S7PostMergeHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostMergeHook.h"

#import "S7PostCheckoutHook.h"

@implementation S7PostMergeHook

+ (NSString *)gitHookName {
    return @"post-merge";
}

+ (NSString *)hookFileContents {
    return @"#!/bin/sh\n"
            "/usr/local/bin/s7 post-merge-hook \"$@\"";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: post-merge hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: post-merge hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7: post-merge hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
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
