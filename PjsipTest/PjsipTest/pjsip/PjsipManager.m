//
//  PjsipManager.m
//  PjsipTest
//
//  Created by 未央生 on 16/11/22.
//  Copyright © 2016年 未央生. All rights reserved.
//

#import "PjsipManager.h"
#import "pjsua.h"
@interface PjsipManager()

//帐户标识
@property (nonatomic, assign) pjsua_acc_id acc_id;
//来电标识
@property (nonatomic, assign) pjsua_call_id called_id;
@property (nonatomic, copy)NSString *ip;

@end

@implementation PjsipManager

+ (void)pjsipInit{
    ///状态标示
    pj_status_t status;
    
    ///注册线程
    pj_bool_t bool_t = pj_thread_is_registered();
    if (!bool_t) {
        pj_thread_desc desc;
        pj_thread_t* thed;
        status = pj_thread_register(NULL,desc,&thed);
        if (status != PJ_SUCCESS)
        {
            NSLog(@"线程注册失败");
        }
    }
    
    status = pjsua_destroy();
    if (status != PJ_SUCCESS)
    {
        NSLog(@"清除信息");
    }
    
    ///初始化程序
    status = pjsua_create();
    if (status != PJ_SUCCESS){
        NSLog(@"pjsua初始化失败");
    }
    else{//初始化pjsua配置
        
        ///初始化通话配置
        pjsua_config config;
        pjsua_config_default (&config);
        //设置登录状态改变回调
        config.cb.on_reg_state2 = &on_reg_state2;
        //设置来电回调
        config.cb.on_incoming_call = &on_incoming_call;
        //设置呼叫状态改变回调
        config.cb.on_call_media_state = &on_call_media_state;
        //设置通话状态改变回调
        config.cb.on_call_state = &on_call_state;
        
        //初始化日志配置
        pjsua_logging_config log_config;
        pjsua_logging_config_default(&log_config);
        //日记等级0不打印日记 4打印详情日记
        log_config.console_level = 0;
        status = pjsua_init(&config, &log_config, NULL);
        //判断是否初始化成功
        if (status != PJ_SUCCESS)
        {
            NSLog(@"创初始化pjsua配置失败");
        }
    }
}

+ (instancetype)sharedPjsipManager{
    static PjsipManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

///登录
- (BOOL)loginPjsipAccounts:(NSString *)accountsString password:(NSString *)passwordString ip:(NSString *)ipString port:(NSInteger)port{
    //状态标识
    pj_status_t status;
    self.ip = ipString;
    //初始化UDP
    {
        pjsua_transport_config config;
        pjsua_transport_config_default(&config);
        config.port = (unsigned)port;
        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &config, NULL);
        if (status != PJ_SUCCESS)
        {
            NSLog(@"添加UDP传输失败");
            return NO;
        }
    }
    //初始化TCP
    {
        pjsua_transport_config config;
        pjsua_transport_config_default(&config);
        config.port = (unsigned)port;
        
        status = pjsua_transport_create(PJSIP_TRANSPORT_TCP, &config, NULL);
        if (status != PJ_SUCCESS)
        {
            NSLog(@"添加TCP传输失败");
            return NO;
        }
    }
    
    //检测pjsua初始化是否成功.
    status = pjsua_start();
    if (status != PJ_SUCCESS)
    {
        NSLog(@"PJSUA初始化失败!");
        return NO;
    }
    
    ///配置账号信息
    pjsua_acc_config config;
    pjsua_acc_config_default(&config);
    
    char accountChar[50];
    strcpy(accountChar, [accountsString UTF8String]);
    char passwordChar[50];
    strcpy(passwordChar, [passwordString UTF8String]);
    
    ///设置账号格式:   sip:账号@服务地址
    char sipAccount[50];
    sprintf(sipAccount, "sip:%s@%s",accountChar,[ipString UTF8String]);
    config.id = pj_str(sipAccount);
    
    //设置服务器格式: sip:服务器地址
    char serviceId[50];
    sprintf(serviceId, "sip:%s",[ipString UTF8String]);
    config.reg_uri = pj_str(serviceId);
    
    //注册账号个数  最多8个
    config.cred_count = 1;
    //注册方案
    config.cred_info[0].scheme = pj_str("Digest");
    //符号"*"
    config.cred_info[0].realm = pj_str("*");
    //帐号
    config.cred_info[0].username = pj_str(accountChar);
    //数据类型
    config.cred_info[0].data_type = 0;
    //密码
    config.cred_info[0].data = pj_str(passwordChar);
    status = pjsua_acc_add(&config, PJ_TRUE, &_acc_id);
    if (status != PJ_SUCCESS)
    {
        NSLog(@"登录SIP电话失败");
        return NO;
    }
    
    return true;
}

