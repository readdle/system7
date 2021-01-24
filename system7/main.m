//
//  main.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "S7Types.h"

#import "S7InitCommand.h"
#import "S7DeinitCommand.h"
#import "S7AddCommand.h"
#import "S7RemoveCommand.h"
#import "S7RebindCommand.h"
#import "S7StatusCommand.h"
#import "S7ResetCommand.h"
#import "S7CheckoutCommand.h"
#import "S7BootstrapCommand.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"
#import "S7PostCommitHook.h"
#import "S7PostMergeHook.h"
#import "S7PrepareCommitMsgHook.h"

#import "S7ConfigMergeDriver.h"

#import "HelpPager.h"

void printHelp() {
    help_puts("");
    help_puts("\033[1mSYNOPSIS\033[0m");
    help_puts("");
    help_puts("  \033[4ms7\033[0m <command> [<arguments>]");
    help_puts("");
    help_puts("\033[1mAVAILABLE COMMANDS\033[0m");
    help_puts("");
    help_puts("  help      show help for a given command or this a overview");
    help_puts("");
    help_puts("  init      create all necessary config files/hooks in the git repo");
    help_puts("  deinit    removes all traces of s7 from the repo");
    help_puts("");
    help_puts("  add       add a new subrepository");
    help_puts("");
    help_puts("  remove    remove the specified subrepos");
    help_puts("");
    help_puts("  rebind    save a new revision/branch of a subrepo(s) to .s7substate");
    help_puts("");
    help_puts("  checkout  update subrepos to correspond to the state saved in .s7substate");
    help_puts("");
    help_puts("  reset     reset subrepo(s) to the last committed state from .s7substate");
    help_puts("");
    help_puts("  status    show changed subrepos");
    help_puts("");
    help_puts("\033[1mFAQ\033[0m");
    help_puts("");
    help_puts(" Q: how to push changes to subrepos together with the main repo?");
    help_puts(" A: just `git push [OPTIONS]` on the main repo. S7 git-hooks will push");
    help_puts("    necessary subrepos automatically.");
    help_puts("");
    help_puts(" Q: how to checkout subrepos after I pull or checkout a different");
    help_puts("    branch/revision?");
    help_puts(" A: just `git pull`/`git checkout` as you normally do.");
    help_puts("    S7 git-hooks will update subrepos as necessary.");
    help_puts("");
    help_puts(" Q: I ran `git reset` or `git stash` and now s7 complains that it's");
    help_puts("    not in sync.");
    help_puts(" A: git doesn't run any hooks for these commands, so you would have");
    help_puts("    to update subrepos using `s7 checkout` (see `s7 help checkout`");
    help_puts("    for more info).");
    help_puts("");
    help_puts("\033[1mENVIRONMENT VARIABLES\033[0m");
    help_puts("");
    help_puts(" S7_TRACE_GIT");
    help_puts("    Enables trace of git commands that s7 invokes. If the variable is set to");
    help_puts("    positive integer, s7 will log each git command, it's stdout and stderr");
    help_puts("    output (if any), and git return code.");
}

Class commandClassByName(NSString *commandName) {
    static NSMutableDictionary<NSString *, Class> *commandNameToCommandClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        commandNameToCommandClass = [NSMutableDictionary new];

        NSSet<Class<S7Command>> *commandClasses = [NSSet setWithArray:@[
            [S7InitCommand class],
            [S7DeinitCommand class],
            [S7AddCommand class],
            [S7RemoveCommand class],
            [S7RebindCommand class],
            [S7StatusCommand class],
            [S7ResetCommand class],
            [S7CheckoutCommand class],
            [S7BootstrapCommand class]
        ]];

        for (Class<S7Command> commandClass in commandClasses) {
            NSString *commandName = [commandClass commandName];
            NSCAssert(nil == commandNameToCommandClass[commandName], @"duplicate name?");

            commandNameToCommandClass[commandName] = commandClass;

            for (NSString *alias in [commandClass aliases]) {
                NSCAssert(nil == commandNameToCommandClass[alias], @"duplicate name?");

                commandNameToCommandClass[alias] = commandClass;
            }
        }
    });

    Class exactMatchClass = commandNameToCommandClass[commandName];
    if (exactMatchClass) {
        return exactMatchClass;
    }

    NSMutableSet<NSString *> *possibleCommandNames = [NSMutableSet new];
    NSMutableSet<Class<S7Command>> *possibleCommandClasses = [NSMutableSet new];
    for (NSString *knownCommandName in commandNameToCommandClass.allKeys) {
        if ([knownCommandName hasPrefix:commandName]) {
            Class<S7Command> knownCommandClass = commandNameToCommandClass[knownCommandName];
            [possibleCommandClasses addObject:knownCommandClass];
            [possibleCommandNames addObject:[knownCommandClass commandName]];
        }
    }

    if (0 == possibleCommandClasses.count) {
        fprintf(stderr, "unknown command '%s'\n", [commandName cStringUsingEncoding:NSUTF8StringEncoding]);
        return nil;
    }
    else if (1 == possibleCommandClasses.count) {
        return possibleCommandClasses.anyObject;
    }
    else {
        NSString *possibleCommands = [[possibleCommandNames allObjects] componentsJoinedByString:@", "];

        fprintf(stderr, "s7: command '%s' is ambiguous:\n", [commandName cStringUsingEncoding:NSUTF8StringEncoding]);
        fprintf(stderr, "    %s\n", possibleCommands.fileSystemRepresentation);
        return nil;
    }
}

