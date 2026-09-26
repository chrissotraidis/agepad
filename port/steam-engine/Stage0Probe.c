// Stage 0a (Mac, read-only): load Valve's client library from the installed
// Steam app and ask it for its client engine. No sign-in, no writes.
// Build: xcrun clang -O0 port/steam-engine/Stage0Probe.c -o <out>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
    const char *library=argc>1?argv[1]:NULL;
    if (!library) { fprintf(stderr,"usage: Stage0Probe /path/to/steamclient.dylib\n");return 64; }
    void *client=dlopen(library,RTLD_NOW|RTLD_LOCAL);
    printf("STAGE0_LOAD ok=%d error=%s\n",client!=NULL,client?"none":dlerror());
    if (!client) return 1;
    void *(*create)(const char *,int *)=dlsym(client,"CreateInterface");
    const char *names[]={"CLIENTENGINE_INTERFACE_VERSION005","SteamClient021","SteamClient020"};
    for (int i=0;i<3;i++) {
        int status=-1;
        void *object=create?create(names[i],&status):NULL;
        Dl_info info={0};
        void *vtable=object?*(void **)object:NULL;
        if (vtable) dladdr(vtable,&info);
        printf("STAGE0_INTERFACE name=%s object=%d status=%d vtable_offset=0x%lx\n",names[i],object!=NULL,status,
               vtable&&info.dli_fbase?(unsigned long)((char *)vtable-(char *)info.dli_fbase):0UL);
        if (i==0 && vtable && getenv("STAGE0_DUMP_VTABLE")) {
            for (int slot=0;slot<96;slot++) {
                void *fn=((void **)vtable)[slot];Dl_info f={0};
                if (!fn || !dladdr(fn,&f) || f.dli_fbase!=info.dli_fbase) break;
                printf("STAGE0_ENGINE_SLOT %d 0x%lx\n",slot,(unsigned long)((char *)fn-(char *)f.dli_fbase));
            }
        }
    }
    return 0;
}
