//
//  S7StatusCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7StatusCommand.h"

@implementation S7StatusCommand

+ (NSString *)commandName {
    return @"status";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    puts("s7 status");
    printCommandAliases(self);
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    const BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (NO == configFileExists || isDirectory) {
        return S7ExitCodeNotS7Repo;
    }

    // compare last committed config to the commit from working directory
    // if different – tell what is about to be committed

    // for each subrepo from config:
    //   compared saved state to the actual state

//    NSAssert(NO, @"not implemented");

    return 0;
}

@end


//parent: 0:894e9a1d02c7 tip
// init
//branch: default
//commit: 1 added, 1 subrepos
//update: (current)


//parent: 1:fa1d078b91a9 tip
// add ReaddleLib subrepo
//branch: expert
//commit: 1 subrepos (new branch)
//update: (current)
