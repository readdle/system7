//
//  postCheckoutHookTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 14.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"
#import "S7PostCheckoutHook.h"
#import "S7DeinitCommand.h"
#import "S7InitCommand.h"
#import "S7PostMergeHook.h"

@interface postCheckoutHookTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation postCheckoutHookTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7PostCheckoutHook *command = [S7PostCheckoutHook new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *masterRevision = nil;
        [repo getCurrentRevision:&masterRevision];

        S7PostCheckoutHook *command = [S7PostCheckoutHook new];
        const int exitStatus = [command runWithArguments:@[ masterRevision, masterRevision, @"1" ]];
        XCTAssertEqual(S7ExitCodeSuccess, exitStatus);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
    }];
}

- (void)testWithoutRequiredArgument {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7PostCheckoutHook *command = [S7PostCheckoutHook new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"fromRev"]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"toRev"]]);
    }];
}

- (void)testOnEmptyS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        S7PostCheckoutHook *command = [S7PostCheckoutHook new];
        const int exitStatus = [command runWithArguments:@[[GitRepository nullRevision], currentRevision, @"0"]];
        XCTAssertEqual(0, exitStatus);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
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
        BOOL dummy = NO;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName isDetachedHEAD:&dummy isEmptyRepo:&dummy];
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
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        XCTAssertEqual(0, [readdleLibSubrepoGit checkoutNewLocalBranch:customBranchName]);
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
        BOOL dummy = NO;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName isDetachedHEAD:&dummy isEmptyRepo:&dummy];
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
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLibRevisionThatWeShouldCheckoutInRD2 = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", nil, @"add system info");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);

        // make more changes to ReaddleLib, but commit and push them only to ReaddleLib repo
        readdleLibRevisionOnMasterPushedSeparately = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"some changes", @"more changes");

        XCTAssertEqual(0, [readdleLibSubrepoGit pushCurrentBranch]);
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
        BOOL dummy = NO;
        [pasteysReaddleLibSubrepo getCurrentBranch:&branchName isDetachedHEAD:&dummy isEmptyRepo:&dummy];
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
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);
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

- (void)testCheckoutThatDoesntTouchSubrepo {
    __block NSString *revisionWhereSubrepoWasAdded = nil;
    __block NSString *firstSubreposUnrelatedRevision = nil;
    __block NSString *secondSubreposUnrelatedRevision = nil;
    __block NSString *expectedReaddleLibRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&revisionWhereSubrepoWasAdded];

        firstSubreposUnrelatedRevision = commit(repo, @"file", @"uno", @"uno");
        secondSubreposUnrelatedRevision = commit(repo, @"file", @"dou", @"dou");

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo fetch];

        XCTAssertEqual(0, s7checkout([GitRepository nullRevision], revisionWhereSubrepoWasAdded));

        GitRepository *niksReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(niksReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [niksReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);

        XCTAssertEqual(0, s7checkout(revisionWhereSubrepoWasAdded, firstSubreposUnrelatedRevision));
        XCTAssertEqual(0, s7checkout(firstSubreposUnrelatedRevision, secondSubreposUnrelatedRevision));
    }];
}

- (void)testCheckoutBackToRevisionWhereSubrepoDidntExist {
    __block NSString *preSubreposUnrelatedRevision = nil;
    __block NSString *revisionWhereSubrepoWasAdded = nil;
    __block NSString *postSubreposUnrelatedRevision = nil;
    __block NSString *expectedReaddleLibRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        preSubreposUnrelatedRevision = commit(repo, @"file", @"uno", @"uno");

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&revisionWhereSubrepoWasAdded];

        postSubreposUnrelatedRevision = commit(repo, @"file", @"dou", @"dou");

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo fetch];

        XCTAssertEqual(0, s7checkout([GitRepository nullRevision], revisionWhereSubrepoWasAdded));

        GitRepository *niksReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(niksReaddleLibSubrepo);

        NSString *actualReaddleLibRevision = nil;
        [niksReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);

        XCTAssertEqual(0, s7checkout(revisionWhereSubrepoWasAdded, preSubreposUnrelatedRevision));
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        XCTAssertEqual(0, s7checkout(preSubreposUnrelatedRevision, postSubreposUnrelatedRevision));

        niksReaddleLibSubrepo = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(niksReaddleLibSubrepo);

        actualReaddleLibRevision = nil;
        [niksReaddleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);
    }];
}

