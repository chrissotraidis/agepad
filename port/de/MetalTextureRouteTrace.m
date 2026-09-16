// Bounded allocation-route diagnostic. Descriptors and results are unchanged.
#include <stdatomic.h>
static _Atomic unsigned DETextureRouteCount;
static void DELogTextureRoute(id owner,SEL selector,MTLTextureDescriptor *d,id result,BOOL completed) {
    unsigned n=atomic_fetch_add(&DETextureRouteCount,1);
    if(n>=4096)return;
    fprintf(stderr,"DE_TEXTURE_ROUTE seq=%u owner=%s api=%s completed=%d format=%lu width=%lu height=%lu levels=%lu result=%p\n",
            n,object_getClassName(owner),sel_getName(selector),completed,(unsigned long)d.pixelFormat,
            (unsigned long)d.width,(unsigned long)d.height,(unsigned long)d.mipmapLevelCount,result);
}
static IMP DERouteOriginal(id owner,SEL selector) {
    for(Class c=object_getClass(owner);c;c=class_getSuperclass(c)) {
        NSValue *value=objc_getAssociatedObject(c,(const void *)selector);
        if(value)return (IMP)value.pointerValue;
    }
    DEUnsupported("texture-route diagnostic missing original method");
}
typedef id (*DERouteBufferFunction)(id,SEL,id,NSUInteger,NSUInteger) NS_RETURNS_RETAINED;
static id DERouteBuffer(id owner,SEL selector,MTLTextureDescriptor *d,NSUInteger offset,NSUInteger stride) NS_RETURNS_RETAINED;
static id DERouteBuffer(id owner,SEL selector,MTLTextureDescriptor *d,NSUInteger offset,NSUInteger stride) {
    id result=((DERouteBufferFunction)DERouteOriginal(owner,selector))(owner,selector,d,offset,stride);
    DELogTextureRoute(owner,selector,d,result,YES);return result;
}
typedef id (*DERouteHeapFunction)(id,SEL,id) NS_RETURNS_RETAINED;
static id DERouteHeap(id owner,SEL selector,MTLTextureDescriptor *d) NS_RETURNS_RETAINED;
static id DERouteHeap(id owner,SEL selector,MTLTextureDescriptor *d) {
    id result=((DERouteHeapFunction)DERouteOriginal(owner,selector))(owner,selector,d);
    DELogTextureRoute(owner,selector,d,result,YES);return result;
}
typedef id (*DERouteHeapOffsetFunction)(id,SEL,id,NSUInteger) NS_RETURNS_RETAINED;
static id DERouteHeapOffset(id owner,SEL selector,MTLTextureDescriptor *d,NSUInteger offset) NS_RETURNS_RETAINED;
static id DERouteHeapOffset(id owner,SEL selector,MTLTextureDescriptor *d,NSUInteger offset) {
    id result=((DERouteHeapOffsetFunction)DERouteOriginal(owner,selector))(owner,selector,d,offset);
    DELogTextureRoute(owner,selector,d,result,YES);return result;
}
static void DETraceRouteMethod(id sample,SEL selector,IMP wrapper) {
    if(!sample)return;
    Class c=object_getClass(sample);Method m=class_getInstanceMethod(c,selector);
    if(!m || method_getImplementation(m)==wrapper)return;
    objc_setAssociatedObject(c,(const void *)selector,[NSValue valueWithPointer:method_getImplementation(m)],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    class_replaceMethod(c,selector,wrapper,method_getTypeEncoding(m));
    fprintf(stderr,"DE_TEXTURE_ROUTE_INSTALLED class=%s api=%s\n",class_getName(c),sel_getName(selector));
}
static void DEInstallTextureRoutes(id<MTLDevice> device) {
    if(!getenv("AGEPAD_TEXTURE_ROUTE_TRACE"))return;
    static dispatch_once_t once;dispatch_once(&once,^{
        for(NSNumber *mode in @[@(MTLResourceStorageModeShared),@(MTLResourceStorageModePrivate)]) {
            id sample=[device newBufferWithLength:65536 options:mode.unsignedLongLongValue];
            DETraceRouteMethod(sample,@selector(newTextureWithDescriptor:offset:bytesPerRow:),(IMP)DERouteBuffer);
        }
        MTLHeapDescriptor *d=[MTLHeapDescriptor new];d.size=65536;d.storageMode=MTLStorageModePrivate;
        id sample=[device newHeapWithDescriptor:d];
        DETraceRouteMethod(sample,@selector(newTextureWithDescriptor:),(IMP)DERouteHeap);
        DETraceRouteMethod(sample,@selector(newTextureWithDescriptor:offset:),(IMP)DERouteHeapOffset);
        fprintf(stderr,"DE_TEXTURE_ROUTE_HEAP_SAMPLE available=%d\n",sample!=nil);
    });
}
