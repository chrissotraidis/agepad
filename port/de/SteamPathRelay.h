#pragma once
// Local diagnostic transport for a fresh, genuine host path response only.
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/time.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
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
    struct timeval timeout={2,0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
    setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
}
#ifdef DE_PATH_RELAY_CLIENT
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
#endif
