//
//  pushHookTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7PrePushHook.h"

@interface pushHookTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation pushHookTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7PrePushHook *command = [S7PrePushHook new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7PrePushHook *command = [S7PrePushHook new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testOnUpToDateRepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        S7PrePushHook *command = [S7PrePushHook new];

        // pre-push will get nothing from stdin is user is playing with `git push`
        // on up-to-date repo (and we haven't committed anything yet)
        command.testStdinContents = @"";

        XCTAssertEqual(0, [command runWithArguments:@[]]);
    }];
}

- (void)testPushOnCorruptedS7Repo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *revision = commit(repo, @"file", @"asdf", @"add sample file");

        // ar-ar! 🏴‍☠️
        [NSFileManager.defaultManager removeItemAtPath:S7ConfigFileName error:nil];

        S7PrePushHook *command = [S7PrePushHook new];

        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     revision,
                                     [GitRepository nullRevision]];

        XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
    }];
}

- (void)testPushWithoutCommittedConfig {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *revision = commit(repo, @"file", @"asdf", @"add sample file");

        S7PrePushHook *command = [S7PrePushHook new];

        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     revision,
                                     [GitRepository nullRevision]];

        XCTAssertEqual(S7ExitCodeNoCommittedS7Config, [command runWithArguments:@[]]);
    }];
}

- (void)testSubrepoIsntPushedIfConfigIsUnknownToGit {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        S7PrePushHook *command = [S7PrePushHook new];

        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     currentRevision,
                                     [GitRepository nullRevision]];

        XCTAssertEqual(S7ExitCodeNoCommittedS7Config, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushDoesntWorkOnNotReboundSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        NSString *readdleLibRevisionNotExpectedToPush = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        NSString *rd2TechnicalCommitRevision = commit(repo, @"file", @"asdf", @"commit trying to fool s7 into pushing of ReaddleLib that is not rebound");

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2TechnicalCommitRevision,
                                     rd2RevisionAfterSubrepoAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevisionNotExpectedToPush];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushDoesntWorkOnReboundSubrepoIfConfigIsNotCommitted {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        // user did `s7 rebind`, but forgot to commit .s7substate

        NSString *rd2TechnicalCommitRevision = commit(repo, @"file", @"asdf", @"commit trying to fool s7 into pushing of ReaddleLib that is not rebound");

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2TechnicalCommitRevision,
                                     rd2RevisionAfterSubrepoAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushWorksOnReboundSubrepoWithCommittedConfig {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *rd2Revision = nil;
        [repo getCurrentRevision:&rd2Revision];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2Revision,
                                     rd2RevisionAfterSubrepoAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushSubrepoWithCustomBranch {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        [subrepoGit checkoutNewLocalBranch:@"release/pdfexpert-7.3.2"];
        NSString *readdleLibRevision = commit(subrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2Revision = nil;
        [repo getCurrentRevision:&rd2Revision];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2Revision,
                                     rd2RevisionAfterSubrepoAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushAfterFetch {
    __block NSString *pasteysLastPushedRD2Revision = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [repo getCurrentRevision:&pasteysLastPushedRD2Revision];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     pasteysLastPushedRD2Revision,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        [repo pushAllBranchesNeedingPush];
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *prevRevision = nil;
        [repo getCurrentRevision:&prevRevision];

        [repo pull];

        NSString *rd2RevisionAfterPull = nil;
        [repo getCurrentRevision:&rd2RevisionAfterPull];

        s7checkout(prevRevision, rd2RevisionAfterPull);


        NSString *subrepoPath = @"Dependencies/RDSFTPOnlineClient";
        s7add(subrepoPath, self.env.githubRDSFTPRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add SFTP subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     rd2RevisionAfterPull];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        [repo pushAllBranchesNeedingPush];
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo fetch];

        GitRepository *readdleLibGit = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLibRevision = commit(readdleLibGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        // pre-push would still be called in this case, even though, actual rd2 push would fail
        NSString *rd2RevisionAfterSubrepoUpdate = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoUpdate];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoUpdate,
                                     pasteysLastPushedRD2Revision];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        // actual rd2 push fails
        XCTAssertNotEqual(0, [repo pushCurrentBranch]);
    }];
}

