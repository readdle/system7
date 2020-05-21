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
    S7ConflictResolutionTypeKeepLocal = (1 << 0),
    S7ConflictResolutionTypeKeepRemote = (1 << 1),
    S7ConflictResolutionTypeMerge = (1 << 2),
    S7ConflictResolutionTypeKeepChanged = (1 << 3),
    S7ConflictResolutionTypeDelete = (1 << 4),
    S7ConflictResolutionTypeKeepConflict = (1 << 5),
};

@class S7SubrepoDescription;

@interface S7ConfigMergeDriver : NSObject

- (int)runWithArguments:(NSArray<NSString *> *)arguments;

@property (nonatomic) S7ConflictResolutionOption (^resolveConflictBlock)(S7SubrepoDescription *ourVersion,
                                                                         S7SubrepoDescription *theirVersion,
                                                                         S7ConflictResolutionOption possibleOptions);

+ (S7Config *)mergeOurConfig:(S7Config *)ourLines
                 theirConfig:(S7Config *)theirConfig
                  baseConfig:(S7Config *)baseConfig;

- (int)mergeRepo:(GitRepository *)repo
      baseConfig:(S7Config *)baseConfig
       ourConfig:(S7Config *)ourConfig
     theirConfig:(S7Config *)theirConfig
saveResultToFilePath:(NSString *)resultFilePath;

@end

NS_ASSUME_NONNULL_END
