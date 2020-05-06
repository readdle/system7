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
    puts("s7 rebind [PATH]...");
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

    S7Config *parsedConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    NSMutableSet<NSString *> *subreposToRebindPaths = [NSMutableSet new];
    if (arguments.count > 0) {
        for (NSString *subrepoPath in arguments) {
            if (NO == [parsedConfig.subrepoPathsSet containsObject:subrepoPath]) {
                fprintf(stderr,
                        "there's no registered subrepo at path '%s'\n"
                        "maybe you wanted to use 'add'?\n",
                        [subrepoPath fileSystemRepresentation]);
                return S7ExitCodeInvalidArgument;
            }

            [subreposToRebindPaths addObject:subrepoPath];
        }
    }
    else {
        subreposToRebindPaths = [parsedConfig.subrepoPathsSet mutableCopy];
    }

    NSMutableArray<S7SubrepoDescription *> *newConfig = [[NSMutableArray alloc] initWithCapacity:parsedConfig.subrepoDescriptions.count];

    for (S7SubrepoDescription *subrepoDescription in parsedConfig.subrepoDescriptions) {
        NSString *const subrepoPath = subrepoDescription.path;

        if (NO == [subreposToRebindPaths containsObject:subrepoPath]) {
            [newConfig addObject:subrepoDescription];
            continue;
        }

        fprintf(stdout, "checking subrepo '%s'\n", [subrepoPath fileSystemRepresentation]);

        GitRepository *gitSubrepo = [[GitRepository alloc] initWithRepoPath:subrepoPath];

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
            [newConfig addObject:subrepoDescription];
            continue;
        }

        fprintf(stdout, " detected an update:\n");
        fprintf(stdout, " old state %s\n", [subrepoStateLogRepresentation(subrepoDescription) cStringUsingEncoding:NSUTF8StringEncoding]);
        fprintf(stdout, " new state %s\n", [subrepoStateLogRepresentation(updatedSubrepoDescription) cStringUsingEncoding:NSUTF8StringEncoding]);

        if (nil == branch) {
            fprintf(stdout,
                    " ⚠️ '%s' is in 'detached HEAD' state\n"
                    " (please, as the courtesy to fellow developers, consider checking out a branch in this subrepo.)\n",
                    [subrepoPath fileSystemRepresentation]);
        }

        [newConfig addObject:updatedSubrepoDescription];
    }

    S7Config *updatedConfig = [[S7Config alloc] initWithSubrepoDescriptions:newConfig];
    return [updatedConfig saveToFileAtPath:S7ConfigFileName];
}

@end
