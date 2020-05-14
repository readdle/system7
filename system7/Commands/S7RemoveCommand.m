//
//  S7RemoveCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 06.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7RemoveCommand.h"

@implementation S7RemoveCommand

+ (NSString *)commandName {
    return @"remove";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"rm" ];
}

+ (void)printCommandHelp {
    puts("s7 remove PATH...");
    printCommandAliases(self);
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    if (arguments.count < 1) {
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    NSMutableArray<S7SubrepoDescription *> *newDescriptionsArray = [parsedConfig.subrepoDescriptions mutableCopy];
    NSMutableString *newGitIgnoreContents = [NSMutableString stringWithContentsOfFile:@".gitignore"
                                                                          encoding:NSUTF8StringEncoding
                                                                             error:nil];

    for (NSString *argument in arguments) {
        NSString *path = [argument stringByStandardizingPath];

        S7SubrepoDescription *subrepoDesc = parsedConfig.pathToDescriptionMap[path];
        if (nil == subrepoDesc) {
            return S7ExitCodeInvalidArgument;
        }

        [newDescriptionsArray removeObject:subrepoDesc];

        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoDesc.path]) {
            NSError *error = nil;
            if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoDesc.path error:&error]) {
                fprintf(stderr,
                        "abort: failed to remove subrepo '%s' directory\n"
                        "error: %s\n",
                        [subrepoDesc.path fileSystemRepresentation],
                        [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                return S7ExitCodeFileOperationFailed;
            }
        }

        [newGitIgnoreContents
         replaceOccurrencesOfString:[subrepoDesc.path stringByAppendingString:@"\n"]
         withString:@""
         options:0
         range:NSMakeRange(0, newGitIgnoreContents.length)];
    }

    NSError *error = nil;
    if (NO == [newGitIgnoreContents writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr,
                "abort: failed to save updated .gitignore\n"
                "error: %s\n",
                [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    S7Config *newConfig = [[S7Config alloc] initWithSubrepoDescriptions:newDescriptionsArray];
    const int configSaveResult = [newConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    if (NO == [newConfig.sha1 writeToFile:S7HashFileName atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr,
                "failed to save %s to disk. Error: %s\n",
                S7HashFileName.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    return 0;
}

@end
