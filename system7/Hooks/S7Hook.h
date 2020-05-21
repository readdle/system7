//
//  S7Hook.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 13.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef S7Hook_h
#define S7Hook_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol S7Hook <NSObject>

+ (NSString *)gitHookName;
+ (NSString *)hookFileContents;

- (int)runWithArguments:(NSArray<NSString *> *)arguments;

@end

NS_ASSUME_NONNULL_END

#endif /* S7Hook_h */
