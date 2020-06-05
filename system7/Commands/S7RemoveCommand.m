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
    puts("s7 remove [OPTION] PATH...");
    printCommandAliases(self);
    puts("");
    puts("options:");
    puts("");
    puts(" -f --force  remove subrepo directory even if it contain uncommited/not pushed");
    puts("             local changes");
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

    BOOL force = NO;
    BOOL anySubrepoHadLocalChanges = NO;
    for (NSString *argument in arguments) {
        if ([argument isEqualToString:@"-f"] || [argument isEqualToString:@"--force"]) {
            force = YES;
            continue;
        }

        NSString *path = [argument stringByStandardizingPath];

        S7SubrepoDescription *subrepoDesc = parsedConfig.pathToDescriptionMap[path];
        if (nil == subrepoDesc) {
            return S7ExitCodeInvalidArgument;
        }

        [newDescriptionsArray removeObject:subrepoDesc];

        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            BOOL canRemoveSubrepoDirectory = YES;
            GitRepository *subrepoGit = [GitRepository repoAtPath:path];
            if (subrepoGit && NO == force) {
                const BOOL hasUnpushedCommits = [subrepoGit hasUnpushedCommits];
                const BOOL hasUncommitedChanges = [subrepoGit hasUncommitedChanges];
                if (hasUncommitedChanges || hasUnpushedCommits) {
                    anySubrepoHadLocalChanges = YES;

                    const char *reason = NULL;
                    if (hasUncommitedChanges && hasUnpushedCommits) {
                        reason = "uncommitted and not pushed changes";
                    }
                    else if (hasUncommitedChanges) {
                        reason = "uncommitted changes";
                    }
                    else {
                        reason = "not pushed changes";
                    }

                    NSAssert(reason, @"");

                    fprintf(stderr,
                            "⚠️  not removing repo '%s' directory because it has %s.\n",
                            path.fileSystemRepresentation,
                            reason);

                    canRemoveSubrepoDirectory = NO;
                }
            }

            if (canRemoveSubrepoDirectory) {
                NSError *error = nil;
                if (NO == [NSFileManager.defaultManager removeItemAtPath:path error:&error]) {
                    fprintf(stderr,
                            "abort: failed to remove subrepo '%s' directory\n"
                            "error: %s\n",
                            [path fileSystemRepresentation],
                            [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                    return S7ExitCodeFileOperationFailed;
                }
            }
        }

        [newGitIgnoreContents
         replaceOccurrencesOfString:[path stringByAppendingString:@"\n"]
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

    if (0 != [newConfig saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);

        return S7ExitCodeFileOperationFailed;
    }

    if (anySubrepoHadLocalChanges) {
        return S7ExitCodeSubrepoHasLocalChanges;
    }

    return S7ExitCodeSuccess;
}

@end
