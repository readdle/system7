//
//  keepTargetBranchMergeStrategy.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 15.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7KeepTargetBranchMergeStrategy.h"
#import "S7SubrepoDescriptionConflict.h"

@interface keepTargetBranchMergeStrategy : XCTestCase
@property (nonatomic) S7KeepTargetBranchMergeStrategy *mergeStrategy;
@end

@implementation keepTargetBranchMergeStrategy

- (void)setUp {
    S7Config.allowNon40DigitRevisions = YES;
    self.mergeStrategy = [[S7KeepTargetBranchMergeStrategy alloc] initWithTargetBranchName:@"trunk"];
}

- (void)tearDown {
    S7Config.allowNon40DigitRevisions = NO;
    self.mergeStrategy = nil;
}

#pragma - tests -

- (void)testAllEmpty {
    S7Config *emptyConfig = [S7Config emptyConfig];
    S7Config *result = [self mergeOurConfig:emptyConfig theirConfig:emptyConfig baseConfig:emptyConfig];
    XCTAssertEqualObjects(emptyConfig, result, @"");
}

- (void)testTheirSideFormalUpdateOfBranch
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, release } "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testOurSideUpdateTheirSideFormalUpdateOfBranch
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 11111, trunk } "];
    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 22222, trunk } "];
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 11111, release } "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testNoChanges
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } "];
    S7Config *our   = base;
    S7Config *their = base;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(base, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

#pragma mark - their side changes -

// TODO: проверить как это сработает на настоящих репозиториях в обоих сценариях
- (void)testTheirSideAdd
{
    S7Config *base  = [S7Config emptyConfig];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, release }  "];

    // - мы можем оказаться тут с абсолютно новой сабрепой, где нет еще release/next, тогда норм ее туда добавить
    //   Например, PEM добавят RDNetwork, и мы его подтянем (почему-то на release/7.20 ветке)
    // - мы можем тут оказаться с древней сабрепой, которую воскресили на релизе. Например, lottie. Тогда вопрос,
    //   имеем ли мы право тут тихонечко подменить название ветки на next. Снова таки возможно два варианта (см. ниже)
    //
    //   --OLD---0---0---0---1111 <--- release
    //      ^                  ^
    //      origin/trunk       trunk
    //
    //                      release
    //                         v
    //   --OLD---0---0---0---1111---2222
    //                        ^        ^
    //                      trunk    origin/trunk
    //
    //   Оба варианта выглядят норм.
    //

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
    S7Config *exp = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk }  "];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSidesAddSameSubrepoSameRevisionDifferentBranch
{
    S7Config *base  = [S7Config emptyConfig];
    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk }  "];
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, release }  "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
    S7Config *exp = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk }  "];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTheirSideUpdate
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk } "];
    S7Config *our   = base;
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 2222, release } "];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqual(1lu, result.subrepoDescriptions.count);
    XCTAssertTrue([result.subrepoDescriptions[0] isKindOfClass:[S7SubrepoDescriptionConflict class]]);

    S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)(result.subrepoDescriptions[0]);

    // Our task here is not to silently switch to the 'release' branch in subrepo
    // as would the default merge strategy do
    //
    XCTAssertEqual(our.subrepoDescriptions[0], conflict.ourVersion);
    XCTAssertEqual(their.subrepoDescriptions[0], conflict.theirVersion);

    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTheirSideDelete
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk }"];
    S7Config *our   = base;
    S7Config *their = [S7Config emptyConfig];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(their, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

#pragma mark - two sides changes - no conflicts -

- (void)testTwoSidesDelSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];
    S7Config *our  =  [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } "];
    S7Config *their   = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSideDeleteDifferentSubrepos {
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"
                                                  " rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *our  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                " rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *their  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                    " pdfkit = { github/pdfkit, ee7812, release/pdfexpert-7.3 }  \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSidesUpdateDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 8888, trunk } \n"
                                                  " rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, release } \n"
                                                  " rduikit = { github/rduikit, 1234, release } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7SubrepoDescription *readdleLibDesc =
        [[S7SubrepoDescription alloc] initWithConfigLine:@"ReaddleLib = { github/ReaddleLib, 8888, trunk }"];
    S7SubrepoDescription *rduikitOurDesc =
        [[S7SubrepoDescription alloc] initWithConfigLine:@"rduikit = { github/rduikit, 7777, trunk }"];
    S7SubrepoDescription *rduikitTheirDesc =
        [[S7SubrepoDescription alloc] initWithConfigLine:@"rduikit = { github/rduikit, 1234, release }"];

    S7Config *exp   = [[S7Config alloc] initWithSubrepoDescriptions:@[
        readdleLibDesc,
        [[S7SubrepoDescriptionConflict alloc] initWithOurVersion:rduikitOurDesc
                                                    theirVersion:rduikitTheirDesc]
    ]];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSidesUpdateSameSubrepoInSameWay
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 47ae, trunk } \n"];

    S7Config *their = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSidesAddOfDifferentSubrepos
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"];

    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 47ae, trunk } \n"];

    S7Config *their   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                    " pdfkit = { github/pdfkit, ee16, release } \n"];

    S7Config *exp   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 47ae, trunk } \n"
                                                  " pdfkit = { github/pdfkit, ee16, trunk } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testTwoSidesAddSameSubrepo
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"];

    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
                                                  " rduikit = { github/rduikit, 47ae, trunk } \n"];

    S7Config *their = our;

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqualObjects(our, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

#pragma mark -

- (void)testTwoSidesUpdateConflict
{
    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 1111, trunk } \n"];
    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 2222, trunk } \n"];
    S7Config *their = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, 3333, release } \n"];

    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    XCTAssertEqual(1lu, result.subrepoDescriptions.count);
    XCTAssertTrue([result.subrepoDescriptions[0] isKindOfClass:[S7SubrepoDescriptionConflict class]]);

    S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)(result.subrepoDescriptions[0]);

    XCTAssertEqual(our.subrepoDescriptions[0], conflict.ourVersion);
    XCTAssertEqual(their.subrepoDescriptions[0], conflict.theirVersion);

    [self assertNoSubrepoNotOnTrunk:result];
}

