//
//  Git+Tests.h
//  system7
//
//  Created by Nik Savko on 18.04.2023.
//  Copyright © 2023 Readdle. All rights reserved.
//

#import "Git.h"

NS_ASSUME_NONNULL_BEGIN

@interface GitRepository (Tests)

- (int)createFile:(NSString *)relativeFilePath withContents:(nullable NSString *)contents;
- (void)run:(void (NS_NOESCAPE ^)(GitRepository *repo))block;

- (int)runGitCommand:(NSString *)command;

@property (nonatomic, class) void (^testRepoConfigureOnInitBlock)(GitRepository *repo);
@property (nonatomic, readonly) BOOL hasMergeConflict;

// Percent-encode every character that isn't RFC 3986 "unreserved".
// `%` itself is included in the escape set, so a literal `%` in a token
// becomes `%25` (avoids garbling the userinfo component of the URL).
+ (NSString *)urlEscapeUserinfo:(NSString *)input;

// Pure builder for the `-c url.<HTTPS+token>.insteadOf=<SSH>` argv prefix.
// Bypasses dispatch_once and process env so tests can probe arbitrary inputs.
+ (NSArray<NSString *> *)gitHubTokenInsteadOfArgumentsForUser:(nullable NSString *)user
                                                        token:(nullable NSString *)token;

// Pure trace-mask helper: redacts any occurrence of `token` (both URL-encoded
// and raw) in `line` with `***`.
+ (NSString *)maskedTraceLine:(NSString *)line
                     forToken:(nullable NSString *)token;

@end

NS_ASSUME_NONNULL_END
