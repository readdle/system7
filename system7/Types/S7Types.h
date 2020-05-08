//
//  S7Types.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 29.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef S7ExitCodes_h
#define S7ExitCodes_h

#import <Foundation/Foundation.h>

extern NSString * const S7ConfigFileName;

typedef enum {
    S7ExitCodeDirty = -1,
    S7ExitCodeSuccess = 0,
    S7ExitCodeMissingRequiredArgument,
    S7ExitCodeInvalidArgument,
    S7ExitCodeUnrecognizedOption,
    S7ExitCodeFileOperationFailed,
    S7ExitCodeGitOperationFailed,
    S7ExitCodeNotGitRepository,
    S7ExitCodeSubrepoIsNotGitRepository,
    S7ExitCodeUncommitedChanges,
    S7ExitCodeNonFastForwardPush,
    S7ExitCodeNotS7Repo,
    S7ExitCodeNoCommittedS7Config,
    S7ExitCodeInvalidSubrepoRevision
} S7ExitCode;

#endif /* S7ExitCodes_h */
