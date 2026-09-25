// Enumerate actual iOS Metal devices. Observe changes by polling the real API;
// UIKit has no advance eGPU-removal request notification to forward.
#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include "UnsupportedBoundary.h"
// Defined below; adapters installed on shared Metal classes consult it so
// system frameworks keep the platform implementation.
static BOOL DEAppImageCaller(const void *caller);
#include "MetalFormatTrace.m"
#include "BC4TextureCompat.m"
#include "MetalTextureRouteTrace.m"
typedef void (^DEMetalDeviceHandler)(id<MTLDevice>,NSString *);
@interface DEMetalObserver : NSObject
@property(nonatomic,copy) DEMetalDeviceHandler handler;
@property(nonatomic,strong) NSArray<id<MTLDevice>> *devices;
@property(nonatomic,strong) dispatch_source_t timer;
@end
@implementation DEMetalObserver @end
static NSMutableSet<DEMetalObserver *> *DEMetalObservers;
static IMP DEOriginalTextureDescriptorAllocation;
static IMP DEOriginalBCSupport;
// Experimental software-device profile, not a report of hardware BC support.
// The allocation/encoder adapters implement the qualified 2D sampling path;
// other compressed operations still fail explicitly and require further work.
static BOOL DEAppImageCaller(const void *caller);
static BOOL DEExperimentalBCSupport(id device,SEL selector) {
    BOOL hardware=((BOOL(*)(id,SEL))DEOriginalBCSupport)(device,selector);
    if (!DEAppImageCaller(__builtin_return_address(0))) return hardware;
    BOOL software=getenv("AGEPAD_EXPERIMENTAL_BC_PROFILE")&&getenv("AGEPAD_SOFTWARE_BC_ALL")&&DEAllBCDecoder;
    static unsigned traces=0;if(traces++<8)fprintf(stderr,"DE_BC_DEVICE_PROFILE hardware=%d software_2d=%d complete_metal_conformance=0\n",hardware,software);
    return hardware||software;
}
typedef id (*DETextureAllocator)(id,SEL,id) NS_RETURNS_RETAINED;
// The adapter replaces the method on the GPU's device class, so system
// frameworks (Core Animation's GPU CoreGraphics renderer on hardware) reach it
// too. Only allocations requested from images inside this app bundle get the
// game adapters; everything else receives the platform's own texture.
static BOOL DEAppImageCaller(const void *caller) {
    Dl_info info={0};
    if (!caller || !dladdr(caller,&info) || !info.dli_fname) return YES;
    static const char *bundle;
    static size_t bundleLength;
    if (!bundle) {
        bundle=strdup(NSBundle.mainBundle.bundlePath.fileSystemRepresentation);
        bundleLength=strlen(bundle);
    }
    const char *name=info.dli_fname;
    if (strncmp(name,"/private",8)==0 && strncmp(bundle,"/private",8)!=0) name+=8;
    return strncmp(name,bundle,bundleLength)==0;
}
static id DECheckedTextureAllocation(id<MTLDevice> device,SEL selector,MTLTextureDescriptor *descriptor) NS_RETURNS_RETAINED;
static id DECheckedTextureAllocation(id<MTLDevice> device,SEL selector,MTLTextureDescriptor *descriptor) {
    if (!DEAppImageCaller(__builtin_return_address(0))) {
        static _Atomic unsigned systemCalls;
        if (systemCalls++<4) fprintf(stderr,"DE_METAL_SYSTEM_ALLOCATION original format=%lu usage=%lu\n",
                                     (unsigned long)descriptor.pixelFormat,(unsigned long)descriptor.usage);
        return ((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,descriptor);
    }
    if(getenv("AGEPAD_TEXTURE_ROUTE_TRACE"))DELogTextureRoute(device,selector,descriptor,nil,NO);
    MTLPixelFormat storage,sample;
    if(getenv("AGEPAD_SOFTWARE_BC_ALL")&&DEBCFormatInfo(descriptor.pixelFormat,NULL,&storage,&sample)) {
        if(!DEAllBCDecoder||descriptor.textureType!=MTLTextureType2D||descriptor.arrayLength!=1||descriptor.sampleCount!=1||!descriptor.mipmapLevelCount||(descriptor.usage&(MTLTextureUsageRenderTarget|MTLTextureUsageShaderWrite)))DEUnsupported("BC descriptor outside implemented 2D sampled texture path");
        MTLTextureDescriptor *actual=[descriptor copy];actual.pixelFormat=storage;actual.usage|=MTLTextureUsageShaderWrite|MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView;
        if(actual.storageMode==(MTLStorageMode)1)actual.storageMode=MTLStorageModeShared;
        id<MTLTexture> backing=((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,actual);if(!backing)return nil;
        id<MTLTexture> sampled=[backing newTextureViewWithPixelFormat:sample];if(!sampled)return nil;
        DEBC4Texture *proxy=[DEBC4Texture alloc];proxy.backing=backing;proxy.sampled=sampled;proxy.logicalFormat=descriptor.pixelFormat;proxy.allFormats=YES;return proxy;
    }
    if(getenv("AGEPAD_ALPHA_RENDER_TARGET") && descriptor.pixelFormat==MTLPixelFormatA8Unorm && (descriptor.usage&MTLTextureUsageRenderTarget)) {
        fprintf(stderr,"DE_ALPHA_TEXTURE width=%lu height=%lu type=%lu levels=%lu usage=%lu storage=%lu\n",(unsigned long)descriptor.width,(unsigned long)descriptor.height,(unsigned long)descriptor.textureType,(unsigned long)descriptor.mipmapLevelCount,(unsigned long)descriptor.usage,(unsigned long)descriptor.storageMode);
        if(descriptor.textureType!=MTLTextureType2D || descriptor.arrayLength!=1 || descriptor.sampleCount!=1 || descriptor.mipmapLevelCount!=1 || (descriptor.usage&MTLTextureUsageShaderWrite))DEUnsupported("A8 render descriptor outside qualified path");
        MTLTextureDescriptor*actual=[descriptor copy];actual.pixelFormat=MTLPixelFormatRGBA8Unorm;actual.usage|=MTLTextureUsagePixelFormatView;
        if(actual.storageMode==(MTLStorageMode)1)actual.storageMode=MTLStorageModeShared;
        id<MTLTexture>backing=((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,actual);if(!backing)return nil;
        id<MTLTexture>sampled=[backing newTextureViewWithPixelFormat:MTLPixelFormatRGBA8Unorm textureType:MTLTextureType2D levels:NSMakeRange(0,1) slices:NSMakeRange(0,1) swizzle:MTLTextureSwizzleChannelsMake(MTLTextureSwizzleZero,MTLTextureSwizzleZero,MTLTextureSwizzleZero,MTLTextureSwizzleAlpha)];if(!sampled)return nil;
        DEAlphaTexture*proxy=[DEAlphaTexture alloc];proxy.backing=backing;proxy.sampled=sampled;return proxy;
    }
    if ((getenv("AGEPAD_SOFTWARE_BC4") && descriptor.pixelFormat==MTLPixelFormatBC4_RUnorm) || (getenv("AGEPAD_SOFTWARE_BC7") && descriptor.pixelFormat==MTLPixelFormatBC7_RGBAUnorm)) {
        BOOL bc7=descriptor.pixelFormat==MTLPixelFormatBC7_RGBAUnorm;
        if(bc7 && !DEBC7Decoder)DEUnsupported("BC7 decoder unavailable");
        fprintf(stderr,"DE_COMPRESSED_DESCRIPTOR logical=%lu width=%lu height=%lu type=%lu levels=%lu slices=%lu usage=%lu\n",(unsigned long)descriptor.pixelFormat,(unsigned long)descriptor.width,(unsigned long)descriptor.height,(unsigned long)descriptor.textureType,(unsigned long)descriptor.mipmapLevelCount,(unsigned long)descriptor.arrayLength,(unsigned long)descriptor.usage);
        if (!DEBC4Decoder || descriptor.textureType!=MTLTextureType2D || descriptor.arrayLength!=1 || descriptor.sampleCount!=1 || descriptor.mipmapLevelCount<1 || (descriptor.usage&MTLTextureUsageRenderTarget)) DEUnsupported("BC4 texture descriptor outside supported upload path");
        MTLTextureDescriptor *actual=[descriptor copy];actual.pixelFormat=bc7?MTLPixelFormatRGBA8Unorm:MTLPixelFormatR8Unorm;actual.usage|=MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite|MTLTextureUsagePixelFormatView;
        if(actual.storageMode==(MTLStorageMode)1)actual.storageMode=MTLStorageModeShared;
        id<MTLTexture> backing=((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,actual);
        if(!backing)return nil;
        DEBC4Texture *proxy=[DEBC4Texture alloc];proxy.backing=backing;proxy.logicalFormat=descriptor.pixelFormat;
        fprintf(stderr,"DE_COMPRESSED_BACKING width=%lu height=%lu actual=%lu logical=%lu\n",(unsigned long)actual.width,(unsigned long)actual.height,(unsigned long)actual.pixelFormat,(unsigned long)descriptor.pixelFormat);
        return proxy;
    }
    if (descriptor.pixelFormat==MTLPixelFormatInvalid) {
        fprintf(stderr,"DE_METAL_INVALID_FORMAT descriptor=%s\n",descriptor.description.UTF8String);
        fprintf(stderr,"DE_METAL_INVALID_FORMAT_STACK %s\n",[[NSThread callStackSymbols] componentsJoinedByString:@"\n"].UTF8String);
    }
    // macOS managed storage has separate CPU/GPU copies. UIKit shared storage
    // provides CPU access with visibility at command submission without an
    // explicit managed-copy synchronization. Preserve every other descriptor field.
    if (descriptor.storageMode==(MTLStorageMode)1) {
        descriptor=[descriptor copy];descriptor.storageMode=MTLStorageModeShared;
        fprintf(stderr,"DE_METAL_STORAGE_ADAPTED managed_to_shared width=%lu height=%lu type=%lu format=%lu\n",(unsigned long)descriptor.width,(unsigned long)descriptor.height,(unsigned long)descriptor.textureType,(unsigned long)descriptor.pixelFormat);
    }

    if (descriptor.textureType==MTLTextureTypeCubeArray &&
        ![device supportsFamily:MTLGPUFamilyApple4] && ![device supportsFamily:MTLGPUFamilyMac2]) {
        if(getenv("AGEPAD_CUBE_ARRAY_STORAGE")) {
            if(descriptor.pixelFormat!=MTLPixelFormatRGBA8Unorm || descriptor.sampleCount!=1 || descriptor.width!=descriptor.height || descriptor.arrayLength>NSUIntegerMax/6 || (descriptor.usage&~(MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView)))
                DEUnsupported("cube-array descriptor outside qualified storage path");
            MTLTextureDescriptor *actual=[descriptor copy];actual.textureType=MTLTextureType2DArray;actual.arrayLength*=6;
            id<MTLTexture> backing=((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,actual);
            if(!backing)return nil;
            DECubeArrayTexture *proxy=[DECubeArrayTexture alloc];proxy.backing=backing;
            fprintf(stderr,"DE_CUBE_ARRAY_STORAGE cubes=%lu slices=%lu width=%lu levels=%lu\n",(unsigned long)descriptor.arrayLength,(unsigned long)actual.arrayLength,(unsigned long)actual.width,(unsigned long)actual.mipmapLevelCount);
            return (id)proxy;
        }
        fprintf(stderr,"DE_METAL_UNSUPPORTED_ALLOCATION type=cube-array width=%lu height=%lu count=%lu format=%lu usage=%lu returning=nil\n",(unsigned long)descriptor.width,(unsigned long)descriptor.height,(unsigned long)descriptor.arrayLength,(unsigned long)descriptor.pixelFormat,(unsigned long)descriptor.usage);
        fprintf(stderr,"DE_CUBE_ALLOCATION_STACK %s\n",[[NSThread callStackSymbols] componentsJoinedByString:@"\n"].UTF8String);
        return nil;
    }
    return ((DETextureAllocator)DEOriginalTextureDescriptorAllocation)(device,selector,descriptor);
}

static NSUInteger DEUnspecifiedDeviceLocation(id device,SEL selector) {
    fprintf(stderr,"DE_METAL_LOCATION unspecified on UIKit\n");
    return NSUIntegerMax; // MTLDeviceLocationUnspecified in the native SDK.
}
static IMP DEOriginalWorkingSet;
static uint64_t DEBackingWorkingSet(id<MTLDevice> device,SEL selector) {
    uint64_t reported=((uint64_t(*)(id,SEL))DEOriginalWorkingSet)(device,selector);
    if(reported)return reported;
    const char *path=getenv("AGEPAD_HOST_METAL_METADATA");
    NSData *data=path?[NSData dataWithContentsOfFile:@(path)]:nil;
    id rows=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    if([rows isKindOfClass:NSArray.class]) for(id row in rows) {
        if(![row isKindOfClass:NSDictionary.class])continue;
        if([row[@"registry_id"] isKindOfClass:NSNumber.class] &&
           [row[@"registry_id"] unsignedLongLongValue]==device.registryID &&
           [row[@"recommended_working_set"] isKindOfClass:NSNumber.class]) {
            uint64_t budget=[row[@"recommended_working_set"] unsignedLongLongValue];
            if(budget) {
                fprintf(stderr,"DE_METAL_WORKING_SET simulator=0 backing=%llu registry=%llu\n",budget,device.registryID);
                return budget;
            }
        }
    }
    return reported;
}
static void DEInstallWorkingSet(id<MTLDevice> device) {
    if(!getenv("AGEPAD_BACKING_WORKING_SET") || DEOriginalWorkingSet || !device)return;
    Class cls=object_getClass(device);
    SEL selector=@selector(recommendedMaxWorkingSetSize);
    Method method=class_getInstanceMethod(cls,selector);
    if(![device respondsToSelector:selector])DEUnsupported("Metal working-set query unavailable");
    DEOriginalWorkingSet=method?method_getImplementation(method):class_getMethodImplementation(cls,selector);
    class_replaceMethod(cls,selector,(IMP)DEBackingWorkingSet,method?method_getTypeEncoding(method):"Q@:");
}
__attribute__((constructor)) static void DEInstallInitialWorkingSet(void) {
    // The game's machine survey precedes its device-observer registration.
    if(getenv("AGEPAD_BACKING_WORKING_SET")) @autoreleasepool {
        DEInstallWorkingSet(MTLCreateSystemDefaultDevice());
    }
}
static NSUInteger DEUnavailableDeviceLocationNumber(id device,SEL selector) {
    // With location=Unspecified there is no slot/port interpretation. Keep an
    // explicit unknown sentinel in the game's metadata rather than a port ID.
    fprintf(stderr,"DE_METAL_LOCATION_NUMBER unavailable; adapter sentinel\n");
    return NSUIntegerMax;
}
static uint64_t DEUnifiedMemoryTransferRate(id<MTLDevice> device,SEL selector) {
    if (!device.hasUnifiedMemory) {
        // Simulator may report a different memory model from its backing GPU.
        // An explicit native survey can supply this desktop-only metadata,
        // but only for the exact same registry ID. No feature flags change.
        const char *path=getenv("AGEPAD_HOST_METAL_METADATA");
        if (path) {
            NSData *data=[NSData dataWithContentsOfFile:@(path)];
            id rows=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
            if ([rows isKindOfClass:NSArray.class]) for (id row in rows) {
                if (![row isKindOfClass:NSDictionary.class]) continue;
                if ([row[@"registry_id"] isKindOfClass:NSNumber.class] && [row[@"registry_id"] unsignedLongLongValue]==device.registryID && [row[@"transfer_rate"] isKindOfClass:NSNumber.class]) {
                    fprintf(stderr,"DE_METAL_TRANSFER_RATE matched backing-GPU native survey\n");
                    return [row[@"transfer_rate"] unsignedLongLongValue];
                }
            }
        }
        DEUnsupported("transfer-rate metadata for non-unified GPU");
    }
    fprintf(stderr,"DE_METAL_TRANSFER_RATE unified-memory device; no separate VRAM link\n");
    return 0;
}
// macOS-only scheduling optimization. UIKit keeps its platform compiler
// scheduling; this fallback never reports that extra-thread mode was enabled.
static void DEPlatformCompilationScheduling(id device,SEL selector,BOOL requested) {
    fprintf(stderr,"DE_METAL_COMPILATION_SCHEDULING requested_maximum=%d effective=platform-default\n",requested);
}
static BOOL DEPlatformCompilationSchedulingValue(id device,SEL selector) { return NO; }
// macOS-only topology/format queries absent from UIKit's built-in Apple GPU.
// Values match a native macOS Apple-silicon integrated GPU (M3 Max survey:
// not removable, low-power or headless; no peer group; no Depth24Stencil8).
static BOOL DEBuiltInAppleGPUNo(id device,SEL selector) {
    static _Atomic unsigned traces;
    if(traces++<8)fprintf(stderr,"DE_METAL_BUILTIN_QUERY %s=0\n",sel_getName(selector));
    return NO;
}
static uint64_t DEBuiltInAppleGPUPeerGroup(id device,SEL selector) { return 0; }
static uint32_t DEBuiltInAppleGPUPeerValue(id device,SEL selector) { return 0; }
static void DEInstallBuiltInAppleGPUQueries(id<MTLDevice> device,Class cls) {
    static const char *const flags[]={"isRemovable","isLowPower","isHeadless","isDepth24Stencil8PixelFormatSupported"};
    static const char *const peers[]={"peerIndex","peerCount"};
    SEL group=sel_registerName("peerGroupID");
    BOOL missing=!class_getInstanceMethod(cls,group);
    for(unsigned i=0;i<4;i++) missing|=!class_getInstanceMethod(cls,sel_registerName(flags[i]));
    for(unsigned i=0;i<2;i++) missing|=!class_getInstanceMethod(cls,sel_registerName(peers[i]));
    if(!missing)return;
    if(!device.hasUnifiedMemory)DEUnsupported("macOS GPU topology for a non-unified-memory device");
    for(unsigned i=0;i<4;i++) {
        SEL selector=sel_registerName(flags[i]);
        if(!class_getInstanceMethod(cls,selector)&&!class_addMethod(cls,selector,(IMP)DEBuiltInAppleGPUNo,"B@:"))
            DEUnsupported("Metal built-in GPU flag installation failed");
    }
    if(!class_getInstanceMethod(cls,group)&&!class_addMethod(cls,group,(IMP)DEBuiltInAppleGPUPeerGroup,"Q@:"))
        DEUnsupported("Metal peer-group installation failed");
    for(unsigned i=0;i<2;i++) {
        SEL selector=sel_registerName(peers[i]);
        if(!class_getInstanceMethod(cls,selector)&&!class_addMethod(cls,selector,(IMP)DEBuiltInAppleGPUPeerValue,"I@:"))
            DEUnsupported("Metal peer-value installation failed");
    }
    fprintf(stderr,"DE_METAL_BUILTIN_GPU_QUERIES installed unified=1\n");
}
static void DEInstallMissingDeviceMetadata(NSArray<id<MTLDevice>> *devices) {
    DEInstallFormatTrace();
    for (id<MTLDevice> device in devices) {
        DEInstallBC4(device);
        DEInstallTextureRoutes(device);
        DEInstallAlphaPipeline(device);
        Class cls=object_getClass(device);
        // Simulator reports no budget despite using the surveyed host GPU.
        // Supply only that GPU's real budget; keep allocation/feature limits.
        DEInstallWorkingSet(device);
        if(getenv("AGEPAD_EXPERIMENTAL_BC_PROFILE")&&!DEOriginalBCSupport) {
            Method method=class_getInstanceMethod(cls,@selector(supportsBCTextureCompression));
            if(!DEAllBCDecoder || ![device respondsToSelector:@selector(supportsBCTextureCompression)])
                DEUnsupported("software BC profile requires installed decoder and device capability query");
            // Metal capture devices can forward this selector rather than own
            // a concrete Method. Preserve that forwarding implementation too.
            DEOriginalBCSupport=method?method_getImplementation(method):class_getMethodImplementation(cls,@selector(supportsBCTextureCompression));
            class_replaceMethod(cls,@selector(supportsBCTextureCompression),(IMP)DEExperimentalBCSupport,method?method_getTypeEncoding(method):"B@:");
        }
        SEL allocation=sel_registerName("newTextureWithDescriptor:");
        if (!DEOriginalTextureDescriptorAllocation) {
            Method method=class_getInstanceMethod(cls,allocation);
            if (!method) DEUnsupported("Metal descriptor allocation method missing");
            DEOriginalTextureDescriptorAllocation=method_getImplementation(method);
            class_replaceMethod(cls,allocation,(IMP)DECheckedTextureAllocation,method_getTypeEncoding(method));
        }

        SEL scheduling=sel_registerName("setShouldMaximizeConcurrentCompilation:");
        if (!class_getInstanceMethod(cls,scheduling)) {
            if (!class_addMethod(cls,scheduling,(IMP)DEPlatformCompilationScheduling,"v@:B"))
                DEUnsupported("Metal compiler scheduling fallback installation failed");
            SEL getter=sel_registerName("shouldMaximizeConcurrentCompilation");
            if (!class_getInstanceMethod(cls,getter) && !class_addMethod(cls,getter,(IMP)DEPlatformCompilationSchedulingValue,"B@:"))
                DEUnsupported("Metal compiler scheduling getter installation failed");
        }
        SEL selector=sel_registerName("location");
        if (!class_getInstanceMethod(cls,selector) && !class_addMethod(cls,selector,(IMP)DEUnspecifiedDeviceLocation,"Q@:"))
            DEUnsupported("Metal location adapter installation failed");
        selector=sel_registerName("locationNumber");
        if (!class_getInstanceMethod(cls,selector) && !class_addMethod(cls,selector,(IMP)DEUnavailableDeviceLocationNumber,"Q@:"))
            DEUnsupported("Metal location-number adapter installation failed");
        selector=sel_registerName("maxTransferRate");
        if (!class_getInstanceMethod(cls,selector) && !class_addMethod(cls,selector,(IMP)DEUnifiedMemoryTransferRate,"Q@:"))
            DEUnsupported("Metal transfer-rate adapter installation failed");
        DEInstallBuiltInAppleGPUQueries(device,cls);
    }
}
__attribute__((constructor)) static void DEInstallInitialMetalAdapter(void) {
    if(getenv("AGEPAD_EARLY_METAL_ADAPTER")) @autoreleasepool {
        id<MTLDevice> device=MTLCreateSystemDefaultDevice();
        if(device)DEInstallMissingDeviceMetadata(@[device]);
        fprintf(stderr,"DE_METAL_ADAPTER_EARLY installed=%d\n",device!=nil);
    }
}
NSArray<id<MTLDevice>> *MTLCopyAllDevicesWithObserver(id<NSObject> __strong *observer,DEMetalDeviceHandler handler) NS_RETURNS_RETAINED;
NSArray<id<MTLDevice>> *MTLCopyAllDevicesWithObserver(id<NSObject> __strong *observer,DEMetalDeviceHandler handler) {
    if (!getenv("AGEPAD_METAL_DEVICES") || !observer || !NSThread.isMainThread) DEUnsupported("Metal device observer requires main thread and output");
    if (@available(iOS 18.0,*)) {
        NSArray *devices=MTLCopyAllDevices();
        DEInstallMissingDeviceMetadata(devices);
        static dispatch_once_t once;dispatch_once(&once,^{DEMetalObservers=[NSMutableSet set];});
        DEMetalObserver *token=[DEMetalObserver new];token.devices=devices;token.handler=handler;
        token.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        __weak DEMetalObserver *weakToken=token;
        dispatch_source_set_event_handler(token.timer,^{
            DEMetalObserver *current=weakToken;if (!current) return;
            NSArray<id<MTLDevice>> *fresh=MTLCopyAllDevices();
            DEInstallMissingDeviceMetadata(fresh);
            NSArray *old=current.devices;current.devices=fresh;
            for (id<MTLDevice> previous in old) {
                BOOL found=NO;for (id<MTLDevice> next in fresh) if (next.registryID==previous.registryID) found=YES;
                if (!found && current.handler) current.handler(previous,@"MTLDeviceWasRemoved");
            }
            for (id<MTLDevice> next in fresh) {
                BOOL found=NO;for (id<MTLDevice> previous in old) if (next.registryID==previous.registryID) found=YES;
                if (!found && current.handler) current.handler(next,@"MTLDeviceWasAdded");
            }
        });
        dispatch_source_set_timer(token.timer,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),NSEC_PER_SEC,NSEC_PER_SEC/10);
        @synchronized(DEMetalObservers) { [DEMetalObservers addObject:token]; }
        *observer=token;dispatch_resume(token.timer);
        fprintf(stderr,"DE_METAL_DEVICES actual_count=%lu observer=polling\n",(unsigned long)devices.count);
        return devices;
    }
    DEUnsupported("Metal device enumeration requires iOS18");
}
void MTLRemoveDeviceObserver(id<NSObject> observer) {
    if (!NSThread.isMainThread) DEUnsupported("Metal observer removal requires main thread");
    if (![observer isKindOfClass:DEMetalObserver.class]) DEUnsupported("foreign Metal observer");
    DEMetalObserver *token=(DEMetalObserver *)observer;
    @synchronized(DEMetalObservers) {
        if (![DEMetalObservers containsObject:token]) return;
        dispatch_source_cancel(token.timer);token.timer=nil;token.handler=nil;
        [DEMetalObservers removeObject:token];
    }
}
