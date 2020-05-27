//
//  S7StatusCommand.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

typedef NS_ENUM(NSInteger, S7Status) {
    S7StatusUnchanged,
    S7StatusAdded,
    S7StatusRemoved,
    S7StatusUpdatedAndRebound,
    S7StatusHasNotReboundCommittedChanges,
    S7StatusHasUncommittedChanges,
};

NS_ASSUME_NONNULL_BEGIN

@interface S7StatusCommand : NSObject <S7Command>

+ (int)repo:(GitRepository *)repo calculateStatus:(NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> * _Nullable __autoreleasing * _Nonnull)ppStatus;

@end

NS_ASSUME_NONNULL_END
