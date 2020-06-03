//
//  S7PostCheckoutHook.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Hook.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7PostCheckoutHook : NSObject <S7Hook>

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                  fromRevision:(NSString *)fromRevision
                    toRevision:(NSString *)toRevision;

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                    fromConfig:(S7Config *)fromConfig
                      toConfig:(S7Config *)toConfig;

+ (int)checkoutSubreposForRepo:(GitRepository *)repo
                    fromConfig:(S7Config *)fromConfig
                      toConfig:(S7Config *)toConfig
                         clean:(BOOL)clean;

@end

NS_ASSUME_NONNULL_END
