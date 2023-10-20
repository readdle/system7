//
//  configParserTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7Config.h"
#import "S7SubrepoDescriptionConflict.h"

@interface configParserTests : XCTestCase

@end

@implementation configParserTests

- (void)testValidConfig {
    NSString *config =
    @"# readdle\n"
    "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, main }\n"
    "\n" // empty line
    "Dependencies/rdcifs={git@github.com:readdle/rdcifs,50835dbf4a6f4bdf4664d94c26fc1fab594df4bf,task/DOC-1567}\n" // some space haters
    "   Dependencies/rdkeychain   =   \t {git@github.com:readdle/rdkeychain,\t1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e, \tmain}   \n" // some space LOVERS (and even TAB here)
    "   \n" // empty line with space left overs
    "# thridparty\n"
    "Dependencies/Thirdparty/log4Cocoa = { git@github.com:readdle/log4Cocoa, e11e50dfb5d2e8ef7e96f9683128e5820755b026, main }\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        XCTAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"main"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdcifs" url:@"git@github.com:readdle/rdcifs" revision:@"50835dbf4a6f4bdf4664d94c26fc1fab594df4bf" branch:@"task/DOC-1567"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdkeychain" url:@"git@github.com:readdle/rdkeychain" revision:@"1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e" branch:@"main"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/Thirdparty/log4Cocoa" url:@"git@github.com:readdle/log4Cocoa" revision:@"e11e50dfb5d2e8ef7e96f9683128e5820755b026" branch:@"main"]
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testTrailingCommentConfig {
    NSString *config =
    @"Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } # please, do not update untill we fix ... \n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        XCTAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"1d55eede9471fc9245de5bd85b55102684c8c300" branch:@"main"],
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testClosingCurlyBraceInTrailingCommentConfig {
    NSString *config =
    @"Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } # ar-ar! I'm a tiny little } (closing curly brace trying to break regex mathch) \n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        XCTAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"1d55eede9471fc9245de5bd85b55102684c8c300" branch:@"main"],
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
        XCTAssert(NO, @"");
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
        XCTAssert(NO, @"");
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
        XCTAssert(NO, @"");
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNil(parsedConfig);
}

- (void)testNoSuchFileConfig {
    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:@"./no-such.config"];
    XCTAssertNotNil(parsedConfig);
    XCTAssert(0 == parsedConfig.subrepoDescriptions.count);
}

- (void)testConfigWithConflict {
    NSString *config =
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "=======\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, experiment } \n"
     ">>>>>>> theirs\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        XCTAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescriptionConflict alloc]
         initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib"
                                                                   url:@"git@github.com:readdle/readdlelib"
                                                              revision:@"1d55eede9471fc9245de5bd85b55102684c8c300"
                                                                branch:@"main"]
         theirVersion:[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib"
                                                             url:@"git@github.com:readdle/readdlelib"
                                                        revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11"
                                                          branch:@"experiment"]],
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNotNil(parsedConfig);
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testConfigWithConflictOneSideRemove {
    NSString *config =
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "=======\n"
     ">>>>>>> theirs\n"
    ;

    NSString *configFilePath = @"./config";

    NSError *error = nil;
    if (NO == [config writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        XCTAssert(NO, @"");
    }

    NSArray<S7SubrepoDescription *> *expectedParsedConfig = @[
        [[S7SubrepoDescriptionConflict alloc]
         initWithOurVersion:[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib"
                                                                   url:@"git@github.com:readdle/readdlelib"
                                                              revision:@"1d55eede9471fc9245de5bd85b55102684c8c300"
                                                                branch:@"main"]
         theirVersion:nil],
    ];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:configFilePath];
    XCTAssertNotNil(parsedConfig);
    XCTAssertEqualObjects(parsedConfig.subrepoDescriptions, expectedParsedConfig);
}

- (void)testInvalidConflicts {
    // unterminated conflict
    S7Config *parsedConfig = [[S7Config alloc] initWithContentsString:
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "=======\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, experiment } \n"];
    XCTAssertNil(parsedConfig);

    // missing our/their separator
    parsedConfig = [[S7Config alloc] initWithContentsString:
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, experiment } \n"
     ">>>>>>> theirs\n"];
    XCTAssertNil(parsedConfig);

    // missing start conflict marker
    parsedConfig = [[S7Config alloc] initWithContentsString:
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, experiment } \n"
     ">>>>>>> theirs\n"];
    XCTAssertNil(parsedConfig);

    // nested crap
    parsedConfig = [[S7Config alloc] initWithContentsString:
    @"<<<<<<< yours\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, 1d55eede9471fc9245de5bd85b55102684c8c300, main } \n"
     "<<<<<<< yours again\n"
     "=======\n"
     "Dependencies/ReaddleLib = { git@github.com:readdle/readdlelib, c1913e99e9b8fffc5405ccfe2d0f53f8c623da11, experiment } \n"];
    XCTAssertNil(parsedConfig);
}

@end
