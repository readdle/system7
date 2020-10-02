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
     "key1 = 1\n"
     "key2 = 2\n"
     @"[section2]\n"
      "key1 = 1\n"
      "key2 = 2\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testWhitespaceIsIgnored {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
    @"[section1]    \r"
     "            key1  \t      =    1\r\n"
     "key2=2\n"
     "\r\r\n"
     @"         [section2]          \n"
      "\t\t\tkey1 = 1\n"
      "key2\t =\t 2            \t    \n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
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
    "key1 = 1\n"
    "key2 = 2 ; followed by a comment\n"
    "  \n"
    "[section2]\n"
     "key1=     1#comment here!\n"
     "    key2=2;followed by a comment\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testQuotesInSectionName {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[merge \"s7\"]\n"
    "key1 = 1\n"
    "key2 = 2 ; followed by a comment\n"
    "  \n"
    "[section2 \"sub contains # and ; signs\"]\n"
     "key1=     1#comment here!\n"
     "    key2=2;followed by a comment\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"merge \"s7\"" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2 \"sub contains # and ; signs\"" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testEmptyValueIsTreatedAsTrue {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section1]\n"
     "key1  =  \n"
     "key2=\n"
     ];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"true",
                                              @"key2" : @"true",
                                          },
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testValueContainsEqualSign {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section1]\n"
     "key1  = 2+2=5 \n"
     "key2= E=mc^2\n"
     ];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"2+2=5",
                                              @"key2" : @"E=mc^2",
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
     "key1  =  \n"
     "key2=\n"
     "key-with-no-value      \n"
     ];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"true",
                                              @"key2" : @"true",
                                          },
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testInvalidSectionIsIgnored {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section1\n"  // <--- no closing ']'
      "  key1 = value1\n"
      "  key2 = value2\n"
      "[section2]\n"
      "key1 = 1\n"
      "key2 = 2\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testOutOfSectionValuesAreIgnored {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"  ignored1 = shit1\n"
      "  ignored2 = 2\n"
      "[section1]\n"
      "  key1 = 1\n"
      "  key2 = 2\n"
      "[section2]\n"
      "  key1 = 1\n"
      "  key2 = 2\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

- (void)testOutOfSectionContinuationAndValueOverwrite {
    S7IniConfig *config =
    [S7IniConfig configWithContentsOfString:
     @"[section2]\n"
      "  key1 = ignored1\n"
      "  key2 = 2\n"
      "[section1]\n"
      "  key1 = 1\n"
      "  key2 = 2\n"
      "[section2]\n"
      "  key1 = 1\n"
      "  key3 = value3\n"];

    XCTAssertNotNil(config);
    NSDictionary *expectedConfig = @{ @"section1" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                          },
                                      @"section2" :
                                          @{
                                              @"key1" : @"1",
                                              @"key2" : @"2",
                                              @"key3" : @"value3",
                                          }
    };
    XCTAssertEqualObjects(config.dictionaryRepresentation,
                          expectedConfig);
}

@end
