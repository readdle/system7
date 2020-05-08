//
//  S7MergeCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 07.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7MergeCommand.h"

#import "S7Diff.h"

// «сам у себя ворую, имею право» (c) Высоцкий
//  (merge algorithm has been stolen from locparse)
//
typedef enum {
    NO_CHANGES,
    UPDATED,
    DELETED,
    ADDED
} ChangeType;

@implementation S7SubrepoDescriptionConflict

- (instancetype)initWithOurVersion:(nullable S7SubrepoDescription *)ourVersion theirVersion:(nullable S7SubrepoDescription *)theirVersion {
    self = [super initWithPath:@"CONFLICT" url:@"CONFLICT" revision:@"CONFLICT" branch:nil];
    if (nil == self) {
        return nil;
    }

    NSAssert(ourVersion || theirVersion, @"at least one must be non-nil");

    _ourVersion = ourVersion;
    _theirVersion = theirVersion;

    return self;
}

- (BOOL)isEqual:(id)object {
    if (NO == [object isKindOfClass:[S7SubrepoDescriptionConflict class]]) {
        return NO;
    }

    S7SubrepoDescriptionConflict *other = (S7SubrepoDescriptionConflict *)object;

    if (self.ourVersion) {
        if (NO == [self.ourVersion isEqual:other.ourVersion]) {
            return NO;
        }
    }
    else if (other.ourVersion) {
        return NO;
    }

    if (self.theirVersion) {
        if (NO == [self.theirVersion isEqual:other.theirVersion]) {
            return NO;
        }
    }
    else if (other.theirVersion) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    return self.ourVersion.hash ^ self.theirVersion.hash;
}

@end

@implementation S7MergeCommand

- (void)printCommandHelp {
    puts("s7 merge BASE_REV OUR_REV THEIR_REV");
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    NSString *baseRevision = nil;
    NSString *ourRevision = nil;
    NSString *theirRevision = nil;

    // if fast-forward – can fallback to checkout?

    for (NSString *argument in arguments) {
        if ([argument hasPrefix:@"-"]) {
//            if ([argument isEqualToString:@"-C"] || [argument isEqualToString:@"-clean"]) {
//                self.clean = YES;
//            }
//            else {
                fprintf(stderr,
                        "option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [self printCommandHelp];
                return S7ExitCodeUnrecognizedOption;
//            }
        }
        else {
            if (nil == baseRevision) {
                baseRevision = argument;
            }
            else if (nil == ourRevision) {
                ourRevision = argument;
            }
            else if (nil == theirRevision) {
                theirRevision = argument;
            }
            else {
                fprintf(stderr,
                        "redundant argument %s\n",
                        [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [self printCommandHelp];
                return S7ExitCodeInvalidArgument;
            }
        }
    }

    if (nil == baseRevision) {
        fprintf(stderr,
                "required argument BASE_REV is missing\n");
        [self printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    if (nil == ourRevision) {
        fprintf(stderr,
                "required argument OUR_REV is missing\n");
        [self printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    if (nil == theirRevision) {
        fprintf(stderr,
                "required argument THEIR_REV is missing\n");
        [self printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if (NO == [repo isRevisionAvailable:baseRevision] && NO == [baseRevision isEqualToString:[GitRepository nullRevision]]) {
        fprintf(stderr,
                "BASE_REV %s is not available in this repository\n",
                [baseRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (NO == [repo isRevisionAvailable:ourRevision]) {
        fprintf(stderr,
                "OUR_REV %s is not available in this repository\n",
                [ourRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (NO == [repo isRevisionAvailable:theirRevision]) {
        fprintf(stderr,
                "THEIR_REV %s is not available in this repository\n",
                [theirRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    return [self mergeRepo:repo baseRevision:baseRevision ourRevision:ourRevision theirRevision:theirRevision];
}


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
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourUpdate = nil;
    diffConfigs(baseConfig, ourConfig, &ourDelete, &ourUpdate, &ourAdd);

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirUpdate = nil;
    diffConfigs(baseConfig, theirConfig, &theirDelete, &theirUpdate, &theirAdd);

    NSMutableArray<S7SubrepoDescription *> * result = [NSMutableArray arrayWithCapacity:ourConfig.subrepoDescriptions.count];

    BOOL foundConflict = NO;

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

        foundConflict = YES;
    }

    NSMutableDictionary * sortHint = [NSMutableDictionary dictionaryWithCapacity:ourConfig.subrepoDescriptions.count];

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
//        else {
//            // both sides add the same source line. If one side adds it not translated
//            // then we can pick the other side (assuming it has translated the line)
//            // and avoid conflict
//            //
//            if ([ourVersion.translation isEqualToString:ourVersion.source]) {
//                [result addObject:theirVersion];
//                continue;
//            }
//            else if ([theirVersion.translation isEqualToString:theirVersion.source]) {
//                [result addObject:ourVersion];
//                continue;
//            }
//        }

        S7SubrepoDescriptionConflict * conflict = [[S7SubrepoDescriptionConflict alloc] initWithOurVersion:ourVersion
                                                                                              theirVersion:theirVersion];
        [result addObject:conflict];

        foundConflict = YES;
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
//
////    if (foundConflict && error) {
////        *error = [NSError errorWithDomain:LocMergeErrorDomain code:LocMergeErrorConflict userInfo:nil];
////    }

    return [[S7Config alloc] initWithSubrepoDescriptions:result];
}

- (int)mergeRepo:(GitRepository *)repo
    baseRevision:(NSString *)baseRevision
     ourRevision:(NSString *)ourRevision
   theirRevision:(NSString *)theirRevision
{
    int getConfigExitStatus = 0;

    S7Config *baseConfig = nil;
    getConfigExitStatus = getConfig(repo, baseRevision, &baseConfig);
    if (0 != getConfigExitStatus) {
        return getConfigExitStatus;
    }

    S7Config *ourConfig = nil;
    getConfigExitStatus = getConfig(repo, ourRevision, &ourConfig);
    if (0 != getConfigExitStatus) {
        return getConfigExitStatus;
    }

    S7Config *theirConfig = nil;
    getConfigExitStatus = getConfig(repo, theirRevision, &theirConfig);
    if (0 != getConfigExitStatus) {
        return getConfigExitStatus;
    }

    S7Config *mergeResult = [self.class mergeOurConfig:ourConfig theirConfig:theirConfig baseConfig:baseConfig];
    mergeResult = mergeResult;

    return 0;
}

@end


