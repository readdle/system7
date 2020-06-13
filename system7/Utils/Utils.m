//
//  Utils.m
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import "Utils.h"

int executeInDirectory(NSString *directory, int (NS_NOESCAPE ^block)(void)) {
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:directory]) {
        NSCAssert(NO, @"todo: add logs");
        return 3;
    }

    int operationReturnValue = 128;
    @try {
        operationReturnValue = block();
        return operationReturnValue;
    }
    @finally {
        if (NO == [[NSFileManager defaultManager] changeCurrentDirectoryPath:cwd]) {
            NSCAssert(NO, @"failed to return CWD to the old state");
        }
    }
}

int getConfig(GitRepository *repo, NSString *revision, S7Config * _Nullable __autoreleasing * _Nonnull ppConfig) {
    int showExitStatus = 0;
    NSString *configContents = [repo showFile:S7ConfigFileName atRevision:revision exitStatus:&showExitStatus];
    if (0 != showExitStatus) {
        if (128 == showExitStatus) {
            // s7 config has been removed or we are back to revision where there was no s7 yet
            // this is a valid situation, so we just return an empty config
            configContents = @"";
        }
        else {
            fprintf(stderr,
                    "failed to retrieve .s7substate config at revision %s.\n"
                    "Git exit status: %d\n",
                    [revision cStringUsingEncoding:NSUTF8StringEncoding],
                    showExitStatus);
            return S7ExitCodeGitOperationFailed;
        }
    }

    *ppConfig = [[S7Config alloc] initWithContentsString:configContents];

    return 0;
}

BOOL isExactlyOneBitSetInNumber(uint32_t bits)
{
    // I was too lazy to do this myself
    // taken here https://stackoverflow.com/questions/51094594/how-to-check-if-exactly-one-bit-is-set-in-an-int/51094793
    return bits && !(bits & (bits-1));
}

int addLineToGitIgnore(NSString *lineToAppend) {
    static NSString *gitIgnoreFileName = @".gitignore";

    BOOL isDirectory = NO;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:gitIgnoreFileName isDirectory:&isDirectory]) {
        if (NO == [[NSFileManager defaultManager]
                   createFileAtPath:gitIgnoreFileName
                   contents:nil
                   attributes:nil])
        {
            fprintf(stderr, "failed to create .gitignore file\n");
            return 1;
        }
    }

    if (isDirectory) {
        fprintf(stderr, ".gitignore is a directory!?\n");
        return 2;
    }

    NSError *error = nil;
    NSMutableString *newContent = [[NSMutableString alloc] initWithContentsOfFile:gitIgnoreFileName encoding:NSUTF8StringEncoding error:&error];
    if (nil != error) {
        fprintf(stderr, "failed to read contents of .gitignore file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 3;
    }

    NSArray<NSString *> *existingGitIgnoreLines = [newContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if ([existingGitIgnoreLines containsObject:lineToAppend]) {
        // do not add twice
        return 0;
    }

    if (newContent.length > 0 && NO == [newContent hasSuffix:@"\n"]) {
        [newContent appendString:@"\n"];
    }

    if (NO == [lineToAppend hasSuffix:@"\n"]) {
        lineToAppend = [lineToAppend stringByAppendingString:@"\n"];
    }
    [newContent appendString:lineToAppend];

    if (NO == [newContent writeToFile:gitIgnoreFileName atomically:YES encoding:NSUTF8StringEncoding error:&error] || nil != error) {
        fprintf(stderr, "failed to write contents of .gitignore file. Error: %s\n",
                [[error description] cStringUsingEncoding:NSUTF8StringEncoding]);
        return 4;
    }

    return 0;
}

int s7RepoPreconditionCheck(void) {
    BOOL isDirectory = NO;
    if (NO == [NSFileManager.defaultManager fileExistsAtPath:S7ConfigFileName isDirectory:&isDirectory]
        || isDirectory)
    {
        fprintf(stderr,
                "abort: not s7 repo root\n");
        return S7ExitCodeNotS7Repo;
    }

    return S7ExitCodeSuccess;
}

int saveUpdatedConfigToMainAndControlFile(S7Config *updatedConfig) {
    int configSaveResult = [updatedConfig saveToFileAtPath:S7ConfigFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    configSaveResult = [updatedConfig saveToFileAtPath:S7ControlFileName];
    if (0 != configSaveResult) {
        return configSaveResult;
    }

    return S7ExitCodeSuccess;
}
