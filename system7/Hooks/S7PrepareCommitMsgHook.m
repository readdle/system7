//
//  S7PrepareCommitMsgHook.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 04.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7PrepareCommitMsgHook.h"

#import "S7PostCheckoutHook.h"
#import "S7StatusCommand.h"

// You may wonder why don't I use `pre-merge-commit`. The answer is –
// this crap "can be bypassed with the --no-verify option". This is for
// starters.
// Then "if the merge cannot be carried out automatically,
// the conflicts need to be resolved and the result committed separately
// ... this hook will not be executed, but the pre-commit hook will,
// if it is enabled.".
// So we come to `pre-commit` hook, you might think. But no, `pre-commit`
// hook "can be bypassed with the --no-verify option."
//
// Git – full of small pleasures 🤷‍♂️
//

@implementation S7PrepareCommitMsgHook

+ (NSString *)gitHookName {
    return @"prepare-commit-msg";
}

+ (NSString *)hookFileContents {
    return hookFileContentsForHookNamed([self gitHookName]);
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    fprintf(stdout, "s7: prepare-commit-msg hook start\n");
    const int result = [self doRunWithArguments:arguments];
    fprintf(stdout, "s7: prepare-commit-msg hook complete\n");
    return result;
}

- (int)doRunWithArguments:(NSArray<NSString *> *)arguments {
    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        fprintf(stderr, "s7: hook – ran in not git repo root!\n");
        return S7ExitCodeNotGitRepository;
    }

    if (NO == isCurrentDirectoryS7RepoRoot()) {
        fprintf(stdout, " doing nothing, no s7 at this branch.\n");
        return 0;
    }

    const char *GIT_REFLOG_ACTION = getenv("GIT_REFLOG_ACTION");
    if (GIT_REFLOG_ACTION &&
        (0 == strcmp(GIT_REFLOG_ACTION, "revert") ||
         0 == strcmp(GIT_REFLOG_ACTION, "cherry-pick")))
    {
        //
        // `git revert` seems to revert changes in the working dir and then "merge" them in.
        //
        // Depending on '--no-edit' option I observe different behaviour:
        //  - with '--no-edit'    : "message" argument. 'post-commit' hook NOT called.
        //  - without '--no-edit' : "merge" argument. 'post-commit' hook is called
        //                          (but the commit is not a merge commit actually).
        //
        // Taking this all into account, the only place where we can handle `git revert` properly,
        // is here. I see no other way, but blindly checkout from .s7control to .s7substate.
        // There is a risk that user did `git reset` before this, and .s7control points to
        // some crap, but what can I do?
        //
        //
        // `git cherry-pick`. This is the only hook it calls. No `post-commit`. Depending on
        // the commit beeing picked, it _sometimes_ calls merge-driver. So, this is the only
        // reliable place to handle cherry-pick
        //
        S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
        S7Config *postRevertConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

        const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:repo fromConfig:controlConfig toConfig:postRevertConfig];
        if (0 != checkoutExitStatus) {
            return checkoutExitStatus;
        }

        return [postRevertConfig saveToFileAtPath:S7ControlFileName];

    }

    const BOOL isMergeCommit = [arguments containsObject:@"merge"];
    if (NO == isMergeCommit) {
        return 0;
    }

    if ([S7StatusCommand areSubreposInSync]) {
        return 0;
    }

    // In 'post-merge' hook we rely on .s7control. We decide which subrepos to update, calculating
    // diff between .s7control and .s7substate.
    //
    // If control is not in sync with the main config, then the result of subrepos checkout would be
    // unpredictable. One possible scenario:
    //
    //   git checkout REV_20            # .s7control and .s7substate would be in sync
    //   git reset --hard REV_100500    # .s7control left from REV_20
    //   git merge something            # pisya
    //
    //
    // I don't think we have the right to update subrepos automatically in this hook:
    //  1. it means that developer hasn't checked the result of what he's committing
    //  2. doing such task in pre-commit hook just doesn't feel right to me
    //

    fprintf(stderr,
            "\033[31m"
            "Subrepos not in sync.\n"
            "This might be the result of:\n"
            " - conflicting merge\n"
            " - git reset\n"
            "\n"
            "This commit may result in undefined subrepos state.\n"
            "\n"
            "How to recover:\n"
            "\n"
            " Case 1:   I didn't perform `git reset REV`. It was `git merge`/`git pull`\n"
            "           that failed due to conflicts.\n"
            "\n"
            " Solution: run `s7 checkout`. It would sync subrepos.\n"
            "           After that you'll be able to commit.\n"
            "           S7 didn't run it automatically as no git-hooks are called\n"
            "           in case of merge conflict.\n"
            "\n"
            "\n"
            " Case 2:   I DID run `git reset REV` to \"checkout\" a different revision\n"
            "           and then ran `git merge`/`git pull`.\n"
            "\n"
            " Solution: you'd have to rollback this merge and return to the clean REV.\n"
            "           If you used `git reset --hard REV` before, then you can use it\n"
            "           once again. After that, run `s7 checkout`\n"
            "\n"
            "           I would recommend to reset local changes and checkout\n"
            "           a REV you want to in a proper way – using `git checkout REV`\n"
            "           (optionally, with '-b <branch-name>')\n"
            "           If you use `git checkout`, then s7 will checkout subrepos\n"
            "           automatically.\n"
            "\n"
            "           After you have clean REV and subrepos are in sync, you can\n"
            "           merge what you were trying to merge\n"
            "\n"
            "You can always check if subrepos are in sync, using `s7 status`.\n"
            "\033[0m");

    // hook exit code is not propagated as git command exit code,
    // so there's no need or sense to return special S7ExitCode here
    return 1;
}
@end