Class hookClassByName(NSString *hookName) {
    static NSMutableDictionary<NSString *, Class> *gitHookNameToClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gitHookNameToClass = [NSMutableDictionary new];

        NSSet<Class<S7Hook>> *hookClasses = [NSSet setWithArray:@[
            [S7PrePushHook class],
            [S7PostCheckoutHook class],
            [S7PostCommitHook class],
            [S7PostMergeHook class],
            [S7PrepareCommitMsgHook class],
        ]];

        for (Class<S7Hook> hookClass in hookClasses) {
            NSString *gitHookName = [hookClass gitHookName];
            NSCAssert(nil == gitHookNameToClass[gitHookName], @"duplicate name?");

            gitHookNameToClass[gitHookName] = hookClass;
        }
    });

    return gitHookNameToClass[hookName];
}

int helpCommand(NSArray<NSString *> *arguments) {
    return withHelpPaginationDo(^int {
        if (arguments.count < 1) {
            printHelp();
            return 0;
        }
        
        NSString *commandName = arguments.firstObject;
        Class<S7Command> commandClass = commandClassByName(commandName);
        if (commandClass) {
            [commandClass printCommandHelp];
            return 0;
        }
        else {
            printHelp();
            return 1;
        }
    });
}

int main(int argc, const char * argv[]) {
    // Turn off stdout buffering to make sure that the order of output corresponds to the logic we have in code.
    // stderr is not buffered by default. If we don't flush stdout after each fprintf,
    // then in case of error, we get a confusing output in terminal. For example:
    //
    //   checking out subrepo X
    //   blah-blah
    //   error: blah-blah
    //   blah-blah
    //   checking out subrepo Y
    //
    // instead of expected:
    //
    //   checking out subrepo X
    //   blah-blah
    //   checking out subrepo Y
    //   error: blah-blah
    //   blah-blah
    //
    setbuf(stdout, NULL);

    if (argc < 2) {
        helpCommand(@[]);
        return S7ExitCodeUnknownCommand;
    }

    NSString *commandName = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];

    NSMutableArray<NSString *> *arguments = [[NSMutableArray alloc] initWithCapacity:argc - 2];
    for (int i=2; i<argc; ++i) {
        NSString *argument = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
        [arguments addObject:argument];
    }

    if ([commandName isEqualToString:@"help"]) {
        return helpCommand(arguments);
    }

    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:[cwd stringByAppendingPathComponent:@".git"] isDirectory:&isDirectory] || NO == isDirectory) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if ([commandName hasSuffix:@"-hook"]) {
        commandName = [commandName stringByReplacingOccurrencesOfString:@"-hook" withString:@""];
        Class<S7Hook> hookClass = hookClassByName(commandName);
        if (nil == hookClass) {
            fprintf(stderr, "unknown hook '%s'\n", [commandName cStringUsingEncoding:NSUTF8StringEncoding]);
            NSCAssert(NO, @"unknown hook");
            return S7ExitCodeUnknownCommand;
        }

        NSObject<S7Hook> *hook = [[[hookClass class] alloc] init];
        return [hook runWithArguments:arguments];
    }
    else if ([commandName isEqualToString:@"merge-driver"]) {
        S7ConfigMergeDriver *configMergeDriver = [S7ConfigMergeDriver new];
        return [configMergeDriver runWithArguments:arguments];
    }
    else {
        Class<S7Command> commandClass = commandClassByName(commandName);
        if (commandClass) {
            NSObject<S7Command> *command = [[[commandClass class] alloc] init];
            return [command runWithArguments:arguments];
        }
        else {
            return S7ExitCodeUnknownCommand;
        }
    }
}
