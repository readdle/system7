//
//  S7InitCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7InitCommand : NSObject <S7Command>

@property (nonatomic, assign) BOOL installFakeHooks;
@property (nonatomic, assign) BOOL runFakeFilter;

+ (NSString *)bootstrapCommandLine;

@end

NS_ASSUME_NONNULL_END
