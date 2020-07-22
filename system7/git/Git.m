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


@implementation GitRepository

#pragma mark - Environment

+ (NSString *)envGitExecutablePath {
    static dispatch_once_t onceToken;
    static NSString *gitExecutablePath;
    dispatch_once(&onceToken, ^{
        NSString *PATH = [[NSProcessInfo processInfo].environment objectForKey:@"PATH"];
        NSArray<NSString *> *pathComponents = [PATH componentsSeparatedByString:@":"];
        for (NSString *pathComponent in pathComponents) {
            NSString *possibleGitExecutablePath = [pathComponent stringByAppendingPathComponent:@"git"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:possibleGitExecutablePath]) {
                gitExecutablePath = possibleGitExecutablePath;
                break;
            }
        }
    });
    
    if (nil == gitExecutablePath) {
        fprintf(stderr, "failed to locate 'git' executable in your system. Looked through PATH – nothing there.\n");
        exit(1);
    }
    
    return gitExecutablePath;
}

+ (NSArray<NSString *> *_Nullable)envGitConfiguration {
    static dispatch_once_t onceToken;
    static NSArray<NSString *> *configuration;
    dispatch_once(&onceToken, ^{
        NSString *const value = [NSProcessInfo processInfo].environment[@"S7_CONFIG"];
        configuration = [value componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    });
    
    return configuration;
}

#pragma mark - Initialization

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
    
    _configuration = [GitRepository envGitConfiguration];

    return self;
}

+ (nullable instancetype)repoAtPath:(NSString *)repoPath {
    return [[self alloc] initWithRepoPath:repoPath];
}

+ (nullable GitRepository *)cloneRepoAtURL:(NSString *)url
                           destinationPath:(NSString *)destinationPath
                                exitStatus:(int *)exitStatus
{
    return [self cloneRepoAtURL:url branch:nil destinationPath:destinationPath exitStatus:exitStatus];
}

+ (nullable GitRepository *)cloneRepoAtURL:(NSString *)url
                                    branch:(NSString * _Nullable)branch
                           destinationPath:(NSString *)destinationPath
                                exitStatus:(int *)exitStatus
{
    NSString *branchOption = branch.length > 0 ? [NSString stringWithFormat:@"-b %@", branch] : @"";
    NSString *command = [NSString stringWithFormat:@"clone %@ \"%@\" \"%@\"", branchOption, url, destinationPath];

    *exitStatus = [self executeGitCommand:command configuration:nil];

    if (0 != *exitStatus) {
        return nil;
    }

    return [[GitRepository alloc] initWithRepoPath:destinationPath];
}

+ (nullable GitRepository *)initializeRepositoryAtPath:(NSString *)path bare:(BOOL)bare exitStatus:(nonnull int *)exitStatus {
    NSString *command = @"init";
    if (bare) {
        command = [command stringByAppendingString:@" --bare"];
    }

    command = [command stringByAppendingFormat:@" %@", path];

    const int gitInitResult = [self executeGitCommand:command configuration:nil];

    *exitStatus = gitInitResult;

    if (0 != gitInitResult) {
        return nil;
    }

    return [[GitRepository alloc] initWithRepoPath:path bare:bare];
}

#pragma mark - utils -

+ (int)executeGitCommand:(NSString *)command
           configuration:(NSArray<NSString *> *_Nullable)configuration
{
    command = [NSString stringWithFormat:@"git %@ %@",
               [[self taskArgumentsFromConfiguration:configuration arguments:@[]] componentsJoinedByString:@" "],
               command];
    
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

    NSAssert(NO == [arguments.firstObject isEqualToString:@"git"],
             @"please, don't use git command itself – just arguments to git");

    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:arguments
                            configuration:self.configuration
                             stdOutOutput:ppStdOutOutput
                             stdErrOutput:ppStdErrOutput];
}

