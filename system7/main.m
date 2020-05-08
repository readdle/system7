//
//  main.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 24.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "S7Parser.h"
#import "Git.h"
#import "Utils.h"
#import "S7Types.h"
#import "S7AddCommand.h"
#import "S7RebindCommand.h"
#import "S7PushCommand.h"

// why separate command? what alternatives I considered?
// 1. no bash scripts – bash script for such tasks is always a big pain in the ass
// 2. no python – I could have written in python, but I just know C better
// 3. I looked for some plugins system in git – didn't find one
// 3. considered forking git itself. First, I had pre-vomit hiccups at the very thought about it.
//    Second, two many GUIs I know are bunding their own version of git, so my fork will be useless.
// 4. thus I stopped at separate command + few git hooks
//
// I was thinking of the way to do all subrepos managing stuff almost automatically as it's done
// in HG.
// I can automate pull and checkout. I can* automate clone. (*with the use of ugly --template hack or global templates).
// But I see no way to intrude into commit process. HG updates subrepos automatically if one performs `hg commit` without
// specifying particular paths. The only thing like that in git is `git commit -a`. There's `pre-commit` hook,
// and maybe I could detect '-a', but hook documentation is as crappy as the whole git (and its documentation).
// For now, I think that we will start with manual rebind of subrepos and commit of .s7substate as any other file.
//
// We use s7 for de-facto centralized commercial repo that uses single (GitHub) server and branch-based
// pull requests. We are not using forks, we are not using other kinds of remotes except origin.
// Thus: s7 always assumes that there's just one remote and it's named 'origin'
//
// Second assumption: we do not play the game of naming local branches differently from remote branches,
// so s7 always assumes that `origin/branch-name` is tracked by local branch `branch-name`


// need a pre-commit hook that will change .s7substate. Or should I? Maybe just `s7 commit [paths]`

// s7 status
// s7 commit PATH – update subrepo binding
// s7 checkout – runs automatically from `post-checkout` git hook
// s7 push

// post-checkout
// pre-merge-commit
// pre-push
//
//
// как автоматом обновить .gitsubstate ? как намекнуть пользователю, что у него поменяны сабрепы?
//
//
// Сценарии:
//

// git clone rd2
// result empty rd2 + .s7config
// s7 checkout
// ============
// s7 clone url
// ============
// (global one time) s7 install – installs global git templates
// git clone url (s7 update – automatically)

// 1. надо склонить проект со всеми сабрепами (это делается только хаками через https://git-scm.com/docs/git-init#_template_directory
//    либо делать руками – s7 checkout)
// 1* clone recursively
//
// 2. пописал что-то в ПДФ-ките. Надо обновить RD2 на новую ревизию
//  s7 status – pdfkit updated
//  s7 "commit" – changes revision in .s7substate
//  git add .s7substate
//  git commit -m"up pdf kit"

// hg commit if subrepo has changes – fails telling "uncommited changes in SUBREPO ..."
// do the same for us
// do not allow push if there're changes in subrepos

// 3. кто-то пописал, что-то в ПДФ-ките и поднял ревизию, а я просто обновился на последние кода
//     git pull (post-checkout hook calls 's7 update')
//     s7 update
//
// 4. я пописал что-то в ПДФ-ките, поднял ревизию. Оказалось, что кто-то тоже параллельно обновил кит. Надо смержиться
//     rd2# git pull (pre-merge-commit hook calls 's7 merge')
//     or s7 merge manually
//
//  add merge-tool for .s7substate
//
// 5. вторая вариация на ту же тему. Мержу релизную ветку в мастер. У нас разные ревизии кита.
// 6. в PEM хочу подтянуть последний кит
// 7. кто-то обновил в ките сабрепу (flounder), и обновил кит в rd2. Мне просто обновиться в rd2. Recursive stuff
//
// 8. я что-то поменял в ките, и в rd2 – хочу посмотреть диф. Nice to have
// 9. я что-то поменял в ките, и в rd2 – хочу сделать коммит. Nice to have
// 10. я что-то поменял в ките, и в rd2 – хочу сделать пуш
// 11. все это дело должно работать на Jenkins-е без всяких шаманств

// validate config – check that there're no duplicates

// Транзакции
// Последняя ревизия в файле на случай работы из command line?

