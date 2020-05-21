//
//  checkoutTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

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

- (void)testWithoutRequiredArgument {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7CheckoutCommand *command = [S7CheckoutCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"fromRev"]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"toRev"]]);
    }];
}

- (void)testWithTooManyArguments {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7CheckoutCommand *command = [S7CheckoutCommand new];
        const int exitStatus = [command runWithArguments:@[@"rev1", @"rev2", @"rev3!"]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, exitStatus);
    }];
}

- (void)testOnEmptyS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        S7CheckoutCommand *command = [S7CheckoutCommand new];
        const int exitStatus = [command runWithArguments:@[[GitRepository nullRevision], currentRevision]];
        XCTAssertEqual(0, exitStatus);
    }];
}

- (void)testInitialCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(0, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *niksReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(niksReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [niksReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);
    }];
}

- (void)testFurtherChangesCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    __block NSString *nikCreatedReaddleLibRevision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        nikCreatedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", nil, @"add system info");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

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
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    NSString *customBranchName = @"feature/mac";

    __block NSString *nikCreatedReaddleLibRevision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSCParameterAssert(0 == [readdleLibSubrepoGit checkoutNewLocalBranch:customBranchName]);
        // ^^^^^^^^^

        nikCreatedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", nil, @"add system info");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

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
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    __block NSString *readdleLibRevisionThatWeShouldCheckoutInRD2 = nil;
    __block NSString *readdleLibRevisionOnMasterPushedSeparately = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLibRevisionThatWeShouldCheckoutInRD2 = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", nil, @"add system info");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);

        // make more changes to ReaddleLib, but commit and push them only to ReaddleLib repo
        readdleLibRevisionOnMasterPushedSeparately = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"some changes", @"more changes");

        NSCParameterAssert(0 == [readdleLibSubrepoGit pushAll]);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

        GitRepository *pasteysReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(pasteysReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [pasteysReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLibRevisionThatWeShouldCheckoutInRD2, actualReaddleLibRevision);

        NSString *branchName = nil;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName];
        XCTAssertEqualObjects(branchName, @"master");

        XCTAssertTrue([pasteysReaddleLibSubrepo isRevisionAvailableLocally:readdleLibRevisionOnMasterPushedSeparately]);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testSubrepoIsRemovedByCheckoutIfOtherDevRemovedIt {
    NSString *typicalGitIgnoreContent =
    @".DS_Store\n"
     "*.pbxuser\n"
     "*.orig\n";

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"drop ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout(prevRevision, currentRevision);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNil(parsedConfig.pathToDescriptionMap[@"Dependencies/ReaddleLib"]);
        
        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);
    }];
}

- (void)testMainRepoBranchSwitch {
    // small note for future desperado programmers: if you are wondering why I do not use `git switch`.
    // `git switch` appeared in git version 2.23. At the moment of writing this code Apple Developer Tools
    // provides us with git 2.21. I don't want to force everyone to install the latest git with `brew`
    // or in any other way
    //

    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;

    __block NSString *pdfKit_pdfexpert_Revision = nil;

    __block NSString *readdleLib_documentsRevision = nil;
    __block NSString *sftp_documentsRevision = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        readdleLib_initialRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        pdfKit_pdfexpert_Revision = commit(pdfKitSubrepoGit, @"RDPDFPageContent.h", @"// NDA", @"add text reflow support");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up pdfkit"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo checkoutNewLocalBranch:@"release/documents-7.1.4"];

        GitRepository *sftpSubrepoGit = s7add(@"Dependencies/RDSFTPOnlineClient", self.env.githubRDSFTPRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add RDSFTP subrepo"];


        sftp_documentsRevision = commit(sftpSubrepoGit, @"RDSFTPOnlineClient.m", @"bugfix", @"fix DOC-1234 – blah-blah");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up sftp with fix to DOC-1234"];


        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        readdleLib_documentsRevision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo checkoutRemoteTrackingBranch:@"release/pdfexpert-7.3"];

        NSString *pdfexpertReleaseRevision = nil;
        [repo getCurrentRevision:&pdfexpertReleaseRevision];

        s7checkout(prevRevision, pdfexpertReleaseRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];

        {
            NSString *actualReaddleLibRevision = nil;
            [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
            XCTAssertEqualObjects(readdleLib_initialRevision, actualReaddleLibRevision);

            NSString *actualPDFKitRevision = nil;
            [pdfKitSubrepoGit getCurrentRevision:&actualPDFKitRevision];
            XCTAssertEqualObjects(pdfKit_pdfexpert_Revision, actualPDFKitRevision);

            XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/RDSFTPOnlineClient"]);
        }

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);


        [repo checkoutRemoteTrackingBranch:@"release/documents-7.1.4"];

        NSString *docsReleaseRevision = nil;
        [repo getCurrentRevision:&docsReleaseRevision];

        s7checkout(pdfexpertReleaseRevision, docsReleaseRevision);

        GitRepository *sftpSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDSFTPOnlineClient"];

        {
            NSString *actualReaddleLibRevision = nil;
            [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
            XCTAssertEqualObjects(readdleLib_documentsRevision, actualReaddleLibRevision);

            NSString *actualPDFKitRevision = nil;
            [pdfKitSubrepoGit getCurrentRevision:&actualPDFKitRevision];
            XCTAssertEqualObjects(pdfKit_initialRevision, actualPDFKitRevision);

            XCTAssertNotNil(sftpSubrepoGit);
            NSString *actualSFTPRevision = nil;
            [sftpSubrepoGit getCurrentRevision:&actualSFTPRevision];
            XCTAssertEqualObjects(sftp_documentsRevision, actualSFTPRevision);
        }

        actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}


// abort if user has not pushed commits?
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
// есть ли вообще какой-то хук на 'git reset'?
// если хук таки есть, то надо не войти в бесконечный цикл reset-hook-reset

@end