+ (int)runGitInRepoAtPath:(NSString *)repoPath
            withArguments:(NSArray<NSString *> *)arguments
            configuration:(NSArray<NSString *> *)configuration
             stdOutOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdOutOutput
             stdErrOutput:(NSString * _Nullable __autoreleasing * _Nullable)ppStdErrOutput
{
    NSTask *task = [NSTask new];
    [task setLaunchPath:[self envGitExecutablePath]];
    [task setArguments:[self taskArgumentsFromConfiguration:configuration
                                                  arguments:arguments]];
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

+ (NSArray<NSString *> *)taskArgumentsFromConfiguration:(NSArray<NSString *> *_Nullable)configuration
                                              arguments:(NSArray<NSString *> *)arguments
{
    if (configuration.count == 0) {
        return arguments;
    }
    
    NSMutableArray<NSString *> *const taskArguments = [NSMutableArray arrayWithCapacity:configuration.count * 2 + arguments.count];
    for (NSString *entry in configuration) {
        [taskArguments addObject:@"-c"]; // tagged pointer for sure
        [taskArguments addObject:entry];
    }
    [taskArguments addObjectsFromArray:arguments];
    
    return taskArguments;
}

#pragma mark - repo info -

- (BOOL)isBareRepo {
    // pastey:
    // this is an optimized version of this command that doesn't spawn real git process.
    // if we get any trouble with it, we can always return to an old and bullet-proof version,
    // which is saved (commented) at the bottom of this method
    //
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:[self.absolutePath stringByAppendingPathComponent:@".git"]]) {
        if ([NSFileManager.defaultManager fileExistsAtPath:[self.absolutePath stringByAppendingPathComponent:@"HEAD"]]) {
            NSString *config = [[NSString alloc] initWithContentsOfFile:[self.absolutePath stringByAppendingPathComponent:@"config"] encoding:NSUTF8StringEncoding error:nil];
            NSArray<NSString *> *configLines = [config componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            return [configLines containsObject:@"\tbare = true"];
        }
    }

    return NO;

//    NSString *stdOutOutput = nil;
//    const int exitStatus = [self runGitCommand:@"config --bool core.bare"
//                                  stdOutOutput:&stdOutOutput
//                                  stdErrOutput:NULL];
//    if (0 != exitStatus) {
//        return exitStatus;
//    }
//
//    return [stdOutOutput containsString:@"true"];
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
    for (NSString *fileName in headsDirectoryContents) {
        if (NO == [fileName hasPrefix:@"."]) {
            return NO;
        }
    }

    return YES;
}

- (void)printStatus {
    [self runGitCommand:@"status"
           stdOutOutput:NULL
           stdErrOutput:NULL];
}

#pragma mark - branches -

- (BOOL)isBranchTrackingRemoteBranch:(NSString *)branchName {
    // check if we are tracking this branch already
    NSString *devNullOutput = nil;
    if (0 == [self runGitCommand:[NSString stringWithFormat:@"config branch.%@.merge", branchName]
                    stdOutOutput:&devNullOutput
                    stdErrOutput:&devNullOutput])
    {
        return YES;
    }

    return NO;
}

- (BOOL)doesBranchExist:(NSString *)branchName {
    NSString *devNull = nil;
    const int revParseExitStatus = [self runGitCommand:[NSString stringWithFormat:@"rev-parse %@", branchName]
                                          stdOutOutput:&devNull
                                          stdErrOutput:&devNull];
    return 0 == revParseExitStatus;

}

