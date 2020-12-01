//
//  S7InitCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7InitCommand.h"

#import "Utils.h"
#import "HelpPager.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"
#import "S7PostCommitHook.h"
#import "S7PostMergeHook.h"
#import "S7PrepareCommitMsgHook.h"

@interface S7InitCommand ()

@property (nonatomic, assign) BOOL forceOverwriteHooks;

@end

@implementation S7InitCommand

+ (NSString *)commandName {
    return @"init";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 init");
    printCommandAliases(self);
    help_puts("");
    help_puts("    No other s7 command can be run on a repo untill s7 is");
    help_puts("    initialized in the repo.");
    help_puts("");
    help_puts("    On a virgin repo – creates all necessary config files,");
    help_puts("    installs git hooks, configures merge driver.");
    help_puts("");
    help_puts("    `s7 init` must be called on a newly cloned s7 repo.");
    help_puts("    It will not only install necessary hooks, but also");
    help_puts("    checkout subrepos. If any subrepo is an s7 repo itself");
    help_puts("    it will also be initialized.");
    help_puts("");
    help_puts("    Can be called multiple times to re-install necessary");
    help_puts("    files/hooks if they are missing.");
    help_puts("");
    help_puts("    Installed s7 files:");
    help_puts("");
    help_puts("     .s7substate:  main config file that stores the state of");
    help_puts("                   subrepos. The only file you'll actually");
    help_puts("                   work with. All other files are 'system'.");
    help_puts("");
    help_puts("     .s7control:   control copy of .s7substate that is used");
    help_puts("                   to detect unauthorized changes to .s7substate.");
    help_puts("                   Also used by some git-hooks for other tasks.");
    help_puts("");
    help_puts("     .s7bak:       created in some cases when you 'loose' commits");
    help_puts("                   in subrepos. Detached commit hashes are printed");
    help_puts("                   to console and also saved to this file.");
    help_puts("");
    help_puts("     .s7bootstrap: used to automatically run `s7 init` in a newly");
    help_puts("                   cloned repo, freeing user from the need to run");
    help_puts("                   `s7 init` manually.");
    help_puts("");
    help_puts("    Installed/modified Git hooks/configuration files:");
    help_puts("");
    help_puts("     .gitignore:   all registered subrepos are added to .gitignore.");
    help_puts("");
    help_puts("     .gitattributes, .git/config:");
    help_puts("                   merge driver for .s7substate file is registered");
    help_puts("                   in these files.");
    help_puts("");
    help_puts("     .git/hooks/post-checkout,");
    help_puts("     .git/hooks/post-commit,");
    help_puts("     .git/hooks/post-merge,");
    help_puts("     .git/hooks/prepare-commit-msg,");
    help_puts("     .git/hooks/pre-push:");
    help_puts("                   these hooks automate s7 operations such as:");
    help_puts("                   push subrepos before main repo is pushed;");
    help_puts("                   checkout subrepos to the proper state on");
    help_puts("                   git pull/checkout/merge");
    help_puts("                   etc.");
    help_puts("");
    help_puts("options:");
    help_puts("");
    help_puts(" --force -f   Forcibly overwrite any existing hooks with s7 hooks. Use this option");
    help_puts("              if s7 init fails because of existing hooks but you don't care");
    help_puts("              about their current contents.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    BOOL bootstrap = NO;

    for (NSString *argument in arguments) {
        if ([argument isEqualToString:@"-f"] || [argument isEqualToString:@"--force"]) {
            self.forceOverwriteHooks = YES;
        }
        else if ([argument isEqualToString:@"--bootstrap"]) {
            bootstrap = YES;
        }
        else {
            return S7ExitCodeUnrecognizedOption;
        }
    }

    if (bootstrap) {
        return [self bootstrap];
    }

    BOOL isDirectory = NO;
    const BOOL configFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory];
    if (NO == configFileExisted) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:S7ConfigFileName contents:nil attributes:nil]) {
            fprintf(stderr, "error: failed to create %s file\n", S7ConfigFileName.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }

    NSSet<Class<S7Hook>> *hookClasses = [NSSet setWithArray:@[
        [S7PrePushHook class],
        [S7PostCheckoutHook class],
        [S7PostCommitHook class],
        [S7PostMergeHook class],
        [S7PrepareCommitMsgHook class],
    ]];

    int hookInstallationExitCode = 0;
    for (Class<S7Hook> hookClass in hookClasses) {
        hookInstallationExitCode = [self installHook:hookClass];
        if (0 != hookInstallationExitCode) {
            fprintf(stderr,
                    "\033[31m"
                    "error: failed to install `%s` git hook\n"
                    "\033[0m",
                        [hookClass gitHookName].fileSystemRepresentation);
            return hookInstallationExitCode;
        }
    }

    const int gitIgnoreUpdateExitCode = addLineToGitIgnore(S7ControlFileName);
    if (0 != gitIgnoreUpdateExitCode) {
        return gitIgnoreUpdateExitCode;
    }

    if (0 != addLineToGitIgnore(S7BakFileName)) {
        return S7ExitCodeFileOperationFailed;
    }

    const int configUpdateExitStatus = [self installS7ConfigMergeDriver];
    if (0 != configUpdateExitStatus) {
        return configUpdateExitStatus;
    }

    const int bootstrapFileCreationExitCode = [self createBootstrapFile];
    if (0 != bootstrapFileCreationExitCode) {
        return bootstrapFileCreationExitCode;
    }

    const BOOL controlFileExisted = [NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName];
    if (NO == controlFileExisted) {
        // create control file at the very end.
        // existance of .s7control is used as an indicator that s7 repo
        // is well formed. No other command will run if there's no .s7control
        //
        if (0 != [[S7Config emptyConfig] saveToFileAtPath:S7ControlFileName]) {
            fprintf(stderr,
                    "failed to save %s to disk.\n",
                    S7ControlFileName.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }

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
        fprintf(stdout, "reinitialized s7 repo in '%s'\n", repo.absolutePath.fileSystemRepresentation);
    }
    else {
        fprintf(stdout, "initialized s7 repo in '%s'\n", repo.absolutePath.fileSystemRepresentation);
    }

    return S7ExitCodeSuccess;
}

- (int)bootstrap {
    if (NO == [self willBootstrapConflictWithGitLFS]) {
        // we may still fail to install bootstrap, for example, if post-checkout hook exists
        // and it's not a shell script (where we can merge in)
        [self
         installHook:@"post-checkout"
         commandLine:[self bootstrapCommandLine]];
    }

    // according to https://git-scm.com/docs/gitattributes
    //  "filter driver that exits with a non-zero status, is not an error but makes the filter a no-op passthru."
    // but in reality, if filter exist with non-zero, Git writes:
    //  "error: external filter 's7 init bootstrap' failed 1"
    // it doesn't affect the clone process, but looks ugly.
    // So... we'd have to actually perform the "filter" and exit gracefully
    //
    if (NO == self.runFakeFilter) {
        char c;
        while ((c=getchar()) != EOF) {
            putchar(c);
        }
    }

    return 0;
}

- (BOOL)willBootstrapConflictWithGitLFS {
    NSError *error = nil;
    NSString *gitattributesContent = [[NSString alloc] initWithContentsOfFile:@".gitattributes" encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        // Such situation would be really unexpected – how would Git find out
        // that it should filter .s7bootstrap if there's no .gitattributes?
        // Maybe something wrong with the permissions?
        // Anyway, if we cannot read .gitattributes, then we better avoid bootstrap.
        //
        fprintf(stderr, "s7 bootstrap: failed to read contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return YES;
    }

    if ([gitattributesContent containsString:@"filter=lfs"]) {
        // this repo contains some LFS files.
        // If LFS hook is NOT installed, then we do not install bootstrap hook
        // not to cause LFS hook install failure. In such case user will have to
        // run `s7 init` manually 🤷‍♂️
        // If LFS hook IS installed, we can still merge-in bootstrap command into it.
        //
        if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".git/hooks/post-checkout"]) {
            return YES;
        }
    }

    return NO;
}

