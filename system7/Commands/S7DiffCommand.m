//
//  S7DiffCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.07.2022.
//  Copyright © 2022 Readdle. All rights reserved.
//

#import "S7DiffCommand.h"

#import "S7StatusCommand.h"

#import "Utils.h"
#import "HelpPager.h"

@implementation S7DiffCommand

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (NSString *)commandName {
    return @"diff";
}

+ (void)printCommandHelp {
    help_puts("s7 diff [GIT_DIFF_ARGUMENTS]");
    printCommandAliases(self);
    help_puts("");
    help_puts("runs `git diff [arguments]` on main repo and all subrepos recursively");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    BOOL userControlsColor = NO;
    for (NSString *argument in arguments) {
        if ([argument isEqualToString:@"--color"] ||
            [argument isEqualToString:@"--no-color"] ||
            [argument hasPrefix:@"--color="])
        {
            userControlsColor = YES;
        }
    }

    if (NO == userControlsColor) {
        arguments = [arguments arrayByAddingObject:@"--color=always"];
    }

    return [self.class runGitDiffOnRepo:repo
                               repoName:@"main repo"
       parentRepoPathRelativeToMainRepo:@""
                          withArguments:arguments];
}

+ (int)runGitDiffOnRepo:(GitRepository *)repo
               repoName:(NSString *)repoName
parentRepoPathRelativeToMainRepo:(NSString *)parentRepoPathRelativeToMainRepo
          withArguments:(NSArray<NSString *> *)arguments
{
    NSString *stdOutOutput = nil;
    int exitCode = [repo diff:arguments stdOutOutput:&stdOutOutput];
    if (stdOutOutput.length > 0) {
        fprintf(stdout, "\033[34m>\033[0m %s:\n", repoName.fileSystemRepresentation);
        fprintf(stdout, "%s\n\n\n", [stdOutOutput cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    S7Config *s7config = nil;

    NSString *s7ConfigPath = [repo.absolutePath stringByAppendingPathComponent:S7ConfigFileName];
    if ([NSFileManager.defaultManager fileExistsAtPath:s7ConfigPath]) {
        s7config = [[S7Config alloc] initWithContentsOfFile:s7ConfigPath];

        for (S7SubrepoDescription *subrepoDesc in s7config.subrepoDescriptions) {
            NSString *relativeSubrepoPath = subrepoDesc.path;

            NSString *absoluteSubrepoPath = [repo.absolutePath stringByAppendingPathComponent:relativeSubrepoPath];

            GitRepository *gitSubrepo = [[GitRepository alloc] initWithRepoPath:absoluteSubrepoPath];
            if (nil == gitSubrepo) {
                NSAssert(gitSubrepo, @"");
                return S7ExitCodeSubrepoIsNotGitRepository;
            }

            NSString *subrepoPathRelativeToMainRepo = [parentRepoPathRelativeToMainRepo stringByAppendingPathComponent:relativeSubrepoPath];
            const int subrepoDiffExitCode = [self
                                             runGitDiffOnRepo:gitSubrepo
                                             repoName:subrepoPathRelativeToMainRepo
                                             parentRepoPathRelativeToMainRepo:subrepoPathRelativeToMainRepo
                                             withArguments:arguments];
            if (S7ExitCodeSuccess != subrepoDiffExitCode) {
                exitCode = subrepoDiffExitCode;
            }
        }
    }

    return exitCode;
}

@end
