//
//  S7PostCheckoutHook.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Hook.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const S7GitPostCheckoutHookFilePath;
extern NSString *const S7GitPostCheckoutHookFileContents;

@interface S7PostCheckoutHook : NSObject <S7Hook>

@end

NS_ASSUME_NONNULL_END
