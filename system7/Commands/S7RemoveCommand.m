//
//  S7RemoveCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 06.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7RemoveCommand.h"
#import "HelpPager.h"

@implementation S7RemoveCommand

+ (NSString *)commandName {
    return @"remove";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"rm" ];
}

+ (void)printCommandHelp {
    help_puts("s7 remove [OPTION] PATH...");
    printCommandAliases(self);
    help_puts("");
    help_puts("Remove the specified subrepo(s)");
    help_puts("");
    help_puts("options:");
    help_puts("");
    help_puts(" -f --force  remove subrepo directory even if it contains uncommitted/not pushed");
    help_puts("             local changes");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    if (arguments.count < 1) {
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    NSMutableArray<S7SubrepoDescription *> *newDescriptionsArray = [parsedConfig.subrepoDescriptions mutableCopy];
    NSMutableSet<NSString *> *pathsToRemoveFromGitignore = [NSMutableSet new];

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

                    logError("⚠️  not removing repo '%s' directory because it has %s.\n",
                             path.fileSystemRepresentation,
                             reason);

                    canRemoveSubrepoDirectory = NO;
                }
            }

            if (canRemoveSubrepoDirectory) {
                NSError *error = nil;
                if (NO == [NSFileManager.defaultManager removeItemAtPath:path error:&error]) {
                    logError("failed to remove subrepo '%s' directory\n"
                             "error: %s\n",
                            [path fileSystemRepresentation],
                            [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                    return S7ExitCodeFileOperationFailed;
                }
            }
        }

        [pathsToRemoveFromGitignore addObject:path];
    }

    S7Config *newConfig = [[S7Config alloc] initWithSubrepoDescriptions:newDescriptionsArray];

    SAVE_UPDATED_CONFIG_TO_MAIN_AND_CONTROL_FILE(newConfig);

    const int gitignoreUpdateResult = removeLinesFromGitIgnore(pathsToRemoveFromGitignore);
    if (S7ExitCodeSuccess != gitignoreUpdateResult) {
        return gitignoreUpdateResult;
    }

    if (anySubrepoHadLocalChanges) {
        return S7ExitCodeSubrepoHasLocalChanges;
    }

    return S7ExitCodeSuccess;
}

@end
