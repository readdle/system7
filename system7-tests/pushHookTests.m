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
    self.env = [[TestReposEnvironment alloc] initWithTestCaseName:self.className];
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
    XCTAssertEqual(S7ExitCodeNotGitRepository, [command runWithArguments:@[]]);
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

        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);
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

        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);
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

        XCTAssertEqual(S7ExitCodeSuccess, [command runWithArguments:@[]]);

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

        [repo pushCurrentBranch];
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        NSString *rd2RevisionAfterPull = nil;
        [repo getCurrentRevision:&rd2RevisionAfterPull];

        s7checkout([GitRepository nullRevision], rd2RevisionAfterPull);


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

        [repo pushCurrentBranch];
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

        [repo pushCurrentBranch];

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

- (void)testPushToDeletedRemoteBranch {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        [readdleLibSubrepoGit checkoutNewLocalBranch:@"experiment"];
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"add geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    int exitStatus = 0;
    GitRepository *readdleLibRepo = [GitRepository
                                     cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                     destinationPath:[self.env.root stringByAppendingPathComponent:@"pastey/projects/ReaddleLib"]
                                     exitStatus:&exitStatus];
    XCTAssertNotNil(readdleLibRepo);
    XCTAssertEqual(0, exitStatus);

    [readdleLibRepo run:^(GitRepository * _Nonnull repo) {
        XCTAssertEqual(0, [repo deleteRemoteBranch:@"experiment"]);
    }];

    __block NSString *commitMadeAfterBranchRemove = nil;
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        commitMadeAfterBranchRemove = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"matrix", @"matrices");

        s7rebind_with_stage();

        [repo commitWithMessage:@"up ReaddleLib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [readdleLibRepo run:^(GitRepository * _Nonnull repo) {
        [repo fetch];

        XCTAssertTrue([repo isRevisionAvailableLocally:commitMadeAfterBranchRemove]);
        XCTAssertEqual(0, [repo checkoutRemoteTrackingBranch:@"experiment"]);
        NSString *RDGeometryContents = [[NSString alloc] initWithContentsOfFile:@"RDGeometry.h" encoding:NSUTF8StringEncoding error:nil];
        XCTAssertEqualObjects(@"matrix", RDGeometryContents);
    }];
}

- (void)testNewBranchPushDoesntPushNotReboundRepos {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"add geometry utils");

        GitRepository *pdfKitSubrepoGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", @"/Type /Ink", @"ink annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));

        [repo checkoutNewLocalBranch:@"experiment"];

        NSString *readdleLibCommitExpectedToBePushed = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sin(Pi)", @"pi");

        s7rebind_with_stage();

        [repo commitWithMessage:@"up ReaddleLib"];

        NSString *pdfKitCommitNotToBePushed = commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", @"WIP", @"unrelated bugfix");

        XCTAssertEqual(0, s7push_currentBranch(repo));

        XCTAssertTrue([self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibCommitExpectedToBePushed]);
        XCTAssertFalse([self.env.githubRDPDFKitRepo isRevisionAvailableLocally:pdfKitCommitNotToBePushed]);
    }];
}

