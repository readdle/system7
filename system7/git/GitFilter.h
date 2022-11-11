//
//  GitFilter.h
//  system7
//
//  Created by Danylo Safronov on 04.11.2022.
//  Copyright © 2022 Readdle. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GitFilter) {
    GitFilterUnspecified,
    GitFilterNone,
    GitFilterBlobNone
};

extern NSString * const kGitFilterBlobNone;

NS_ASSUME_NONNULL_END
