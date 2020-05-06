//
//  pushTests.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "S7InitCommand.h"
#import "S7AddCommand.h"
#import "S7RebindCommand.h"
#import "S7PushCommand.h"

@interface pushTests : XCTestCase
@property (nonatomic, strong) TestReposEnvironment *env;
@end

@implementation pushTests

- (void)setUp {
    self.env = [TestReposEnvironment new];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark -

- (void)testCreate {
    S7PushCommand *command = [S7PushCommand new];
    XCTAssertNotNil(command);
}

- (void)testOnNotS7Repo {
    S7PushCommand *command = [S7PushCommand new];
    XCTAssertEqual(S7ExitCodeNotS7Repo, [command runWithArguments:@[]]);
}

- (void)testOnEmptyS7Repo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        S7PushCommand *command = [S7PushCommand new];
        XCTAssertEqual(S7ExitCodeNoCommittedS7Config, [command runWithArguments:@[]]);
    });
}

- (void)testSubrepoIsntPushedIfConfigIsUnknownToGit {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(subrepoGit);

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(S7ExitCodeNoCommittedS7Config, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    });
}

- (void)testPushDoesntWorkOnNotReboundSubrepo {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib subrepo"];
        [self.env.pasteyRd2Repo pushAll];

        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(subrepoGit);

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    });
}

- (void)testPushDoesntWorkOnReboundSubrepoIfConfigIsNotCommitted {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib subrepo"];
        [self.env.pasteyRd2Repo pushAll];

        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(subrepoGit);

        s7rebind();

        // user did `s7 rebind`, but forgot to commit .s7substate

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    });
}

- (void)testPushWorksOnReboundSubrepoWithCommittedConfig {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib subrepo"];
        [self.env.pasteyRd2Repo pushAll];

        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(subrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2Revision = nil;
        [self.env.pasteyRd2Repo getCurrentRevision:&rd2Revision];

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        XCTAssertTrue([self.env.githubRd2Repo isRevisionAvailable:rd2Revision]);
    });
}

- (void)testPushSubrepoWithCustomBranch {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *subrepoGit = s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib subrepo"];
        [self.env.pasteyRd2Repo pushAll];

        [subrepoGit checkoutNewLocalBranch:@"release/pdfexpert-7.3.2"];
        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(subrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];
        NSString *rd2Revision = nil;
        [self.env.pasteyRd2Repo getCurrentRevision:&rd2Revision];

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        XCTAssertTrue([self.env.githubRd2Repo isRevisionAvailable:rd2Revision]);
    });
}


- (void)testPushAfterFetch {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        s7init();

        NSString *subrepoPath = @"Dependencies/ReaddleLib";
        s7add(subrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib subrepo"];
        [self.env.pasteyRd2Repo pushAll];

        return 0;
    });

    executeInDirectory(self.env.nikRd2Repo.absolutePath, ^int {
        [self.env.nikRd2Repo pull];

        NSString *subrepoPath = @"Dependencies/RDSFTPOnlineClient";
        s7add(subrepoPath, self.env.githubRDSFTPRepo.absolutePath);

        [self.env.nikRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.nikRd2Repo commitWithMessage:@"add SFTP subrepo"];
        [self.env.nikRd2Repo pushAll];

        return 0;
    });

    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int {
        [self.env.pasteyRd2Repo fetch];

        GitRepository *readdleLibGit = [[GitRepository alloc] initWithRepoPath:@"Dependencies/ReaddleLib"];
        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(readdleLibGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(S7ExitCodeNonFastForwardPush, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    });
}

- (void)testRebindJustOneSubreposAtATime {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        NSString *readdleLibSubrepoPath = @"Dependencies/ReaddleLib";
        GitRepository *readdleLibSubrepoGit = s7add(readdleLibSubrepoPath, self.env.githubReaddleLibRepo.absolutePath);

        NSString *pdfKitSubrepoPath = @"Dependencies/RDPDFKit";
        GitRepository *pdfKitSubrepoGit = s7add(pdfKitSubrepoPath, self.env.githubRDPDFKitRepo.absolutePath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"add ReaddleLib and RDPDFKit subrepos"];
        [self.env.pasteyRd2Repo pushAll];

        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);
        NSString *pdfKitRevision = makeSampleCommitToRDPDFKit(pdfKitSubrepoGit);

        s7rebind_specific(pdfKitSubrepoPath);

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up RDPDFKit"];

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertFalse(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        const BOOL isPDFKitPushed = [self.env.githubRDPDFKitRepo isRevisionAvailable:pdfKitRevision];
        XCTAssertTrue(isPDFKitPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");
    });
}

- (void)testInitialPush {
    executeInDirectory(self.env.pasteyRd2Repo.absolutePath, ^int{
        s7init();

        GitRepository *readdleLibSubrepoGit = s7add(@"Dependencies/ReaddleLib", self.env.githubReaddleLibRepo.absolutePath);
        NSString *readdleLibRevision = makeSampleCommitToReaddleLib(readdleLibSubrepoGit);

        s7rebind();

        [self.env.pasteyRd2Repo add:@[S7ConfigFileName, @".gitignore"]];
        [self.env.pasteyRd2Repo commitWithMessage:@"up ReaddleLib"];

        S7PushCommand *pushCommand = [S7PushCommand new];
        XCTAssertEqual(0, [pushCommand runWithArguments:@[]]);

        const BOOL isReaddleLibPushed = [self.env.githubReaddleLibRepo isRevisionAvailable:readdleLibRevision];
        XCTAssertTrue(isReaddleLibPushed, @"s7 push must push only rebound (and .s7substate committed) subrepos");

        return 0;
    });
}

// check subrepo revision and branch consistency? If revision is not at branch, then we will do a kaka to everyone checking out this subrepo.
// validate config – check that full 40-symbol revision saved. Prevent push if not
// test all commited changes to subrepo (even not rebound) get pushed to remote
// test subrepo changes commited after push are not pushed unless subrepo is rebound (and config committed) again
// test push works depth-first – push changes to readdlelib remote from nik, try s7 push on rd2 from pastey; check that changes in rd2 are not pushed
// test recursive push – pdf kit rebound formcalc
// test push works on all branches where config was changed
// what if branch has been dropped at remote?
// do not push if in detached HEAD
// если я обновил сабрепу в одном из коммитов, а потом удалил эту сабрепу – пычкать нет смысла. Вопрос – мог ли я грохнуть незакоммиченные изм-я в сабрепе, когда удалял ее
// если я обновил сабрепу, а потом отдельным коммитом откатил обновление – пычкать? Подсмотреть в HG
// test push on a new branch
// push – подвязаться на pre-push хук. Без параметров пычкать только текущую ветку.
// добавить тест, что пычкается только текущая ветка
// надо еще привлечь второй мозг – не могу понять как тут правильно. Пока делаю только текущую ветку.
//    if (pushMainRepo) {
//        const int gitExitStatus = [repo pushCurrentBranch];
//        if (0 != gitExitStatus) {
//            return gitExitStatus;
//        }
//    }
// Пользователь мог наделать изм-й на нескольких ветках в главном репозитории, и в сабрепах. s7 push выглядит так,
// что точно должен запычкать все ветки где был сделан s7 rebind. Но не пычкать другие ветки – бред.
// Если вызов из хука, то там четко пычкаем все что сказал хук. А вот просто s7 push – вопрос.
// Можно сделать ход конем! s7 push делает git push --all, а дальше все по накатанной схеме!




@end