- (void)testRebindJustOneSubreposAtATime {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];

        NSString *revisionAfterSubreposAdd = nil;
        [repo getCurrentRevision:&revisionAfterSubreposAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     revisionAfterSubreposAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        [repo pushAllBranchesNeedingPush];

        NSString *readdleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");
        NSString *pdfKitRevision = commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", nil, @"add annotations");

        s7rebind_specific(pdfKitSubrepoPath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up RDPDFKit"];

        NSString *rd2RevisionAfterSubrepoUpdate = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoUpdate];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoUpdate,
                                     revisionAfterSubreposAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        const BOOL isPDFKitPushed = [self.env.githubRDPDFKitRepo isRevisionAvailableLocally:pdfKitRevision];
        XCTAssertTrue(isPDFKitPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testInitialPush {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *revisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&revisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     revisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

- (void)testPushNewBranch {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *revisionAfterSubreposAdd = nil;
        [repo getCurrentRevision:&revisionAfterSubreposAdd];

        XCTAssertEqual(0, s7push_currentBranch(repo));

        [repo checkoutNewLocalBranch:@"experiment"];

        commit(repo, @"file", @"hello", @"add file");

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];
}

- (void)testPushNewBranchAfterSeparateChangesToSubrepo {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *revisionAfterSubreposAdd = nil;
        [repo getCurrentRevision:&revisionAfterSubreposAdd];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    int dummy = 0;
    GitRepository *separateReaddLibRepo =
    [GitRepository
     cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
     destinationPath:[self.env.root stringByAppendingPathComponent:@"pastey/projects/ReaddleLib"]
     exitStatus:&dummy];
    XCTAssertNotNil(separateReaddLibRepo);

    [separateReaddLibRepo run:^(GitRepository * _Nonnull repo) {
        commit(repo, @"RDGeometry.h", @"sqrt(-1);", @"ha-ha");
        XCTAssertEqual(0, [repo pushCurrentBranch]);
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo checkoutNewLocalBranch:@"experiment"];

        commit(repo, @"file", @"hello", @"add file");

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];
}

- (void)testPushDoesntTryToPushUnchangedBranchesInSubrepos {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind();

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        [repo checkoutNewLocalBranch:@"release/pdfexpert-7.3"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"math is hard");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up readdle lib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo checkoutNewLocalBranch:@"release/documents-7.1.4"];

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        [readdleLibSubrepoGit fetch];
        [readdleLibSubrepoGit checkoutNewLocalBranch:@"release/documents-7.1.4"];
        XCTAssertNotNil(readdleLibSubrepoGit);
        commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"iPad 11''", @"add support for a new iPad model");

        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        // эх, до чего же я люблю git...
        // git push --all [in ReaddleLib]
        // ...
        // ! [rejected]    master -> master (non-fast-forward)
        // только вот незадача – я нихуя не делал на мастере, но кто ж объяснит это авторам гита
        //
        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];
}

- (void)testPushDoesntPushNotReboundChanges {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add_stage(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);
        commit(subrepoGit, @"RDGeometry.h", @"sqrt", @"math");
        s7rebind_with_stage();

        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        NSString *rd2RevisionAfterSubrepoAdd = nil;
        [repo getCurrentRevision:&rd2RevisionAfterSubrepoAdd];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterSubrepoAdd,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);


        NSString *readdleLibRevisionNotToBePushed = commit(subrepoGit, @"RDGeometry.h", @"RDRectArea", @"area");

        [repo createFile:@"main.m" withContents:@"int main(void) { return 0; }"];
        [repo commitWithMessage:@"technical commit"];

        NSString *rd2Revision = nil;
        [repo getCurrentRevision:&rd2Revision];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2Revision,
                                     rd2RevisionAfterSubrepoAdd];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibRevisionNotToBePushed];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    }];
}

// recursive push is tested by integration test (case20-pushPullWorkRecursively.sh)


// what if branch has been dropped at remote?
// test push on a new branch

@end