- (void)testFileCheckoutFromOldRevision {
    // aka `git checkout OLD_REVISION -- file`
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *preSubreposUnrelatedRevision = commit(repo, @"file", @"uno", @"uno");

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *postSubreposUnrelatedRevision = commit(repo, @"file", @"dou", @"dou");

        S7PostCheckoutHook *hook = [S7PostCheckoutHook new];
        const int hookExitStatus = [hook runWithArguments:@[ postSubreposUnrelatedRevision,
                                                             preSubreposUnrelatedRevision,
                                                             @"0" // <--- emulate file checkout
                                                            ]];
        XCTAssertEqual(0, hookExitStatus);

        readdleLibSubrepoGit = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);
    }];
}

- (void)testCheckoutToDiscardFileChanges {
    // aka `git checkout -- file`
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        commit(repo, @"file", @"uno", @"uno");

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *postSubreposUnrelatedRevision = commit(repo, @"file", @"dou", @"dou");

        S7PostCheckoutHook *hook = [S7PostCheckoutHook new];
        const int hookExitStatus = [hook runWithArguments:@[ postSubreposUnrelatedRevision,
                                                             postSubreposUnrelatedRevision,
                                                             @"0" // <--- emulate file checkout
                                                            ]];
        XCTAssertEqual(0, hookExitStatus);

        readdleLibSubrepoGit = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);
    }];
}

- (void)testCheckoutS7ConfigFromOldRevision {
    // aka `git checkout OLD_REVISION -- .s7substate`
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *preSubreposUnrelatedRevision = commit(repo, @"file", @"uno", @"uno");

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
//        NSString *expectedReaddleLibRevision =
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");
        [readdleLibSubrepoGit pushCurrentBranch];

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *postSubreposUnrelatedRevision = commit(repo, @"file", @"dou", @"dou");

        // here user performs `git checkout OLD_REVISION -- .s7substate`
        [@"" writeToFile:S7ConfigFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7PostCheckoutHook *hook = [S7PostCheckoutHook new];
        const int hookExitStatus = [hook runWithArguments:@[ postSubreposUnrelatedRevision,
                                                             preSubreposUnrelatedRevision,
                                                             @"0" // <--- emulate file checkout
                                                            ]];
        XCTAssertEqual(0, hookExitStatus);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
    }];
}

- (void)testCheckoutToDiscardS7ConfigChanges {
    // aka `git checkout -- .s7substate`
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        // and here user changes his mind and makes
        // `git checkout -- .s7substate`
        [@"" writeToFile:S7ConfigFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7PostCheckoutHook *hook = [S7PostCheckoutHook new];
        const int hookExitStatus = [hook runWithArguments:@[ currentRevision,
                                                             currentRevision,
                                                             @"0" // <--- emulate file checkout
                                                            ]];
        XCTAssertEqual(0, hookExitStatus);

        // there's no way for s7 to hook to find out the previous .s7substate content
        // as we are running in `post-checkou`.
        // thus – abandond subrepo would be left intact and user would have to remove
        // it by hand
        //
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
    }];
}

- (void)testBranchSwitchWithUncommittedChangesInSubrepo {
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *readdleLib_pdfExpertRevision = nil;
    __block NSString *readdleLib_documentsRevision = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        readdleLib_initialRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        readdleLib_pdfExpertRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"math is hard");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up readdle lib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo checkoutNewLocalBranch:@"release/documents-7.1.4"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        [readdleLibSubrepoGit fetch];
        [readdleLibSubrepoGit checkoutNewLocalBranch:@"release/documents-7.1.4"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        readdleLib_documentsRevision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        S7Config *prevConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // make local changes in ReaddleLib ...
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        NSString *uncommittedSystemInfoContents = @"iPhoneX";
        [readdleLibSubrepoGit createFile:@"RDSystemInfo.h" withContents:uncommittedSystemInfoContents];

        // forget about it and try to switch to a different branch in rd2
        [repo checkoutRemoteTrackingBranch:@"release/pdfexpert-7.3"];

        NSString *pdfexpertReleaseRevision = nil;
        [repo getCurrentRevision:&pdfexpertReleaseRevision];

        XCTAssertNotEqual(0, s7checkout(prevRevision, pdfexpertReleaseRevision));

        // we cannot prevent rd2 update with post-checkout...
        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertNotEqualObjects(actualConfig, controlConfig);
        XCTAssertEqualObjects(prevConfig, controlConfig);

        // but our hook must prevent subrepo update
        readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        // ReaddleLib must stay at the same revision...
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLib_documentsRevision, actualReaddleLibRevision);

        NSString *RDSystemInfoContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDSystemInfo.h" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(RDSystemInfoContents, uncommittedSystemInfoContents);
    }];
}

