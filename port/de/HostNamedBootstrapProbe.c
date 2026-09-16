// Read-only host lookup through the designated CoreSimulator service port.
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv) {
    if (argc!=2 || strcmp(argv[1],"com.apple.CoreSimulator.SimDevice.574671AD-6F61-4558-9528-BF946DDB760A")) return 64;
    mach_port_t space=MACH_PORT_NULL;
    kern_return_t status=bootstrap_look_up(bootstrap_port,argv[1],&space);
    printf("{\"namespace_lookup\":%d,\"same_as_host\":%s,\"services\":[",status,space==bootstrap_port?"true":"false");fflush(stdout);
    if (status==KERN_SUCCESS) {
        const char *services[]={"com.valvesoftware.steam.ipctool","com.apple.frontboard.systemappservices","com.apple.cfprefsd.daemon"};
        for (unsigned i=0;i<3;i++) {
            mach_port_t port=MACH_PORT_NULL;
            status=bootstrap_look_up(space,services[i],&port);
            printf("%s{\"name\":\"%s\",\"status\":%d,\"found\":%s}",i?",":"",services[i],status,status==0 && MACH_PORT_VALID(port)?"true":"false");fflush(stdout);
            if (MACH_PORT_VALID(port)) mach_port_deallocate(mach_task_self(),port);
        }
        mach_port_deallocate(mach_task_self(),space);
    }
    puts("]}");return 0;
}
