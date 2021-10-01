//
//  optionsParsingTests.m
//  optionsParsingTests
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "S7IniConfig.h"
#import "S7Options.h"

@interface optionsParsingTests : XCTestCase

@end

@implementation optionsParsingTests

- (void)testCorrectAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh, git"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSSet<S7OptionsTransportProtocolName> *expectedTransportProtocols =
    [NSSet setWithObjects:S7OptionsTransportProtocolNameSSH, S7OptionsTransportProtocolNameGit, nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testCorrectAllowedTransportProtocolsListWithOneProtocolParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSSet<S7OptionsTransportProtocolName> *expectedTransportProtocols =
    [NSSet setWithObjects:S7OptionsTransportProtocolNameSSH, nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testCaseInsensitivityInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = SsH, gIt, HtTpS"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSSet<S7OptionsTransportProtocolName> *expectedTransportProtocols = [NSSet setWithObjects:
                                                                         S7OptionsTransportProtocolNameSSH,
                                                                         S7OptionsTransportProtocolNameGit,
                                                                         S7OptionsTransportProtocolNameHTTPS,
                                                                         nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testMissedAddSectionInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"transport-protocols = git"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, S7Options.supportedTransportProtocols);
}

- (void)testMissedOptionInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"[add]"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, S7Options.supportedTransportProtocols);
}

- (void)testMissedOptionValueInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols ="];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, S7Options.supportedTransportProtocols);
}

- (void)testInvalidSeparatorInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh | git.https"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, S7Options.supportedTransportProtocols);
}

- (void)testInvalidProtocolInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh, kaka"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, S7Options.supportedTransportProtocols);
}

- (void)testLocalURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *localURLString = @"file://path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:localURLString]);
}

- (void)testLocalURLWithAbsolutePathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *localURLString = @"/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:localURLString]);
}

- (void)testLocalURLWithRelativePathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *localURLString = @"./path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:localURLString]);
}

- (void)testLocalURLWithRelativeParentPathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *localURLString = @"../path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:localURLString]);
}

- (void)testSSHURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *sshURLString = @"ssh://user@host.xz/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:sshURLString]);
}

- (void)testSSHURLInSCPLikeFormatMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *sshURLString = @"user@host.xz:path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:sshURLString]);
}

- (void)testSSHURLInSCPLikeFormatAndUserNameExpansionMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *sshURLString = @"host.xz:/~user/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:sshURLString]);
}

- (void)testGitURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = git"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *gitURLString = @"git://host.xz/~user/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:gitURLString]);
}

- (void)testHTTPURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = http"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *httpURLString = @"http://host.xz/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:httpURLString]);
}

- (void)testHTTPSURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = https"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *httpURLString = @"https://host.xz/path/to/repo.git/";
    
    XCTAssertTrue([options urlStringMatchesAllowedTransportProtocols:httpURLString]);
}

- (void)testURLWithNotAllowedTransportProtocol {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = http, https, git"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *sshURLString = @"github.com:/~user/path/to/repo.git/";
    
    XCTAssertFalse([options urlStringMatchesAllowedTransportProtocols:sshURLString]);
}

- (void)testHTTPSURLDoesNotMatchSSHTransportProtocol {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7Options *options = [[S7Options alloc] initWithIniConfig:config];
    NSString *httpsURLString = @"https://user@host.xz/path/to/repo.git/";
    
    XCTAssertFalse([options urlStringMatchesAllowedTransportProtocols:httpsURLString]);
}

@end
