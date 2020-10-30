//
//  S7SubrepoDescription.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 09.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7SubrepoDescription.h"
#import "S7Config.h"

@implementation S7SubrepoDescription

- (instancetype)initWithConfigLine:(NSString *)trimmedLine {
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        regex = [NSRegularExpression
                 regularExpressionWithPattern:@"(.*)\\s*=\\s*\\{(.*?)\\}\\s*(#.*)?\\s*"
                 options:0
                 error:&error];
        NSCAssert(regex && nil == error, @"");
    });

    NSCAssert(regex, @"");

    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:trimmedLine
                                                              options:0
                                                                range:NSMakeRange(0, trimmedLine.length)];
    if (1 != matches.count) {
        fprintf(stderr, "error: failed to parse subrepo description (1).\n");
        return nil;
    }

    NSTextCheckingResult *match = matches.firstObject;
    if (4 != match.numberOfRanges) {
        fprintf(stderr, "error: failed to parse subrepo description (2).\n");
        return nil;
    }

    const NSRange pathRange = [match rangeAtIndex:1];
    NSString *path = [trimmedLine substringWithRange:pathRange];
    path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (0 == path.length) {
        fprintf(stderr, "error: failed to parse subrepo description. Empty path.\n");
        return nil;
    }

    const NSRange propertiesRange = [match rangeAtIndex:2];
    NSString *properties = [trimmedLine substringWithRange:propertiesRange];
    properties = [properties stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (0 == properties.length) {
        fprintf(stderr, "error: failed to parse subrepo description. Empty properties.\n");
        return nil;
    }

    NSArray<NSString *> *propertiesComponents = [properties componentsSeparatedByString:@","];
    if (propertiesComponents.count < 2 || propertiesComponents.count > 3) {
        fprintf(stderr, "error: failed to parse subrepo description. Invalid preporties value.\n");
        return nil;
    }

    NSString *url = [[propertiesComponents objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (0 == url.length) {
        fprintf(stderr, "error: failed to parse subrepo description. Invalid url.\n");
        return nil;
    }

    NSString *revision = [[propertiesComponents objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (NO == S7Config.allowNon40DigitRevisions && 40 != revision.length) {
        fprintf(stderr, "error: failed to parse subrepo description. Expected full 40-symbol revisions.\n");
        return nil;
    }

    NSString *branch = [[propertiesComponents objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (0 == branch.length) {
        fprintf(stderr, "error: failed to parse subrepo description. Invalid branch.\n");
        return nil;
    }

    return [self initWithPath:path url:url revision:revision branch:branch];
}

- (instancetype)initWithPath:(NSString *)path
                         url:(NSString *)url
                    revision:(NSString *)revision
                      branch:(NSString *)branch
{
    self = [super init];
    if (nil == self) {
        return nil;
    }

    NSParameterAssert(path.length > 0);
    NSParameterAssert(url.length > 0);
    NSParameterAssert(revision.length > 0);
    NSParameterAssert(branch.length > 0);

    _path = path;
    _url = url;
    _revision = revision;
    _branch = branch;

    return self;
}

#pragma mark - NSCopying -

- (id)copyWithZone:(NSZone *)zone {
    return [[S7SubrepoDescription alloc] initWithPath:self.path
                                                  url:self.url
                                             revision:self.revision
                                               branch:self.branch];
}

#pragma mark -

- (BOOL)isEqual:(id)object {
    if (NO == [object isKindOfClass:[S7SubrepoDescription class]]) {
        return NO;
    }

    S7SubrepoDescription *other = (S7SubrepoDescription *)object;

    return [self.path isEqualToString:other.path] &&
           [self.url isEqualToString:other.url] &&
           [self.revision isEqualToString:other.revision] &&
           [self.branch isEqualToString:other.branch];
}

- (NSUInteger)hash {
    return self.path.hash ^ self.url.hash ^ self.revision.hash ^ self.branch.hash;
}

#pragma mark -

- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"%@ = { %@, %@, %@ }", self.path, self.url, self.revision, self.branch ];
}

- (NSString *)humanReadableRevisionAndBranchState {
    return [NSString stringWithFormat:@"'%@' (%@)", self.revision, self.branch];
}


#pragma mark -

- (NSString *)description {
    return self.stringRepresentation;
}

@end
