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
#import "S7PostCheckoutHook.h"

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
    const BOOL configFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (NO == configFileExisted) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:S7ConfigFileName contents:nil attributes:nil]) {
            fprintf(stderr, "error: failed to create %s file\n", S7ConfigFileName.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }

    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7HashFileName]) {
        NSError *error = nil;
        if (NO == [[S7Config emptyConfig].sha1 writeToFile:S7HashFileName atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            fprintf(stderr,
                    "failed to save %s to disk. Error: %s\n",
                    S7HashFileName.fileSystemRepresentation,
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

            return S7ExitCodeFileOperationFailed;
        }
    }

    NSDictionary<NSString *, NSString *> *hooksToInstall =
        @{
            S7GitPrePushHookFilePath : S7GitPrePushHookFileContents,
            S7GitPostCheckoutHookFilePath : S7GitPostCheckoutHookFileContents,
        };

    __block int hookInstallationExitCode = 0;
    [hooksToInstall
     enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull path, NSString * _Nonnull contents, BOOL * _Nonnull stop) {
        hookInstallationExitCode = [self installHookFile:path withContents:contents];
        if (0 != hookInstallationExitCode) {
            *stop = YES;
        }
    }];

    if (0 != hookInstallationExitCode) {
        return hookInstallationExitCode;
    }

    const int gitIgnoreUpdateExitCode = addLineToGitIgnore(S7HashFileName);
    if (0 != gitIgnoreUpdateExitCode) {
        return gitIgnoreUpdateExitCode;
    }

    if (configFileExisted) {
        fprintf(stdout, "reinitialized s7 repo\n");
    }
    else {
        fprintf(stdout, "initialized s7 repo\n");
    }

    return 0;
}

- (int)installHookFile:(NSString *)filePath withContents:(NSString *)contents {
    if ([NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        NSString *existingContents = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        if ([contents isEqualToString:existingContents]) {
            return 0;
        }

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
