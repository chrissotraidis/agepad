#include "HostSteamPathQuery.h"
#include "SteamPathRelay.h"
#include <sys/stat.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
int main(int argc,char **argv) {
    if(argc!=3)return 64;
    char *end=NULL;long limit=strtol(argv[2],&end,10);
    // limit 0 = serve until stopped (AgePad helper); otherwise a bounded test run.
    if(!end || *end || limit<0 || limit>32)return 64;
    struct sockaddr_un address={0};address.sun_family=AF_UNIX;
    if(strlen(argv[1])>=sizeof(address.sun_path))return 64;
    strcpy(address.sun_path,argv[1]);umask(077);
    int listener=socket(AF_UNIX,SOCK_STREAM,0);if(listener<0)return 65;
    // bind refuses an existing path; never replace another service's socket.
    if(bind(listener,(struct sockaddr *)&address,sizeof(address)) || listen(listener,2)){close(listener);return 66;}
    puts("DE_HOST_PATH_RELAY_READY");fflush(stdout);
    time_t deadline=time(NULL)+60;
    for(long i=0;limit==0 || (i<limit && time(NULL)<deadline);) {
        struct pollfd pfd={listener,POLLIN,0};
        if(poll(&pfd,1,1000)<=0)continue;
        int peer=accept(listener,NULL,NULL);if(peer<0)continue;
        DEPathSocketOptions(peer);uid_t uid;gid_t gid;
        char request[8];
        if(getpeereid(peer,&uid,&gid) || uid!=getuid() ||
           DEPathTransfer(peer,request,sizeof(request),0) || memcmp(request,"AGEPATH1",8)){close(peer);continue;}
        DEPathResponse response={0};response.status=DEReadHostSteamPath(response.payload);
        int sent=DEPathTransfer(peer,&response,sizeof(response),1);
        printf("DE_HOST_PATH_RELAY_QUERY status=%d delivered=%d\n",response.status,sent==0);fflush(stdout);
        close(peer);i++;
    }
    close(listener);unlink(argv[1]);return 0;
}
