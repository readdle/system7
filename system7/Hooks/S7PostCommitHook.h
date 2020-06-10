//
//  S7PostCommitHook.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Hook.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7PostCommitHook : NSObject <S7Hook>

@property (nullable, nonatomic) void (^hookWillUpdateSubrepos)(void);

@end

NS_ASSUME_NONNULL_END
