//
//  gitPackedRefsTests.m
//  system7-tests
//
//  Created by Nik Savko on 11.03.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

@interface gitPackedRefsTests : XCTestCase

@property (nonatomic, strong) TestReposEnvironment *env;

@end

@implementation gitPackedRefsTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)packRefsInRepo:(GitRepository *)repo {
    [repo runGitCommand:@"pack-refs --all"];
    [repo runGitCommand:@"gc"];
}

- (void)testCurrentRevision {
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *revision1;
        XCTAssertEqual([repo getCurrentRevision:&revision1], 0);
        XCTAssertNotNil(revision1);
        XCTAssertNotEqualObjects(revision1, [GitRepository nullRevision]);
        
        [self packRefsInRepo:repo];
        
        NSString *revision2;
        XCTAssertEqual([repo getCurrentRevision:&revision2], 0);
        XCTAssertEqualObjects(revision1, revision2);
    }];
}

- (void)testCurrentBranch {
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        BOOL noop;
        
        NSString *branch1;
        [repo getCurrentBranch:&branch1 isDetachedHEAD:&noop isEmptyRepo:&noop];
        XCTAssertNotNil(branch1);
        XCTAssertEqualObjects(branch1, @"master");
        
        [self packRefsInRepo:repo];
        
        NSString *branch2;
        [repo getCurrentBranch:&branch2 isDetachedHEAD:&noop isEmptyRepo:&noop];
        XCTAssertEqualObjects(branch1, branch2);
    }];
}

- (void)testIsEmptyRepo {
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        XCTAssertFalse(repo.isEmptyRepo);
        [self packRefsInRepo:repo];
        XCTAssertFalse(repo.isEmptyRepo);
    }];
}

- (void)testIsBareCloneEmpty {
    NSString *const remoteRepoPath = [self.env.root stringByAppendingPathComponent:@"empty-repo.remote"];
    NSString *const repoPath = [self.env.root stringByAppendingPathComponent:@"empty-repo.local"];
    int exitStatus = 0;
    XCTAssertNotNil([GitRepository initializeRepositoryAtPath:remoteRepoPath
                                                         bare:YES
                                            defaultBranchName:NULL
                                                   exitStatus:&exitStatus]);
    XCTAssertEqual(exitStatus, 0);
    
    GitRepository *const repo = [GitRepository cloneRepoAtURL:remoteRepoPath destinationPath:repoPath exitStatus:&exitStatus];
    XCTAssertTrue(repo.isEmptyRepo);
    
    [self packRefsInRepo:repo];
    XCTAssertTrue(repo.isEmptyRepo);
}

@end
