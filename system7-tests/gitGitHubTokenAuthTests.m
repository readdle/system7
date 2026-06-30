//
//  gitGitHubTokenAuthTests.m
//  system7-tests
//
//  Copyright © 2026 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "Git.h"
#import "Git+Tests.h"

@interface gitGitHubTokenAuthTests : XCTestCase
@end

@implementation gitGitHubTokenAuthTests

#pragma mark - GIT_CONFIG_* env builder -

- (void)testReturnsEmptyWhenUserNil {
    XCTAssertEqualObjects(@{}, [GitRepository gitHubTokenConfigEnvironmentForUser:nil token:@"abc" existingConfigCount:0]);
}

- (void)testReturnsEmptyWhenUserEmpty {
    XCTAssertEqualObjects(@{}, [GitRepository gitHubTokenConfigEnvironmentForUser:@"" token:@"abc" existingConfigCount:0]);
}

- (void)testReturnsEmptyWhenTokenNil {
    XCTAssertEqualObjects(@{}, [GitRepository gitHubTokenConfigEnvironmentForUser:@"alice" token:nil existingConfigCount:0]);
}

- (void)testReturnsEmptyWhenTokenEmpty {
    XCTAssertEqualObjects(@{}, [GitRepository gitHubTokenConfigEnvironmentForUser:@"alice" token:@"" existingConfigCount:0]);
}

- (void)testBuildsHeaderAuthEntriesFromZero {
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenConfigEnvironmentForUser:@"alice" token:@"abc123" existingConfigCount:0];

    // base64("alice:abc123") == "YWxpY2U6YWJjMTIz"
    NSDictionary<NSString *, NSString *> *const expected = @{
        @"GIT_CONFIG_COUNT": @"3",
        @"GIT_CONFIG_KEY_0": @"url.https://github.com/.insteadOf",
        @"GIT_CONFIG_VALUE_0": @"git@github.com:",
        @"GIT_CONFIG_KEY_1": @"url.https://github.com/.insteadOf",
        @"GIT_CONFIG_VALUE_1": @"ssh://git@github.com/",
        @"GIT_CONFIG_KEY_2": @"http.https://github.com/.extraheader",
        @"GIT_CONFIG_VALUE_2": @"Authorization: Basic YWxpY2U6YWJjMTIz",
    };
    XCTAssertEqualObjects(expected, env);
}

- (void)testAppendsPastExistingConfigCount {
    // A nested s7 inherits the parent's injected GIT_CONFIG_COUNT=3 and must not
    // clobber entries 0..2.
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenConfigEnvironmentForUser:@"alice" token:@"abc" existingConfigCount:3];

    XCTAssertEqualObjects(@"6", env[@"GIT_CONFIG_COUNT"]);
    XCTAssertEqualObjects(@"url.https://github.com/.insteadOf", env[@"GIT_CONFIG_KEY_3"]);
    XCTAssertEqualObjects(@"git@github.com:", env[@"GIT_CONFIG_VALUE_3"]);
    XCTAssertEqualObjects(@"ssh://git@github.com/", env[@"GIT_CONFIG_VALUE_4"]);
    XCTAssertEqualObjects(@"http.https://github.com/.extraheader", env[@"GIT_CONFIG_KEY_5"]);
    // base64("alice:abc") == "YWxpY2U6YWJj"
    XCTAssertEqualObjects(@"Authorization: Basic YWxpY2U6YWJj", env[@"GIT_CONFIG_VALUE_5"]);
    // Must not clobber the caller's existing entries (indices 0..2).
    XCTAssertNil(env[@"GIT_CONFIG_KEY_0"]);
    XCTAssertNil(env[@"GIT_CONFIG_VALUE_2"]);
}

- (void)testTokenNeverAppearsRawOnlyInBase64Header {
    NSString *const user = @"alice";
    NSString *const token = @"ghp_SuperSecret/@:%123";  // chars that would have needed URL-escaping
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenConfigEnvironmentForUser:user token:token existingConfigCount:0];

    NSString *const expectedBasic =
        [[[NSString stringWithFormat:@"%@:%@", user, token] dataUsingEncoding:NSUTF8StringEncoding]
         base64EncodedStringWithOptions:0];

    // The raw token must not appear in any entry — it rides only in the header,
    // base64-encoded. (base64 needs no percent-encoding for arbitrary bytes.)
    NSString *const joined = [env.allValues componentsJoinedByString:@"\n"];
    XCTAssertFalse([joined containsString:token], @"raw token leaked into config: %@", joined);
    NSString *const expectedHeader = [NSString stringWithFormat:@"Authorization: Basic %@", expectedBasic];
    XCTAssertEqualObjects(expectedHeader, env[@"GIT_CONFIG_VALUE_2"]);
}

- (void)testGithubDotComOnly {
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenConfigEnvironmentForUser:@"alice" token:@"abc" existingConfigCount:0];

    NSString *const joined = [[env.allKeys arrayByAddingObjectsFromArray:env.allValues] componentsJoinedByString:@" "];
    XCTAssertFalse([joined containsString:@"gitlab"]);
    XCTAssertFalse([joined containsString:@"bitbucket"]);
}

@end
