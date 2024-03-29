//
//  initTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"
#import "S7PostCommitHook.h"
#import "S7PostMergeHook.h"

#import "TestReposEnvironment.h"

@interface initTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation initTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    
}

#pragma mark -

- (void)testCreate {
    S7InitCommand *statusCommand = [S7InitCommand new];
    XCTAssertNotNil(statusCommand);
}

- (void)testOnVirginRepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        return S7ExitCodeSuccess;
    });

    [self assertRepoAtPathHasAllProperSystemFiles:self.env.pasteyRd2Repo.absolutePath];
}

- (void)testOnVirginRepoWithADifferentWorkingDir {
    // init pastey's repo with the working dir in nik's repo
    executeInDirectory(self.env.nikRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[] inRepo:self.env.pasteyRd2Repo]);
        return S7ExitCodeSuccess;
    });

    [self assertRepoAtPathHasAllProperSystemFiles:self.env.pasteyRd2Repo.absolutePath];
}

- (void)testOnAlreadyInitializedRepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        S7Config *actualConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(actualConfig);


        command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@".s7control"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@".s7control" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@".s7control"].location,
                       @"must be added to .gitignore just once");

        NSString *configContents = [[NSString alloc]
                                    initWithData:[NSFileManager.defaultManager contentsAtPath:@".git/config"]
                                    encoding:NSUTF8StringEncoding];
        XCTAssertTrue([configContents containsString:@"[merge \"s7\"]"]);
        XCTAssertEqual([configContents rangeOfString:@"[merge \"s7\"]" options:NSBackwardsSearch].location,
                       [configContents rangeOfString:@"[merge \"s7\"]"].location,
                       @"must be added to .git/config just once");

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(actualConfig, controlConfig); // re-init must not overwrite existing control file contents
    }];
}

- (void)testInitOnRepoWithOldStyleGitHooks {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *oldStyleHookContents = @"#!/bin/sh\n"
                                          "/usr/local/bin/s7 pre-push-hook \"$@\" <&0";
        [oldStyleHookContents writeToFile:@".git/hooks/pre-push" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);

        NSString *installedHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/pre-push" encoding:NSUTF8StringEncoding error:nil];
        NSString *expectedResultingHookContents =
        @"#!/bin/sh\n"
        "\n"
        "/usr/local/bin/s7 pre-push-hook \"$@\" <&0 || exit $?\n";

        XCTAssertEqualObjects(installedHookContents, expectedResultingHookContents);
    }];
}

- (void)testInitOnRepoWithExistingGitLFSHook_MustMergeInS7Call {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *gitLFSHookContents =
        @"#!/bin/sh\n"
        "command -v git-lfs >/dev/null 2>&1 || { echo >&2 \"\nThis repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting .git/hooks/pre-push.\n\"; exit 2; }\n"
        "git lfs pre-push \"$@\"\n";
        [gitLFSHookContents writeToFile:@".git/hooks/pre-push" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);

        NSString *installedHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/pre-push" encoding:NSUTF8StringEncoding error:nil];

        NSString *expectedResultingHookContents =
        @"#!/bin/sh\n"
        "\n"
        "/usr/local/bin/s7 pre-push-hook \"$@\" <&0 || exit $?\n"
        "\n"
        "command -v git-lfs >/dev/null 2>&1 || { echo >&2 \"\nThis repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting .git/hooks/pre-push.\n\"; exit 2; }\n"
        "git lfs pre-push \"$@\"\n";

        XCTAssertEqualObjects(installedHookContents, expectedResultingHookContents);
    }];
}

- (void)testInitOnRepoWithNonBinShSheBang {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [@"#!/bin/ruby\nputs \"Hello World\"" writeToFile:@".git/hooks/pre-push" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeFileOperationFailed, [command runWithArguments:@[]]);
    }];
}

- (void)testInitOnRepoThatHasNoSheBang {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *existingHookContents = @"дулі-дулі, дулі вам!";
        [existingHookContents writeToFile:@".git/hooks/pre-push" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeFileOperationFailed, [command runWithArguments:@[]]);

        NSString *installedHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/pre-push" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue([installedHookContents containsString:existingHookContents]);
    }];
}

- (void)testInitForceOnRepoThatHasCustomGitHooks {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [@"дулі-дулі, дулі вам!" writeToFile:@".git/hooks/pre-push" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[ @"--force" ]]);

        NSString *installedHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/pre-push" encoding:NSUTF8StringEncoding error:nil];
        NSString *expectedHookCallCommandPart = [NSString stringWithFormat:@"s7 %@-hook", [S7PrePushHook gitHookName]];
        XCTAssertTrue([installedHookContents containsString:expectedHookCallCommandPart]);
        XCTAssertFalse([installedHookContents containsString:@"дулі-дулі"]);
    }];
}

