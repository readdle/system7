//
//  S7StatusCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

typedef NS_OPTIONS(NSUInteger, S7Status) {
    S7StatusUnchanged = 0,
    S7StatusAdded = (1 << 1),
    S7StatusRemoved = (1 << 2),
    S7StatusUpdatedAndRebound = (1 << 3),
    S7StatusDetachedHead = (1 << 4),
    S7StatusHasNotReboundCommittedChanges = (1 << 5),
    S7StatusHasUncommittedChanges = (1 << 6),
};

NS_ASSUME_NONNULL_BEGIN

@interface S7StatusCommand : NSObject <S7Command>

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSString *, NSNumber * /* S7Status */> * _Nullable __autoreleasing * _Nonnull)ppStatus;

@end

NS_ASSUME_NONNULL_END
