//
//  TestReposEnvironment.m
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "TestReposEnvironment.h"

#import "Git.h"


@interface TestReposEnvironment ()
@property (nonatomic, strong) NSString *root;
@end

@implementation TestReposEnvironment

@synthesize pasteyRd2Repo = _pasteyRd2Repo;
@synthesize nikRd2Repo = _nikRd2Repo;

- (instancetype)init {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    _root = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    BOOL isDirectory = NO;
    NSError *error = nil;

    if ([[NSFileManager defaultManager] fileExistsAtPath:self.root isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager] removeItemAtPath:self.root error:&error]) {
            NSParameterAssert(NO);
            return nil;
        }
    }

    const BOOL testFolderRootCreated = [[NSFileManager defaultManager]
                                        createDirectoryAtPath:self.root
                                        withIntermediateDirectories:NO
                                        attributes:nil
                                        error:&error];
    if (NO == testFolderRootCreated) {
        NSParameterAssert(NO);
        return nil;
    }

    [self initializeGitHubRepos];

    return self;
}

- (void)dealloc {
    [[NSFileManager defaultManager] removeItemAtPath:self.root error:nil];
}

#pragma mark - utils -

- (void)touch:(NSString *)filePath {
    NSString *absoluteFilePath = filePath;
    if (NO == [absoluteFilePath hasPrefix:@"/"]) {
        absoluteFilePath = [self.root stringByAppendingPathComponent:filePath];
    }

    if (NO == [[NSFileManager defaultManager] createFileAtPath:absoluteFilePath contents:nil attributes:nil]) {
        NSParameterAssert(NO);
    }
}

- (void)makeDir:(NSString *)filePath {
    NSString *absoluteFilePath = filePath;
    if (NO == [absoluteFilePath hasPrefix:@"/"]) {
        absoluteFilePath = [self.root stringByAppendingPathComponent:filePath];
    }

    NSError *error = nil;
    const BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:absoluteFilePath withIntermediateDirectories:YES attributes:nil error:&error];
    if (NO == result) {
        NSParameterAssert(NO);
    }
}

#pragma mark -

- (GitRepository *)initializeRemoteRepoAtRelativePath:(NSString *)relativePath {
    NSString *absoluteFilePath = [self.root stringByAppendingPathComponent:relativePath];
    int exitStatus = 0;
    GitRepository *repo = [GitRepository initializeRepositoryAtPath:absoluteFilePath bare:YES exitStatus:&exitStatus];
    NSAssert(0 == exitStatus, @"");
    return repo;
}

- (void)initializeGitHubRepos {
    NSAssert(nil == _githubRd2Repo, @"must be called only once!");

    _githubRd2Repo = [self initializeRemoteRepoAtRelativePath:@"github/rd2"];
    NSAssert(_githubRd2Repo, @"");

    executeInDirectory(self.root, ^int {
        // make rd2 non-empty by default
        int gitCloneExitStatus = 0;
        GitRepository *tmpRd2Repo = [GitRepository cloneRepoAtURL:@"github/rd2" destinationPath:@"tmp" exitStatus:&gitCloneExitStatus];
        NSParameterAssert(tmpRd2Repo);
        NSParameterAssert(0 == gitCloneExitStatus);

        [self touch:[self.root stringByAppendingPathComponent:@"tmp/.gitignore"]];
        [tmpRd2Repo add:@[@".gitignore"]];
        [tmpRd2Repo commitWithMessage:@"add .gitignore"];
        [tmpRd2Repo pushAll];

        return 0;
    });

    _githubReaddleLibRepo = [self initializeRemoteRepoAtRelativePath:@"github/ReaddleLib"];
    NSAssert(_githubReaddleLibRepo, @"");

    _githubRDSFTPRepo = [self initializeRemoteRepoAtRelativePath:@"github/RDSFTPOnlineClient"];
    NSAssert(_githubRDSFTPRepo, @"");

    _githubRDPDFKitRepo = [self initializeRemoteRepoAtRelativePath:@"github/RDPDFKit"];
    NSAssert(_githubRDPDFKitRepo, @"");

    _githubFormCalcRepo = [self initializeRemoteRepoAtRelativePath:@"github/FormCalc"];
    NSAssert(_githubFormCalcRepo, @"");
}

- (GitRepository *)pasteyRd2Repo {
    if (nil == _pasteyRd2Repo) {
        executeInDirectory(self.root, ^int{
            int gitCloneExitStatus = 0;
            _pasteyRd2Repo = [GitRepository cloneRepoAtURL:@"github/rd2" destinationPath:@"pastey/projects/rd2" exitStatus:&gitCloneExitStatus];
            NSParameterAssert(_pasteyRd2Repo);
            NSParameterAssert(0 == gitCloneExitStatus);
            return gitCloneExitStatus;
        });
    }

    return _pasteyRd2Repo;
}

- (GitRepository *)nikRd2Repo {
    if (nil == _nikRd2Repo) {
        executeInDirectory(self.root, ^int{
            int gitCloneExitStatus = 0;
            _nikRd2Repo = [GitRepository cloneRepoAtURL:@"github/rd2" destinationPath:@"nik/rd2" exitStatus:&gitCloneExitStatus];
            NSParameterAssert(_nikRd2Repo);
            NSParameterAssert(0 == gitCloneExitStatus);
            return gitCloneExitStatus;
        });
    }

    return _nikRd2Repo;
}

@end
