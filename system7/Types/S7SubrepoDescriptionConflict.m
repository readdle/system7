//
//  S7SubrepoDescriptionConflict.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 09.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7SubrepoDescriptionConflict.h"

@implementation S7SubrepoDescriptionConflict

- (instancetype)initWithOurVersion:(nullable S7SubrepoDescription *)ourVersion theirVersion:(nullable S7SubrepoDescription *)theirVersion {
    NSAssert(ourVersion || theirVersion, @"at least one must be non-nil");
    NSString *path = ourVersion ? ourVersion.path : theirVersion.path;
    if (nil == path) {
        NSParameterAssert(path);
        return nil;
    }

    NSString *url = ourVersion ? ourVersion.url : theirVersion.url;
    if (nil == url) {
        NSParameterAssert(url);
        return nil;
    }

    self = [super initWithPath:path url:url revision:@"CONFLICT" branch:@"CONFLICT"];
    if (nil == self) {
        return nil;
    }

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

- (NSString *)stringRepresentation {
    return [NSString
            stringWithFormat:
            @"<<<<<<< yours\n"
             "%@\n"
             "=======\n"
             "%@\n"
             ">>>>>>> theirs",
            self.ourVersion,
            self.theirVersion ];
}


@end
