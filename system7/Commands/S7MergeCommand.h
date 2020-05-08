//
//  S7MergeCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 07.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7MergeCommand : NSObject <S7Command>

+ (S7Config *)mergeOurConfig:(S7Config *)ourLines
                 theirConfig:(S7Config *)theirConfig
                  baseConfig:(S7Config *)baseConfig;

@end

@interface S7SubrepoDescriptionConflict : S7SubrepoDescription

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithOurVersion:(nullable S7SubrepoDescription *)ourVersion theirVersion:(nullable S7SubrepoDescription *)theirVersion;

@property (nonatomic, readonly, nullable) S7SubrepoDescription *ourVersion;
@property (nonatomic, readonly, nullable) S7SubrepoDescription *theirVersion;

@end

NS_ASSUME_NONNULL_END
