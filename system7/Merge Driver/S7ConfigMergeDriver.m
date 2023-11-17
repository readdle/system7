//
//  S7ConfigMergeDriver.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 18.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7ConfigMergeDriver.h"

#import "S7Diff.h"
#import "Utils.h"
#import "S7PostCheckoutHook.h"
#import "S7SubrepoDescriptionConflict.h"


@implementation S7ConfigMergeDriver

- (instancetype)init {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    [self setResolveConflictBlock:^S7ConflictResolutionOption(S7SubrepoDescription * _Nullable ourVersion,
                                                              S7SubrepoDescription * _Nullable theirVersion)
     {
        return [S7ConfigMergeDriver resolveConflictBetweenOurVersion:ourVersion theirVersion:theirVersion];
     }];

    return self;
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: config merge driver start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: config merge driver complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    // do not check for S7ConfigFileName existance. It's OK for one side not to have
    // it. Also, if we merge two sides that add S7 independently, then for some
    // reason, on merge there's not .s7substate in the working dir

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if (arguments.count < 3) {
        char *names[] = { "BASE", "OUR", "THEIR" };
        fprintf(stderr,
                "required argument %s is missing\n",
                names[arguments.count]);
        return S7ExitCodeMissingRequiredArgument;
    }

    NSString *baseConfigFilePath = arguments[0];
    NSString *ourConfigFilePath = arguments[1];
    NSString *theirConfigFilePath = arguments[2];

    S7Config *baseConfig = [[S7Config alloc] initWithContentsOfFile:baseConfigFilePath];
    S7Config *ourConfig = [[S7Config alloc] initWithContentsOfFile:ourConfigFilePath];
    S7Config *theirConfig = [[S7Config alloc] initWithContentsOfFile:theirConfigFilePath];

    return [self mergeRepo:repo
                baseConfig:baseConfig
                 ourConfig:ourConfig
               theirConfig:theirConfig
      saveResultToFilePath:ourConfigFilePath];
}

typedef enum {
    NO_CHANGES,
    UPDATED,
    DELETED,
    ADDED
} ChangeType;

+ (ChangeType)changesToSubrepoAtPath:(NSString *)path
                      inDeletedLines:(NSDictionary<NSString *, S7SubrepoDescription *> *)deleted
                        updatedLines:(NSDictionary<NSString *, S7SubrepoDescription *> *)updated
{
    ChangeType changes = NO_CHANGES;
    if ([deleted objectForKey:path]) {
        changes = DELETED;
    }
    else if ([updated objectForKey:path]) {
        changes = UPDATED;
    }

    return changes;
}

+ (S7Config *)mergeOurConfig:(S7Config *)ourConfig theirConfig:(S7Config *)theirConfig baseConfig:(S7Config *)baseConfig {
    BOOL dummy = NO;
    return [self mergeOurConfig:ourConfig theirConfig:theirConfig baseConfig:baseConfig detectedConflict:&dummy];
}

