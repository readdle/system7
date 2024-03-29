//
//  S7ResetCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 02.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7ResetCommand.h"

#import "S7Utils.h"
#import "S7PostCheckoutHook.h"
#import "S7HelpPager.h"

@implementation S7ResetCommand

+ (NSString *)commandName {
    return @"reset";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 reset [-X|--exclude PATH] --all|PATH...");
    printCommandAliases(self);
    help_puts("");
    help_puts("reset subrepos to the state saved in the last committed %s", S7ConfigFileName.fileSystemRepresentation);
    help_puts("");
    help_puts("   ⚠️  CAUTION: reset is a shotgun – use carefully.");
    help_puts("");
    help_puts("   - It drops any uncommitted local changes in a reset subrepo.");
    help_puts("   - It doesn't keep any backups.");
    help_puts("   - It can make changes committed in subrepos 'detached', and the only way");
    help_puts("     to get them back would be via search in ref-log.");
    help_puts("");
    help_puts("   With this in mind --all or PATH... options were made required,");
    help_puts("   so that you could think twice before running this command.");
    help_puts("");
    help_puts("options ([+] can be repeated):");
    help_puts("");
    help_puts(" --all             reset all subrepo");
    help_puts(" -X --exclude [+]  do not reset given subrepos");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    NSString *currentRevision = nil;
    if (0 != [repo getCurrentRevision:&currentRevision]) {
        return S7ExitCodeGitOperationFailed;
    }

    S7Config *lastCommittedConfig = nil;
    int showExitStatus = getConfig(repo, currentRevision, &lastCommittedConfig);
    if (0 != showExitStatus) {
        return showExitStatus;
    }

    BOOL resetAll = NO;
    NSMutableSet<NSString *> *excludePaths = [NSMutableSet new];
    NSMutableSet<NSString *> *subreposToResetPaths = [NSMutableSet new];
    if (arguments.count > 0) {
        for (NSUInteger i = 0; i < arguments.count; ++i) {
            NSString *argument = arguments[i];

            if ([argument hasPrefix:@"-"]) {
                if ([argument isEqualToString:@"--all"]) {
                    resetAll = YES;
                    continue;
                }
                else if ([argument isEqualToString:@"-X"] || [argument isEqualToString:@"--exclude"]) {
                    if (i + 1 < arguments.count) {
                        NSString *path = [arguments[i + 1] stringByStandardizingPath];
                        
                        ++i;

                        if (NO == [lastCommittedConfig.subrepoPathsSet containsObject:path]) {
                            logError("there's no registered subrepo at path '%s'\n"
                                     "maybe you wanted to use 'add'?\n",
                                     [argument fileSystemRepresentation]);
                            return S7ExitCodeInvalidParameterValue;
                        }

                        [excludePaths addObject:path];
                    }
                    else {
                        return S7ExitCodeInvalidParameterValue;
                    }

                    continue;
                }
                else {
                    logError("option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                    [[self class] printCommandHelp];
                    return S7ExitCodeUnrecognizedOption;
                }
            }
            else {
                NSString *path = [argument stringByStandardizingPath];

                if (NO == [lastCommittedConfig.subrepoPathsSet containsObject:path]) {
                    logError("there's no registered subrepo at path '%s'\n"
                             "maybe you wanted to use 'add'?\n",
                             [argument fileSystemRepresentation]);
                    return S7ExitCodeInvalidArgument;
                }

                [subreposToResetPaths addObject:path];
            }
        }
    }

    if (resetAll && subreposToResetPaths.count > 0) {
        logError("please specify EITHER '--all' OR PATH...\n\n");
        [[self class] printCommandHelp];
        return S7ExitCodeInvalidArgument;
    }
    else if (resetAll) {
        subreposToResetPaths = [lastCommittedConfig.subrepoPathsSet mutableCopy];

        if (0 == lastCommittedConfig.subrepoDescriptions.count) {
            return S7ExitCodeSuccess;
        }
    }

    [subreposToResetPaths minusSet:excludePaths];

    if (0 == subreposToResetPaths.count) {
        logError("please specify subrepos to reset or '--all'. Read why below.\n\n");
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    NSArray<S7SubrepoDescription *> *subreposToReset = [lastCommittedConfig.subrepoDescriptions filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(S7SubrepoDescription * evaluatedObject, NSDictionary<NSString *,id> * _Nullable _) {
        return [subreposToResetPaths containsObject:evaluatedObject.path];
    }]];

    S7Config *subConfigToResetTo = [[S7Config alloc] initWithSubrepoDescriptions:subreposToReset];

    const int checkoutExitStatus = [S7PostCheckoutHook
                                    checkoutSubreposForRepo:repo
                                    fromConfig:[S7Config emptyConfig]
                                    toConfig:subConfigToResetTo
                                    clean:YES];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    S7Config *workingConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    NSMutableArray<S7SubrepoDescription *> *resultingSubrepoDescriptions =
        [[NSMutableArray alloc] initWithCapacity:workingConfig.subrepoDescriptions.count];
    for (S7SubrepoDescription *subrepoDesc in workingConfig.subrepoDescriptions) {
        // iterate over descriptions (not paths) to keep the order
        NSString *subrepoPath = subrepoDesc.path;

        S7SubrepoDescription *descriptionToSave = subConfigToResetTo.pathToDescriptionMap[subrepoPath];
        if (nil == descriptionToSave) {
            descriptionToSave = subrepoDesc;
        }

        [resultingSubrepoDescriptions addObject:descriptionToSave];
    }

    S7Config *resultingConfig = [[S7Config alloc] initWithSubrepoDescriptions:resultingSubrepoDescriptions];

    SAVE_UPDATED_CONFIG_TO_MAIN_AND_CONTROL_FILE(resultingConfig);

    return S7ExitCodeSuccess;
}

@end
