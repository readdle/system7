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
    self.env = [TestReposEnvironment new];
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
    });
}

- (void)testOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[ @"--all" ]]);
    });
}

- (void)testInvalidArguments {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init_deactivateHooks();

        S7ResetCommand *command = [S7ResetCommand new];
        XCTAssertEqual(S7ExitCodeInvalidArgument, [command runWithArguments:@[ @"Dependencies/NoSuch" ]]);

        int exitStatus = [command runWithArguments:@[ @"-X", @"Dependencies/NoSuch", @"--all" ]];
        XCTAssertEqual(S7ExitCodeInvalidParameterValue, exitStatus);
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
                                                branch:@"master"],
            [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/RDPDFKit"
                                                   url:self.env.githubRDPDFKitRepo.absolutePath
                                              revision:expectedPdfKitCommit // PDFKit was not reset, so it should stay rebound
                                                branch:@"master"]
        ]];

        S7Config *mainConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
        XCTAssertEqualObjects(mainConfig, expectedConfig);

        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        XCTAssertEqualObjects(controlConfig, expectedConfig);
    }];
}

@end
