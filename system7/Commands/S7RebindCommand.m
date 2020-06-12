//
//  S7RebindCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7RebindCommand.h"
#import "S7Config.h"
#import "Git.h"

@implementation S7RebindCommand

+ (NSString *)commandName {
    return @"rebind";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"record" ];
}

+ (void)printCommandHelp {
    puts("s7 rebind [--stage] [PATH]...");
    printCommandAliases(self);
    puts("");
    puts("TODO");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];
    if (nil == parsedConfig) {
        return S7ExitCodeFailedToParseConfig;
    }

    BOOL stageConfig = NO;

    NSMutableSet<NSString *> *subreposToRebindPaths = [NSMutableSet new];
    if (arguments.count > 0) {
        for (NSString *argument in arguments) {
            if ([argument isEqualToString:@"--stage"]) {
                stageConfig = YES;
                continue;
            }

            NSString *path = [argument stringByStandardizingPath];

            if (NO == [parsedConfig.subrepoPathsSet containsObject:path]) {
                fprintf(stderr,
                        "there's no registered subrepo at path '%s'\n"
                        "maybe you wanted to use 'add'?\n",
                        [argument fileSystemRepresentation]);
                return S7ExitCodeInvalidArgument;
            }

            [subreposToRebindPaths addObject:path];
        }
    }

    if (0 == subreposToRebindPaths.count) {
        subreposToRebindPaths = [parsedConfig.subrepoPathsSet mutableCopy];
    }

    NSMutableArray<S7SubrepoDescription *> *newConfigSubrepoDescriptions = [[NSMutableArray alloc] initWithCapacity:parsedConfig.subrepoDescriptions.count];

    NSMutableArray<NSString *> *reboundSubrepoPaths = [NSMutableArray arrayWithCapacity:subreposToRebindPaths.count];

    for (S7SubrepoDescription *subrepoDescription in parsedConfig.subrepoDescriptions) {
        NSString *const subrepoPath = subrepoDescription.path;

        if (NO == [subreposToRebindPaths containsObject:subrepoPath]) {
            [newConfigSubrepoDescriptions addObject:subrepoDescription];
            continue;
        }

        fprintf(stdout, "checking subrepo '%s'... ", [subrepoPath fileSystemRepresentation]);

        GitRepository *gitSubrepo = [[GitRepository alloc] initWithRepoPath:subrepoPath];
        if (nil == gitSubrepo) {
            NSAssert(gitSubrepo, @"");
            return S7ExitCodeSubrepoIsNotGitRepository;
        }

        NSString *revision = nil;
        if (0 != [gitSubrepo getCurrentRevision:&revision]) {
            return S7ExitCodeGitOperationFailed;
        }

        NSString *branch = nil;
        if (0 != [gitSubrepo getCurrentBranch:&branch]) {
            return S7ExitCodeGitOperationFailed;
        }

        if (nil == branch) {
            fprintf(stderr,
                    " ⚠️ '%s' is in 'detached HEAD' state\n"
                    "     1. you won't be able to push changes in this repo.\n"
                    "        (at least using s7)\n"
                    "     2. even if you do push, as the courtesy to fellow developers,\n"
                    "        s7 won't allow you to rebind subrepo with the detached HEAD\n"
                    "        as this will cause too much trouble to others\n\n"
                    "     So, please, checkout a named branch in this subrepo.\n",
                    [subrepoPath fileSystemRepresentation]);
            return S7ExitCodeDetachedHEAD;
        }

        S7SubrepoDescription *updatedSubrepoDescription = [[S7SubrepoDescription alloc]
                                                           initWithPath:subrepoPath
                                                           url:subrepoDescription.url
                                                           revision:revision
                                                           branch:branch];

        if ([updatedSubrepoDescription isEqual:subrepoDescription]) {
            fprintf(stdout, "up to date.\n");
            [newConfigSubrepoDescriptions addObject:subrepoDescription];
            continue;
        }

        fprintf(stdout, "detected an update:\n");
        fprintf(stdout, " old state %s\n", [subrepoDescription.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);
        fprintf(stdout, " new state %s\n", [updatedSubrepoDescription.humanReadableRevisionAndBranchState cStringUsingEncoding:NSUTF8StringEncoding]);

        [reboundSubrepoPaths addObject:updatedSubrepoDescription.path];
        [newConfigSubrepoDescriptions addObject:updatedSubrepoDescription];
    }

    if ([newConfigSubrepoDescriptions isEqual:parsedConfig.subrepoDescriptions]) {
        fprintf(stdout,
                "(seems like there's nothing to rebind)\n");
        return S7ExitCodeSuccess;
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfigSubrepoDescriptions];
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
        if (0 != [repo add:@[ S7ConfigFileName ]]) {
            return S7ExitCodeGitOperationFailed;
        }
    }
    else {
        fprintf(stdout, "\nrebound the following subrepos:\n");
        for (NSString *path in reboundSubrepoPaths) {
            fprintf(stdout, " %s\n", path.fileSystemRepresentation);
        }
        fprintf(stdout,
                "\nplease, don't forget to commit the %s\n",
                S7ConfigFileName.fileSystemRepresentation);
    }

    return S7ExitCodeSuccess;
}

@end
