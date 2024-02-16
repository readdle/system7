//
//  S7VersionCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7VersionCommand.h"

#import "S7HelpPager.h"

#ifndef VERSION_NUMBER
static const char VERSION_NUMBER[] = "1.0";
#endif

@implementation S7VersionCommand

+ (NSString *)commandName {
    return @"version";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 version");
    printCommandAliases(self);
    help_puts("");
    help_puts("Prints installed s7 version number.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    logInfo("s7 version %s", VERSION_NUMBER);
#ifdef COMMIT_HASH
    logInfo(" (%s)", COMMIT_HASH);
#endif
    logInfo("\n");
    return S7ExitCodeSuccess;
}

@end
