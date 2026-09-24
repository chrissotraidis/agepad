// The Mac IPC helper imports a logging spelling absent from Simulator libSystem.
// Forward logging; an opt-in diagnostic relay carries genuine host path replies.
#include <stdarg.h>
#include <syslog.h>
#include <errno.h>
#include <mach/mach.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <pthread.h>
#define DE_PATH_RELAY_CLIENT 1
#include "SteamPathRelay.h"
// Device-only, opt-in experiment: keep the original helper's Mach service
// inside this app process. No Steam reply, identity or ownership state is
// synthesized here; the original helper still handles every request.
static mach_port_t DELocalSteamPort = MACH_PORT_NULL;
static _Thread_local int DEHelperThread;
void DEIPCMarkHelperThread(void) {
    DEHelperThread=1;
    if (getenv("AGEPAD_DEVICE_LOCAL_IPC_PROBE")) setenv("AGEPAD_IPC_TRACE","1",1);
}
int DELocalServiceReady(void) { return MACH_PORT_VALID(DELocalSteamPort); }
kern_return_t bootstrap_check_in(mach_port_t bootstrap,const char *name,mach_port_t *service) {
    if (getenv("AGEPAD_DEVICE_LOCAL_IPC_PROBE") && name &&
        strcmp(name,"com.valvesoftware.steam.ipctool")==0 && service) {
        if (MACH_PORT_VALID(DELocalSteamPort)) return 1101;
        mach_port_t port=MACH_PORT_NULL;
        kern_return_t status=mach_port_allocate(mach_task_self(),MACH_PORT_RIGHT_RECEIVE,&port);
        if (status!=KERN_SUCCESS) return status;
        status=mach_port_insert_right(mach_task_self(),port,port,MACH_MSG_TYPE_MAKE_SEND);
        if (status!=KERN_SUCCESS) {mach_port_destroy(mach_task_self(),port);return status;}
        DELocalSteamPort=port;*service=port;
        fprintf(stderr,"DE_LOCAL_STEAM_HELPER_CHECKIN port=%u\n",port);fflush(stderr);
        return KERN_SUCCESS;
    }
    kern_return_t (*real)(mach_port_t,const char *,mach_port_t *)=dlsym(RTLD_NEXT,"bootstrap_check_in");
    return real?real(bootstrap,name,service):KERN_NOT_SUPPORTED;
}
kern_return_t bootstrap_look_up(mach_port_t bootstrap,const char *name,mach_port_t *service) {
    if (getenv("AGEPAD_IPC_TRACE") && name) {
        fprintf(stderr,"DE_IPC_LOOKUP name=%s ready=%d\n",name,DELocalServiceReady());fflush(stderr);
    }
    if (getenv("AGEPAD_DEVICE_LOCAL_IPC_PROBE") && name &&
        strcmp(name,"com.valvesoftware.steam.ipctool")==0 && service &&
        MACH_PORT_VALID(DELocalSteamPort)) {
        *service=DELocalSteamPort;
        fprintf(stderr,"DE_LOCAL_STEAM_CLIENT_LOOKUP port=%u\n",DELocalSteamPort);fflush(stderr);
        return KERN_SUCCESS;
    }
    kern_return_t (*real)(mach_port_t,const char *,mach_port_t *)=dlsym(RTLD_NEXT,"bootstrap_look_up");
    return real?real(bootstrap,name,service):KERN_NOT_SUPPORTED;
}
void *launch_msg(const void *request) {
    void *(*real)(const void *)=dlsym(RTLD_NEXT,"launch_msg");
    void *reply=real?real(request):NULL;
    if (getenv("AGEPAD_IPC_TRACE")) {
        fprintf(stderr,"DE_IPC_LAUNCH_MSG request=%d reply=%d\n",request!=NULL,reply!=NULL);fflush(stderr);
    }
    return reply;
}
__attribute__((noreturn)) void _exit(int status) {
    if (DEHelperThread) {
        fprintf(stderr,"DE_LOCAL_STEAM_HELPER_EXIT status=%d\n",status);fflush(stderr);
        if (MACH_PORT_VALID(DELocalSteamPort)) mach_port_destroy(mach_task_self(),DELocalSteamPort);
        DELocalSteamPort=MACH_PORT_NULL;
        pthread_exit((void *)(intptr_t)(status+1));
    }
    void (*real)(int)=dlsym(RTLD_NEXT,"_exit");
    if (real) real(status);
    __builtin_trap();
}
// Optional diagnostics report only the GetSteamPath message shape/presence.
// The optional relay replaces only path-reply payloads with fresh host responses.
// It does not synthesize registration, account state or authentication results.
static _Thread_local unsigned DEIPCLastRequest;
static mach_msg_return_t DEIPCMessage(mach_msg_header_t *message,mach_msg_option_t options,
        mach_msg_size_t sendSize,mach_msg_size_t receiveSize,mach_port_name_t receiveName,
        mach_msg_timeout_t timeout,mach_port_name_t notify) {
    int entryErrno=errno;
    int trace=getenv("AGEPAD_IPC_TRACE")!=NULL;
    const char *relay=getenv("AGEPAD_HOST_PATH_RELAY");
    if (relay && (options&MACH_SEND_MSG) && DEIPCLastRequest==14 && sendSize==544) {
        DEPathResponse response={0};
        int transport=DEGetRelayedPath(relay,&response);
        if (!transport && response.status==KERN_SUCCESS && memchr(response.payload+8,0,512))
            memcpy((char *)message+24,response.payload,sizeof(response.payload));
        fprintf(stderr,"DE_IPC_HOST_PATH transport=%d host_status=%d\n",transport,transport?-1:response.status);fflush(stderr);
    }
    if (trace && (options&MACH_SEND_MSG) && DEIPCLastRequest==14 && sendSize>=33) {
        uint32_t pid=0;memcpy(&pid,(char *)message+28,4);
        fprintf(stderr,"DE_IPC_PATH_REPLY bytes=%u pid_present=%d path_present=%d\n",
            sendSize,pid!=0,((unsigned char *)message)[32]!=0);fflush(stderr);
    }
    errno=entryErrno;
    mach_msg_return_t result=mach_msg(message,options,sendSize,receiveSize,receiveName,timeout,notify);
    if (trace) {
        fprintf(stderr,"DE_IPC_MACH_MSG options=%u send=%u receive=%u port=%u result=%d id=%d\n",
            options,sendSize,receiveSize,receiveName,result,message?message->msgh_id:0);fflush(stderr);
    }
    int saved=errno;
    if ((trace || relay) && result==MACH_MSG_SUCCESS && (options&MACH_RCV_MSG) &&
        receiveSize>=28 && message->msgh_size>=28) {
        uint32_t request=0;memcpy(&request,(char *)message+24,4);
        DEIPCLastRequest=request;
        if (request==13 || request==14) {
            fprintf(stderr,"DE_IPC_PATH_REQUEST opcode=%u bytes=%u\n",request,message->msgh_size);fflush(stderr);
        }
    }
    errno=saved;
    return result;
}
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DEIPCMessageInterpose={
    (const void *)DEIPCMessage,(const void *)mach_msg
};
void DEIPCSystemLog(int priority,const char *format,...) __asm("_syslog$DARWIN_EXTSN");
void DEIPCSystemLog(int priority,const char *format,...) {
    int saved=errno;
    va_list arguments;
    va_start(arguments,format);
    vsyslog(priority,format,arguments);
    va_end(arguments);
    errno=saved;
}
