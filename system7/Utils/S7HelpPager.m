//
//  S7HelpPager.m
//  system7
//
//  Created by Nik on 24.07.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7HelpPager.h"

static FILE *_s7helpFile = NULL;

FILE *s7help(void) {
    NSCParameterAssert([NSThread isMainThread]);
    return _s7helpFile ?: stdout;
}

int withHelpPaginationDo(int (^block)(void)) {
    NSCParameterAssert([NSThread isMainThread]);
    NSCParameterAssert(_s7helpFile == NULL);
    
    _s7helpFile = popen("less -r", "w");
    
    const int code = block();
    
    if (_s7helpFile) {
        pclose(_s7helpFile);
        _s7helpFile = NULL;
    }
    
    return code;
}

void help_puts(const char * __restrict format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(s7help(), format, args);
    fputs("\n", s7help());
    va_end(args);
}
