//
//  mergeAlgorithmTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7ConfigMergeDriver.h"
#import "S7SubrepoDescriptionConflict.h"

@interface mergeAlgorithmTests : XCTestCase
@end

@implementation mergeAlgorithmTests

- (void)setUp {
    S7Config.allowNon40DigitRevisions = YES;
}

- (void)tearDown {
    S7Config.allowNon40DigitRevisions = NO;
}

#pragma - sanity -

- (void)testAllEmpty {
    S7Config *emptyConfig = [S7Config emptyConfig];
    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:emptyConfig theirConfig:emptyConfig baseConfig:emptyConfig];
    XCTAssertEqualObjects(emptyConfig, result, @"");
}

- (void)testNoChanges
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = base;

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(base, result, @"");
}

#pragma mark - one side changes -

- (void)testOneSideAdd
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideUpdate
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, b16ff, master } "];

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideDelete
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

#pragma mark - two sides changes - no conflicts -

- (void)testTwoSidesDelSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];
    S7Config *our  =  [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } "];
    S7Config *their   = our;

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"
                                                  " rduikit = { github/rduikit, 47ae, master } \n"];

    S7Config *their = our;

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

#pragma mark -

- (void)testTwoSidesUpdateConflict
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, master } \n"];
    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, 12345, master } \n"];
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, 54321, master } \n"];

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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


    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];

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

    S7Config *result = [S7ConfigMergeDriver mergeOurConfig:our theirConfig:their baseConfig:base];
    S7Config *exp    = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, master } \n"
                                                  " rduikit = { github/rduikit, 7777, master } \n"
                                                  " pdfkit = { github/pdfkit, 2346, master } \n"
                                                  " keychain = { github/keychain, a7d43, master } \n"
                                                  " syncLib = { github/syncLib, ed67, master } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, master } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

@end
