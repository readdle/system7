//
//  S7Logging.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.09.2023.
//  Copyright © 2023 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void logInfo(const char * __restrict, ...) __printflike(1, 2);
void logError(const char * __restrict, ...) __printflike(1, 2);

NS_ASSUME_NONNULL_END
