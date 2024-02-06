//
//  S7KeepTargetBranchMergeStrategy.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 31.01.2024.
//  Copyright © 2024 Readdle. All rights reserved.
//

#import "S7KeepTargetBranchMergeStrategy.h"

#import "S7Diff.h"
#import "Utils.h"
#import "S7SubrepoDescriptionConflict.h"


@interface S7KeepTargetBranchMergeStrategy ()
@property (nonatomic) NSString *targetBranchName;
@end

@implementation S7KeepTargetBranchMergeStrategy

typedef enum {
    NO_CHANGES,
    UPDATED,
    DELETED,
    ADDED
} ChangeType;

- (instancetype)initWithTargetBranchName:(NSString *)targetBranchName {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    _targetBranchName = targetBranchName;

    return self;
}

- (S7Config *)mergeOurConfig:(S7Config *)ourConfig
                 theirConfig:(S7Config *)theirConfig
                  baseConfig:(S7Config *)baseConfig
            detectedConflict:(BOOL *)ppDetectedConflict
{
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *ourUpdate = nil;
    diffConfigs(baseConfig, ourConfig, &ourDelete, &ourUpdate, &ourAdd);

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirDelete = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirAdd = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *theirUpdate = nil;
    diffConfigs(baseConfig, theirConfig, &theirDelete, &theirUpdate, &theirAdd);

    // TODO: Extract
    NSMutableSet<NSString *> *formallyUpdatedSubrepos = [NSMutableSet new];
    [theirUpdate enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull subrepoPath, S7SubrepoDescription * _Nonnull desc, BOOL * _Nonnull _) {
        S7SubrepoDescription *baseDesc = baseConfig.pathToDescriptionMap[subrepoPath];
        if ([baseDesc.revision isEqualToString:desc.revision]) {
            [formallyUpdatedSubrepos addObject:subrepoPath];
        }
    }];

    [theirUpdate removeObjectsForKeys:formallyUpdatedSubrepos.allObjects];
    // TODO: -

    NSMutableArray<S7SubrepoDescription *> * result = [NSMutableArray arrayWithCapacity:ourConfig.subrepoDescriptions.count];

    __block BOOL detectedConflict = NO;

    __auto_type recordConflict = ^(S7SubrepoDescription * _Nullable ourVersion, S7SubrepoDescription * _Nullable theirVersion) {
        S7SubrepoDescriptionConflict *conflict = [[S7SubrepoDescriptionConflict alloc]
                                                  initWithOurVersion:ourVersion
                                                  theirVersion:theirVersion];
        [result addObject:conflict];

        detectedConflict = YES;
    };

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
                S7SubrepoDescription *ourVersion = ourConfig.pathToDescriptionMap[subrepoPath];
                S7SubrepoDescription *theirVersion = [theirUpdate objectForKey:subrepoPath];
                recordConflict(ourVersion, theirVersion);
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

        // either both sides have changed this line, but in a different way,
        // or one side have changed and the other have deleted
        // so this is a conflict

        if (DELETED == ourChanges && UPDATED == theirChanges) {
            // the result of a keep-target-branch strategy should not prone user to make an error and leave
            // not the target branch in the resulting .s7substate file.
            // In this case (our delete, their update), user will be asked to make a choice:
            //  (d)elete or use a (c)hanged version ?
            // if user decides to keep a changed version and theirVersion is not at the targetBranch, then we have
            // high chance for the wrong branch to slip into to the resulting file.
            // To prevent this, we slightly fool the user (and the merge driver) into thinking that he's deciding
            // between (d)elete and (c)hanged, where changed points to the targetBranch.
            //
            S7SubrepoDescription *theirVersionOnTargetBranch = [[S7SubrepoDescription alloc]
                                                                initWithPath:theirVersion.path
                                                                url:theirVersion.url
                                                                revision:theirVersion.revision
                                                                branch:self.targetBranchName];
            theirVersionOnTargetBranch.comment = [NSString stringWithFormat:@"Originally from `%@` branch.",
                                                  theirVersion.branch];

            recordConflict(ourVersion, theirVersionOnTargetBranch);
        }
        else {
            recordConflict(ourVersion, theirVersion);
        }
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

        if ([ourVersion isEqual:theirVersion ignoreBranches:YES]) {
            [result addObject:ourVersion];
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
        S7SubrepoDescription *their = [theirAdd objectForKey:addedLineSource];
        S7SubrepoDescription *theirOnTargetBranch = [[S7SubrepoDescription alloc] initWithPath:their.path
                                                                                           url:their.url
                                                                                      revision:their.revision
                                                                                        branch:self.targetBranchName];
        [result addObject:theirOnTargetBranch];
    }

    *ppDetectedConflict = detectedConflict;

    return [[S7Config alloc] initWithSubrepoDescriptions:result];
}

- (ChangeType)changesToSubrepoAtPath:(NSString *)path
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

@end
