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

// apodrugin@readdle.com
// We can't use path with tilde (i.e. '~/.s7options'), because when 's7' is run using 'sudo', then
// tilde expansion using -[NSString stringByExpandingTildeInPath] works incorrectly
// and returns '/var/root' instead of current user home directory.
// NSHomeDirectory() also doesn't work.
#define S7GlobalOptionsFilePath [[NSString stringWithUTF8String:getenv("HOME")] stringByAppendingPathComponent:S7OptionsFileName]
NSString * const S7SystemOptionsFilePath = @"/etc/s7options";


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
        if ([[NSFileManager defaultManager] fileExistsAtPath:iniOptionsFilePath]) {
            [optionsChain addObject:[[S7IniConfigOptions alloc] initWithContentsOfFile:iniOptionsFilePath]];
        }
    };

    addIniConfigOptionsIfPossible(S7OptionsFileName);
    addIniConfigOptionsIfPossible(S7GlobalOptionsFilePath);
    addIniConfigOptionsIfPossible(S7SystemOptionsFilePath);
    
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
