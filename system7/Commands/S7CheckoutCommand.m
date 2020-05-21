//
//  S7CheckoutCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 30.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7CheckoutCommand.h"

#import "S7Diff.h"

@interface S7CheckoutCommand ()

@property (nonatomic, assign) BOOL clean;

@end

@implementation S7CheckoutCommand

+ (NSString *)commandName {
    return @"checkout";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"co", @"update" ];
}

+ (void)printCommandHelp {
    puts("s7 checkout [-C] FROM_REV TO_REV");
    printCommandAliases(self);
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

    NSString *fromRevision = nil;
    NSString *toRevision = nil;

    for (NSString *argument in arguments) {
        if ([argument hasPrefix:@"-"]) {
            if ([argument isEqualToString:@"-C"] || [argument isEqualToString:@"-clean"]) {
                self.clean = YES;
            }
            else {
                fprintf(stderr,
                        "option %s not recognized\n", [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeUnrecognizedOption;
            }
        }
        else {
            if (nil == fromRevision) {
                fromRevision = argument;
            }
            else if (nil == toRevision) {
                toRevision = argument;
            }
            else {
                fprintf(stderr,
                        "redundant argument %s\n",
                        [argument cStringUsingEncoding:NSUTF8StringEncoding]);
                [[self class] printCommandHelp];
                return S7ExitCodeInvalidArgument;
            }
        }
    }

    if (nil == fromRevision) {
        fprintf(stderr,
                "required argument FROM_REV is missing\n");
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    if (nil == toRevision) {
        fprintf(stderr,
                "required argument TO_REV is missing\n");
        [[self class] printCommandHelp];
        return S7ExitCodeMissingRequiredArgument;
    }

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7 must be run in the root of a git repo.\n");
        return S7ExitCodeNotGitRepository;
    }

    if (NO == [repo isRevisionAvailableLocally:fromRevision] && NO == [fromRevision isEqualToString:[GitRepository nullRevision]]) {
        fprintf(stderr,
                "FROM_REV %s is not available in this repository\n",
                [fromRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
    }

    if (NO == [repo isRevisionAvailableLocally:toRevision]) {
        fprintf(stderr,
                "TO_REV %s is not available in this repository\n",
                [toRevision cStringUsingEncoding:NSUTF8StringEncoding]);
        return S7ExitCodeInvalidArgument;
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
    //  ...
    //    если человек проебался, и вызвал эту команду, когда у него есть более новые коммиты
    //    на этой ветке в сабрепе, надо думать. Я не могу скинуть его ветку с текущей ревизии,
    //    т.к. тогда его коммиты "проебутся" (уйдут в detached head).
    //    Могу вытянуть чисто ревизию, и предупредить, что твоя ветка осталась там, но она
    //    разошлась с origin-ом
    //
    //   go into subrepo subrepos

    return [self checkoutSubreposForRepo:repo fromRevision:fromRevision toRevision:toRevision];
}

- (int)checkoutSubreposForRepo:(GitRepository *)repo
                  fromRevision:(NSString *)fromRevision
                    toRevision:(NSString *)toRevision
{
    int showExitStatus = 0;
    NSString *fromConfigContents = [repo showFile:S7ConfigFileName atRevision:fromRevision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed? Or we are back to revision where there was no s7 yet
            fromConfigContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [fromRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    NSString *toConfigContents = [repo showFile:S7ConfigFileName atRevision:toRevision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed? Or we are back to revision where there was no s7 yet
            toConfigContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [toRevision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    S7Config *fromConfig = [[S7Config alloc] initWithContentsString:fromConfigContents];
    S7Config *toConfig = [[S7Config alloc] initWithContentsString:toConfigContents];

    const int checkoutExitStatus = [self checkoutSubreposForRepo:repo fromConfig:fromConfig toConfig:toConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    if (0 != [toConfig saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);

        return S7ExitCodeFileOperationFailed;
    }

    return 0;
}

- (int)checkoutSubreposForRepo:(GitRepository *)repo
                    fromConfig:(S7Config *)fromConfig
                      toConfig:(S7Config *)toConfig
{
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = nil;
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = nil;
    NSDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = nil;
    diffConfigs(fromConfig,
                toConfig,
                &subreposToDelete,
                &subreposToUpdate,
                &subreposToAdd);

    for (S7SubrepoDescription *subrepoToDelete in subreposToDelete.allValues) {
        NSString *subrepoPath = subrepoToDelete.path;
        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:subrepoPath isDirectory:&isDirectory] && isDirectory) {
            fprintf(stdout, "removing subrepo '%s'", subrepoPath.fileSystemRepresentation);

            NSError *error = nil;
            if (NO == [NSFileManager.defaultManager removeItemAtPath:subrepoPath error:&error]) {
                fprintf(stderr,
                        "abort: failed to remove subrepo '%s' directory\n"
                        "error: %s\n",
                        [subrepoPath fileSystemRepresentation],
                        [error.description cStringUsingEncoding:NSUTF8StringEncoding]);
                return S7ExitCodeFileOperationFailed;
            }
        }
    }

    for (S7SubrepoDescription *subrepoDesc in toConfig.subrepoDescriptions) {
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

        if (NO == [subrepoGit isRevisionAvailableLocally:subrepoDesc.revision]) {
            fprintf(stdout,
                    "fetching '%s'\n",
                    [subrepoDesc.path fileSystemRepresentation]);

            if (0 != [subrepoGit fetch]) {
                return S7ExitCodeGitOperationFailed;
            }
        }

        if (NO == [subrepoGit isRevisionAvailableLocally:subrepoDesc.revision]) {
            fprintf(stderr,
                    "revision '%s' does not exist in '%s'\n",
                    [subrepoDesc.revision cStringUsingEncoding:NSUTF8StringEncoding],
                    [subrepoDesc.path fileSystemRepresentation]);

            return S7ExitCodeInvalidSubrepoRevision;
        }

        if (0 != [subrepoGit checkoutRemoteTrackingBranch:subrepoDesc.branch]) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        NSString *currentBranchHeadRevision = nil;
        if (0 != [subrepoGit getCurrentRevision:&currentBranchHeadRevision]) {
            // todo: log
            return S7ExitCodeGitOperationFailed;
        }

        if (NO == [subrepoDesc.revision isEqualToString:currentBranchHeadRevision]) {
            // todo: nil branch is not possible any more, but we are 'loosing' branch HEAD here
            // add safety here
//            if (nil == subrepoDesc.branch) {
//                fprintf(stdout,
//                        "checking out detached HEAD in subrepository '%s'\n",
//                        [subrepoDesc.path fileSystemRepresentation]);
//
//                fprintf(stdout,
//                        "check out a git branch if you intend to make changes\n");
//            }

            // I really hope that `reset` is always a good way to checkout a revision considering we are already
            // at the right branch.
            // I'm a bit confused, cause, for example, HG does `merge --ff` if we are going up, but their logic
            // is a bit different, so nevermind.
            // Life will show if I am right.
            //
            // Found an alternative – `git checkout -B branch revision`
            //
            [subrepoGit resetToRevision:subrepoDesc.revision];
        }
    }

    return 0;
}

@end
