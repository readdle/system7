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
extern NSString * const S7ControlFileName;
extern NSString * const S7BakFileName;
extern NSString * const S7BootstrapFileName;
extern NSString * const S7OptionsFileName;

typedef enum {
    S7ExitCodeSuccess = 0,
    S7ExitCodeUnknownCommand,
    S7ExitCodeMissingRequiredArgument,
    S7ExitCodeInvalidArgument,
    S7ExitCodeInvalidParameterValue,
    S7ExitCodeUnrecognizedOption,
    S7ExitCodeFileOperationFailed,
    S7ExitCodeGitOperationFailed,
    S7ExitCodeNotGitRepository,
    S7ExitCodeSubrepoIsNotGitRepository,
    S7ExitCodeSubrepoHasLocalChanges,
    S7ExitCodeDetachedHEAD,
    S7ExitCodeSubrepoAlreadyExists,
    S7ExitCodeSubreposNotInSync,
    S7ExitCodeNonFastForwardPush,
    S7ExitCodeMergeFailed,
    S7ExitCodeSubrepoHasNotReboundChanges,
    S7ExitCodeNotS7Repo,
    S7ExitCodeNoCommittedS7Config,
    S7ExitCodeInvalidSubrepoRevision,
    S7ExitCodeInternalError,
    S7ExitCodeFailedToParseConfig,
} S7ExitCode;

#endif /* S7ExitCodes_h */
