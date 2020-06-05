//
//  Git.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 27.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "Git.h"
#import "Utils.h"

#include <stdlib.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *gitExecutablePath = nil;

@implementation GitRepository

+ (void)load {
    NSString *PATH = [[NSProcessInfo processInfo].environment objectForKey:@"PATH"];
    NSArray<NSString *> *pathComponents = [PATH componentsSeparatedByString:@":"];
    for (NSString *pathComponent in pathComponents) {
        NSString *possibleGitExecutablePath = [pathComponent stringByAppendingPathComponent:@"git"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:possibleGitExecutablePath]) {
            gitExecutablePath = possibleGitExecutablePath;
            break;
        }
    }

    if (nil == gitExecutablePath) {
        fprintf(stderr, "failed to locate 'git' executable in your system. Looked through PATH – nothing there.\n");
        exit(1);
    }
}

- (nullable instancetype)initWithRepoPath:(NSString *)repoPath {
    return [self initWithRepoPath:repoPath bare:NO];
}

- (nullable instancetype)initWithRepoPath:(NSString *)repoPath bare:(BOOL)bare {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    if (NO == bare) {
        BOOL isDirectory = NO;
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:[repoPath stringByAppendingPathComponent:@".git"] isDirectory:&isDirectory]
            || NO == isDirectory)
        {
            fprintf(stderr, "'%s' is not a git repository.\n", [repoPath fileSystemRepresentation]);
            return nil;
        }
    }

    if ([repoPath hasPrefix:@"/"]) {
        _absolutePath = [repoPath stringByStandardizingPath];
    }
    else {
        _absolutePath = [[[NSFileManager.defaultManager currentDirectoryPath] stringByAppendingPathComponent:repoPath] stringByStandardizingPath];
    }

    return self;
}

+ (nullable instancetype)repoAtPath:(NSString *)repoPath {
    return [[self alloc] initWithRepoPath:repoPath];
}

+ (nullable GitRepository *)cloneRepoAtURL:(NSString *)url
                           destinationPath:(NSString *)destinationPath
                                exitStatus:(int *)exitStatus
{
    NSString *command = [NSString stringWithFormat:@"git clone %@ %@", url, destinationPath];

    *exitStatus = [self executeCommand:command];

    if (0 != *exitStatus) {
        return nil;
    }

    return [[GitRepository alloc] initWithRepoPath:destinationPath];
}

+ (nullable GitRepository *)initializeRepositoryAtPath:(NSString *)path bare:(BOOL)bare exitStatus:(nonnull int *)exitStatus {
    NSString *command = @"git init";
    if (bare) {
        command = [command stringByAppendingString:@" --bare"];
    }

    command = [command stringByAppendingFormat:@" %@", path];

    const int gitInitResult = [self executeCommand:command];

    *exitStatus = gitInitResult;

    if (0 != gitInitResult) {
        return nil;
    }

    return [[GitRepository alloc] initWithRepoPath:path bare:bare];
}

#pragma mark - utils -

