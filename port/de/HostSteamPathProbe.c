// Observe the real supplied SDK's host discovery request/response. No mutation.
#include <mach/mach.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
static int output=-1;
static _Thread_local int pending;
static mach_msg_return_t ObserveMessage(mach_msg_header_t *msg,mach_msg_option_t options,
        mach_msg_size_t sendSize,mach_msg_size_t receiveSize,mach_port_name_t receiveName,
        mach_msg_timeout_t timeout,mach_port_name_t notify) {
    int saved=errno;
    uint32_t opcode=0;
    if ((options&MACH_SEND_MSG) && sendSize==32) {
        memcpy(&opcode,(char *)msg+24,4);
        if (opcode==14) {
            pending=1;
            fprintf(stderr,"DE_HOST_PATH_REQUEST id=%d bits=%u options=%u bytes=%u\n",msg->msgh_id,msg->msgh_bits,options,sendSize);
        }
    }
    errno=saved;
    mach_msg_return_t result=mach_msg(msg,options,sendSize,receiveSize,receiveName,timeout,notify);
    saved=errno;
    if (pending && result==MACH_MSG_SUCCESS && (options&MACH_RCV_MSG)) {
        pending=0;
        if (msg->msgh_size==544 && receiveSize>=544) {
            uint32_t pid=0;memcpy(&pid,(char *)msg+28,4);
            fprintf(stderr,"DE_HOST_PATH_REPLY id=%d bytes=%u pid_present=%d path_present=%d\n",msg->msgh_id,msg->msgh_size,pid!=0,((char *)msg)[32]!=0);
            if (output>=0) {
                ssize_t count=write(output,(char *)msg+24,520);
                fprintf(stderr,"DE_HOST_PATH_CAPTURE bytes=%zd\n",count);
                close(output);output=-1;
            }
        }
    }
    errno=saved;return result;
}
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } ObserveInterpose={
    (const void *)ObserveMessage,(const void *)mach_msg
};
#ifdef DE_OBSERVER_LIBRARY
__attribute__((constructor)) static void ObserveStart(void) {
    const char *path=getenv("AGEPAD_HOST_PATH_CAPTURE");
    if (path) output=open(path,O_WRONLY|O_CREAT|O_EXCL,0600);
}
#else
int main(int argc,char **argv) {
    if (argc!=4) return 64;
    if (chdir(argv[3])) return 67;
    output=open(argv[2],O_WRONLY|O_CREAT|O_EXCL,0600);
    if (output<0) return 65;
    void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    bool (*running)(void)=handle?dlsym(handle,"SteamAPI_IsSteamRunning"):NULL;
    const char *(*path)(void)=handle?dlsym(handle,"SteamAPI_GetSteamInstallPath"):NULL;
    if (!running || !path) { close(output);return 66; }
    bool live=running();const char *install=path();
    printf("DE_HOST_DISCOVERY running=%d public_getter_is_dot=%d\n",live,install && strcmp(install,".")==0);
    bool (*initialize)(void)=dlsym(handle,"SteamAPI_Init");
    void (*shutdown)(void)=dlsym(handle,"SteamAPI_Shutdown");
    if (!initialize || !shutdown) {if (output>=0) close(output);return 68;}
    bool initialized=initialize();
    printf("DE_HOST_SDK initialized=%d\n",initialized);
    if (initialized) shutdown();
    if (output>=0) close(output);
    return live?0:1;
}
#endif
