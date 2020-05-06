//
//  S7CheckoutCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7CheckoutCommand.h"

#import "S7Parser.h"
#import "Git.h"

@interface S7CheckoutCommand ()

@property (nonatomic, assign) BOOL clean;

@end

@implementation S7CheckoutCommand

- (void)printCommandHelp {
    puts("s7 checkout [-C]");
    puts("");
    puts("updates subrepos to revisions/branches saved in .s7substate");
    puts("");
    puts("options:");
    puts("");
    puts(" -C --clean    discard uncommited changes (no backup)");
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

    for (NSString *argument in arguments) {
        if ([argument isEqualToString:@"-C"] || [argument isEqualToString:@"-clean"]) {
            self.clean = YES;
        }
        else {
            fprintf(stderr,
                    "option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
            [self printCommandHelp];
            return S7ExitCodeUnrecognizedOption;
        }
    }

    // по-хорошему, надо сравнить текущий конфиг с предыдущим конфигом, и обновить все согласно дифу.
    //
    // если это вызов из `git checkout`, то у нас есть старая/новая ревизии
    //
    // если это просто вызов из CLI, то можно взять старую ревизию только если она хранится в файлике, но тут возможен
    // такой вариант – я добавил сабрепу, закоммитил, а потом понял, что это была ошибка; я откатил коммит, а файлик
    // остался лежать, и в нем невалидная ревизия 🤷‍♂️. Можно в этом случае фолбэчиться на режим без старой ревизии.
    //
    // Еще вопрос. Если пользователь добавил сабрепу, и вызвал эту команду. Если .s7substate не закоммичен, то хорошо ли
    // что я читаю из него? Если пользователь сделает `git checkout OLD_REV`, то поведение будет отличаться – мы возьмем
    // состояние .s7substate из HEAD, а не папочки.
    //
    // Из этого следует, что как минимум, эта команда должна фейлиться, если есть изм-я в репе.

    // ==> нужно сначала програнтать статус, и если хоть в какой-то сабрепе есть изм-я, то фейлиться


    // for every subrepo:
    //  abort if it has uncommitted changes (unless -C/--clean) is passed
    //  compare current revision/branch to the one from .s7substate
    //    if nothing to do – continue
    //  check if revision is available
    //    if not – git fetch
    //    check if revision is available
    //    if not – fail
    //  checkout revision/branch
    //    если человек проебался, и вызвал эту команду, когда у него есть более новые коммиты
    //    на этой ветке в сабрепе, надо думать. Я не могу скинуть его ветку с текущей ревизии,
    //    т.к. тогда его коммиты "проебутся" (уйдут в detached head).
    //    Могу вытянуть чисто ревизию, и предупредить, что твоя ветка осталась там, но она
    //    разошлась с origin-ом
    //
    //  go into subrepo subrepos

    return [self checkoutSubreposForRepoAtPath:@"."];
}

- (int)checkoutSubreposForRepoAtPath:(NSString *)repoPath {
    // todo: should I rely on the disk state or retrieve the state from git?
    S7Config *parsedConfig = [[S7Config alloc]
                              initWithContentsOfFile:[repoPath stringByAppendingPathComponent:S7ConfigFileName]];
    for (S7SubrepoDescription *subrepoDesc in parsedConfig.subrepoDescriptions) {
        GitRepository *subrepoGit = nil;

        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoDesc.path isDirectory:&isDirectory] && isDirectory) {
            subrepoGit = [[GitRepository alloc] initWithRepoPath:subrepoDesc.path];
            if (nil == subrepoGit) {
                return S7ExitCodeSubrepoIsNotGitRepository;
            }

            if ([subrepoGit hasUncommitedChanges]) {
                if (NO == self.clean) {
                    fprintf(stderr,
                            "found uncommited changes in subrepo '%s'\n"
                            "use -C/--clean option if you want to discard any changes automatically\n",
                            subrepoDesc.path.fileSystemRepresentation);
                    return S7ExitCodeUncommitedChanges;
                }
                else {
                    const int resetExitStatus = [subrepoGit resetLocalChanges];
                    if (0 != resetExitStatus) {
                        fprintf(stderr,
                                "failed to discard uncommited changes in subrepo '%s'\n",
                                subrepoDesc.path.fileSystemRepresentation);
                        return resetExitStatus;
                    }
                }
            }
        }
        else {
            fprintf(stdout,
                    "cloning subrepo '%s' from '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation],
                    [subrepoDesc.url fileSystemRepresentation]);

            int cloneExitStatus = 0;
            subrepoGit = [GitRepository
                          cloneRepoAtURL:subrepoDesc.url
                          destinationPath:subrepoDesc.path
                          exitStatus:&cloneExitStatus];
            if (nil == subrepoGit || 0 != cloneExitStatus) {
                fprintf(stderr,
                        "failed to clone subrepo '%s'\n",
                        [subrepoDesc.path fileSystemRepresentation]);
                return S7ExitCodeGitOperationFailed;
            }
        }

        NSString *currentBranch = nil;
        int gitExitStatus = [subrepoGit getCurrentBranch:&currentBranch];
        if (0 != gitExitStatus) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        NSString *currentRevision = nil;
        gitExitStatus = [subrepoGit getCurrentRevision:&currentRevision];
        if (0 != gitExitStatus) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        S7SubrepoDescription *currentSubrepoDesc = [[S7SubrepoDescription alloc]
                                                    initWithPath:subrepoDesc.path
                                                    url:subrepoDesc.url
                                                    revision:currentRevision
                                                    branch:currentBranch];
        if ([currentSubrepoDesc isEqual:subrepoDesc]) {
            continue;
        }

        if (NO == [subrepoGit isRevisionAvailable:subrepoDesc.revision]) {
            fprintf(stdout,
                    "fetching '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation]);

            if (0 != [subrepoGit fetch]) {
                return S7ExitCodeGitOperationFailed;
            }
        }

        if (NO == [subrepoGit isRevisionAvailable:subrepoDesc.revision]) {
            fprintf(stderr,
                    "revision '%s' does not exist in '%s'\n",
                    [subrepoDesc.revision cStringUsingEncoding:NSUTF8StringEncoding],
                    [subrepoDesc.path fileSystemRepresentation]);

            return S7ExitCodeInvalidSubrepoRevision;
        }

        if (subrepoDesc.branch) {
            if (0 != [subrepoGit checkoutRemoteTrackingBranch:subrepoDesc.branch remoteName:@"origin"]) {
                // todo: log
                return S7ExitCodeGitOperationFailed;
            }
        }

        NSString *currentBranchHeadRevision = nil;
        if (0 != [subrepoGit getCurrentRevision:&currentBranchHeadRevision]) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [subrepoDesc.revision isEqualToString:currentBranchHeadRevision]) {
            if (nil == subrepoDesc.branch) {
                fprintf(stdout,
                        "checking out detached HEAD in subrepository '%s'\n",
                        [subrepoDesc.path fileSystemRepresentation]);

                fprintf(stdout,
                        "check out a git branch if you intend to make changes\n");
            }

            // I really hope that `reset` is always a good way to checkout a revision considering we are already
            // at the right branch.
            // I'm a bit confused, cause, for example, HG does `merge --ff` if we are going up, but their logic
            // is a bit different, so nevermind.
            // Life will show if I was right.
            [subrepoGit resetToRevision:subrepoDesc.revision];
        }
    }

    return 0;
}

@end
