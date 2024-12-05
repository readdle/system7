//
//  mergeDriverTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 07.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#include <stdlib.h>

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7ConfigMergeDriver.h"

// all hook calls in these tests are pure simulation
#import "S7PostMergeHook.h"
#import "S7PostCommitHook.h"
#import "S7PrepareCommitMsgHook.h"
#import "S7DeinitCommand.h"
#import "S7PostCheckoutHook.h"

#import "S7RebindCommand.h"
#import "S7CheckoutCommand.h"

#import "S7SubrepoDescriptionConflict.h"


@interface mergeDriverTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation mergeDriverTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
    }];
}

- (void)tearDown {
    unsetenv("S7_MERGE_DRIVER_INTERMEDIATE_BRANCH");
    unsetenv("S7_MERGE_DRIVER_KEEP_TARGET_BRANCH");
    unsetenv("S7_MERGE_DRIVER_RESPONSE");
}

#pragma mark -

- (void)testMergeDriverWithMissingRequiredArguments {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        S7ConfigMergeDriver *mergeDriver = [S7ConfigMergeDriver new];
        const int exitStatus = [mergeDriver runWithArguments:@[ @"one", @"two" ]];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, exitStatus);
    }];
}

- (void)testSuccessfullDifferentBranchesNonConflictMerge {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *initialReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&initialReaddleLibRevision];

        NSString *initialRD2Revision = nil;
        [repo getCurrentRevision:&initialRD2Revision];



        [repo checkoutNewLocalBranch:@"experiment"];

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        NSString *readdleLibExperimentalCommit = commit(readdleLibGit, @"file", @"contents", @"test commit");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *experimentBranchRD2Revision = nil;
        [repo getCurrentRevision:&experimentBranchRD2Revision];



        [repo checkoutExistingLocalBranch:@"main"];

        s7checkout(experimentBranchRD2Revision, initialRD2Revision);

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        NSString *actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(initialReaddleLibRevision, actualReaddleLibRevision);

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        [repo mergeWith:@"experiment"];

        // config merge driver won't be called in this case, as the config has been changed at one side only

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(readdleLibExperimentalCommit, actualReaddleLibRevision);
    }];
}

- (void)testSameBranchMergeWithoutConflicts {
    __block S7Config *baseConfig = nil;
    __block S7Config *niksConfig = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    __block NSString *pdfKit_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];

        pdfKit_niks_Revision = commit(pdfKitSubrepoGit, @"RDPDFPageContent.h", @"// NDA", @"add text reflow support");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up pdfkit"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();

        // just to show that in case of non-merge commit this hook doesn't do anything
        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[]]);

        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        // aka [repo merge];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        const int mergeExitStatus = [configMergeDriver mergeRepo:repo baseConfig:baseConfig ourConfig:ourConfig theirConfig:niksConfig saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKit_niks_Revision, pdfKitActualRevision);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        XCTAssertEqualObjects(readdleLib_pasteys_Revision, readdleLibActualRevision);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testSimplePull {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        S7Config *niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(baseConfig, niksConfig);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];

        XCTAssertEqualObjects(readdleLibActualRevision, readdleLib_initialRevision);
    }];
}

