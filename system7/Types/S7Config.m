//
//  S7Config.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Config.h"
#import "S7Types.h"
#import "S7SubrepoDescriptionConflict.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S7Config

- (nullable instancetype)initWithContentsOfFile:(NSString *)configFilePath {
    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&isDirectory]) {
        return [self initWithSubrepoDescriptions:@[]];
    }

    if (isDirectory) {
        logError("failed to load config at path '%s'. File is a directory.", configFilePath.fileSystemRepresentation);
        return nil;
    }

    NSError *error = nil;
    NSString *fileContents = [[NSString alloc] initWithContentsOfFile:configFilePath
                                                             encoding:NSUTF8StringEncoding
                                                                error:&error];
    if (nil == fileContents || error) {
        logError("failed to load config at path '%s'. Failed to read string content.", configFilePath.fileSystemRepresentation);
        return nil;
    }

    return [self initWithContentsString:fileContents];
}

- (nullable instancetype)initWithContentsString:(NSString *)fileContents {
    NSMutableArray<S7SubrepoDescription *> *subrepoDescriptions = [NSMutableArray new];

    NSArray *lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    BOOL inConflict = NO;
    BOOL collectingOurSideConflict = NO;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *conflictOurSideSubrepoDescriptions = nil;
    NSMutableDictionary<NSString *, S7SubrepoDescription *> *conflictTheirSideSubrepoDescriptions = nil;

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == trimmedLine.length) {
            // skip empty lines
            continue;
        }

        if ([trimmedLine hasPrefix:@"#"]) {
            // skip comments
            continue;
        }

        if ([trimmedLine hasPrefix:@"<<<<<<<"]) {
            if (inConflict) {
                logError("unexpected conflict marker. Already parsing conflict.\n");
                return nil;
            }

            inConflict = YES;
            collectingOurSideConflict = YES;

            conflictOurSideSubrepoDescriptions = [NSMutableDictionary new];
            conflictTheirSideSubrepoDescriptions = [NSMutableDictionary new];

            continue;
        }
        else if ([trimmedLine hasPrefix:@"======="]) {
            if (NO == inConflict) {
                logError("unexpected conflict separator marker. Not parsing conflict.\n");
                return nil;
            }

            collectingOurSideConflict = NO;

            continue;
        }
        else if ([trimmedLine hasPrefix:@">>>>>>>"]) {
            if (NO == inConflict) {
                logError("unexpected conflict end marker. Not parsing conflict.\n");
                return nil;
            }

            if (collectingOurSideConflict) {
                logError("unexpected conflict end marker. Expected conflict separator '=====...' marker\n");
                return nil;
            }

            inConflict = NO;

            // Use arrays here to keep an order of subrepos.
            // This will result in a better diff of .s7substate file.
            // An alternative way would be to throw our and their subrepo paths in a single set,
            // and iterate over that set here – would remove the need of a separate run through
            // 'conflictTheirSideSubrepoDescriptions', but would change the order of lines
            // in .s7substate
            //
            NSArray<NSString *> *ourSideConflictPaths = [conflictOurSideSubrepoDescriptions.allKeys copy];
            for (NSString *subrepoPath in ourSideConflictPaths) {
                S7SubrepoDescription *ourDesc = conflictOurSideSubrepoDescriptions[subrepoPath];
                S7SubrepoDescription *theirDesc = conflictTheirSideSubrepoDescriptions[subrepoPath];

                S7SubrepoDescriptionConflict *conflict = [[S7SubrepoDescriptionConflict alloc]
                                                          initWithOurVersion:ourDesc
                                                          theirVersion:theirDesc];
                [subrepoDescriptions addObject:conflict];
            }

            [conflictOurSideSubrepoDescriptions removeObjectsForKeys:ourSideConflictPaths];
            [conflictTheirSideSubrepoDescriptions removeObjectsForKeys:ourSideConflictPaths];

            for (NSString *subrepoPath in conflictTheirSideSubrepoDescriptions.allKeys) {
                S7SubrepoDescription *theirDesc = conflictTheirSideSubrepoDescriptions[subrepoPath];

                S7SubrepoDescriptionConflict *conflict = [[S7SubrepoDescriptionConflict alloc]
                                                          initWithOurVersion:nil
                                                          theirVersion:theirDesc];
                [subrepoDescriptions addObject:conflict];
            }

            conflictOurSideSubrepoDescriptions = nil;
            conflictTheirSideSubrepoDescriptions = nil;

            continue;
        }

        S7SubrepoDescription *subrepoDesc = [[S7SubrepoDescription alloc] initWithConfigLine:trimmedLine];
        if (nil == subrepoDesc) {
            logError("failed to parse config. Invalid line '%s'", [line cStringUsingEncoding:NSUTF8StringEncoding]);
            return nil;
        }

        if (inConflict) {
            if (collectingOurSideConflict) {
                conflictOurSideSubrepoDescriptions[subrepoDesc.path] = subrepoDesc;
            }
            else {
                conflictTheirSideSubrepoDescriptions[subrepoDesc.path] = subrepoDesc;
            }
        }
        else {
            [subrepoDescriptions addObject:subrepoDesc];
        }
    }

    if (inConflict) {
        logError("not terminated conflict\n");
        return nil;
    }

    return [self initWithSubrepoDescriptions:subrepoDescriptions];
}

