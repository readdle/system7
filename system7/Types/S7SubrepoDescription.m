//
//  S7SubrepoDescription.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 09.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7SubrepoDescription.h"


@implementation S7SubrepoDescription

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
