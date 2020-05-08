//
//  Command.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef Command_h
#define Command_h

#import <Foundation/Foundation.h>

@protocol S7Command <NSObject>

- (int)runWithArguments:(NSArray<NSString *> *)arguments;

- (void)printCommandHelp;

@end

#endif /* Command_h */
