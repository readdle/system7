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
#import "S7BootstrapCommand.h"

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
    help_puts(" --force -f        Forcibly overwrite any existing hooks with s7 hooks. Use this option");
    help_puts("                   if s7 init fails because of existing hooks but you don't care");
    help_puts("                   about their current contents.");
    help_puts("");
    help_puts(" --no-bootstrap    Do not create .s7bootstrap file.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    return [self runWithArguments:arguments inRepo:repo];
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments inRepo:(GitRepository *)repo {
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    BOOL createBootstrapFile = YES;

    for (NSString *argument in arguments) {
        if ([argument isEqualToString:@"-f"] || [argument isEqualToString:@"--force"]) {
            self.forceOverwriteHooks = YES;
        }
        else if ([argument isEqualToString:@"--no-bootstrap"]) {
            createBootstrapFile = NO;
        }
        else {
            return S7ExitCodeUnrecognizedOption;
        }
    }

    NSString *const absoluteRepoPath = repo.absolutePath;

    NSString *const configFilePath = [absoluteRepoPath stringByAppendingPathComponent:S7ConfigFileName];
    BOOL isDirectory = NO;
    const BOOL configFileExisted = [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&isDirectory];
    if (NO == configFileExisted) {
        if (NO == [[NSFileManager defaultManager] createFileAtPath:configFilePath contents:nil attributes:nil]) {
            logError("failed to create %s file\n", configFilePath.fileSystemRepresentation);
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
        hookInstallationExitCode = [self installHook:hookClass inRepo:repo];
        if (0 != hookInstallationExitCode) {
            logError("error: failed to install `%s` git hook\n",
                     [hookClass gitHookName].fileSystemRepresentation);
            return hookInstallationExitCode;
        }
    }

    const int gitIgnoreUpdateExitCode = addLineToGitIgnore(repo, S7ControlFileName);
    if (0 != gitIgnoreUpdateExitCode) {
        return gitIgnoreUpdateExitCode;
    }

    if (0 != addLineToGitIgnore(repo, S7BakFileName)) {
        return S7ExitCodeFileOperationFailed;
    }

    const int configUpdateExitStatus = [self installS7ConfigMergeDriverInRepo:repo];
    if (0 != configUpdateExitStatus) {
        return configUpdateExitStatus;
    }

    if (createBootstrapFile) {
        const int bootstrapFileCreationExitCode = [self createBootstrapFileInRepo:repo];
        if (0 != bootstrapFileCreationExitCode) {
            return bootstrapFileCreationExitCode;
        }
    }

    NSString *const controlFilePath = [absoluteRepoPath stringByAppendingPathComponent:S7ControlFileName];
    const BOOL controlFileExisted = [NSFileManager.defaultManager fileExistsAtPath:controlFilePath];
    if (NO == controlFileExisted) {
        // create control file at the very end.
        // existence of .s7control is used as an indicator that s7 repo
        // is well formed. No other command will run if there's no .s7control
        //
        if (0 != [[S7Config emptyConfig] saveToFileAtPath:controlFilePath]) {
            logError("failed to save %s to disk.\n",
                     controlFilePath.fileSystemRepresentation);

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
        // I stuck to the second variant. Only if that's a first init (control file didn't exist).
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
        logInfo("reinitialized s7 repo in '%s'\n", repo.absolutePath.fileSystemRepresentation);
    }
    else {
        logInfo("initialized s7 repo in '%s'\n", repo.absolutePath.fileSystemRepresentation);
    }

    return S7ExitCodeSuccess;
}

- (int)installHook:(Class<S7Hook>)hookClass inRepo:(GitRepository *)repo {
    // there's no guarantee that s7 will be the only one citizen of a hook,
    // thus we add " || exit $?" – to exit hook properly if s7 hook fails
    NSString *commandLine = [NSString
                             stringWithFormat:
                             @"/usr/local/bin/s7 %@-hook \"$@\" <&0 || exit $?",
                             [hookClass gitHookName]];

    return installHook(repo, [hookClass gitHookName], commandLine, self.forceOverwriteHooks, self.installFakeHooks);
}

- (int)installS7ConfigMergeDriverInRepo:(GitRepository *)repo {
    if (self.installFakeHooks) {
        return 0;
    }

    NSString *configFilePath = [repo.absolutePath stringByAppendingPathComponent:@".git/config"];

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:configFilePath isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:configFilePath
                   contents:nil
                   attributes:nil])
        {
            logError("failed to create .git/config file\n");
            return 1;
        }
    }

    if (isDirectory) {
        logError(".git/config is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        logError("failed to read contents of .git/config file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeFileOperationFailed;
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
            logError("failed to write contents of .git/config file. Error: %s\n",
                    [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
            return 4;
        }
    }

    const int gitattributesUpdateExitCode = 
        addLineToGitAttributes(repo, [NSString stringWithFormat:@"%@ merge=s7", S7ConfigFileName]);
    if (0 != gitattributesUpdateExitCode) {
        return gitattributesUpdateExitCode;
    }

    return 0;
}

- (int)createBootstrapFileInRepo:(GitRepository *)repo {
    if (self.installFakeHooks) {
        return S7ExitCodeSuccess;
    }

    NSString *const bootstrapFilePath = [repo.absolutePath stringByAppendingPathComponent:S7BootstrapFileName];
    const BOOL fileExisted = [[NSFileManager defaultManager] fileExistsAtPath:bootstrapFilePath];
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

        if (NO == [[NSFileManager defaultManager] createFileAtPath:bootstrapFilePath
                                                          contents:[bootstrapFileContents dataUsingEncoding:NSUTF8StringEncoding]
                                                        attributes:nil]) {
            logError("failed to create %s file\n", bootstrapFilePath.fileSystemRepresentation);
            return S7ExitCodeFileOperationFailed;
        }
    }

    const int gitattributesUpdateExitCode = 
        addLineToGitAttributes(repo, [NSString stringWithFormat:@"%@ filter=s7", S7BootstrapFileName]);
    if (0 != gitattributesUpdateExitCode) {
        return gitattributesUpdateExitCode;
    }

    return S7ExitCodeSuccess;
}

@end