- (void)testFirstInitOnLocalCopyRunsCheckout {
    __block NSString *expectedReaddleLibRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        expectedReaddleLibRevision = commit(subrepoGit, @"RDGeometry.h", @"sqrt", @"math is hard");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [subrepoGit pushCurrentBranch];
        [repo pushCurrentBranch];
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        S7Config *config = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, config.subrepoDescriptions.count);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        s7init_deactivateHooks();

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);
        GitRepository *subrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(subrepoGit);
        NSString *actualReaddleLibRevsions = nil;
        [subrepoGit getCurrentRevision:&actualReaddleLibRevsions];
        XCTAssertEqualObjects(actualReaddleLibRevsions, expectedReaddleLibRevision);
    }];
}

- (void)testRecursiveInit {
    int cloneExitStatus = 0;
    GitRepository *pdfKitRepo = [GitRepository cloneRepoAtURL:self.env.githubRDPDFKitRepo.absolutePath destinationPath:[self.env.root stringByAppendingPathComponent:@"pastey/rdpdfkit"] exitStatus:&cloneExitStatus];
    XCTAssertEqual(0, cloneExitStatus);
    XCTAssertNotNil(pdfKitRepo);

    __block NSString *expectedFormCalcRevision = nil;
    [pdfKitRepo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add_stage(@"Dependencies/FormCalc", self.env.githubFormCalcRepo.absolutePath);

        [repo commitWithMessage:@"add FormCalc subrepo"];

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        expectedFormCalcRevision = commit(formCalcSubrepoGit, @"Parser.c", @"AST", @"ast");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up FormCalc"];

        [formCalcSubrepoGit pushCurrentBranch];
        [repo pushCurrentBranch];
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        [repo commitWithMessage:@"add PDFKit subrepo"];

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        NSString *actualFormCalcRevision = nil;
        [formCalcSubrepoGit getCurrentRevision:&actualFormCalcRevision];
        XCTAssertEqualObjects(actualFormCalcRevision, expectedFormCalcRevision);

        [repo pushCurrentBranch];
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        XCTAssertEqual(0, s7init_deactivateHooks());

        // smoke test that hooks in subrepo have been installed
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/RDPDFKit/.git/hooks/post-checkout"]);

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        NSString *actualFormCalcRevision = nil;
        [formCalcSubrepoGit getCurrentRevision:&actualFormCalcRevision];
        XCTAssertEqualObjects(actualFormCalcRevision, expectedFormCalcRevision);
    }];
}

- (void)testInRepoWithoutGitHooksDirectory {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        // one of our developers cloned repo using SourceTree and then 's7 init' failed,
        // 'cause there was no .git/hook dir
        XCTAssertTrue([NSFileManager.defaultManager removeItemAtPath:@".git/hooks" error:nil]);

        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
    }];
}

#pragma mark - assertions -

- (void)assertRepoAtPathHasAllProperSystemFiles:(NSString *)absoluteRepoPath {
    executeInDirectory(absoluteRepoPath, ^int{
        BOOL isDirectory = NO;
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);
        
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);
        
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7BootstrapFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@".gitignore" isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:S7ControlFileName].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:S7ControlFileName options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:S7ControlFileName].location,
                       @"must be added to .gitignore just once");
        
        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName isDirectory:&isDirectory]);
        XCTAssertFalse(isDirectory);
        
        S7Config *config = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertNotNil(config);
        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(config, controlConfig);
        
        NSSet<Class<S7Hook>> *hookClasses = [NSSet setWithArray:@[
            [S7PrePushHook class],
            [S7PostCheckoutHook class],
            [S7PostCommitHook class],
            [S7PostMergeHook class],
        ]];
        
        for (Class<S7Hook> hookClass in hookClasses) {
            NSString *gitHookName = [hookClass gitHookName];
            NSString *actualHookContents = [[NSString alloc]
                                            initWithData:[NSFileManager.defaultManager contentsAtPath:[@".git/hooks" stringByAppendingPathComponent:gitHookName]]
                                            encoding:NSUTF8StringEncoding];
            NSString *expectedHookCallCommandPart = [NSString stringWithFormat:@"s7 %@-hook", gitHookName];
            XCTAssertTrue([actualHookContents containsString:expectedHookCallCommandPart]);
        }
        
        NSString *configContents = [[NSString alloc]
                                    initWithData:[NSFileManager.defaultManager contentsAtPath:@".git/config"]
                                    encoding:NSUTF8StringEncoding];
        XCTAssertTrue([configContents containsString:@"[merge \"s7\"]"]);

        NSString *gitattributesContents = [[NSString alloc]
                                           initWithData:[NSFileManager.defaultManager contentsAtPath:@".gitattributes"]
                                           encoding:NSUTF8StringEncoding];
        XCTAssertTrue([gitattributesContents containsString:@"merge=s7"]);
        XCTAssertTrue([gitattributesContents containsString:@"filter=s7"]);

        return 0;
    });
}

@end
