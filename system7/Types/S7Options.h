//
//  S7Options.h
//  S7Options
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class S7IniConfig;

// apodrugin@readdle.com
// Actually git also supports FTP/FTPS protocols, but they are deprecated
// (see https://git-scm.com/docs/git-clone#_git_urls). Thus these protocols
// are omitted in list.
typedef NSString *S7OptionsTransportProtocolName NS_EXTENSIBLE_STRING_ENUM;
extern S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameLocal;
extern S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameSSH;
extern S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameGit;
extern S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameHTTP;
extern S7OptionsTransportProtocolName const S7OptionsTransportProtocolNameHTTPS;

@interface S7Options : NSObject

@property (nonatomic, readonly) NSSet<S7OptionsTransportProtocolName> *allowedTransportProtocols;

@property (nonatomic, class, readonly) NSSet<S7OptionsTransportProtocolName> *supportedTransportProtocols;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithContentsOfFile:(NSString *)filePath;
- (nullable instancetype)initWithIniConfig:(S7IniConfig *)iniConfig NS_DESIGNATED_INITIALIZER;

- (BOOL)urlStringMatchesAllowedTransportProtocols:(NSString *)urlString;

@end

NS_ASSUME_NONNULL_END
