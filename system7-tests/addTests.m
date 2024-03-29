//
//  addTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7AddCommand.h"
#import "S7Config.h"

#import "TestReposEnvironment.h"

@interface addTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation addTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCreate {
    S7AddCommand *command = [S7AddCommand new];
    XCTAssertNotNil(command);
}

- (void)testWithoutMandatoryArguments {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        S7AddCommand *command = [S7AddCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);

        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[ @"--stage" ]]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddExistingNonGitRepoAsSubrepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        NSError *error = nil;
        XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:@"Dependencies/ReaddleLib"
                                                withIntermediateDirectories:YES
                                                                 attributes:nil
                                                                      error:&error]);

        S7AddCommand *command = [S7AddCommand new];
        XCTAssertEqual(S7ExitCodeSubrepoIsNotGitRepository, [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddAlreadyClonedRepoWithJustDirectoryPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

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
                                                     branch:@"main"];
        XCTAssertEqualObjects(expectedDescription,
                              newConfig.subrepoDescriptions.firstObject);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddAlreadyClonedRepoWithNotAllowedTransportProtocol {
    GitRepository *localRepo = [self.env initializeLocalRepoAtRelativePath:@"user/projects/rd2"
                                       addCommandAllowedTransportProtocols:[NSSet setWithObject:S7TransportProtocolNameSSH]];
    
    executeInDirectory(localRepo.absolutePath, ^int {
        s7init_deactivateHooks();

        int cloneExitStatus = 0;
        GitRepository *readdleLibRepo = [GitRepository
                                         cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                         destinationPath:@"Dependencies/ReaddleLib"
                                         exitStatus:&cloneExitStatus];
        XCTAssertNotNil(readdleLibRepo);
        XCTAssertEqual(0, cloneExitStatus);

        S7AddCommand *command = [S7AddCommand new];
        XCTAssertEqual(S7ExitCodeInvalidArgument, [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddRepoWithURLWhichDoesNotMatchAllowedTransportProtocol {
    GitRepository *localRepo = [self.env initializeLocalRepoAtRelativePath:@"user/projects/rd2"
                                       addCommandAllowedTransportProtocols:[NSSet setWithObject:S7TransportProtocolNameSSH]];
    
    executeInDirectory(localRepo.absolutePath, ^int {
        s7init_deactivateHooks();

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath ]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, addResult);
        
        return addResult;
    });
}

- (void)testAddRepoWithURLWhichMatchesAllowedTransportProtocol {
    GitRepository *localRepo = [self.env initializeLocalRepoAtRelativePath:@"user/projects/rd2"
                                       addCommandAllowedTransportProtocols:[NSSet setWithObject:S7TransportProtocolNameLocal]];
    
    executeInDirectory(localRepo.absolutePath, ^int {
        s7init_deactivateHooks();

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath ]];
        XCTAssertEqual(0, addResult);
        
        return addResult;
    });
}

- (void)testAddRepoWithUrlAndPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

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
                                                     branch:@"main"];
        XCTAssertEqualObjects(expectedDescription,
                              newConfig.subrepoDescriptions.firstObject);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location,
                       @"must be added to .gitignore just once");
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddRepoWithUrlAndNotStandartizedPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        s7add(@"Dependencies/ReaddleLib/", self.env.githubReaddleLibRepo.absolutePath);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        NSString *expectedInitialRevision = nil;
        [self.env.githubReaddleLibRepo getCurrentRevision:&expectedInitialRevision];
        S7SubrepoDescription *expectedDescription = [[S7SubrepoDescription alloc]
                                                     initWithPath:@"Dependencies/ReaddleLib"
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:expectedInitialRevision
                                                     branch:@"main"];
        XCTAssertEqualObjects(expectedDescription,
                              newConfig.subrepoDescriptions.firstObject);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        // path has been standartized, and actual saved path has no trailing slash
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib/"].location, NSNotFound);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location,
                       @"must be added to .gitignore just once");
        
        return S7ExitCodeSuccess;
    });
}


