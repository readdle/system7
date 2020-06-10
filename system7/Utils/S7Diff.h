//
//  S7Diff.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 08.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class S7Config;
@class S7SubrepoDescription;

int diffConfigs(S7Config *fromConfig,
                S7Config *toConfig,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToDelete,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToUpdate,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToAdd);

NS_ASSUME_NONNULL_END