+ (S7Config *)mergeOurConfig:(S7Config *)ourConfig
                 theirConfig:(S7Config *)theirConfig
                  baseConfig:(S7Config *)baseConfig
            detectedConflict:(BOOL *)ppDetectedConflict
{
    // «сам у себя ворую, имею право» (c) Высоцкий
    //  (merge algorithm has been stolen from locparse)
    //

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourUpdate = nil;
    diffConfigs(baseConfig, ourConfig, &ourDelete, &ourUpdate, &ourAdd);

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirUpdate = nil;
    diffConfigs(baseConfig, theirConfig, &theirDelete, &theirUpdate, &theirAdd);

    NSMutableArray<S7SubrepoDescription *> * result = [NSMutableArray arrayWithCapacity:ourConfig.subrepoDescriptions.count];

    BOOL detectedConflict = NO;

    for (S7SubrepoDescription *baseSubrepoDesc in baseConfig.subrepoDescriptions) {
        NSString * const subrepoPath = baseSubrepoDesc.path;

        const ChangeType ourChanges = [self changesToSubrepoAtPath:subrepoPath inDeletedLines:ourDelete updatedLines:ourUpdate];
        const ChangeType theirChanges = [self changesToSubrepoAtPath:subrepoPath inDeletedLines:theirDelete updatedLines:theirUpdate];

        const BOOL bothSidesHaveNotChangedThisLine = (NO_CHANGES == ourChanges && NO_CHANGES == theirChanges);
        if (bothSidesHaveNotChangedThisLine) {
            [result addObject:baseSubrepoDesc];
            continue;
        }

        const BOOL bothSidesHaveDeletedThisLine = (DELETED == ourChanges && DELETED == theirChanges);
        if (bothSidesHaveDeletedThisLine) {
            // if it's deleted, then it will get deleted by not being added to the results
            continue;
        }

        const BOOL onlyOneSideHaveChangedThisLine = (NO_CHANGES == ourChanges || NO_CHANGES == theirChanges);
        if (onlyOneSideHaveChangedThisLine) {
            if (UPDATED == ourChanges) {
                S7SubrepoDescription *ourVersion = [ourUpdate objectForKey:subrepoPath];
                [result addObject:ourVersion];
            }
            else if (UPDATED == theirChanges) {
                S7SubrepoDescription *theirVersion = [theirUpdate objectForKey:subrepoPath];
                [result addObject:theirVersion];
            }

            // if it's deleted, then it will get deleted by not being added to the results

            continue;
        }

        // version will be nil in case line was deleted at that side
        S7SubrepoDescription * ourVersion = [ourUpdate objectForKey:subrepoPath];
        S7SubrepoDescription * theirVersion = [theirUpdate objectForKey:subrepoPath];

        const BOOL bothSidesHaveUpdatedThisLine = (UPDATED == ourChanges && UPDATED == theirChanges);
        if (bothSidesHaveUpdatedThisLine) {
            if ([ourVersion isEqual:theirVersion]) {
                // both sides have changed line in the same way – take any version, this is not a conflict
                S7SubrepoDescription * any = ourVersion;
                [result addObject:any];
                continue;
            }
        }

        // either boths side have changed this line, but in a different way,
        // or one side have changed and the other have deleted
        // so this is a conflict

        S7SubrepoDescriptionConflict *conflict = [[S7SubrepoDescriptionConflict alloc]
                                                  initWithOurVersion:ourVersion
                                                  theirVersion:theirVersion];
        [result addObject:conflict];

        detectedConflict = YES;
    }

    NSMutableDictionary<NSString *, NSNumber *> *sortHint = [NSMutableDictionary dictionaryWithCapacity:ourConfig.subrepoDescriptions.count];

    for (NSUInteger i = 0; i < ourConfig.subrepoDescriptions.count; ++i) {

        S7SubrepoDescription *ourVersion = ourConfig.subrepoDescriptions[i];

        sortHint[ourVersion.path] = @(i);

        if (nil == [ourAdd objectForKey:ourVersion.path]) {
            continue;
        }

        // we cannot just insert our added line at the same position they were in ourLines
        // as every deletion from the right shifts lines

        NSString * const addedSubrepoPath = ourVersion.path;

        S7SubrepoDescription *theirVersion = [theirAdd objectForKey:addedSubrepoPath];

        // mark as processed
        [theirAdd removeObjectForKey:addedSubrepoPath];

        if (nil == theirVersion) {
            [result addObject:ourVersion];
            continue;
        }

        if ([ourVersion isEqual:theirVersion]) {
            S7SubrepoDescription *any = ourVersion;
            [result addObject:any];
            continue;
        }

        S7SubrepoDescriptionConflict * conflict = [[S7SubrepoDescriptionConflict alloc] initWithOurVersion:ourVersion
                                                                                              theirVersion:theirVersion];
        [result addObject:conflict];

        detectedConflict = YES;
    }

    // sort as it is in our
    [result sortUsingComparator:^NSComparisonResult(S7SubrepoDescription *yellow, S7SubrepoDescription *blue) {
        if ([yellow isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
            yellow = [(S7SubrepoDescriptionConflict*)yellow ourVersion];
        }

        if ([blue isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
            blue = [(S7SubrepoDescriptionConflict*)blue ourVersion];
        }

        if (nil == yellow || nil == blue) {
            // our side has deleted this line and their side has modified it
            return NSOrderedAscending;
        }

        NSNumber * yellowIndex = sortHint[yellow.path];
        NSNumber * blueIndex = sortHint[blue.path];

        return [yellowIndex compare:blueIndex];
    }];

    // finished by adding what left from their added subrepos
    for (NSString * addedLineSource in theirAdd) {
        S7SubrepoDescription *theirVersion = [theirAdd objectForKey:addedLineSource];
        [result addObject:theirVersion];
    }

    *ppDetectedConflict = detectedConflict;

    return [[S7Config alloc] initWithSubrepoDescriptions:result];
}

- (S7SubrepoDescription *)mergeSubrepoConflict:(S7SubrepoDescriptionConflict *)conflictToMerge exitStatus:(int *)exitStatus {
    GitRepository *subrepoGit = [GitRepository repoAtPath:conflictToMerge.path];
    if (nil == subrepoGit) {
        *exitStatus = S7ExitCodeSubrepoIsNotGitRepository;
        return conflictToMerge;
    }

    NSString *subrepoPath = conflictToMerge.path;
    NSString *theirRevision = conflictToMerge.theirVersion.revision;

    if (NO == [subrepoGit isRevisionAvailableLocally:theirRevision]) {
        fprintf(stdout,
                "fetching '%s'\n",
                [subrepoPath fileSystemRepresentation]);

        if (0 != [subrepoGit fetch]) {
            *exitStatus = S7ExitCodeGitOperationFailed;
            return conflictToMerge;
        }

        if (NO == [subrepoGit isRevisionAvailableLocally:theirRevision]) {
            fprintf(stderr,
                    "revision '%s' does not exist in '%s'\n",
                    [theirRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    subrepoPath.fileSystemRepresentation);

            *exitStatus = S7ExitCodeInvalidSubrepoRevision;
            return conflictToMerge;
        }
    }

    NSString *resultingBranchName = conflictToMerge.ourVersion.branch;

    const char *intermediateBranchNameCString = getenv("S7_MERGE_DRIVER_INTERMEDIATE_BRANCH");
    if (intermediateBranchNameCString) {
        NSString *intermediateBranchName = [[NSString alloc]
                                            initWithCString:intermediateBranchNameCString
                                            encoding:NSUTF8StringEncoding];

        if (0 != [subrepoGit checkoutNewLocalBranch:intermediateBranchName]) {
            *exitStatus = S7ExitCodeGitOperationFailed;
            return conflictToMerge;
        }

        resultingBranchName = intermediateBranchName;
    }

    if (0 != [subrepoGit mergeWith:theirRevision]) {
        *exitStatus = S7ExitCodeGitOperationFailed;
        return conflictToMerge;
    }

    NSString *mergeRevision = nil;
    if (0 != [subrepoGit getCurrentRevision:&mergeRevision]) {
        *exitStatus = S7ExitCodeGitOperationFailed;
        return conflictToMerge;
    }

    return [[S7SubrepoDescription alloc] initWithPath:subrepoPath
                                                  url:conflictToMerge.ourVersion.url
                                             revision:mergeRevision
                                               branch:resultingBranchName];
}

- (int)mergeRepo:(GitRepository *)repo
      baseConfig:(S7Config *)baseConfig
       ourConfig:(S7Config *)ourConfig
     theirConfig:(S7Config *)theirConfig
saveResultToFilePath:(NSString *)resultFilePath
{
    NSParameterAssert(baseConfig);
    NSParameterAssert(ourConfig);
    NSParameterAssert(theirConfig);

    BOOL detectedConflict = NO;
    S7Config *mergeResult = [self.class mergeOurConfig:ourConfig theirConfig:theirConfig baseConfig:baseConfig detectedConflict:&detectedConflict];
    NSParameterAssert(mergeResult);

    if (detectedConflict && NULL == self.resolveConflictBlock) {
        NSAssert(NO, @"WTF?!");
        return S7ExitCodeInternalError;
    }

    BOOL conflictResolved = YES;
    if (detectedConflict) {
        NSMutableArray<S7SubrepoDescription *> *resolvedMergeResultSubrepos =
            [NSMutableArray arrayWithCapacity:mergeResult.subrepoDescriptions.count];

        for (S7SubrepoDescription *subrepoDesc in mergeResult.subrepoDescriptions) {
            if (NO == [subrepoDesc isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
                [resolvedMergeResultSubrepos addObject:subrepoDesc];
                continue;
            }

            S7SubrepoDescriptionConflict *conflict = (S7SubrepoDescriptionConflict *)subrepoDesc;

            const S7ConflictResolutionOption userDecision = self.resolveConflictBlock(conflict.ourVersion,
                                                                                      conflict.theirVersion);

            if (S7ConflictResolutionOptionKeepConflict == userDecision) {
                conflictResolved = NO;
            }

            switch (userDecision) {
                case S7ConflictResolutionOptionKeepLocal:
                    [resolvedMergeResultSubrepos addObject:conflict.ourVersion];
                    break;

                case S7ConflictResolutionOptionKeepRemote:
                    [resolvedMergeResultSubrepos addObject:conflict.theirVersion];
                    break;

                case S7ConflictResolutionOptionMerge: {
                    int subrepoMergeExitStatus = 0;
                    S7SubrepoDescription *subrepoMergeResult = [self mergeSubrepoConflict:conflict exitStatus:&subrepoMergeExitStatus];
                    NSAssert(subrepoMergeResult, @"");
                    [resolvedMergeResultSubrepos addObject:subrepoMergeResult];

                    if (0 != subrepoMergeExitStatus) {
                        conflictResolved = NO;
                    }

                    break;
                }

                case S7ConflictResolutionOptionKeepChanged:
                    if (conflict.ourVersion) {
                        [resolvedMergeResultSubrepos addObject:conflict.ourVersion];
                    }
                    else {
                        NSAssert(conflict.theirVersion, @"");
                        [resolvedMergeResultSubrepos addObject:conflict.theirVersion];
                    }
                    break;

                case S7ConflictResolutionOptionDelete:
                    // do nothing – this subrepo's life has just finished
                    break;

                case S7ConflictResolutionOptionKeepConflict:
                    [resolvedMergeResultSubrepos addObject:conflict];
                    break;
            }
        }

        mergeResult = [[S7Config alloc] initWithSubrepoDescriptions:resolvedMergeResultSubrepos];
    }

    const int configSaveResult = [mergeResult saveToFileAtPath:resultFilePath];
    if (S7ExitCodeSuccess != configSaveResult) {
        return configSaveResult;
    }

    if (S7ExitCodeSuccess != [mergeResult saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);

        return S7ExitCodeFileOperationFailed;
    }

    if (NO == conflictResolved) {
        return S7ExitCodeMergeFailed;
    }

    return [S7PostCheckoutHook checkoutSubreposForRepo:repo fromConfig:ourConfig toConfig:mergeResult];
}

+ (S7ConflictResolutionOption)resolveConflictBetweenOurVersion:(S7SubrepoDescription * _Nullable)ourVersion
                                                  theirVersion:(S7SubrepoDescription * _Nullable)theirVersion
{
    {
        S7ConflictResolutionOption resolutionFromEnv;
        if ([self readMergeResolutionFromEnvironmentVariable:&resolutionFromEnv
                                                  ourVersion:ourVersion
                                                theirVersion:theirVersion])
        {
            return resolutionFromEnv;
        }
    }

    if (!isatty(fileno(stdin))) {
        fprintf(stderr,
                "\033[31m"
                "to run interactive merge of s7 subrepos, please run the following command in Terminal:\n"
                "\033[1m"
                "  git checkout -m .s7substate\n\n"
                "\033[m"
                "\033[0m");
        return S7ConflictResolutionOptionKeepConflict;
    }

    if (ourVersion && theirVersion) {
        S7ConflictResolutionOption possibleConflictResolutionOptions =
        S7ConflictResolutionOptionKeepLocal |
        S7ConflictResolutionOptionKeepRemote |
        S7ConflictResolutionOptionMerge;

        // should write this to stdout or stderr?
        fprintf(stdout,
                "\n"
                " subrepo '%s' has diverged\n"
                "  local revision: %s\n"
                "  remote revision: %s\n"
                "  you can (m)erge, keep (l)ocal or keep (r)emote.\n"
                "  what do you want to do? ",
                ourVersion.path.fileSystemRepresentation,
                [ourVersion.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding],
                [theirVersion.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]
                );

        return [S7ConfigMergeDriver
                readConflictResolutionFromStdinWithAllowedOptions:possibleConflictResolutionOptions
                prompt:@"\n  sorry?\n"
                "  (m)erge, keep (l)ocal or keep (r)emote.\n"
                "  what do you want to do? "];
    }
    else {
        NSCAssert(ourVersion || theirVersion, @"");
        S7ConflictResolutionOption possibleConflictResolutionOptions =
        S7ConflictResolutionOptionKeepChanged |
        S7ConflictResolutionOptionDelete;

        if (ourVersion) {
            fprintf(stdout,
                    "  local changed subrepository '%s' which remote removed\n"
                    "  use (c)hanged version or (d)elete? ",
                    ourVersion.path.fileSystemRepresentation);
        }
        else {
            fprintf(stdout,
                    "  remote changed subrepository '%s' which local removed\n"
                    "  use (c)hanged version or (d)elete? ",
                    ourVersion.path.fileSystemRepresentation);
        }

        return [S7ConfigMergeDriver
                readConflictResolutionFromStdinWithAllowedOptions:possibleConflictResolutionOptions
                prompt:@"\n  sorry?\n"
                "  use (c)hanged version or (d)elete? "];
    }
}

+ (BOOL)readMergeResolutionFromEnvironmentVariable:(S7ConflictResolutionOption *)pResolution
                                        ourVersion:(S7SubrepoDescription * _Nullable)ourVersion
                                      theirVersion:(S7SubrepoDescription * _Nullable)theirVersion
{
    NSString *const response = NSProcessInfo.processInfo.environment[@"S7_MERGE_DRIVER_RESPONSE"];
    if (response) {
        S7ConflictResolutionOption resolution;
        if (response.length > 0 &&
            [S7ConfigMergeDriver mergeResolution:&resolution
                                    forUserInput:[response characterAtIndex:0]
                              allowedResolutions:~0])
        {
            NSString *resolutionString;
            switch (resolution) {
                case S7ConflictResolutionOptionMerge:
                    resolutionString = @"merge";
                    break;
                case S7ConflictResolutionOptionKeepLocal:
                    resolutionString = @"keep local";
                    break;
                case S7ConflictResolutionOptionKeepRemote:
                    resolutionString = @"keep remote";
                    break;
                case S7ConflictResolutionOptionKeepChanged:
                    resolutionString = @"keep changed";
                    break;
                case S7ConflictResolutionOptionDelete:
                    resolutionString = @"delete";
                    break;
                case S7ConflictResolutionOptionKeepConflict:
                    resolutionString = @"keep conflict";
                    break;
            }

            fprintf(stdout,
                    "\n"
                    " subrepo '%s' has diverged\n"
                    "  local revision: %s\n"
                    "  remote revision: %s\n"
                    "  S7_MERGE_DRIVER_RESPONSE: %s\n",
                    ourVersion.path.fileSystemRepresentation,
                    [ourVersion.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding],
                    [theirVersion.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding],
                    [resolutionString cStringUsingEncoding:NSUTF8StringEncoding]
                    );

            *pResolution = resolution;
            return YES;
        }
        else {
            fprintf(stderr,
                    "\033[31m"
                    "  failed to recognize S7_MERGE_DRIVER_RESPONSE: '%s'\n"
                    "\033[0m",
                    [response cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }

    return NO;
}

+ (S7ConflictResolutionOption)readConflictResolutionFromStdinWithAllowedOptions:(S7ConflictResolutionOption)allowedResolutions
                                                                         prompt:(NSString *)prompt
{
    const int BUF_LEN = 20;
    char buf[BUF_LEN];

    NSUInteger numberOfTries = 0;
    do {
        ++numberOfTries;

        S7ConflictResolutionOption resolution;
        char *userInput = fgets(buf, BUF_LEN, stdin);
        if (userInput &&
            strlen(userInput) >= 1 &&
            [S7ConfigMergeDriver mergeResolution:&resolution
                                    forUserInput:userInput[0]
                              allowedResolutions:allowedResolutions])
        {
            return resolution;
        }

        fprintf(stdout, "%s", [prompt cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    while (numberOfTries < 5);

    fprintf(stderr, "too many attempts – will leave the conflict unresolved\n");

    return S7ConflictResolutionOptionKeepConflict;
}

+ (BOOL)mergeResolution:(S7ConflictResolutionOption *)pResolution
           forUserInput:(char)userInput
     allowedResolutions:(S7ConflictResolutionOption)allowedResolutions
{
    userInput = tolower(userInput);

    S7ConflictResolutionOption userResolution;
    switch (userInput) {
        case 'm':
            userResolution = S7ConflictResolutionOptionMerge;
            break;

        case 'l':
            userResolution = S7ConflictResolutionOptionKeepLocal;
            break;

        case 'r':
            userResolution = S7ConflictResolutionOptionKeepRemote;
            break;

        case 'c':
            userResolution = S7ConflictResolutionOptionKeepChanged;
            break;

        case 'd':
            userResolution = S7ConflictResolutionOptionDelete;
            break;

        default:
            return NO;
    }

    if (0 != (userResolution & allowedResolutions)) {
        *pResolution = userResolution;
        return YES;
    }

    return NO;
}

@end
