//
//  S7HashCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 12.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7HashCommand : NSObject <S7Command>

- (NSString *)calculateHash;

@end

NS_ASSUME_NONNULL_END
