// Version-specific, read-only descriptor-origin diagnostic. No format changes.
#include <dlfcn.h>
static IMP DEOriginalPixelFormatSetter;
__attribute__((noinline,used)) void DETracePixelFormat(id descriptor,SEL selector,NSUInteger format,const unsigned char *texture) {
    Dl_info info={0};void *caller=__builtin_return_address(0);
    if (!format && dladdr(caller,&info) && (uintptr_t)caller-(uintptr_t)info.dli_fbase==0xa9ec7c) {
        uint16_t internal;uint64_t mapped;uint32_t width,height;
        memcpy(&internal,texture+0x90,2);memcpy(&mapped,texture+0x298,8);
        memcpy(&width,texture+0x68,4);memcpy(&height,texture+0x6c,4);
        fprintf(stderr,"DE_METAL_FORMAT_ORIGIN internal=%u mapped=%llu width=%u height=%u\n",internal,(unsigned long long)mapped,width,height);
    }
    ((void(*)(id,SEL,NSUInteger))DEOriginalPixelFormatSetter)(descriptor,selector,format);
}
// At this observed call site x19 is the original texture object. Preserve the
// original LR and all ABI arguments, supplying x19 only as a diagnostic arg4.
__attribute__((naked)) static void DEPixelFormatCapture(void) {
    __asm__("mov x3, x19\n b _DETracePixelFormat");
}
static void DEInstallFormatTrace(void) {
    if (!getenv("AGEPAD_METAL_FORMAT_TRACE") || DEOriginalPixelFormatSetter) return;
    Class cls=object_getClass([MTLTextureDescriptor new]);SEL selector=@selector(setPixelFormat:);
    Method method=class_getInstanceMethod(cls,selector);
    if (!method) DEUnsupported("pixel format diagnostic setter missing");
    DEOriginalPixelFormatSetter=method_getImplementation(method);
    class_replaceMethod(cls,selector,(IMP)DEPixelFormatCapture,method_getTypeEncoding(method));
}
