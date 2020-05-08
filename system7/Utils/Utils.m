//
//  Utils.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "Utils.h"

int executeInDirectory(NSString *directory, int (NS_NOESCAPE ^block)(void)) {
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:directory]) {
        NSCAssert(NO, @"todo: add logs");
        return 3;
    }

    int operationReturnValue = 128;
    @try {
        operationReturnValue = block();
        return operationReturnValue;
    }
    @finally {
        if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:cwd]) {
            NSCAssert(NO, @"todo: add logs");
            return 4;
        }
    }
}

int getConfig(GitRepository *repo, NSString *revision, S7Config * _Nullable __autoreleasing * _Nonnull ppConfig) {
    int showExitStatus = 0;
    NSString *configContents = [repo showFile:S7ConfigFileName atRevision:revision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed? Or we are back to revision where there was no s7 yet
            configContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [revision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    *ppConfig = [[S7Config alloc] initWithContentsString:configContents];

    return 0;
}
