//
//  mergeTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 07.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7MergeCommand.h"
#import "S7SubrepoDescriptionConflict.h"

@interface mergeTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation mergeTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
    S7Config.allowNon40DigitRevisions = YES;
}

- (void)tearDown {
    S7Config.allowNon40DigitRevisions = NO;
}

#pragma mark -

- (void)testCreate {
    S7MergeCommand *command = [S7MergeCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7MergeCommand *command = [S7MergeCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testWithoutRequiredArgument {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7MergeCommand *command = [S7MergeCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"ourRev"]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[@"theirRev"]]);

        int exitStatus = [command runWithArguments:@[@"baseRev", @"ourRev"]];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, exitStatus);
    }];
}

- (void)testWithTooManyArguments {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7MergeCommand *command = [S7MergeCommand new];
        const int exitStatus = [command runWithArguments:@[@"rev1", @"rev2", @"rev3"]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, exitStatus);
    }];
}

#pragma - sanity -

- (void)testAllEmpty {
    S7Config *emptyConfig = [S7Config emptyConfig];
    S7Config *result = [S7MergeCommand mergeOurConfig:emptyConfig theirConfig:emptyConfig baseConfig:emptyConfig];
    XCTAssertEqualObjects(emptyConfig, result, @"");
}

- (void)testNoChanges
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = base;

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(base, result, @"");
}

#pragma mark - one side changes -

- (void)testOneSideAdd
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideUpdate
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, b16ff, master } "];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideDelete
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

#pragma mark - two sides changes - no conflicts -

- (void)testTwoSidesDelSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];
    S7Config *our  =  [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *their   = our;

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testTwoSideDelOfDifferentSubrepos {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                    " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesUpdateDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, 8888, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 1234, master } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, 8888, master } \n"
                                                  " rduikit = { github/rduikit, 1234, master } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesUpdateSameSubrepoInSameWay
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 47ae, master } \n"];

    S7Config *their = our;

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testTwoSidesAddOfDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 47ae, master } \n"];

    S7Config *their   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                    " pdfkit = { github/pdfkit, ee16, master } \n"];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 47ae, master } \n"
                                                  " pdfkit = { github/pdfkit, ee16, master } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 47ae, master } \n"];

    S7Config *their = our;

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

#pragma mark -

- (void)testTwoSidesUpdateConflict
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];
    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, 12345, master } \n"];
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, 54321, master } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqual(1lu, result.subrepoDescriptions.count);
    XCTAssertTrue([result.subrepoDescriptions[0] isKindOfClass:[S7SubrepoDescriptionConflict class]]);

    S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)(result.subrepoDescriptions[0]);

    XCTAssertEqual(our.subrepoDescriptions[0], conflict.ourVersion);
    XCTAssertEqual(their.subrepoDescriptions[0], conflict.theirVersion);
}

- (void)testOneSideDelOtherSideUpdateConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 2345, master } \n"];


    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"master"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:nil
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"2345" branch:@"master"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepoWithDifferentStateConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                 " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                   " rduikit = { github/rduikit, 8888, master } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"master"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"master"]
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"8888" branch:@"master"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepoWithDifferentBranchButSameRevisionConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                 " rduikit = { github/rduikit, 7777, i-love-git } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                   " rduikit = { github/rduikit, 7777, huyaster } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"master"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"i-love-git"]
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"huyaster"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testMergeKeepsOurAddedLinesAtTheirPositionInFile {
    // this is important to have sane diff that people can read easily
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"
                                                  " readdleLib = { github/readdleLib, ab12, master } \n"
                                                  " syncLib = { github/syncLib, ed67, master } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, master } \n"];

    S7Config *their  = base;

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testMergeKeepsOurLinesOrder {
    // say, someone has decided to 'refactor' our config order to make it easier for human beeings.
    // we will try to keep this order
    S7Config *base   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"];

    S7Config *our   = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"
                                                  " keychain = { github/keychain, a7d43, master } \n"
                                                  " syncLib = { github/syncLib, ed67, master } \n"];

    S7Config *their   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, master } \n"];

    S7Config *result = [S7MergeCommand mergeOurConfig:our theirConfig:their baseConfig:base];
    S7Config *exp    = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"
                                                  " keychain = { github/keychain, a7d43, master } \n"
                                                  " syncLib = { github/syncLib, ed67, master } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, master } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testSameBranchMergeWithoutConflicts {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    __block NSString *rd2_niksRevision = nil;
    __block NSString *pdfKit_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];

        pdfKit_niks_Revision = commit(pdfKitSubrepoGit, @"RDPDFPageContent.h", @"// NDA", @"add text reflow support");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up pdfkit"];

        [repo getCurrentRevision:&rd2_niksRevision];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLib_pasteys_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        const int pushExitStatus = s7push(repo, @"master", rd2_pasteysRevision, rd2_niksRevision);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        [repo merge];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKit_niks_Revision, pdfKitActualRevision);

        NSString *readdleLibActualRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&readdleLibActualRevision];
        XCTAssertEqualObjects(readdleLib_pasteys_Revision, readdleLibActualRevision);

        BOOL isDirectory = NO;
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7HashFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        NSString *hashFileContents = [NSString stringWithContentsOfFile:S7HashFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssert(hashFileContents.length > 0);
        XCTAssertEqualObjects(actualConfig.sha1, hashFileContents);
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_Merge {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block NSString *rd2_niksRevision = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&rd2_niksRevision];

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

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        __block int callNumber = 0;
        [mergeCommand setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
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

        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

        XCTAssertEqual(4, callNumber, @"we played a fool several times, but then responded with a valid value – `merge`");

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

        // not checking 'sha1' here as we didn't perform actual git merge and S7ConfigFile is not updated at the moment
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepLocal {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block NSString *rd2_niksRevision = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&rd2_niksRevision];

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

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        [mergeCommand setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion,
                                                                          S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
            S7ConflictResolutionOption expectedResolutionOptions =
                S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote | S7ConflictResolutionTypeMerge;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeKeepLocal;
         }];

        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

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

        // not checking 'sha1' here as we didn't perform actual git merge and S7ConfigFile is not updated at the moment
    }];
}

