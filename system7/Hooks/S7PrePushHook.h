//
//  S7PrePushHook.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Hook.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7PrePushHook : NSObject <S7Hook>

@end

@interface S7PrePushHook ()
@property (nonatomic, strong) NSString *testStdinContents;
@end

NS_ASSUME_NONNULL_END
