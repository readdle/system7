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
#import "S7AddCommand.h"
#import "S7RemoveCommand.h"
#import "S7RebindCommand.h"
#import "S7StatusCommand.h"
#import "S7ResetCommand.h"
#import "S7CheckoutCommand.h"

#import "S7PrePushHook.h"
#import "S7PostCheckoutHook.h"
#import "S7PostCommitHook.h"
#import "S7PostMergeHook.h"
#import "S7PrepareCommitMsgHook.h"

#import "S7ConfigMergeDriver.h"

// Why separate command? What alternatives did I consider?
// 0. — git submodules – also known as sobmodules – sadly well known piece of crap
//    — git-subtree and git-subrepo – both seemed promissing until I found out
//      that both save subrepo's history in... parent (!) repo. What do they drink?
// 1. no bash scripts – bash script for such tasks is always a big pain in the ass
// 2. no python – I could have written in python, but I just know C better
// 3. I looked for some plugin system in git – didn't find one
// 4. considered forking git itself. First, I had pre-vomit hiccups at the very thought about it.
//    Second, too many GUIs I know, are bunding their own version of git, so my fork will be useless.
// 5. thus I stopped at separate command + few git hooks
//
// I was thinking of the way to do all subrepos managing stuff almost automatic as it's done
// in HG.
// I can automate pull and checkout. I can* automate clone. (*with the use of ugly --template hack or global templates).
// But I see no way to intrude into commit process. HG updates subrepos automatically if one performs `hg commit` without
// specifying particular paths. The only thing like that in git is `git commit -a`. There's `pre-commit` hook,
// and maybe I could detect '-a', but hook documentation is as crappy as the whole git (and its documentation).
// For now, I think that we will start with manual rebind of subrepos and commit of .s7substate as any other file.
//
// We use s7 for de-facto centralized commercial repos that use single (GitHub) server and branch-based
// pull requests. We are not using forks, we are not using other kinds of remotes except 'origin'.
// Thus: s7 always assumes that there's just one remote and it's named 'origin'
//
// Second assumption: we do not play the game of naming local branches differently from remote branches,
// so s7 always assumes that `origin/branch-name` is tracked by local branch `branch-name`
//
// Third assumption: there's such thing as octopus merge (one can merge more than two heads at a time).
// I haven't found a way to detect and prohibit this stuff.
// Custom merge driver isn't called in case of octopus (did I say I strongly hate git?);
// All merge hooks can be bypassed with --no-verify, so I don't rely on them;
// The only option was pre-commit hook, but I think you know the result.
// One more note on octopus – I tried to merge two branches into master. Two of three brances changed
// the same file (.s7substate in my experiment, but I think it doesn't really matter) – octopus strategy
// failed and fell back to the default merge of... I don't know what – the result was like I didn't merge
// anything, but the file had a conflict :joy:
// The result looked like this:
//    * 6667738 (HEAD -> master) merge octopus (`git merge test test2`)
//    * 7ff4dca me too
//    * 7221d84 up subrepos
//    | * 4a9db5b (test2) up file (changed a different file at branch test2)
//    |/
//    | * edd53c0 (test) up subrepos
//    |/
//    * 4ebe9c8 <doesn't matter>
//    ~
//
// A note about `git reset`. This beast doesn't call any hooks, so there's no chance for s7 to update
// subrepos automatically. The only way to help user I came up with is to save a copy of .s7substate into
// not tracked file .s7control. If actual config is not equal to the one saved in .s7control, then
// we can throw a build error from our project (like cocoapods do when pods are not in sync).
// This trick is also used by the `post-checkout` hook to understand if user updated an unrelated file
// or our precious .s7substate.
//

void printHelp() {
    puts("usage: s7 <command> [<arguments>]");
    puts("");
    puts("Available commands:");
    puts("");
    puts("  help      show help for a given command or this a overview");
    puts("");
    puts("  init      create all necessary config files/hooks in the git repo");
    puts("");
    puts("  add       add a new subrepo");
    puts("  remove    remove the specified subrepos");
    puts("");
    puts("  rebind    save a new revision/branch of a subrepo(s) to .s7substate");
    puts("");
    puts("  checkout  update subrepos to correspond to the state saved in .s7substate");
    puts("  reset     reset subrepo(s) to the last committed state from .s7substate");
    puts("");
    puts("  status    show changed subrepos");
    puts("");
    puts("");
    puts("FAQ.");
    puts("");
    puts(" Q: how to push changes to subrepos together with the main repo?");
    puts(" A: just `git push [OPTIONS]` on the main repo. S7 git-hooks will push");
    puts("    necessary subrepos automatically.");
    puts("");
    puts(" Q: how to checkout subrepos after I pull or checkout a different");
    puts("    branch/revision?");
    puts(" A: just `git pull`/`git checkout` as you normally do.");
    puts("    S7 git-hooks will update subrepos as necessary.");
    puts("");
    puts(" Q: I ran `git reset` or `git stash` and now s7 complains that it's");
    puts("    not in sync.");
    puts(" A: git doesn't run any hooks for these commands, so you would have");
    puts("    to update subrepos using `s7 checkout` (see `s7 help checkout`");
    puts("    for more info).");
}

Class commandClassByName(NSString *commandName) {
    static NSMutableDictionary<NSString *, Class> *commandNameToCommandClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        commandNameToCommandClass = [NSMutableDictionary new];

        NSSet<Class<S7Command>> *commandClasses = [NSSet setWithArray:@[
            [S7InitCommand class],
            [S7AddCommand class],
            [S7RemoveCommand class],
            [S7RebindCommand class],
            [S7StatusCommand class],
            [S7ResetCommand class],
            [S7CheckoutCommand class],
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
}

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        printHelp();
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