+ (int)executeCommand:(NSString *)command {
    return system([command cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (int)runGitCommand:(NSString *)command
        stdOutOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdOutOutput
        stdErrOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdErrOutput
{
    // Local helper method to run simple git commands.
    //
    // Easier to use and read than -runGitInRepoAtPath:withArguments:,
    // which accepts an array of arguments.
    //
    // User must be cautios though – as this methods splits command into arguments
    // by whitespace, it cannot be used for arguments that may contain spaces,
    // for example, "commit -m\"up pdf kit\"" is a bad 'command' – it will confuse git
    // and it will fail.
    //
    NSArray<NSString *> *arguments = [command componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    arguments = [arguments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return evaluatedObject.length > 0;
    }]];

    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:arguments
                             stdOutOutput:ppStdOutOutput
                             stdErrOutput:ppStdErrOutput];
}

+ (int)runGitInRepoAtPath:(NSString *)repoPath
            withArguments:(NSArray<NSString *> *)arguments
             stdOutOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdOutOutput
             stdErrOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdErrOutput
{
    NSTask *task = [NSTask new];
    [task setLaunchPath:gitExecutablePath];
    [task setArguments:arguments];
    task.currentDirectoryURL = [NSURL fileURLWithPath:repoPath];

    // https://stackoverflow.com/questions/49184623/nstask-race-condition-with-readabilityhandler-block
    // we must use semaphore to make sure we finish reading from pipes properly once task finished it's execution.
    dispatch_semaphore_t pipeCloseSemaphore = dispatch_semaphore_create(0);

    __auto_type setUpPipeReadabilityHandler = ^ void (NSPipe *pipe, NSMutableData *resultingData) {
        __weak __auto_type weakPipe = pipe;
        pipe.fileHandleForReading.readabilityHandler = ^ (NSFileHandle * _Nonnull handle) {
            // DO NOT use -availableData in these handlers.
            NSData *newData = [handle readDataOfLength:NSUIntegerMax];
            if (0 == newData.length) {
                dispatch_semaphore_signal(pipeCloseSemaphore);

                __strong __auto_type strongPipe = weakPipe;
                strongPipe.fileHandleForReading.readabilityHandler = nil;
            }
            else {
               [resultingData appendData:newData];
            }
        };
    };

    __block NSMutableData *outputData = nil;
    if (ppStdOutOutput) {
        outputData = [NSMutableData new];
        NSPipe *outputPipe = [NSPipe new];
        task.standardOutput = outputPipe;
        setUpPipeReadabilityHandler(outputPipe, outputData);
    }

    NSMutableData *errorData = nil;
    if (ppStdErrOutput) {
        errorData = [NSMutableData new];
        NSPipe *errorPipe = [NSPipe new];
        task.standardError = errorPipe;
        setUpPipeReadabilityHandler(errorPipe, errorData);
    }

    NSError *error = nil;
    if (NO == [task launchAndReturnError:&error]) {
        fprintf(stderr, "failed to run git command. Error = %s", [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 1;
    }

    [task waitUntilExit];

    if (ppStdOutOutput) {
        dispatch_semaphore_wait(pipeCloseSemaphore, DISPATCH_TIME_FOREVER);

        NSString *stdOutOutput = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        *ppStdOutOutput = stdOutOutput;
    }

    if (ppStdErrOutput) {
        dispatch_semaphore_wait(pipeCloseSemaphore, DISPATCH_TIME_FOREVER);

        NSString *stdErrorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        *ppStdErrOutput = stdErrorOutput;
    }

    pipeCloseSemaphore = NULL;

    return [task terminationStatus];
}

#pragma mark - repo info -

- (BOOL)isBareRepo {
    NSString *stdOutOutput = nil;
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"config", @"--bool", @"core.bare" ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:NULL];
    if (0 != exitStatus) {
        return exitStatus;
    }

    return [stdOutOutput containsString:@"true"];
}

- (BOOL)isEmptyRepo {
    NSError *error = nil;
    NSArray *headsDirectoryContents =
    [[NSFileManager defaultManager]
     contentsOfDirectoryAtPath:[self.absolutePath stringByAppendingPathComponent:@".git/refs/heads/"]
     error:&error];

    if (error) {
        NSAssert(NO, @"");
        return NO;
    }

    // I could have checked if 'heads' dir is just empty, but I'm afraid of stuff like .DS_Store
    BOOL repoHasAnyHead = NO;
    for (NSString *fileName in headsDirectoryContents) {
        if (NO == [fileName hasPrefix:@"."]) {
            repoHasAnyHead = YES;
            break;
        }
    }

    if (repoHasAnyHead) {
        return NO;
    }

    return YES;
}

#pragma mark - branches -

- (BOOL)isBranchTrackingRemoteBranch:(NSString *)branchName {
    // check if we are tracking this branch already
    NSString *configSpell = [NSString stringWithFormat:@"branch.%@.merge", branchName];
    NSString *devNullOutput = nil;
    if (0 == [self.class runGitInRepoAtPath:self.absolutePath
                              withArguments:@[ @"config", configSpell ]
                               stdOutOutput:&devNullOutput
                               stdErrOutput:&devNullOutput])
    {
        return YES;
    }

    return NO;
}

- (int)checkoutRemoteTrackingBranch:(NSString *)branchName {
    NSAssert(NO == [branchName hasPrefix:@"origin/"], @"expecting raw branch name without remote name");

    // check if we are tracking this branch already
    if ([self isBranchTrackingRemoteBranch:branchName]) {
        return [self checkoutExistingLocalBranch:branchName];
    }

    NSString *remoteName = @"origin";
    NSString *fullBranchName = [NSString stringWithFormat:@"%@/%@", remoteName, branchName];

    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"checkout", @"--track", fullBranchName ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)checkoutNewLocalBranch:(NSString *)branchName {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"checkout", @"-b", branchName ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)checkoutExistingLocalBranch:(NSString *)branchName {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"checkout", branchName ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)forceCheckoutExistingLocalBranch:(NSString *)branchName revision:(NSString *)revisions {
    // pastey: theoretically, one can be concirned with "injection" here
    // I think it's not a problem for two reasons:
    //  1. s7 is purely a developer tool, so if someone wants to do some harm and they have access to our coce,
    //     they have an easier ways than injections
    //  2. anyway 'command' is then split into arguments and passed to git as an array, so git would most likely
    //     not accept these arguments; unless the user is super smart to build some fancy git command that allows
    //     exectuting different git commands (see point #1)
    //
    return [self runGitCommand:[NSString stringWithFormat:@"checkout -B %@ %@", branchName, revisions]
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}


- (int)getCurrentBranch:(NSString * _Nullable __autoreleasing * _Nonnull)ppBranch {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int revParseExitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"rev-parse", @"--abbrev-ref", @"HEAD" ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != revParseExitStatus) {
        if (128 == revParseExitStatus) {
            // most likely – an empty repo. Let's make sure
            if ([self isEmptyRepo]) {
                *ppBranch = @"master";
                return 0;
            }
        }
        return revParseExitStatus;
    }

    NSString *branch = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (NO == [branch isEqualToString:@"HEAD"]) { // detached HEAD
        *ppBranch = branch;
    }

    return 0;
}

- (BOOL)isInDetachedHEAD {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int revParseExitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"rev-parse", @"--abbrev-ref", @"HEAD" ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != revParseExitStatus) {
        return NO;
    }

    NSString *branch = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [branch isEqualToString:@"HEAD"];
}

#pragma mark - revisions -

+ (NSString *)nullRevision {
    static NSString *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [[NSMutableString alloc] initWithCapacity:40];
        for (int i=0; i<40; ++i) {
            [((NSMutableString *)result) appendString:@"0"];
        }
    });

    return result;
}

