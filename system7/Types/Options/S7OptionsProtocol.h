//
//  S7OptionsProtocol.h
//  system7
//
//  Created by Andrew Podrugin on 26.11.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S7TransportProtocolName.h"

NS_ASSUME_NONNULL_BEGIN

@protocol S7OptionsProtocol<NSObject>

@property (nonatomic, readonly, nullable) NSSet<S7TransportProtocolName> *allowedTransportProtocols;

@end

NS_ASSUME_NONNULL_END
