//
//  controlTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 12.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

@interface controlTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation controlTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGitResetCanBeDetectedWithHash {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        NSString *firstRevision = nil;
        [repo getCurrentRevision:&firstRevision];

        S7Config *firstConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];


        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *secondRevision = nil;
        [repo getCurrentRevision:&secondRevision];

        S7Config *secondConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // say a naïve user 'switched' to an old rd2 revision using `git reset --hard REV`
        XCTAssertEqual(0, [repo resetToRevision:firstRevision]);

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        // there's no way to hook into `git reset`, so he's left with subrepos state not in sync with the
        // .s7substate he has just "checked out"
        XCTAssertEqualObjects(firstConfig, actualConfig);

        // detect this by looking into .s7control
        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertEqualObjects(secondConfig, controlConfig);

        // fix this by calling `s7 checkout`
        s7checkout(secondRevision, firstRevision);

        actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(actualConfig, controlConfig);
    }];
}

@end