- (void)testMergeWithoutConflicts {
    __block S7Config *baseConfig = nil;
    __block S7Config *niksConfig = nil;

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    __block NSString *pdfKit_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];

        pdfKit_niks_Revision = commit(pdfKitSubrepoGit, @"RDPDFPageContent.h", @"// NDA", @"add text reflow support");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up pdfkit"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        // aka [repo merge];

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        const int mergeExitStatus = [configMergeDriver mergeRepo:repo baseConfig:baseConfig ourConfig:ourConfig theirConfig:niksConfig saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKit_niks_Revision, pdfKitActualRevision);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        XCTAssertEqualObjects(readdleLib_pasteys_Revision, readdleLibActualRevision);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testPullWithConflictInUnrelatedFile {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        commit(repo, @"best-band", @"rhcp", @"... little ant, checking out this and that");

        s7push_currentBranch(repo);
    }];

    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        commit(repo, @"best-band", @"metallica", @"Sleep with one eye open, Gripping your pillow tight");

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        commit(repo, @"best-band", @"nirvana", @"Where do bad folks go when they die? They don't go to heaven where the angels fly");

        XCTAssertNotEqual(0, s7push_currentBranch(repo), @"nik has pushed");

        [repo pull];

        // conflict in an innocent-file. No hooks would be called. Resolve conflict, add file and commit.
        // and it's only here when the post-commit hook would get called.

        XCTAssertTrue([@"U2" writeToFile:@"best-band" atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        [repo add:@[@"best-band"]];
        XCTAssertEqual(0, [repo commitWithMessage:@"merge"]);

        S7CheckoutCommand *checkoutCommand = [S7CheckoutCommand new];
        XCTAssertEqual(0, [checkoutCommand runWithArguments:@[]]);

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostCommitHook *postCommitHook = [S7PostCommitHook new];
        XCTAssertEqual(0, [postCommitHook runWithArguments:@[]]);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLib_niks_Revision);
    }];
}

- (void)testPostCommitHookDoesNothingOnSimpleCommit {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        commit(repo, @"file", @"asdf", @"test");

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[]]);

        S7PostCommitHook *postCommitHook = [S7PostCommitHook new];
        __block BOOL hookTriedToUpdatedSubrepos = NO;
        postCommitHook.hookWillUpdateSubrepos = ^{
            hookTriedToUpdatedSubrepos = YES;
        };

        XCTAssertEqual(0, [postCommitHook runWithArguments:@[]]);
        XCTAssertFalse(hookTriedToUpdatedSubrepos);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_Merge {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *expectedSystemInfoContents = @"iPad 11''";
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", expectedSystemInfoContents, @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        __block int callNumber = 0;
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
//            possibleOptions:
//                S7ConflictResolutionOptionKeepLocal | S7ConflictResolutionOptionKeepRemote | S7ConflictResolutionOptionMerge;

            ++callNumber;

            if (callNumber > 1) {
                // it keeps asking us?
                XCTFail(@"");
            }

            return S7ConflictResolutionOptionMerge;
         }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        XCTAssertEqual(1, callNumber, @"we played a fool several times, but then responded with a valid value – `merge`");

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);


        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        int gitExitStatus = 0;
        NSString *actualGeometryContents = [readdleLibSubrepoGit showFile:@"RDGeometry.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualGeometryContents, expectedRDGeometryContents);

        NSString *actualSystemInfoContents = [readdleLibSubrepoGit showFile:@"RDSystemInfo.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualSystemInfoContents, expectedSystemInfoContents);

        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_niks_Revision toRevision:readdleLibActualRevision]);
        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_pasteys_Revision toRevision:readdleLibActualRevision]);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepConflict {
    __block S7Config *baseConfig = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        // ReaddleLib will conflict and two other will have to merge well
        s7add(@"Dependencies/RDSFTP", self.env.githubRDSFTPRepo.absolutePath);
        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    __block NSString *sftp_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"xyz", @"some useful math func");

        GitRepository *sftpSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDSFTP"];
        XCTAssertNotNil(sftpSubrepoGit);

        sftp_niks_Revision = commit(sftpSubrepoGit, @"RDSFTP.h", @"ssh2 request", @"some usuful code");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib and RDSFTP"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLib_pasteys_Revision =
            commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        GitRepository *pdfkitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfkit_pasteys_Revision = commit(pdfkitSubrepoGit, @"RDPDFAnnotation.h", @"AP/N", @"generate AP/N");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib and RDPDFKit"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];

        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");

            return S7ConflictResolutionOptionKeepConflict;
         }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertNotEqual(0, mergeExitStatus);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/RDSFTP"
             url:self.env.githubRDSFTPRepo.absolutePath
             revision:sftp_niks_Revision
             branch:@"main"],

            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/RDPDFKit"
             url:self.env.githubRDPDFKitRepo.absolutePath
             revision:pdfkit_pasteys_Revision
             branch:@"main"],

            [[S7SubrepoDescriptionConflict alloc]
             initWithOurVersion:[[S7SubrepoDescription alloc] 
                                 initWithPath:@"Dependencies/ReaddleLib"
                                 url:self.env.githubReaddleLibRepo.absolutePath
                                 revision:readdleLib_pasteys_Revision
                                 branch:@"main"]
             theirVersion:[[S7SubrepoDescription alloc]
                           initWithPath:@"Dependencies/ReaddleLib"
                           url:self.env.githubReaddleLibRepo.absolutePath
                           revision:readdleLib_niks_Revision
                           branch:@"main"]]
        ]];

        XCTAssertEqualObjects(actualConfig, expectedConfig);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);

        NSString *readdleLibSubrepoRevision = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&readdleLibSubrepoRevision]);
        XCTAssertEqualObjects(readdleLibSubrepoRevision, readdleLib_pasteys_Revision);

        NSString *pdfkitSubrepoRevision = nil;
        XCTAssertEqual(0, [pdfkitSubrepoGit getCurrentRevision:&pdfkitSubrepoRevision]);
        XCTAssertEqualObjects(pdfkitSubrepoRevision, pdfkit_pasteys_Revision);

        GitRepository *sftpSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDSFTP"];
        NSString *sftpSubrepoRevision = nil;
        XCTAssertEqual(0, [sftpSubrepoGit getCurrentRevision:&sftpSubrepoRevision]);
        XCTAssertEqualObjects(sftpSubrepoRevision, sftp_niks_Revision);
    }];
}

- (void)testTheirAddNewSubrepoBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepConflict {
    __block S7Config *baseConfig = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    __block NSString *rdpdfKitLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"xyz", @"some useful math func");

        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);

        GitRepository *rdpdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        XCTAssertEqual(0, [rdpdfKitSubrepoGit getCurrentRevision:&rdpdfKitLib_niks_Revision]);

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib and RDSFTP"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLib_pasteys_Revision =
            commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib and RDPDFKit"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];

        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");

            return S7ConflictResolutionOptionKeepConflict;
         }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertNotEqual(0, mergeExitStatus);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescriptionConflict alloc]
             initWithOurVersion:[[S7SubrepoDescription alloc]
                                 initWithPath:@"Dependencies/ReaddleLib"
                                 url:self.env.githubReaddleLibRepo.absolutePath
                                 revision:readdleLib_pasteys_Revision
                                 branch:@"main"]
             theirVersion:[[S7SubrepoDescription alloc]
                           initWithPath:@"Dependencies/ReaddleLib"
                           url:self.env.githubReaddleLibRepo.absolutePath
                           revision:readdleLib_niks_Revision
                           branch:@"main"]],

            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/RDPDFKit"
             url:self.env.githubRDPDFKitRepo.absolutePath
             revision:rdpdfKitLib_niks_Revision
             branch:@"main"]
        ]];

        XCTAssertEqualObjects(actualConfig, expectedConfig);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);

        // Test ReaddleLib has merge conflict and subrepo is set to local revision.
        NSString *readdleLibSubrepoRevision = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&readdleLibSubrepoRevision]);
        XCTAssertEqualObjects(readdleLibSubrepoRevision, readdleLib_pasteys_Revision);

        // Test RDPDFKit has been checked out and points to 'their' revision.
        GitRepository *pdfkitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfkitSubrepoRevision = nil;
        XCTAssertEqual(0, [pdfkitSubrepoGit getCurrentRevision:&pdfkitSubrepoRevision]);
        XCTAssertEqualObjects(pdfkitSubrepoRevision, rdpdfKitLib_niks_Revision);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionSameFileSubrepoConflictResolution_Merge {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *niksRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", niksRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        NSString *pasteysRDGeometryContents = @"sqrt";
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", pasteysRDGeometryContents, @"sqrt");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
//            possibleOptions:
//                S7ConflictResolutionOptionKeepLocal | S7ConflictResolutionOptionKeepRemote | S7ConflictResolutionOptionMerge;

            return S7ConflictResolutionOptionMerge;
         }];

        XCTAssertNotEqual(0, [repo merge]);

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(S7ExitCodeMergeFailed, mergeExitStatus);

        __block NSString *mergedReaddleLibRevision = nil;
        NSString *mergedRDGeometryContents = @"xyz\nsqrt\n";
        [readdleLibSubrepoGit run:^(GitRepository * _Nonnull subrepo) {
            // resolve conflict
            [subrepo createFile:@"RDGeometry.h" withContents:mergedRDGeometryContents];
            [subrepo add:@[@"RDGeometry.h"]];
            [subrepo commitWithMessage:@"merge"];
            [subrepo getCurrentRevision:&mergedReaddleLibRevision];
        }];

        NSString *configFileContents = [[NSString alloc] initWithContentsOfFile:S7ConfigFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue([configFileContents containsString:@"<<<"], @"must contain conflict");

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[ @"--stage" ]]);

        S7Config *expectedMergedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib"
                                                   url:self.env.githubReaddleLibRepo.absolutePath
                                              revision:mergedReaddleLibRevision
                                                branch:@"main"]
        ]];

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(expectedMergedConfig, actualConfig);

        [repo commitWithMessage:@"merge"];

        S7PrepareCommitMsgHook *prepareCommitHook = [S7PrepareCommitMsgHook new];
        XCTAssertEqual(0, [prepareCommitHook runWithArguments:@[ @"merge" ]]);

        S7PostCommitHook *postCommitHook = [S7PostCommitHook new];
        XCTAssertEqual(0, [postCommitHook runWithArguments:@[]]);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        int gitExitStatus = 0;
        NSString *actualGeometryContents = [readdleLibSubrepoGit showFile:@"RDGeometry.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualGeometryContents, mergedRDGeometryContents);

        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_niks_Revision toRevision:readdleLibActualRevision]);
        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_pasteys_Revision toRevision:readdleLibActualRevision]);

        actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);

        XCTAssertEqualObjects(readdleLibActualRevision, mergedReaddleLibRevision);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepLocal {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *expectedSystemInfoContents = @"iPad 11''";
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", expectedSystemInfoContents, @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                               S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
//            possibleOptions:
//                S7ConflictResolutionOptionKeepLocal | S7ConflictResolutionOptionKeepRemote | S7ConflictResolutionOptionMerge;

            return S7ConflictResolutionOptionKeepLocal;
        }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);


        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];

        XCTAssertEqualObjects(readdleLib_pasteys_Revision, readdleLibActualRevision);

        NSString *readdleLibActualBranch = nil;
        BOOL dummy = NO;
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch isDetachedHEAD:&dummy isEmptyRepo:&dummy];
        XCTAssertEqualObjects(@"main", readdleLibActualBranch);

        int gitExitStatus = 0;
        NSString *actualGeometryContents = [readdleLibSubrepoGit showFile:@"RDGeometry.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(128, gitExitStatus);
        XCTAssert(0 == actualGeometryContents.length);

        NSString *actualSystemInfoContents = [readdleLibSubrepoGit showFile:@"RDSystemInfo.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualSystemInfoContents, expectedSystemInfoContents);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepRemote {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *expectedSystemInfoContents = @"iPad 11''";
        commit(readdleLibSubrepoGit, @"RDSystemInfo.h", expectedSystemInfoContents, @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                               S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
//            possibleOptions:
//                S7ConflictResolutionOptionKeepLocal | S7ConflictResolutionOptionKeepRemote | S7ConflictResolutionOptionMerge;

            return S7ConflictResolutionOptionKeepRemote;
        }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);


        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];

        XCTAssertEqualObjects(readdleLib_niks_Revision, readdleLibActualRevision);

        NSString *readdleLibActualBranch = nil;
        BOOL dummy = NO;
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch isDetachedHEAD:&dummy isEmptyRepo:&dummy];
        XCTAssertEqualObjects(@"main", readdleLibActualBranch);

        int gitExitStatus = 0;
        NSString *actualGeometryContents = [readdleLibSubrepoGit showFile:@"RDGeometry.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualGeometryContents, expectedRDGeometryContents);

        NSString *actualSystemInfoContents = [readdleLibSubrepoGit showFile:@"RDSystemInfo.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(128, gitExitStatus);
        XCTAssert(0 == actualSystemInfoContents.length);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testOneSideUpdateOtherSideDeleteConflictResolution_Delete {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepo"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                               S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertNil(ourVersion);
            XCTAssertEqualObjects(theirVersion.path, @"Dependencies/ReaddleLib");

//            possibleOptions:
//                S7ConflictResolutionOptionKeepChanged | S7ConflictResolutionOptionDelete;

            return S7ConflictResolutionOptionDelete;
        }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);


        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(parsedConfig);
        XCTAssertEqual(1, parsedConfig.subrepoDescriptions.count);

        XCTAssertEqualObjects(parsedConfig.subrepoDescriptions[0].path, @"Dependencies/RDPDFKit");

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKitActualRevision, pdfKit_initialRevision);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testOneSideUpdateOtherSideDeleteConflictResolution_KeepChanged {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepo"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                               S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertNil(ourVersion);
            XCTAssertEqualObjects(theirVersion.path, @"Dependencies/ReaddleLib");

//            possibleOptions:
//                S7ConflictResolutionOptionKeepChanged | S7ConflictResolutionOptionDelete;

            return S7ConflictResolutionOptionKeepChanged;
        }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);


        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(parsedConfig);

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:self.env.githubReaddleLibRepo.absolutePath revision:readdleLib_niks_Revision branch:@"main"],
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/RDPDFKit" url:self.env.githubRDPDFKitRepo.absolutePath revision:pdfKit_initialRevision branch:@"main"],
        ]];

        XCTAssertEqualObjects(expectedConfig, parsedConfig);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKitActualRevision, pdfKit_initialRevision);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_niks_Revision toRevision:readdleLibActualRevision]);

        int gitExitStatus = 0;
        NSString *actualGeometryContents = [readdleLibSubrepoGit showFile:@"RDGeometry.h" atRevision:readdleLibActualRevision exitStatus:&gitExitStatus];
        XCTAssertEqual(0, gitExitStatus);
        XCTAssertEqualObjects(actualGeometryContents, expectedRDGeometryContents);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

