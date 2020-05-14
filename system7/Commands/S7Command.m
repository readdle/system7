//
//  S7Command.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Command.h"

void printCommandAliases(Class<S7Command> commandClass) {
    NSArray<NSString *> *aliases = [commandClass aliases];
    if (aliases.count > 0) {
        puts("");

        NSString *aliasesString = [aliases componentsJoinedByString:@", "];
        fprintf(stdout, "aliases: %s\n", aliasesString.fileSystemRepresentation);
    }
}
