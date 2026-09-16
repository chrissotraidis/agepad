#include "HostSteamPathQuery.h"
#include <fcntl.h>
#include <stdio.h>
int main(int argc,char **argv) {
    if (argc!=2) return 64;
    unsigned char payload[520]={0};
    kern_return_t status=DEReadHostSteamPath(payload);
    uint32_t pid=0;memcpy(&pid,payload+4,4);
    printf("DE_HOST_QUERY status=%d pid_present=%d path_present=%d\n",status,pid!=0,payload[8]!=0);
    if (status!=KERN_SUCCESS) return 1;
    int file=open(argv[1],O_WRONLY|O_CREAT|O_EXCL,0600);
    if (file<0) return 65;
    ssize_t written=write(file,payload,sizeof(payload));close(file);
    return written==sizeof(payload)?0:66;
}
