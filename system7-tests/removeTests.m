//
//  removeTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 06.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7RemoveCommand.h"

#import "TestReposEnvironment.h"

@interface removeTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation removeTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreate {
    S7RemoveCommand *command = [S7RemoveCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7RemoveCommand *command = [S7RemoveCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[@"no-such"]]);
}

- (void)testWithoutMandatoryArguments {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init();

        S7RemoveCommand *command = [S7RemoveCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);
    }];
}

- (void)testUnknownSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init();

        S7RemoveCommand *command = [S7RemoveCommand new];
        XCTAssertEqual(S7ExitCodeInvalidArgument, [command runWithArguments:@[ @"no-such" ]]);
    }];
}

- (void)testRemoveValidSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *typicalGitIgnoreContent =
            @".DS_Store\n"
             "*.pbxuser\n"
             "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, initialConfig.subrepoDescriptions.count);

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        // also test input paths' standartization
        const int removeResult = [removeCommand runWithArguments:@[ @"Dependencies/ReaddleLib/" ]];
        XCTAssertEqual(0, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        BOOL isDirectory = NO;
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7HashFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        NSString *hashFileContents = [NSString stringWithContentsOfFile:S7HashFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssert(hashFileContents.length > 0);
        XCTAssertEqualObjects(newConfig.sha1, hashFileContents);
    }];
}

@end
