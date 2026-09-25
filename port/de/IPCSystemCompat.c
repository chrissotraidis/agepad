// The Mac IPC helper imports a logging spelling absent from Simulator libSystem.
// Forward logging; an opt-in diagnostic relay carries genuine host path replies.
#include <stdarg.h>
#include <syslog.h>
#include <errno.h>
#include <mach/mach.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <TargetConditionals.h>
#include <stdatomic.h>
#include <mach-o/dyld.h>
#include <limits.h>
#define DE_PATH_RELAY_CLIENT 1
#include "SteamPathRelay.h"
// Device-only, opt-in experiment: keep the original helper's Mach service
// inside this app process. No Steam reply, identity or ownership state is
// synthesized here; the original helper still handles every request.
static mach_port_t DELocalSteamPort = MACH_PORT_NULL;
static _Atomic int32_t DEHostSteamPID;
static pthread_mutex_t DEHostPathLock=PTHREAD_MUTEX_INITIALIZER;
static char DEHostSteamExecutable[512];
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
        // A real lookup gives the caller its own send-right reference, which
        // the Steam client releases after each session. Match that so a later
        // client (the game's own Steam API) can still reach the same helper.
        kern_return_t status=mach_port_mod_refs(mach_task_self(),DELocalSteamPort,
                                                MACH_PORT_RIGHT_SEND,1);
        if (status!=KERN_SUCCESS) return status;
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
// Paired-Mac engineering relay only. Mac Steam tracks a connected game by a
// local process ID and drops the client once that PID is not a live Mac
// process; an iPad PID never is. The Steam images (only they link this shim)
// report the Mac relay's PID, which lives exactly as long as this relayed
// session. The game executable and iOS keep the real iPad PID.
static pid_t DEHostSessionPID(void) {
    const char *text=getenv("AGEPAD_HOST_SESSION_PID");
    if (!text || !getenv("AGEPAD_STEAM_TUNNEL_HOST")) return 0;
    char *end=NULL;
    long value=strtol(text,&end,10);
    return end && !*end && value>1 && value<INT32_MAX ? (pid_t)value : 0;
}
pid_t getpid(void) {
    static pid_t (*real)(void);
    if (!real) real=(pid_t (*)(void))dlsym(RTLD_NEXT,"getpid");
    pid_t host=DEHostSessionPID();
    if (host) {
        static atomic_flag reported=ATOMIC_FLAG_INIT;
        if (!atomic_flag_test_and_set(&reported)) {
            fprintf(stderr,"DE_IPC_HOST_SESSION_PID steam_images=relay local=%d\n",real?real():-1);fflush(stderr);
        }
        return host;
    }
    return real?real():-1;
}
static void DELogExitFrames(int status) {
    // Opt-in hardware diagnostic: Steam's fatal-assert path leaves through
    // _exit; record the calling thread's frames first, then exit unchanged.
    if (getenv("AGEPAD_DEVICE_MAIN_WATCHDOG")) {
        char line[512];
        int length=snprintf(line,sizeof(line),"DE_STEAM_EXIT status=%d\n",status);
        if (length>0) write(STDERR_FILENO,line,(size_t)length);
        uintptr_t fp=(uintptr_t)__builtin_frame_address(0);
        for (unsigned i=0;fp && i<40;i++) {
            uintptr_t frame[2];vm_size_t copied=0;
            if (vm_read_overwrite(mach_task_self(),fp,sizeof(frame),(vm_address_t)frame,&copied)!=KERN_SUCCESS ||
                copied!=sizeof(frame) || frame[0]<=fp) break;
            uintptr_t pc=frame[1]&0x0000000fffffffffULL;fp=frame[0];
            Dl_info info={0};
            if (dladdr((void *)pc,&info) && info.dli_fname) {
                const char *slash=strrchr(info.dli_fname,'/');
                length=snprintf(line,sizeof(line),"DE_STEAM_EXIT_FRAME %u %s+0x%lx %s\n",i,slash?slash+1:info.dli_fname,
                                (unsigned long)(pc-(uintptr_t)info.dli_fbase),info.dli_sname?info.dli_sname:"?");
                if (length>0) write(STDERR_FILENO,line,(size_t)length);
            }
        }
    }
}
int kill(pid_t pid,int signal) {
    pid_t sessionPID=DEHostSessionPID();
    if (signal!=0) {
        char line[160];
        int length=snprintf(line,sizeof(line),"DE_IPC_KILL pid=%d signal=%d session=%d caller=%p\n",
                            pid,signal,sessionPID&&pid==sessionPID,__builtin_return_address(0));
        if (length>0) write(STDERR_FILENO,line,(size_t)length);
    }
    if (sessionPID && pid==sessionPID) {
        // The Steam images asked about "themselves": act on this app process.
        pid_t (*realPID)(void)=(pid_t (*)(void))dlsym(RTLD_NEXT,"getpid");
        int (*realKill)(pid_t,int)=dlsym(RTLD_NEXT,"kill");
        return realPID && realKill ? realKill(realPID(),signal) : (errno=ENOSYS,-1);
    }
    int32_t observed=atomic_load(&DEHostSteamPID);
    const char *host=getenv("AGEPAD_HOST_PATH_RELAY_TCP_HOST");
    const char *port=getenv("AGEPAD_HOST_PATH_RELAY_TCP_PORT");
    if (signal==0 && observed>0 && pid==observed && host && port) {
        DEPathResponse current={0};
        int transport=DEGetRelayedPathTCP(host,atoi(port),&current);
        int32_t fresh=0;
        if (!transport && current.status==KERN_SUCCESS)
            memcpy(&fresh,current.payload+4,sizeof(fresh));
        int alive=!transport && current.status==KERN_SUCCESS && fresh==observed;
        fprintf(stderr,"DE_IPC_HOST_PID_CHECK transport=%d match=%d\n",transport,alive);fflush(stderr);
        if (alive) return 0;
        errno=ESRCH;
        return -1;
    }
    int (*real)(pid_t,int)=dlsym(RTLD_NEXT,"kill");
    return real?real(pid,signal):(errno=ENOSYS,-1);
}
void *dlopen(const char *path,int mode) {
    void *(*real)(const char *,int)=dlsym(RTLD_NEXT,"dlopen");
    if (!real) return NULL;
    if (path && atomic_load(&DEHostSteamPID)>0 &&
        getenv("AGEPAD_HOST_PATH_RELAY_TCP_HOST")) {
        char hostExecutable[sizeof(DEHostSteamExecutable)]={0};
        pthread_mutex_lock(&DEHostPathLock);
        memcpy(hostExecutable,DEHostSteamExecutable,sizeof(hostExecutable));
        pthread_mutex_unlock(&DEHostPathLock);
        const char *slash=strrchr(hostExecutable,'/');
        static const char clientName[]="steamclient.dylib";
        size_t prefix=slash?(size_t)(slash-hostExecutable+1):0;
        if (prefix && strlen(path)==prefix+sizeof(clientName)-1 &&
            memcmp(path,hostExecutable,prefix)==0 &&
            strcmp(path+prefix,clientName)==0) {
            char executable[PATH_MAX]={0};
            uint32_t size=sizeof(executable);
            if (_NSGetExecutablePath(executable,&size)==0) {
                char *deviceSlash=strrchr(executable,'/');
                if (deviceSlash && (size_t)(deviceSlash-executable)+
                    sizeof("/Frameworks/steamclient.dylib")<sizeof(executable)) {
                    strcpy(deviceSlash,"/Frameworks/steamclient.dylib");
                    void *local=real(executable,mode);
                    fprintf(stderr,"DE_IPC_LOCAL_STEAM_CLIENT mapped=%d\n",local!=NULL);fflush(stderr);
                    if (local) return local;
                }
            }
        }
    }
    return real(path,mode);
}
int connect(int fd,const struct sockaddr *address,socklen_t length) {
    int (*real)(int,const struct sockaddr *,socklen_t)=dlsym(RTLD_NEXT,"connect");
    int result=-1;
    const char *host=getenv("AGEPAD_STEAM_TUNNEL_HOST");
    const char *fromText=getenv("AGEPAD_STEAM_LOOPBACK_PORT");
    const char *toText=getenv("AGEPAD_STEAM_TUNNEL_PORT");
    int redirected=0;
    if (real && host && fromText && toText && address && address->sa_family==AF_INET &&
        length>=sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *original=(const struct sockaddr_in *)address;
        char *fromEnd=NULL,*toEnd=NULL;
        long from=strtol(fromText,&fromEnd,10),to=strtol(toText,&toEnd,10);
        struct sockaddr_in6 destination={.sin6_family=AF_INET6};
        if (*fromText && *toText && *fromEnd==0 && *toEnd==0 &&
            from>=1024 && from<=65535 && to>=1024 && to<=65535 &&
            original->sin_addr.s_addr==htonl(INADDR_LOOPBACK) &&
            ntohs(original->sin_port)==from &&
            DEPairedTunnelAddress(host,&destination.sin6_addr)==0) {
            destination.sin6_port=htons((uint16_t)to);
            int tunnel=socket(AF_INET6,SOCK_STREAM,0);
            if (tunnel>=0) {
                int flags=fcntl(fd,F_GETFL);
                if (flags>=0) fcntl(tunnel,F_SETFL,flags|O_NONBLOCK);
                result=real(tunnel,(const struct sockaddr *)&destination,sizeof(destination));
                int connectionErrno=result==0?0:errno;
                if (result<0 && connectionErrno==EINPROGRESS) {
                    struct pollfd pending={.fd=tunnel,.events=POLLOUT};
                    int waited=poll(&pending,1,2000);
                    int failure=0;
                    socklen_t failureSize=sizeof(failure);
                    if (waited>0 && getsockopt(tunnel,SOL_SOCKET,SO_ERROR,&failure,&failureSize)==0 && !failure) {
                        result=0;connectionErrno=0;
                    } else connectionErrno=waited==0?ETIMEDOUT:(failure?failure:errno);
                }
                if (result==0) {
                    if (flags>=0) fcntl(tunnel,F_SETFL,flags);
                    if (dup2(tunnel,fd)<0) {result=-1;connectionErrno=errno;}
                    else redirected=1;
                }
                close(tunnel);
                errno=connectionErrno;
            }
        } else result=real(fd,address,length);
    } else if (real) result=real(fd,address,length);
    else errno=ENOSYS;
    int saved=errno;
    if (getenv("AGEPAD_IPC_TRACE")) {
        const char *endpoint="non-unix";
        char path[sizeof(((struct sockaddr_un *)0)->sun_path)+1]={0};
        char ipv4[INET_ADDRSTRLEN]={0};
        if (address && address->sa_family==AF_UNIX && length>offsetof(struct sockaddr_un,sun_path)) {
            const struct sockaddr_un *unixAddress=(const struct sockaddr_un *)address;
            size_t bytes=length - offsetof(struct sockaddr_un,sun_path);
            if (bytes>sizeof(path)-1) bytes=sizeof(path)-1;
            memcpy(path,unixAddress->sun_path,bytes);
            const char *slash=strrchr(path,'/');
            endpoint=slash?slash+1:path;
        } else if (address && address->sa_family==AF_INET && length>=sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *internet=(const struct sockaddr_in *)address;
            if (inet_ntop(AF_INET,&internet->sin_addr,ipv4,sizeof(ipv4))) endpoint=ipv4;
        }
        int port=address && address->sa_family==AF_INET && length>=sizeof(struct sockaddr_in)
            ? ntohs(((const struct sockaddr_in *)address)->sin_port) : 0;
        fprintf(stderr,"DE_IPC_CONNECT family=%d endpoint=%s port=%d redirected=%d result=%d errno=%d\n",
            address?address->sa_family:-1,endpoint,port,redirected,result,saved);fflush(stderr);
    }
    errno=saved;
    return result;
}
__attribute__((noreturn)) void _exit(int status) {
    if (DEHelperThread) {
        fprintf(stderr,"DE_LOCAL_STEAM_HELPER_EXIT status=%d\n",status);fflush(stderr);
        if (MACH_PORT_VALID(DELocalSteamPort)) mach_port_destroy(mach_task_self(),DELocalSteamPort);
        DELocalSteamPort=MACH_PORT_NULL;
        pthread_exit((void *)(intptr_t)(status+1));
    }
    DELogExitFrames(status);
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
    const char *tcpHost=getenv("AGEPAD_HOST_PATH_RELAY_TCP_HOST");
    const char *tcpPort=getenv("AGEPAD_HOST_PATH_RELAY_TCP_PORT");
    if ((relay || (tcpHost && tcpPort)) && (options&MACH_SEND_MSG) &&
        DEIPCLastRequest==14 && sendSize==544) {
        DEPathResponse response={0};
        int transport=relay?DEGetRelayedPath(relay,&response):
            DEGetRelayedPathTCP(tcpHost,atoi(tcpPort),&response);
        if (!transport && response.status==KERN_SUCCESS && memchr(response.payload+8,0,512)) {
            memcpy((char *)message+24,response.payload,sizeof(response.payload));
            int32_t hostPid=0;
            memcpy(&hostPid,response.payload+4,sizeof(hostPid));
            if (hostPid>0) {
                pthread_mutex_lock(&DEHostPathLock);
                memcpy(DEHostSteamExecutable,response.payload+8,
                    sizeof(DEHostSteamExecutable));
                pthread_mutex_unlock(&DEHostPathLock);
                atomic_store(&DEHostSteamPID,hostPid);
            }
        }
        fprintf(stderr,"DE_IPC_HOST_PATH transport=%d host_status=%d\n",transport,transport?-1:response.status);fflush(stderr);
    }
    if (trace && (options&MACH_SEND_MSG) && DEIPCLastRequest==14 && sendSize>=33) {
        uint32_t pid=0;memcpy(&pid,(char *)message+28,4);
        fprintf(stderr,"DE_IPC_PATH_REPLY bytes=%u pid_present=%d path_present=%d\n",
            sendSize,pid!=0,((unsigned char *)message)[32]!=0);fflush(stderr);
    }
    errno=entryErrno;
#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    mach_msg_return_t (*real)(mach_msg_header_t *,mach_msg_option_t,mach_msg_size_t,
        mach_msg_size_t,mach_port_name_t,mach_msg_timeout_t,mach_port_name_t)=
        dlsym(RTLD_NEXT,"mach_msg");
    mach_msg_return_t result=real?real(message,options,sendSize,receiveSize,
        receiveName,timeout,notify):KERN_NOT_SUPPORTED;