- (void)testBranchSwitchWithUncommittedChangesInSubrepoUpdatesAllOtherSubrepoDespiteFailInOne {
    __block NSString *readdleLib_initialRevision = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        readdleLib_initialRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");
        s7add(@"Dependencies/RDSFTP", self.env.githubRDSFTPRepo.absolutePath);

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    __block NSString *expectedPdfKitRevision = nil;
    __block NSString *expectedSFTPRevision = nil;

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"math is hard");

        GitRepository *pdfKitRepo = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        expectedPdfKitRevision = commit(pdfKitRepo, @"RDPDFAnnotation.h", @"/AP /N", @"first");

        GitRepository *sftpRepo = [GitRepository repoAtPath:@"Dependencies/RDSFTP"];
        expectedSFTPRevision = commit(sftpRepo, @"main.m", @"public static void main", @"FTP – kaka");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        S7Config *prevConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // make local changes in ReaddleLib ...
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        NSString *uncommittedSystemInfoContents = @"iPhoneX";
        [readdleLibSubrepoGit createFile:@"RDSystemInfo.h" withContents:uncommittedSystemInfoContents];

        // forget about it and try to switch to a different branch in rd2
        [repo checkoutRemoteTrackingBranch:@"release/pdfexpert-7.3"];

        NSString *pdfexpertReleaseRevision = nil;
        [repo getCurrentRevision:&pdfexpertReleaseRevision];

        XCTAssertEqual(S7ExitCodeSubrepoHasLocalChanges, s7checkout(prevRevision, pdfexpertReleaseRevision));

        // we cannot prevent rd2 update with post-checkout...
        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertNotEqualObjects(actualConfig, controlConfig);
        XCTAssertEqualObjects(prevConfig, controlConfig);

        // but our hook must prevent subrepo update
        readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        // ReaddleLib must stay at the same revision...
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLib_initialRevision, actualReaddleLibRevision);

        NSString *RDSystemInfoContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDSystemInfo.h" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(RDSystemInfoContents, uncommittedSystemInfoContents);

        // other subrepos must update successfully despite failure in one subrepo
        //
        GitRepository *pdfKitRepo = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *actualPdfKitRevision = nil;
        [pdfKitRepo getCurrentRevision:&actualPdfKitRevision];
        XCTAssertEqualObjects(expectedPdfKitRevision, actualPdfKitRevision);

        GitRepository *sftpRepo = [GitRepository repoAtPath:@"Dependencies/RDSFTP"];
        NSString *actualSFTPRevision = nil;
        [sftpRepo getCurrentRevision:&actualSFTPRevision];
        XCTAssertEqualObjects(expectedSFTPRevision, actualSFTPRevision);
    }];
}

- (void)testBranchSwitchDoesNotRemoveSubrepoDirIfInContainsUncommittedLocalChanges {
    __block NSString *readdleLib_initialRevision = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        readdleLib_initialRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        S7Config *prevConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // make local changes in ReaddleLib ...
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        NSString *uncommittedSystemInfoContents = @"iPhoneX";
        [readdleLibSubrepoGit createFile:@"RDSystemInfo.h" withContents:uncommittedSystemInfoContents];

        // forget about it and try to switch to a different branch in rd2
        [repo checkoutRemoteTrackingBranch:@"release/pdfexpert-7.3"];

        NSString *pdfexpertReleaseRevision = nil;
        [repo getCurrentRevision:&pdfexpertReleaseRevision];

        XCTAssertEqual(0, s7checkout(prevRevision, pdfexpertReleaseRevision));

        // we cannot prevent rd2 update with post-checkout...
        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // unlike in case of update, we exit with success (0) and do not prevent contol config from update
        // user will see a warning and subrepo dir will be kept locally, it will also become untracked
        // as it's been removed from .gitignore
        //
        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
        XCTAssertNotEqualObjects(prevConfig, controlConfig);

        // but our hook must prevent subrepo update
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        // ReaddleLib must stay at the same revision...
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLib_initialRevision, actualReaddleLibRevision);

        NSString *RDSystemInfoContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDSystemInfo.h" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(RDSystemInfoContents, uncommittedSystemInfoContents);
    }];
}

