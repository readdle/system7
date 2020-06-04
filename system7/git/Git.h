//
//  Git.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 27.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GitRepository : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithRepoPath:(NSString *)repoPath;

+ (nullable instancetype)repoAtPath:(NSString *)repoPath;
+ (nullable GitRepository *)cloneRepoAtURL:(NSString *)url destinationPath:(NSString *)destinationPath exitStatus:(int *)exitStatus;
+ (nullable GitRepository *)initializeRepositoryAtPath:(NSString *)path bare:(BOOL)bare exitStatus:(int *)exitStatus;

@property (nonatomic, readonly, strong) NSString *absolutePath;

- (BOOL)isEmptyRepo;
- (BOOL)isBareRepo;

- (int)fetch;
- (int)pull;
- (int)merge;
- (int)mergeWith:(NSString *)commit;

- (BOOL)hasUnpushedCommits;
- (int)pushAllBranchesNeedingPush;
- (int)pushCurrentBranch;
- (int)pushBranch:(NSString *)branchName;

- (int)checkoutNewLocalBranch:(NSString *)branchName;
- (int)checkoutExistingLocalBranch:(NSString *)branchName;
- (int)checkoutRemoteTrackingBranch:(NSString *)branchName;
- (int)deleteRemoteBranch:(NSString *)branchName;
- (int)forceCheckoutExistingLocalBranch:(NSString *)branchName revision:(NSString *)revisions;
- (BOOL)isBranchTrackingRemoteBranch:(NSString *)branchName;
- (int)getCurrentBranch:(NSString * _Nullable __autoreleasing * _Nonnull)ppBranch;
- (BOOL)isInDetachedHEAD;

+ (NSString *)nullRevision;
- (int)getCurrentRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision;
- (int)getLatestRemoteRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision atBranch:(NSString *)branchName;
- (BOOL)isRevisionAvailableLocally:(NSString *)revision;
- (BOOL)isRevisionReachableFromAnyBranch:(NSString *)revision numberOfOrphanedCommits:(int *)pNumberOfOrphanedCommits;
- (BOOL)isRevision:(NSString *)revision knownAtRemoteBranch:(NSString *)branchName;
- (BOOL)isRevisionAnAncestor:(NSString *)possibleAncestor toRevision:(NSString *)possibleDescendant;
- (BOOL)isMergeRevision:(NSString *)revision;
- (int)checkoutRevision:(NSString *)revision;

- (NSString *)showFile:(NSString *)filePath atRevision:(NSString *)revision exitStatus:(int *)exitStatus;

- (BOOL)hasUncommitedChanges;

- (int)add:(NSArray<NSString *> *)filePaths;
- (int)commitWithMessage:(NSString *)message;

- (int)resetLocalChanges;
- (int)resetToRevision:(NSString *)revision;

- (int)getRemote:(NSString * _Nullable __autoreleasing * _Nonnull)ppRemote;
- (int)getUrl:(NSString * _Nullable __autoreleasing * _Nonnull)ppUrl forRemote:(NSString *)remote;

@end

@interface GitRepository (Tests)

- (int)createFile:(NSString *)relativeFilePath withContents:(nullable NSString *)contents;
- (void)run:(void (NS_NOESCAPE ^)(GitRepository *repo))block;

@end

NS_ASSUME_NONNULL_END
