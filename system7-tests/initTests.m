//
//  initTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"

#import "TestReposEnvironment.h"

@interface initTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation initTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
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
    });
}

- (void)testOnAlreadyInitializedRepo {
    [self.env touch:[self.env.pasteyRd2Repo.absolutePath stringByAppendingPathComponent:S7ConfigFileName]];

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertNotEqual(0, [command runWithArguments:@[]]);
    });
}

@end
