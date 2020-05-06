//
//  TestUtils.h
//  system7-tests
//
//  Created by Pavlo Shkrabliuk on 05.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#ifndef TestUtils_h
#define TestUtils_h

//
// utils operate on current directory
//

void s7init(void);

GitRepository *s7add(NSString *subrepoPath, NSString *url);
void s7remove(NSString *subrepoPath);

void s7rebind(void);
void s7rebind_specific(NSString *subrepoPath);

void s7push(void);

void s7checkout(void);

NSString * makeSampleCommitToReaddleLib(GitRepository *readdleLibSubrepoGit);
NSString * makeSampleCommitToRDPDFKit(GitRepository *pdfKitSubrepoGit);


#endif /* TestUtils_h */
