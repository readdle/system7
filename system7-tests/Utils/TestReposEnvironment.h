//
//  TestReposEnvironment.h
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GitRepository;

@interface TestReposEnvironment : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTestCaseName:(NSString *)testCaseName;

@property (nonatomic, readonly, strong) NSString *root;

@property (nonatomic, readonly, strong) GitRepository *githubRd2Repo;
@property (nonatomic, readonly, strong) GitRepository *githubReaddleLibRepo;
@property (nonatomic, readonly, strong) GitRepository *githubRDSFTPRepo;
@property (nonatomic, readonly, strong) GitRepository *githubRDPDFKitRepo;
@property (nonatomic, readonly, strong) GitRepository *githubFormCalcRepo;
@property (nonatomic, readonly, strong) GitRepository *githubTestBareRepo;

@property (nonatomic, readonly, strong) GitRepository *pasteyRd2Repo;
@property (nonatomic, readonly, strong) GitRepository *nikRd2Repo;

- (GitRepository *)initializeRemoteRepoAtRelativePath:(NSString *)relativePath;

- (void)touch:(NSString *)filePath;
- (void)makeDir:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
