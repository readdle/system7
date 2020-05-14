//
//  hashTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 12.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7HashCommand.h"
#import "TestReposEnvironment.h"

@interface hashTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation hashTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreate {
    S7HashCommand *command = [S7HashCommand new];
    XCTAssertNotNil(command);
}

- (void)testInNotS7Repo {
    S7HashCommand *command = [S7HashCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testInValidS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init();

        S7HashCommand *command = [S7HashCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(parsedConfig.sha1, [command calculateHash]);
    }];
}

- (void)testGitResetCanBeDetectedWithHash {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        S7HashCommand *hashCommand = [S7HashCommand new];

        NSString *firstRevision = nil;
        [repo getCurrentRevision:&firstRevision];

        NSString *firstS7Hash = [hashCommand calculateHash];


        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *secondRevision = nil;
        [repo getCurrentRevision:&secondRevision];

        NSString *secondS7Hash = [hashCommand calculateHash];

        // say a naïve user 'switched' to an old rd2 revision using `git reset --hard REV`
        XCTAssertEqual(0, [repo resetToRevision:firstRevision]);

        // there's no way to hook into `git reset`, so he's left with subrepos state not in sync with the
        // .s7substate he has just "checked out"
        XCTAssertEqualObjects(firstS7Hash, [hashCommand calculateHash]);

        // detect this by looking into .s7hash
        NSString *hashFileContents = [NSString stringWithContentsOfFile:S7HashFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssert(hashFileContents.length > 0);
        XCTAssertEqualObjects(secondS7Hash, hashFileContents);

        // fix this by calling `s7 checkout`
        s7checkout(secondRevision, firstRevision);

        hashFileContents = [NSString stringWithContentsOfFile:S7HashFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssert(hashFileContents.length > 0);
        XCTAssertEqualObjects(firstS7Hash, hashFileContents);
    }];
}

@end