- (BOOL)isRevisionAvailableLocally:(NSString *)revision {
    const int exitStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"cat-file", @"-e", revision ]
                            stdOutOutput:NULL
                            stdErrOutput:NULL];
    return 0 == exitStatus;
}

- (BOOL)isRevision:(NSString *)revision knownAtRemoteBranch:(NSString *)branchName {
    NSString *remoteBranchName = branchName;
    if (NO == [remoteBranchName hasPrefix:@"origin/"]) {
        remoteBranchName = [NSString stringWithFormat:@"origin/%@", branchName];
    }

    NSString *stdOutOutput = nil;
    const int exitStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"branch", @"-r", @"--contains", revision, remoteBranchName ]
                            stdOutOutput:&stdOutOutput
                            stdErrOutput:NULL];
    stdOutOutput = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return 0 == exitStatus && [stdOutOutput isEqualToString:remoteBranchName];
}

- (BOOL)isRevisionAnAncestor:(NSString *)possibleAncestor toRevision:(NSString *)possibleDescendant {
    NSParameterAssert(40 == possibleAncestor.length);
    NSParameterAssert(40 == possibleDescendant.length);

    NSString *stdOutOutput = nil;
    const int exitStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"merge-base", possibleAncestor, possibleDescendant ]
                            stdOutOutput:&stdOutOutput
                            stdErrOutput:NULL];
    if (0 != exitStatus) {
        NSAssert(NO, @"");
        return NO;
    }

    NSString *mergeBaseRevision = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSAssert(40 == mergeBaseRevision.length, @"");

    return [possibleAncestor isEqualToString:mergeBaseRevision];
}

- (BOOL)isMergeRevision:(NSString *)revision {
    NSParameterAssert(40 == revision.length);

    // does it have two parents?
    // git show -s --format="%H" REV^2
    NSString *query = [NSString stringWithFormat:@"%@^2", revision];
    NSString *devNull = nil;
    const int exitStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"show", @"-s", @"--format='%H'", query ]
                            stdOutOutput:&devNull
                            stdErrOutput:&devNull];
    if (0 != exitStatus) {
        return NO;
    }

    return YES;
}

