//
//  S7Utils.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Utils.h"
#import "S7BootstrapCommand.h"

int executeInDirectory(NSString *directory, int (NS_NOESCAPE ^block)(void)) {
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:directory]) {
        logError("failed to change current directory to %s.", directory.fileSystemRepresentation);
        return S7ExitCodeFileOperationFailed;
    }

    int operationReturnValue = 128;
    @try {
        operationReturnValue = block();
        return operationReturnValue;
    }
    @finally {
        if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:cwd]) {
            logError("failed to return current directory to %s.", cwd.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }
}

int getConfig(GitRepository *repo, NSString *revision, S7Config * _Nullable __autoreleasing * _Nonnull ppConfig) {
    int showExitStatus = 0;
    NSString *configContents = [repo showFile:S7ConfigFileName atRevision:revision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed or we are back to revision where there was no s7 yet
            // this is a valid situation, so we just return an empty config
            configContents = @"";
        }
        else {
            logError("failed to retrieve .s7substate config at revision %s.\n"
                     "Git exit status: %d\n",
                     [revision cStringUsingEncoding:NSUTF8StringEncoding],
                     showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    *ppConfig = [[S7Config alloc] initWithContentsString:configContents];

    return 0;
}

int addLineToGitIgnore(GitRepository *repo, NSString *lineToAppend) {
    NSString *gitignoreAbsoluteFilePath = [repo.absolutePath stringByAppendingPathComponent:@".gitignore"];

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:gitignoreAbsoluteFilePath isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:gitignoreAbsoluteFilePath
                   contents:nil
                   attributes:nil])
        {
            logError("failed to create .gitignore file\n");
            return 1;
        }
    }

    if (isDirectory) {
        logError(".gitignore is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:gitignoreAbsoluteFilePath encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        logError("failed to read contents of .gitignore file. Error: %s\n",
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    NSArray<NSString *> *existingGitIgnoreLines = [newContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if ([existingGitIgnoreLines containsObject:lineToAppend]) {
        // do not add twice
        return 0;
    }

    if (newContent.length > 0 && NO == [newContent hasSuffix:@"\n"]) {
        [newContent appendString:@"\n"];
    }

    if (NO == [lineToAppend hasSuffix:@"\n"]) {
        lineToAppend = [lineToAppend stringByAppendingString:@"\n"];
    }
    [newContent appendString:lineToAppend];

    if (NO == [newContent writeToFile:gitignoreAbsoluteFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        logError("failed to write contents of .gitignore file. Error: %s\n",
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

int removeLinesFromGitIgnore(NSSet<NSString *> *linesToRemove) {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".gitignore" isDirectory:&isDirectory]) {
        return S7ExitCodeSuccess;
    }

    if (isDirectory) {
        return S7ExitCodeFileOperationFailed;
    }

    NSError *error = nil;
    NSString *gitignoreContents = [NSString stringWithContentsOfFile:@".gitignore"
                                                            encoding:NSUTF8StringEncoding
                                                               error:&error];
    if (nil == gitignoreContents || error) {
        logError("failed to remove lines from .gitignore. File read failed. Error: %s\n",
                 [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    NSMutableString *newContents = [[NSMutableString alloc] initWithCapacity:gitignoreContents.length];
    [gitignoreContents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (NO == [linesToRemove containsObject:line]) {
            [newContents appendString:line];
            [newContents appendString:@"\n"];
        }
    }];

    if (NO == [newContents writeToFile:@".gitignore" atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        logError("failed to save updated .gitignore\n"
                 "error: %s\n",
                 [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    return S7ExitCodeSuccess;
}

int addLineToGitAttributes(GitRepository *repo, NSString *lineToAppend) {
    NSString *gitattributesFilePath = [repo.absolutePath stringByAppendingPathComponent:@".gitattributes"];

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:gitattributesFilePath isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:gitattributesFilePath
                   contents:nil
                   attributes:nil])
        {
            logError("failed to create .gitattributes file\n");
            return 1;
        }
    }

    if (isDirectory) {
        logError(".gitattributes is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:gitattributesFilePath encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        logError("failed to read contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    NSArray<NSString *> *existingGitattributeLines = [newContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if ([existingGitattributeLines containsObject:lineToAppend]) {
        // do not add twice
        return 0;
    }

    if (newContent.length > 0 && NO == [newContent hasSuffix:@"\n"]) {
        [newContent appendString:@"\n"];
    }

    if (NO == [lineToAppend hasSuffix:@"\n"]) {
        lineToAppend = [lineToAppend stringByAppendingString:@"\n"];
    }
    [newContent appendString:lineToAppend];

    if (NO == [newContent writeToFile:gitattributesFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        logError("failed to write contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

int removeFilesFromGitattributes(NSSet<NSString *> *filesToRemove) {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".gitattributes" isDirectory:&isDirectory]) {
        return S7ExitCodeSuccess;
    }

    if (isDirectory) {
        return S7ExitCodeFileOperationFailed;
    }

    NSMutableArray<NSString *> *linesToRemovePrefixes = [[NSMutableArray alloc] initWithCapacity:filesToRemove.count];
    for (NSString *fileToRemove in filesToRemove) {
        [linesToRemovePrefixes addObject:[NSString stringWithFormat:@"%@ ", fileToRemove]];
    }

    NSError *error = nil;
    NSString *existingContents = [NSString stringWithContentsOfFile:@".gitattributes"
                                                           encoding:NSUTF8StringEncoding
                                                              error:&error];
    if (nil == existingContents || error) {
        logError("failed to remove files from .gitattributes. File read failed. Error: %s\n",
                [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    NSMutableString *newContents = [[NSMutableString alloc] initWithCapacity:existingContents.length];
    [existingContents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        BOOL removeLine = NO;
        for (NSString *lineToRemovePrefix in linesToRemovePrefixes) {
            if ([line hasPrefix:lineToRemovePrefix]) {
                removeLine = YES;
                break;
            }
        }

        if (NO == removeLine) {
            [newContents appendString:line];
            [newContents appendString:@"\n"];
        }
    }];

    if (NO == [newContents writeToFile:@".gitattributes" atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        logError("failed to save updated .gitattributes\n"
                 "error: %s\n",
                 [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
    }

    return S7ExitCodeSuccess;
}

BOOL isCurrentDirectoryS7RepoRoot(void) {
    BOOL isDirectory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory] && (NO == isDirectory);
}

BOOL isS7Repo(GitRepository *repo) {
    NSString *configFilePath = [repo.absolutePath stringByAppendingPathComponent:S7ConfigFileName];
    BOOL isDirectory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:configFilePath isDirectory:&isDirectory] && (NO == isDirectory);
}

int s7RepoPreconditionCheck(void) {
    if (NO == isCurrentDirectoryS7RepoRoot())
    {
        logError("abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    const BOOL controlFileExists = [NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName];
    if (NO == controlFileExists) {
        logError("abort: s7 repo is corrupted.\n"
                 "(most likely 's7 init' failed to install git hooks)\n");
        return S7ExitCodeNotS7Repo;
    }

    return S7ExitCodeSuccess;
}

int saveUpdatedConfigToMainAndControlFile(S7Config *updatedConfig) {
    int configSaveResult = [updatedConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    configSaveResult = [updatedConfig saveToFileAtPath:S7ControlFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    return S7ExitCodeSuccess;
}

NSString *getGlobalGitConfigValue(NSString *key) {
    NSCParameterAssert(key != nil);
    NSString *const launch = [NSString stringWithFormat:@"git config --global --get %@", key];
    FILE *const proc = popen([launch cStringUsingEncoding:NSUTF8StringEncoding], "r");
    if (proc == NULL) {
        return nil;
    }
    
    NSMutableString *const value = [NSMutableString new];
    char buffer[16];
    while (fgets(buffer, sizeof(buffer) / sizeof(char), proc)) {
        [value appendFormat:@"%s", buffer];
    }
    
    if (pclose(proc) != 0) {
        return nil;
    }
    
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

int installHook(GitRepository *repo, NSString *hookName, NSString *commandLine, BOOL forceOverwrite, BOOL installFakeHooks) {
    if (installFakeHooks) {
        return S7ExitCodeSuccess;
    }
    
    NSString *const hooksDirAbsolutePath = [repo.absolutePath stringByAppendingPathComponent:@".git/hooks"];
    NSString *hookFilePath = [hooksDirAbsolutePath stringByAppendingPathComponent:hookName];

    NSString *contentsToWrite = [NSString stringWithFormat:@"#!/bin/sh\n\n%@\n", commandLine];

    if (NO == forceOverwrite && [NSFileManager.defaultManager fileExistsAtPath:hookFilePath]) {
        NSString *existingContents = [[NSString alloc] initWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];
        if (NO == [existingContents hasPrefix:@"#!/bin/sh\n"]) {
            logError("hook %s already exists and it's not a shell script, so we cannot merge s7 call into it\n",
                     hookFilePath.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }

        if ([existingContents containsString:commandLine]) {
            return S7ExitCodeSuccess;
        }

        NSString *oldStyleS7HookContents = [NSString
                                            stringWithFormat:
                                            @"#!/bin/sh\n"
                                            "/usr/local/bin/s7 %@-hook \"$@\" <&0",
                                            hookName];
        if (NO == [existingContents isEqualToString:oldStyleS7HookContents]) {
            NSString *existingHookBody = [existingContents stringByReplacingOccurrencesOfString:@"#!/bin/sh\n"
                                                                                     withString:@""];

            // 'uninstall' bootstrap command
            existingHookBody = [existingHookBody stringByReplacingOccurrencesOfString:[[S7BootstrapCommand class] bootstrapCommandLine]
                                                                           withString:@""];

            NSString *mergedHookContents = [NSString stringWithFormat:
                                            @"#!/bin/sh\n"
                                            "\n"
                                            "%@\n"
                                            "\n"
                                            "%@",
                                            commandLine,
                                            existingHookBody];

            contentsToWrite = mergedHookContents;
        }
    }
    
    NSError *error = nil;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:hooksDirAbsolutePath]) {
        if (NO == [NSFileManager.defaultManager
                   createDirectoryAtPath:hooksDirAbsolutePath
                   withIntermediateDirectories:NO
                   attributes:nil
                   error:&error])
        {
            logError("'.git/hooks' directory doesn't exist. Failed to create it. Error: %s\n",
                     [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

            return S7ExitCodeFileOperationFailed;
        }
    }

    if (NO == [contentsToWrite writeToFile:hookFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        logError("failed to save %s to disk. Error: %s\n",
                 hookFilePath.fileSystemRepresentation,
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    NSUInteger posixPermissions = [NSFileManager.defaultManager attributesOfItemAtPath:hookFilePath error:&error].filePosixPermissions;
    if (error) {
        logError("failed to read %s posix permissions. Error: %s\n",
                 hookFilePath.fileSystemRepresentation,
                 [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    posixPermissions |= 0111;

    if (NO == [NSFileManager.defaultManager setAttributes:@{ NSFilePosixPermissions : @(posixPermissions) }
                                             ofItemAtPath:hookFilePath
                                                    error:&error])
    {
        logError("failed to make hook %s executable. Error: %s\n",
                 hookFilePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    return S7ExitCodeSuccess;
}

BOOL S7ArgumentMatchesFlag(NSString *argument, NSString *longFlag, NSString *shortFlag) {
    argument = [argument stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-"]];

    return [argument isEqualToString:shortFlag] || [argument isEqualToString:longFlag];
}
