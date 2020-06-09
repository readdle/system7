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
#import "S7PostCommitHook.h"
#import "S7PostMergeHook.h"

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
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    BOOL isDirectory = NO;
    const BOOL configFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (NO == configFileExisted) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:S7ConfigFileName contents:nil attributes:nil]) {
            fprintf(stderr, "error: failed to create %s file\n", S7ConfigFileName.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }

    const BOOL controlFileExisted = [NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName];
    if (NO == controlFileExisted) {
        if (0 != [[S7Config emptyConfig] saveToFileAtPath:S7ControlFileName]) {
            fprintf(stderr,
                    "failed to save %s to disk.\n",
                    S7ControlFileName.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }
    }

    NSSet<Class<S7Hook>> *hookClasses = [NSSet setWithArray:@[
        [S7PrePushHook class],
        [S7PostCheckoutHook class],
        [S7PostCommitHook class],
        [S7PostMergeHook class],
    ]];

    int hookInstallationExitCode = 0;
    for (Class<S7Hook> hookClass in hookClasses) {
        hookInstallationExitCode = [self installHook:hookClass];
        if (0 != hookInstallationExitCode) {
            fprintf(stderr,
                    "error: failed to install `%s` git hook\n",
                        [hookClass gitHookName].fileSystemRepresentation);
            return hookInstallationExitCode;
        }
    }

    const int gitIgnoreUpdateExitCode = addLineToGitIgnore(S7ControlFileName);
    if (0 != gitIgnoreUpdateExitCode) {
        return gitIgnoreUpdateExitCode;
    }

    const int configUpdateExitStatus = [self installS7ConfigMergeDriver];
    if (0 != configUpdateExitStatus) {
        return configUpdateExitStatus;
    }

    if (NO == controlFileExisted) {
        NSString *currentRevision = nil;
        if (0 != [repo getCurrentRevision:&currentRevision]) {
            return S7ExitCodeGitOperationFailed;
        }

        // pastey:
        // I considered two options:
        //  1. make 'init' pure, i.e. it just creates necessary files and (re-)installs hooks
        //     thus to get to work on an existing s7 repo, user would have to run two commands
        //      -- s7 init
        //      -- s7 reset / git checkout -- .s7substate
        //  2. make init run checkout on user's behalf to make setup easier
        //
        // I stuck to the second variant. Only if that's a first init (control file didn't exist)
        // This would make end user's experience better
        //
        const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:repo
                                                                      fromRevision:[GitRepository nullRevision]
                                                                        toRevision:currentRevision];
        if (0 != checkoutExitStatus) {
            return checkoutExitStatus;
        }
    }

    if (configFileExisted) {
        fprintf(stdout, "reinitialized s7 repo\n");
    }
    else {
        fprintf(stdout, "initialized s7 repo\n");
    }

    return 0;
}

- (int)installHook:(Class<S7Hook>)hookClass {
    NSString *hookFilePath = [@".git/hooks" stringByAppendingPathComponent:[hookClass gitHookName]];
    NSString *contents = [hookClass hookFileContents];

    if ([NSFileManager.defaultManager fileExistsAtPath:hookFilePath]) {
        NSString *existingContents = [[NSString alloc] initWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];
        if ([contents isEqualToString:existingContents]) {
            return 0;
        }

        fprintf(stderr,
                "hook already installed at path %s\n",
                hookFilePath.fileSystemRepresentation);
        return S7ExitCodeFileOperationFailed;
    }

    if (self.installFakeHooks) {
        contents = @"";
    }

    NSError *error = nil;
    if (NO == [contents writeToFile:hookFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        fprintf(stderr,
                "failed to save %s to disk. Error: %s\n",
                hookFilePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    NSUInteger posixPermissions = [NSFileManager.defaultManager attributesOfItemAtPath:hookFilePath error:&error].filePosixPermissions;
    if (error) {
        fprintf(stderr,
                "failed to read %s posix permissions. Error: %s\n",
                hookFilePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    posixPermissions |= 0111;

    if (NO == [NSFileManager.defaultManager setAttributes:@{ NSFilePosixPermissions : @(posixPermissions) }
                                             ofItemAtPath:hookFilePath
                                                    error:&error])
    {
        fprintf(stderr,
                "failed to make hook %s executable. Error: %s\n",
                hookFilePath.fileSystemRepresentation,
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

        return S7ExitCodeFileOperationFailed;
    }

    return 0;
}

- (int)installS7ConfigMergeDriver {
    if (self.installFakeHooks) {
        return 0;
    }

    NSString *configFilePath = @".git/config";

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:configFilePath
                   contents:nil
                   attributes:nil])
        {
            fprintf(stderr, "failed to create .git/config file\n");
            return 1;
        }
    }

    if (isDirectory) {
        fprintf(stderr, ".git/config is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        fprintf(stderr, "failed to read contents of .git/config file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 3;
    }

    NSString *mergeDriverDeclarationHeader = @"[merge \"s7\"]";
    NSArray<NSString *> *existingGitConfigLines = [newContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (NO == [existingGitConfigLines containsObject:mergeDriverDeclarationHeader]) {
        if (newContent.length > 0 && NO == [newContent hasSuffix:@"\n"]) {
            [newContent appendString:@"\n"];
        }

        NSMutableString *mergeDriverDeclaration = [mergeDriverDeclarationHeader mutableCopy];
        [mergeDriverDeclaration appendString:@"\n"];
        [mergeDriverDeclaration appendString:@"\tdriver = s7 merge-driver %O %A %B\n"];

        [newContent appendString:mergeDriverDeclaration];

        if (NO == [newContent writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
            fprintf(stderr, "failed to write contents of .git/config file. Error: %s\n",
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return 4;
        }
    }

    const int gitattributesUpdateExitCode = addLineToGitAttributes([NSString stringWithFormat:@"%@ merge=s7", S7ConfigFileName]);
    if (0 != gitattributesUpdateExitCode) {
        return gitattributesUpdateExitCode;
    }

    return 0;
}

int addLineToGitAttributes(NSString *lineToAppend) {
    static NSString *gitattributesFileName = @".gitattributes";

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:gitattributesFileName isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:gitattributesFileName
                   contents:nil
                   attributes:nil])
        {
            fprintf(stderr, "failed to create .gitattributes file\n");
            return 1;
        }
    }

    if (isDirectory) {
        fprintf(stderr, ".gitattributes is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:gitattributesFileName encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        fprintf(stderr, "failed to read contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 3;
    }

    NSArray<NSString *> *existingGitattributeLines = [newContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (NSNotFound != [existingGitattributeLines indexOfObject:lineToAppend]) {
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

    if (NO == [newContent writeToFile:gitattributesFileName atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        fprintf(stderr, "failed to write contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

@end
