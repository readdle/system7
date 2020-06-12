//
//  S7Diff.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 08.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Diff.h"

int diffConfigs(S7Config *fromConfig,
                S7Config *toConfig,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToDelete,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToUpdate,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToAdd)
{
    NSDictionary<NSString *, S7SubrepoDescription *> *fromConfigMap = fromConfig.pathToDescriptionMap;
    NSMutableSet<NSString *> *fromSubrepoPathsSet = [fromConfig.subrepoPathsSet mutableCopy];

    NSDictionary<NSString *, S7SubrepoDescription *> *toConfigMap = toConfig.pathToDescriptionMap;
    NSMutableSet<NSString *> *toSubrepoPathsSet = [toConfig.subrepoPathsSet mutableCopy];

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = [NSMutableDictionary new];
    NSMutableSet<NSString *> *subreposToCompare = [fromSubrepoPathsSet mutableCopy];
    [subreposToCompare intersectSet:toSubrepoPathsSet];
    for (NSString *path in subreposToCompare) {
        S7SubrepoDescription *fromDescription = fromConfigMap[path];
        NSCAssert(fromDescription, @"");
        S7SubrepoDescription *toDescription = toConfigMap[path];
        NSCAssert(toDescription, @"");

        if (NO == [fromDescription isEqual:toDescription]) {
            subreposToUpdate[path] = toDescription;
        }
    }
    *ppSubreposToUpdate = subreposToUpdate;

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *subreposToDelete = [NSMutableDictionary new];
    [fromSubrepoPathsSet minusSet:toSubrepoPathsSet];
    for (NSString *path in fromSubrepoPathsSet) {
        NSCAssert(nil == toConfigMap[path], @"");
        S7SubrepoDescription *fromDescription = fromConfigMap[path];
        NSCAssert(fromDescription, @"");

        subreposToDelete[path] = fromDescription;
    }
    *ppSubreposToDelete = subreposToDelete;

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = [NSMutableDictionary new];
    [toSubrepoPathsSet minusSet:fromSubrepoPathsSet];
    [toSubrepoPathsSet minusSet:subreposToCompare];
    for (NSString *path in toSubrepoPathsSet) {
        NSCAssert(nil == fromConfigMap[path], @"");
        S7SubrepoDescription *toDescription = toConfigMap[path];
        NSCAssert(toDescription, @"");

        subreposToAdd[path] = toDescription;
    }
    *ppSubreposToAdd = subreposToAdd;

    return S7ExitCodeSuccess;
}