- (void)testAddRepoWithUrlAndInvalidPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, initialConfig.subrepoDescriptions.count);

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"/Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath ]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, addResult);
        
        return addResult;
    });
}

- (void)testAddEmptyRepoWithUrlAndPath {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, initialConfig.subrepoDescriptions.count);

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"Dependencies/Bare", self.env.githubTestBareRepo.absolutePath ]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, addResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);
        
        return addResult;
    });
}

- (void)testAddRepoWithDetachedHEAD {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

        int cloneExitStatus = 0;
        GitRepository *readdleLibSubrepoGit = [GitRepository
                                             cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                             destinationPath:@"Dependencies/ReaddleLib"
                                             exitStatus:&cloneExitStatus];
        XCTAssertNotNil(readdleLibSubrepoGit);
        XCTAssertEqual(0, cloneExitStatus);

        NSString *initalRevisionInReaddleLib = nil;
        [readdleLibSubrepoGit getCurrentRevision:&initalRevisionInReaddleLib];

        commit(readdleLibSubrepoGit, @"RDGeomtry.h", @"RDRectArea", @"WIP");

        [readdleLibSubrepoGit checkoutRevision:initalRevisionInReaddleLib];



        S7AddCommand *command = [S7AddCommand new];
        int addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, addResult);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(0, newConfig.subrepoDescriptions.count);


        [readdleLibSubrepoGit checkoutExistingLocalBranch:@"main"];

        command = [S7AddCommand new];
        addResult = [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(S7ExitCodeSuccess, addResult);

        newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);
        
        return addResult;
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
        XCTAssertEqual(0, [tempReaddleLibRepo pushCurrentBranch]);

        [tempReaddleLibRepo getCurrentRevision:&expectedRevision];
        
        return S7ExitCodeSuccess;
    });

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();
        
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

        return S7ExitCodeSuccess;
    });
}

- (void)testGitIgnoredIsUpdatedProperly {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init_deactivateHooks();

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
        
        return S7ExitCodeSuccess;
    });
}

- (void)testAddWithStageOption {
    // without any options `s7 add` updates .s7substate and .gitignore and leaves user decide when to make `git add`
    // '--stage' option performs `git add .s7substate .gitignore`
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"--stage", @"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath ]];
        XCTAssertEqual(0, addResult);

        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *newRevision = nil;
        [repo getCurrentRevision:&newRevision];

        int dummy = 0;
        NSString *commitedConfigContents = [repo showFile:S7ConfigFileName atRevision:newRevision exitStatus:&dummy];

        S7Config *newConfig = [[S7Config alloc] initWithContentsString:commitedConfigContents];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        NSString *expectedReaddleLibRevision = nil;
        [self.env.githubReaddleLibRepo getCurrentRevision:&expectedReaddleLibRevision];

        S7SubrepoDescription *expectedSubrepoDesc = [[S7SubrepoDescription alloc]
                                                     initWithPath:@"Dependencies/ReaddleLib"
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:expectedReaddleLibRevision
                                                     branch:@"main"];
        XCTAssertEqualObjects(expectedSubrepoDesc, newConfig.subrepoDescriptions.firstObject);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);

        NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue(gitignoreContents.length > 0);
        XCTAssertNotEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location, NSNotFound);
        XCTAssertEqual([gitignoreContents rangeOfString:@"Dependencies/ReaddleLib" options:NSBackwardsSearch].location,
                       [gitignoreContents rangeOfString:@"Dependencies/ReaddleLib"].location,
                       @"must be added to .gitignore just once");
    }];
}

- (void)testAddAnotherS7Repo {
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

        S7AddCommand *command = [S7AddCommand new];
        const int addResult = [command runWithArguments:@[ @"--stage", @"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath ]];
        XCTAssertEqual(0, addResult);

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        NSString *actualFormCalcRevision = nil;
        [formCalcSubrepoGit getCurrentRevision:&actualFormCalcRevision];
        XCTAssertEqualObjects(actualFormCalcRevision, expectedFormCalcRevision);
    }];
}

@end
