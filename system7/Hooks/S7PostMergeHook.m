//
//  S7PostMergeHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostMergeHook.h"

#import "S7CheckoutCommand.h"

@implementation S7PostMergeHook

+ (NSString *)gitHookName {
    return @"post-merge";
}

+ (NSString *)hookFileContents {
    return @"#!/bin/sh\n"
            "s7 post-merge-hook \"$@\"";
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    const char *debug = getenv("S7_DEBUG");
    if (debug) {
        fprintf(stdout, "🎖 start s7 post-merge hook\n");
    }
    const int result = [self doRunWithArguments:arguments];
    if (debug) {
        fprintf(stdout, "🎖✅ finished s7 post-merge hook\n");
    }
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7: post-merge hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
    }

    S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
    S7Config *postMergeConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    S7CheckoutCommand *checkoutCommand = [S7CheckoutCommand new];
    const int checkoutExitStatus = [checkoutCommand checkoutSubreposForRepo:repo fromConfig:controlConfig toConfig:postMergeConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    return [postMergeConfig saveToFileAtPath:S7ControlFileName];
}

@end
