//
//  S7SubrepoDescription.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 09.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface S7SubrepoDescription : NSObject<NSCopying>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *revision;
@property (nonatomic, readonly) NSString *branch;

@property (nonatomic, nullable) NSString *comment;

@property (nonatomic, readonly) BOOL hasConflict;

- (instancetype)initWithConfigLine:(NSString *)trimmedLine;

- (instancetype)initWithPath:(NSString *)path
                         url:(NSString *)url
                    revision:(NSString *)revision
                      branch:(NSString *)branch NS_DESIGNATED_INITIALIZER;

- (NSString *)stringRepresentation;
- (NSString *)humanReadableRevisionAndBranchState;

- (BOOL)isEqual:(id)object ignoreBranches:(BOOL)shouldIgnoreBranches;

@end

NS_ASSUME_NONNULL_END
