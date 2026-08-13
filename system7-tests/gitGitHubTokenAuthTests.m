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
        @"S7_GIT_AUTH_INJECTED": @"1",
    };
    XCTAssertEqualObjects(expected, env);
}

- (void)testAppendsPastExistingConfigCount {
    // The caller's environment already carries foreign GIT_CONFIG_COUNT=3 (e.g.
    // from a CI clone script). We must append past it and not clobber entries
    // 0..2. (This is NOT a nested s7 — that case carries the injected marker and
    // is covered by testReusesEnvironmentWhenAuthAlreadyInjected below.)
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

#pragma mark - recursive (nested) subrepo cloning -

// Counts how many GIT_CONFIG_VALUE_* entries carry an Authorization header.
// git accumulates every http.<url>.extraheader value, so more than one here
// means git would emit duplicate Authorization headers (GitHub → HTTP 400).
static NSUInteger authHeaderCount(NSDictionary<NSString *, NSString *> *env) {
    NSUInteger count = 0;
    for (NSString *value in env.allValues) {
        if ([value hasPrefix:@"Authorization: Basic "]) {
            ++count;
        }
    }
    return count;
}

- (void)testReusesEnvironmentWhenAuthAlreadyInjected {
    // A nested s7 inherits the parent's fully-formed auth environment (marker +
    // GIT_CONFIG_*). It must reuse it verbatim, never appending a second header.
    NSDictionary<NSString *, NSString *> *const inherited =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:@{}];

    NSDictionary<NSString *, NSString *> *const nested =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:inherited];

    XCTAssertEqualObjects(inherited, nested, @"nested s7 must not modify the inherited auth environment");
    XCTAssertEqualObjects(@"3", nested[@"GIT_CONFIG_COUNT"]);
    XCTAssertEqual((NSUInteger)1, authHeaderCount(nested));
}

- (void)testMarkerIsWhatTellsANestedS7Apart {
    // The nested-s7 fast path keys off the marker, and nothing else: an
    // environment that carries GitHub rewrites but no marker is somebody else's
    // config (see the pre-configured-rewrite tests below), and the builder must
    // still be willing to build for it.
    NSDictionary<NSString *, NSString *> *const foreign = @{
        @"GIT_CONFIG_COUNT": @"1",
        @"GIT_CONFIG_KEY_0": @"url.https://outer:OUTER@github.com/.insteadOf",
        @"GIT_CONFIG_VALUE_0": @"git@github.com:",
    };

    NSDictionary<NSString *, NSString *> *const env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:foreign];

    XCTAssertEqualObjects(@"1", env[@"S7_GIT_AUTH_INJECTED"]);
    XCTAssertEqualObjects(@"4", env[@"GIT_CONFIG_COUNT"]);
}

- (void)testRecursiveCloningKeepsSingleAuthHeaderAcrossManyLevels {
    // Reproduces the CI failure: rd2 → RDPDFKit → SPFlounder → Eigen. Each level
    // inherits the level above's environment. Without the idempotency guard the
    // extraheader would multiply per level and GitHub would answer HTTP 400.
    NSDictionary<NSString *, NSString *> *env =
        [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:@{}];

    for (NSUInteger level = 0; level < 4; ++level) {
        env = [GitRepository gitHubTokenAuthTaskEnvironmentForUser:@"alice" token:@"abc" processEnvironment:env];
        XCTAssertEqual((NSUInteger)1, authHeaderCount(env), @"duplicate Authorization header at nesting level %lu", (unsigned long)level);
        XCTAssertEqualObjects(@"3", env[@"GIT_CONFIG_COUNT"]);
    }
}

#pragma mark - pre-configured GitHub URL rewrite -

// s7 keeps a GitHub URL rewrite that the surrounding job has already configured
// (buildserver-utils' set-https-auth.sh, or a git config file on the machine)
// instead of stacking its own rule on top of it. The decision is made from the
// output of `git config --get-regexp ^url\..*\.insteadof$`.

