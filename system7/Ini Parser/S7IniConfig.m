//
//  S7IniConfig.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 29.09.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7IniConfig.h"

// this parser is very basic, as we don't need all features
// possible in Git config.
// https://git-scm.com/docs/git-config
// https://www.mercurial-scm.org/doc/hgrc.5.html
//  - no value continuation
//  - no special treatment of subsections
//  - no includes
//  - no quoted value containing escaped \\ and \"
//  - no other sophisticated things
//

@interface S7IniConfig ()
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *parsedConfig;
@end

@implementation S7IniConfig

- (instancetype)initWithParsedConfig:(NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)parsedConfig {
    NSParameterAssert(parsedConfig);

    self = [super init];
    if (nil == self) {
        return nil;
    }

    _parsedConfig = parsedConfig;

    return self;
}

+ (instancetype)configWithContentsOfFile:(NSString *)filePath {
    NSError *error = nil;
    NSString *fileContents = [[NSString alloc] initWithContentsOfFile:filePath
                                                             encoding:NSUTF8StringEncoding
                                                                error:&error];
    if (nil == fileContents || error) {
        fprintf(stderr, "failed to load config at path '%s'. Failed to read string content.", filePath.fileSystemRepresentation);
        return nil;
    }

    return [self configWithContentsOfString:fileContents];
}

+ (NSString *)parseSectionHeaderLine:(NSString *)trimmedLine {
    NSAssert([trimmedLine hasPrefix:@"["], @"");

    if (trimmedLine.length < 3) {
        // at least '[a]' – opening, closing brackets and one character
        return nil;
    }

    __block NSUInteger closingBracketIndex = NSNotFound;
    __block BOOL inQuotes = NO;
    [trimmedLine
     enumerateSubstringsInRange:NSMakeRange(1, trimmedLine.length - 1)
     options:NSStringEnumerationByComposedCharacterSequences
     usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange _, BOOL * _Nonnull stop) {
        if ([substring isEqualToString:@"\""]) {
            if (NO == inQuotes) {
                inQuotes = YES;
            }
            else {
                inQuotes = NO;
            }
        }
        else if (NO == inQuotes && [substring isEqualToString:@"]"]) {
            closingBracketIndex = substringRange.location;
            *stop = YES;
        }
     }];

    if (NSNotFound != closingBracketIndex) {
        NSString *stringBetweenBrackets = [trimmedLine substringWithRange:NSMakeRange(1, closingBracketIndex - 1)];
        NSString *trimmedStringBetweenBrackets = [stringBetweenBrackets stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedStringBetweenBrackets.length > 0) {
            return trimmedStringBetweenBrackets;
        }
    }

    return nil;
}

+ (NSDictionary<NSString *, NSObject *> *)parseKeyValueLine:(NSString *)trimmedLine {
    __block NSUInteger equalSignPosition = NSNotFound;
    __block NSUInteger commentStartPosition = trimmedLine.length;
    __block BOOL inQuotes = NO;

    [trimmedLine
     enumerateSubstringsInRange:NSMakeRange(1, trimmedLine.length - 1)
     options:NSStringEnumerationByComposedCharacterSequences
     usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange _, BOOL * _Nonnull stop) {
        if (NSNotFound == equalSignPosition) {
            if ([substring isEqualToString:@"="]) {
                equalSignPosition = substringRange.location;
            }
        }
        else {
            if ([substring isEqualToString:@"\""]) {
                if (NO == inQuotes) {
                    inQuotes = YES;
                }
                else {
                    inQuotes = NO;
                }
            }
            else if (NO == inQuotes && ([substring isEqualToString:@"#"] || [substring isEqualToString:@";"])) {
                commentStartPosition = substringRange.location;
                *stop = YES;
                return;
            }
        }
     }];

    if (NSNotFound == equalSignPosition) {
        return nil;
    }

    NSAssert(commentStartPosition > equalSignPosition, @"");
    NSString *key = [trimmedLine substringToIndex:equalSignPosition];
    key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (0 == key.length) {
        return nil;
    }

    NSString *value = [trimmedLine substringWithRange:NSMakeRange(equalSignPosition + 1, commentStartPosition - equalSignPosition - 1)];
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if (0 == value.length) {
        // from https://git-scm.com/docs/git-config
        //  "All the other lines (and the remainder of the line after the section header)
        //   are recognized as setting variables, in the form name = value
        //   (or just name, which is a short-hand to say that the variable is the boolean "true")"
        //
        value = @"true";
    }

    return @{ key : value };
}

+ (instancetype)configWithContentsOfString:(NSString *)string {
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSString *> *> *parsedConfig = [NSMutableDictionary new];

    __block NSString *currentSectionTitle = nil;

    [string enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (0 == trimmedLine.length) {
            return;
        }

        if ([trimmedLine hasPrefix:@"#"] || [trimmedLine hasPrefix:@";"]) {
            // skip comments
            return;
        }

        if ([trimmedLine hasPrefix:@"["]) {
            NSString *sectionTitle = [self parseSectionHeaderLine:trimmedLine];
            if (sectionTitle) {
                currentSectionTitle = sectionTitle;
                if (nil == parsedConfig[currentSectionTitle]) {
                    parsedConfig[currentSectionTitle] = [NSMutableDictionary new];
                }
            }
        }
        else if (currentSectionTitle) {
            NSDictionary *kv = [self parseKeyValueLine:trimmedLine];
            if (kv) {
                NSAssert(parsedConfig[currentSectionTitle], @"");
                [parsedConfig[currentSectionTitle] addEntriesFromDictionary:kv];
            }
        }
    }];

    return [[S7IniConfig alloc] initWithParsedConfig:parsedConfig];
}

- (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)dictionaryRepresentation {
    return self.parsedConfig;
}

@end
