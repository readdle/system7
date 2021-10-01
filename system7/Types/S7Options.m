//
//  S7Options.m
//  S7Options
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7Options.h"
#import "S7IniConfig.h"

NS_ASSUME_NONNULL_BEGIN

S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameLocal = @"local";
S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameSSH = @"ssh";
S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameGit = @"git";
S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameHTTP = @"http";
S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameHTTPS = @"https";

static NSString * const S7OptionsAddCommandSectionName = @"add";
static NSString * const S7OptionsAddCommandAllowedTransportProtocols = @"transport-protocols";


@interface S7Options()

@property (nonatomic, readonly) S7IniConfig *iniConfig;

@end

@implementation S7Options

#pragma mark - Synthesizers -

@synthesize allowedTransportProtocols = _allowedTransportProtocols;

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

+ (NSSet<S7OptionsTransportProtocolName> *)supportedTransportProtocols {
    static NSSet<S7OptionsTransportProtocolName> *supportedTransportProtocols = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        supportedTransportProtocols = [NSSet setWithObjects:
                                       S7OptionsTransportProtocolNameLocal,
                                       S7OptionsTransportProtocolNameSSH,
                                       S7OptionsTransportProtocolNameGit,
                                       S7OptionsTransportProtocolNameHTTP,
                                       S7OptionsTransportProtocolNameHTTPS,
                                       nil];
    });
    
    return supportedTransportProtocols;
}

- (NSSet<S7OptionsTransportProtocolName> *)allowedTransportProtocols {
    if (nil != _allowedTransportProtocols) {
        return _allowedTransportProtocols;
    }
    
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *iniDict = self.iniConfig.dictionaryRepresentation;
    NSString *allowedProtocolsString = iniDict[S7OptionsAddCommandSectionName][S7OptionsAddCommandAllowedTransportProtocols].lowercaseString;
    NSString *trimmedAllowedProtocolsString = [allowedProtocolsString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSArray<NSString *> *components = [trimmedAllowedProtocolsString componentsSeparatedByString:@","];
    
    if (0 == components.count) {
        _allowedTransportProtocols = self.class.supportedTransportProtocols;
        return _allowedTransportProtocols;
    }
    
    NSMutableArray<S7OptionsTransportProtocolName> *protocols = [NSMutableArray arrayWithCapacity:components.count];
    
    for (NSString *component in components) {
        [protocols addObject:[component stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    }
    
    NSMutableSet<S7OptionsTransportProtocolName> *unexpectedProtocols = [NSMutableSet setWithArray:protocols];
        
    [unexpectedProtocols minusSet:self.class.supportedTransportProtocols];
    if (unexpectedProtocols.count > 0) {
        NSMutableString *errorMessage =
        [NSMutableString stringWithFormat:@"error: unsupported transport protocol(s) detected during '%@' option parsing:",
         S7OptionsAddCommandAllowedTransportProtocols];
        
        for (S7OptionsTransportProtocolName protocol in unexpectedProtocols) {
            [errorMessage appendFormat:@" '%@'", protocol];
        }
        
        fprintf(stderr, "%s\n", [errorMessage cStringUsingEncoding:NSUTF8StringEncoding]);
        _allowedTransportProtocols = self.class.supportedTransportProtocols;
        return _allowedTransportProtocols;
    }
    
    _allowedTransportProtocols = [NSSet setWithArray:protocols];
    return _allowedTransportProtocols;
}

- (BOOL)urlStringMatchesAllowedTransportProtocols:(NSString *)urlString {
    NSDictionary<S7OptionsTransportProtocolName, NSValue *> *protocolToMethodMap =
    @{
        S7OptionsTransportProtocolNameLocal : [NSValue valueWithPointer:isLocalURLString],
        S7OptionsTransportProtocolNameSSH : [NSValue valueWithPointer:isSSHURLString],
        S7OptionsTransportProtocolNameGit : [NSValue valueWithPointer:isGitURLString],
        S7OptionsTransportProtocolNameHTTP : [NSValue valueWithPointer:isHTTPURLString],
        S7OptionsTransportProtocolNameHTTPS : [NSValue valueWithPointer:isHTTPSURLString]
    };
    
    for (S7OptionsTransportProtocolName protocol in self.allowedTransportProtocols) {
        BOOL (*urlStringMatchesProtocol)(NSString *) = [protocolToMethodMap[protocol] pointerValue];

        if (urlStringMatchesProtocol(urlString)) {
            return YES;
        }
    }
    
    return NO;
}

static BOOL isLocalURLString(NSString *urlString) {
    if (urlStringHasScheme(urlString, @"file")) {
        return YES;
    }
    
    return [urlString hasPrefix:@"/"] || [urlString hasPrefix:@"./"] || [urlString hasPrefix:@"../"];
}

static BOOL isSSHURLString(NSString *urlString) {
    if (urlStringHasScheme(urlString, @"ssh")) {
        return YES;
    }

    const NSInteger firstColonIndex = [urlString rangeOfString:@":"].location;
    
    if (NSNotFound == firstColonIndex) {
        return NO;
    }
    
    return NSNotFound == [urlString rangeOfString:@"/" options:0 range:NSMakeRange(0, firstColonIndex)].location;
}

static BOOL isGitURLString(NSString *urlString) {
    return urlStringHasScheme(urlString, @"git");
}

static BOOL isHTTPURLString(NSString *urlString) {
    return urlStringHasScheme(urlString, @"http");
}

static BOOL isHTTPSURLString(NSString *urlString) {
    return urlStringHasScheme(urlString, @"https");
}

static BOOL urlStringHasScheme(NSString *urlString, NSString *scheme) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:urlString];
    
    return [components.scheme isEqual:scheme];
}

@end

NS_ASSUME_NONNULL_END