- (void)testBranchSwitchDoesNotRemoveSubrepoDirIfInContainsUnpushedCommits {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        S7Config *prevConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // make local changes in ReaddleLib ...
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        NSString *committedSystemInfoContents = @"iPhoneX";
        NSString *expectedReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", committedSystemInfoContents, @"commit and forget to push");

        // forget about it and try to switch to a different branch in rd2
        [repo checkoutRemoteTrackingBranch:@"release/pdfexpert-7.3"];

        NSString *pdfexpertReleaseRevision = nil;
        [repo getCurrentRevision:&pdfexpertReleaseRevision];

        XCTAssertEqual(0, s7checkout(prevRevision, pdfexpertReleaseRevision));

        // we cannot prevent rd2 update with post-checkout...
        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // unlike in case of update, we exit with success (0) and do not prevent contol config from update
        // user will see a warning and subrepo dir will be kept locally, it will also become untracked
        // as it's been removed from .gitignore
        //
        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
        XCTAssertNotEqualObjects(prevConfig, controlConfig);

        // but our hook must prevent subrepo update
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        // ReaddleLib must stay at the same revision...
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(expectedReaddleLibRevision, actualReaddleLibRevision);

        NSString *RDSystemInfoContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDSystemInfo.h" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(RDSystemInfoContents, committedSystemInfoContents);
    }];
}

- (void)testSwitchToPreS7Branch {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *masterRevision = nil;
        [repo getCurrentRevision:&masterRevision];

        [repo checkoutNewLocalBranch:@"s7"];

        s7init_deactivateHooks();

        s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        s7push_currentBranch(repo);

        NSString *s7Revision = nil;
        [repo getCurrentRevision:&s7Revision];

        [repo checkoutExistingLocalBranch:@"master"];

        S7PostCheckoutHook *postCheckoutHook = [S7PostCheckoutHook new];
        [postCheckoutHook runWithArguments:@[s7Revision, masterRevision, @"1"]];

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);

        [repo checkoutExistingLocalBranch:@"s7"];

        postCheckoutHook = [S7PostCheckoutHook new];
        [postCheckoutHook runWithArguments:@[masterRevision, s7Revision, @"1"]];

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
    }];
}

- (void)testCheckoutClonesSubrepoEvenIfRemoteBranchIsDeleted {
    __block NSString *lastReboundReaddleLibRevision = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepo = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [readdleLibSubrepo checkoutNewLocalBranch:@"feature/god-forsaken-feature"];
        lastReboundReaddleLibRevision = commit(readdleLibSubrepo, @"File.c", @"new feature", @"new feature");

        s7rebind_with_stage();
        [repo commitWithMessage:@"switch ReaddleLib to feature/god-forsaken-feature"];

        s7push_currentBranch(repo);

        // merge pull request in ReaddleLib
        [readdleLibSubrepo checkoutExistingLocalBranch:@"master"];
        [readdleLibSubrepo mergeWith:@"feature/god-forsaken-feature"];
        [readdleLibSubrepo deleteLocalBranch:@"feature/god-forsaken-feature"];
        [readdleLibSubrepo deleteRemoteBranch:@"feature/god-forsaken-feature"];

        // and forget to rebind rd2 back to master of ReaddleLib...
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(S7ExitCodeSuccess, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *readdleLibSubrepo = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepo);

        BOOL dummy = NO;
        NSString *actualReaddleLibBranch = nil;
        [readdleLibSubrepo getCurrentBranch:&actualReaddleLibBranch isDetachedHEAD:&dummy isEmptyRepo:&dummy];
        XCTAssertEqualObjects(actualReaddleLibBranch, @"feature/god-forsaken-feature");
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepo getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, lastReboundReaddleLibRevision);
    }];
}

- (void)testSubrepoMigrationToNewHosting {
    int exitStatus = 0;
    GitRepository *bitbucketRepo = [GitRepository
                                    cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                    destinationPath:[self.env.root stringByAppendingPathComponent:@"bitbucket/ReaddleLib"]
                                    exitStatus:&exitStatus];
    XCTAssertNotNil(bitbucketRepo);
    XCTAssertEqual(0, exitStatus);

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepo = s7add_stage(@"Dependencies/ReaddleLib", bitbucketRepo.absolutePath);
        XCTAssertNotNil(readdleLibSubrepo);
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(S7ExitCodeSuccess, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *readdleLibSubrepo = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        GitRepository *readdleLibSubrepo = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        XCTAssertNotNil(readdleLibSubrepo);
        [repo commitWithMessage:@"migrate ReaddleLib subrepo from Bitbucket to GitHub"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(S7ExitCodeSuccess, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *readdleLibSubrepo = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepo);
        NSString *remoteUrl = nil;
        [readdleLibSubrepo getUrl:&remoteUrl];
        XCTAssertEqualObjects(remoteUrl, self.env.githubReaddleLibRepo.absolutePath);
    }];
}

