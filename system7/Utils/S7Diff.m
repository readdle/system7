//
//  S7Diff.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 08.05.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "S7Diff.h"

NSSet *intersectSets(NSSet *yellow, NSSet *blue) {
    NSMutableSet *result = [yellow mutableCopy];
    [result intersectSet:blue];
    return result;
}

NSSet *minusSets(NSSet *minuend, NSSet *subtrahend) {
    NSMutableSet *result = [minuend mutableCopy];
    [result minusSet:subtrahend];
    return result;
}

int diffConfigs(S7Config *fromConfig,
                S7Config *toConfig,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToDelete,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToUpdate,
                NSMutableDictionary<NSString *, S7SubrepoDescription *> * _Nullable __autoreleasing * _Nonnull ppSubreposToAdd)
{
    NSDictionary<NSString *, S7SubrepoDescription *> *fromConfigMap = fromConfig.pathToDescriptionMap;
    NSSet<NSString *> *fromSubrepoPathsSet = fromConfig.subrepoPathsSet;

    NSDictionary<NSString *, S7SubrepoDescription *> *toConfigMap = toConfig.pathToDescriptionMap;
    NSSet<NSString *> *toSubrepoPathsSet = toConfig.subrepoPathsSet;

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *subreposToUpdate = [NSMutableDictionary new];
    NSSet<NSString *> *subreposToCompare = intersectSets(fromSubrepoPathsSet, toSubrepoPathsSet);
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
    for (NSString *path in minusSets(fromSubrepoPathsSet, toSubrepoPathsSet)) {
        NSCAssert(nil == toConfigMap[path], @"");
        S7SubrepoDescription *fromDescription = fromConfigMap[path];
        NSCAssert(fromDescription, @"");

        subreposToDelete[path] = fromDescription;
    }
    *ppSubreposToDelete = subreposToDelete;

    NSMutableDictionary<NSString *, S7SubrepoDescription *> *subreposToAdd = [NSMutableDictionary new];
    for (NSString *path in minusSets(toSubrepoPathsSet, fromSubrepoPathsSet)) {
        NSCAssert(nil == fromConfigMap[path], @"");
        S7SubrepoDescription *toDescription = toConfigMap[path];
        NSCAssert(toDescription, @"");

        subreposToAdd[path] = toDescription;
    }
    *ppSubreposToAdd = subreposToAdd;

    return S7ExitCodeSuccess;
}