- (void)testMergeBranchWithDeinitializedS7 {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        // s7 init
        s7init_deactivateHooks();
        
        // git ci -am "init s7"
        s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"init s7"];
        NSString *mainWithS7;
        [repo getCurrentRevision:&mainWithS7];
        
        // git co -b "no-s7"
        [repo checkoutNewLocalBranch:@"no-s7"];
        
        // s7 deinit
        S7DeinitCommand *command = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);
        
        // git add -u
        // git ci -m "deinit s7"
        [repo add:@[@".gitignore", S7ConfigFileName]];
        [repo commitWithMessage:@"deinit s7"];
        NSString *branchWithoutS7;
        [repo getCurrentRevision:&branchWithoutS7];
        
        // git checkout main
        [repo checkoutExistingLocalBranch:@"main"];
        XCTAssertEqual(S7ExitCodeSuccess, s7init_deactivateHooks());
        
        S7PostCheckoutHook *postCheckoutHook = [S7PostCheckoutHook new];
        int hookExitStatus = [postCheckoutHook runWithArguments:@[
            branchWithoutS7,
            mainWithS7,
            @"1"
        ]];
        XCTAssertEqual(S7ExitCodeSuccess, hookExitStatus);
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
        
        // git merge --no-edit no-s7
        [repo mergeWith:branchWithoutS7];
        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        hookExitStatus = [postMergeHook runWithArguments:@[@"0"]];
        XCTAssertEqual(S7ExitCodeSuccess, hookExitStatus);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7substate"]);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@".s7control"]);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
    }];
}

