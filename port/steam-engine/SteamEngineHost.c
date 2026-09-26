#include "SteamEngineHost.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef int32_t HSteamPipe,HSteamUser;
static void *Engine,*User;
static HSteamPipe Pipe;
static HSteamUser GlobalUser;
static struct { int logOn,logOff,loggedOn,logonState,connected,steamID,setLoginToken,logOnOffline,subscribed,canOffline; } Method;

static void *Slot(void *object,int slot) { return (*(void ***)object)[slot]; }
static const char *TypeName(void *object) {
    void **typeinfo=(void **)(*(void ***)object)[-1];
    return typeinfo?(const char *)typeinfo[1]:"";
}
// Each IClientUser proxy method passes its own name to the IPC call in x4
// (adrp x4 / add x4, x4, #off). Read that name; stop at the method's ret.
static const char *ProxyMethodName(void *function) {
    const uint32_t *code=(const uint32_t *)function;
    uintptr_t page=0;
    for (int i=0;i<256;i++) {
        uint32_t insn=code[i];
        if (insn==0xd65f03c0) return NULL; // ret
        if ((insn&0x9f00001f)==0x90000004) { // adrp x4
            int64_t imm=(int64_t)((((insn>>5)&0x7ffff)<<2)|((insn>>29)&3));
            if (imm&(1<<20)) imm-=1<<21;
            page=((uintptr_t)&code[i]&~(uintptr_t)0xfff)+(uintptr_t)(imm<<12);
        } else if ((insn&0xffc003ff)==0x91000084 && page) { // add x4, x4, #imm
            return (const char *)(page+((insn>>10)&0xfff));
        }
    }
    return NULL;
}
static int FindMethod(const char *name,void *image) {
    Dl_info base;
    if (!dladdr(image,&base)) return -1;
    for (int slot=0;slot<400;slot++) {
        Dl_info info;void *function=Slot(User,slot);
        if (!dladdr(function,&info) || info.dli_fbase!=base.dli_fbase) break; // end of vtable
        const char *found=ProxyMethodName(function);
        if (found && strcmp(found,name)==0) return slot;
    }
    return -1;
}
static void *Pump(void *unused) {
    (void)unused;
    for (;;) { ((void (*)(void *))Slot(Engine,19))(Engine);usleep(10000); } // RunFrame
    return NULL;
}
bool AgePadEngineStart(void *image,char *error,unsigned long errorSize) {
    if (User) return true; // one engine per process; later sign-ins reuse it
    void *(*create)(const char *,int *)=(void *(*)(const char *,int *))dlsym(image,"CreateInterface");
    int status=0;
    Engine=create?create("CLIENTENGINE_INTERFACE_VERSION005",&status):NULL;
    if (!Engine || !strstr(TypeName(Engine),"CSteamClient")) { snprintf(error,errorSize,"engine interface unavailable");return false; }
    GlobalUser=((HSteamUser (*)(void *,HSteamPipe *))Slot(Engine,2))(Engine,&Pipe); // CreateGlobalUser
    if (!GlobalUser || !Pipe) { snprintf(error,errorSize,"CreateGlobalUser failed");return false; }
    User=((void *(*)(void *,HSteamUser,HSteamPipe))Slot(Engine,8))(Engine,GlobalUser,Pipe); // IClientUser
    if (!User || strcmp(TypeName(User),"14IClientUserMap")) { snprintf(error,errorSize,"IClientUser not at the expected slot (%s)",User?TypeName(User):"null");return false; }
    struct { const char *name;int *slot; } wanted[]={
        {"LogOn",&Method.logOn},{"LogOff",&Method.logOff},{"BLoggedOn",&Method.loggedOn},
        {"GetLogonState",&Method.logonState},{"BConnected",&Method.connected},{"GetSteamID",&Method.steamID},
        {"SetLoginToken",&Method.setLoginToken},{"LogOnOffline",&Method.logOnOffline},{"BIsSubscribedApp",&Method.subscribed},
        {"CanLogonOffline",&Method.canOffline}};
    for (unsigned i=0;i<sizeof(wanted)/sizeof(*wanted);i++) {
        *wanted[i].slot=FindMethod(wanted[i].name,(void *)create);
        if (*wanted[i].slot<0) { snprintf(error,errorSize,"IClientUser::%s not found",wanted[i].name);return false; }
    }
    pthread_t thread;pthread_create(&thread,NULL,Pump,NULL);pthread_detach(thread);
    return true;
}
void AgePadEngineSetLoginToken(const char *token,const char *account) {
    ((void (*)(void *,const char *,const char *))Slot(User,Method.setLoginToken))(User,token,account);
}
int AgePadEngineLogOn(uint64_t steamID) { return ((int (*)(void *,uint64_t))Slot(User,Method.logOn))(User,steamID); }
int AgePadEngineLogOnOffline(void) { return ((int (*)(void *,bool))Slot(User,Method.logOnOffline))(User,true); }
void AgePadEngineLogOff(void) { ((void (*)(void *))Slot(User,Method.logOff))(User); }
bool AgePadEngineLoggedOn(void) { return User && ((bool (*)(void *))Slot(User,Method.loggedOn))(User); }
bool AgePadEngineConnected(void) { return User && ((bool (*)(void *))Slot(User,Method.connected))(User); }
int AgePadEngineLogonState(void) { return User?((int (*)(void *))Slot(User,Method.logonState))(User):-1; }
uint64_t AgePadEngineSteamID(void) { return User?((uint64_t (*)(void *))Slot(User,Method.steamID))(User):0; }
bool AgePadEngineOwnsApp(uint32_t appID) { return User && ((bool (*)(void *,uint32_t))Slot(User,Method.subscribed))(User,appID); }
int AgePadEngineCanLogOnOffline(void) { return User?((int (*)(void *))Slot(User,Method.canOffline))(User):-1; }
kern_return_t AgePadEngineRegister(const char *clientPath,kern_return_t (*lookUp)(mach_port_t,const char *,mach_port_t *)) {
    mach_port_t service=MACH_PORT_NULL;
    kern_return_t status=lookUp(bootstrap_port,"com.valvesoftware.steam.ipctool",&service);
    if (status!=KERN_SUCCESS) return status;
    struct { mach_msg_header_t header; uint32_t operation,pid; char path[512]; } request;
    memset(&request,0,sizeof(request));
    request.header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,0);
    request.header.msgh_size=sizeof(request);request.header.msgh_remote_port=service;request.header.msgh_id=104;
    request.operation=13;request.pid=(uint32_t)getpid();strlcpy(request.path,clientPath,sizeof(request.path));
    status=mach_msg(&request.header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,sizeof(request),0,MACH_PORT_NULL,2000,MACH_PORT_NULL);
    mach_port_deallocate(mach_task_self(),service);
    return status;
}
