//
//  S7MergeStrategy.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 31.01.2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class S7Config;

@protocol S7MergeStrategy <NSObject>

- (S7Config *)mergeOurConfig:(S7Config *)ourConfig
                 theirConfig:(S7Config *)theirConfig
                  baseConfig:(S7Config *)baseConfig
            detectedConflict:(BOOL *)ppDetectedConflict;

@end

NS_ASSUME_NONNULL_END
