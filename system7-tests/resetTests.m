//
//  resetTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 02.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7ResetCommand.h"

@interface resetTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation resetTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7ResetCommand *command = [S7ResetCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7ResetCommand *command = [S7ResetCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testRequiredArguments {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(S7ExitCodeMissingRequiredArgument, [command runWithArguments:@[]]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testInvalidArguments {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(S7ExitCodeInvalidArgument, [command runWithArguments:@[ @"Dependencies/NoSuch" ]]);

        int exitStatus = [command runWithArguments:@[ @"-X", @"Dependencies/NoSuch", @"--all" ]];
        XCTAssertEqual(S7ExitCodeInvalidParameterValue, exitStatus);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testEitherAllOrPathArgument_NotBoth {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        GitRepository *pdfKitGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"AP/N", @"annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add subrepos"];

        [readdleLibGit createFile:@"RDGeometry.h" withContents:@"sqrt"];
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"kaka", @"accidential commit");


        S7ResetCommand *command = [S7ResetCommand new];
        const int exitStatus = [command runWithArguments:@[ @"--all", @"Dependencies/ReaddleLib" ]];
        XCTAssertEqual(S7ExitCodeInvalidArgument, exitStatus);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"sqrt");

        NSString *RDPDFAnnotationContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/RDPDFKit/RDPDFAnnotation.h"
                                                                            encoding:NSUTF8StringEncoding
                                                                               error:nil];
        XCTAssertEqualObjects(RDPDFAnnotationContents, @"kaka");
    }];
}

- (void)testSpecificSubrepoReset {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        GitRepository *pdfKitGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"AP/N", @"annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add subrepos"];

        [readdleLibGit createFile:@"RDGeometry.h" withContents:@"sqrt"];
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"kaka", @"accidential commit");


        S7ResetCommand *command = [S7ResetCommand new];
        const int exitStatus = [command runWithArguments:@[ @"Dependencies/RDPDFKit" ]];
        XCTAssertEqual(0, exitStatus);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"sqrt");

        NSString *RDPDFAnnotationContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/RDPDFKit/RDPDFAnnotation.h"
                                                                            encoding:NSUTF8StringEncoding
                                                                               error:nil];
        XCTAssertEqualObjects(RDPDFAnnotationContents, @"AP/N");
    }];
}

- (void)testResetAllExceptOne {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        GitRepository *pdfKitGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"AP/N", @"annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add subrepos"];

        [readdleLibGit createFile:@"RDGeometry.h" withContents:@"sqrt"];
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"kaka", @"accidential commit");


        S7ResetCommand *command = [S7ResetCommand new];
        const int exitStatus = [command runWithArguments:@[ @"--all", @"-X", @"Dependencies/RDPDFKit" ]];
        XCTAssertEqual(0, exitStatus);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");

        NSString *RDPDFAnnotationContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/RDPDFKit/RDPDFAnnotation.h"
                                                                            encoding:NSUTF8StringEncoding
                                                                               error:nil];
        XCTAssertEqualObjects(RDPDFAnnotationContents, @"kaka");
    }];
}

- (void)testResetUncommittedLocalChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(subrepoGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"init ReaddeLib"];

        [subrepoGit createFile:@"RDGeometry.h" withContents:@"sqrt"];

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");
    }];
}

- (void)testResetUntrackedFiles {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(subrepoGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"init ReaddeLib"];

        [subrepoGit createFile:@"experiment.c" withContents:@"wild experiment"];

        NSString *untrackedFolderPath = [subrepoGit.absolutePath stringByAppendingPathComponent:@"a"];
        NSString *untrackedSubFolderPath = [untrackedFolderPath stringByAppendingPathComponent:@"a"];
        NSError *error = nil;
        [NSFileManager.defaultManager
         createDirectoryAtPath:untrackedSubFolderPath
         withIntermediateDirectories:YES
         attributes:nil
         error:&error];
        XCTAssert(nil == error, @"");

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib/experiment.c"]);

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib/experiment.c"]);
        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:untrackedFolderPath]);
    }];
}