// пройти по всем exit кодам, и перейти на S7ExitCode

// verbose/quite modes?

// rebind – remap, record?

// allow short forms "status" - "st", "stat", etc.
// allow aliases

// always standartize subrepo paths

// color output if istty()
// checking subrepo 'Dependencies/ReaddleLib'
//  detected an update:
//  old state 'a8ce1d5234908ee65f59c831a803c83893920c2f' (master) - red
//  new state 'f1e7add16515f003ed756324f91c66b699a5a48c' (master) - green


// push – возможно заюзать хак с diff-stat, чтобы не мотаться на сервер для каждой сабрепы.
//        либо сделать на своих файлах, но это стремно. Можно сотворить неконсистентность на ровном месте
// push – подвязаться на pre-push хук. Без параметров пычкать только текущую ветку.

// думаю, что можно сделать чтобы s7 add сразу стейджил .s7substate и .gitignore
// как минимум, надо писать в stdout подсказку что делать дальше

// думаю, что можно сделать чтобы s7 rebind сразу стейджил .s7substate
// как минимум, надо писать в stdout подсказку что делать дальше
// у git commit есть ключ -a, но не хочу использовать его, т.к. он может проассоциироваться с --all
// лучше пусть будет --stage

// todo: make all commands recursive: rebind, push, checkout, status, etc.?

// make `s7 init` install hooks?

// add --recursive/-R option to rebind? Would be handy if you want to commit subrepo with subrepos. Seems to be a rare
// case – not adding now
// but `s7 commit` sounds like a good stuff – commit both main repo and subrepos. Should think about it.

// add custom merge-tool for .s7config file, so that git would call `s7 merge` if this file needs merging

// use libgit2 if git process run overhead starts to bother us

void printHelp() {
    puts("usage: s7 <command> [<arguments>]");
    puts("\nAvailable commands:");
    puts("");
    puts("  help      show help for a given command or this a help overview");
    puts("");
    puts("  init      create all necessary config files in the git repo");
    puts("");
    puts("  add       add a new subrepo");
    puts("  remove    removes a subrepo(s)");
    puts("");
    puts("  rebind    save a new revision/branch of a subrepo(s) to .s7substate");
    puts("  push      push changes from the repo and all it's subrepos");
    puts("");
    puts("  checkout  update subrepos to the state saved in a checked out revision");
    puts("  merge     incorporate changes to subrepos from two revisions");
}

NSObject<S7Command> *commandByName(NSString *commandName) {
    static NSMutableDictionary<NSString *, NSObject<S7Command> *> *commandNameToCommandMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        commandNameToCommandMap = [NSMutableDictionary new];

        commandNameToCommandMap[@"add"] = [S7AddCommand new];
        commandNameToCommandMap[@"rebind"] = [S7RebindCommand new];
        commandNameToCommandMap[@"push"] = [S7PushCommand new];
    });

    return commandNameToCommandMap[commandName];
}

int helpCommand(int argc, const char *argv[]) {
    if (argc < 1) {
        printHelp();
        return 0;
    }

    NSString *commandName = [NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding];
    NSObject<S7Command> *command = commandByName(commandName);
    if (command) {
        [command printCommandHelp];
    }
    else {
        fprintf(stderr, "unknown command '%s'\n", [commandName cStringUsingEncoding:NSUTF8StringEncoding]);
        printHelp();
    }

    return 0;
}

int main(int argc, const char * argv[]) {
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:[cwd stringByAppendingPathComponent:@".git"] isDirectory:&isDirectory] || NO == isDirectory) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if (argc < 2) {
        printHelp();
        return 1;
    }

    NSString *commandName = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    NSObject<S7Command> *command = commandByName(commandName);
    if (command) {
        NSMutableArray<NSString *> *arguments = [[NSMutableArray alloc] initWithCapacity:argc - 2];
        for (int i=2; i<argc; ++i) {
            NSString *argument = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
            [arguments addObject:argument];
        }

        return [command runWithArguments:arguments];
    }
    else if ([commandName isEqualToString:@"help"]) {
        return helpCommand(argc - 2, argv + 2);
    }
    else {
        fprintf(stderr, "error: unknown command '%s'\n", [commandName cStringUsingEncoding:NSUTF8StringEncoding]);
        printHelp();
        return 1;
    }
}
