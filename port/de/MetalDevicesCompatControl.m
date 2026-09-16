#include "MetalDevicesCompat.m"
int main(void) { @autoreleasepool {
    id<NSObject> token=nil;__block unsigned notifications=0;
    NSArray<id<MTLDevice>> *devices=MTLCopyAllDevicesWithObserver(&token,^(id<MTLDevice> d,NSString *name){notifications++;});
    NSArray<id<MTLDevice>> *actual=MTLCopyAllDevices();
    BOOL matches=devices.count==actual.count;
    for (NSUInteger i=0;i<devices.count&&matches;i++) matches=devices[i].registryID==actual[i].registryID;
    BOOL unspecified=YES;
    for (id<MTLDevice> device in devices) {
        SEL selector=sel_registerName("location");
        NSUInteger (*readLocation)(id,SEL)=(void *)class_getMethodImplementation(object_getClass(device),selector);
        unspecified=unspecified && readLocation(device,selector)==NSUIntegerMax;
    }
    __weak id weakToken=token;
    MTLRemoveDeviceObserver(token);token=nil;
    BOOL released=weakToken==nil && DEMetalObservers.count==0;
    printf("{\"actual_device_count\":%lu,\"matches_real_enumeration\":%s,\"observer_released\":%s,\"notifications\":%u}\n",(unsigned long)devices.count,matches?"true":"false",released?"true":"false",notifications);
    printf("{\"location_unspecified\":%s}\n",unspecified?"true":"false");
    return matches&&released&&notifications==0&&unspecified?0:1;
} }
