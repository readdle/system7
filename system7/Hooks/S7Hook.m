//
//  S7Hook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Hook.h"

NSString *hookFileContentsForHookNamed(NSString * hookName) {
    return [NSString
            stringWithFormat:
            @"#!/bin/sh\n"
             "/usr/local/bin/s7 %@-hook \"$@\" <&0",
            hookName];
}
