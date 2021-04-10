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

    return 0;
}

@end
