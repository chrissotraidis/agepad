// Diagnostic pass-throughs: preserve the real validation result and all outputs.
// No code-signing requirement, ownership check, or authentication result changes.
#import <Foundation/Foundation.h>
#import <Security/SecBase.h>
#include <dlfcn.h>
#include <errno.h>
#include <execinfo.h>
#include "UnsupportedBoundary.h"
// macOS exposes the system anchor list; iOS does not. Do not invent trusted
// anchors or report success until an equivalent device API is established.
OSStatus DESecTrustCopyAnchorCertificates(CFArrayRef *anchors)
    __asm__("_SecTrustCopyAnchorCertificates");
OSStatus DESecTrustCopyAnchorCertificates(CFArrayRef *anchors) {
    if (anchors) *anchors=NULL;
    fprintf(stderr,"DE_SECURITY_ANCHOR_LIST unavailable on iOS\n");
    return errSecUnimplemented;
}
static void *DERealSecurity(const char *name) {
    int saved=errno;
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once,^{library=dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_NOW|RTLD_LOCAL|RTLD_FIRST);});
    void *function=library?dlsym(library,name):NULL;
    errno=saved;
    if (!function) DEUnsupported(name);
    return function;
}
static int32_t DEValidationResult(const char *name,int32_t result,uint32_t flags,BOOL requirement) {
    int saved=errno;
    fprintf(stderr,"DE_REAL_SECURITY %s status=%d flags=%u requirement=%d\n",name,result,flags,requirement);
    fflush(stderr);errno=saved;return result;
}
int32_t SecCodeCopySelf(uint32_t flags,CFTypeRef *code) {
    int32_t (*original)(uint32_t,CFTypeRef *)=DERealSecurity("SecCodeCopySelf");
    int32_t result=original(flags,code);
    int saved=errno;
    if (getenv("AGEPAD_MAC_SECURITY_CALLERS")) {
        void *frames[12];
        int count=backtrace(frames,12);
        for (int i=1;i<count;i++) {
            Dl_info info={0};
            if (!dladdr(frames[i],&info)) continue;
            const char *name=info.dli_fname?strrchr(info.dli_fname,'/'):NULL;
            fprintf(stderr,"DE_SECURITY_CALLER frame=%d image=%s offset=0x%llx\n",i,
                name?name+1:"unknown",(unsigned long long)((uintptr_t)frames[i]-(uintptr_t)info.dli_fbase));
        }
    }
    errno=saved;
    return DEValidationResult("SecCodeCopySelf",result,flags,NO);
}
int32_t SecCodeCopyStaticCode(CFTypeRef code,uint32_t flags,CFTypeRef *staticCode) {
    int32_t (*original)(CFTypeRef,uint32_t,CFTypeRef *)=DERealSecurity("SecCodeCopyStaticCode");
    return DEValidationResult("SecCodeCopyStaticCode",original(code,flags,staticCode),flags,NO);
}
int32_t SecStaticCodeCreateWithPath(CFURLRef path,uint32_t flags,CFTypeRef *code) {
    int32_t (*original)(CFURLRef,uint32_t,CFTypeRef *)=DERealSecurity("SecStaticCodeCreateWithPath");
    return DEValidationResult("SecStaticCodeCreateWithPath",original(path,flags,code),flags,NO);
}
int32_t SecCodeCheckValidity(CFTypeRef code,uint32_t flags,CFTypeRef requirement) {
    int32_t (*original)(CFTypeRef,uint32_t,CFTypeRef)=DERealSecurity("SecCodeCheckValidity");
    return DEValidationResult("SecCodeCheckValidity",original(code,flags,requirement),flags,requirement!=NULL);
}
int32_t SecStaticCodeCheckValidity(CFTypeRef code,uint32_t flags,CFTypeRef requirement) {
    int32_t (*original)(CFTypeRef,uint32_t,CFTypeRef)=DERealSecurity("SecStaticCodeCheckValidity");
    return DEValidationResult("SecStaticCodeCheckValidity",original(code,flags,requirement),flags,requirement!=NULL);
}
