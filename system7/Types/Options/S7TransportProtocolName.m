//
//  S7TransportProtocolName.m
//  system7
//
//  Created by Andrew Podrugin on 26.11.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7TransportProtocolName.h"

NS_ASSUME_NONNULL_BEGIN

S7TransportProtocolName const S7TransportProtocolNameLocal = @"local";
S7TransportProtocolName const S7TransportProtocolNameSSH = @"ssh";
S7TransportProtocolName const S7TransportProtocolNameGit = @"git";
S7TransportProtocolName const S7TransportProtocolNameHTTP = @"http";
S7TransportProtocolName const S7TransportProtocolNameHTTPS = @"https";

NSSet<S7TransportProtocolName> *S7SupportedTransportProtocolNames(void) {
    static NSSet<S7TransportProtocolName> *supportedTransportProtocolNames = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        supportedTransportProtocolNames = [NSSet setWithObjects:
                                           S7TransportProtocolNameLocal,
                                           S7TransportProtocolNameSSH,
                                           S7TransportProtocolNameGit,
                                           S7TransportProtocolNameHTTP,
                                           S7TransportProtocolNameHTTPS,
                                           nil];
    });
    
    return supportedTransportProtocolNames;
}

static BOOL S7URLStringHasScheme(NSString *urlString, NSString *scheme) {
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:urlString];
    
    return [components.scheme isEqual:scheme];
}

static BOOL S7IsLocalURLString(NSString *urlString) {
    if (S7URLStringHasScheme(urlString, @"file")) {
        return YES;
    }
    
    return [urlString hasPrefix:@"/"] || [urlString hasPrefix:@"./"] || [urlString hasPrefix:@"../"];
}

static BOOL S7IsSSHURLString(NSString *urlString) {
    if (S7URLStringHasScheme(urlString, @"ssh")) {
        return YES;
    }
    
    const NSUInteger schemeSeparatorLocation = [urlString rangeOfString:@"://"].location;
    
    if (NSNotFound != schemeSeparatorLocation) {
        return NO;
    }

    const NSUInteger firstColonIndex = [urlString rangeOfString:@":"].location;
    
    if (NSNotFound == firstColonIndex) {
        return NO;
    }
    
    const NSUInteger slashLocationBeforeColon =
    [urlString rangeOfString:@"/" options:0 range:NSMakeRange(0, firstColonIndex)].location;
    
    return NSNotFound == slashLocationBeforeColon;
}

static BOOL S7IsGitURLString(NSString *urlString) {
    return S7URLStringHasScheme(urlString, @"git");
}

static BOOL S7IsHTTPURLString(NSString *urlString) {
    return S7URLStringHasScheme(urlString, @"http");
}

static BOOL S7IsHTTPSURLString(NSString *urlString) {
    return S7URLStringHasScheme(urlString, @"https");
}

BOOL S7URLStringMatchesTransportProtocolNames(NSString *urlString,
                                              NSSet<S7TransportProtocolName> *transportProtocolNames)
{
    if (0 == urlString.length || nil == transportProtocolNames) {
        NSCParameterAssert(urlString.length > 0);
        NSCParameterAssert(nil != transportProtocolNames);
        return NO;
    }
    
    NSDictionary<S7TransportProtocolName, NSValue *> *protocolToMethodMap =
    @{
        S7TransportProtocolNameLocal : [NSValue valueWithPointer:S7IsLocalURLString],
        S7TransportProtocolNameSSH : [NSValue valueWithPointer:S7IsSSHURLString],
        S7TransportProtocolNameGit : [NSValue valueWithPointer:S7IsGitURLString],
        S7TransportProtocolNameHTTP : [NSValue valueWithPointer:S7IsHTTPURLString],
        S7TransportProtocolNameHTTPS : [NSValue valueWithPointer:S7IsHTTPSURLString]
    };
    
    for (S7TransportProtocolName protocol in transportProtocolNames) {
        BOOL (*urlStringMatchesProtocol)(NSString *) = [protocolToMethodMap[protocol] pointerValue];

        if (urlStringMatchesProtocol(urlString)) {
            return YES;
        }
    }
    
    return NO;
}

NS_ASSUME_NONNULL_END
