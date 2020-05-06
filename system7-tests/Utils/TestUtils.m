//
//  TestUtils.c
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#include "TestUtils.h"

#import "S7InitCommand.h"
#import "S7AddCommand.h"
#import "S7RemoveCommand.h"
#import "S7RebindCommand.h"
#import "S7PushCommand.h"
#import "S7CheckoutCommand.h"

void s7init(void) {
    S7InitCommand *initCommand = [S7InitCommand new];
    const int result = [initCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

GitRepository *s7add(NSString *subrepoPath, NSString *url) {
    S7AddCommand *addCommand = [S7AddCommand new];
    const int addResult = [addCommand runWithArguments:@[ subrepoPath, url ]];
    NSCAssert(0 == addResult, @"");

    GitRepository *subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoPath];
    NSCAssert(subrepoGit, @"");
    return subrepoGit;
}

void s7remove(NSString *subrepoPath) {
    S7RemoveCommand *rebindCommand = [S7RemoveCommand new];
    const int result = [rebindCommand runWithArguments:@[subrepoPath]];
    NSCAssert(0 == result, @"");
}

void s7rebind(void) {
    S7RebindCommand *rebindCommand = [S7RebindCommand new];
    const int result = [rebindCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

void s7rebind_specific(NSString *subrepoPath) {
    S7RebindCommand *rebindCommand = [S7RebindCommand new];
    const int result = [rebindCommand runWithArguments:@[ subrepoPath ]];
    NSCAssert(0 == result, @"");
}

void s7push(void) {
    S7PushCommand *pushCommand = [S7PushCommand new];
    const int result = [pushCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}

void s7checkout(void) {
    S7CheckoutCommand *checkoutCommand = [S7CheckoutCommand new];
    const int result = [checkoutCommand runWithArguments:@[]];
    NSCAssert(0 == result, @"");
}


NSString * makeSampleCommitToReaddleLib(GitRepository *readdleLibSubrepoGit) {
    NSString *fileName = @"RDGeometry.h";
    NSCParameterAssert(0 == [readdleLibSubrepoGit createFile:fileName withContents:nil]);
    NSCParameterAssert(0 == [readdleLibSubrepoGit add:@[ fileName ]]);
    NSCParameterAssert(0 == [readdleLibSubrepoGit commitWithMessage:@"add geometry utils"]);
    NSString *readdleLibRevision = nil;
    NSCParameterAssert(0 == [readdleLibSubrepoGit getCurrentRevision:&readdleLibRevision]);
    return readdleLibRevision;
}

NSString * makeSampleCommitToRDPDFKit(GitRepository *pdfKitSubrepoGit) {
    NSString *fileName = @"RDPDFAnnotation.h";
    NSCParameterAssert(0 == [pdfKitSubrepoGit createFile:fileName withContents:nil]);
    NSCParameterAssert(0 == [pdfKitSubrepoGit add:@[ fileName ]]);
    NSCParameterAssert(0 == [pdfKitSubrepoGit commitWithMessage:@"add annotations"]);
    NSString *pdfKitRevision = nil;
    NSCParameterAssert(0 == [pdfKitSubrepoGit getCurrentRevision:&pdfKitRevision]);
    return pdfKitRevision;
}
