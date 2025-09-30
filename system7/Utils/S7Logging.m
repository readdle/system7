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

char *formatMessage(const char * __restrict format, va_list *args) {
    va_list args_copy;
    va_copy(args_copy, *args);
    const int writtenSize = vsnprintf(nil, 0, format, args_copy);
    va_end(args_copy);

    const size_t bufferSize = writtenSize + 1;
    char *const buffer = malloc(bufferSize);
    vsnprintf(buffer, bufferSize, format, *args);

    return buffer;
}

void logInfo(const char * __restrict format, ...) {
    va_list args;
    va_start(args, format);
    char *const message = formatMessage(format, &args);
    va_end(args);

    withTTYLockDo(^{
        fprintf(stdout, "%s", message);
    });

    free(message);
}

void logError(const char * __restrict format, ...) {
    va_list args;
    va_start(args, format);
    char *const message = formatMessage(format, &args);
    va_end(args);

    withTTYLockDo(^{
        if (canUseColorForOutputToFile(fileno(stderr))) {
            fprintf(stderr,
                    "\033[31m"
                    "%s"
                    "\033[0m",
                    message);
        }
        else {
            fprintf(stderr, "ERROR: %s", message);
        }
    });

    free(message);
}
