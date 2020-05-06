//
//  S7InitCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7InitCommand.h"

@implementation S7InitCommand

- (void)printCommandHelp {
    puts("s7 init");
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    const BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (configFileExists) {
        fprintf(stderr, "abort: s7 already configured\n");
        return 1;
    }

    if (NO == [[NSFileManager defaultManager] createFileAtPath:S7ConfigFileName contents:nil attributes:nil]) {
        fprintf(stderr, "error: failed to create config file\n");
        return S7ExitCodeFileOperationFailed;
    }

    return 0;
}

@end