- (int)checkoutRemoteTrackingBranch:(NSString *)branchName {
    // check if we are tracking this branch already
    if ([self isBranchTrackingRemoteBranch:branchName]) {
        return [self checkoutExistingLocalBranch:branchName];
    }
    
    if ([self doesBranchExist:branchName]) {
        return [self checkoutExistingLocalBranch:branchName];
    }

    return [self runGitCommand:[NSString stringWithFormat:@"checkout --track origin/%@", branchName]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)deleteRemoteBranch:(NSString *)branchName {
    NSAssert(NO == [branchName hasPrefix:@"origin/"], @"expecting raw branch name without remote name");
    return [self runGitCommand:[NSString stringWithFormat:@"push origin --delete %@", branchName]
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)deleteLocalBranch:(NSString *)branchName {
    return [self runGitCommand:[NSString stringWithFormat:@"branch -d %@", branchName]
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}

- (int)checkoutNewLocalBranch:(NSString *)branchName {
    return [self runGitCommand:[NSString stringWithFormat:@"checkout -b %@", branchName]
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}

- (int)checkoutExistingLocalBranch:(NSString *)branchName {
    return [self runGitCommand:[NSString stringWithFormat:@"checkout %@", branchName]
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}

- (int)forceCheckoutLocalBranch:(NSString *)branchName revision:(NSString *)revisions {
    // pastey: theoretically, one can be concerned with "injection" here
    // I think it's not a problem for two reasons:
    //  1. s7 is purely a developer tool, so if someone wants to do some harm and they have access to our code,
    //     they have an easier ways than injections
    //  2. anyway 'command' is then split into arguments and passed to git as an array, so git would most likely
    //     not accept these arguments; unless the user is super smart to build some fancy git command that allows
    //     exectuting different git commands (see point #1)
    //
    return [self runGitCommand:[NSString stringWithFormat:@"checkout -B %@ %@", branchName, revisions]
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}


- (int)getCurrentBranch:(NSString * _Nullable __autoreleasing * _Nonnull)ppBranch
         isDetachedHEAD:(BOOL *)isDetachedHEAD
            isEmptyRepo:(BOOL *)isEmptyRepo
{
    // pastey:
    // this is an optimized version of this command that doesn't spawn real git process.
    // if we get any trouble with it, we can always return to an old and bullet-proof version,
    // which is saved (commented) at the bottom of this method

    BOOL bareRepo = NO;
    NSError *error = nil;
    NSString *HEAD = [[NSString alloc]
                      initWithContentsOfFile:[self.absolutePath stringByAppendingPathComponent:@".git/HEAD"]
                      encoding:NSUTF8StringEncoding
                      error:&error];
    if (nil == HEAD) {
        if (NO == [self isBareRepo]) {
            return S7ExitCodeGitOperationFailed;
        }

        bareRepo = YES;

        error = nil;
        HEAD = [[NSString alloc]
                initWithContentsOfFile:[self.absolutePath stringByAppendingPathComponent:@"HEAD"]
                encoding:NSUTF8StringEncoding
                error:&error];
    }

    if (error || nil == HEAD) {
        NSAssert(NO, @"WTF?");
        return S7ExitCodeGitOperationFailed;
    }

    HEAD = [HEAD stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    if ([HEAD hasPrefix:@"ref: "]) {
        NSArray<NSString *> *components = [HEAD componentsSeparatedByString:@" "];
        NSAssert(2 == components.count, @"");

        NSString *ref = components.lastObject;

        NSString *refPath = bareRepo
            ? [self.absolutePath stringByAppendingPathComponent:ref]
            : [[self.absolutePath stringByAppendingPathComponent:@".git"] stringByAppendingPathComponent:ref];

        if (NO == [NSFileManager.defaultManager fileExistsAtPath:refPath]) {
            *isEmptyRepo = YES;
            return 0;
        }

        NSString *branchName = [ref stringByReplacingOccurrencesOfString:@"refs/heads/" withString:@""];
        NSAssert(branchName.length > 0, @"");
        *ppBranch = branchName;
    }
    else {
        *isDetachedHEAD = YES;
    }

    return 0;

//    NSString *stdOutOutput = nil;
//    NSString *devNull = nil;
//    const int revParseExitStatus = [self runGitCommand:@"rev-parse --abbrev-ref HEAD"
//                                          stdOutOutput:&stdOutOutput
//                                          stdErrOutput:&devNull];
//    if (0 != revParseExitStatus) {
//        if (128 == revParseExitStatus) {
//            // most likely – an empty repo. Let's make sure
//            if ([self isEmptyRepo]) {
//                *ppBranch = @"master";
//                return 0;
//            }
//        }
//        return revParseExitStatus;
//    }
//
//    NSString *branch = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    if (NO == [branch isEqualToString:@"HEAD"]) { // detached HEAD
//        *ppBranch = branch;
//    }
//
//    return 0;
}

#pragma mark - revisions -

+ (NSString *)nullRevision {
    static NSString *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [@"" stringByPaddingToLength:40 withString:@"0" startingAtIndex:0];
    });

    return result;
}

- (BOOL)isRevisionAvailableLocally:(NSString *)revision {
    NSParameterAssert(40 == revision.length);

//    // pastey:
//    // this is an optimized version of this command that doesn't spawn real git process.
//    // if we get any trouble with it, we can always return to an old and bullet-proof version,
//    // which is saved (commented) at the bottom of this method
//    //
//
//    BOOL isDirectory = NO;
//    NSString *objectsDirPath = [self.absolutePath stringByAppendingPathComponent:@".git/objects"];
//    if (NO == [NSFileManager.defaultManager fileExistsAtPath:objectsDirPath isDirectory:&isDirectory]) {
//        if ([self isBareRepo]) {
//            objectsDirPath = [self.absolutePath stringByAppendingPathComponent:@"objects"];
//            if (NO == [NSFileManager.defaultManager fileExistsAtPath:objectsDirPath isDirectory:&isDirectory]) {
//                NSAssert(NO, @"");
//                return NO;
//            }
//        }
//    }
//
//    if (NO == isDirectory) {
//        NSAssert(NO, @"");
//        return NO;
//    }
//
//    NSString *relativeObjectPath = [[revision substringToIndex:2] stringByAppendingPathComponent:[revision substringFromIndex:2]];
//    NSString *absoluteObjectPath = [objectsDirPath stringByAppendingPathComponent:relativeObjectPath];
//
//    return [NSFileManager.defaultManager fileExistsAtPath:absoluteObjectPath];

    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"cat-file -e %@", revision]
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return 0 == exitStatus;
}

- (BOOL)isRevisionDetached:(NSString *)revision numberOfOrphanedCommits:(int *)pNumberOfOrphanedCommits {
    NSString *stdOutOutput = nil;
    __unused const int exitStatus = [self
                                    runGitCommand:[NSString stringWithFormat:@"rev-list %@ --not --branches --remotes", revision]
                                    stdOutOutput:&stdOutOutput
                                    stdErrOutput:NULL];
    NSAssert(0 == exitStatus, @"");

    stdOutOutput = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (0 == stdOutOutput.length) {
        *pNumberOfOrphanedCommits = 0;
        return NO;
    }
    else {
        NSArray<NSString *> *commits = [stdOutOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        *pNumberOfOrphanedCommits = (int)commits.count;
        return YES;
    }
}

- (BOOL)isRevision:(NSString *)revision knownAtRemoteBranch:(NSString *)branchName {
    NSString *remoteBranchName = branchName;
    if (NO == [remoteBranchName hasPrefix:@"origin/"]) {
        remoteBranchName = [NSString stringWithFormat:@"origin/%@", branchName];
    }

    NSString *stdOutOutput = nil;
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"branch -r --contains %@ %@", revision, remoteBranchName]
                                  stdOutOutput:&stdOutOutput
                                  stdErrOutput:NULL];
    stdOutOutput = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return 0 == exitStatus && [stdOutOutput isEqualToString:remoteBranchName];
}

- (BOOL)isRevisionAnAncestor:(NSString *)possibleAncestor toRevision:(NSString *)possibleDescendant {
    NSParameterAssert(40 == possibleAncestor.length);
    NSParameterAssert(40 == possibleDescendant.length);

    NSString *stdOutOutput = nil;
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"merge-base %@ %@", possibleAncestor, possibleDescendant]
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
    NSString *devNull = nil;
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"show -s --format='%%H' %@^2", revision]
                                  stdOutOutput:&devNull
                                  stdErrOutput:&devNull];
    if (0 != exitStatus) {
        return NO;
    }

    return YES;
}

