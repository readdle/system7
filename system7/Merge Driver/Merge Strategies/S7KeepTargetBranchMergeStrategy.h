//
//  S7KeepTargetBranchMergeStrategy.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 31.01.2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

#import "S7MergeStrategy.h"

NS_ASSUME_NONNULL_BEGIN

@class S7Config;

@interface S7KeepTargetBranchMergeStrategy : NSObject <S7MergeStrategy>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTargetBranchName:(NSString *)targetBranchName;

@end

NS_ASSUME_NONNULL_END
