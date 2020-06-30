//
//  removeTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 06.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7RemoveCommand.h"

#import "TestReposEnvironment.h"

@interface removeTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation removeTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreate {
    S7RemoveCommand *command = [S7RemoveCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7RemoveCommand *command = [S7RemoveCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[@"no-such"]]);
}

- (void)testWithoutMandatoryArguments {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7RemoveCommand *command = [S7RemoveCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);
    }];
}

- (void)testUnknownSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7RemoveCommand *command = [S7RemoveCommand new];
        XCTAssertEqual(S7ExitCodeInvalidArgument, [command runWithArguments:@[ @"no-such" ]]);
    }];
}

- (void)testRemoveValidSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *typicalGitIgnoreContent =
            @".DS_Store\n"
             "*.pbxuser\n"
             "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, initialConfig.subrepoDescriptions.count);

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        // also test input paths' standartization
        const int removeResult = [removeCommand runWithArguments:@[ @"Dependencies/ReaddleLib/" ]];
        XCTAssertEqual(0, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

- (void)testRemoveWithUncommittedLocalChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *typicalGitIgnoreContent =
        @".DS_Store\n"
        "*.pbxuser\n"
        "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibInitialRevision = nil;
        [readdleLibGit getCurrentRevision:&readdleLibInitialRevision];

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [readdleLibGit createFile:@"RDGeometry" withContents:@"👨‍🏫"];

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        const int removeResult = [removeCommand runWithArguments:@[ @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(S7ExitCodeSubrepoHasLocalChanges, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        NSString *actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLibInitialRevision);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

- (void)testRemoveWithUncommittedLocalChangesForce {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *typicalGitIgnoreContent =
        @".DS_Store\n"
        "*.pbxuser\n"
        "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibInitialRevision = nil;
        [readdleLibGit getCurrentRevision:&readdleLibInitialRevision];

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [readdleLibGit createFile:@"RDGeometry" withContents:@"👨‍🏫"];

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        const int removeResult = [removeCommand runWithArguments:@[ @"-f", @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(0, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

- (void)testRemoveWithNotPushedLocalChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *typicalGitIgnoreContent =
        @".DS_Store\n"
        "*.pbxuser\n"
        "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *expectedReaddleLibRevision = commit(readdleLibGit, @"RDGeometry", @"RDRectArea", @"rect area");

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        const int removeResult = [removeCommand runWithArguments:@[ @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(S7ExitCodeSubrepoHasLocalChanges, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        readdleLibGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibGit);
        NSString *actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, expectedReaddleLibRevision);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

- (void)testRemoveWithNotPushedLocalChangesForce {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
        
        NSString *typicalGitIgnoreContent =
        @".DS_Store\n"
        "*.pbxuser\n"
        "*.orig\n";

        [typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil];

        GitRepository *readdleLibGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibInitialRevision = nil;
        [readdleLibGit getCurrentRevision:&readdleLibInitialRevision];

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        commit(readdleLibGit, @"RDGeometry", @"RDRectArea", @"rect area");

        S7RemoveCommand *removeCommand = [S7RemoveCommand new];
        const int removeResult = [removeCommand runWithArguments:@[ @"-f", @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(0, removeResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib"]);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertNotEqual(NSNotFound, [gitignoreContents rangeOfString:typicalGitIgnoreContent].location);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

@end