- (void)testMainRepoBranchDeletePush {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"add geometry utils");

        GitRepository *pdfKitSubrepoGit = s7add_stage(@"Dependencies/RDPDFKit", self.env.githubRDPDFKitRepo.absolutePath);
        commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", @"/Type /Ink", @"ink annotations");

        s7rebind_with_stage();

        [repo commitWithMessage:@"add subrepos"];

        XCTAssertEqual(0, s7push_currentBranch(repo));


        [repo checkoutNewLocalBranch:@"experiment"];

        NSString *lastPushedReaddleLibCommit = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"RDRectArea", @"geometry utils");

        s7rebind_with_stage();

        [repo commitWithMessage:@"up ReaddleLib 1"];

        NSString *lastPushedCommitOnExperimentBranch = nil;
        [repo getCurrentRevision:&lastPushedCommitOnExperimentBranch];

        s7push_currentBranch(repo);


        NSString *readdleLibCommitNotToBePushed = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sin(Pi)", @"pi");

        s7rebind_with_stage();

        [repo commitWithMessage:@"up ReaddleLib 2"];

        NSString *pdfKitCommitNotToBePushed = commit(pdfKitSubrepoGit, @"RDPDFAnnotation.h", @"WIP", @"unrelated bugfix");

        S7PrePushHook *command = [S7PrePushHook new];

        command.testStdinContents = [NSString stringWithFormat:@"(delete) %@ refs/heads/experiment %@",
                                     [GitRepository nullRevision],
                                     lastPushedCommitOnExperimentBranch];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        XCTAssertEqual(0, [repo deleteRemoteBranch:@"experiment"]);
        

        [repo checkoutExistingLocalBranch:@"master"];

        commit(repo, @"file", @"test", @"subrepos unrealted stuff");

        XCTAssertEqual(0, s7push_currentBranch(repo));

        XCTAssertTrue([self.env.githubReaddleLibRepo isRevisionAvailableLocally:lastPushedReaddleLibCommit]);
        XCTAssertFalse([self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibCommitNotToBePushed]);
        XCTAssertFalse([self.env.githubRDPDFKitRepo isRevisionAvailableLocally:pdfKitCommitNotToBePushed]);
    }];
}

- (void)testPushAllDoesntFailOnBranchesThatDontHaveS7 {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        NSString *initialRevision = nil;
        [repo getCurrentRevision:&initialRevision];

        NSString *masterRevision = commit(repo, @"test", @"test", @"test");


        [repo checkoutNewLocalBranch:@"s7"];

        s7init_deactivateHooks();

        [repo add:@[@"."]];
        [repo commitWithMessage:@"init s7"];


        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     initialRevision,
                                     masterRevision];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
    }];
}

- (void)testPushChangesNotVisibleFromNaiveStartEndConfigDiff {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add_stage(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *initialReaddleLibRevision = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sqrt", @"add geometry utils");

        [repo commitWithMessage:@"add subrepo"];

        XCTAssertEqual(0, s7push_currentBranch(repo));

        [readdleLibSubrepoGit checkoutNewLocalBranch:@"experiment"];
        NSString *readdleLibCommitExpectedToBePushed = commit(readdleLibSubrepoGit, @"RDGeometry.h", @"sin(Pi)", @"pi");
        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [readdleLibSubrepoGit forceCheckoutLocalBranch:@"master" revision:initialReaddleLibRevision];
        s7rebind_with_stage();
        [repo commitWithMessage:@"revert ReaddleLib"];

        XCTAssertEqual(0, s7push_currentBranch(repo));

        XCTAssertTrue([self.env.githubReaddleLibRepo isRevisionAvailableLocally:readdleLibCommitExpectedToBePushed]);
    }];
}

