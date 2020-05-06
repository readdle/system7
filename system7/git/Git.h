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

- (int)fetch;
- (int)pull;

- (int)pushAll;
- (int)pushCurrentBranch;

- (int)checkoutNewLocalBranch:(NSString *)branchName;
- (int)checkoutExistingLocalBranch:(NSString *)branchName;
- (int)checkoutRemoteTrackingBranch:(NSString *)branchName remoteName:(NSString *)remoteName;

+ (NSString *)nullRevision;
- (int)getCurrentRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision;
- (int)getLatestRemoteRevision:(NSString * _Nullable __autoreleasing * _Nonnull)ppRevision atBranch:(NSString *)branchName;

- (int)getCurrentBranch:(NSString * _Nullable __autoreleasing * _Nonnull)ppBranch;

- (BOOL)isRevisionAvailable:(NSString *)revision;
- (BOOL)isRevisionAnAncestor:(NSString *)possibleAncestor toRevision:(NSString *)possibleDescendant;

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
