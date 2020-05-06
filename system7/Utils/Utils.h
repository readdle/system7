//
//  Utils.h
//  system7
//
//  Created by Pavlo Shkrabliuk on 28.04.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

int executeInDirectory(NSString *directory, int (NS_NOESCAPE ^block)(void));

NS_ASSUME_NONNULL_END
