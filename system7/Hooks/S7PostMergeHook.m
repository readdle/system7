//
//  S7PostMergeHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PostMergeHook.h"

#import "S7PostCheckoutHook.h"
#import "S7InitCommand.h"

@implementation S7PostMergeHook

+ (NSString *)gitHookName {
    return @"post-merge";
}

+ (BOOL)dependsOnStdin {
    return NO;
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    logInfo("\ns7: post-merge hook start\n");
    const int result = [self doRunWithArguments:arguments];
    logInfo("s7: post-merge hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        logError("s7: post-merge hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
    }

    const int lfsInstallExitCode = [S7InitCommand initializeGitLFSIfNecessaryInRepo:repo];
    if (S7ExitCodeSuccess != lfsInstallExitCode) {
        return lfsInstallExitCode;
    }

    S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
    S7Config *postMergeConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:repo fromConfig:controlConfig toConfig:postMergeConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName]) {
        return [postMergeConfig saveToFileAtPath:S7ControlFileName];
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:S7ControlFileName]) {
        NSError *error = nil;
        if (NO == [NSFileManager.defaultManager removeItemAtPath:S7ControlFileName error:&error]) {
            logError("failed to remove %s. Error: %s\n",
                    S7ControlFileName.fileSystemRepresentation,
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeFileOperationFailed;
        }
    }
    
    return S7ExitCodeSuccess;
}

@end
