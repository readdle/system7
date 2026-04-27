//
//  S7WorktreeCommand.m
//  system7
//

#import "S7WorktreeCommand.h"

#import "S7InitCommand.h"
#import "S7HelpPager.h"

@implementation S7WorktreeCommand

+ (NSString *)commandName {
    return @"worktree";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"wt" ];
}

+ (void)printCommandHelp {
    help_puts("s7 worktree add <path> [<branch>]");
    printCommandAliases(self);
    help_puts("");
    help_puts("Creates a new git worktree and initializes s7 subrepos in it.");
    help_puts("");
    help_puts("This is a convenience wrapper around:");
    help_puts("  git worktree add <path> [<branch>]");
    help_puts("  cd <path> && s7 init");
    help_puts("");
    help_puts("Subrepo clones in the new worktree automatically use the main");
    help_puts("worktree's subrepos as a reference for faster cloning.");
    help_puts("");
    help_puts("subcommands:");
    help_puts("");
    help_puts(" add <path> [<branch>]  Create a worktree and init s7 in it");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count < 2) {
        logError("usage: s7 worktree add <path> [<branch>]\n");
        return S7ExitCodeMissingRequiredArgument;
    }

    NSString *subcommand = arguments[0];
    if (NO == [subcommand isEqualToString:@"add"]) {
        logError("unknown worktree subcommand '%s'. Only 'add' is supported.\n",
                 [subcommand cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeUnknownCommand;
    }

    NSString *worktreePath = arguments[1];
    NSString *branch = (arguments.count > 2) ? arguments[2] : nil;

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    NSMutableString *gitWorktreeCmd = [NSMutableString stringWithFormat:@"git worktree add %@", worktreePath];
    if (branch.length > 0) {
        [gitWorktreeCmd appendFormat:@" %@", branch];
    }

    logInfo("running: %s\n", [gitWorktreeCmd cStringUsingEncoding:NSUTF8StringEncoding]);

    const int worktreeExitCode = system([gitWorktreeCmd cStringUsingEncoding:NSUTF8StringEncoding]);
    if (0 != worktreeExitCode) {
        logError("git worktree add failed with exit code %d\n", worktreeExitCode);
        return S7ExitCodeGitOperationFailed;
    }

    NSString *absoluteWorktreePath = worktreePath;
    if (NO == [absoluteWorktreePath hasPrefix:@"/"]) {
        absoluteWorktreePath = [[[NSFileManager defaultManager] currentDirectoryPath]
                                stringByAppendingPathComponent:worktreePath];
    }
    absoluteWorktreePath = [absoluteWorktreePath stringByStandardizingPath];

    NSString *previousDir = [[NSFileManager defaultManager] currentDirectoryPath];
    if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:absoluteWorktreePath]) {
        logError("failed to cd into '%s'\n", [absoluteWorktreePath fileSystemRepresentation]);
        return S7ExitCodeFileOperationFailed;
    }

    logInfo("\ninitializing s7 in worktree '%s'\n\n", [absoluteWorktreePath fileSystemRepresentation]);

    GitRepository *worktreeRepo = [GitRepository repoAtPath:@"."];
    if (nil == worktreeRepo) {
        [[NSFileManager defaultManager] changeCurrentDirectoryPath:previousDir];
        logError("failed to open worktree as git repo\n");
        return S7ExitCodeNotGitRepository;
    }

    S7InitCommand *initCommand = [S7InitCommand new];
    const int initExitCode = [initCommand runWithArguments:@[ @"--no-bootstrap" ] inRepo:worktreeRepo];

    [[NSFileManager defaultManager] changeCurrentDirectoryPath:previousDir];

    if (0 != initExitCode) {
        logError("s7 init failed in worktree\n");
        return initExitCode;
    }

    logInfo("\nworktree ready at '%s'\n", [absoluteWorktreePath fileSystemRepresentation]);

    return S7ExitCodeSuccess;
}

@end
