//
//  TestUtils.h
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef TestUtils_h
#define TestUtils_h

NS_ASSUME_NONNULL_BEGIN

@class GitRepository;

//
// utils operate on current directory
//

void s7init(void);

GitRepository *s7add(NSString *subrepoPath, NSString *url);
void s7remove(NSString *subrepoPath);

void s7rebind(void);
void s7rebind_with_stage(void); // add --stage option. No need to manually call 'git add .s7substate'
void s7rebind_specific(NSString *subrepoPath);

void s7push(void);

int s7checkout(NSString *fromRevision, NSString *toRevision);

NSString * commit(GitRepository *repo, NSString *fileName, NSString * _Nullable fileContents, NSString *commitMessage);

NS_ASSUME_NONNULL_END

#endif /* TestUtils_h */
