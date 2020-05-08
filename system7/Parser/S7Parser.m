//
//  S7Parser.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Parser.h"
#import "S7Types.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S7SubrepoDescription

- (instancetype)initWithPath:(NSString *)path
                         url:(NSString *)url
                    revision:(NSString *)revision
                      branch:(nullable NSString *)branch
{
    self = [super init];
    if (nil == self) {
        return nil;
    }

    NSParameterAssert(path);
    NSParameterAssert(url);
    NSParameterAssert(revision);
    NSParameterAssert(nil == branch || branch.length > 0);

    _path = path;
    _url = url;
    _revision = revision;
    _branch = branch;

    return self;
}

#pragma mark -

- (BOOL)isEqual:(id)object {
    if (NO == [object isKindOfClass:[S7SubrepoDescription class]]) {
        return NO;
    }

    S7SubrepoDescription *other = (S7SubrepoDescription *)object;

    if (self.branch && other.branch) {
        if (NO == [self.branch isEqualToString:other.branch]) {
            return NO;
        }
    }
    else if (NO == (nil == self.branch && nil == other.branch)) {
        return NO;
    }

    return [self.path isEqualToString:other.path] &&
           [self.url isEqualToString:other.url] &&
           [self.revision isEqualToString:other.revision];
}

- (NSUInteger)hash {
    return self.path.hash ^ self.url.hash ^ self.revision.hash ^ self.branch.hash;
}

#pragma mark -

- (NSString *)stringRepresentation {
    NSString *branchComponent = @"";
    if (self.branch) {
        branchComponent = [NSString stringWithFormat:@", %@", self.branch];
    }
    return [NSString stringWithFormat:@"%@ = { %@, %@%@ }", self.path, self.url, self.revision, branchComponent ];
}

#pragma mark -

- (NSString *)description {
    return self.stringRepresentation;
}

@end

@implementation S7Config

static BOOL _allowNon40DigitRevisions = NO;

+ (BOOL)allowNon40DigitRevisions {
    return _allowNon40DigitRevisions;
}

+ (void)setAllowNon40DigitRevisions:(BOOL)allowNon40DigitRevisions {
    _allowNon40DigitRevisions = allowNon40DigitRevisions;
}

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

        NSString *branch = nil;
        if (3 == propertiesComponents.count) {
            branch = [[propertiesComponents objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (0 == branch.length) {
                branch = nil;
            }
        }

        S7SubrepoDescription *subrepoDesc = [[S7SubrepoDescription alloc] initWithPath:path url:url revision:revision branch:branch];

        [subrepoDescriptions addObject:subrepoDesc];
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

    NSError *error = nil;
    if (NO == [configContents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error]
        || error)
    {
        fprintf(stderr, "failed to save %s to disk. Error: %s\n",
                [S7ConfigFileName cStringUsingEncoding:NSUTF8StringEncoding],
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 1;
    }

    return 0;
}

- (BOOL)isEqual:(id)object {
    if (NO == [object isKindOfClass:[S7Config class]]) {
        return NO;
    }

    S7Config *other = (S7Config *)object;
    return [other.subrepoDescriptions isEqual:self.subrepoDescriptions];
}

- (NSUInteger)hash {
    NSUInteger result = 0;
    for (S7SubrepoDescription *subrepoDesc in self.subrepoDescriptions) {
        result ^= subrepoDesc.hash;
    }
    return result;
}

@end




NS_ASSUME_NONNULL_END
