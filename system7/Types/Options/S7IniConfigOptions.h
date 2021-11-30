//
//  S7IniConfigOptions.h
//  S7IniConfigOptions
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S7OptionsProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class S7IniConfig;


@interface S7IniConfigOptions : NSObject<S7OptionsProtocol>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithContentsOfFile:(NSString *)filePath;
- (nullable instancetype)initWithIniConfig:(S7IniConfig *)iniConfig NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
