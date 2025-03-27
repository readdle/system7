//
//  S7DeinitCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 01.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7DeinitCommand.h"

#import "S7HelpPager.h"

// I considered if deinit should remove all actual subrepo directories
// and decided not to do that. I don't know what will the user do next:
//  - maybe they will migrate to another subrepos system they like best
//  - maybe they even called `deinit` by mistake, then restoring
//    .s7substate and calling `init` would fix the mistake more or less
//    easily (and quickly and without data loss if anything has not been
//    committed/pushed in any of subrepos).
//
// Removing subrepo dirs is fairly easy with `git clean -d`.
//
// Not removing subrepos also makes deinit solve one single task. If user
// wants to remove subrepos, there's `s7 rm` for that – it will also run
// all necessary security checks (uncommitted changes, unpushed changes, ...).
//
// This decision may prove wrong. I don't have real use cases now.
// The first reason I implement `deinit` now, is to allow people __try__
// System 7. `deinit` is a must if you just want to play with the new tool
// and see if it fits your needs (although Andrew suggested making
// deinit a paid feature :joy:).
//

@implementation S7DeinitCommand

+ (NSString *)commandName {
    return @"deinit";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 deinit");
    printCommandAliases(self);
    help_puts("");
    help_puts("    Removes all traces of s7 from the repo.");
    help_puts("    Deletes all .s7* files.");
    help_puts("    Scrapes s7 calls out from git hooks, and removes a hook altogether");
    help_puts("    if s7 was the only citizen of that hook.");
    help_puts("    Removes s7-related stuff from .gitignore, .git/config and .gitattributes.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    // let user remove traces of s7 even if repo is 'corrupted' (for example as the result of
    // attempts to get rid of s7 by hand)
    //    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    int result = S7ExitCodeSuccess;

    NSMutableSet<NSString *> *linesToRemoveFromGitIgnore = [NSMutableSet new];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    for (S7SubrepoDescription *subrepoDesc in parsedConfig.subrepoDescriptions) {
        [linesToRemoveFromGitIgnore addObject:subrepoDesc.path];
    }

    for (NSString *fileName in @[ S7BakFileName, S7BootstrapFileName, S7ControlFileName, S7ConfigFileName ]) {
        if (NO == [NSFileManager.defaultManager fileExistsAtPath:fileName]) {
            continue;
        }
        
        NSError *error = nil;
        if (NO == [NSFileManager.defaultManager removeItemAtPath:fileName error:&error]) {
            logError("Failed to remove file %s. Error: %s\n",
                     fileName.fileSystemRepresentation,
                     [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

            result = S7ExitCodeFileOperationFailed;
        }
    }

    [linesToRemoveFromGitIgnore addObjectsFromArray:@[
        S7BakFileName,
        S7ControlFileName,
    ]];

    const int gitignoreUpdateResult = removeLinesFromGitIgnore(linesToRemoveFromGitIgnore);
    if (S7ExitCodeSuccess != gitignoreUpdateResult) {
        result = gitignoreUpdateResult;
    }

    const int gitattributesUpdateResult =
    removeFilesFromGitattributes([NSSet setWithArray:@[
                                    S7ConfigFileName,
                                    S7BootstrapFileName
                                ]]);
    if (S7ExitCodeSuccess != gitattributesUpdateResult) {
        result = gitattributesUpdateResult;
    }

    if (0 != [repo removeLocalConfigSection:@"merge.s7"]) {
        result = S7ExitCodeGitOperationFailed;
    }

    NSArray<NSString *> *hookFileNames = @[
        @"post-checkout",
        @"post-commit",
        @"post-merge",
        @"prepare-commit-msg",
        @"pre-push",
    ];

    for (NSString *hookName in hookFileNames) {
        const int hookUpdateResult = [self removeS7FromHook:hookName];
        if (S7ExitCodeSuccess != hookUpdateResult) {
            result = hookUpdateResult;
        }
    }

    return result;
}

- (int)removeS7FromHook:(NSString *)hookFileName {
    NSString *hookFilePath = [@".git/hooks" stringByAppendingPathComponent:hookFileName];
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:hookFilePath]) {
        return S7ExitCodeSuccess;
    }

    NSError *error = nil;
    NSString *existingHookContents = [[NSString alloc] initWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];
    if (error) {
        logError("failed to read contents of %s. Error: %s\n",
                 [hookFileName fileSystemRepresentation],
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    if (NO == [existingHookContents hasPrefix:@"#!/bin/sh\n"]) {
        // s7 just won't install to such file
        return S7ExitCodeSuccess;
    }

    NSRegularExpression *s7HookCallLineRegex = [NSRegularExpression regularExpressionWithPattern:@".+s7 [a-z-]+-hook" options:0 error:&error];
    if (nil == s7HookCallLineRegex || error) {
        logError("fatal: failed to compile s7-hook line regex. Error: %s\n",
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInternalError;
    }

    __block NSInteger numberOfLeavingNonEmptyLines = -1; // start with -1 to ignore shebang
    NSMutableArray *resultingHookLines = [NSMutableArray new];
    [existingHookContents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if ([s7HookCallLineRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)]) {
            // skip s7-hook call line
            return;
        }

        [resultingHookLines addObject:line];

        if ([line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length > 0) {
            ++numberOfLeavingNonEmptyLines;
        }
    }];

    if (0 == numberOfLeavingNonEmptyLines) {
        if (NO == [NSFileManager.defaultManager removeItemAtPath:hookFilePath error:&error]) {
            logError("failed to remove %s. Error: %s\n",
                     [hookFileName fileSystemRepresentation],
                     [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeFileOperationFailed;
        }
    }
    else {
        NSString *resultingHookContents = [resultingHookLines componentsJoinedByString:@"\n"];
        if (NO == [resultingHookContents writeToFile:hookFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            logError("failed to update %s contents. Error: %s\n",
                     [hookFileName fileSystemRepresentation],
                     [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeFileOperationFailed;
        }
    }

    return S7ExitCodeSuccess;
}

@end
