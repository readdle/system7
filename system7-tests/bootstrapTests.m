//
//  bootstrapTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 27.11.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7BootstrapCommand.h"
#import "S7InitCommand.h"

#import "TestReposEnvironment.h"

@interface bootstrapTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation bootstrapTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        XCTAssertTrue([NSFileManager.defaultManager createFileAtPath:@".gitattributes" contents:nil attributes:nil]);
        
        return S7ExitCodeSuccess;
    });
}

// these tests are pure emulation – filter is not really called by Git

- (void)runBootstrap {
    S7BootstrapCommand *command = [S7BootstrapCommand new];
    command.runFakeFilter = YES;
    const int exitCode = [command runWithArguments:@[]];
    XCTAssertEqual(S7ExitCodeSuccess, exitCode);
}

- (BOOL)doesPostCheckoutHookContainInitCall {
    NSString *postCheckoutHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/post-checkout" encoding:NSUTF8StringEncoding error:nil];
    return [postCheckoutHookContents containsString:@"s7 init"];
}

- (void)testOnVirginRepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        [self runBootstrap];

        XCTAssertTrue([self doesPostCheckoutHookContainInitCall]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testOnLFSRepo_WITH_NO_LFSHooksInstalled {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        XCTAssert([@"*.mp4 filter=lfs diff=lfs merge=lfs -text" writeToFile:@".gitattributes" atomically:YES encoding:NSUTF8StringEncoding error:nil],
                  @"failed to install fake lfs filter");

        [self runBootstrap];

        XCTAssertFalse([self doesPostCheckoutHookContainInitCall]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testOnLFSRepo_WITH_LFSHooksInstalled {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        XCTAssert([@"*.mp4 filter=lfs diff=lfs merge=lfs -text"
                   writeToFile:@".gitattributes"
                   atomically:YES
                   encoding:NSUTF8StringEncoding
                   error:nil],
                  @"failed to install fake lfs filter");

        XCTAssert([NSFileManager.defaultManager
                   createFileAtPath:@".git/hooks/post-checkout"
                   contents:[@"#!/bin/sh\n"
                             "Git LFS was here" dataUsingEncoding:NSUTF8StringEncoding]
                   attributes:nil],
                  @"failed to install fake lfs hook");

        [self runBootstrap];

        XCTAssertTrue([self doesPostCheckoutHookContainInitCall]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testOnLFSRepoWithUnidentifiedPythonHooksInstalled {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        // - maybe there's some tool we don't know, which installs hooks before s7
        // - maybe user ran `git clone --template ...` and hooks were installed automatically
        // If hook is not a shell script, there's no way we can merge into it.
        //
        NSString *alienHook =
        @"#!/usr/local/bin/python\n"
        "print 'hello'";
        XCTAssertTrue([alienHook writeToFile:@".git/hooks/post-checkout" atomically:YES encoding:NSUTF8StringEncoding error:nil]);

        [self runBootstrap];

        XCTAssertFalse([self doesPostCheckoutHookContainInitCall]);
        
        return S7ExitCodeSuccess;
    });
}

- (void)testOnInitializedS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        S7InitCommand *command = [S7InitCommand new];
        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);

        // drop the .s7control. Emulating the behaviour that we used to have:
        // switch to a commit before s7 used to drop .s7control, but left post-checkout hook installed.
        // So, this is to fix an existing bug first of all.
        // And then, in theory, this is also valid if a user drops .s7control by hand.
        //
        XCTAssertTrue([NSFileManager.defaultManager removeItemAtPath:S7ControlFileName error:nil]);

        [self runBootstrap];

        XCTAssertFalse([self doesPostCheckoutHookContainInitCall]);

        return S7ExitCodeSuccess;
    });
}

@end
