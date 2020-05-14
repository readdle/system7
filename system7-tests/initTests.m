//
//  initTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"

#import "TestReposEnvironment.h"

@interface initTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation initTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    
}

#pragma mark -

- (void)testCreate {
    S7InitCommand *statusCommand = [S7InitCommand new];
    XCTAssertNotNil(statusCommand);
}

- (void)testOnVirginRepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        BOOL isDirectory = NO;
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7HashFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".gitignore" isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:S7HashFileName].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:S7HashFileName options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:S7HashFileName].location,
                       @"must be added to .gitignore just once");

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7HashFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        S7Config *config = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(config);
        NSString *hashFileContents = [NSString stringWithContentsOfFile:S7HashFileName encoding:NSUTF8StringEncoding error:nil];
        XCTAssert(hashFileContents.length > 0);
        XCTAssertEqualObjects(config.sha1, hashFileContents);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7GitPrePushHookFilePath isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        NSDictionary<NSString *, NSString *> *expectedHooksAndTheirContents =
            @{
                S7GitPrePushHookFilePath : S7GitPrePushHookFileContents,
                S7GitPostCheckoutHookFilePath : S7GitPostCheckoutHookFileContents,
            };

        [expectedHooksAndTheirContents
         enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *actualHookContents = [[NSString alloc]
                                            initWithData:[NSFileManager.defaultManager contentsAtPath:key]
                                            encoding:NSUTF8StringEncoding];
            XCTAssertEqualObjects(actualHookContents, obj);
         }];
    });
}

- (void)testOnAlreadyInitializedRepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@".s7hash"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@".s7hash" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@".s7hash"].location,
                       @"must be added to .gitignore just once");
    });
}

- (void)testToInitOnRepoThatHasCustomGitHooks {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [@"дулі-дулі, дулі вам!" writeToFile:S7GitPrePushHookFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeFileOperationFailed, [command runWithArguments:@[]]);
    }];
}

@end
