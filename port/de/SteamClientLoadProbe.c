// Execute genuine library/factory and optional connection calls. No fake state.
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
int main(int argc,char **argv) {
    bool connect=argc==3 && strcmp(argv[2],"--connect-client")==0;
    if (argc!=2 && !(argc==3 && (connect || strcmp(argv[2],"--create-interface")==0))) return 64;
    printf("DE_CLIENT_LOAD_BEGIN pid=%d\n",getpid());fflush(stdout);
    void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    const char *error=handle?NULL:dlerror();
    printf("DE_CLIENT_LOAD_RESULT loaded=%d\n",handle!=NULL);fflush(stdout);
    if (error) { fprintf(stderr,"DE_CLIENT_LOAD_ERROR %s\n",error);fflush(stderr); }
    if (handle && argc==3) {
        void *(*factory)(const char *,int *)=dlsym(handle,"CreateInterface");
        printf("DE_CLIENT_FACTORY_BEGIN export=%d\n",factory!=NULL);fflush(stdout);
        if (!factory) return 2;
        int status=-1;
        void *interface=factory("SteamClient020",&status);
        printf("DE_CLIENT_FACTORY_RESULT interface_present=%d status=%d\n",interface!=NULL,status);fflush(stdout);
        if (!interface) return 3;
        if (connect) {
            // First slots of Valve's published SteamClient020 interface.
            void **methods=*(void ***)interface;
            int32_t (*create)(void *)=(int32_t (*)(void *))methods[0];
            bool (*releasePipe)(void *,int32_t)=(bool (*)(void *,int32_t))methods[1];
            int32_t (*globalUser)(void *,int32_t)=(int32_t (*)(void *,int32_t))methods[2];
            void (*releaseUser)(void *,int32_t,int32_t)=(void (*)(void *,int32_t,int32_t))methods[4];
            puts("DE_CLIENT_PIPE_BEGIN");fflush(stdout);
            int32_t pipe=create(interface);
            printf("DE_CLIENT_PIPE_RESULT nonzero=%d\n",pipe!=0);fflush(stdout);
            if (!pipe) return 4;
            puts("DE_CLIENT_CONNECT_BEGIN");fflush(stdout);
            int32_t user=globalUser(interface,pipe);
            printf("DE_CLIENT_CONNECT_RESULT nonzero=%d\n",user!=0);fflush(stdout);
            bool loggedOn=false;
            if (user) {
                void *(*getUser)(void *,int32_t,int32_t,const char *)=
                    (void *(*)(void *,int32_t,int32_t,const char *))methods[5];
                void *userInterface=getUser(interface,user,pipe,"SteamUser021");
                printf("DE_CLIENT_USER_INTERFACE present=%d\n",userInterface!=NULL);fflush(stdout);
                if (userInterface) {
                    void **userMethods=*(void ***)userInterface;
                    bool (*isLoggedOn)(void *)=(bool (*)(void *))userMethods[1];
                    loggedOn=isLoggedOn(userInterface);
                    printf("DE_CLIENT_LOGGED_ON %d\n",loggedOn);fflush(stdout);
                }
            }
            if (user) releaseUser(interface,pipe,user);
            bool released=releasePipe(interface,pipe);
            printf("DE_CLIENT_PIPE_RELEASED %d\n",released);fflush(stdout);
            if (!released) return 6;
            if (!user) return 5;
            if (!loggedOn) return 7;
        }
    }
    // Let process exit tear down its own loaded modules; no game SDK initialization.
    return handle?0:1;
}
