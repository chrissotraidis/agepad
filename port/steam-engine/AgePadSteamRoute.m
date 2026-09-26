#import "AgePadSteamRoute.h"
#import <Security/Security.h>
#include "SteamEngineHost.h"
#import "SteamQRSignIn.h"

static NSString *const KeychainService=@"AgePad Steam sign-in";
static dispatch_queue_t EngineQueue(void) {
    static dispatch_queue_t queue;static dispatch_once_t once;
    dispatch_once(&once,^{ queue=dispatch_queue_create("agepad.steam-engine",DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static NSString *AccountFile(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject
        stringByAppendingPathComponent:@"AgePadSteamAccount.env"];
}
static NSDictionary *KeychainQuery(NSString *account) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:KeychainService,(__bridge id)kSecAttrAccount:account};
}
static void SaveToken(NSString *account,NSString *token) {
    SecItemDelete((__bridge CFDictionaryRef)KeychainQuery(account));
    NSMutableDictionary *item=[KeychainQuery(account) mutableCopy];
    item[(__bridge id)kSecValueData]=[token dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    OSStatus status=SecItemAdd((__bridge CFDictionaryRef)item,NULL);
    fprintf(stderr,"AGEPAD_STEAM_SIGNIN_SAVED keychain=%d\n",(int)status);
}
static NSString *LoadToken(NSString *account) {
    NSMutableDictionary *query=[KeychainQuery(account) mutableCopy];
    query[(__bridge id)kSecReturnData]=@YES;
    CFTypeRef data=NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query,&data)!=errSecSuccess || !data) return nil;
    return [[NSString alloc] initWithData:(__bridge_transfer NSData *)data encoding:NSUTF8StringEncoding];
}

