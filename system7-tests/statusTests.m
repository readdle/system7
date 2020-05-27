//
//  statusTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"
#import "S7StatusCommand.h"

#import "TestReposEnvironment.h"
#import "Utils.h"
#import "Git.h"

@interface statusTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation statusTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    
}

#pragma mark -

- (void)testCreate {
    S7StatusCommand *statusCommand = [S7StatusCommand new];
    XCTAssertNotNil(statusCommand);
}

- (void)testCheckStatusOnNonS7Repo {
    S7StatusCommand *statusCommand = [S7StatusCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [statusCommand runWithArguments:@[]]);
}

- (void)testStatusOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7StatusCommand *statusCommand = [S7StatusCommand new];
        XCTAssertEqual(0, [statusCommand runWithArguments:@[]]);
    });
}

- (void)testStatusOnDirtyEmptyMainRepo {
    // changes in main repo do not bother s7

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        [repo createFile:@"file" withContents:nil];
        [repo add:@[@"file"]];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        const int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        XCTAssertEqual(0, status.count);
    }];
}

- (void)testJustAddedSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        const int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusAdded) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testUpdatedSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        XCTAssertEqual(0, status.count);

        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusUpdatedAndRebound) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);

        [repo commitWithMessage:@"up ReaddleLib"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        XCTAssertEqual(0, status.count);
    }];
}

- (void)testRemoveSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        s7remove(@"Dependencies/ReaddleLib");

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusRemoved) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testUncommittedChangesInSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π", @"Pi!");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(@{}, status);

        [readdleLibSubrepoGit createFile:@"RDGeometry.h" withContents:@"let π=3.14;"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusHasUncommittedChanges) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testUnknownFileChangesInSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(@{}, status);

        [readdleLibSubrepoGit createFile:@"RDGeometry.h" withContents:@"let π=3.14;"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusHasUncommittedChanges) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testCommittedNotReboundChangesInSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(@{}, status);

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π^e", @"Pi^e!");

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusHasNotReboundCommittedChanges) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testBothReboundAndNotReboundChangesInSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(@{}, status);

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π", @"Pi!");

        s7rebind();

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π^e", @"Pi^e!");

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusUpdatedAndRebound) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]],
            @(S7StatusHasNotReboundCommittedChanges) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]]
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testSubrepoAtDetachedHead {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *commit1 = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"one", @"commit 1");
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"two", @"commit 2");

        s7rebind();
        
        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(@{}, status);

        [readdleLibSubrepoGit checkoutRevision:commit1];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSNumber * /* S7Status */, NSSet<NSString *> *> *expectedStatus = @{
            @(S7StatusDetachedHead) : [NSSet setWithArray:@[ @"Dependencies/ReaddleLib" ]],
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

@end
