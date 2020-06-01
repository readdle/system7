//
//  rebindTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>


#import "TestReposEnvironment.h"

#import "S7InitCommand.h"
#import "S7AddCommand.h"
#import "S7RebindCommand.h"

@interface rebindTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation rebindTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7RebindCommand *command = [S7RebindCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7RebindCommand *command = [S7RebindCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *initCommand = [S7InitCommand new];
        XCTAssertEqual(0, [initCommand runWithArguments:@[]]);

        S7RebindCommand *command = [S7RebindCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
    });
}

- (void)testRebindTheOnlySubrepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[]]);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        S7SubrepoDescription *expectedSubrepoDesc = [[S7SubrepoDescription alloc]
                                                     initWithPath:subrepoPath
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:readdleLibRevision
                                                     branch:@"master"];
        XCTAssertEqualObjects(expectedSubrepoDesc, newConfig.subrepoDescriptions.firstObject);
    });
}

- (void)testRebindAllSubreposAtOnce {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *readdleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        NSString *pdfKitRevision = commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", nil, @"add annotations");


        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[]]);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(2, newConfig.subrepoDescriptions.count);

        S7SubrepoDescription *expectedReaddleLibDesc = [[S7SubrepoDescription alloc]
                                                        initWithPath:readdleLibSubrepoPath
                                                        url:self.env.githubReaddleLibRepo.absolutePath
                                                        revision:readdleLibRevision
                                                        branch:@"master"];
        XCTAssertEqualObjects(expectedReaddleLibDesc, newConfig.pathToDescriptionMap[readdleLibSubrepoPath]);

        S7SubrepoDescription *expectedPDFKitDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:pdfKitSubrepoPath
                                                    url:self.env.githubRDPDFKitRepo.absolutePath
                                                    revision:pdfKitRevision
                                                    branch:@"master"];
        XCTAssertEqualObjects(expectedPDFKitDesc, newConfig.pathToDescriptionMap[pdfKitSubrepoPath]);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    });
}

- (void)testRebindJustOneSubreposAtATime {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        NSString *pdfKitRevision = commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", nil, @"add annotations");

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        // also test path standartization
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[ @"./Dependencies/RDPDFKit/" ]]);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(2, newConfig.subrepoDescriptions.count);

        XCTAssertEqualObjects(initialConfig.pathToDescriptionMap[readdleLibSubrepoPath],
                              newConfig.pathToDescriptionMap[readdleLibSubrepoPath],
                              @"ReaddleLib should stay intact");

        S7SubrepoDescription *expectedPDFKitDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:pdfKitSubrepoPath
                                                    url:self.env.githubRDPDFKitRepo.absolutePath
                                                    revision:pdfKitRevision
                                                    branch:@"master"];
        XCTAssertEqualObjects(expectedPDFKitDesc, newConfig.pathToDescriptionMap[pdfKitSubrepoPath]);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    });
}

- (void)testRebindSubrepoSwitchedToDifferentBranch {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        XCTAssertEqual(0, [subrepoGit checkoutNewLocalBranch:@"feature/geometry"]);
        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[]]);

        S7Config *newConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        S7SubrepoDescription *expectedSubrepoDesc = [[S7SubrepoDescription alloc]
                                                     initWithPath:subrepoPath
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:readdleLibRevision
                                                     branch:@"feature/geometry"];
        XCTAssertEqualObjects(expectedSubrepoDesc, newConfig.subrepoDescriptions.firstObject);
    });
}

- (void)testRebindWithStageOption {
    // without any options `s7 rebind` updates .s7substate and leaves user decide when to make `git add .s7substate`
    // '--stage' option performs `git add .s7substate`
    //
    // 'git commit' has '-a' option that states for '(a)dd to stage', but I don't want to use -a here as
    // it can be confused with '--all'. Like, `rebind all`. `rebind --stage` cannot be misread.
    //
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[ S7ConfigFileName, @".gitignore" ]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[ @"--stage" ]]);

        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *newRevision = nil;
        [repo getCurrentRevision:&newRevision];

        int dummy = 0;
        NSString *commitedConfigContents = [repo showFile:S7ConfigFileName atRevision:newRevision exitStatus:&dummy];

        S7Config *newConfig = [[S7Config alloc] initWithContentsString:commitedConfigContents];
        XCTAssertEqual(1, newConfig.subrepoDescriptions.count);

        S7SubrepoDescription *expectedSubrepoDesc = [[S7SubrepoDescription alloc]
                                                     initWithPath:subrepoPath
                                                     url:self.env.githubReaddleLibRepo.absolutePath
                                                     revision:readdleLibRevision
                                                     branch:@"master"];
        XCTAssertEqualObjects(expectedSubrepoDesc, newConfig.subrepoDescriptions.firstObject);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertNotNil(controlConfig);
        XCTAssertEqualObjects(newConfig, controlConfig);
    }];
}

- (void)testRebindSubrepoWithDetachedHead {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *commit1 = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"one", @"commit 1");
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"two", @"commit 2");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib"];

        [readdleLibSubrepoGit checkoutRevision:commit1];

        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(S7ExitCodeDetachedHEAD, [rebindCommand runWithArguments:@[]]);
    }];
}


@end
