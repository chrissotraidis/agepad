#pragma once
// Read-only lookup of the genuine Steam discovery service. No registration,
// global bootstrap change, authentication replacement, or namespace mutation.
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <dlfcn.h>
static NSArray *DESteamMachDiscovery(void) {
    mach_port_t *bootstrap=dlsym(RTLD_DEFAULT,"bootstrap_port");
    kern_return_t (*lookup)(mach_port_t,const char *,mach_port_t *)=dlsym(RTLD_DEFAULT,"bootstrap_look_up");
    kern_return_t (*parent)(mach_port_t,mach_port_t *)=dlsym(RTLD_DEFAULT,"bootstrap_parent");
    if (!bootstrap || !lookup) return @[@{@"error":@"Bootstrap lookup API unavailable"}];
    NSMutableArray *steps=[NSMutableArray array];
    mach_port_t current=*bootstrap;
    BOOL owned=NO;
    for (NSUInteger depth=0;depth<8;depth++) {
        mach_port_t service=MACH_PORT_NULL;
        kern_return_t status=lookup(current,"com.valvesoftware.steam.ipctool",&service);
        NSMutableDictionary *step=[@{@"depth":@(depth),@"lookup_result":@(status),@"service_found":@(status==KERN_SUCCESS && MACH_PORT_VALID(service))} mutableCopy];
        if (MACH_PORT_VALID(service)) mach_port_deallocate(mach_task_self(),service);
        [steps addObject:step];
        if (!parent || status==KERN_SUCCESS) break;
        mach_port_t next=MACH_PORT_NULL;
        kern_return_t parentStatus=parent(current,&next);
        step[@"parent_result"]=@(parentStatus);
        if (parentStatus!=KERN_SUCCESS || !MACH_PORT_VALID(next)) break;
        if (next==current) {
            step[@"parent_is_same"]=@YES;
            mach_port_deallocate(mach_task_self(),next);break;
        }
        if (owned) mach_port_deallocate(mach_task_self(),current);
        current=next;owned=YES;
    }
    if (owned) mach_port_deallocate(mach_task_self(),current);
    return steps;
}
