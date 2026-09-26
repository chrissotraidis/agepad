// Stage 0 (Mac) of docs/STEAM-ENGINE-LOOP.md, using the same engine host the
// iPad app uses. Modes (environment):
//   STAGE0_SIGNIN=<page.html>  QR sign-in first (token goes to the engine in memory only)
//   STAGE0_STEAMID=<id64>      log on with the engine's own saved sign-in
//   STAGE0_OFFLINE=1           use Steam's offline mode for that account
//   STAGE0_GAME=<libsteam_api> after sign-in, register with ipcserver and attach DE's libsteam_api
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <servers/bootstrap.h>
#include "SteamEngineHost.h"
#import "SteamQRSignIn.h"

static void GameSide(const char *path) {
    void *api=dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if (!api) { printf("GAME_API_LOAD_FAILED %s\n",dlerror());return; }
    bool ok=((bool (*)(void))dlsym(api,"SteamAPI_Init"))();
    printf("GAME_STEAMAPI_INIT ok=%d\n",ok);fflush(stdout);
    if (!ok) return;
    void *user=((void *(*)(void))dlsym(api,"SteamAPI_SteamUser_v021"))();
    void *apps=((void *(*)(void))dlsym(api,"SteamAPI_SteamApps_v008"))();
    for (int i=0;i<5;i++) {
        ((void (*)(void))dlsym(api,"SteamAPI_RunCallbacks"))();
        printf("GAME_STATE logged_on=%d owns_aoe2de=%d\n",
            ((bool (*)(void *))dlsym(api,"SteamAPI_ISteamUser_BLoggedOn"))(user),
            ((bool (*)(void *,uint32_t))dlsym(api,"SteamAPI_ISteamApps_BIsSubscribedApp"))(apps,813780));
        fflush(stdout);sleep(2);
    }
}
int main(int argc,char **argv) {
    @autoreleasepool {
    if (argc<2) { fprintf(stderr,"usage: Stage0Engine steamclient.dylib [seconds]\n");return 64; }
    int seconds=argc>2?atoi(argv[2]):20;
    NSDictionary *signIn=nil;
    if (getenv("STAGE0_SIGNIN")) {
        NSString *page=@(getenv("STAGE0_SIGNIN")),*error=nil;
        signIn=AgePadSteamQRSignIn(@"AgePad",300,^(NSString *challenge) {
            // Self-refreshing page: Steam rotates the code about every 30 s.
            NSString *png=[AgePadSteamQRPNG(challenge,600) base64EncodedStringWithOptions:0];
            NSString *html=[NSString stringWithFormat:@"<html><head><meta http-equiv=refresh content=2><title>AgePad Steam sign-in</title></head>"
                "<body style='font:24px -apple-system;text-align:center;margin-top:40px'><p>Scan with the Steam app (Steam Guard &rarr; scan QR)</p>"
                "<img width=420 src='data:image/png;base64,%@'></body></html>",png];
            [html writeToFile:page atomically:YES encoding:NSUTF8StringEncoding error:nil];
            printf("SIGNIN_QR_READY\n");fflush(stdout);
        },&error);
        if (!signIn) { printf("SIGNIN_FAILED %s\n",error.UTF8String);return 3; }
        printf("SIGNIN_OK account=%s steam_id=%s\n",[signIn[AgePadSteamAccountName] UTF8String],[signIn[AgePadSteamID64] UTF8String]);fflush(stdout);
    }
    void *client=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if (!client) { printf("ENGINE_LOAD_FAILED %s\n",dlerror());return 1; }
    char error[160]={0};
    if (!AgePadEngineStart(client,error,sizeof error)) { printf("ENGINE_START_FAILED %s\n",error);return 2; }
    printf("ENGINE_STARTED\n");fflush(stdout);
    uint64_t steamID=getenv("STAGE0_STEAMID")?strtoull(getenv("STAGE0_STEAMID"),NULL,10):0;
    if (signIn) {
        AgePadEngineSetLoginToken([signIn[AgePadSteamRefreshToken] UTF8String],[signIn[AgePadSteamAccountName] UTF8String]);
        steamID=strtoull([signIn[AgePadSteamID64] UTF8String],NULL,10);
        signIn=nil;
    }
    if (steamID) {
        int result=getenv("STAGE0_OFFLINE")?AgePadEngineLogOnOffline():AgePadEngineLogOn(steamID);
        printf("ENGINE_LOGON offline=%d result=%d\n",getenv("STAGE0_OFFLINE")!=NULL,result);fflush(stdout);
    }
    if (getenv("STAGE0_GAME")) {
        for (int i=0;i<60 && !AgePadEngineLoggedOn();i++) sleep(1);
        printf("IPCSERVER_REGISTER status=%d\n",AgePadEngineRegister(argv[1],bootstrap_look_up));fflush(stdout);
        GameSide(getenv("STAGE0_GAME"));
    }
    for (int t=0;t<seconds;t+=2) {
        uint64_t current=AgePadEngineSteamID();
        printf("ENGINE_STATE seconds=%d connected=%d logged_on=%d logon_state=%d account_known=%d\n",
            t,AgePadEngineConnected(),AgePadEngineLoggedOn(),AgePadEngineLogonState(),(current&0xffffffffULL)!=0);
        fflush(stdout);sleep(2);
    }
    }
    return 0;
}
