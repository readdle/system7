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

- (void)testReturnsNilWhenUserNil {
    XCTAssertNil([GitRepository gitHubTokenAuthTaskEnvironmentForUser:nil token:@"abc" processEnvironment:@{}]);
}

- (void)testReturnsNilWhenUserEmpty {
    XCTAssertNil([GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"" token:@"abc" processEnvironment:@{}]);
}

- (void)testReturnsNilWhenTokenNil {
    XCTAssertNil([GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:nil processEnvironment:@{}]);
}

- (void)testReturnsNilWhenTokenEmpty {
    XCTAssertNil([GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"" processEnvironment:@{}]);
}

- (void)testBuildsHeaderAuthEntriesFromZero {
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc123" processEnvironment:@{}];

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
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:@{@"GIT_CONFIG_COUNT": @"3"}];

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

- (void)testNegativeOrGarbageExistingCountClampsToZero {
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:@{@"GIT_CONFIG_COUNT": @"-5"}];

    XCTAssertEqualObjects(@"3", env[@"GIT_CONFIG_COUNT"]);
    XCTAssertEqualObjects(@"url.https://github.com/.insteadOf", env[@"GIT_CONFIG_KEY_0"]);
}

- (void)testInheritedEnvironmentPassesThrough {
    // The returned dictionary is the COMPLETE child environment: everything the
    // process already had, plus the auth entries.
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice"
                                                       token:@"abc"
                                          processEnvironment:@{@"HOME": @"/Users/alice", @"GIT_CONFIG_COUNT": @"1"}];

    XCTAssertEqualObjects(@"/Users/alice", env[@"HOME"]);
    XCTAssertEqualObjects(@"4", env[@"GIT_CONFIG_COUNT"]);
    XCTAssertEqualObjects(@"url.https://github.com/.insteadOf", env[@"GIT_CONFIG_KEY_1"]);
}

- (void)testTokenNeverAppearsRawOnlyInBase64Header {
    NSString *const user = @"alice";
    NSString *const token = @"ghp_SuperSecret/@:%123";  // chars that would have needed URL-escaping
    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:user token:token processEnvironment:@{}];

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
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:@{}];

    NSString *const joined = [[env.allKeys arrayByAddingObjectsFromArray:env.allValues] componentsJoinedByString:@" "];
    XCTAssertFalse([joined containsString:@"gitlab"]);
    XCTAssertFalse([joined containsString:@"bitbucket"]);
}

@end
