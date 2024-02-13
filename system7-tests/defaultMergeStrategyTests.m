//
//  defaultMergeStrategyTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7DefaultMergeStrategy.h"
#import "S7SubrepoDescriptionConflict.h"

@interface defaultMergeStrategyTests : XCTestCase
@property (nonatomic) S7DefaultMergeStrategy *mergeStrategy;
@end

@implementation defaultMergeStrategyTests

- (void)setUp {
    S7Config.allowNon40DigitRevisions = YES;
    self.mergeStrategy = [S7DefaultMergeStrategy new];
}

- (void)tearDown {
    S7Config.allowNon40DigitRevisions = NO;
    self.mergeStrategy = nil;
}

#pragma - sanity -

- (void)testAllEmpty {
    S7Config *emptyConfig = [S7Config emptyConfig];
    S7Config *result = [self mergeOurConfig:emptyConfig theirConfig:emptyConfig baseConfig:emptyConfig];
    XCTAssertEqualObjects(emptyConfig, result, @"");
}

- (void)testNoChanges
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } "];
    S7Config *our   = base;
    S7Config *their = base;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(base, result, @"");
}

#pragma mark - one side changes -

- (void)testOneSideAdd
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideUpdate
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, b16ff, main } "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

- (void)testOneSideDelete
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
}

#pragma mark - two sides changes - no conflicts -

- (void)testTwoSidesDeleteSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];
    S7Config *our  =  [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } "];
    S7Config *their   = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testTwoSideDelOfDifferentSubrepos {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                    " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesUpdateDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, 8888, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 1234, main } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, 8888, main } \n"
                                                  " rduikit = { github/rduikit, 1234, main } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesUpdateSameSubrepoInSameWay
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 47ae, main } \n"];

    S7Config *their = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testTwoSidesAddOfDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 47ae, main } \n"];

    S7Config *their   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                    " pdfkit = { github/pdfkit, ee16, main } \n"];

    S7Config *exp   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 47ae, main } \n"
                                                  " pdfkit = { github/pdfkit, ee16, main } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 47ae, main } \n"];

    S7Config *their = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

#pragma mark -

- (void)testTwoSidesUpdateConflict
{
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];
    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, 12345, main } \n"];
    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, 54321, main } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqual(1lu, result.subrepoDescriptions.count);
    XCTAssertTrue([result.subrepoDescriptions[0] isKindOfClass:[S7SubrepoDescriptionConflict class]]);

    S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)(result.subrepoDescriptions[0]);

    XCTAssertEqual(our.subrepoDescriptions[0], conflict.ourVersion);
    XCTAssertEqual(their.subrepoDescriptions[0], conflict.theirVersion);
}

- (void)testOneSideDelOtherSideUpdateConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    S7Config *their = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 2345, main } \n"];


    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"main"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:nil
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"2345" branch:@"main"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepoWithDifferentStateConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                 " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                   " rduikit = { github/rduikit, 8888, main } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"main"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"main"]
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"8888" branch:@"main"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testTwoSidesAddSameSubrepoWithDifferentBranchButSameRevisionConflict {
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"];

    S7Config *our  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                 " rduikit = { github/rduikit, 7777, i-love-git } \n"];

    S7Config *their  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                   " rduikit = { github/rduikit, 7777, huyaster } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescription alloc] initWithPath:@"keychain" url:@"github/keychain" revision:@"a7d43" branch:@"main"],
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"i-love-git"]
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"huyaster"] ]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
}

- (void)testMergeKeepsOurAddedLinesAtTheirPositionInFile {
    // this is important to have sane diff that people can read easily
    S7Config *base  = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"];

    S7Config *our   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"
                                                  " pdfkit = { github/pdfkit, 2346, main } \n"
                                                  " readdleLib = { github/readdleLib, ab12, main } \n"
                                                  " syncLib = { github/syncLib, ed67, main } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, main } \n"];

    S7Config *their  = base;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
}

- (void)testMergeKeepsOurLinesOrder {
    // say, someone has decided to 'refactor' our config order to make it easier for human beeings.
    // we will try to keep this order
    S7Config *base   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"
                                                  " pdfkit = { github/pdfkit, 2346, main } \n"];

    S7Config *our   = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"
                                                  " pdfkit = { github/pdfkit, 2346, main } \n"
                                                  " keychain = { github/keychain, a7d43, main } \n"
                                                  " syncLib = { github/syncLib, ed67, main } \n"];

    S7Config *their   = [S7Config configWithString:@" keychain = { github/keychain, a7d43, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"
                                                  " pdfkit = { github/pdfkit, 2346, main } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, main } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
    S7Config *exp    = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, main } \n"
                                                  " rduikit = { github/rduikit, 7777, main } \n"
                                                  " pdfkit = { github/pdfkit, 2346, main } \n"
                                                  " keychain = { github/keychain, a7d43, main } \n"
                                                  " syncLib = { github/syncLib, ed67, main } \n"
                                                  " rdintegration = { github/rdintegration, 7de5, main } \n"];

    XCTAssertEqualObjects(exp, result, @"");
}

#pragma mark - utils -

- (S7Config *)mergeOurConfig:(S7Config *)ourConfig theirConfig:(S7Config *)theirConfig baseConfig:(S7Config *)baseConfig {
    BOOL dummy = NO;
    return [self.mergeStrategy mergeOurConfig:ourConfig theirConfig:theirConfig baseConfig:baseConfig detectedConflict:&dummy];
}


@end