- (void)testTwoBranchesPointingToSameCommitArePushed {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        commit(readdleLibSubrepoGit, @"RDGeometry.h", nil, @"add geometry utils");
        s7rebind_with_stage();
        [repo commitWithMessage:@"add ReaddleLib subrepo"];

        [readdleLibSubrepoGit checkoutNewLocalBranch:@"feature/system-info"];
        commit(readdleLibSubrepoGit, @"RDSystemInfo.h", @"RDGetDeviceModel()", @"add new method");
        s7rebind_with_stage();
        [repo commitWithMessage:@"up ReaddleLib"];

        [readdleLibSubrepoGit checkoutExistingLocalBranch:@"master"];
        s7rebind_with_stage();
        [repo commitWithMessage:@"switch ReaddleLib back to master"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    [self.env.nikRd2Repo run:^(GitRepository * _Nonnull repo) {
        [repo pull];

        s7init_deactivateHooks();

        NSString *currentRevision = nil;
        [repo getCurrentRevision:&currentRevision];

        s7checkout([GitRepository nullRevision], currentRevision);

        GitRepository *readdleLibSubrepoGit = [GitRepository repoAtPath:@"Dependencies/ReaddleLib"];
        [readdleLibSubrepoGit checkoutRemoteTrackingBranch:@"feature/system-info"];
        [readdleLibSubrepoGit checkoutExistingLocalBranch:@"master"];
        XCTAssertEqual(0, [readdleLibSubrepoGit mergeWith:@"feature/system-info"]);
        s7rebind_with_stage();
        [repo commitWithMessage:@"merge System Info branch in ReaddleLib into master"];

        NSString *latestRevisionAtMaster = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&latestRevisionAtMaster]);

        [readdleLibSubrepoGit checkoutExistingLocalBranch:@"feature/system-info"];
        NSString *latestRevisionAtFeature = nil;
        XCTAssertEqual(0, [readdleLibSubrepoGit getCurrentRevision:&latestRevisionAtFeature]);

        XCTAssertEqualObjects(latestRevisionAtFeature, latestRevisionAtMaster);

        [readdleLibSubrepoGit checkoutExistingLocalBranch:@"master"];

        XCTAssertEqual(0, s7push_currentBranch(repo));
    }];

    int exitStatus = 0;
    GitRepository *readdleLibRepo = [GitRepository
                                     cloneRepoAtURL:self.env.githubReaddleLibRepo.absolutePath
                                     destinationPath:[self.env.root stringByAppendingPathComponent:@"ReaddleLib"]
                                     exitStatus:&exitStatus];
    XCTAssertNotNil(readdleLibRepo);
    XCTAssertEqual(0, exitStatus);

    [readdleLibRepo run:^(GitRepository * _Nonnull repo) {
        NSString *remoteRevisionAtMaster = nil;
        [repo getLatestRemoteRevision:&remoteRevisionAtMaster atBranch:@"master"];

        NSString *remoteRevisionAtFeature = nil;
        [repo getLatestRemoteRevision:&remoteRevisionAtFeature atBranch:@"feature/system-info"];

        XCTAssertNotNil(remoteRevisionAtMaster);
        XCTAssertNotNil(remoteRevisionAtFeature);
        // we used not to push 'feature/system-info' because of the way we detected which branches need push
        XCTAssertEqualObjects(remoteRevisionAtMaster, remoteRevisionAtFeature);
    }];
}

- (void)testPushNewBranchWithDeletedBranchInSubrepoHistory {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        // Add ReaddleLib subrepo
        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepo = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];
        
        NSString *revisionAfterAddedReaddleLib = nil;
        [repo getCurrentRevision:&revisionAfterAddedReaddleLib];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     revisionAfterAddedReaddleLib,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        [repo pushCurrentBranch];
        
        // Switch to another branch in main repo
        [repo checkoutNewLocalBranch:@"feature/plus-button"];
        
        // Switch to another branch in ReaddleLib subrepo
        [readdleLibSubrepo checkoutNewLocalBranch:@"feature/dead-branch"];
        commit(readdleLibSubrepo, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();
        
        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2RevisionWithDeadBranchInSubrepo = nil;
        [repo getCurrentRevision:&rd2RevisionWithDeadBranchInSubrepo];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/feature/plus-button %@ refs/heads/feature/plus-button %@",
                                     rd2RevisionWithDeadBranchInSubrepo,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        
        [repo pushCurrentBranch];
        
        // Merge "pull request" in ReaddleLib subrepo into master and delete merged branch
        [readdleLibSubrepo checkoutExistingLocalBranch:@"master"];
        [readdleLibSubrepo mergeWith:@"feature/dead-branch"];
        [readdleLibSubrepo deleteRemoteBranch:@"feature/dead-branch"];
        [readdleLibSubrepo deleteLocalBranch:@"feature/dead-branch"];
        
        commit(readdleLibSubrepo, @"NSLayoutConstraint+ReaddleLib.h", nil, @"add autolayout utils");
        
        s7rebind_with_stage();
        
        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2RevisionWithMergedNonMasterInSubrepo = nil;
        [repo getCurrentRevision:&rd2RevisionWithMergedNonMasterInSubrepo];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/feature/plus-button %@ refs/heads/feature/plus-button %@",
                                     rd2RevisionWithMergedNonMasterInSubrepo,
                                     rd2RevisionWithDeadBranchInSubrepo];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        
        [repo pushCurrentBranch];
        
        // Switch to bugfix branch in rd2
        [repo checkoutNewLocalBranch:@"feature/plus-button-fix"];
        
        commit(readdleLibSubrepo, @"RDDevice.h", nil, @"add device utils");

        s7rebind_with_stage();
        
        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2RevisionWithRDDeviceInSubrepo = nil;
        [repo getCurrentRevision:&rd2RevisionWithRDDeviceInSubrepo];
        
        NSString *rd2BugfixCommit = commit(repo, @"Bugfix.h", nil, @"Fixed plus button");
        
        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/feature/plus-button-fix %@ refs/heads/feature/plus-button-fix %@",
                                     rd2BugfixCommit,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        
        [repo pushCurrentBranch];
    }];
}

