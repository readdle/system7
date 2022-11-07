//
//  S7IniConfigOptions.m
//  S7IniConfigOptions
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7IniConfigOptions.h"
#import "S7IniConfig.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const S7IniConfigOptionsAddCommandSectionName = @"add";
static NSString * const S7IniConfigOptionsAddCommandAllowedTransportProtocols = @"transport-protocols";
static NSString * const S7IniConfigOptionsGitCommandSectionName = @"git";
static NSString * const S7IniConfigOptionsGitCommandFilter = @"filter";

@interface S7IniConfigOptions()

@property (nonatomic, readonly) S7IniConfig *iniConfig;
@property (nonatomic, assign) BOOL areAllowedTransportProtocolsParsed;
@property (nonatomic, assign) BOOL areFilterParsed;

@end

@implementation S7IniConfigOptions

#pragma mark - Synthesizers -

@synthesize allowedTransportProtocols = _allowedTransportProtocols;
@synthesize filter = _filter;

#pragma mark - Initialization -

- (nullable instancetype)initWithContentsOfFile:(NSString *)filePath {
    if (0 == filePath.length) {
        NSParameterAssert(filePath.length > 0);
        return nil;
    }
    
    S7IniConfig *iniConfig = [S7IniConfig configWithContentsOfFile:filePath];
    
    return [self initWithIniConfig:iniConfig];
}

- (nullable instancetype)initWithIniConfig:(S7IniConfig *)iniConfig {
    if (nil == iniConfig) {
        NSParameterAssert(nil != iniConfig);
        return nil;
    }
    
    if (nil == (self = [super init])) {
        return nil;
    }
 
    _iniConfig = iniConfig;
    
    return self;
}

#pragma mark - Properties -

- (nullable NSSet<S7TransportProtocolName> *)allowedTransportProtocols {
    if (self.areAllowedTransportProtocolsParsed) {
        return _allowedTransportProtocols;
    }
    
    __auto_type handleParsingCompletion = ^(NSSet<S7TransportProtocolName> * _Nullable allowedTransportProtocols) {
        self.areAllowedTransportProtocolsParsed = YES;
        self->_allowedTransportProtocols = allowedTransportProtocols;
    };
    
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *iniDict = self.iniConfig.dictionaryRepresentation;
    NSString *allowedProtocolsString = iniDict[S7IniConfigOptionsAddCommandSectionName][S7IniConfigOptionsAddCommandAllowedTransportProtocols].lowercaseString;
    NSString *trimmedAllowedProtocolsString = [allowedProtocolsString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSArray<NSString *> *components = [trimmedAllowedProtocolsString componentsSeparatedByString:@","];
    
    if (0 == components.count) {
        handleParsingCompletion(nil);
        return nil;
    }
    
    NSMutableArray<S7TransportProtocolName> *protocols = [NSMutableArray arrayWithCapacity:components.count];
    
    for (NSString *component in components) {
        [protocols addObject:[component stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    }
    
    NSMutableSet<S7TransportProtocolName> *unexpectedProtocols = [NSMutableSet setWithArray:protocols];
        
    [unexpectedProtocols minusSet:S7SupportedTransportProtocolNames()];
    if (unexpectedProtocols.count > 0) {
        NSMutableString *errorMessage =
        [NSMutableString stringWithFormat:@"error: unsupported transport protocol(s) detected during '%@' option parsing:",
         S7IniConfigOptionsAddCommandAllowedTransportProtocols];
        
        for (S7TransportProtocolName protocol in unexpectedProtocols) {
            [errorMessage appendFormat:@" '%@'", protocol];
        }
        
        fprintf(stderr,
                "\033[31m"
                "%s\n"
                "\033[0m",
                [errorMessage cStringUsingEncoding:NSUTF8StringEncoding]);
        
        handleParsingCompletion(nil);
        return nil;
    }
    
    handleParsingCompletion([NSSet setWithArray:protocols]);
    return _allowedTransportProtocols;
}

- (GitFilter)filter {
    if (self.areFilterParsed) {
        return _filter;
    }
    
    NSDictionary<NSString*, NSDictionary<NSString*, NSString *> *> *iniDictionary = self.iniConfig.dictionaryRepresentation;
    NSString *filterValue = iniDictionary[S7IniConfigOptionsGitCommandSectionName][S7IniConfigOptionsGitCommandFilter].lowercaseString;
    
    if (filterValue == nil) {
        _filter = GitFilterUnspecified;
    }
    else {
        if ([filterValue isEqualToString:kGitFilterBlobNone]) {
            _filter = GitFilterBlobNone;
        }
        else {
            NSString *errorMessage =
            [NSString stringWithFormat:@"error: unsupported filter detected during '%@' option parsing.",
             S7IniConfigOptionsGitCommandFilter];
            
            fprintf(stderr,
                    "\033[31m"
                    "%s\n"
                    "\033[0m",
                    [errorMessage cStringUsingEncoding:NSUTF8StringEncoding]);
            
            _filter = GitFilterUnspecified;
        }
    }
    
    self.areFilterParsed = YES;
    return _filter;
}

@end

NS_ASSUME_NONNULL_END
