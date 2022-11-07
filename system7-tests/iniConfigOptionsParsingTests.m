//
//  iniConfigOptionsParsingTests.m
//  iniConfigOptionsParsingTests
//
//  Created by Andrew Podrugin on 01.10.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "S7IniConfig.h"
#import "S7IniConfigOptions.h"
#import "GitFilter.h"

@interface optionsParsingTests : XCTestCase

@end

@implementation optionsParsingTests

- (void)testCorrectAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh, git"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSSet<S7TransportProtocolName> *expectedTransportProtocols =
    [NSSet setWithObjects:S7TransportProtocolNameSSH, S7TransportProtocolNameGit, nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testCorrectAllowedTransportProtocolsListWithOneProtocolParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSSet<S7TransportProtocolName> *expectedTransportProtocols =
    [NSSet setWithObjects:S7TransportProtocolNameSSH, nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testCaseInsensitivityInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = SsH, gIt, HtTpS"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSSet<S7TransportProtocolName> *expectedTransportProtocols = [NSSet setWithObjects:
                                                                         S7TransportProtocolNameSSH,
                                                                         S7TransportProtocolNameGit,
                                                                         S7TransportProtocolNameHTTPS,
                                                                         nil];
    
    XCTAssertEqualObjects(options.allowedTransportProtocols, expectedTransportProtocols);
}

- (void)testMissedAddSectionInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"transport-protocols = git"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertNil(options.allowedTransportProtocols);
}

- (void)testMissedOptionInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"[add]"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertNil(options.allowedTransportProtocols);
}

- (void)testMissedOptionValueInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols ="];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertNil(options.allowedTransportProtocols);
}

- (void)testInvalidSeparatorInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh | git.https"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertNil(options.allowedTransportProtocols);
}

- (void)testInvalidProtocolInAllowedTransportProtocolsListParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh, kaka"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertNil(options.allowedTransportProtocols);
}

- (void)testLocalURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *localURLString = @"file://path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(localURLString, options.allowedTransportProtocols));
}

- (void)testLocalURLWithAbsolutePathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *localURLString = @"/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(localURLString, options.allowedTransportProtocols));
}

- (void)testLocalURLWithRelativePathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *localURLString = @"./path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(localURLString, options.allowedTransportProtocols));
}

- (void)testLocalURLWithRelativeParentPathMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = local"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *localURLString = @"../path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(localURLString, options.allowedTransportProtocols));
}

- (void)testSSHURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *sshURLString = @"ssh://user@host.xz/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(sshURLString, options.allowedTransportProtocols));
}

- (void)testSSHURLInSCPLikeFormatMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *sshURLString = @"user@host.xz:path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(sshURLString, options.allowedTransportProtocols));
}

- (void)testSSHURLInSCPLikeFormatAndUserNameExpansionMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *sshURLString = @"host.xz:/~user/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(sshURLString, options.allowedTransportProtocols));
}

- (void)testGitURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = git"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *gitURLString = @"git://host.xz/~user/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(gitURLString, options.allowedTransportProtocols));
}

- (void)testHTTPURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = http"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *httpURLString = @"http://host.xz/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(httpURLString, options.allowedTransportProtocols));
}

- (void)testHTTPSURLMatching {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = https"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *httpURLString = @"https://host.xz/path/to/repo.git/";
    
    XCTAssertTrue(S7URLStringMatchesTransportProtocolNames(httpURLString, options.allowedTransportProtocols));
}

- (void)testURLWithNotAllowedTransportProtocol {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = http, https, git"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *sshURLString = @"github.com:/~user/path/to/repo.git/";
    
    XCTAssertFalse(S7URLStringMatchesTransportProtocolNames(sshURLString, options.allowedTransportProtocols));
}

- (void)testHTTPSURLDoesNotMatchSSHTransportProtocol {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[add]\n"
                           "transport-protocols = ssh"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    NSString *httpsURLString = @"https://user@host.xz/path/to/repo.git/";
    
    XCTAssertFalse(S7URLStringMatchesTransportProtocolNames(httpsURLString, options.allowedTransportProtocols));
}

- (void)testCorrectFilterBlobNoneParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[git]\n"
                           "filter = blob:none"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];
    
    XCTAssertEqual(options.filter, GitFilterBlobNone);
}

- (void)testCorrectCaseInsensitivityFilterBlobNoneParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[git]\n"
                           "filter = Blob:NONE"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];

    XCTAssertEqual(options.filter, GitFilterBlobNone);
}

- (void)testEmptyFilterParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[git]\n"
                           "filter = "];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];

    XCTAssertEqual(options.filter, GitFilterNone);
}

- (void)testUnsupportedFilterParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:
                           @"[git]\n"
                           "filter = unsupported filter"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];

    XCTAssertEqual(options.filter, GitFilterNone);
}

- (void)testMissedGitSectionInFilterParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"filter = blob:none"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];

    XCTAssertEqual(options.filter, GitFilterUnspecified);
}

- (void)testMissedGitSectionOptionInFilterParsing {
    S7IniConfig *config = [S7IniConfig configWithContentsOfString:@"[git]"];
    S7IniConfigOptions *options = [[S7IniConfigOptions alloc] initWithIniConfig:config];

    XCTAssertEqual(options.filter, GitFilterUnspecified);
}

@end
