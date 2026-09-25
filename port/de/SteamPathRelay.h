#pragma once
// Local diagnostic transport for a fresh, genuine host path response only.
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <poll.h>
#include <fcntl.h>
#include <netinet/tcp.h>
typedef struct { int32_t status; unsigned char payload[520]; } DEPathResponse;
static int DEPathTransfer(int fd,void *bytes,size_t count,int sending) {
    size_t offset=0;
    while (offset<count) {
        ssize_t n=sending?write(fd,(char *)bytes+offset,count-offset):read(fd,(char *)bytes+offset,count-offset);
        if (n<0 && errno==EINTR) continue;
        if (n<=0) return -1;
        offset+=(size_t)n;
    }
    return 0;
}
static void DEPathSocketOptions(int fd) {
    int yes=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));
    // Steam IPC is thousands of tiny request/reply messages; with Nagle plus
    // delayed ACKs each one waited up to ~200 ms on Wi-Fi (startup crawled at
    // ~2 KB/s). Send immediately.
    setsockopt(fd,IPPROTO_TCP,TCP_NODELAY,&yes,sizeof(yes));
    struct timeval timeout={2,0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
    setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
}
#ifdef DE_PATH_RELAY_CLIENT
static int DEPairedTunnelAddress(const char *text,struct in6_addr *address) {
    if (!text || !address) return -1;
    if (strcmp(text,"paired-tunnel")!=0)
        return inet_pton(AF_INET6,text,address)==1?0:-1;
    struct ifaddrs *interfaces=NULL;
    if (getifaddrs(&interfaces)) return -1;
    int found=-1;
    for (struct ifaddrs *it=interfaces;it;it=it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family!=AF_INET6 ||
            !it->ifa_name || strncmp(it->ifa_name,"utun",4)!=0) continue;
        struct in6_addr candidate=((struct sockaddr_in6 *)it->ifa_addr)->sin6_addr;
        if ((candidate.s6_addr[0]&0xfe)!=0xfc || candidate.s6_addr[15]!=1) continue;
        int zero=1;
        for (int i=8;i<15;i++) if (candidate.s6_addr[i]) zero=0;
        if (!zero) continue;
        candidate.s6_addr[15]=2;
        *address=candidate;
        found=0;
        break;
    }
    freeifaddrs(interfaces);
    return found;
}
// Connect to the Mac Steam relay. `hosts` is "paired-tunnel" (USB/CoreDevice
// link), an IP literal, a host name, or a comma-separated list tried in order
// (e.g. home Wi-Fi address, then a Tailscale address). When a pairing key is
// configured (AGEPAD_RELAY_TOKEN), every connection starts with
// "AGEPAD1 <mode> <key>\n" so the Mac helper serves only this paired iPad.
// Modes: S = Steam client stream, P = Steam path query, I = helper info.
// Returns a connected blocking socket, or -1 with errno set.
static int DERelayConnectOne(const struct sockaddr *address,socklen_t length,int timeoutMs) {
    int fd=socket(address->sa_family,SOCK_STREAM,0);
    if (fd<0) return -1;
    int yes=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));
    int flags=fcntl(fd,F_GETFL);fcntl(fd,F_SETFL,flags|O_NONBLOCK);
    int result=connect(fd,address,length);
    if (result<0 && errno==EINPROGRESS) {
        struct pollfd pending={.fd=fd,.events=POLLOUT};
        int failure=0;socklen_t size=sizeof(failure);
        int waited=poll(&pending,1,timeoutMs);
        if (waited>0 && getsockopt(fd,SOL_SOCKET,SO_ERROR,&failure,&size)==0 && !failure) result=0;
        else { errno=waited==0?ETIMEDOUT:(failure?failure:errno);result=-1; }
    }
    if (result) { int saved=errno;close(fd);errno=saved;return -1; }
    fcntl(fd,F_SETFL,flags&~O_NONBLOCK);
    return fd;
}
static int DERelayConnect(const char *hosts,int port,char mode) {
    if (!hosts || port<1024 || port>65535) { errno=EINVAL;return -1; }
    const char *token=getenv("AGEPAD_RELAY_TOKEN");
    char list[512];snprintf(list,sizeof list,"%s",hosts);
    int fd=-1,lastErrno=EHOSTUNREACH;
    for (char *cursor=list,*host;fd<0 && (host=strsep(&cursor,","));) {
        while (*host==' ') host++;
        if (!*host) continue;
        struct in6_addr tunnel;
        if (!strcmp(host,"paired-tunnel")) {
            if (DEPairedTunnelAddress(host,&tunnel)) continue;
            struct sockaddr_in6 address={.sin6_len=sizeof(address),.sin6_family=AF_INET6,.sin6_port=htons((uint16_t)port),.sin6_addr=tunnel};
            fd=DERelayConnectOne((struct sockaddr *)&address,sizeof(address),2000);
            if (fd<0) lastErrno=errno;
            continue;
        }
        char service[8];snprintf(service,sizeof service,"%d",port);
        struct addrinfo hints={.ai_family=AF_UNSPEC,.ai_socktype=SOCK_STREAM},*results=NULL;
        if (getaddrinfo(host,service,&hints,&results)) continue;
        for (struct addrinfo *it=results;it && fd<0;it=it->ai_next) {
            fd=DERelayConnectOne(it->ai_addr,it->ai_addrlen,1500);
            if (fd<0) lastErrno=errno;
        }
        freeaddrinfo(results);
    }
    if (fd<0) { errno=lastErrno;return -1; }
    if (token && *token) {
        char header[160];
        int length=snprintf(header,sizeof header,"AGEPAD1 %c %s\n",mode,token);
        if (length<=0 || length>=(int)sizeof header || DEPathTransfer(fd,header,(size_t)length,1)) { close(fd);errno=EPROTO;return -1; }
    }
    return fd;
}
static int DEGetRelayedPath(const char *path,DEPathResponse *response) {
    struct sockaddr_un address={0};address.sun_family=AF_UNIX;
    int trace=getenv("AGEPAD_IPC_TRACE")!=NULL;
    size_t pathLength=strlen(path);
    if (pathLength>=sizeof(address.sun_path)) {
        if(trace) fprintf(stderr,"DE_IPC_RELAY stage=path_length result=-1 errno=%d path_length=%zu\n",ENAMETOOLONG,pathLength);
        return -1;
    }
    strcpy(address.sun_path,path);
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if(fd<0) {
        if(trace) fprintf(stderr,"DE_IPC_RELAY stage=socket result=-1 errno=%d path_length=%zu\n",errno,pathLength);
        return -1;
    }
    DEPathSocketOptions(fd);
    const char *stage="connect";
    int result=connect(fd,(struct sockaddr *)&address,sizeof(address));
    char request[8]={'A','G','E','P','A','T','H','1'};
    if (!result) {stage="write";result=DEPathTransfer(fd,request,sizeof(request),1);}
    if (!result) {stage="read";result=DEPathTransfer(fd,response,sizeof(*response),0);}
    int saved=errno;
    if(trace && result) fprintf(stderr,"DE_IPC_RELAY stage=%s result=%d errno=%d path_length=%zu\n",stage,result,saved,pathLength);
    close(fd);return result;
}
static int DEGetRelayedPathTCP(const char *host,int port,DEPathResponse *response) {
    int fd=DERelayConnect(host,port,'P');
    if(fd<0)return -1;
    DEPathSocketOptions(fd);
    char request[8]={'A','G','E','P','A','T','H','1'};
    int result=DEPathTransfer(fd,request,sizeof(request),1);
    if(!result)result=DEPathTransfer(fd,response,sizeof(*response),0);
    close(fd);
    return result;
}
#endif
