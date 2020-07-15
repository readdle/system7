//
//  S7AddCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

NS_ASSUME_NONNULL_BEGIN

@interface S7AddCommand : NSObject <S7Command>

// used by tests. This flag is passed-through to init command called on subrepos
// that are s7 repos themselves
@property (nonatomic, assign) BOOL installFakeHooks;

@end

NS_ASSUME_NONNULL_END