- (void)testNoRewriteConfigured {
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:nil]);
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:@""]);
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:@"\n"]);
}

- (void)testGitHubRewriteIsRecognized {
    XCTAssertTrue([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                   @"url.https://ci:SECRET@github.com/.insteadof git@github.com:"]);
}

- (void)testGitHubRewriteIsRecognizedOnEitherSideOfTheRule {
    // Rewriting GitHub URLs onto some mirror: github.com is only in the value.
    XCTAssertTrue([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                   @"url.https://mirror.local/.insteadof https://github.com/"]);
}

- (void)testGitHubRewriteIsMatchedCaseInsensitively {
    XCTAssertTrue([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                   @"url.https://ci:SECRET@GitHub.com/.insteadof git@GitHub.com:"]);
}

- (void)testRewriteForAnotherHostDoesNotCount {
    // Says nothing about GitHub auth — s7 must still install its own rewrite.
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                    @"url.https://mirror.local/.insteadof https://gitlab.com/"]);
}

- (void)testPushOnlyRewriteDoesNotCount {
    // pushInsteadOf affects pushes only; fetches would still go over SSH.
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                    @"url.https://ci:SECRET@github.com/.pushinsteadof git@github.com:"]);
}

- (void)testNonRewriteConfigDoesNotCount {
    // Neither a github.com remote nor our own extraheader is a rewrite.
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                    @"remote.origin.url git@github.com:readdle/system7.git"]);
    XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                    @"http.https://github.com/.extraheader Authorization: Basic YWxpY2U6YWJj"]);
}

- (void)testAnyOfTheRulesIsEnough {
    NSString *const output =
        @"url.https://mirror.local/.insteadof https://gitlab.com/\n"
        @"url.ssh://hg@bitbucket.org/.insteadof https://bitbucket.org/\n"
        @"url.https://ci:SECRET@github.com/.insteadof git@github.com:\n";
    XCTAssertTrue([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:output]);
}

- (void)testGitReportsRulesInjectedThroughTheEnvironment {
    // End to end against the real git: the rules a job exports before running s7
    // (set-https-auth.sh does exactly this) must come back from the query, in the
    // shape the check above expects. The machine's own global/system config must
    // not have a say in it.
    NSDictionary<NSString *, NSString *> *const jobEnvironment = @{
        @"GIT_CONFIG_GLOBAL": @"/dev/null",
        @"GIT_CONFIG_NOSYSTEM": @"1",
        @"GIT_CONFIG_COUNT": @"1",
        @"GIT_CONFIG_KEY_0": @"url.https://outer:OUTER@github.com/.insteadOf",
        @"GIT_CONFIG_VALUE_0": @"git@github.com:",
    };

    [jobEnvironment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        setenv(key.UTF8String, value.UTF8String, 1);
    }];

    // The query looks at the config git sees from where s7 runs, so run it from
    // a directory that is not a repo — no local config gets a vote either.
    NSString *const currentDirectoryPath = NSFileManager.defaultManager.currentDirectoryPath;
    [NSFileManager.defaultManager changeCurrentDirectoryPath:NSTemporaryDirectory()];

    @try {
        XCTAssertTrue([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                       [GitRepository insteadOfRulesFromEffectiveGitConfig]]);

        // ...and with the job's rules gone, there's nothing to keep.
        unsetenv("GIT_CONFIG_COUNT");
        unsetenv("GIT_CONFIG_KEY_0");
        unsetenv("GIT_CONFIG_VALUE_0");
        XCTAssertFalse([GitRepository gitHubURLRewriteConfiguredInGitConfigOutput:
                        [GitRepository insteadOfRulesFromEffectiveGitConfig]]);
    }
    @finally {
        // The whole test bundle shares this process's environment and cwd.
        for (NSString *key in jobEnvironment) {
            unsetenv(key.UTF8String);
        }
        [NSFileManager.defaultManager changeCurrentDirectoryPath:currentDirectoryPath];
    }
}

@end
