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
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:S7OptionsFileName]) {
        [optionsChain addObject:[[S7IniConfigOptions alloc] initWithContentsOfFile:S7OptionsFileName]];
    }
    
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

@end

NS_ASSUME_NONNULL_END
