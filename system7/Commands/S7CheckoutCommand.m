//
//  S7CheckoutCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 02.06.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7CheckoutCommand.h"

#import "S7PostCheckoutHook.h"
#import "HelpPager.h"

@implementation S7CheckoutCommand

+ (NSString *)commandName {
    return @"checkout";
}

+ (NSArray<NSString *> *)aliases {
    return @[ @"co" ];
}

+ (void)printCommandHelp {
    help_puts("s7 checkout");
    printCommandAliases(self);
    help_puts("");
    help_puts("Update subrepos to correspond to the state saved in .s7substate.");
    help_puts("Keeps subrepo intact if it contains any uncommitted changes.");
    help_puts("");
    help_puts("You would need this after:");
    help_puts(" 1. merge conflict in main repo. In that case no hooks are called,");
    help_puts("    thus there's no chance for s7 to update subrepos automatically.");
    help_puts("    If you decide to build project after fixing merge conflicts,");
    help_puts("    you would stumble on subrepos 'not in sync' error.");
    help_puts(" 2. you use `git reset OLD_REV`. No hooks are called on `git reset`");
    help_puts("    So, you'd have to update subrepos manually, using this command.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    S7_REPO_PRECONDITION_CHECK();

    GitRepository *repo = [GitRepository repoAtPath:@"."];
    if (nil == repo) {
        return S7ExitCodeNotGitRepository;
    }

    S7Config *controlConfig = [[S7Config alloc] initWithContentsOfFile:S7ControlFileName];
    S7Config *workingConfig = [[S7Config alloc] initWithContentsOfFile:S7ConfigFileName];

    const int checkoutExitStatus = [S7PostCheckoutHook checkoutSubreposForRepo:repo
                                                                    fromConfig:controlConfig
                                                                      toConfig:workingConfig];
    if (0 != checkoutExitStatus) {
        return checkoutExitStatus;
    }

    if (0 != [workingConfig saveToFileAtPath:S7ControlFileName]) {
        fprintf(stderr,
                "failed to save %s to disk.\n",
                S7ControlFileName.fileSystemRepresentation);

        return S7ExitCodeFileOperationFailed;
    }

    return S7ExitCodeSuccess;
}

@end