- (void)testOneSideDelOtherSideUpdateConflict {
    S7Config *base  = [S7Config configWithString:@" rduikit = { github/rduikit, 7777, trunk } \n"];

    S7Config *our   = [S7Config emptyConfig];

    S7Config *their = [S7Config configWithString:@" rduikit = { github/rduikit, 2345, release } \n"];


    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];

    S7Config *exp   =  [[S7Config alloc]
                        initWithSubrepoDescriptions:
                        @[
                            [[S7SubrepoDescriptionConflict alloc]
                             initWithOurVersion:nil
                             // the result of a keep-target-branch strategy should never point to anything
                             // but the target branch which is why 
                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"2345" branch:@"trunk"]]
                        ]];

    XCTAssertEqualObjects(exp, result, @"");
    [self assertNoSubrepoNotOnTrunk:result];
}

//- (void)testTwoSidesAddSameSubrepoWithDifferentStateConflict {
//    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"];
//
//    S7Config *our  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                 " rduikit = { github/rduikit, 7777, trunk } \n"];
//
//    S7Config *their  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                   " rduikit = { github/rduikit, 8888, trunk } \n"];
//
//    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
//
//    S7Config *exp   =  [[S7Config alloc]
//                        initWithSubrepoDescriptions:
//                        @[
//                            [[S7SubrepoDescription alloc] initWithPath:@"ReaddleLib" url:@"github/ReaddleLib" revision:@"a7d43" branch:@"main"],
//                            [[S7SubrepoDescriptionConflict alloc]
//                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"main"]
//                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"8888" branch:@"main"] ]
//                        ]];
//
//    XCTAssertEqualObjects(exp, result, @"");
//    [self assertNoSubrepoNotOnTrunk:result];
//}
//
//- (void)testTwoSidesAddSameSubrepoWithDifferentBranchButSameRevisionConflict {
//    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"];
//
//    S7Config *our  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                 " rduikit = { github/rduikit, 7777, i-love-git } \n"];
//
//    S7Config *their  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                   " rduikit = { github/rduikit, 7777, huyaster } \n"];
//
//    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
//
//    S7Config *exp   =  [[S7Config alloc]
//                        initWithSubrepoDescriptions:
//                        @[
//                            [[S7SubrepoDescription alloc] initWithPath:@"ReaddleLib" url:@"github/ReaddleLib" revision:@"a7d43" branch:@"main"],
//                            [[S7SubrepoDescriptionConflict alloc]
//                             initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"i-love-git"]
//                             theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"rduikit" url:@"github/rduikit" revision:@"7777" branch:@"huyaster"] ]
//                        ]];
//
//    XCTAssertEqualObjects(exp, result, @"");
//    [self assertNoSubrepoNotOnTrunk:result];
//}
//
//- (void)testMergeKeepsOurAddedLinesAtTheirPositionInFile {
//    // this is important to have sane diff that people can read easily
//    S7Config *base  = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"];
//
//    S7Config *our   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"
//                                                  " pdfkit = { github/pdfkit, 2346, trunk } \n"
//                                                  " readdleLib = { github/readdleLib, ab12, trunk } \n"
//                                                  " syncLib = { github/syncLib, ed67, trunk } \n"
//                                                  " rdintegration = { github/rdintegration, 7de5, trunk } \n"];
//
//    S7Config *their  = base;
//
//    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
//
//    XCTAssertEqualObjects(our, result, @"");
//    [self assertNoSubrepoNotOnTrunk:result];
//}
//
//- (void)testMergeKeepsOurLinesOrder {
//    // say, someone has decided to 'refactor' our config order to make it easier for human beeings.
//    // we will try to keep this order
//    S7Config *base   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"
//                                                  " pdfkit = { github/pdfkit, 2346, trunk } \n"];
//
//    S7Config *our   = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"
//                                                  " pdfkit = { github/pdfkit, 2346, trunk } \n"
//                                                  " ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " syncLib = { github/syncLib, ed67, trunk } \n"];
//
//    S7Config *their   = [S7Config configWithString:@" ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"
//                                                  " pdfkit = { github/pdfkit, 2346, trunk } \n"
//                                                  " rdintegration = { github/rdintegration, 7de5, trunk } \n"];
//
//    S7Config *result = [self mergeOurConfig:our theirConfig:their baseConfig:base];
//    S7Config *exp    = [S7Config configWithString:@" readdleLib = { github/readdleLib, ab12, trunk } \n"
//                                                  " rduikit = { github/rduikit, 7777, trunk } \n"
//                                                  " pdfkit = { github/pdfkit, 2346, trunk } \n"
//                                                  " ReaddleLib = { github/ReaddleLib, a7d43, trunk } \n"
//                                                  " syncLib = { github/syncLib, ed67, trunk } \n"
//                                                  " rdintegration = { github/rdintegration, 7de5, trunk } \n"];
//
//    XCTAssertEqualObjects(exp, result, @"");
//    [self assertNoSubrepoNotOnTrunk:result];
//}

#pragma mark - utils -

- (S7Config *)mergeOurConfig:(S7Config *)ourConfig theirConfig:(S7Config *)theirConfig baseConfig:(S7Config *)baseConfig {
    BOOL dummy = NO;
    return [self.mergeStrategy mergeOurConfig:ourConfig theirConfig:theirConfig baseConfig:baseConfig detectedConflict:&dummy];
}

- (void)assertNoSubrepoNotOnTrunk:(S7Config *)config {
    for (S7SubrepoDescription *desc in config.subrepoDescriptions) {
        if ([desc isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
            S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)desc;
            if (conflict.ourVersion) {
                XCTAssertEqualObjects(conflict.ourVersion.branch, @"trunk");
            }
        }
        else {
            XCTAssertEqualObjects(desc.branch, @"trunk");
        }
    }
}

@end
