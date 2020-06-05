//
//  S7AddCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7AddCommand.h"
#import "S7Config.h"
#import "Git.h"
#import "Utils.h"
#import "S7InitCommand.h"
#import "S7PostCheckoutHook.h"

@implementation S7AddCommand

+ (NSString *)commandName {
    return @"add";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    puts("s7 add [--stage] PATH [URL [branch]]");
    printCommandAliases(self);
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count < 1) {
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    BOOL stageConfig = NO;

    NSString *path = nil;
    NSString *url = nil;
    NSString *branch = nil;

    for (NSString *argument in arguments) {
        if ([argument hasPrefix:@"-"]) {
            if ([argument isEqualToString:@"--stage"]) {
                stageConfig = YES;
            }
            else {
                fprintf(stderr,
                        "option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeUnrecognizedOption;
            }
        }
        else {
            if (nil == path) {
                path = argument;
            }
            else if (nil == url) {
                url = argument;
            }
            else if (nil == branch) {
                branch = argument;
            }
            else {
                fprintf(stderr,
                        "redundant argument %s\n",
                        [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeInvalidArgument;
            }
        }
    }

    return [self doAddSubrepo:path url:url branch:branch stageConfig:stageConfig];
}

- (int)doAddSubrepo:(NSString *)path url:(NSString * _Nullable)url branch:(NSString * _Nullable)branch stageConfig:(BOOL)stageConfig {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if ([path hasPrefix:@"/"]) {
        fprintf(stderr, "only relative paths are expected\n");
        return S7ExitCodeInvalidArgument;
    }

    path = [path stringByStandardizingPath];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    for (S7SubrepoDescription *subrepoDesc in parsedConfig.subrepoDescriptions) {
        if ([subrepoDesc.path isEqualToString:path]) {
            fprintf(stderr, "subrepo at path '%s' already registered in %s.\n",
                    [path cStringUsingEncoding:NSUTF8StringEncoding],
                    [S7ConfigFileName cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeSubrepoAlreadyExists;
        }
    }

    GitRepository *gitSubrepo = nil;

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (0 == url.length) {
            NSLog(@"ERROR: failed to add subrepo. Non-empty url expected.");
            return S7ExitCodeInvalidArgument;
        }

        int cloneResult = 0;
        gitSubrepo = [GitRepository cloneRepoAtURL:url destinationPath:path exitStatus:&cloneResult];
        if (0 != cloneResult) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else if (NO == isDirectory) {
        NSLog(@"ERROR: failed to add subrepo at path '%@'. File exists and it's not a directory.", path);
        return S7ExitCodeInvalidArgument;
    }
    else {
        // 'add' can work in two modes:
        // 1. command clones the repo on it's own
        // 2. subrepo has already been cloned by a client.
        //    Here we check if a folder at @path is really what it should be.

        BOOL isDirectory = NO;
        if (NO == [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@".git"]
                                                       isDirectory:&isDirectory]
            || NO == isDirectory)
        {
            fprintf(stderr,
                    "folder at path '%s' already exists, but it's not a git repo\n",
                    [path cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        gitSubrepo = [[GitRepository alloc] initWithRepoPath:path];
        NSCAssert(gitSubrepo, @"");

        NSString *remote = nil;
        if (0 != [gitSubrepo getRemote:&remote]) {
            return S7ExitCodeGitOperationFailed;
        }

        NSString *actualRemoteUrl = nil;
        if (0 != [gitSubrepo getUrl:&actualRemoteUrl forRemote:remote]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (nil == url) {
            url = actualRemoteUrl;
        }
        else if (NO == [actualRemoteUrl isEqualToString:url]) {
            // if user gave us url, then we should compare it with the url from an existing repo he also gave us
            do {
                if (NO == [url hasPrefix:@"ssh:"] && NO == [url hasPrefix:@"git@"]) {
                    NSCAssert(NO == [url hasPrefix:@"file:"],
                              @"'file' protocol in url-form is not implemented. You are welcome to add it if you need it");

                    // there's a chance that this is the same local url in absolute and relative form
                    // 'actualRemoteUrl' returned by 'git remote get-url origin' is always absolute
                    if ([url hasPrefix:@"."] && NO == [url hasPrefix:@"/"]) {
                        // can also use 'standartizePath', but have no need at the moment
                        // leave that for future desperado programmers
                        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
                        NSString *absouluteUrl = [cwd stringByAppendingPathComponent:url];
                        if ([[absouluteUrl stringByStandardizingPath] isEqualToString:[actualRemoteUrl stringByStandardizingPath]]) {
                            break;
                        }
                    }
                }

                fprintf(stderr,
                        "inconsistency:"
                        "git remote at path '%s' has been cloned from '%s'.\n"
                        "repo requested to add should be cloned from '%s'\n",
                        [path cStringUsingEncoding:NSUTF8StringEncoding],
                        [actualRemoteUrl cStringUsingEncoding:NSUTF8StringEncoding],
                        [url cStringUsingEncoding:NSUTF8StringEncoding]);
                return S7ExitCodeInvalidArgument;
            } while(0);
        }
    }

    NSCAssert(gitSubrepo, @"");

    if ([gitSubrepo isBareRepo]) {
        fprintf(stderr, "adding bare git repo as a subrepo is not supported. What do you plan to develop in it?\n");
        return S7ExitCodeInvalidArgument;
    }

    if (branch) {
        if (0 != [gitSubrepo checkoutRemoteTrackingBranch:branch]) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else {
        if (0 != [gitSubrepo getCurrentBranch:&branch]) {
            return S7ExitCodeGitOperationFailed;
        }


        if (nil == branch) {
            if ([gitSubrepo isEmptyRepo]) {
                branch = @"master"; // ?
            }
            else {
                return S7ExitCodeGitOperationFailed;
            }
        }
    }

    NSString *revision = nil;
    if (0 != [gitSubrepo getCurrentRevision:&revision]) {
        return S7ExitCodeGitOperationFailed;
    }

    NSMutableArray<S7SubrepoDescription *> *newConfig = [parsedConfig.subrepoDescriptions mutableCopy];
    [newConfig addObject:[[S7SubrepoDescription alloc] initWithPath:path url:url revision:revision branch:branch]];

    NSCAssert(newConfig, @"");
    NSCAssert(newConfig.count == parsedConfig.subrepoDescriptions.count + 1, @"");

    // do this in transaction? all or nothing?

    const int gitignoreAddResult = addLineToGitIgnore(path);
    if (0 != gitignoreAddResult) {
        return gitignoreAddResult;
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:S7ConfigFileName] isDirectory:&isDirectory]) {
        if (isDirectory) {
            fprintf(stderr,
                    "warn: added subrepo '%s' contains %s, but that's a directory\n",
                    path.fileSystemRepresentation,
                    S7ConfigFileName.fileSystemRepresentation);
        }
        else {
            const int subrepoS7InitExitCode =
            executeInDirectory(path, ^int{
                S7InitCommand *initCommand = [S7InitCommand new];
                const int initExitCode = [initCommand runWithArguments:@[]];
                if (0 != initExitCode) {
                    return initExitCode;
                }

                // pastey:
                // I could have called `git checkout -- .s7substate` or `git checkout BRANCH`
                // to make just installed hook (post-checkout) do the trick,
                // but this would be harder to test (as unit-test would rely on the s7 installed
                // at test machine)
                //
                NSString *currentRevision = nil;
                [gitSubrepo getCurrentRevision:&currentRevision];

                const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:gitSubrepo
                                                                              fromRevision:[GitRepository nullRevision]
                                                                                toRevision:currentRevision];
                return checkoutExitStatus;
            });

            if (0 != subrepoS7InitExitCode) {
                fprintf(stderr, "failed to init system 7 in subrepo '%s'\n", path.fileSystemRepresentation);
                return subrepoS7InitExitCode;
            }
        }
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfig];
    const int configSaveResult = [updatedConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    if (0 != [updatedConfig saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);
        
        return S7ExitCodeFileOperationFailed;
    }

    if (stageConfig) {
        if (0 != [repo add:@[ S7ConfigFileName, @".gitignore" ]]) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else {
        fprintf(stdout,
                "please, don't forget to commit the %s and .gitignore\n",
                S7ConfigFileName.fileSystemRepresentation);
    }

    return S7ExitCodeSuccess;
}

@end
