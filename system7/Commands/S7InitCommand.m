//
//  S7InitCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7InitCommand.h"

#import "Utils.h"
#import "S7PrePushHook.h"

@implementation S7InitCommand

+ (NSString *)commandName {
    return @"init";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    puts("s7 init");
    printCommandAliases(self);
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    const BOOL configFileExists = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (configFileExists) {
        fprintf(stderr, "abort: s7 already configured\n");
        return 1;
    }

    if (NO == [[NSFileManager defaultManager] createFileAtPath:S7ConfigFileName contents:nil attributes:nil]) {
        fprintf(stderr, "error: failed to create %s file\n", S7ConfigFileName.fileSystemRepresentation);
        return S7ExitCodeFileOperationFailed;
    }

    NSError *error = nil;
    if (NO == [[S7Config emptyConfig].sha1 writeToFile:S7HashFileName atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr,
                "failed to save %s to disk. Error: %s\n",
                S7HashFileName.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    const int hookInstallationExitCode = [self installHookFile:S7GitPrePushHookFilePath withContents:S7GitPrePushHookFileContents];
    if (0 != hookInstallationExitCode) {
        return hookInstallationExitCode;
    }

    return addLineToGitIgnore(S7HashFileName);
}

- (int)installHookFile:(NSString *)filePath withContents:(NSString *)contents {
    if ([NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        fprintf(stderr,
                "hook already installed at path %s\n",
                filePath.fileSystemRepresentation);
        return S7ExitCodeFileOperationFailed;
    }

    if (self.installFakeHooks) {
        contents = @"";
    }

    NSError *error = nil;
    if (NO == [contents writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr,
                "failed to save %s to disk. Error: %s\n",
                filePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    NSUInteger posixPermissions = [NSFileManager.defaultManager attributesOfItemAtPath:filePath error:&error].filePosixPermissions;
    if (error) {
        fprintf(stderr,
                "failed to read %s posix permissions. Error: %s\n",
                filePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    posixPermissions |= 0111;

    if (NO == [NSFileManager.defaultManager setAttributes:@{ NSFilePosixPermissions : @(posixPermissions) }
                                             ofItemAtPath:filePath
                                                    error:&error])
    {
        fprintf(stderr,
                "failed to make hook %s executable. Error: %s\n",
                filePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    return 0;
}

@end
