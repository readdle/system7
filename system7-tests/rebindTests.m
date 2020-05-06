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
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *fileName = @"RDGeometry.h";
        XCTAssertEqual(0, [subrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [subrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [subrepoGit commitWithMessage:@"add geometry utils"]);
        NSString *readdleLibRevision = nil;
        XCTAssertEqual(0, [subrepoGit getCurrentRevision:&readdleLibRevision]);

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
        s7init();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *fileName = @"RDGeometry.h";
        XCTAssertEqual(0, [readdleLibSubrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [readdleLibSubrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [readdleLibSubrepoGit commitWithMessage:@"add geometry utils"]);
        NSString *readdleLibRevision = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&readdleLibRevision]);

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        fileName = @"RDPDFAnnotation.h";
        XCTAssertEqual(0, [pdfKitSubrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [pdfKitSubrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [pdfKitSubrepoGit commitWithMessage:@"add annotations"]);
        NSString *pdfKitRevision = nil;
        XCTAssertEqual(0, [pdfKitSubrepoGit getCurrentRevision:&pdfKitRevision]);


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
    });
}

- (void)testRebindJustOneSubreposAtATime {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *fileName = @"RDGeometry.h";
        XCTAssertEqual(0, [readdleLibSubrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [readdleLibSubrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [readdleLibSubrepoGit commitWithMessage:@"add geometry utils"]);
        NSString *readdleLibRevision = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&readdleLibRevision]);

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        S7Config *initialConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        fileName = @"RDPDFAnnotation.h";
        XCTAssertEqual(0, [pdfKitSubrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [pdfKitSubrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [pdfKitSubrepoGit commitWithMessage:@"add annotations"]);
        NSString *pdfKitRevision = nil;
        XCTAssertEqual(0, [pdfKitSubrepoGit getCurrentRevision:&pdfKitRevision]);


        S7RebindCommand *rebindCommand = [S7RebindCommand new];
        XCTAssertEqual(0, [rebindCommand runWithArguments:@[ pdfKitSubrepoPath ]]);

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
    });
}

- (void)testRebindSubrepoSwitchedToDifferentBranch {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *fileName = @"RDGeometry.h";
        XCTAssertEqual(0, [subrepoGit checkoutNewLocalBranch:@"feature/geometry"]);
        XCTAssertEqual(0, [subrepoGit createFile:fileName withContents:nil]);
        XCTAssertEqual(0, [subrepoGit add:@[ fileName ]]);
        XCTAssertEqual(0, [subrepoGit commitWithMessage:@"add geometry utils"]);
        NSString *readdleLibRevision = nil;
        XCTAssertEqual(0, [subrepoGit getCurrentRevision:&readdleLibRevision]);

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

@end
