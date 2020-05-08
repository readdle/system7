//
//  addTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7AddCommand.h"
#import "S7Parser.h"

#import "TestReposEnvironment.h"

@interface addTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation addTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreate {
    S7AddCommand *command = [S7AddCommand new];
    XCTAssertNotNil(command);
}

- (void)testWithoutMandatoryArguments {
    S7AddCommand *command = [S7AddCommand new];
    XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);
}

- (void)testAddExistingNonGitRepoAsSubrepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        NSError *error = nil;
        XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:@"Dependencies/ReaddleLib"
                                                withIntermediateDirectories:YES
                                                                 attributes:nil
                                                                      error:&error]);

        S7AddCommand *command = [S7AddCommand new];
        XCTAssertEqual(S7ExitCodeSubrepoIsNotGitRepository, [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]]);
    });
}

- (void)testAddAlreadyClonedRepoWithJustDirectoryPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, initialConfig.subrepoDescriptions.count);

        int cloneExitStatus = 0;
        GitRepository *readdleLibRepo = [GitRepository
                                         cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                         destinationPath:@"Dependencies/ReaddleLib"
                                         exitStatus:&cloneExitStatus];
        XCTAssertNotNil(readdleLibRepo);
        XCTAssertEqual(0, cloneExitStatus);

        S7AddCommand *command = [S7AddCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]]);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        NSString *expectedInitialRevision = nil;
        [self.env.githubReaddleLibRepo getCurrentRevision:&expectedInitialRevision];
        S7SubrepoDescription *expectedDescription = [[S7SubrepoDescription alloc]
                                                     initWithPath:@"Dependencies/ReaddleLib"
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:expectedInitialRevision
                                                     branch:nil];
        XCTAssertEqualObjects(expectedDescription,
                              newConfig.subrepoDescriptions.firstObject);

    });
}

- (void)testAddRepoWithUrlAndPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, initialConfig.subrepoDescriptions.count);

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath ]];
        XCTAssertEqual(0, addResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        NSString *expectedInitialRevision = nil;
        [self.env.githubReaddleLibRepo getCurrentRevision:&expectedInitialRevision];
        S7SubrepoDescription *expectedDescription = [[S7SubrepoDescription alloc]
                                                     initWithPath:@"Dependencies/ReaddleLib"
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:expectedInitialRevision
                                                     branch:nil];
        XCTAssertEqualObjects(expectedDescription,
                              newConfig.subrepoDescriptions.firstObject);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location,
                       @"must be added to .gitignore just once");
    });
}

- (void)testAddRepoWithUrlAndPathBranch {
    __block NSString *expectedRevision = nil;
    executeInDirectory(self.env.root, ^int {
        int cloneExitStatus = 0;
        GitRepository *tempReaddleLibRepo = [GitRepository
                                             cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                             destinationPath:@"ReaddleLib"
                                             exitStatus:&cloneExitStatus];
        XCTAssertNotNil(tempReaddleLibRepo);
        XCTAssertEqual(0, cloneExitStatus);

        XCTAssertEqual(0, [tempReaddleLibRepo checkoutNewLocalBranch:@"feature/mac"]);
        XCTAssertEqual(0, [tempReaddleLibRepo createFile:@"RDSystemInformation.h" withContents:nil]);
        XCTAssertEqual(0, [tempReaddleLibRepo add:@[ @"RDSystemInformation.h" ]]);
        [tempReaddleLibRepo commitWithMessage:@"add RDSystemInformation.h, lorem ipsum, etc."];
        XCTAssertEqual(0, [tempReaddleLibRepo pushAll]);

        [tempReaddleLibRepo getCurrentRevision:&expectedRevision];
    });

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, initialConfig.subrepoDescriptions.count);

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath, @"feature/mac" ]];
        XCTAssertEqual(0, addResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        S7SubrepoDescription *expectedSubrepoDesc =
            [[S7SubrepoDescription alloc]
             initWithPath:@"Dependencies/ReaddleLib"
             url:self.env.githubReaddleLibRepo.absolutePath
             revision:expectedRevision
             branch:@"feature/mac"];
        XCTAssertEqualObjects(expectedSubrepoDesc,
                              newConfig.subrepoDescriptions.firstObject);

    });
}

- (void)testGitIgnoredIsUpdatedProperly {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init();

        NSString *typicalGitIgnoreContent = @".DS_Store\n"
                                             "*.pbxuser\n"
                                             "*.orig\n";

        XCTAssertTrue([typicalGitIgnoreContent writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:nil]);

        s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        s7add(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);

        for (NSString *subrepoPath in @[ @"Dependencies/RDPDFKit", @"Dependencies/ReaddleLib"]) {
            XCTAssertNotEqual([gitignoreContents rangeOfString:subrepoPath].location, NSNotFound);
            XCTAssertEqual([gitignoreContents rangeOfString:subrepoPath options:NSBackwardsSearch].location,
                           [gitignoreContents rangeOfString:subrepoPath].location,
                           @"must be added to .gitignore just once");
        }

        XCTAssert([gitignoreContents rangeOfString:typicalGitIgnoreContent].location != NSNotFound);
    });
}

@end
