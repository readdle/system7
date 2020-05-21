//
//  mergeTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 07.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7ConfigMergeDriver.h"

#import "S7PostMergeHook.h"
#import "S7PostCommitHook.h"

#import "S7SubrepoDescriptionConflict.h"


// We use `prepare-commit-msg` hook to react at... merges.
// You may wonder why don't I use `pre-merge-commit`. The answer is –
// this crap "can be bypassed with the --no-verify option". This is for
// starters.
// Then "if the merge cannot be carried out automatically,
// the conflicts need to be resolved and the result committed separately
// ... this hook will not be executed, but the pre-commit hook will,
// if it is enabled.".
// So we come to `pre-commit` hook, you might think. But no, `pre-commit`
// hook "can be bypassed with the --no-verify option."
// Git – full of small pleasures 🤷‍♂️
//
// And even that's not all `prepare-commit-msg` is not enough to detect
// merges/pulls. Sometimes we detect them from `post-merge` hook:
//  - in case of fast-forward merge
//  - in case of branch merge without conflict, as there's no way
//    to understand from `post-merge` that this hook has already done
//    the job
//


@interface mergeTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation mergeTests

- (void)setUp {
//    unsetenv("GIT_REFLOG_ACTION");
    self.env = [TestReposEnvironment new];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
    }];
}

- (void)tearDown {
//    unsetenv("GIT_REFLOG_ACTION");
}

#pragma mark -

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



        [repo checkoutExistingLocalBranch:@"master"];

        s7checkout(experimentBranchRD2Revision, initialRD2Revision);

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        NSString *actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(initialReaddleLibRevision, actualReaddleLibRevision);


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

        [repo merge];

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

        [repo merge];

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
                                                                          S7SubrepoDescription * _Nonnull theirVersion,
                                                                          S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
            S7ConflictResolutionOption expectedResolutionOptions =
                S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote | S7ConflictResolutionTypeMerge;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            ++callNumber;

            if (1 == callNumber) {
                // play a fool and return an option not in 'possibleOptions'
                return S7ConflictResolutionTypeKeepChanged;
            }
            else if (2 == callNumber) {
                // play a fool and return an option not in 'possibleOptions' one more time
                return S7ConflictResolutionTypeDelete;
            }
            else if (3 == callNumber) {
                // шоб да, так нет
                return S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote;
            }
            else if (callNumber > 4) {
                // it keeps asking us?
                XCTFail(@"");
            }

            return S7ConflictResolutionTypeMerge;
         }];

        const int mergeExitStatus = [configMergeDriver
                                     mergeRepo:repo
                                     baseConfig:baseConfig
                                     ourConfig:ourConfig
                                     theirConfig:niksConfig
                                     saveResultToFilePath:S7ConfigFileName];
        XCTAssertEqual(0, mergeExitStatus);

        XCTAssertEqual(4, callNumber, @"we played a fool several times, but then responded with a valid value – `merge`");

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
                                                                               S7SubrepoDescription * _Nonnull theirVersion,
                                                                               S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
            S7ConflictResolutionOption expectedResolutionOptions =
            S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote | S7ConflictResolutionTypeMerge;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeKeepLocal;
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
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch];
        XCTAssertEqualObjects(@"master", readdleLibActualBranch);

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
                                                                               S7SubrepoDescription * _Nonnull theirVersion,
                                                                               S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
            S7ConflictResolutionOption expectedResolutionOptions =
            S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote | S7ConflictResolutionTypeMerge;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeKeepRemote;
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
        [readdleLibSubrepoGit getCurrentBranch:&readdleLibActualBranch];
        XCTAssertEqualObjects(@"master", readdleLibActualBranch);

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
                                                                               S7SubrepoDescription * _Nonnull theirVersion,
                                                                               S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertNil(ourVersion);
            XCTAssertEqualObjects(theirVersion.path, @"Dependencies/ReaddleLib");

            S7ConflictResolutionOption expectedResolutionOptions =
            S7ConflictResolutionTypeKeepChanged | S7ConflictResolutionTypeDelete;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeDelete;
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
                                                                               S7SubrepoDescription * _Nonnull theirVersion,
                                                                               S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertNil(ourVersion);
            XCTAssertEqualObjects(theirVersion.path, @"Dependencies/ReaddleLib");

            S7ConflictResolutionOption expectedResolutionOptions =
            S7ConflictResolutionTypeKeepChanged | S7ConflictResolutionTypeDelete;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeKeepChanged;
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
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:self.env.githubReaddleLibRepo.absolutePath revision:readdleLib_niks_Revision branch:@"master"],
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/RDPDFKit" url:self.env.githubRDPDFKitRepo.absolutePath revision:pdfKit_initialRevision branch:@"master"],
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

// test – fail if no control file exists
// test merge-driver when config doesn't exist at one side

// test merge is not allowed if there're uncommited local changes

// what happens if subrepo merge ends with merge conflict? – test this – we should save .s7substate with conflict markers

// [LOW] test merge and checkout if subrepo has switched to a different url – we must drop an old one and clone from a new url
// [LOW] test how we react if merged subrepo is not a git repo (user has done something bad to it)

// recursive?

// renormalize – seems like the thing for clang-format
// .gitattributes 'ident' – interesting stuff for hgrevision.h/swift substitution
// .gitattributes 'filter' – interesting stuff for clang-format (+ filter.<driver>.process)
// .gitattributes 'merge' – penetrate s7 here
//        Defining a custom merge driver
//        The definition of a merge driver is done in the .git/config file, not in the gitattributes file, so strictly speaking this manual page is a wrong place to talk about it. However…


@end
