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
        fprintf(stderr, "failed to load config at path '%s'. File is a directory.", configFilePath.fileSystemRepresentation);
        return nil;
    }

    NSError *error = nil;
    NSString *fileContents = [[NSString alloc] initWithContentsOfFile:configFilePath
                                                             encoding:NSUTF8StringEncoding
                                                                error:&error];
    if (nil == fileContents || error) {
        fprintf(stderr, "failed to load config at path '%s'. Failed to read string content.", configFilePath.fileSystemRepresentation);
        return nil;
    }

    return [self initWithContentsString:fileContents];
}

- (nullable instancetype)initWithContentsString:(NSString *)fileContents {
    NSMutableArray<S7SubrepoDescription *> *subrepoDescriptions = [NSMutableArray new];

    NSArray *lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"(.*)\\s*=\\s*\\{(.*?)\\}\\s*(#.*)?\\s*"
                                  options:0
                                  error:&error];
    NSCAssert(regex && nil == error, @"");

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
                fprintf(stderr, "error: unexpected conflict marker. Already parsing conflict.\n");
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
                fprintf(stderr, "error: unexpected conflict separator marker. Not parsing conflict.\n");
                return nil;
            }

            collectingOurSideConflict = NO;

            continue;
        }
        else if ([trimmedLine hasPrefix:@">>>>>>>"]) {
            if (NO == inConflict) {
                fprintf(stderr, "error: unexpected conflict end marker. Not parsing conflict.\n");
                return nil;
            }

            if (collectingOurSideConflict) {
                fprintf(stderr, "error: unexpected conflict end marker. Expected conflict separator '=====...' marker\n");
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
                conflictOurSideSubrepoDescriptions[subrepoPath] = nil;
                S7SubrepoDescription *theirDesc = conflictTheirSideSubrepoDescriptions[subrepoPath];
                conflictTheirSideSubrepoDescriptions[subrepoPath] = nil;

                S7SubrepoDescriptionConflict *conflict = [[S7SubrepoDescriptionConflict alloc]
                                                          initWithOurVersion:ourDesc
                                                          theirVersion:theirDesc];
                [subrepoDescriptions addObject:conflict];
            }

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

        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:trimmedLine
                                                                  options:0
                                                                    range:NSMakeRange(0, trimmedLine.length)];
        if (1 != matches.count) {
            NSLog(@"ERROR: failed to parse config (1). Invalid line '%@'", line);
            return nil;
        }

        NSTextCheckingResult *match = matches.firstObject;
        if (4 != match.numberOfRanges) {
            NSLog(@"ERROR: failed to parse config (2). Invalid line '%@'", line);
            return nil;
        }

        const NSRange pathRange = [match rangeAtIndex:1];
        NSString *path = [trimmedLine substringWithRange:pathRange];
        path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == path.length) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. Empty path.", line);
            return nil;
        }

        const NSRange propertiesRange = [match rangeAtIndex:2];
        NSString *properties = [trimmedLine substringWithRange:propertiesRange];
        properties = [properties stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == properties.length) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. Empty properties.", line);
            return nil;
        }

        NSArray<NSString *> *propertiesComponents = [properties componentsSeparatedByString:@","];
        if (propertiesComponents.count < 2 || propertiesComponents.count > 3) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. Invalid preporties value", line);
            return nil;
        }

        NSString *url = [[propertiesComponents objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == url.length) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. Invalid url", line);
            return nil;
        }

        NSString *revision = [[propertiesComponents objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (NO == self.class.allowNon40DigitRevisions && 40 != revision.length) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. We expect full 40-symbol revisions.", line);
            return nil;
        }

        NSString *branch = [[propertiesComponents objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == branch.length) {
            NSLog(@"ERROR: failed to parse config. Invalid line '%@'. Invalid branch", line);
            return nil;
        }

        S7SubrepoDescription *subrepoDesc = [[S7SubrepoDescription alloc] initWithPath:path url:url revision:revision branch:branch];

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
        fprintf(stderr, "not terminated conflict\n");
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
            NSLog(@"ERROR: duplicate path '%@' in config.", subrepoDesc.path);
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
        fprintf(stderr, "failed to save %s to disk. Error: %s\n",
                [S7ConfigFileName cStringUsingEncoding:NSUTF8StringEncoding],
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    return 0;
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
