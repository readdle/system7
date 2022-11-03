//
//  S7FilterBlobNone.h
//  system7
//
//  Created by Danylo Safronov on 03.11.2022.
//  Copyright © 2022 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S7FilterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const S7FilterBlobNoneKey;

@interface S7FilterBlobNone : NSObject<S7FilterProtocol>
@end

NS_ASSUME_NONNULL_END