- (void)testSubrepoMigrationToDifferentFork {
    GitRepository *airBnbLottie = [self.env initializeRemoteRepoAtRelativePath:@"github/airbnb/lottie-ios"];
    XCTAssertNotNil(airBnbLottie);

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *lottieSubrepo = s7add_stage(@"Dependencies/Thirdparty/lottie-ios", airBnbLottie.absolutePath);
        XCTAssertNotNil(lottieSubrepo);
        [repo commitWithMessage:@"add lottie subrepo"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(S7ExitCodeSuccess, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *lottieSubrepo = [GitRepository repoAtPath:@"Dependencies/Thirdparty/lottie-ios"];
        XCTAssertNotNil(lottieSubrepo);
    }];

    int exitStatus = 0;
    GitRepository *lottieReaddleForkRepo = [GitRepository
                                            cloneRepoAtURL:airBnbLottie.absolutePath
                                            branch:nil
                                            bare:YES
                                            destinationPath:[self.env.root stringByAppendingPathComponent:@"github/readdle/lottie-ios"]
                                            exitStatus:&exitStatus];
    NSAssert(lottieReaddleForkRepo, @"");
    XCTAssertEqual(0, exitStatus);

    __block NSString *customLottieFixRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/Thirdparty/lottie-ios");

        GitRepository *lottieSubrepo = s7add_stage(@"Dependencies/Thirdparty/lottie-ios", lottieReaddleForkRepo.absolutePath);
        XCTAssertNotNil(lottieSubrepo);
        [repo commitWithMessage:@"move to custom fork of lottie"];

        customLottieFixRevision = commit(lottieSubrepo, @"FilepathImageProvider.swift", @"fix", @"fix conflicting NSImage extension");
        s7rebind_with_stage();
        [repo commitWithMessage:@"fix conflicting NSImage extension in lottie"];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        XCTAssertEqual(S7ExitCodeSuccess, s7checkout([GitRepository nullRevision], currentRevision));

        GitRepository *lottieSubrepo = [GitRepository repoAtPath:@"Dependencies/Thirdparty/lottie-ios"];
        XCTAssertNotNil(lottieSubrepo);
        NSString *remoteUrl = nil;
        [lottieSubrepo getUrl:&remoteUrl];
        XCTAssertEqualObjects(remoteUrl, lottieReaddleForkRepo.absolutePath);

        NSString *lottieRevision = nil;
        [lottieSubrepo getCurrentRevision:&lottieRevision];
        XCTAssertEqualObjects(lottieRevision, customLottieFixRevision);
    }];
}

- (void)testCheckoutSameBrachAfterDeinit {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        // s7 init
        s7init_deactivateHooks();
        
        // git ci -am "init s7"
        [repo add:@[@"."]];
        [repo commitWithMessage:@"init s7"];
        NSString *revWithS7;
        [repo getCurrentRevision:&revWithS7];
        
        // s7 deinit
        S7DeinitCommand *command = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);
        
        // git ci -am "deinit s7"
        [repo add:@[@"."]];
        [repo commitWithMessage:@"deinit s7"];
        NSString *revWithoutS7;
        [repo getCurrentRevision:&revWithoutS7];
        
        // git push
        [repo pushCurrentBranch];
        
        // git checkout -B master HEAD~1
        [repo forceCheckoutLocalBranch:@"master" revision:revWithS7];
        XCTAssertEqual(S7ExitCodeSuccess, s7init_deactivateHooks());
        
        S7PostCheckoutHook *postCheckoutHook = [S7PostCheckoutHook new];
        int hookExitStatus = [postCheckoutHook runWithArguments:@[
            revWithoutS7,
            revWithS7,
            @"0"
        ]];
        XCTAssertEqual(S7ExitCodeSuccess, hookExitStatus);
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
        
        // git pull
        [repo pull];
        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        hookExitStatus = [postMergeHook runWithArguments:@[@"0"]];
        XCTAssertEqual(S7ExitCodeSuccess, hookExitStatus);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7substate"]);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
        
        // git checkout -B master HEAD~1
        [repo forceCheckoutLocalBranch:@"master" revision:revWithS7];
        XCTAssertEqual(S7ExitCodeSuccess, s7init_deactivateHooks());
        
        postCheckoutHook = [S7PostCheckoutHook new];
        hookExitStatus = [postCheckoutHook runWithArguments:@[
            revWithoutS7,
            revWithS7,
            @"0"
        ]];
        XCTAssertEqual(S7ExitCodeSuccess, hookExitStatus);
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
    }];
}

// there's no unit test for recursive checkout as it works on hooks
// and I don't want to rely on hooks (s7 version installed on test machine) in unit-tests,
// that's why recursive is tested by integration tests only

@end