- (int)getCurrentRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision {
    // pastey:
    // this is an optimized version of this command that doesn't spawn real git process.
    // if we get any trouble with it, we can always return to an old and bullet-proof version,
    // which is saved (commented) at the bottom of this method

    NSString *revision = nil;

    BOOL bareRepo = NO;
    NSError *error = nil;
    NSString *HEAD = [[NSString alloc]
                      initWithContentsOfFile:[self.absolutePath stringByAppendingPathComponent:@".git/HEAD"]
                      encoding:NSUTF8StringEncoding
                      error:&error];
    if (nil == HEAD) {
        if (NO == [self isBareRepo]) {
            return 1;
        }

        bareRepo = YES;

        error = nil;
        HEAD = [[NSString alloc]
                initWithContentsOfFile:[self.absolutePath stringByAppendingPathComponent:@"HEAD"]
                encoding:NSUTF8StringEncoding
                error:&error];
    }

    if (error || nil == HEAD) {
        NSAssert(NO, @"WTF?");
        return S7ExitCodeGitOperationFailed;
    }

    HEAD = [HEAD stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    if ([HEAD hasPrefix:@"ref: "]) {
        NSArray<NSString *> *components = [HEAD componentsSeparatedByString:@" "];
        NSAssert(2 == components.count, @"");
        NSString *ref = components.lastObject;
        NSAssert(ref.length > 0, @"");

        NSString *refPath = bareRepo
            ? [self.absolutePath stringByAppendingPathComponent:ref]
            : [[self.absolutePath stringByAppendingPathComponent:@".git"] stringByAppendingPathComponent:ref];

        NSString *refContents = [[NSString alloc]
                                 initWithContentsOfFile:refPath
                                 encoding:NSUTF8StringEncoding
                                 error:&error];
        if (nil == refContents) {
            *ppRevision = [self.class nullRevision];
            return 0;
        }

        revision = [refContents stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }
    else {
        // detached HEAD
        revision = HEAD;
    }

//    NSString *stdOutOutput = nil;
//    NSString *devNull = nil;
//    const int revParseExitStatus = [self runGitCommand:@"rev-parse HEAD"
//                                          stdOutOutput:&stdOutOutput
//                                          stdErrOutput:&devNull];
//    if (0 != revParseExitStatus) {
//        if (128 == revParseExitStatus) {
//            // most likely – an empty repo. Let's make sure
//            if ([self isEmptyRepo]) {
//                *ppRevision = [self.class nullRevision];
//                return 0;
//            }
//        }
//        return revParseExitStatus;
//    }
//
//    NSString *revision = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    if (revision.length < 40) {
//        if ([self isBareRepo] && [revision isEqualToString:@"HEAD"]) {
//            // an empty and bare revision. Most likely a newborn repo
//            *ppRevision = [self.class nullRevision];
//            return 0;
//        }
//    }

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
    const int revParseExitStatus = [self runGitCommand:[NSString stringWithFormat:@"rev-parse %@", remoteBranchName]
                                          stdOutOutput:&stdOutOutput
                                          stdErrOutput:NULL];
    if (0 != revParseExitStatus) {
        return revParseExitStatus;
    }

    NSString *revision = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSAssert(40 == revision.length, @"");
    *ppRevision = revision;

    return 0;
}

- (int)checkoutRevision:(NSString *)revision {
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"checkout %@", revision]
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

#pragma mark - remote -

- (int)getRemote:(NSString * _Nullable __autoreleasing * _Nonnull)ppRemote {
    NSString *stdOutOutput = nil;
    const int exitStatus = [self runGitCommand:@"remote"
                                  stdOutOutput:&stdOutOutput
                                  stdErrOutput:NULL];
    if (0 != exitStatus) {
        return exitStatus;
    }

    NSString *remote = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    *ppRemote = remote;

    return 0;
}

- (int)getUrl:(NSString * _Nullable __autoreleasing * _Nonnull)ppUrl {
    NSString *stdOutOutput = nil;
    const int exitStatus = [self runGitCommand:@"remote get-url origin"
                                  stdOutOutput:&stdOutOutput
                                  stdErrOutput:NULL];
    if (0 != exitStatus) {
        return exitStatus;
    }

    NSString *url = [stdOutOutput stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    *ppUrl = url;

    return 0;
}

#pragma mark - exchange -

- (int)fetch {
    const int exitStatus = [self runGitCommand:@"fetch"
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

- (int)pull {
    const int exitStatus = [self runGitCommand:@"pull"
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

- (int)mergeWith:(NSString *)commit {
    // pastey:
    // this is a zalipon for a recursive interactive merge of subrepos. See example situation in case-recursiveMerge.sh
    // In English, we had a problem:
    //  - user wants to merge two branches in main repo (rd2)
    //  - git notices that .s7substate needs to be merged; git calls s7 merge-driver
    //  - s7 merge-driver sees that a subrepo (RDPDFKit) has diverged. s7 asks user what to do. User decides to merge
    //  - s7 calls git merge on RDPDFKit
    //  - RDPDFKit is an s7 repo on its own. .s7substate in RDPDFKit needs to be merged. Git calls s7 merge-driver
    //  - s7 merge-driver sees that RDPDFKit subrepo (FormCalc) has diverged. Ask user. User says – merge.
    //  - hang!!!
    //
    // Turned out that we hanged in `fgets`. I.e. it was waiting for user's input. But user did answer. He could type
    // as mad, but nothing happened at s7 side. stdin was somehow FUBAR at s7 side.
    //
    // As you can see, there's a bunch of buddies calling each other here, and every step passes stdin to the next
    // command in one way or another:
    //  - git calls s7 merge-driver. I looked into git code – it runs `sh -c <merge-driver>`. So here's the first
    //    stdin juggling. Git creates pipes between shell and itself. Shell most likely fork/exec-s s7 and stdin
    //    from shell is inherited by s7
    //  - then s7 reads stdin and runs `git merge`. Used to run it using NSTask here. NSTask documentation says
    //    that child process will inherit stdin from the calling process (s7)
    //  - git merge calls s7 for subrepo. Shell. S7
    //  - stdin FUBAR
    //
    // I've spent like four hours trying to find what's wrong with stdin. I dup-ed it, reopened, closed, checked all
    // I could come up with. Nothing helped. The only zalipon that helps, is to use `system`, which would
    // run git using shell. I'm not sure why this works. To investigate this further one might use strace (dtruss),
    // but I'm full. Will investigate this further if we meet more trouble. To use dtruss one will have to disable SIP.
    //
    return executeInDirectory(self.absolutePath, ^int{
        return [self.class executeGitCommand:[NSString stringWithFormat:@"merge --no-edit %@", commit]
                               configuration:self.configuration];
    });
}

- (int)merge {
    return [self runGitCommand:@"merge --no-edit"
                  stdOutOutput:NULL
                  stdErrOutput:NULL];
}

- (BOOL)hasUnpushedCommits {
    NSString *stdOutOutput = nil;
    const int logExitStatus = [self runGitCommand:@"log --branches --not --remotes --pretty=format:%h"
                                     stdOutOutput:&stdOutOutput
                                     stdErrOutput:NULL];
    if (0 != logExitStatus) {
        return NO;
    }

    __block BOOL result = NO;
    [stdOutOutput enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (line.length > 0) {
            result = YES;
            *stop = YES;
        }
    }];

    return result;
}

- (int)pushCurrentBranch {
    NSString *currentBranchName = nil;
    BOOL dummy = NO;
    const int getBranchExitStatus = [self getCurrentBranch:&currentBranchName isDetachedHEAD:&dummy isEmptyRepo:&dummy];
    if (0 != getBranchExitStatus) {
        return getBranchExitStatus;
    }

    return [self pushBranch:currentBranchName];
}

- (int)pushBranch:(NSString *)branchName {
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"push -u origin %@", branchName]
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

- (int)pushAll {
    const int exitStatus = [self runGitCommand:@"push --all"
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

#pragma mark - reset -

- (int)resetLocalChanges {
    const int exitStatus = [self runGitCommand:@"reset --hard HEAD" stdOutOutput:NULL stdErrOutput:NULL];
    if (0 != exitStatus) {
        return exitStatus;
    }

    return [self runGitCommand:@"clean -fd" stdOutOutput:NULL stdErrOutput:NULL];
}

- (int)resetHardToRevision:(NSString *)revision {
    const int exitStatus = [self runGitCommand:[NSString stringWithFormat:@"reset --hard %@", revision]
                                  stdOutOutput:NULL
                                  stdErrOutput:NULL];
    return exitStatus;
}

#pragma mark - examine history -

- (NSArray<NSString *> *)logRevisionsOfFile:(NSString *)filePath
                                    fromRef:(NSString *)fromRef
                                      toRef:(NSString *)toRef
                                 exitStatus:(int *)exitStatus
{
    NSParameterAssert(filePath.length > 0);
    
    NSString *command =
    [NSString stringWithFormat:@"log %@..%@ --reverse --pretty=format:%%H -- %@",
     fromRef,
     toRef,
     filePath];
    
    return [self runRevisionsCommand:command exitStatus:exitStatus];
}

- (NSArray<NSString *> *)logNotPushedCommitsFromRef:(NSString *)fromRef
                                               file:(nullable NSString *)filePath
                                         exitStatus:(int *)exitStatus
{
    NSString *command =
    [NSString stringWithFormat:@"log %@ --not --remotes --reverse --pretty=format:%%H",
     fromRef];
    
    if (filePath.length > 0) {
        command = [command stringByAppendingFormat:@" -- %@", filePath];
    }
    
    return [self runRevisionsCommand:command exitStatus:exitStatus];
}

- (NSArray<NSString *> *)runRevisionsCommand:(NSString *)command
                                  exitStatus:(int *)exitStatus
{
    NSParameterAssert(command);
    
    NSString *stdOutOutput = nil;
    const int logExitStatus = [self runGitCommand:command
                                     stdOutOutput:&stdOutOutput
                                     stdErrOutput:NULL];
    *exitStatus = logExitStatus;
    if (0 != logExitStatus) {
        NSAssert(NO, @"what?s");
        return @[];
    }

    NSMutableArray<NSString *> *result = [NSMutableArray new];
    [stdOutOutput enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (line.length > 0) {
            [result addObject:line];
        }
    }];
    return result;
}

- (NSString *)showFile:(NSString *)filePath atRevision:(NSString *)revision exitStatus:(int *)exitStatus {
    NSString *fileContents = nil;
    NSString *devNull = nil;
    NSString *spell = [NSString stringWithFormat:@"%@:%@", revision, filePath];
    *exitStatus = [self.class
                   runGitInRepoAtPath:self.absolutePath
                   withArguments:@[ @"show", spell ]
                   configuration:self.configuration
                   stdOutOutput:&fileContents
                   stdErrOutput:&devNull];
    return fileContents;
}

#pragma mark - commit -

- (BOOL)hasUncommitedChanges {
    if ([self isEmptyRepo]) {
        return NO;
    }

    // pastey:
    // we used to do the following here:
    //  git update-index -q --refresh
    //  git diff-index --quiet HEAD
    // Then, in some time to check for untracked files
    // I've added `status --porcelain` call, thus
    // update-index/diff-index became unnecessary. That's two
    // extra calls to external process.
    //
    
    NSString *statusOutput = nil;
    const int statusExitCode = [self.class
                                runGitInRepoAtPath:self.absolutePath
                                withArguments:@[ @"status", @"--porcelain", @"--untracked-files=normal" ]
                                configuration:self.configuration
                                stdOutOutput:&statusOutput
                                stdErrOutput:NULL];
    if (0 != statusExitCode) {
        return NO;
    }

    statusOutput = [statusOutput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return statusOutput.length > 0;
}

- (int)add:(NSArray<NSString *> *)filePaths {
    NSArray<NSString *> *args = [@[@"add", @"--"] arrayByAddingObjectsFromArray:filePaths];
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:args
                            configuration:self.configuration
                             stdOutOutput:NULL
                             stdErrOutput:NULL];
}

- (int)commitWithMessage:(NSString *)message {
    return [self.class runGitInRepoAtPath:self.absolutePath
                            withArguments:@[ @"commit", [NSString stringWithFormat:@"-m'%@'", message] ]
                            configuration:self.configuration
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

- (int)runGitCommand:(NSString *)command additionalConfiguration:(NSArray<NSString *> *)configuration {
    NSArray<NSString *> *const currentConfiguration = self.configuration;
    self.configuration = [self.configuration arrayByAddingObjectsFromArray:configuration];
    const int code = [self runGitCommand:command stdOutOutput:nil stdErrOutput:nil];
    self.configuration = currentConfiguration;
    
    return code;
}

@end


NS_ASSUME_NONNULL_END
