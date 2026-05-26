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

#pragma mark - argv builder -

- (void)testReturnsEmptyWhenUserNil {
    XCTAssertEqualObjects(@[],
                          [GitRepository gitHubTokenInsteadOfArgumentsForUser:nil token:@"abc"]);
}

- (void)testReturnsEmptyWhenUserEmpty {
    XCTAssertEqualObjects(@[],
                          [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"" token:@"abc"]);
}

- (void)testReturnsEmptyWhenTokenNil {
    XCTAssertEqualObjects(@[],
                          [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"alice" token:nil]);
}

- (void)testReturnsEmptyWhenTokenEmpty {
    XCTAssertEqualObjects(@[],
                          [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"alice" token:@""]);
}

- (void)testBuildsTwoInsteadOfPairsForSimpleCreds {
    NSArray<NSString *> *const args = [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"alice"
                                                                                    token:@"abc123"];

    NSArray<NSString *> *const expected = @[
        @"-c", @"url.https://alice:abc123@github.com/.insteadOf=git@github.com:",
        @"-c", @"url.https://alice:abc123@github.com/.insteadOf=ssh://git@github.com/",
    ];
    XCTAssertEqualObjects(expected, args);
}

- (void)testPercentEncodesSpecialCharsInToken {
    // Token with every char that would break URL parsing if left raw.
    NSString *const token = @"a/b@c:d%e#f g";
    NSArray<NSString *> *const args = [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"alice"
                                                                                    token:token];

    XCTAssertEqual((NSUInteger)4, args.count);

    NSString *const joined = [args componentsJoinedByString:@" "];
    // Each special character must be percent-encoded inside the userinfo.
    XCTAssertTrue([joined containsString:@"a%2Fb%40c%3Ad%25e%23f%20g"],
                  @"token chars must be percent-encoded; joined argv was: %@", joined);

    // And the raw forms with the original separators must NOT leak through —
    // a raw `@` after the token would terminate the userinfo prematurely.
    XCTAssertFalse([joined containsString:@"a/b@c:d%e#f g"]);
}

- (void)testPercentEncodesSpecialCharsInUser {
    NSArray<NSString *> *const args = [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"al ice@org"
                                                                                    token:@"abc"];

    NSString *const joined = [args componentsJoinedByString:@" "];
    XCTAssertTrue([joined containsString:@"al%20ice%40org:abc@github.com/"],
                  @"user chars must be percent-encoded; joined argv was: %@", joined);
}

- (void)testInsteadOfBaseUsesHTTPSAndGithubDotComOnly {
    NSArray<NSString *> *const args = [GitRepository gitHubTokenInsteadOfArgumentsForUser:@"alice"
                                                                                    token:@"abc"];

    NSString *const joined = [args componentsJoinedByString:@" "];
    XCTAssertTrue([joined containsString:@".insteadOf=git@github.com:"]);
    XCTAssertTrue([joined containsString:@".insteadOf=ssh://git@github.com/"]);
    XCTAssertTrue([joined containsString:@"url.https://alice:abc@github.com/"]);

    // No other hosts referenced — every "github.com" should be the only host.
    XCTAssertFalse([joined containsString:@"gitlab"]);
    XCTAssertFalse([joined containsString:@"bitbucket"]);
}

#pragma mark - trace masking -

- (void)testTraceMaskReplacesEncodedTokenSubstring {
    NSString *const line = @"-c url.https://alice:abc123@github.com/.insteadOf=git@github.com: "
                            "clone git@github.com:readdle/RDPDFKit.git dest";

    NSString *const masked = [GitRepository maskedTraceLine:line forToken:@"abc123"];

    XCTAssertFalse([masked containsString:@"abc123"], @"raw token leaked: %@", masked);
    XCTAssertTrue([masked containsString:@"https://alice:***@github.com/"]);
    // The non-credential parts of the command line must be preserved.
    XCTAssertTrue([masked containsString:@"git@github.com:readdle/RDPDFKit.git"]);
    XCTAssertTrue([masked containsString:@"clone"]);
}

- (void)testTraceMaskAlsoRedactsTokenWithSpecialChars {
    // The encoded form is what actually appears in the argv; the raw form
    // is masked as defense-in-depth in case git echoes it back somewhere.
    NSString *const token = @"a/b@c";
    NSString *const line = @"-c url.https://alice:a%2Fb%40c@github.com/.insteadOf=git@github.com:";

    NSString *const masked = [GitRepository maskedTraceLine:line forToken:token];

    XCTAssertFalse([masked containsString:@"a%2Fb%40c"], @"encoded token leaked: %@", masked);
    XCTAssertTrue([masked containsString:@"https://alice:***@github.com/"]);
}

- (void)testTraceMaskNoOpWhenTokenEmpty {
    NSString *const line = @"clone git@github.com:readdle/RDPDFKit.git dest";

    XCTAssertEqualObjects(line, [GitRepository maskedTraceLine:line forToken:nil]);
    XCTAssertEqualObjects(line, [GitRepository maskedTraceLine:line forToken:@""]);
}

- (void)testTraceMaskAlsoRedactsLongToken {
    // Verifies that masking doesn't depend on token length — `***` is applied
    // regardless. (Earlier iterations partial-revealed long tokens; this guards
    // against that regression.)
    NSString *const token = @"ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789";  // 40 chars
    NSString *const line = [NSString stringWithFormat:@"https://alice:%@@github.com/", token];

    NSString *const masked = [GitRepository maskedTraceLine:line forToken:token];

    XCTAssertTrue([masked containsString:@"https://alice:***@github.com/"], @"got: %@", masked);
    XCTAssertFalse([masked containsString:token], @"raw token leaked: %@", masked);
}

@end
