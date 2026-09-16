// Read-only discovery experiment. No service registration or task mutation.
#include <mach/mach.h>
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
    mach_port_t *bp=dlsym(RTLD_DEFAULT,"bootstrap_port");
    kern_return_t (*lookup)(mach_port_t,const char *,mach_port_t *)=dlsym(RTLD_DEFAULT,"bootstrap_look_up");
    kern_return_t (*root)(mach_port_t,mach_port_t *)=dlsym(RTLD_DEFAULT,"bootstrap_get_root");
    kern_return_t (*user)(mach_port_t,const char *,uid_t,mach_port_t *)=dlsym(RTLD_DEFAULT,"bootstrap_look_up_per_user");
    if (!bp || !lookup) { puts("{\"api_available\":false}"); return 1; }
    const char *service="com.valvesoftware.steam.ipctool";
    printf("{\"pid\":%d,\"api_available\":true,\"routes\":[",getpid());
    for (int route=0;route<4;route++) {
        mach_port_t space=*bp,found=MACH_PORT_NULL;
        kern_return_t status=KERN_NOT_SUPPORTED;
        if (route==0) status=lookup(space,service,&found);
        if (route==1 && user) status=user(space,service,getuid(),&found);
        if (route==2 && root) {
            space=MACH_PORT_NULL;
            status=root(*bp,&space);
            if (status==KERN_SUCCESS) {
                status=lookup(space,service,&found);
                mach_port_deallocate(mach_task_self(),space);
            }
        }
        if (route==3) {
            space=MACH_PORT_NULL;
            status=task_get_special_port(mach_task_self(),TASK_BOOTSTRAP_PORT,&space);
            if (status==KERN_SUCCESS) {
                status=lookup(space,service,&found);
                mach_port_deallocate(mach_task_self(),space);
            }
        }
        printf("%s{\"route\":\"%s\",\"api_available\":%s,\"status\":%d,\"found\":%s}",
               route?",":"",route==0?"current":route==1?"current_user":route==2?"root":"kernel_bootstrap",
               (route==0 || route==3 || (route==1 && user) || (route==2 && root))?"true":"false",
               status,status==KERN_SUCCESS && MACH_PORT_VALID(found)?"true":"false");
        if (MACH_PORT_VALID(found)) mach_port_deallocate(mach_task_self(),found);
    }
    puts("]}");
    return 0;
}
