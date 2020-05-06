//
//  system7_tests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7Parser.h"

@interface system7_tests : XCTestCase

@end

@implementation system7_tests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

// test trailing comments

- (void)testValidConfig {
    NSString *config =
    @"# readdle\n"
    "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, master }\n"
    "\n" // empty line
    "Dependencies/rdcifs={git@github.com:readdle/rdcifs,50835dbf4a6f4bdf4664d94c26fc1fab594df4bf,task/DOC-1567}\n" // some space haters
    "   Dependencies/rdkeychain   =   \t {git@github.com:readdle/rdkeychain,\t1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e, \tmaster}   \n" // some space LOVERS (and even TAB here)
    "   \n" // empty line with space left overs
    "# thridparty\n"
    "Dependencies/Thirdparty/log4Cocoa = { git@github.com:readdle/log4Cocoa, e11e50dfb5d2e8ef7e96f9683128e5820755b026, master }\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"master"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdcifs" url:@"git@github.com:readdle/rdcifs" revision:@"50835dbf4a6f4bdf4664d94c26fc1fab594df4bf" branch:@"task/DOC-1567"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdkeychain" url:@"git@github.com:readdle/rdkeychain" revision:@"1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e" branch:@"master"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/Thirdparty/log4Cocoa" url:@"git@github.com:readdle/log4Cocoa" revision:@"e11e50dfb5d2e8ef7e96f9683128e5820755b026" branch:@"master"]
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testTrailingCommentConfig {
    NSString *config =
    @"Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, master } # please, do not update untill we fix ... \n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"1d55eede9471fc9245de5bd85b55102684c8c300" branch:@"master"],
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testClosingCurlyBraceInTrailingCommentConfig {
    NSString *config =
    @"Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, master } # ar-ar! I'm a tiny little } (closing curly brace trying to break regex mathch) \n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"1d55eede9471fc9245de5bd85b55102684c8c300" branch:@"master"],
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testInvalidSeparatorConfig {
    NSString *config =
    @"Dependencies/ReaddleLib : git@github.com:readdle/readdlelib\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNil(parsedConfig);
}

- (void)testInvalidMissingPathConfig {
    NSString *config =
    @"    = git@github.com:readdle/readdlelib\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNil(parsedConfig);
}

- (void)testInvalidMissingUrlConfig {
    NSString *config =
    @"    = git@github.com:readdle/readdlelib\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSAssert(NO, @"");
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNil(parsedConfig);
}

- (void)testNoSuchFileConfig {
    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:@"./no-such.config"];
    XCTAssertNotNil(parsedConfig);
    XCTAssert(0 == parsedConfig.subrepoDescriptions.count);
}


@end
