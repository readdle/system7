//
//  S7Logging.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.09.2023.
//  Copyright © 2023 Readdle. All rights reserved.
//

#include <stdio.h>

#import "S7Logging.h"

void withTTYLockDo(void(NS_NOESCAPE ^block)(void)) {
    // The lock is necessary as we parallelize
    // some operations. Without locked access to the console, we will get a soup of different operation's output.
    //
    // This doesn't prevent logical soup of course – that's clients responsibility to
    // control how they structure multithreaded logging, so that the end user can understand anything

    static NSLock *ttyLock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ttyLock = [NSLock new];
    });

    [ttyLock lock];

        block();

    [ttyLock unlock];
}

BOOL canUseColorForOutputToFile(int fileno) {
    const char *const term = getenv("TERM");
    return isatty(fileno) && term != NULL && strcasecmp(term, "dumb") != 0;
}

void logInfo(const char * __restrict format, ...) {
    va_list va_args;
    char message[256];

    va_start(va_args, format);
    vsprintf(message, format, va_args);
    va_end(va_args);

    char *messagePointer = message;
    withTTYLockDo(^{
        fprintf(stdout, "%s", messagePointer);
    });
}

void logError(const char * __restrict format, ...) {
    va_list va_args;
    char message[256];

    va_start(va_args, format);
    vsprintf(message, format, va_args);
    va_end(va_args);

    char *messagePointer = message;
    withTTYLockDo(^{
        if (canUseColorForOutputToFile(fileno(stderr))) {
            fprintf(stderr,
                    "\033[31m"
                    "%s"
                    "\033[0m",
                    messagePointer);
        }
        else {
            fprintf(stderr, "ERROR: %s", messagePointer);
        }
    });
}
