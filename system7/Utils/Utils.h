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

BOOL isCurrentDirectoryS7RepoRoot(void);
int s7RepoPreconditionCheck(void);
int saveUpdatedConfigToMainAndControlFile(S7Config *updatedConfig);

#define S7_REPO_PRECONDITION_CHECK()                    \
    do {                                                \
        const int result = s7RepoPreconditionCheck();   \
        if (S7ExitCodeSuccess != result) {              \
            return result;                              \
        }                                               \
    } while (0);

#define SAVE_UPDATED_CONFIG_TO_MAIN_AND_CONTROL_FILE(updatedConfig)                 \
    do {                                                                            \
        const int result = saveUpdatedConfigToMainAndControlFile(updatedConfig);    \
        if (S7ExitCodeSuccess != result) {                                          \
            return result;                                                          \
        }                                                                           \
    } while (0);

NS_ASSUME_NONNULL_END