+ (nullable instancetype)configWithString:(NSString *)configContents {
    return [[self alloc] initWithContentsString:configContents];
}

+ (instancetype)emptyConfig {
    return [[S7Config alloc] initWithSubrepoDescriptions:@[]];
}

- (instancetype)initWithSubrepoDescriptions:(NSArray<S7SubrepoDescription *> *)subrepoDescriptions {
    self = [super init];
    if (nil == self) {
        return nil;
    }

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *pathToDescriptionMap = [NSMutableDictionary new];
    NSMutableSet<NSString *> *subrepoPathsSet = [NSMutableSet new];

    for (S7SubrepoDescription *subrepoDesc in subrepoDescriptions) {
        if ([subrepoPathsSet containsObject:subrepoDesc.path]) {
            logError("duplicate path '%s' in config.", subrepoDesc.path.fileSystemRepresentation);
            return nil;
        }

        [pathToDescriptionMap setObject:subrepoDesc forKey:subrepoDesc.path];
        [subrepoPathsSet addObject:subrepoDesc.path];
    }

    _subrepoDescriptions = subrepoDescriptions;
    _pathToDescriptionMap = pathToDescriptionMap;
    _subrepoPathsSet = subrepoPathsSet;

    return self;
}

- (int)saveToFileAtPath:(NSString *)filePath {
    NSMutableString *configContents = [[NSMutableString alloc] initWithCapacity:self.subrepoDescriptions.count * 100]; // quick approximation
    for (S7SubrepoDescription *subrepoDescription in self.subrepoDescriptions) {
        if (subrepoDescription.comment) {
            [configContents appendString:@"# "];
            [configContents appendString:subrepoDescription.comment];
            [configContents appendString:@"\n"];
        }
        [configContents appendString:[subrepoDescription stringRepresentation]];
        [configContents appendString:@"\n"];
    }

    // for future desperado programmers:
    // `atomically:YES` is crucial here. I want to write all or nothing, not to leave half-written file
    // to a user.
    // If you decide to bring more OOP here in the future (like, make each S7SubrepoDescription
    // write its own part), remember about atomicity – write to temp file/string and replace the whole content
    //
    NSError *error = nil;
    if (NO == [configContents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error]
        || error)
    {
        logError("failed to save %s to disk. Error: %s\n",
                filePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    return S7ExitCodeSuccess;
}

- (BOOL)isEqual:(id)object {
    if (NO == [object isKindOfClass:[S7Config class]]) {
        return NO;
    }

    S7Config *other = (S7Config *)object;
    return [other.pathToDescriptionMap isEqual:self.pathToDescriptionMap];
}

- (NSUInteger)hash {
    NSUInteger result = 0;
    for (S7SubrepoDescription *subrepoDesc in self.subrepoDescriptions) {
        result ^= subrepoDesc.hash;
    }
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<S7Config: %p. Subrepos = \n%@\n>", self, self.subrepoDescriptions];
}

#pragma mark -

static BOOL _allowNon40DigitRevisions = NO;

+ (BOOL)allowNon40DigitRevisions {
    return _allowNon40DigitRevisions;
}

+ (void)setAllowNon40DigitRevisions:(BOOL)allowNon40DigitRevisions {
    _allowNon40DigitRevisions = allowNon40DigitRevisions;
}

@end


NS_ASSUME_NONNULL_END