- (void)testResetBothUntrackedFilesAndUncommittedChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(subrepoGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"init ReaddeLib"];

        [subrepoGit createFile:@"RDGeometry.h" withContents:@"sqrt"];
        [subrepoGit createFile:@"experiment.c" withContents:@"wild experiment"];

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib/experiment.c"]);

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/ReaddleLib/experiment.c"]);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");
    }];
}


- (void)testResetCommittedLocalChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"init ReaddeLib"];

        commit(subrepoGit, @"RDGeometry.h", @"sqrt", @"add geometry utils");

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");

        NSString *actualReaddleLibRevision = nil;
        [subrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLibRevision);
    }];
}

- (void)testResetReboundButNotCommittedSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *initialReaddleLibRevision = commit(readdleLibGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");

        GitRepository *pdfKitGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitGit, @"RDPDFAnnotation.h", @"AP/N", @"annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add ReaddeLib subrepo"];

        commit(readdleLibGit, @"RDGeometry.h", @"kaka", @"accidental changes");
        NSString *expectedPdfKitCommit = commit(pdfKitGit, @"RDPDFAnnotation.h", @"/F 4", @"flags");

        s7rebind_with_stage();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"Dependencies/ReaddleLib" ]]);


        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");

        NSString *RDPDFAnnotationContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/RDPDFKit/RDPDFAnnotation.h"
                                                                            encoding:NSUTF8StringEncoding
                                                                               error:nil];
        XCTAssertEqualObjects(RDPDFAnnotationContents, @"/F 4");


        NSString *actualReaddleLibRevision = nil;
        [readdleLibGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, initialReaddleLibRevision);

        NSString *actualPDFKitRevision = nil;
        [pdfKitGit getCurrentRevision:&actualPDFKitRevision];
        XCTAssertEqualObjects(actualPDFKitRevision, expectedPdfKitCommit);

        S7Config *expectedConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib"
                                                   url:self.env.githubReaddleLibRepo.absolutePath
                                              revision:initialReaddleLibRevision
                                                branch:@"main"],
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/RDPDFKit"
                                                   url:self.env.githubRDPDFKitRepo.absolutePath
                                              revision:expectedPdfKitCommit // PDFKit was not reset, so it should stay rebound
                                                branch:@"main"]
        ]];

        S7Config *mainConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(mainConfig, expectedConfig);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertEqualObjects(controlConfig, expectedConfig);
    }];
}

- (void)testResetDetachedHeadInSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *subrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddeLib"];

        NSString *firstCommitInReaddleLib = commit(subrepoGit, @"RDGeometry.h", @"tabula rasa", @"add geometry utils");
        s7rebind_with_stage();

        commit(subrepoGit, @"RDGeometry.h", @"sqrt", @"math");

        [repo commitWithMessage:@"up ReaddeLib"];

        [subrepoGit checkoutRevision:firstCommitInReaddleLib];

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/ReaddleLib/RDGeometry.h"
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil];
        XCTAssertEqualObjects(RDGeometryContents, @"tabula rasa");
    }];
}

- (void)testResetChangesInSubSubrepo {
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

        // add RDPDFKit twice to be sure that we also test dispatch_apply parallel work inside reset.
        // If we have just one subrepo, then dispatch_apply is too smart and simply runs the only operation
        // straight on the calling thread.
        s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        s7add_stage(@"Dependencies/RDPDFKit2", self.env.githubRDPDFKitRepo.absolutePath);

        GitRepository *formCalcSubrepoGit = [GitRepository repoAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc"];
        XCTAssertNotNil(formCalcSubrepoGit);

        [repo commitWithMessage:@"add PDFKit subrepo"];

        [formCalcSubrepoGit createFile:@"Trash" withContents:@"asdf"];
        commit(formCalcSubrepoGit, @"Parser.c", @"wild experiment", @"expertiment");

        XCTAssertTrue([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc/Trash"]);

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);

        XCTAssertFalse([NSFileManager.defaultManager fileExistsAtPath:@"Dependencies/RDPDFKit/Dependencies/FormCalc/Trash"]);
        NSString *actualParserContents = [[NSString alloc] initWithContentsOfFile:@"Dependencies/RDPDFKit/Dependencies/FormCalc/Parser.c" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(@"AST", actualParserContents);
    }];
}

@end
