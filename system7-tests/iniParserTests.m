//
//  iniParserTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 29.09.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7IniConfig.h"

@interface iniParserTests : XCTestCase

@end

@implementation iniParserTests

- (void)testExample {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@""];
    XCTAssertNotNil(config);
}

- (void)testSimpleConfig {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
    @"[section1]\n"
     "value1 = 1\n"
     "value2 = 2\n"
     @"[section2]\n"
      "value1 = 1\n"
      "value2 = 2\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testWhitespaceIsIgnored {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
    @"[section1]    \n"
     "            value1  \t      =    1\n"
     "value2=2\n"
     @"         [section2]          \n"
      "\t\t\tvalue1 = 1\n"
      "value2\t =\t 2            \t    \n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testCommentsAndEmptyLinesAreIgnored {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"# I'm a comment. Followed by an empty line\n"
     "    \n"
    "[section1]\n"
    "value1 = 1\n"
    "value2 = 2 ; followed by a comment\n"
    "  \n"
    "[section2]\n"
     "value1=     1#comment here!\n"
     "    value2=2;followed by a comment\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testQuotesInSectionName {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[merge \"s7\"]\n"
    "value1 = 1\n"
    "value2 = 2 ; followed by a comment\n"
    "  \n"
    "[section2 \"sub contains # and ; signs\"]\n"
     "value1=     1#comment here!\n"
     "    value2=2;followed by a comment\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"merge \"s7\"" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          },
                                      @"section2 \"sub contains # and ; signs\"" :
                                          @{
                                              @"value1" : @"1",
                                              @"value2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testEmptyValueIsTreatedAsTrue {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section1]\n"
     "value1  =  \n"
     "value2=\n"
     ];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"value1" : @"true",
                                              @"value2" : @"true",
                                          },
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testInvalidKVs {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section1]\n"
     " \t  = value-for-empty key\n" // empty key
     "value1  =  \n"
     "value2=\n"
     "key-with-no-value      \n"
     ];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"value1" : @"true",
                                              @"value2" : @"true",
                                          },
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

@end
