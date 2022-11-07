//
//  S7DefaultOptions.m
//  system7
//
//  Created by Andrew Podrugin on 26.11.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7DefaultOptions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S7DefaultOptions

#pragma mark - Properties -

- (nullable NSSet<S7TransportProtocolName> *)allowedTransportProtocols {
    return S7SupportedTransportProtocolNames();
}

- (GitFilter)filter {
    return GitFilterUnspecified;
}

@end

NS_ASSUME_NONNULL_END
