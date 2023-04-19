//
//  checkoutTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 02.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestReposEnvironment.h"

#import "S7CheckoutCommand.h"
#import "S7PostMergeHook.h"
#import "S7PostCommitHook.h"
#import "S7PostCheckoutHook.h"

@interface checkoutTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation checkoutTests

- (void)setUp {
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
}

- (void)tearDown {
    S7PostCheckoutHook.warnAboutDetachingCommitsHook = nil;
}

#pragma mark -

- (void)testCreate {
    S7CheckoutCommand *command = [S7CheckoutCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7CheckoutCommand *command = [S7CheckoutCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testPullWithConflictInUnrelatedFile {
    __block S7Config *baseConfig = nil;
    __block NSString *readdleLib_initialRevision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
        
        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit getCurrentRevision:&readdleLib_initialRevision];

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        baseConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        commit(repo, @"best-band", @"rhcp", @"... little ant, checking out this and that");

        s7push_currentBranch(repo);
    }];

    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        commit(repo, @"best-band", @"metallica", @"Sleep with one eye open, Gripping your pillow tight");

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        commit(repo, @"best-band", @"nirvana", @"Where do bad folks go when they die? They don't go to heaven where the angels fly");

        XCTAssertNotEqual(0, s7push_currentBranch(repo), @"nik has pushed");

        [repo pull];

        // conflict in an innocent-file. No hooks would be called. Resolve conflict, add file and commit.
        // and it's only here when the post-commit hook would get called.

        // as no hooks were called, subrepos are not checkout properly, but .s7substate in working dir is updated
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLib_initialRevision);

        // say, developer has resolved the conflict
        XCTAssertTrue([@"U2" writeToFile:@"best-band" atomically:YES encoding:NSUTF8StringEncoding error:nil]);

        // but he would naturally want to build project before committing merge result
        // if he tries to build, then he will find out that subrepos are not in sync
        // so he would have to run `s7 checkout`
        //
        S7CheckoutCommand *command = [S7CheckoutCommand new];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLib_niks_Revision);

        // build succeeded. Can commit
        [repo add:@[@"best-band"]];
        XCTAssertEqual(0, [repo commitWithMessage:@"merge"]);

        S7PostCommitHook *postCommitHook = [S7PostCommitHook new];
        XCTAssertEqual(0, [postCommitHook runWithArguments:@[]]);

        actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLib_niks_Revision);
    }];
}

- (void)testCheckoutWarnsAboutDetachingLocalCommits {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        s7push_currentBranch(repo);
    }];

    __block NSString *readdleLib_niks_Revision = nil;
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        readdleLib_niks_Revision = commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        s7push_currentBranch(repo);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"matrix", @"matrix");
        NSString *readdleLib_pasteys_Revision =
            commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"math");

        [repo pull];

        __block BOOL warningPrinted = NO;
        S7PostCheckoutHook.warnAboutDetachingCommitsHook = ^(NSString * _Nonnull topRevision, int numberOfCommits) {
            warningPrinted = YES;
            XCTAssertEqual(2, numberOfCommits);
            XCTAssertEqualObjects(topRevision, readdleLib_pasteys_Revision);
        };

        S7PostMergeHook *postMergeHook = [S7PostMergeHook new];
        const int mergeHookExitStatus = [postMergeHook runWithArguments:@[]];
        XCTAssertEqual(0, mergeHookExitStatus);

        XCTAssertTrue(warningPrinted);

        readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        XCTAssertNotNil(readdleLibSubrepoGit);

        NSString *actualReaddleLibRevision = nil;
        [readdleLibSubrepoGit getCurrentRevision:&actualReaddleLibRevision];
        XCTAssertEqualObjects(actualReaddleLibRevision, readdleLib_niks_Revision);
    }];
}

- (void)testCheckoutNonTrackingBranchInSubrepo {
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
        
        GitRepository *const readdleLib = s7add_stage(@"Dependencies/ReaddleLib",
                                                      self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add ReaddleLib subrepo"];
        s7push_currentBranch(repo);
        
        [readdleLib checkoutNewLocalBranch:@"experiment/srgb"];
        commit(readdleLib, @"NSColor+RD.h", @"sRGB", @"repaint");
        // with this option I was able to create situation when
        // I had fully functional local and remote branches yet
        // local branch wasn't tracking remote. Git was OK about it
        // but s7 was unable to checkout this branch
        [readdleLib runGitCommand:@"-c push.default=current push"];
        
        [repo checkoutNewLocalBranch:@"experiment/srgb"];
        s7rebind_with_stage();
        [repo commitWithMessage:@"updated ReaddleLib"];
        
        NSString *readdleLibRevision;
        [readdleLib getCurrentRevision:&readdleLibRevision];
        XCTAssertNotNil(readdleLibRevision);
        commit(readdleLib, @"NSColor+RD.h", @"sRGB\n", @"newline!");
        
        [repo checkoutExistingLocalBranch:@"master"];
        XCTAssertEqual(0, [[S7CheckoutCommand new] runWithArguments:@[]]);
        
        [repo checkoutExistingLocalBranch:@"experiment/srgb"];
        XCTAssertEqual(0, [[S7CheckoutCommand new] runWithArguments:@[]]);
        
        
        NSString *checkedReaddleLibRevision;
        [readdleLib getCurrentRevision:&checkedReaddleLibRevision];
        XCTAssertNotNil(checkedReaddleLibRevision);
        XCTAssertEqualObjects(readdleLibRevision, checkedReaddleLibRevision);
    }];
}

- (void)testSubrepoMoveWithoutCheckout {
    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();
        [repo runGitCommand:@"add ."];
        [repo commitWithMessage:@"init s7"];
        // Get revision X.
        NSString *rootRevision;
        [repo getCurrentRevision:&rootRevision];
        
        // Checkout and commit ReaddleLib.
        NSString *const masterReaddeLibPath = @"Dependencies/ReaddleLib";
        s7add_stage(masterReaddeLibPath,
                    self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add Dependencies/ReaddleLib subrepo"];
        
        // Checkout X, create new branch.
        [repo checkoutRevision:rootRevision];
        XCTAssertEqual(0, [[S7CheckoutCommand new] runWithArguments:@[]]);
        [repo checkoutNewLocalBranch:@"feature"];
        
        // Checkout ReaddleLib with different path, and commit.
        NSString *const featureReaddleLibPath = @"Libraries/ReaddleLib";
        s7add_stage(featureReaddleLibPath,
                    self.env.githubReaddleLibRepo.absolutePath);
        [repo commitWithMessage:@"add Libraries/ReaddleLib subrepo"];
        
        // Save ReaddleLib file number.
        NSUInteger(^getFSNumber)(NSString *) = ^(NSString *path){
            return [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSystemFileNumber];
        };
        const NSUInteger originalFolderFSNumber = getFSNumber(featureReaddleLibPath);
        
        // Check that ReaddleLib folder is moved, not cloned during switch between by comparing file numbers.
        [repo checkoutExistingLocalBranch:@"master"];
        XCTAssertEqual(0, [[S7CheckoutCommand new] runWithArguments:@[]]);
        XCTAssertEqual(originalFolderFSNumber, getFSNumber(masterReaddeLibPath));
        
        [repo checkoutExistingLocalBranch:@"feature"];
        XCTAssertEqual(0, [[S7CheckoutCommand new] runWithArguments:@[]]);
        XCTAssertEqual(originalFolderFSNumber, getFSNumber(featureReaddleLibPath));
    }];
}

@end