// recursive must be implemented by hooks in subrepos

- (void)testMergeWithIntermediateBranch {
    NSString *intermediateBranchName = @"merge/experiment/to/main";
    setenv("S7_MERGE_DRIVER_INTERMEDIATE_BRANCH", intermediateBranchName.fileSystemRepresentation, 1);

    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *niksRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        [repo checkoutNewLocalBranch:@"experiment"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        [readdleLibSubrepoGit checkoutNewLocalBranch:@"experiment"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", niksRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPhone 15", @"add new device");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");

            return S7ConflictResolutionOptionMerge;
         }];

        XCTAssertNotEqual(0, [repo mergeWith:@"experiment"]);

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(S7ExitCodeSuccess, mergeExitStatus);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];

        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_niks_Revision toRevision:readdleLibActualRevision]);
        XCTAssertTrue([readdleLibSubrepoGit isRevisionAnAncestor:readdleLib_pasteys_Revision toRevision:readdleLibActualRevision]);

        NSString *readdleLibActualBranch = nil;
        BOOL dummy = NO;
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch isDetachedHEAD:&dummy isEmptyRepo:&dummy];
        XCTAssertEqualObjects(readdleLibActualBranch, intermediateBranchName);

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/ReaddleLib"
             url:self.env.githubReaddleLibRepo.absolutePath
             revision:readdleLibActualRevision
             branch:intermediateBranchName]
        ]];

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        XCTAssertEqualObjects(actualConfig, expectedConfig);
    }];
}

