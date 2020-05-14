//
//  S7SubrepoDescription.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 09.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface S7SubrepoDescription : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *revision;
@property (nonatomic, readonly, nullable) NSString *branch;

- (instancetype)initWithPath:(NSString *)path
                         url:(NSString *)url
                    revision:(NSString *)revision
                      branch:(nullable NSString *)branch;

- (NSString *)stringRepresentation;
- (NSString *)humanReadableRevisionAndBranchState;

@end

NS_ASSUME_NONNULL_END