- (NSString *)bootstrapCommandLine {
    return @"/usr/local/bin/s7 init";
}

- (int)installHook:(Class<S7Hook>)hookClass {
    // there's no guarantie that s7 will be the only one citizen of a hook,
    // thus we add " || exit $?" – to exit hook properly if s7 hook fails
    NSString *commandLine = [NSString
                             stringWithFormat:
                             @"/usr/local/bin/s7 %@-hook \"$@\" <&0 || exit $?",
                             [hookClass gitHookName]];

    return [self installHook:[hookClass gitHookName]
                 commandLine:commandLine];
}

- (int)installHook:(NSString *)hookName commandLine:(NSString *)commandLine {
    NSString *hookFilePath = [@".git/hooks" stringByAppendingPathComponent:hookName];

    NSString *contentsToWrite = [NSString stringWithFormat:@"#!/bin/sh\n\n%@\n", commandLine];

    if (NO == self.forceOverwriteHooks && [NSFileManager.defaultManager fileExistsAtPath:hookFilePath]) {
        NSString *existingContents = [[NSString alloc] initWithContentsOfFile:hookFilePath encoding:NSUTF8StringEncoding error:nil];
        if (NO == [existingContents hasPrefix:@"#!/bin/sh\n"]) {
            fprintf(stderr,
                    "\033[31m"
                    "hook %s already exists and it's not a shell script, so we cannot merge s7 call into it\n"
                    "\033[0m",
                    hookFilePath.fileSystemRepresentation);

            return S7ExitCodeFileOperationFailed;
        }

        if ([existingContents containsString:commandLine]) {
            return 0;
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
            existingHookBody = [existingHookBody stringByReplacingOccurrencesOfString:[self bootstrapCommandLine]
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

    if (self.installFakeHooks) {
        contentsToWrite = @"";
    }

    NSError *error = nil;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".git/hooks"]) {
        if (NO == [NSFileManager.defaultManager
                   createDirectoryAtPath:@".git/hooks"
                   withIntermediateDirectories:NO
                   attributes:nil
                   error:&error])
        {
            fprintf(stderr,
                    "'.git/hooks' directory doesn't exist. Failed to create it. Error: %s\n",
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);

            return S7ExitCodeFileOperationFailed;
        }
    }

    if (NO == [contentsToWrite writeToFile:hookFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
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

- (int)createBootstrapFile {
    if (self.installFakeHooks) {
        return S7ExitCodeSuccess;
    }

    const BOOL fileExisted = [[NSFileManager defaultManager] fileExistsAtPath:S7BootstrapFileName];
    if (NO == fileExisted) {
        NSString *bootstrapFileContents =
        @"This file is used to automatically run `s7 init` when an existing s7 repo is cloned.\n"
         "You clone a repo and all subrepos are cloned automatically, and there's no need to\n"
         "remember that you should call `s7 init` manually.\n"
         "\n"
         "In case you are curious, here's how it works:\n"
         " 0. on installation, s7 registers as the filter in the global git config.\n"
         "    See https://git-scm.com/docs/gitattributes [filter] for more info on filters.\n"
         "\n"
         " 1. when s7 is first set up in a repo, it creates .s7bootstrap (this file)\n"
         "    and modifies repo's .gitattributes to tell Git that .s7bootstrap should be \"filtered\" with s7.\n"
         "\n"
         " 2. once `git clone` is complete, Git checks out files into a working tree.\n"
         "    .s7bootstrap is also checked out and s7 filter is called.\n"
         "    This is the backdoor we will use to call `s7 init` automatically.\n"
         "\n"
         " 3. s7 filter cannot call `s7 init` right away as there's no guarantee that other\n"
         "    files have been checked out by this time (for example, .s7substate).\n"
         "    Thus, s7 filter installs a temporary post-checkout hook.\n"
         "\n"
         " 4. after all files have been checked out, post-checkout hook is called,\n"
         "    and it finally calls `s7 init`.\n"
         "\n"
         "\n"
         "Are there any possible alternatives to this process? Sure:\n"
         "  - call `s7 init` manually :) You may still have to do this if bootstrap fails. Read more below.\n"
         "  - implement `s7 clone` command. I think this is too easy to misuse – one will run `git clone`\n"
         "    just because of muscle memory, see no subrepos and curse. Plus, this is one more command to remember.\n"
         "  - templates to use with `git clone --template ...`. Same issues as with custom clone command,\n"
         "    but this one looks even more complex – some new terms... templates (wat?!), you'd have to remember\n"
         "    the path to those templates. Too complex.\n"
         "\n"
         "\n"
         "NOTE:\n"
         " s7 won't install its bootstrap hook if:\n"
         "  - post-checkout hook exists and it's not a shell script (where we can merge in).\n"
         "    This is theoretically possible if a user ran clone with custom templates\n"
         "  - there's *no post-checkout hook yet*, but s7 can see that the repo uses Git LFS,\n"
         "    thus it can predict that LFS *will* be installing its hooks. If s7 installs\n"
         "    its bootstrap post-checkout, then Git LFS will fail to install its post-checkout –\n"
         "    not the situation we want a user to deal with.\n"
         ;

        if (NO == [[NSFileManager defaultManager] createFileAtPath:S7BootstrapFileName
                                                          contents:[bootstrapFileContents dataUsingEncoding:NSUTF8StringEncoding]
                                                        attributes:nil]) {
            fprintf(stderr, "error: failed to create %s file\n", S7BootstrapFileName.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }

    const int gitattributesUpdateExitCode = addLineToGitAttributes([NSString stringWithFormat:@"%@ filter=s7", S7BootstrapFileName]);
    if (0 != gitattributesUpdateExitCode) {
        return gitattributesUpdateExitCode;
    }

    return S7ExitCodeSuccess;
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

    if (NO == [newContent writeToFile:gitattributesFileName atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        fprintf(stderr, "failed to write contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

@end
