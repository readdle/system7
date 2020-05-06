//
//  diffTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 26.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7Parser.h"

@interface diffTests : XCTestCase

@end

@implementation diffTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAddFirstSubrepo {
    S7Config *fromConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[]];
    S7Config *toConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"master"]
    ]];

    NSArray<S7SubrepoDescription *> *subreposToDelete = nil;
    NSArray<S7SubrepoDescription *> *subreposToUpdate = nil;
    NSArray<S7SubrepoDescription *> *subreposToAdd = nil;

    diffConfigs(fromConfig, toConfig, &subreposToDelete, &subreposToUpdate, &subreposToAdd);

    XCTAssert(0 == subreposToDelete.count);
    XCTAssert(0 == subreposToUpdate.count);

    XCTAssertEqualObjects(subreposToAdd, toConfig.subrepoDescriptions);
}

- (void)testUpdateSubrepo {
    S7Config *fromConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"master"]
    ]];
    S7Config *toConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"e11e50dfb5d2e8ef7e96f9683128e5820755b026" branch:@"master"]
    ]];

    NSArray<S7SubrepoDescription *> *subreposToDelete = nil;
    NSArray<S7SubrepoDescription *> *subreposToUpdate = nil;
    NSArray<S7SubrepoDescription *> *subreposToAdd = nil;

    diffConfigs(fromConfig, toConfig, &subreposToDelete, &subreposToUpdate, &subreposToAdd);

    XCTAssert(0 == subreposToDelete.count);
    XCTAssert(0 == subreposToAdd.count);

    XCTAssertEqualObjects(subreposToUpdate, toConfig.subrepoDescriptions);
}

- (void)testRemoveSubrepo {
    S7Config *fromConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"master"]
    ]];
    S7Config *toConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[]];

    NSArray<S7SubrepoDescription *> *subreposToDelete = nil;
    NSArray<S7SubrepoDescription *> *subreposToUpdate = nil;
    NSArray<S7SubrepoDescription *> *subreposToAdd = nil;

    diffConfigs(fromConfig, toConfig, &subreposToDelete, &subreposToUpdate, &subreposToAdd);

    XCTAssert(0 == subreposToAdd.count);
    XCTAssert(0 == subreposToUpdate.count);

    XCTAssertEqualObjects(subreposToDelete, fromConfig.subrepoDescriptions);
}

- (void)testAllInOneTransaction {
    S7Config *fromConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"c1913e99e9b8fffc5405ccfe2d0f53f8c623da11" branch:@"master"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdcifs" url:@"git@github.com:readdle/rdcifs" revision:@"50835dbf4a6f4bdf4664d94c26fc1fab594df4bf" branch:@"task/DOC-1567"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdkeychain" url:@"git@github.com:readdle/rdkeychain" revision:@"1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e" branch:@"master"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/Thirdparty/log4Cocoa" url:@"git@github.com:readdle/log4Cocoa" revision:@"e11e50dfb5d2e8ef7e96f9683128e5820755b026" branch:@"master"]
    ]];

    S7Config *toConfig = [[S7Config alloc] initWithSubrepoDescriptions:@[
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"7a98ac1d616d4cbe8e7932b3fdb6f4d61407c6cd" branch:@"master"],  // just update
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdcifs" url:@"git@github.com:readdle/rdcifs" revision:@"61b7aa1fff3b4d628d7d6ff97f76a51169724d99" branch:@"master"],  // update and switch branch
        // drop rdkeychain
//        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdkeychain" url:@"git@github.com:readdle/rdkeychain" revision:@"1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e" branch:@"master"],
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/Thirdparty/log4Cocoa" url:@"git@github.com:readdle/log4Cocoa" revision:@"e11e50dfb5d2e8ef7e96f9683128e5820755b026" branch:@"master"], // do not touch log4Cocoa
        // add rdsubscriptionkit
        [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdsubscriptionkit" url:@"git@github.com:readdle/rdsubscriptionkit" revision:@"491500e4bb70402f1f1fde8aeb10a597eba301df" branch:@"master"],
    ]];

    NSArray<S7SubrepoDescription *> *subreposToDelete = nil;
    NSArray<S7SubrepoDescription *> *subreposToUpdate = nil;
    NSArray<S7SubrepoDescription *> *subreposToAdd = nil;

    diffConfigs(fromConfig, toConfig, &subreposToDelete, &subreposToUpdate, &subreposToAdd);

    XCTAssertEqualObjects(subreposToDelete, @[[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdkeychain" url:@"git@github.com:readdle/rdkeychain" revision:@"1952a059e7a9e7d96715ce2fc34b564dfe5b0d0e" branch:@"master"]]);

    XCTAssertEqualObjects(subreposToAdd, @[[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdsubscriptionkit" url:@"git@github.com:readdle/rdsubscriptionkit" revision:@"491500e4bb70402f1f1fde8aeb10a597eba301df" branch:@"master"]]);

    NSSet<S7SubrepoDescription *> *expectedSubreposToUpdate = [NSSet setWithArray:
    @[[[S7SubrepoDescription alloc] initWithPath:@"Dependencies/ReaddleLib" url:@"git@github.com:readdle/readdlelib" revision:@"7a98ac1d616d4cbe8e7932b3fdb6f4d61407c6cd" branch:@"master"],  // just update
      [[S7SubrepoDescription alloc] initWithPath:@"Dependencies/rdcifs" url:@"git@github.com:readdle/rdcifs" revision:@"61b7aa1fff3b4d628d7d6ff97f76a51169724d99" branch:@"master"]
    ]];

    NSSet<S7SubrepoDescription *> *actualSubreposToUpdate = [NSSet setWithArray:subreposToUpdate];
    XCTAssertEqualObjects(actualSubreposToUpdate, expectedSubreposToUpdate);
}

@end
