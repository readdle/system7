//
//  statusTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"
#import "S7StatusCommand.h"

#import "TestReposEnvironment.h"
#import "Utils.h"
#import "Git.h"

#define FULL_STOP_FAIL()                \
    self.continueAfterFailure = NO;     \
    XCTFail();

@interface statusTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation statusTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    
}

#pragma mark -

- (void)testCreate {
    S7StatusCommand *statusCommand = [S7StatusCommand new];
    XCTAssertNotNil(statusCommand);
}

- (void)testCheckStatusOnNonS7Repo {
    S7StatusCommand *statusCommand = [S7StatusCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [statusCommand runWithArguments:@[]]);
}

- (void)testStatusOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *initCommand = [S7InitCommand new];
        [initCommand runWithArguments:@[]];

        S7StatusCommand *statusCommand = [S7StatusCommand new];
        XCTAssertEqual(0, [statusCommand runWithArguments:@[]]);
    });
}

- (void)testStatusOnDirtyEmptyMainRepo {
    // changes in main repo do not bother s7

    [self.env.pasteyRd2Repo createFile:@"file" withContents:nil];
    [self.env.pasteyRd2Repo add:@[@"file"]];

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *initCommand = [S7InitCommand new];
        [initCommand runWithArguments:@[]];

        S7StatusCommand *statusCommand = [S7StatusCommand new];
        XCTAssertEqual(0, [statusCommand runWithArguments:@[]]);
    });
}

// test on repo with clear subrepo
// test on repo with commited local changes (should I warn about anything?)
// test on repo with uncommitted local changes
// test on repo with untracked local files

@end
