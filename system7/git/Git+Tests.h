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

@end

NS_ASSUME_NONNULL_END