- (void)testPushExistingBranchWithDeletedBranchInSubrepoHistory {
    [self.env.pasteyRd2Repo run:^(GitRepository * _Nonnull repo) {
        s7init_deactivateHooks();

        // Add ReaddleLib subrepo
        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepo = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [repo add:@[S7ConfigFileName, @".gitignore"]];
        [repo commitWithMessage:@"add ReaddleLib subrepo"];
        
        NSString *rd2RevisionAfterAddedReaddleLib = nil;
        [repo getCurrentRevision:&rd2RevisionAfterAddedReaddleLib];

        S7PrePushHook *command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2RevisionAfterAddedReaddleLib,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);

        [repo pushCurrentBranch];
        
        // Switch to another branch in main repo
        [repo checkoutNewLocalBranch:@"feature/plus-button"];
        
        // Switch to another branch in ReaddleLib subrepo
        [readdleLibSubrepo checkoutNewLocalBranch:@"feature/dead-branch"];
        commit(readdleLibSubrepo, @"RDGeometry.h", nil, @"add geometry utils");

        s7rebind_with_stage();
        
        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2RevisionWithDeadBranchInSubrepo = nil;
        [repo getCurrentRevision:&rd2RevisionWithDeadBranchInSubrepo];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/feature/plus-button %@ refs/heads/feature/plus-button %@",
                                     rd2RevisionWithDeadBranchInSubrepo,
                                     [GitRepository nullRevision]];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        
        [repo pushCurrentBranch];
        
        // Merge "pull request" in ReaddleLib subrepo into master and delete merged branch
        [readdleLibSubrepo checkoutExistingLocalBranch:@"master"];
        [readdleLibSubrepo mergeWith:@"feature/dead-branch"];
        [readdleLibSubrepo deleteRemoteBranch:@"feature/dead-branch"];
        [readdleLibSubrepo deleteLocalBranch:@"feature/dead-branch"];
        
        commit(readdleLibSubrepo, @"NSLayoutConstraint+ReaddleLib.h", nil, @"add autolayout utils");
        
        s7rebind_with_stage();
        
        [repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2RevisionWithMergedNonMasterInSubrepo = nil;
        [repo getCurrentRevision:&rd2RevisionWithMergedNonMasterInSubrepo];

        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/feature/plus-button %@ refs/heads/feature/plus-button %@",
                                     rd2RevisionWithMergedNonMasterInSubrepo,
                                     rd2RevisionWithDeadBranchInSubrepo];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
        
        [repo pushCurrentBranch];
        
        // Merge 'pull request' into master
        [repo checkoutExistingLocalBranch:@"master"];
        [repo mergeWith:@"feature/plus-button"];
        
        [repo commitWithMessage:@"Merged Plus Button feature"];
        
        NSString *rd2MergeCommit = nil;
        [repo getCurrentRevision:&rd2MergeCommit];
        
        command = [S7PrePushHook new];
        command.testStdinContents = [NSString stringWithFormat:@"refs/heads/master %@ refs/heads/master %@",
                                     rd2MergeCommit,
                                     rd2RevisionAfterAddedReaddleLib];
        XCTAssertEqual(0, [command runWithArguments:@[]]);
    }];
}

// recursive push is tested by integration test (case20-pushPullWorkRecursively.sh)

@end
