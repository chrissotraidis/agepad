// Read-only capability probe for the explicitly supplied diagnostic process.
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdlib.h>
int main(int argc,char **argv) {
    if (argc!=2) return 64;
    @autoreleasepool {
        char *end=NULL;long value=strtol(argv[1],&end,10);
        if (!end || *end || value<=0 || value>INT_MAX) return 64;
        mach_port_t task=MACH_PORT_NULL,space=MACH_PORT_NULL,service=MACH_PORT_NULL;
        kern_return_t status=task_for_pid(mach_task_self(),(pid_t)value,&task);
        NSMutableDictionary *result=[@{@"pid":@(value),@"task_for_pid":@(status)} mutableCopy];
        if (status==KERN_SUCCESS) {
            status=task_get_special_port(task,TASK_BOOTSTRAP_PORT,&space);
            result[@"bootstrap_port_result"]=@(status);
            if (status==KERN_SUCCESS) {
                result[@"same_as_host_namespace"]=@(space==bootstrap_port);
                status=bootstrap_look_up(space,"com.valvesoftware.steam.ipctool",&service);
                result[@"steam_lookup"]=@(status);
                result[@"service_found"]=@(status==KERN_SUCCESS && MACH_PORT_VALID(service));
            }
        }
        for (NSNumber *port in @[@(service),@(space),@(task)]) {
            if (MACH_PORT_VALID(port.unsignedIntValue)) mach_port_deallocate(mach_task_self(),port.unsignedIntValue);
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);
    }
    return 0;
}
