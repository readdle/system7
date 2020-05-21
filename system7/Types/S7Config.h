//
//  S7Config.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class S7SubrepoDescription;

@interface S7Config : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithContentsString:(NSString *)configContents;
+ (nullable instancetype)configWithString:(NSString *)configContents;

- (nullable instancetype)initWithContentsOfFile:(NSString *)filePath;
- (instancetype)initWithSubrepoDescriptions:(NSArray<S7SubrepoDescription *> *)subrepoDescriptions;

+ (instancetype)emptyConfig;

@property (class) BOOL allowNon40DigitRevisions; // for tests only

@property (nonatomic, readonly) NSArray<S7SubrepoDescription *> *subrepoDescriptions;
@property (nonatomic, readonly) NSDictionary<NSString *, S7SubrepoDescription *> *pathToDescriptionMap;
@property (nonatomic, readonly) NSSet<NSString *> *subrepoPathsSet;

- (int)saveToFileAtPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
