//
//  S7HelpPager.h
//  system7
//
//  Created by Nik on 24.07.2020.
//  Copyright © 2020 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

int withHelpPaginationDo(int (^block)(void));

void help_puts(const char * __restrict, ...) __printflike(1, 2);

NS_ASSUME_NONNULL_END