- (int)getCurrentRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int revParseExitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"rev-parse", @"HEAD" ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != revParseExitStatus) {
        if (128 == revParseExitStatus) {
            // most likely – an empty repo. Let's make sure
            if ([self isEmptyRepo]) {
                *ppRevision = [self.class nullRevision];
                return 0;
            }
        }
        return revParseExitStatus;
    }

    NSString *revision = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (revision.length < 40) {
        if ([self isBareRepo] && [revision isEqualToString:@"HEAD"]) {
            // an empty and bare revision. Most likely a newborn repo
            *ppRevision = [self.class nullRevision];
            return 0;
        }
    }

    NSAssert(40 == revision.length, @"");
    *ppRevision = revision;

    return 0;
}

- (int)getLatestRemoteRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision atBranch:(NSString *)branchName {
    NSString *remoteBranchName = branchName;
    if (NO == [remoteBranchName hasPrefix:@"origin/"]) {
        remoteBranchName = [NSString stringWithFormat:@"origin/%@", branchName];
    }

    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int revParseExitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"rev-parse", remoteBranchName ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != revParseExitStatus) {
        return revParseExitStatus;
    }

    NSString *revision = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSAssert(40 == revision.length, @"");
    *ppRevision = revision;

    return 0;
}

- (int)checkoutRevision:(NSString *)revision {
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                            withArguments:@[ @"checkout", revision ]
                                             stdOutOutput:NULL
                                             stdErrOutput:NULL];
    return exitStatus;
}

#pragma mark - remote -

- (int)getRemote:(NSString * _Nullable __autoreleasing * _Nonnull)ppRemote {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"remote" ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != exitStatus) {
        return exitStatus;
    }

    NSString *remote = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    *ppRemote = remote;

    return 0;
}

- (int)getUrl:(NSString * _Nullable __autoreleasing * _Nonnull)ppUrl forRemote:(NSString *)remote {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                                    withArguments:@[ @"remote", @"get-url", remote ]
                                                     stdOutOutput:&stdOutOutput
                                                     stdErrOutput:&stdErrOutput];
    if (0 != exitStatus) {
        return exitStatus;
    }

    NSString *url = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    *ppUrl = url;

    return 0;
}

#pragma mark - exchange -

- (int)fetch {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                            withArguments:@[ @"fetch" ]
                                             stdOutOutput:&stdOutOutput
                                             stdErrOutput:&stdErrOutput];
    return exitStatus;
}

- (int)pull {
    NSString *stdOutOutput = nil;
    NSString *stdErrOutput = nil;
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                            withArguments:@[ @"pull" ]
                                             stdOutOutput:&stdOutOutput
                                             stdErrOutput:&stdErrOutput];
    return exitStatus;
}

- (int)mergeWith:(NSString *)commit {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"merge", @"--no-edit", commit ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)merge {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"merge", @"--no-edit" ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (BOOL)hasUnpushedCommits {
    int dummy = 0;
    return [self branchesToPushWithExitStatus:&dummy].count > 0;
}

- (NSArray<NSString *> *)branchesToPushWithExitStatus:(int *)exitStatus {
    NSString *stdOutOutput = nil;
    const int logExitStatus = [self runGitCommand:@"log --branches --not --remotes --no-walk --decorate --pretty=format:%S"
                                     stdOutOutput:&stdOutOutput
                                     stdErrOutput:NULL];
    *exitStatus = logExitStatus;
    if (0 != logExitStatus) {
        return @[];
    }

    NSArray<NSString *> *result = [stdOutOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    result = [result filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return evaluatedObject.length > 0;
    }]];
    return result;
}

- (int)pushAllBranchesNeedingPush {
    int logExitStatus = 0;
    NSArray<NSString *> *branchesToPush = [self branchesToPushWithExitStatus:&logExitStatus];
    if (0 != logExitStatus) {
        return logExitStatus;
    }

    if (0 == branchesToPush.count) {
        fprintf(stdout, "found nothing to push\n");
        return 0;
    }

    NSString *branches = [branchesToPush componentsJoinedByString:@" "];

    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"push -u origin %@", branches]
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

- (int)pushCurrentBranch {
    NSString *currentBranchName = nil;
    const int getBranchExitStatus = [self getCurrentBranch:&currentBranchName];
    if (0 != getBranchExitStatus) {
        return getBranchExitStatus;
    }

    return [self pushBranch:currentBranchName];
}

- (int)pushBranch:(NSString *)branchName {
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                            withArguments:@[ @"push", @"-u", @"origin", branchName ]
                                             stdOutOutput:NULL
                                             stdErrOutput:NULL];
    return exitStatus;
}

