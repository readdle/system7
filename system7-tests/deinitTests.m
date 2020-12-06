//
//  deinitTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 01.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7DeinitCommand.h"
#import "S7InitCommand.h"
#import "S7Types.h"

#import "TestReposEnvironment.h"

@interface deinitTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation deinitTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

#define assertRepoAtPWDIsFreeFromS7() \
do {                                                                            \
    NSFileManager *fileManager = NSFileManager.defaultManager;                  \
    XCTAssertFalse([fileManager fileExistsAtPath:S7BakFileName]);               \
    XCTAssertFalse([fileManager fileExistsAtPath:S7BootstrapFileName]);         \
    XCTAssertFalse([fileManager fileExistsAtPath:S7ControlFileName]);           \
    XCTAssertFalse([fileManager fileExistsAtPath:S7ConfigFileName]);            \
                                                                                \
    if ([fileManager fileExistsAtPath:@".gitignore"]) {                         \
        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];    \
        XCTAssertFalse([gitignoreContents containsString:S7ControlFileName]);   \
        XCTAssertFalse([gitignoreContents containsString:S7BakFileName]);       \
    }                                                                           \
                                                                                \
    if ([fileManager fileExistsAtPath:@".gitattributes"]) {                     \
        NSString *gitattributesContents = [NSString stringWithContentsOfFile:@".gitattributes" encoding:NSUTF8StringEncoding error:nil]; \
        XCTAssertFalse([gitattributesContents containsString:@"s7"]);           \
    }                                                                           \
                                                                                \
    if ([fileManager fileExistsAtPath:@".git/config"]) {                        \
        NSString *configContents = [NSString stringWithContentsOfFile:@".git/config" encoding:NSUTF8StringEncoding error:nil];  \
        XCTAssertFalse([configContents containsString:@"s7"]);                  \
    }                                                                           \
                                                                                \
    NSArray<NSString *> *hookFileNames = @[                                     \
        @"post-checkout",                                                       \
        @"post-commit",                                                         \
        @"post-merge",                                                          \
        @"prepare-commit-msg",                                                  \
        @"pre-push"                                                             \
    ];                                                                          \
    for (NSString *hookName in hookFileNames) {                                 \
        NSString *hookFilePath = [NSString stringWithFormat:@".git/hooks/%@", hookName];    \
        if ([fileManager fileExistsAtPath:hookFilePath]) {                                  \
            NSString *hookFileContents = [NSString stringWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];  \
            XCTAssertFalse([hookFileContents containsString:@"s7"]);            \
        }                                                                       \
    }                                                                           \
}                                                                               \
while(0);

NSString *stringByRemovingEmptyLines(NSString *string) {
    NSMutableArray *resultLines = [NSMutableArray new];
    [string enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (0 == [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length) {
            return;
        }

        [resultLines addObject:line];
    }];

    return [resultLines componentsJoinedByString:@"\n"];
}

BOOL areStringEqualIgnoringEmptyLines(NSString *yellow, NSString *blue) {
    return [stringByRemovingEmptyLines(yellow) isEqualToString:stringByRemovingEmptyLines(blue)];
}


#pragma mark -

- (void)testCreate {
    S7DeinitCommand *command = [S7DeinitCommand new];
    XCTAssertNotNil(command);
}

- (void)testAssertion {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        assertRepoAtPWDIsFreeFromS7();
        return 0;
    });
}

- (void)testOnVirginNonS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7DeinitCommand *command = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);
        return 0;
    });
}

- (void)testOnSimpleS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        S7InitCommand *initCommand = [S7InitCommand new];
        XCTAssertEqual(0, [initCommand runWithArguments:@[]]);

        S7DeinitCommand *deinitCommand = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [deinitCommand runWithArguments:@[]]);

        assertRepoAtPWDIsFreeFromS7();
    }];
}

- (void)testOnSimpleS7RepoWithBackupFile {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        S7InitCommand *initCommand = [S7InitCommand new];
        XCTAssertEqual(0, [initCommand runWithArguments:@[]]);

        [NSFileManager.defaultManager createFileAtPath:S7BakFileName contents:nil attributes:nil];

        S7DeinitCommand *deinitCommand = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [deinitCommand runWithArguments:@[]]);

        assertRepoAtPWDIsFreeFromS7();
    }];
}

- (void)testOnS7PlusGitLFSRepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prePushHookFilePath = @".git/hooks/pre-push";
        NSString *expectedGitLfsPrePushHookContents =
        @"#!/bin/sh\n"
        "command -v git-lfs >/dev/null 2>&1 || { echo >&2 \"\nThis repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting .git/hooks/pre-push.\n\"; exit 2; }"
        "git lfs pre-push \"$@\"";
        if (NO == [expectedGitLfsPrePushHookContents writeToFile:prePushHookFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            XCTFail(@"FATAL: failed to setup 'Git LFS' repo");
            return;
        }

        S7InitCommand *initCommand = [S7InitCommand new];
        XCTAssertEqual(0, [initCommand runWithArguments:@[]]);

        S7DeinitCommand *deinitCommand = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [deinitCommand runWithArguments:@[]]);

        assertRepoAtPWDIsFreeFromS7();

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:prePushHookFilePath],
                      @"deinit must not have removed pre-push hook, as Git LFS lived there");
        NSString *actualPrePushHookContents = [[NSString alloc] initWithContentsOfFile:prePushHookFilePath encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(areStringEqualIgnoringEmptyLines(actualPrePushHookContents, expectedGitLfsPrePushHookContents));
    }];
}

- (void)testOnRepoWithPureGitLfsHook {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prePushHookFilePath = @".git/hooks/pre-push";
        NSString *expectedGitLfsPrePushHookContents =
        @"#!/bin/sh\n"
        "command -v git-lfs >/dev/null 2>&1 || { echo >&2 \"\nThis repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting .git/hooks/pre-push.\n\"; exit 2; }"
        "git lfs pre-push \"$@\"";
        if (NO == [expectedGitLfsPrePushHookContents writeToFile:prePushHookFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            XCTFail(@"FATAL: failed to setup 'Git LFS' repo");
            return;
        }

        S7DeinitCommand *deinitCommand = [S7DeinitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [deinitCommand runWithArguments:@[]]);

        assertRepoAtPWDIsFreeFromS7();

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:prePushHookFilePath],
                      @"deinit must not have removed pre-push hook, as Git LFS lived there");
        NSString *actualPrePushHookContents = [[NSString alloc] initWithContentsOfFile:prePushHookFilePath encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(actualPrePushHookContents, expectedGitLfsPrePushHookContents);
    }];
}

@end
