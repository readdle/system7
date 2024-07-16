//
//  S7BootstrapCommand.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 20.12.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7BootstrapCommand.h"

#import "S7Utils.h"
#import "S7HelpPager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation S7BootstrapCommand

+ (NSString *)commandName {
    return @"bootstrap";
}

+ (NSArray<NSString *> *)aliases {
    return @[];
}

+ (void)printCommandHelp {
    help_puts("s7 bootstrap");
    help_puts("");
    help_puts("Service command used to automatically run `s7 init` in a new repo clone.");
    help_puts("");
    help_puts("You should not use this command unless you are s7 itself or s7 developer.");
    help_puts("Read the contents of .s7bootstrap file in any existing s7 repo for more");
    help_puts("info about the bootstrap process.");
}

- (int)runWithArguments:(NSArray<NSString *> *)arguments {
    if ([self shouldInstallBootstrap]) {
        // we may still fail to install bootstrap, for example, if post-checkout hook exists
        // and it's not a shell script (where we can merge in)
        //
        GitRepository *repo = [GitRepository repoAtPath:@"."];
        if (nil == repo) {
            return S7ExitCodeNotGitRepository;
        }

        installHook(repo,
                    @"post-checkout",
                    [[self class] bootstrapCommandLine],
                    NO,
                    NO);
    }

    // according to https://git-scm.com/docs/gitattributes
    //  "filter driver that exits with a non-zero status, is not an error but makes the filter a no-op passthru."
    // but in reality, if filter exist with non-zero, Git writes:
    //  "error: external filter '...' failed 1"
    // it doesn't affect the clone process, but looks ugly.
    // So... we'd have to actually perform the "filter" and exit gracefully
    //
    if (NO == self.runFakeFilter) {
        char c;
        while ((c=getchar()) != EOF) {
            putchar(c);
        }
    }

    return S7ExitCodeSuccess;
}

- (BOOL)shouldInstallBootstrap {
    if ([self isS7PostCheckoutAlreadyInstalled]) {
        return NO;
    }

    if ([self willBootstrapConflictWithGitLFS]) {
        return NO;
    }

    if ([NSFileManager.defaultManager fileExistsAtPath:S7ControlFileName]) {
        // If repo contains .s7control, then user has already done some work in it
        // which implies that s7 IS initialized in the repo.
        // If we install bootstrap at such repo, then it will install bootstrap into
        // post-checkout hook, but the actual `s7 init` won't be called in the process
        // of checkout, as .s7control exists
        //
        return NO;
    }

    return YES;
}

- (BOOL)isS7PostCheckoutAlreadyInstalled {
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".git/hooks/post-checkout"]) {
        return NO;
    }

    NSError *error = nil;
    NSString *postCheckoutContent = [[NSString alloc] initWithContentsOfFile:@".git/hooks/post-checkout"
                                                                    encoding:NSUTF8StringEncoding
                                                                       error:&error];
    if (nil != error) {
        logError("s7 bootstrap: failed to read contents of the post-checkout hook file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return NO;
    }

    if ([postCheckoutContent containsString:@"s7 post-checkout"]) {
        return YES;
    }

    return NO;
}

- (BOOL)willBootstrapConflictWithGitLFS {
    NSError *error = nil;
    NSString *gitattributesContent = [[NSString alloc] initWithContentsOfFile:@".gitattributes" encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        // Such situation would be really unexpected – how would Git find out
        // that it should filter .s7bootstrap if there's no .gitattributes?
        // Maybe something wrong with the permissions?
        // Anyway, if we cannot read .gitattributes, then we better avoid bootstrap.
        //
        logError("s7 bootstrap: failed to read contents of .gitattributes file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return YES;
    }

    if ([gitattributesContent containsString:@"filter=lfs"]) {
        // this repo contains some LFS files.
        // If LFS hook is NOT installed, then we do not install bootstrap hook
        // not to cause LFS hook install failure. In such case user will have to
        // run `s7 init` manually 🤷‍♂️
        // If LFS hook IS installed, we can still merge-in bootstrap command into it.
        //
        if (NO == [NSFileManager.defaultManager fileExistsAtPath:@".git/hooks/post-checkout"]) {
            return YES;
        }
    }

    return NO;
}

+ (NSString *)bootstrapCommandLine {
    return @"/usr/local/bin/s7 init";
}

@end

NS_ASSUME_NONNULL_END