- (void)testOneSideUpdateOtherSideDeleteConflictResolution_UnexpectedEnvResolutionOptionIsIgnored {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block S7Config *niksConfig = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepo"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // possible options here are: S7ConflictResolutionOptionKeepChanged (c) | S7ConflictResolutionOptionDelete (d)
        // and we are saying to use 'l'. If driver naively follows such command, then it will take nil (ourVersion)
        // and put it into merge results array – i.e. cause crash.
        //
        setenv("S7_MERGE_DRIVER_RESPONSE", "l", 1);

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        configMergeDriver.isTerminalInteractive = ^{ return NO; };

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertNotEqual(0, mergeExitStatus);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescriptionConflict alloc]
             initWithOurVersion:nil
             theirVersion:[[S7SubrepoDescription alloc]
                           initWithPath:@"Dependencies/ReaddleLib"
                           url:self.env.githubReaddleLibRepo.absolutePath
                           revision:readdleLib_niks_Revision
                           branch:@"main"]]
        ]];

        XCTAssertEqualObjects(actualConfig, expectedConfig);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig);

        XCTAssertNil([GitRepository repoAtPath:@"Dependencies/ReaddleLib"]);
    }];
}

- (void)testMergeKeepTargetBranch {
    setenv("S7_MERGE_DRIVER_KEEP_TARGET_BRANCH", "main", 1);

    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];
    
    __block S7Config *niksConfig = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        [repo checkoutNewLocalBranch:@"release"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        [readdleLibSubrepoGit checkoutNewLocalBranch:@"release"];

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        niksConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPhone 15", @"add new device");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        [repo fetch];

        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        [configMergeDriver setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion)
         {
            XCTFail(@"Keep Target Branch strategy should not produce merge conflicts in this scenario.");
            return S7ConflictResolutionOptionMerge;
         }];

        XCTAssertNotEqual(0, [repo mergeWith:@"release"]);

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(S7ExitCodeSuccess, mergeExitStatus);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];

        XCTAssertEqualObjects(readdleLibActualRevision, readdleLib_pasteys_Revision);

        NSString *readdleLibActualBranch = nil;
        BOOL dummy = NO;
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch isDetachedHEAD:&dummy isEmptyRepo:&dummy];
        XCTAssertEqualObjects(readdleLibActualBranch, @"main");

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/ReaddleLib"
             url:self.env.githubReaddleLibRepo.absolutePath
             revision:readdleLib_pasteys_Revision
             branch:@"main"]
        ]];

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        XCTAssertEqualObjects(actualConfig, expectedConfig);
    }];
}
@end