@implementation AgePadSteamRoute
+ (BOOL)hasAccount { return getenv("AGEPAD_STEAM_ENGINE_ID")!=NULL; }
+ (NSString *)accountName { const char *name=getenv("AGEPAD_STEAM_ENGINE_NAME");return name?@(name):@""; }
+ (void)forgetAccount {
    const char *steamID=getenv("AGEPAD_STEAM_ENGINE_ID");
    if (steamID) SecItemDelete((__bridge CFDictionaryRef)KeychainQuery(@(steamID)));
    [NSFileManager.defaultManager removeItemAtPath:AccountFile() error:nil];
    unsetenv("AGEPAD_STEAM_ENGINE_ID");unsetenv("AGEPAD_STEAM_ENGINE_NAME");
}
+ (void)prepareWithClient:(void *)client {
    dispatch_async(EngineQueue(),^{
        char error[160]={0};
        bool started=AgePadEngineStart(client,error,sizeof error);
        fprintf(stderr,"AGEPAD_ENGINE_PREPARED started=%d error=%s\n",started,started?"none":error);fflush(stderr);
        // Opt-in diagnostic: an anonymous Steam logon exercises the server
        // connection and logon message without any account.
        if (started && getenv("AGEPAD_ENGINE_ANON_TEST")) {
            int result=AgePadEngineLogOn(0x01A0000000000000ULL);
            for (int second=0;second<30;second+=2) {
                fprintf(stderr,"AGEPAD_ENGINE_ANON t=%d result=%d connected=%d logged_on=%d logon_state=%d\n",second,result,
                    AgePadEngineConnected(),AgePadEngineLoggedOn(),AgePadEngineLogonState());fflush(stderr);
                if (AgePadEngineLoggedOn()) break;
                sleep(2);
            }
            AgePadEngineLogOff();
        }
    });
}
+ (void)saveSignIn:(NSDictionary *)signIn {
    NSString *steamID=signIn[AgePadSteamID64],*name=signIn[AgePadSteamAccountName];
    SaveToken(steamID,signIn[AgePadSteamRefreshToken]);
    NSString *file=[NSString stringWithFormat:@"AGEPAD_STEAM_ENGINE_ID=%@\nAGEPAD_STEAM_ENGINE_NAME=%@\n",steamID,name];
    [file writeToFile:AccountFile() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    setenv("AGEPAD_STEAM_ENGINE_ID",steamID.UTF8String,1);setenv("AGEPAD_STEAM_ENGINE_NAME",name.UTF8String,1);
}
+ (void)startWithClient:(void *)client path:(NSString *)clientPath lookUp:(AgePadBootstrapLookUp)lookUp
                 status:(void (^)(NSString *))status completion:(void (^)(NSString *))completion {
    NSString *steamID=@(getenv("AGEPAD_STEAM_ENGINE_ID")?:""),*name=[self accountName];
    void (^say)(NSString *)=^(NSString *message) { dispatch_async(dispatch_get_main_queue(),^{ status(message); }); };
    void (^finish)(NSString *)=^(NSString *error) { dispatch_async(dispatch_get_main_queue(),^{ completion(error); }); };
    dispatch_async(EngineQueue(),^{
        // The game's own Steam connection must reach this engine, not a Mac relay.
        for (NSString *key in @[@"AGEPAD_STEAM_TUNNEL_HOST",@"AGEPAD_HOST_PATH_RELAY_TCP_HOST",@"AGEPAD_STEAM_TUNNEL_PORT",
                @"AGEPAD_HOST_PATH_RELAY_TCP_PORT",@"AGEPAD_STEAM_LOOPBACK_PORT",@"AGEPAD_RELAY_TOKEN"]) unsetenv(key.UTF8String);
        char error[160]={0};
        if (!AgePadEngineStart(client,error,sizeof error)) {
            fprintf(stderr,"AGEPAD_ENGINE_START_FAILED %s\n",error);
            finish([NSString stringWithFormat:@"Steam couldn't start inside AgePad (%s).",error]);return;
        }
        NSString *account=steamID,*token=LoadToken(account);
        // Opt-in diagnostic: attach the game to an anonymous engine session
        // (tests the ipcserver/game plumbing; the game is not licensed there).
        BOOL anonymous=getenv("AGEPAD_ENGINE_ANON_GAME")!=NULL;
        fprintf(stderr,"AGEPAD_ENGINE_STARTED saved_sign_in=%d anonymous_test=%d\n",token!=nil,anonymous);
        if (anonymous) { account=@"117093590311632896";token=nil; } // 0x01A0000000000000
        if (!token && !anonymous) { finish(@"Your Steam sign-in is missing on this iPad. Sign in again.");return; }
        if (token) AgePadEngineSetLoginToken(token.UTF8String,name.UTF8String);
        say([NSString stringWithFormat:@"Signing in to Steam as %@…",name]);
        int result=AgePadEngineLogOn(strtoull(account.UTF8String,NULL,10));
        BOOL offline=NO;
        for (int tenth=0;tenth<600 && !AgePadEngineLoggedOn();tenth++) {
            if (tenth%20==0) fprintf(stderr,"AGEPAD_ENGINE_STATE t=%d result=%d connected=%d logged_on=0 logon_state=%d offline=%d\n",
                tenth/10,result,AgePadEngineConnected(),AgePadEngineLogonState(),offline);
            // No connection after 10 s: Steam's own offline mode (needs one earlier online sign-in).
            if (tenth==100 && !AgePadEngineConnected()) {
                offline=YES;result=AgePadEngineLogOnOffline();
                say(@"No connection. Starting Steam in offline mode…");
            }
            usleep(100000);
        }
        BOOL loggedOn=AgePadEngineLoggedOn();
        fprintf(stderr,"AGEPAD_ENGINE_LOGON logged_on=%d offline=%d logon_state=%d\n",loggedOn,offline,AgePadEngineLogonState());
        if (!loggedOn) {
            finish(offline?@"Steam couldn't start offline. Connect to the Internet once, then try again.":
                           @"Steam didn't finish signing in. Check the connection and try again.");return;
        }
        kern_return_t registered=AgePadEngineRegister(clientPath.fileSystemRepresentation,lookUp);
        fprintf(stderr,"AGEPAD_ENGINE_REGISTERED status=%d\n",registered);
        finish(registered==KERN_SUCCESS?nil:@"Steam started, but the game couldn't be connected to it.");
    });
}
+ (UIView *)signInViewWithCompletion:(void (^)(void))signedIn {
    UIStackView *panel=[UIStackView new];
    panel.axis=UILayoutConstraintAxisVertical;panel.spacing=14;panel.alignment=UIStackViewAlignmentLeading;
    UILabel *title=[UILabel new];
    title.text=@"Sign in to Steam";title.font=[UIFont systemFontOfSize:26 weight:UIFontWeightBold];title.textColor=UIColor.whiteColor;
    UILabel *how=[UILabel new];how.numberOfLines=0;
    how.text=@"On your phone, open the Steam app, tap the Steam Guard shield, then scan this code. You only do this once; AgePad remembers the sign-in on this iPad and never sees your password.";
    how.font=[UIFont systemFontOfSize:18];how.textColor=[UIColor colorWithRed:.75 green:.81 blue:.84 alpha:1];
    UIImageView *code=[UIImageView new];
    code.backgroundColor=UIColor.whiteColor;code.layer.magnificationFilter=kCAFilterNearest;
    [code.widthAnchor constraintEqualToConstant:300].active=YES;[code.heightAnchor constraintEqualToConstant:300].active=YES;
    UILabel *state=[UILabel new];state.numberOfLines=0;
    state.text=@"Getting a sign-in code…";state.font=[UIFont systemFontOfSize:17 weight:UIFontWeightMedium];state.textColor=UIColor.whiteColor;
    UIButtonConfiguration *style=UIButtonConfiguration.plainButtonConfiguration;
    style.baseForegroundColor=[UIColor colorWithRed:.88 green:.71 blue:.40 alpha:1];
    style.title=@"No phone app? Sign in with your password instead";
    style.contentInsets=NSDirectionalEdgeInsetsZero;
    UIButton *passwordButton=[UIButton buttonWithConfiguration:style primaryAction:nil];
    for (UIView *view in @[title,how,code,state,passwordButton]) [panel addArrangedSubview:view];
    // Whichever sign-in (QR or password) finishes first completes the panel.
    __block BOOL done=NO;
    void (^succeed)(NSDictionary *)=^(NSDictionary *signIn) {
        dispatch_async(dispatch_get_main_queue(),^{
            if (done) return;
            done=YES;
            fprintf(stderr,"AGEPAD_STEAM_SIGNIN_OK\n");
            [self saveSignIn:signIn];
            state.text=[NSString stringWithFormat:@"Signed in as %@.",signIn[AgePadSteamAccountName]];
            signedIn();
        });
    };
    __weak UIStackView *weakPanel=panel;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        while (weakPanel && !done) {
            NSString *error=nil;
            NSDictionary *signIn=AgePadSteamQRSignIn(@"AgePad (iPad)",280,^(NSString *challenge) {
                UIImage *image=[UIImage imageWithData:AgePadSteamQRPNG(challenge,600)];
                dispatch_async(dispatch_get_main_queue(),^{ if (!done) { code.image=image;state.text=@"Waiting for you to approve on your phone. The code refreshes by itself."; } });
            },&error);
            if (signIn) { succeed(signIn);return; }
            fprintf(stderr,"AGEPAD_STEAM_SIGNIN_RETRY %s\n",error.UTF8String);
            dispatch_async(dispatch_get_main_queue(),^{ if (!done) state.text=@"Getting a new code…"; });
            sleep(error && [error containsString:@"timed out"]?1:5);
        }
    });
    // Password + Steam Guard. The password stays in this alert's memory, is
    // encrypted with Steam's key and sent once; it is never saved or logged.
    __weak UIButton *weakButton=passwordButton;
    [passwordButton addAction:[UIAction actionWithHandler:^(UIAction *action) {
        UIViewController *host=weakButton.window.rootViewController;
        while (host.presentedViewController) host=host.presentedViewController;
        UIAlertController *form=[UIAlertController alertControllerWithTitle:@"Sign in to Steam"
            message:@"Your password is sent only to Steam, encrypted. AgePad doesn't keep it." preferredStyle:UIAlertControllerStyleAlert];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder=@"Steam account name";field.autocapitalizationType=UITextAutocapitalizationTypeNone;
            field.autocorrectionType=UITextAutocorrectionTypeNo;field.textContentType=UITextContentTypeUsername; }];
        [form addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder=@"Password";field.secureTextEntry=YES;field.textContentType=UITextContentTypePassword; }];
        [form addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        __weak UIAlertController *weakForm=form;
        [form addAction:[UIAlertAction actionWithTitle:@"Sign In" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSString *account=weakForm.textFields[0].text,*password=weakForm.textFields[1].text;
            state.text=@"Signing in…";
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
                NSString *error=nil;
                NSDictionary *signIn=AgePadSteamPasswordSignIn(account,password,@"AgePad (iPad)",^NSString *(int codeType) {
                    __block NSString *entered=nil;
                    dispatch_semaphore_t answered=dispatch_semaphore_create(0);
                    dispatch_async(dispatch_get_main_queue(),^{
                        UIAlertController *guard=[UIAlertController alertControllerWithTitle:@"Steam Guard code"
                            message:codeType==2?@"Enter the code Steam emailed you.":@"Enter the code from the Steam app (Steam Guard)."
                            preferredStyle:UIAlertControllerStyleAlert];
                        [guard addTextFieldWithConfigurationHandler:^(UITextField *field) {
                            field.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters;field.textContentType=UITextContentTypeOneTimeCode; }];
                        __weak UIAlertController *weakGuard=guard;
                        [guard addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *c) { dispatch_semaphore_signal(answered); }]];
                        [guard addAction:[UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDefault handler:^(UIAlertAction *c) {
                            entered=weakGuard.textFields[0].text;dispatch_semaphore_signal(answered); }]];
                        [host presentViewController:guard animated:YES completion:nil];
                    });
                    dispatch_semaphore_wait(answered,DISPATCH_TIME_FOREVER);
                    return entered;
                },^{
                    dispatch_async(dispatch_get_main_queue(),^{ state.text=@"Approve the sign-in in the Steam app on your phone…"; });
                },&error);
                if (signIn) { succeed(signIn);return; }
                fprintf(stderr,"AGEPAD_STEAM_PASSWORD_SIGNIN_FAILED %s\n",error.UTF8String);
                dispatch_async(dispatch_get_main_queue(),^{ if (!done) state.text=error?:@"Sign-in didn't finish."; });
            });
        }]];
        [host presentViewController:form animated:YES completion:nil];
    }] forControlEvents:UIControlEventPrimaryActionTriggered];
    return panel;
}
@end
