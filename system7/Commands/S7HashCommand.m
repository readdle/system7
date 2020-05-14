//
//  S7HashCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 12.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7HashCommand.h"

@implementation S7HashCommand

+ (NSString *)commandName {
    return @"hash";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    puts("s7 hash");
    printCommandAliases(self);
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

    fprintf(stdout, "%s\n", [self calculateHash].fileSystemRepresentation);

    return 0;
}

- (NSString *)calculateHash {
    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    NSAssert(parsedConfig, @"");
    return parsedConfig.sha1;
}

@end
