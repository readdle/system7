//
//  S7IniConfig.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 29.09.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface S7IniConfig : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)configWithContentsOfFile:(NSString *)filePath;
+ (instancetype)configWithContentsOfString:(NSString *)string;

- (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
