//
//  S7VersionCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.01.2021.
//  Copyright © 2021 Readdle. All rights reserved.
//

#import "S7VersionCommand.h"

#import "HelpPager.h"

static const char VERSION_NUMBER[] = "1.0";
static const char VERSION_DATE[] = "2021-02-04";

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
    fprintf(stdout, "s7 version %s (%s)\n", VERSION_NUMBER, VERSION_DATE);
    return S7ExitCodeSuccess;
}

@end