- (void)testBothSideUpdateSubrepoToDifferentRevisionConflictResolution_KeepRemote {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block NSString *rd2_niksRevision = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&rd2_niksRevision];

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

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        [mergeCommand setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
                                                                          S7SubrepoDescription * _Nonnull theirVersion,
                                                                          S7ConflictResolutionOption possibleOptions)
         {
            XCTAssertEqualObjects(ourVersion.path, @"Dependencies/ReaddleLib");
            S7ConflictResolutionOption expectedResolutionOptions =
                S7ConflictResolutionTypeKeepLocal | S7ConflictResolutionTypeKeepRemote | S7ConflictResolutionTypeMerge;
            XCTAssertEqual(expectedResolutionOptions, possibleOptions);

            return S7ConflictResolutionTypeKeepRemote;
         }];

        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

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

        // not checking 'sha1' here as we didn't perform actual git merge and S7ConfigFile is not updated at the moment
    }];
}

- (void)testOneSideUpdateOtherSideDeleteConflictResolution_Delete {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block NSString *rd2_niksRevision = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&rd2_niksRevision];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepo"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        [mergeCommand setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
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

        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(parsedConfig);
        XCTAssertEqual(1, parsedConfig.subrepoDescriptions.count);

        XCTAssertEqualObjects(parsedConfig.subrepoDescriptions[0].path, @"Dependencies/RDPDFKit");

        GitRepository *pdfKitSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit"];
        NSString *pdfKitActualRevision = nil;
        [pdfKitSubrepoGit getCurrentRevision:&pdfKitActualRevision];
        XCTAssertEqualObjects(pdfKitActualRevision, pdfKit_initialRevision);

        // not checking 'sha1' here as we didn't perform actual git merge and S7ConfigFile is not updated at the moment
    }];
}

- (void)testOneSideUpdateOtherSideDeleteConflictResolution_KeepChanged {
    __block NSString *rd2_initialRevision = nil;
    __block NSString *readdleLib_initialRevision = nil;
    __block NSString *pdfKit_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        GitRepository *pdfKitSubrepoGit = s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];
        [pdfKitSubrepoGit getCurrentRevision:&pdfKit_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        [repo getCurrentRevision:&rd2_initialRevision];

        s7push_currentBranch(repo);
    }];

    NSString *expectedRDGeometryContents = @"xyz";
    __block NSString *rd2_niksRevision = nil;
    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDGeometry.h", expectedRDGeometryContents, @"some useful math func");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [repo getCurrentRevision:&rd2_niksRevision];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7remove(@"Dependencies/ReaddleLib");

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"drop ReaddleLib subrepo"];

        const int pushExitStatus = s7push_currentBranch(repo);
        XCTAssertNotEqual(0, pushExitStatus, @"nik has pushed. I must merge");

        [repo fetch];

        NSString *rd2_pasteysRevision = nil;
        [repo getCurrentRevision:&rd2_pasteysRevision];

        S7MergeCommand *mergeCommand = [S7MergeCommand new];
        [mergeCommand setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nonnull ourVersion,
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

        const int mergeExitStatus = [mergeCommand runWithArguments:@[ rd2_initialRevision, rd2_pasteysRevision, rd2_niksRevision ]];
        XCTAssertEqual(0, mergeExitStatus);

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

        // not checking 'sha1' here as we didn't perform actual git merge and S7ConfigFile is not updated at the moment
    }];
}

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
