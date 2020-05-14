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

- (NSString *)humanReadableRevisionAndBranchState {
    NSString *branchDescription = @"";
    if (self.branch) {
        branchDescription = [NSString stringWithFormat:@" (%@)", self.branch];
    }
    return [NSString stringWithFormat:@"'%@'%@", self.revision, branchDescription];
}


#pragma mark -

- (NSString *)description {
    return self.stringRepresentation;
}

@end
