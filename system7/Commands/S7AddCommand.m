//
//  S7AddCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7AddCommand.h"
#import "S7Parser.h"
#import "Git.h"

@implementation S7AddCommand

- (void)printCommandHelp {
    puts("s7 add PATH [URL [branch]]");
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count < 1) {
        [self printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    NSString *path = arguments[0];
    NSCAssert(path.length > 0, @"");

    NSString *url = nil;
    if (arguments.count > 1) {
        url = arguments[1];
    }

    NSString *branch = nil;
    if (arguments.count > 2) {
        branch = arguments[2];
    }

    return [self doAddSubrepo:path url:url branch:branch];
}

- (int)doAddSubrepo:(NSString *)path url:(NSString * _Nullable)url branch:(NSString * _Nullable)branch {
    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    for (S7SubrepoDescription *subrepoDesc in parsedConfig.subrepoDescriptions) {
        if ([subrepoDesc.path isEqualToString:path]) {
            fprintf(stderr, "subrepo at path '%s' already registered in %s.\n",
                    [path cStringUsingEncoding:NSUTF8StringEncoding],
                    [S7ConfigFileName cStringUsingEncoding:NSUTF8StringEncoding]);
            return 1;
        }
    }

    GitRepository *gitSubrepo = nil;

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (0 == url.length) {
            NSLog(@"ERROR: failed to add subrepo. Non-empty url expected.");
            return 1;
        }

        int cloneResult = 0;
        gitSubrepo = [GitRepository cloneRepoAtURL:url destinationPath:path exitStatus:&cloneResult];
        if (0 != cloneResult) {
            return cloneResult;
        }
    }
    else if (NO == isDirectory) {
        NSLog(@"ERROR: failed to add subrepo at path '%@'. File exists and it's not a directory.", path);
        return 1;
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
        const int remoteResult = [gitSubrepo getRemote:&remote];
        if (0 != remoteResult) {
            return remoteResult;
        }

        NSString *actualRemoteUrl = nil;
        const int remoteUrlResult = [gitSubrepo getUrl:&actualRemoteUrl forRemote:remote];
        if (0 != remoteUrlResult) {
            return remoteUrlResult;
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
                return 1;
            } while(0);
        }
    }

    NSCAssert(gitSubrepo, @"");

    if (branch) {
        const int checkoutResult = [gitSubrepo checkoutRemoteTrackingBranch:branch];
        if (0 != checkoutResult) {
            return checkoutResult;
        }
    }

    NSString *revision = nil;
    const int getRevisionResult = [gitSubrepo getCurrentRevision:&revision];
    if (0 != getRevisionResult) {
        return getRevisionResult;
    }

    NSMutableArray<S7SubrepoDescription *> *newConfig = [parsedConfig.subrepoDescriptions mutableCopy];
    [newConfig addObject:[[S7SubrepoDescription alloc] initWithPath:path url:url revision:revision branch:branch]];

    NSCAssert(newConfig, @"");
    NSCAssert(newConfig.count == parsedConfig.subrepoDescriptions.count + 1, @"");

    // do this in transaction? all or nothing?

    const int gitignoreAddResult = addSubrepoToGitIgnore(path);
    if (0 != gitignoreAddResult) {
        return gitignoreAddResult;
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfig];
    const int configSaveResult = [updatedConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    return 0;
}

static int addSubrepoToGitIgnore(NSString *subrepoPath) {
    static NSString *gitIgnoreFileName = @".gitignore";

    NSString *lineToAppend = [subrepoPath stringByAppendingString:@"\n"];

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:gitIgnoreFileName isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:gitIgnoreFileName
                   contents:nil
                   attributes:nil])
        {
            fprintf(stderr, "failed to create .gitignore file\n");
            return 1;
        }
    }

    if (isDirectory) {
        fprintf(stderr, ".gitignore is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:gitIgnoreFileName encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        fprintf(stderr, "failed to read contents of .gitignore file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 3;
    }

    if (newContent.length > 0 && NO == [newContent hasSuffix:@"\n"]) {
        [newContent appendString:@"\n"];
    }

    [newContent appendString:lineToAppend];

    if (NO == [newContent writeToFile:gitIgnoreFileName atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        fprintf(stderr, "failed to write contents of .gitignore file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

@end