#else
    mach_msg_return_t result=mach_msg(message,options,sendSize,receiveSize,receiveName,timeout,notify);
#endif
    if (trace) {
        fprintf(stderr,"DE_IPC_MACH_MSG options=%u send=%u receive=%u port=%u result=%d id=%d\n",
            options,sendSize,receiveSize,receiveName,result,message?message->msgh_id:0);fflush(stderr);
    }
    int saved=errno;
    if ((trace || relay || tcpHost) && result==MACH_MSG_SUCCESS && (options&MACH_RCV_MSG) &&
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
#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
mach_msg_return_t mach_msg(mach_msg_header_t *message,mach_msg_option_t options,
        mach_msg_size_t sendSize,mach_msg_size_t receiveSize,mach_port_name_t receiveName,
        mach_msg_timeout_t timeout,mach_port_name_t notify) {
    return DEIPCMessage(message,options,sendSize,receiveSize,receiveName,timeout,notify);
}
#else
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } DEIPCMessageInterpose={
    (const void *)DEIPCMessage,(const void *)mach_msg
};
#endif
void DEIPCSystemLog(int priority,const char *format,...) __asm("_syslog$DARWIN_EXTSN");
void DEIPCSystemLog(int priority,const char *format,...) {
    int saved=errno;
    va_list arguments;
    va_start(arguments,format);
    vsyslog(priority,format,arguments);
    va_end(arguments);
    errno=saved;
}