///呼叫
- (void)callAccount:(NSString *)accountsString{
    
    char accountChar[50];
    sprintf(accountChar,"sip:%s@%s",[accountsString UTF8String],[self.ip UTF8String]);
    pj_str_t url = pj_str(accountChar);
    
    //初始化呼叫
    pjsua_call_setting  call_set;
    pjsua_call_setting_default(&call_set);
    
    pj_status_t status = pjsua_call_make_call(_acc_id, &url, &call_set, NULL, NULL, NULL);
    if (status != PJ_SUCCESS)
    {
        NSLog(@"呼叫失败");
    }
}

///挂断
- (void)hangUp{
    //获账户信息
    pjsua_call_info config;
    pjsua_call_get_info(_acc_id, &config);
    
    ///判断是否在通话中
    if (config.media_status == PJSUA_CALL_MEDIA_ACTIVE)
    {
        pjsua_call_hangup_all();
    }
}

///接电话
- (void)answerCall{
    pjsua_call_answer(_called_id, 200, NULL, NULL);
}


#pragma mark - 回调
///登录状态改变回调
static void on_reg_state2(pjsua_acc_id acc_id, pjsua_reg_info *info){
    if (info->renew != 0) {
        if (info->cbparam->code == 200) {
            NSLog(@"登录成功");
        }
        else{
            NSLog(@"登录失败code:%d ",info->cbparam->code);
        }
    }
    else{
        if (info->cbparam->code == 200)
        {
            NSLog(@"SIP退出登录成功");
        }
    }
}

///来电回调
static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata){
    //获取来电信息
    pjsua_call_info info;
    pjsua_call_get_info(call_id, &info);
    NSString *callStr = [NSString stringWithUTF8String:info.remote_info.ptr];
    //这里发送一个通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"calling" object:nil userInfo:@{@"calledCAcount":callStr}];
    NSLog(@"%@",callStr);
}

///呼叫回调
static void on_call_media_state(pjsua_call_id call_id)
{
    //获取呼叫信息
    pjsua_call_info info;
    pjsua_call_get_info(call_id, &info);
    
    if (info.media_status == PJSUA_CALL_MEDIA_ACTIVE)
    {//呼叫接通
        
        //建立单向媒体流从源到汇
        pjsua_conf_connect(info.conf_slot, 0);
        pjsua_conf_connect(0, info.conf_slot);
        
        NSLog(@"呼叫成功,等待对方接听");
    }
}

//通话状态改变回调
static void on_call_state(pjsua_call_id call_id, pjsip_event *e)
{
    
    // 通话状态:CALLING
    // 通话状态:EARLY
    // 通话状态:EARLY
    // 呼叫成功,等待对方接听
    // 通话状态:CONNECTING
    // 通话状态:CONFIRMED
    // DISCONNCTD  对方挂断
    //获取通话信息
    pjsua_call_info ci;
    pjsua_call_get_info(call_id, &ci);
    
    NSString *status = [NSString stringWithUTF8String:ci.state_text.ptr];
    NSLog(@"通话状态:%@",status);
    
    
}

@end
