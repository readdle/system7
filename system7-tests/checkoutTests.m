//
//  checkoutTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7InitCommand.h"
#import "S7AddCommand.h"
#import "S7CheckoutCommand.h"

@interface checkoutTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation checkoutTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7CheckoutCommand *command = [S7CheckoutCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7CheckoutCommand *command = [S7CheckoutCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        S7CheckoutCommand *command = [S7CheckoutCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
    });
}

- (void)testInitialCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        return 0;
    });

    executeInDirectory(self.env.nikRd2Repo.absolutePath, ^int{
        [self.env.nikRd2Repo pull];

        S7CheckoutCommand *command = [S7CheckoutCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        GitRepository *niksReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(niksReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [niksReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);
    });
}

- (void)testFurtherChangesCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        return 0;
    });

    __block NSString *nikCreatedReaddleLibRevision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *fileName = @"RDSystemInfo.h";
        NSCParameterAssert(0 == [readdleLibSubrepoGit createFile:fileName withContents:nil]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit add:@[ fileName ]]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit commitWithMessage:@"add system info"]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit getCurrentRevision:&nikCreatedReaddleLibRevision]);

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push();
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *pasteysReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(pasteysReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [pasteysReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(nikCreatedReaddleLibRevision, actualReaddleLibRevision);

        NSString *branchName = nil;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName];
        XCTAssertEqualObjects(branchName, @"master");
    }];
}

- (void)testCustomBranchCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        return 0;
    });

    NSString *customBranchName = @"feature/mac";

    __block NSString *nikCreatedReaddleLibRevision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *fileName = @"RDSystemInfo.h";
        NSCParameterAssert(0 == [readdleLibSubrepoGit checkoutNewLocalBranch:customBranchName]);
        // ^^^^^^^^^
        NSCParameterAssert(0 == [readdleLibSubrepoGit createFile:fileName withContents:nil]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit add:@[ fileName ]]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit commitWithMessage:@"add system info"]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit getCurrentRevision:&nikCreatedReaddleLibRevision]);

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push();
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *pasteysReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(pasteysReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [pasteysReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(nikCreatedReaddleLibRevision, actualReaddleLibRevision);

        NSString *branchName = nil;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName];
        XCTAssertEqualObjects(branchName, customBranchName);
    }];
}

- (void)testCheckoutSubrepoAtNotLatestRevisionOfBranch {
    __block NSString *expectedReaddleLibRevision = nil;
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        return 0;
    });

    __block NSString *readdleLibRevisionThatWeShouldCheckoutInRD2 = nil;
    __block NSString *readdleLibRevisionOnMasterPushedSeparately = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *fileName = @"RDSystemInfo.h";
        NSCParameterAssert(0 == [readdleLibSubrepoGit createFile:fileName withContents:nil]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit add:@[ fileName ]]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit commitWithMessage:@"add system info"]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit getCurrentRevision:&readdleLibRevisionThatWeShouldCheckoutInRD2]);

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        // make more changes to ReaddleLib, but commit and push them only to ReaddleLib repo
        NSCParameterAssert(0 == [readdleLibSubrepoGit createFile:fileName withContents:@"some changes"]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit add:@[ fileName ]]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit commitWithMessage:@"more changes"]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit getCurrentRevision:&readdleLibRevisionOnMasterPushedSeparately]);
        NSCParameterAssert(0 == [readdleLibSubrepoGit pushAll]);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        GitRepository *pasteysReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(pasteysReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [pasteysReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLibRevisionThatWeShouldCheckoutInRD2, actualReaddleLibRevision);

        NSString *branchName = nil;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName];
        XCTAssertEqualObjects(branchName, @"master");

        XCTAssertTrue([pasteysReaddleLibSubrepo isRevisionAvailable:readdleLibRevisionOnMasterPushedSeparately]);
    }];
}

- (void)testSubrepoIsRemovedByCheckoutIfOtherDevRemovedIt {
    NSString *typicalGitIgnoreContent =
    @".DS_Store\n"
     "*.pbxuser\n"
     "*.orig\n";

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        s7push();

        return 0;
    });

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"drop ReaddleLib"];

        s7push();
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7checkout();

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNil(parsedConfig.pathToDescriptionMap[@"Dependencies/ReaddleLib"]);
        
        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);
    }];
}

// abort if user has not pushed commits?
// нужно удалять если репа убрана из .s7substate
// test recursive
//
// надо обсудить clean мод. В гите легко отстрелить себе ногу. В случае если пользователь делает git checkout -- .
// или git reset --hard на главной репе, это значит, что он хочет сделать суть hg up -C. По-идее, тут надо дропнуть и все
// изм-я в сабрепах. HG это делает в два захода:
//    # first reset the index to unmark new files for commit, because
//    # reset --hard will otherwise throw away files added for commit,
//    # not just unmark them.
//    self._gitcommand([b'reset', b'HEAD'])
//    self._gitcommand([b'reset', b'--hard', b'HEAD'])

@end
