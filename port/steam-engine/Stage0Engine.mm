// Stage 0a-ii (Mac): start Valve's client engine from an isolated Steam
// folder, identify its interfaces by C++ type name, pump frames and report
// whether it connects to Steam's servers. No sign-in is attempted.
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <cxxabi.h>
#include <pthread.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>
#import "SteamQRSignIn.h"
typedef int32_t HSteamPipe, HSteamUser;
static const char *TypeName(void *object) {
    if (!object) return "null";
    void **vtable=*(void ***)object;
    void **typeinfo=(void **)vtable[-1];
    if (!typeinfo) return "?";
    return (const char *)typeinfo[1];
}
static void *Slot(void *object,int slot) { return (*(void ***)object)[slot]; }
static void *PumpEngine(void *engine) {
    for (;;) { ((void (*)(void *))Slot(engine,19))(engine);usleep(10000); } // RunFrame
    return NULL;
}
// What steam_osx does as Steam's launcher: tell Valve's ipcserver which
// process and install path hold the running client (operation 13; operation
// 14 is the read games use). Games then load steamclient from that folder.
static kern_return_t RegisterWithIPCServer(const char *executablePath) {
    mach_port_t service=MACH_PORT_NULL;
    kern_return_t status=bootstrap_look_up(bootstrap_port,"com.valvesoftware.steam.ipctool",&service);
    if (status!=KERN_SUCCESS) return status;
    struct { mach_msg_header_t header; uint32_t operation; uint32_t pid; char path[512]; } request={};
    request.header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,0);
    request.header.msgh_size=sizeof(request);request.header.msgh_remote_port=service;request.header.msgh_id=104;
    request.operation=13;request.pid=getpid();strlcpy(request.path,executablePath,sizeof(request.path));
    status=mach_msg(&request.header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,sizeof(request),0,MACH_PORT_NULL,2000,MACH_PORT_NULL);
    mach_port_deallocate(mach_task_self(),service);
    return status;
}
// Game side: Valve's unmodified libsteam_api from the owned DE install, in
// the same process as the engine. Every answer comes from the real engine.
static void GameSide(const char *path) {
    void *api=dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if (!api) { printf("GAME_API_LOAD_FAILED %s\n",dlerror());return; }
    setenv("SteamAppId","813780",1);setenv("SteamGameId","813780",1);
    bool (*init)(void)=(bool (*)(void))dlsym(api,"SteamAPI_Init");
    bool ok=init();
    int pipe=((int (*)(void))dlsym(api,"SteamAPI_GetHSteamPipe"))();
    int user=((int (*)(void))dlsym(api,"SteamAPI_GetHSteamUser"))();
    printf("GAME_STEAMAPI_INIT ok=%d pipe=%d user=%d\n",ok,pipe,user);fflush(stdout);
    if (!ok) return;
    void *steamUser=((void *(*)(void))dlsym(api,"SteamAPI_SteamUser_v021"))();
    void *steamApps=((void *(*)(void))dlsym(api,"SteamAPI_SteamApps_v008"))();
    for (int i=0;i<6;i++) {
        ((void (*)(void))dlsym(api,"SteamAPI_RunCallbacks"))();
        bool loggedOn=((bool (*)(void *))dlsym(api,"SteamAPI_ISteamUser_BLoggedOn"))(steamUser);
        bool owns=((bool (*)(void *,uint32_t))dlsym(api,"SteamAPI_ISteamApps_BIsSubscribedApp"))(steamApps,813780);
        printf("GAME_STATE logged_on=%d owns_aoe2de=%d\n",loggedOn,owns);fflush(stdout);
        sleep(2);
    }
}
int main(int argc,char **argv) {
    if (argc<2) { fprintf(stderr,"usage: Stage0Engine steamclient.dylib [seconds]\n");return 64; }
    int seconds=argc>2?atoi(argv[2]):20;
    // Optional QR sign-in before the engine starts. The token is handed to the
    // engine in memory and never written or printed by this probe.
    NSDictionary *signIn=nil;
    if (getenv("STAGE0_SIGNIN")) {
        NSString *qrPath=[NSString stringWithUTF8String:getenv("STAGE0_SIGNIN")];
        NSString *error=nil;
        signIn=AgePadSteamQRSignIn(@"AgePad iPad",300,^(NSString *challenge) {
            // A self-refreshing page, since Steam rotates the code about every 30 s.
            NSString *png=[AgePadSteamQRPNG(challenge,600) base64EncodedStringWithOptions:0];
            NSString *page=[NSString stringWithFormat:@"<html><head><meta http-equiv=refresh content=2><title>AgePad Steam sign-in</title></head>"
                "<body style='font:24px -apple-system;text-align:center;margin-top:40px'><p>Scan with the Steam app (Steam Guard &rarr; scan QR)</p>"
                "<img width=420 src='data:image/png;base64,%@'></body></html>",png];
            [page writeToFile:qrPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            printf("SIGNIN_QR_READY %s\n",qrPath.UTF8String);fflush(stdout);
        },&error);
        if (!signIn) { printf("SIGNIN_FAILED %s\n",error.UTF8String);return 3; }
        printf("SIGNIN_OK account=%s steam_id=%s\n",[signIn[AgePadSteamAccountName] UTF8String],[signIn[AgePadSteamID64] UTF8String]);fflush(stdout);
    }
    void *client=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if (!client) { printf("ENGINE_LOAD_FAILED %s\n",dlerror());return 1; }
    void *(*create)(const char *,int *)=(void *(*)(const char *,int *))dlsym(client,"CreateInterface");
    int status=0;void *engine=create("CLIENTENGINE_INTERFACE_VERSION005",&status);
    printf("ENGINE object=%p type=%s\n",engine,TypeName(engine));
    HSteamPipe pipe=0;
    HSteamUser user=((HSteamUser(*)(void *,HSteamPipe *))Slot(engine,2))(engine,&pipe);
    printf("ENGINE_GLOBAL_USER user=%d pipe=%d\n",user,pipe);fflush(stdout);
    if (!user || !pipe) return 2;
    // Candidate interface getters: identify each by the returned object's type.
    int getters[]={8,9,10,13,15,16,17,18,21,22,23,24,25,27,34,35,43,44,46,47,50,51,52,54,55,57,58,59,60,62,63,64,65,67,69,70,71,72,74,75,76,79};
    void *userInterface=NULL;
    for (unsigned i=0;i<sizeof(getters)/sizeof(*getters);i++) {
        void *object=((void *(*)(void *,HSteamUser,HSteamPipe))Slot(engine,getters[i]))(engine,user,pipe);
        const char *name=TypeName(object);
        int demangled=0;char *pretty=abi::__cxa_demangle(name,NULL,NULL,&demangled);
        printf("ENGINE_SLOT %d type=%s\n",getters[i],pretty?pretty:name);free(pretty);
        if (object && strstr(name,"IClientUser") && !strstr(name,"Stats")) userInterface=object;
    }
    fflush(stdout);
    if (getenv("STAGE0_DUMP") && userInterface) {
        Dl_info base;dladdr((void *)create,&base);
        for (int s=0;s<400;s++) {
            void *fn=Slot(userInterface,s);Dl_info info;
            if (!dladdr(fn,&info) || info.dli_fbase!=base.dli_fbase) break;
            printf("USER_SLOT %d off=0x%lx\n",s,(unsigned long)((char *)fn-(char *)base.dli_fbase));
        }
        return 0;
    }
    // IClientUser slots, read from each proxy method's own name string
    // (generated/steam-engine/user-slot-names.txt).
    enum { kLogOn=1,kLogOff=3,kBLoggedOn=4,kGetLogonState=5,kBConnected=6,kGetSteamID=10,kSetLoginToken=56,kCanLogonOffline=214,kLogOnOffline=215 };
    if (!userInterface) return 4;
    uint64_t steamID=0;
    if (signIn) {
        ((void (*)(void *,const char *,const char *))Slot(userInterface,kSetLoginToken))(userInterface,[signIn[AgePadSteamRefreshToken] UTF8String],[signIn[AgePadSteamAccountName] UTF8String]);
        steamID=strtoull([signIn[AgePadSteamID64] UTF8String],NULL,10);
        signIn=nil;
    } else if (getenv("STAGE0_STEAMID")) steamID=strtoull(getenv("STAGE0_STEAMID"),NULL,10);
    if (steamID) {
        int offline=getenv("STAGE0_OFFLINE")!=NULL;
        int result=offline?((int (*)(void *,bool))Slot(userInterface,kLogOnOffline))(userInterface,true)
                          :((int (*)(void *,uint64_t))Slot(userInterface,kLogOn))(userInterface,steamID);
        printf("ENGINE_LOGON offline=%d result=%d\n",offline,result);fflush(stdout);
    }
    pthread_t pump;pthread_create(&pump,NULL,PumpEngine,engine);
    if (getenv("STAGE0_GAME")) {
        // A game can only attach to a signed-in (or offline-signed-in) user.
        for (int i=0;i<60 && !((bool (*)(void *))Slot(userInterface,kBLoggedOn))(userInterface);i++) sleep(1);
        printf("IPCSERVER_REGISTER status=%d\n",RegisterWithIPCServer(getenv("STAGE0_REGISTER_PATH")?:argv[1]));fflush(stdout);
        GameSide(getenv("STAGE0_GAME"));
    }
    for (int t=0;t<seconds*10;t++) {
        if (t%20==0) {
            int connected=((bool (*)(void *))Slot(userInterface,kBConnected))(userInterface);
            int loggedOn=((bool (*)(void *))Slot(userInterface,kBLoggedOn))(userInterface);
            int logonState=((int (*)(void *))Slot(userInterface,kGetLogonState))(userInterface);
            int canOffline=((bool (*)(void *))Slot(userInterface,kCanLogonOffline))(userInterface);
            uint64_t current=((uint64_t (*)(void *))Slot(userInterface,kGetSteamID))(userInterface);
            printf("ENGINE_STATE seconds=%d connected=%d logged_on=%d logon_state=%d can_offline=%d steam_id_set=%d\n",
                t/10,connected,loggedOn,logonState,canOffline,current!=0 && (current&0xffffffffULL)!=0);fflush(stdout);
        }
        usleep(100000);
    }
    return 0;
}
