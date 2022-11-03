//
//  S7Options.m
//  system7
//
//  Created by Andrew Podrugin on 26.11.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7Options.h"
#import "S7IniConfigOptions.h"
#import "S7DefaultOptions.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const S7UserOptionsFilePath = @"~/.s7options";


@interface S7Options()

@property (nonatomic, readonly) NSArray<id<S7OptionsProtocol>> *optionsChain;

@end


@implementation S7Options

#pragma mark - Initialization -

- (instancetype)init {
    if (nil == (self = [super init])) {
        return nil;
    }
    
    NSMutableArray<id<S7OptionsProtocol>> *optionsChain = [NSMutableArray arrayWithCapacity:2];
    
    __auto_type addIniConfigOptionsIfPossible = ^(NSString *iniOptionsFilePath) {
        NSString *fullPath = iniOptionsFilePath.stringByExpandingTildeInPath;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
            [optionsChain addObject:[[S7IniConfigOptions alloc] initWithContentsOfFile:fullPath]];
        }
    };
    
    NSString *userOptionsFilePath = S7UserOptionsFilePath;
    const char *userOptionsPathEnvVariable = getenv("S7_USER_OPTIONS_PATH");

    if (NULL != userOptionsPathEnvVariable) {
        userOptionsFilePath = [NSString stringWithUTF8String:userOptionsPathEnvVariable];
    }
    
    addIniConfigOptionsIfPossible(S7OptionsFileName);
    addIniConfigOptionsIfPossible(userOptionsFilePath);
    
    [optionsChain addObject:[S7DefaultOptions new]];
    _optionsChain = optionsChain;
    
    return self;
}

#pragma mark - Properties -

- (nullable NSSet<S7TransportProtocolName> *)allowedTransportProtocols {
    for (id<S7OptionsProtocol> options in self.optionsChain) {
        NSSet<S7TransportProtocolName> *allowedTransportProtocols = options.allowedTransportProtocols;
        
        if (nil != allowedTransportProtocols) {
            return allowedTransportProtocols;
        }
    }
    
    NSAssert(NO, @"This should not happen. At least we should return default options.");
    return nil;
}

- (nullable id<S7FilterProtocol>)filter {
    for (id<S7OptionsProtocol> options in self.optionsChain) {
        const id<S7FilterProtocol> filter = options.filter;
        
        if (nil != filter) {
            return filter;
        }
    }
    
    return nil;
}

@end

NS_ASSUME_NONNULL_END
