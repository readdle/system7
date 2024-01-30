//
//  S7AddCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7AddCommand.h"
#import "S7Config.h"
#import "S7Options.h"
#import "Git.h"
#import "Utils.h"
#import "S7InitCommand.h"
#import "S7PostCheckoutHook.h"
#import "HelpPager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S7AddCommand

+ (NSString *)commandName {
    return @"add";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 add [--stage] PATH [URL [BRANCH]]");
    printCommandAliases(self);
    help_puts("");
    help_puts("add a new subrepo at PATH.");
    help_puts("");
    help_puts("    If used with the PATH only, assumes that subrepo has been already");
    help_puts("    cloned to the PATH. Deduces URL and BRANCH from the actual subrepo");
    help_puts("    git repo state.");
    help_puts("");
    help_puts("    If used with PATH and URL, clones git repo from URL to PATH.");
    help_puts("    (If subrepo at PATH already exists, then `add` will check that it");
    help_puts("    was cloned from the URL.)");
    help_puts("    In this variant, if BRANCH is supplied, cloned subrepo is also");
    help_puts("    switched to the BRANCH.");
    help_puts("");
    help_puts("options:");
    help_puts("");
    help_puts(" --stage     stage updated files for save with the next `git commit`");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

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
                logError("option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
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
                logError("redundant argument %s\n",
                         [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeInvalidArgument;
            }
        }
    }

    if (nil == path) {
        logError("missing required argument PATH\n");
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    return [self doAddSubrepo:path url:url branch:branch stageConfig:stageConfig];
}

- (int)doAddSubrepo:(NSString *)path url:(NSString * _Nullable)url branch:(NSString * _Nullable)branch stageConfig:(BOOL)stageConfig {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        logError("s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if ([path hasPrefix:@"/"]) {
        logError("only relative paths are expected\n");
        return S7ExitCodeInvalidArgument;
    }

    path = [path stringByStandardizingPath];

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    for (S7SubrepoDescription *subrepoDesc in parsedConfig.subrepoDescriptions) {
        if ([subrepoDesc.path isEqualToString:path]) {
            logError("subrepo at path '%s' already registered in %s.\n",
                    [path cStringUsingEncoding:NSUTF8StringEncoding],
                    [S7ConfigFileName cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeSubrepoAlreadyExists;
        }
    }

    S7Options *options = [S7Options new];
    GitRepository *gitSubrepo = nil;

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (0 == url.length) {
            logError("failed to add subrepo. Non-empty url expected.");
            return S7ExitCodeInvalidArgument;
        }
        
        if (NO == S7URLStringMatchesTransportProtocolNames(url, options.allowedTransportProtocols)) {
            logError("URL '%s' does not match allowed transport protocol(s): %s.\n",
                     [url cStringUsingEncoding:NSUTF8StringEncoding],
                     [[options.allowedTransportProtocols.allObjects componentsJoinedByString:@", "]
                      cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeInvalidArgument;
        }

        int cloneResult = 0;
        gitSubrepo = [GitRepository cloneRepoAtURL:url
                                   destinationPath:path
                                            filter:options.filter
                                        exitStatus:&cloneResult];
        
        if (0 != cloneResult) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else if (NO == isDirectory) {
        logError("failed to add subrepo at path '%s'. File exists and it's not a directory.", 
                 path.fileSystemRepresentation);
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
            logError("folder at path '%s' already exists, but it's not a git repo\n",
                     [path cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        gitSubrepo = [[GitRepository alloc] initWithRepoPath:path];
        NSCAssert(gitSubrepo, @"");

        NSString *actualRemoteUrl = nil;
        if (0 != [gitSubrepo getUrl:&actualRemoteUrl]) {
            return S7ExitCodeGitOperationFailed;
        }
        
        if (NO == S7URLStringMatchesTransportProtocolNames(actualRemoteUrl, options.allowedTransportProtocols)) {
            logError("cloned subrepo URL '%s' does not match allowed transport protocol(s): %s.\n",
                     [actualRemoteUrl cStringUsingEncoding:NSUTF8StringEncoding],
                     [[options.allowedTransportProtocols.allObjects componentsJoinedByString:@", "]
                      cStringUsingEncoding:NSUTF8StringEncoding]);
            return S7ExitCodeInvalidArgument;
        }

        if (nil == url) {
            url = actualRemoteUrl;
        }
        else if (NO == [actualRemoteUrl isEqualToString:url]) {
            // if user gave us @url, then we should compare it with the url from an existing repo at the @path argument
            do {
                if (NO == [url hasPrefix:@"ssh:"] && NO == [url hasPrefix:@"git@"]) {
                    NSCAssert(NO == [url hasPrefix:@"file:"],
                              @"'file' protocol in url-form is not implemented. You are welcome to add it if you need it");

                    // there's a chance that this is the same local url in absolute and relative form.
                    // 'actualRemoteUrl' returned by 'git remote get-url origin' is always absolute
                    if ([url hasPrefix:@"./"]) {
                        // can also use 'standartizePath', but have no need at the moment
                        // leave that for future desperado programmers
                        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
                        NSString *absouluteUrl = [cwd stringByAppendingPathComponent:url];
                        if ([[absouluteUrl stringByStandardizingPath] isEqualToString:[actualRemoteUrl stringByStandardizingPath]]) {
                            break;
                        }
                    }
                }

                logError("inconsistency:"
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
        logError("adding bare git repo as a subrepo is not supported. What do you plan to develop in it?\n");
        return S7ExitCodeInvalidArgument;
    }

    if (branch) {
        if (0 != [gitSubrepo checkoutRemoteTrackingBranch:branch]) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else {
        BOOL isEmptyRepo = NO;
        BOOL isDetachedHEAD = NO;
        if (0 != [gitSubrepo getCurrentBranch:&branch isDetachedHEAD:&isDetachedHEAD isEmptyRepo:&isEmptyRepo]) {
            return S7ExitCodeGitOperationFailed;
        }


        if (nil == branch) {
            if (isEmptyRepo) {
                // if we allowed to add an empty subrepo, then such bad things will be possible:
                //  1. someone adds an empty subrepo
                //  2. pushes it (they won't be able to push, for starters,
                //     but let's imagine, that person's a cool hacker and they do push main repo with
                //     .s7substate pointing to an empty repo)
                //  3. someone else clones the subrepo as a free-standing repo, and pushes some
                //     changes to it.
                //  4. some third innocent developer pulls the main repo, with subrepo pointing
                //     to an empty subrepo. We would have to clone the subrepo (it would clone
                //     with the changes from (3) by default). Say, we are smart and we would tell
                //     git... what? there's no way to force git to checkout NULL revision. We could
                //     clone with -n, but that's a crap too.
                //
                // One more scenario:
                //  1. someone adds an empty subrepo. Commits.
                //  2. switches to do some work on a different branch
                //  3. switches back to the original branch where he added an empty subrepo. How do we checkout NULL?
                //
                logError(" Adding empty git repo as a subrepo is not allowed.\n"
                         "\n"
                         " There will be no chance for you and your fellow developers\n"
                         " to checkout this subrepo properly in some situations.\n"
                         "\n"
                         " Please add any commit to this subrepo.\n"
                         " For example, adding .gitignore is always a good idea.\n");
                return S7ExitCodeInvalidArgument;
            }
            else {
                // detached HEAD is an evil. If someone could share subrepo in a detached HEAD,
                // then that person would share all pleasures of detached HEAD with others.
                // Besides, I want to see how that person pushes the detached HEAD. Like this:
                //  `git push origin HEAD:main`?
                //
                // Branch is required. No discussions.
                //
                NSAssert(isDetachedHEAD, @"");
                logError(" Adding subrepo with a detached HEAD is not allowed.\n"
                         "\n"
                         " Please, as the courtesy to fellow developers,\n"
                         " checkout a named branch in this subrepo.\n");
                return S7ExitCodeInvalidArgument;
            }
        }
    }

    NSString *revision = nil;
    if (0 != [gitSubrepo getCurrentRevision:&revision]) {
        return S7ExitCodeGitOperationFailed;
    }

    NSCAssert(parsedConfig && parsedConfig.subrepoDescriptions, @"");

    NSMutableArray<S7SubrepoDescription *> *newConfig = [parsedConfig.subrepoDescriptions mutableCopy];
    [newConfig addObject:[[S7SubrepoDescription alloc] initWithPath:path url:url revision:revision branch:branch]];

    NSCAssert(newConfig, @"");
    NSCAssert(newConfig.count == parsedConfig.subrepoDescriptions.count + 1, @"");

    // do this in transaction? all or nothing?

    const int gitignoreAddResult = addLineToGitIgnore(repo, path);
    if (0 != gitignoreAddResult) {
        return gitignoreAddResult;
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:S7ConfigFileName] isDirectory:&isDirectory]) {
        if (isDirectory) {
            logError("warn: added subrepo '%s' contains %s, but that's a directory\n",
                     path.fileSystemRepresentation,
                     S7ConfigFileName.fileSystemRepresentation);
        }
        else {
            const int subrepoS7InitExitCode =
            executeInDirectory(path, ^int{
                S7InitCommand *initCommand = [S7InitCommand new];
                initCommand.installFakeHooks = self.installFakeHooks;
                const int initExitCode = [initCommand runWithArguments:@[ @"--no-bootstrap" ]];
                if (0 != initExitCode) {
                    return initExitCode;
                }

                // pastey:
                // I could have called `git checkout -- .s7substate` or `git checkout BRANCH`
                // to make just installed hook (post-checkout) do the trick,
                // but this would be harder to test (as unit-test would rely on the s7 installed
                // at test machine)
                //
                const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:gitSubrepo
                                                                              fromRevision:[GitRepository nullRevision]
                                                                                toRevision:revision];
                return checkoutExitStatus;
            });

            if (0 != subrepoS7InitExitCode) {
                logError("failed to init system 7 in subrepo '%s'\n", path.fileSystemRepresentation);
                return subrepoS7InitExitCode;
            }
        }
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfig];

    SAVE_UPDATED_CONFIG_TO_MAIN_AND_CONTROL_FILE(updatedConfig);

    if (stageConfig) {
        if (0 != [repo add:@[ S7ConfigFileName, @".gitignore" ]]) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else {
        logInfo("please, don't forget to commit the %s and .gitignore\n",
                S7ConfigFileName.fileSystemRepresentation);
    }

    return S7ExitCodeSuccess;
}

@end

NS_ASSUME_NONNULL_END