#pragma mark - reset -

- (int)resetLocalChanges {
    // from mercurial subrepos.py:
    //  "first reset the index to unmark new files for commit, because
    //   reset --hard will otherwise throw away files added for commit,
    //   not just unmark them"

    const int exitStatus = [self runGitCommand:@"reset HEAD" stdOutOutput:NULL stdErrOutput:NULL];
    if (0 != exitStatus) {
        return exitStatus;
    }

    return [self runGitCommand:@"reset --hard HEAD" stdOutOutput:NULL stdErrOutput:NULL];
}

- (int)resetToRevision:(NSString *)revision {
    const int exitStatus = [self.class runGitInRepoAtPath:self.absolutePath
                                            withArguments:@[ @"reset", @"--hard", revision ]
                                             stdOutOutput:NULL
                                             stdErrOutput:NULL];
    return exitStatus;
}


- (NSString *)showFile:(NSString *)filePath atRevision:(NSString *)revision exitStatus:(int *)exitStatus {
    NSString *fileContents = nil;
    NSString *devNull = nil;
    NSString *spell = [NSString stringWithFormat:@"%@:%@", revision, filePath];
    *exitStatus = [self.class
                   runGitInRepoAtPath:self.absolutePath
                   withArguments:@[ @"show", spell ]
                   stdOutOutput:&fileContents
                   stdErrOutput:&devNull];
    return fileContents;
}

- (BOOL)hasUncommitedChanges {
    if ([self isEmptyRepo]) {
        return NO;
    }
    
    // borrowed from by mercurial/subrepo.py
    //
    // """This must be run before git diff-index.
    //    diff-index only looks at changes to file stat;
    //    this command looks at file contents and updates the stat."""
    //
    // git update-index -q --refresh
    // git diff-index --quiet HEAD
    //
    const int updateIndexStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"update-index", @"-q", @"--refresh" ]
                            stdOutOutput:NULL
                            stdErrOutput:NULL];
    if (0 != updateIndexStatus) {
        return updateIndexStatus;
    }

    // should you be curious, yes 'update-index' understands only '-q'
    // and 'diff-index' understands only '--quiet'.
    // And yes, 'git status' returns 0 in any case – either there're changes
    // or not.
    //
    const int diffIndexStatus = [self.class
                            runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"diff-index", @"--quiet", @"HEAD" ]
                            stdOutOutput:NULL
                            stdErrOutput:NULL];
    if (0 != diffIndexStatus) {
        return YES;
    }

    NSString *statusOutput = nil;
    const int statusExitCode = [self.class
                                runGitInRepoAtPath:self.absolutePath
                                withArguments:@[ @"status", @"--porcelain", @"--untracked-files=normal" ]
                                stdOutOutput:&statusOutput
                                stdErrOutput:NULL];
    if (0 != statusExitCode) {
        return NO;
    }

    static NSRegularExpression *unknownFileRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unknownFileRegex = [NSRegularExpression regularExpressionWithPattern:@"^\?\? " options:0 error:nil];
        NSCAssert(unknownFileRegex, @"");
    });

    NSTextCheckingResult *match = [unknownFileRegex firstMatchInString:statusOutput options:0 range:NSMakeRange(0, statusOutput.length)];
    return (match != nil);
}

- (int)add:(NSArray<NSString *> *)filePaths {
    NSArray<NSString *> *args = [@[@"add", @"--"] arrayByAddingObjectsFromArray:filePaths];
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:args
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)commitWithMessage:(NSString *)message {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"commit", [NSString stringWithFormat:@"-m'%@'", message] ]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

@end

@implementation GitRepository (Tests)

- (int)createFile:(NSString *)relativeFilePath withContents:(nullable NSString *)contents {
    NSAssert(NO == [relativeFilePath hasPrefix:@"/"], @"relative please!");

    return executeInDirectory(self.absolutePath, ^int {
        if (NO == [NSFileManager.defaultManager createFileAtPath:relativeFilePath
                                                        contents:[contents dataUsingEncoding:NSUTF8StringEncoding]
                                                      attributes:nil]) {
            NSCAssert(NO, @"something went wrong!");
            return 1;
        }

        return 0;
    });
}

- (void)run:(void (NS_NOESCAPE ^)(GitRepository *repo))block {
    executeInDirectory(self.absolutePath, ^int {
        block(self);
        return 0;
    });
}

@end


NS_ASSUME_NONNULL_END
