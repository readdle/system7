//
//  Utils.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN



int executeInDirectory(NSString *directory, int (NS_NOESCAPE ^block)(void));

int getConfig(GitRepository *repo, NSString *revision, S7Config * _Nullable __autoreleasing * _Nonnull ppConfig);

int addLineToGitIgnore(NSString *lineToAppend);

BOOL isExactlyOneBitSetInNumber(uint32_t bits);

#define S7_REPO_PRECONDITION_CHECK()                \
    do {                                            \
        BOOL isDirectory = NO;                      \
        if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory] \
            || isDirectory)                         \
        {                                           \
            fprintf(stderr,                         \
                    "abort: not s7 repo root\n");   \
            return S7ExitCodeNotS7Repo;             \
        }                                           \
    } while (0);

NS_ASSUME_NONNULL_END
