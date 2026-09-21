// Read public Mac framework string constants for matching notification/key names.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <mach/vm_map.h>

// Only non-executable memory can hold an object pointer. Reading a text symbol
// as an id and messaging it crashes, so reject executable regions first.
// (__DATA_CONST is mapped read-only, so writability is not the test.)
static int DEInNonExecutableData(void *address) {
    if (!address) return 0;
    vm_address_t region=(vm_address_t)address;
    vm_size_t size=0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object=MACH_PORT_NULL;
    if (vm_region_64(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,
                     (vm_region_info_t)&info,&count,&object)!=KERN_SUCCESS) return 0;
    if ((vm_address_t)address<region || (vm_address_t)address>=region+size) return 0;
    return !(info.protection&VM_PROT_EXECUTE);
}
int main(int argc,char **argv) {
    @autoreleasepool {
        if (argc!=2) return 64;
        NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:NULL];
        NSMutableDictionary *values=[NSMutableDictionary dictionary];
        for (NSDictionary *library in manifest[@"libraries"]) {
            void *handle=dlopen([library[@"path"] UTF8String],RTLD_NOW|RTLD_LOCAL);
            if (!handle) continue;
            for (NSDictionary *entry in library[@"symbols"]) {
                NSString *symbol=entry[@"symbol"];
                if (![entry[@"action"] hasPrefix:@"NULL diagnostic data"] ||
                    [symbol isEqual:@"_NSApp"] || [symbol hasPrefix:@"__swift_FORCE_LOAD"]) continue;
                // Only known string-variable naming families; a manifest from an
                // older probe may have misclassified a function ending Attribute.
                if (![symbol hasPrefix:@"_NS"] && ![symbol hasPrefix:@"_k"] &&
                    !([symbol hasPrefix:@"_MTLDevice"] && [symbol hasSuffix:@"Notification"])) continue;
                fprintf(stderr,"DE_CONSTANT_READ %s\n",symbol.UTF8String); fflush(stderr);
                void *address=dlsym(handle,[[symbol substringFromIndex:1] UTF8String]);
                if (DEInNonExecutableData(address)) {
                    id value=*(__unsafe_unretained id *)address;
                    if ([value isKindOfClass:NSString.class]) values[symbol]=value;
                }
            }
        }
        NSData *json=[NSJSONSerialization dataWithJSONObject:values options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(json.bytes,1,json.length,stdout); fputc('\n',stdout);
    }
}
