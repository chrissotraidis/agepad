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
#define DE_PATH_RELAY_CLIENT 1
#include "SteamPathRelay.h"
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
