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
@property (nonatomic, strong) NSString *testCaseName;
@end

@implementation TestReposEnvironment

@synthesize pasteyRd2Repo = _pasteyRd2Repo;
@synthesize nikRd2Repo = _nikRd2Repo;

@synthesize githubRd2Repo = _githubRd2Repo;
@synthesize githubReaddleLibRepo = _githubReaddleLibRepo;
@synthesize githubRDSFTPRepo = _githubRDSFTPRepo;
@synthesize githubRDPDFKitRepo = _githubRDPDFKitRepo;
@synthesize githubFormCalcRepo = _githubFormCalcRepo;
@synthesize githubTestBareRepo = _githubTestBareRepo;

- (instancetype)initWithTestCaseName:(NSString *)testCaseName {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    self.testCaseName = testCaseName;
    _root = [[NSTemporaryDirectory()
             stringByAppendingPathComponent:@"com.readdle.system7-tests"]
             stringByAppendingPathComponent:testCaseName];
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
                                        withIntermediateDirectories:YES
                                        attributes:nil
                                        error:&error];
    if (NO == testFolderRootCreated) {
        NSParameterAssert(NO);
        return nil;
    }

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

    static NSString *templateRepoPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        templateRepoPath = [[NSTemporaryDirectory()
                            stringByAppendingPathComponent:@"com.readdle.system7-tests.generic-template"]
                            stringByAppendingPathComponent:self.testCaseName];

        if ([[NSFileManager defaultManager] fileExistsAtPath:templateRepoPath]) {
            NSError *error = nil;
            if (NO == [[NSFileManager defaultManager] removeItemAtPath:templateRepoPath error:&error]) {
                NSCParameterAssert(NO);
            }
        }

        int exitStatus = 0;
        __unused GitRepository *repo = [GitRepository initializeRepositoryAtPath:templateRepoPath bare:YES exitStatus:&exitStatus];
        NSCAssert(repo, @"");
        NSCAssert(0 == exitStatus, @"");
        
        // nsavko: working around my local setup
        if ([getGlobalGitConfigValue(@"commit.gpgsign") isEqualToString:@"true"]) {
            GitRepository.testRepoConfigureOnInitBlock = ^(GitRepository * _Nonnull repo) {
                [repo runGitCommand:@"config --local commit.gpgsign false"];
            };
        }

        NSString *tmpCloneRepoPath = [[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:@"com.readdle.system7-tests.generic-template-tmp-clone"]
                                       stringByAppendingPathComponent:self.testCaseName];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpCloneRepoPath]) {
            if (NO == [[NSFileManager defaultManager] removeItemAtPath:tmpCloneRepoPath error:nil]) {
                NSCParameterAssert(NO);
            }
        }

        // make repo non-empty by default
        int gitCloneExitStatus = 0;
        GitRepository *tmpRepo = [GitRepository cloneRepoAtURL:templateRepoPath destinationPath:tmpCloneRepoPath exitStatus:&gitCloneExitStatus];
        NSCParameterAssert(tmpRepo);
        NSCParameterAssert(0 == gitCloneExitStatus);

        [tmpRepo createFile:@".gitignore" withContents:@"# add files you want to ignore here\n"];
        [tmpRepo add:@[@".gitignore"]];
        [tmpRepo commitWithMessage:@"add .gitignore"];
        [tmpRepo pushCurrentBranch];

        if (NO == [NSFileManager.defaultManager removeItemAtPath:tmpCloneRepoPath error:nil]) {
            NSCParameterAssert(NO);
        }
    });

    NSString *repoParentDirPath = [absoluteFilePath stringByDeletingLastPathComponent];

    NSError *error = nil;
    if (NO == [NSFileManager.defaultManager createDirectoryAtPath:repoParentDirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSAssert(NO, @"");
    }

    if (NO == [NSFileManager.defaultManager copyItemAtPath:templateRepoPath toPath:absoluteFilePath error:&error]) {
        NSAssert(NO, @"");
    }

    GitRepository *repo = [[GitRepository alloc] initWithRepoPath:absoluteFilePath bare:YES];
    NSAssert(repo, @"");

    return repo;
}

- (GitRepository *)githubRd2Repo {
    if (nil == _githubRd2Repo) {
        _githubRd2Repo = [self initializeRemoteRepoAtRelativePath:@"github/rd2"];
        NSAssert(_githubRd2Repo, @"");
    }

    return _githubRd2Repo;
}

- (GitRepository *)githubReaddleLibRepo {
    if (nil == _githubReaddleLibRepo) {
        _githubReaddleLibRepo = [self initializeRemoteRepoAtRelativePath:@"github/ReaddleLib"];
        NSAssert(_githubReaddleLibRepo, @"");
    }
    return _githubReaddleLibRepo;
}

- (GitRepository *)githubRDSFTPRepo {
    if (nil == _githubRDSFTPRepo) {
        _githubRDSFTPRepo = [self initializeRemoteRepoAtRelativePath:@"github/RDSFTPOnlineClient"];
        NSAssert(_githubRDSFTPRepo, @"");
    }
    return _githubRDSFTPRepo;
}

- (GitRepository *)githubRDPDFKitRepo {
    if (nil == _githubRDPDFKitRepo) {
        _githubRDPDFKitRepo = [self initializeRemoteRepoAtRelativePath:@"github/RDPDFKit"];
        NSAssert(_githubRDPDFKitRepo, @"");
    }
    return _githubRDPDFKitRepo;
}

- (GitRepository *)githubFormCalcRepo {
    if (nil == _githubFormCalcRepo) {
        _githubFormCalcRepo = [self initializeRemoteRepoAtRelativePath:@"github/FormCalc"];
        NSAssert(_githubFormCalcRepo, @"");
    }
    return _githubFormCalcRepo;
}

- (GitRepository *)githubTestBareRepo {
    if (nil == _githubTestBareRepo) {
        NSString *absoluteFilePath = [self.root stringByAppendingPathComponent:@"github/bare"];
        int exitStatus = 0;
        _githubTestBareRepo = [GitRepository initializeRepositoryAtPath:absoluteFilePath bare:YES exitStatus:&exitStatus];
        NSAssert(0 == exitStatus, @"");
        NSAssert(_githubTestBareRepo, @"");
    }

    return _githubTestBareRepo;
}

- (GitRepository *)pasteyRd2Repo {
    if (nil == _pasteyRd2Repo) {
        executeInDirectory(self.root, ^int{
            int gitCloneExitStatus = 0;
            _pasteyRd2Repo = [GitRepository cloneRepoAtURL:self.githubRd2Repo.absolutePath
                                           destinationPath:@"pastey/projects/rd2"
                                                exitStatus:&gitCloneExitStatus];
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
            _nikRd2Repo = [GitRepository cloneRepoAtURL:self.githubRd2Repo.absolutePath
                                        destinationPath:@"nik/rd2"
                                             exitStatus:&gitCloneExitStatus];
            NSParameterAssert(_nikRd2Repo);
            NSParameterAssert(0 == gitCloneExitStatus);
            return gitCloneExitStatus;
        });
    }

    return _nikRd2Repo;
}

@end
