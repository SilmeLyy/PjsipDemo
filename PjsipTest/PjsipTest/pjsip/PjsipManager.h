//
//  PjsipManager.h
//  PjsipTest
//
//  Created by 未央生 on 16/11/22.
//  Copyright © 2016年 未央生. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PjsipManager : NSObject

+ (void)pjsipInit;

+ (instancetype)sharedPjsipManager;

- (BOOL)loginPjsipAccounts:(NSString *)accountsString
                  password:(NSString *)passwordString
                        ip:(NSString *)ipString
                      port:(NSInteger )port;

//呼叫
- (void)callAccount:(NSString *)accountsString;

//挂断
- (void)hangUp;

//接电话
- (void)answerCall;

@end
