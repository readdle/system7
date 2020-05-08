//
//  S7RebindCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7RebindCommand.h"
#import "S7Parser.h"
#import "Git.h"

@implementation S7RebindCommand

- (void)printCommandHelp {
    puts("s7 rebind [--stage] [PATH]...");
    puts("");
    puts("TODO");
}

NSString *subrepoStateLogRepresentation(S7SubrepoDescription *subrepoDescription) {
    NSString *branchDescription = @"";
    if (subrepoDescription.branch) {
        branchDescription = [NSString stringWithFormat:@" (%@)", subrepoDescription.branch];
    }
    return [NSString stringWithFormat:@"'%@'%@", subrepoDescription.revision, branchDescription];
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

    BOOL stageConfig = NO;

    NSMutableSet<NSString *> *subreposToRebindPaths = [NSMutableSet new];
    if (arguments.count > 0) {
        for (NSString *argument in arguments) {
            if ([argument isEqualToString:@"--stage"]) {
                stageConfig = YES;
                continue;
            }

            if (NO == [parsedConfig.subrepoPathsSet containsObject:argument]) {
                fprintf(stderr,
                        "there's no registered subrepo at path '%s'\n"
                        "maybe you wanted to use 'add'?\n",
                        [argument fileSystemRepresentation]);
                return S7ExitCodeInvalidArgument;
            }

            [subreposToRebindPaths addObject:argument];
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
        int gitExitStatus = [gitSubrepo getCurrentRevision:&revision];
        if (0 != gitExitStatus) {
            // todo: log
            return gitExitStatus;
        }

        NSString *branch = nil;
        gitExitStatus = [gitSubrepo getCurrentBranch:&branch];
        if (0 != gitExitStatus) {
            // todo: log
            return gitExitStatus;
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
        fprintf(stdout, " old state %s\n", [subrepoStateLogRepresentation(subrepoDescription) cStringUsingEncoding:NSUTF8StringEncoding]);
        fprintf(stdout, " new state %s\n", [subrepoStateLogRepresentation(updatedSubrepoDescription) cStringUsingEncoding:NSUTF8StringEncoding]);

        if (nil == branch) {
            fprintf(stdout,
                    " ⚠️ '%s' is in 'detached HEAD' state\n"
                    " (please, as the courtesy to fellow developers, consider checking out a branch in this subrepo.)\n",
                    [subrepoPath fileSystemRepresentation]);
        }

        [reboundSubrepoPaths addObject:updatedSubrepoDescription.path];
        [newConfigSubrepoDescriptions addObject:updatedSubrepoDescription];
    }

    if ([newConfigSubrepoDescriptions isEqual:parsedConfig.subrepoDescriptions]) {
        fprintf(stdout,
                "(seems like there's nothing to rebind)\n");
        return 0;
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfigSubrepoDescriptions];
    const int configSaveExitStatus = [updatedConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveExitStatus) {
        return configSaveExitStatus;
    }

    if (stageConfig) {
        return [repo add:@[ S7ConfigFileName ]];
    }
    else {
        fprintf(stdout, "\nrebound the following subrepos:\n");
        for (NSString *path in reboundSubrepoPaths) {
            fprintf(stdout, " %s\n", path.fileSystemRepresentation);
        }
        fprintf(stdout, "\nplease, don't forget to commit the %s\n", S7ConfigFileName.fileSystemRepresentation);
    }

    return 0;
}

@end
