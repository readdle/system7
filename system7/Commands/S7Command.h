//
//  S7Command.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef S7Command_h
#define S7Command_h

#import <Foundation/Foundation.h>

@protocol S7Command <NSObject>

+ (NSString *)commandName;
+ (NSArray<NSString *> *)aliases;

+ (void)printCommandHelp;

- (int)runWithArguments:(NSArray<NSString *> *)arguments;

@end

void printCommandAliases(Class<S7Command> commandClass);

#endif /* S7Command_h */
