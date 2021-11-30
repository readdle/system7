//
//  S7TransportProtocolName.h
//  system7
//
//  Created by Andrew Podrugin on 26.11.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// apodrugin@readdle.com
// Actually git also supports FTP/FTPS protocols, but they are deprecated
// (see https://git-scm.com/docs/git-clone#_git_urls). Thus these protocols
// are omitted in list.
typedef NSString *S7TransportProtocolName NS_EXTENSIBLE_STRING_ENUM;
extern S7TransportProtocolName const S7TransportProtocolNameLocal;
extern S7TransportProtocolName const S7TransportProtocolNameSSH;
extern S7TransportProtocolName const S7TransportProtocolNameGit;
extern S7TransportProtocolName const S7TransportProtocolNameHTTP;
extern S7TransportProtocolName const S7TransportProtocolNameHTTPS;

NSSet<S7TransportProtocolName> *S7SupportedTransportProtocolNames(void);
BOOL S7URLStringMatchesTransportProtocolNames(NSString *urlString,
                                              NSSet<S7TransportProtocolName> *transportProtocolNames);

NS_ASSUME_NONNULL_END
