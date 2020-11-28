//
//  initBootstrapTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 27.11.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"

#import "TestReposEnvironment.h"

@interface initBootstrapTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation initBootstrapTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        XCTAssertTrue([NSFileManager.defaultManager createFileAtPath:@".gitattributes" contents:nil attributes:nil]);
    });
}

// these tests are pure emulation – filter is not really called by Git

- (void)runBootstrap {
    S7InitCommand *initBootstrapCommand = [S7InitCommand new];
    const int exitCode = [initBootstrapCommand runWithArguments:@[@"bootstrap"]];
    XCTAssertEqual(1, exitCode);
}

- (BOOL)doesPostCheckoutHookContainInitCall {
    NSString *postCheckoutHookContents = [[NSString alloc] initWithContentsOfFile:@".git/hooks/post-checkout" encoding:NSUTF8StringEncoding error:nil];
    return [postCheckoutHookContents containsString:@"s7 init"];
}

- (void)testOnVirginRepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        [self runBootstrap];

        XCTAssertTrue([self doesPostCheckoutHookContainInitCall]);
    });
}

- (void)testOnLFSRepo_WITH_NO_LFSHooksInstalled {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        NSCAssert([@"*.mp4 filter=lfs diff=lfs merge=lfs -text" writeToFile:@".gitattributes" atomically:YES encoding:NSUTF8StringEncoding error:nil],
                  @"failed to install fake lfs filter");

        [self runBootstrap];

        XCTAssertFalse([self doesPostCheckoutHookContainInitCall]);
    });
}

- (void)testOnLFSRepo_WITH_LFSHooksInstalled {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        NSCAssert([@"*.mp4 filter=lfs diff=lfs merge=lfs -text"
                   writeToFile:@".gitattributes"
                   atomically:YES
                   encoding:NSUTF8StringEncoding
                   error:nil],
                  @"failed to install fake lfs filter");

        NSCAssert([NSFileManager.defaultManager
                   createFileAtPath:@".git/hooks/post-checkout"
                   contents:[@"#!/bin/sh\n"
                             "Git LFS was here" dataUsingEncoding:NSUTF8StringEncoding]
                   attributes:nil],
                  @"failed to install fake lfs hook");

        [self runBootstrap];

        XCTAssertTrue([self doesPostCheckoutHookContainInitCall]);
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
    });
}


@end
