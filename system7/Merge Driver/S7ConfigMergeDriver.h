//
//  S7ConfigMergeDriver.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 18.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(uint32_t, S7ConflictResolutionOption) {
    S7ConflictResolutionOptionKeepLocal = (1 << 0),
    S7ConflictResolutionOptionKeepRemote = (1 << 1),
    S7ConflictResolutionOptionMerge = (1 << 2),
    S7ConflictResolutionOptionKeepChanged = (1 << 3),
    S7ConflictResolutionOptionDelete = (1 << 4),
    S7ConflictResolutionOptionKeepConflict = (1 << 5),
};

@class S7SubrepoDescription;

@interface S7ConfigMergeDriver : NSObject

- (int)runWithArguments:(NSArray<NSString *> *)arguments;

@property (nonatomic) S7ConflictResolutionOption (^resolveConflictBlock)(S7SubrepoDescription * _Nullable ourVersion,
                                                                         S7SubrepoDescription * _Nullable theirVersion);
@property (nonatomic) BOOL (^isTerminalInteractive)(void);

- (int)mergeRepo:(GitRepository *)repo
      baseConfig:(S7Config *)baseConfig
       ourConfig:(S7Config *)ourConfig
     theirConfig:(S7Config *)theirConfig
saveResultToFilePath:(NSString *)resultFilePath;

@end

NS_ASSUME_NONNULL_END
