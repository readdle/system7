//
//  statusTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7StatusCommand.h"

#import "TestReposEnvironment.h"
#import "Utils.h"
#import "Git.h"

@interface statusTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation statusTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        const int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusAdded)
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusUpdatedAndRebound)
        };
        XCTAssertEqualObjects(status, expectedStatus);

        [repo commitWithMessage:@"up ReaddleLib"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });
    }];
}

- (void)testRemoveSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        s7remove(@"Dependencies/ReaddleLib");

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);

        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusRemoved)
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        [readdleLibSubrepoGit createFile:@"RDGeometry.h" withContents:@"let π=3.14;"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusHasUncommittedChanges)
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        [readdleLibSubrepoGit createFile:@"RDGeometry.h" withContents:@"let π=3.14;"];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusHasUncommittedChanges)
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π^e", @"Pi^e!");

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusHasNotReboundCommittedChanges)
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π", @"Pi!");

        s7rebind();

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"π^e", @"Pi^e!");

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusUpdatedAndRebound | S7StatusHasNotReboundCommittedChanges),
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

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        XCTAssertEqualObjects(status, @{ @"Dependencies/ReaddleLib" : @(S7StatusUnchanged) });

        [readdleLibSubrepoGit checkoutRevision:commit1];

        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(0, exitCode);
        XCTAssertNotNil(status);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/ReaddleLib" : @(S7StatusDetachedHead)
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

- (void)testSubreposNotInSync {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddleLib"];

        NSString *initialRevision = nil;
        [repo getCurrentRevision:&initialRevision];

        commit(subrepoGit, @"RDGeometry.h", @"sqrt", @"math");
        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo resetHardToRevision:initialRevision];

        XCTAssertFalse([NSFileManager.defaultManager contentsEqualAtPath:S7ConfigFileName andPath:S7ControlFileName]);

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(S7ExitCodeSubreposNotInSync, exitCode);
        XCTAssertNil(status);
    }];
}

- (void)testRecursive {
    int cloneExitStatus = 0;
    GitRepository *pdfKitRepo = [GitRepository cloneRepoAtURL:self.env.githubRDPDFKitRepo.absolutePath destinationPath:[self.env.root stringByAppendingPathComponent:@"pastey/rdpdfkit"] exitStatus:&cloneExitStatus];
    XCTAssertEqual(0, cloneExitStatus);
    XCTAssertNotNil(pdfKitRepo);

    __block NSString *expectedFormCalcRevision = nil;
    [pdfKitRepo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        [repo add:@[ @".gitattributes"] ];

        s7add_stage(@"Dependencies/FormCalc", self.env.githubFormCalcRepo.absolutePath);

        [repo commitWithMessage:@"add FormCalc subrepo"];

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        expectedFormCalcRevision = commit(formCalcSubrepoGit, @"Parser.c", @"AST", @"ast");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up FormCalc"];

        [formCalcSubrepoGit pushAllBranchesNeedingPush];
        [repo pushCurrentBranch];
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        NSDictionary<NSString *, NSNumber * /* S7Status */> *status = nil;
        int exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(S7ExitCodeSuccess, exitCode);
        NSDictionary<NSString *, NSNumber * /* S7Status */> *expectedStatus = @{
            @"Dependencies/RDPDFKit" : @(S7StatusAdded),
            @"Dependencies/RDPDFKit/Dependencies/FormCalc" : @(S7StatusUnchanged)
        };
        XCTAssertEqualObjects(status, expectedStatus);

        [repo commitWithMessage:@"add pdf kit subrepo"];

        status = nil;
        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(S7ExitCodeSuccess, exitCode);
        expectedStatus = @{
            @"Dependencies/RDPDFKit" : @(S7StatusUnchanged),
            @"Dependencies/RDPDFKit/Dependencies/FormCalc" : @(S7StatusUnchanged)
        };
        XCTAssertEqualObjects(status, expectedStatus);

        [formCalcSubrepoGit createFile:@"Kaka" withContents:@"rubbish"];

        status = nil;
        exitCode = [S7StatusCommand repo:repo calculateStatus:&status];
        XCTAssertEqual(S7ExitCodeSuccess, exitCode);
        expectedStatus = @{
            @"Dependencies/RDPDFKit" : @(S7StatusUnchanged),
            @"Dependencies/RDPDFKit/Dependencies/FormCalc" : @(S7StatusHasUncommittedChanges)
        };
        XCTAssertEqualObjects(status, expectedStatus);
    }];
}

@end
