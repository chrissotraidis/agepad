// Version-specific Simulator bridge. The original test executes unchanged.
// Reserved import is used only at recorded diagnostic call sites.
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#include "UnsupportedBoundary.h"
static NSString *DEMinSpecMessage(const void *state) {
    const unsigned char *s=(const unsigned char *)state+8;
    BOOL heap=(s[23]&0x80)!=0;
    NSUInteger length=heap?((const NSUInteger *)s)[1]:s[23];
    const unichar *chars=heap?*(const unichar *const *)s:(const unichar *)s;
    if (length>16384 || (length && !chars)) DEUnsupported("unknown minimum-spec string representation");
    return [[NSString alloc] initWithCharacters:chars length:length];
}
long DEMinSpecCallBridge(void *a,uintptr_t b,void *c,void *d,void *e) __asm__("_CGWindowListCreateImage");
long DEMinSpecCallBridge(void *a,uintptr_t b,void *c,void *d,void *e) {
    Dl_info info={0};void *caller=__builtin_return_address(0);
    if (!getenv("AGEPAD_MINSPEC_DIALOG") || !dladdr(caller,&info)) DEUnsupported("minimum-spec bridge not enabled");
    uintptr_t offset=(uintptr_t)caller-(uintptr_t)info.dli_fbase;
    if (offset==0x2eb12e0 && getenv("AGEPAD_FONT_TRACE")) {
        const char *path=*(const char **)((const char *)d+8);
        fprintf(stderr,"DE_FONT_FILE_REQUEST path=%s\n",path?:"(null)");
        uintptr_t (*readFile)(void *,uintptr_t,void *,void *)=(void *)((uintptr_t)info.dli_fbase+0x2cb562c);
        uintptr_t result=readFile(a,b,c,d);
        fprintf(stderr,"DE_FONT_FILE_RESULT success=%llu bytes=%llu data=%p\n",(unsigned long long)result,*(unsigned long long *)c,*(void **)b);
        return result;
    }
    if (offset==0xaa2864 && getenv("AGEPAD_STAGING_TRACE")) {
        const unsigned char *state=a;
        fprintf(stderr,"DE_STAGING_REQUEST bytes=%llu alignment=%llu capacity=%u cursor=%llu available=%llu requested=%llu pending=%u\n",
          (unsigned long long)b,(unsigned long long)(uintptr_t)c,
          *(const uint32_t *)(state+0x118),*(const unsigned long long *)(state+0x120),
          *(const unsigned long long *)(state+0x248),*(const unsigned long long *)(state+0x250),*(const uint32_t *)(state+0x12c));
        void *(*allocate)(void *,uintptr_t,uintptr_t)=(void *)((uintptr_t)info.dli_fbase+0xa7f920);
        void *result=allocate(a,b,(uintptr_t)c);
        fprintf(stderr,"DE_STAGING_RETURN nonnull=%d\n",result!=NULL);
        return (long)result;
    }
    if (offset==0xaa5e0c && getenv("AGEPAD_METAL_FORMAT_TRACE")) {
        uintptr_t (*mapping)(uint32_t,uintptr_t)=(void *)((uintptr_t)info.dli_fbase+0xa9a780);
        uintptr_t result=mapping((uint32_t)(uintptr_t)a,b);
        fprintf(stderr,"DE_ORIGINAL_FORMAT_MAPPING internal=%u capability=%llu result=%llu\n",(uint32_t)(uintptr_t)a,(unsigned long long)b,(unsigned long long)result);
        if(!result && (uint32_t)(uintptr_t)a==102 && getenv("AGEPAD_SOFTWARE_BC7")) return 152; // software BC7 RGBA, actual hardware flag unchanged
        if(!result && (uint32_t)(uintptr_t)a==93 && getenv("AGEPAD_SOFTWARE_BC4")) return 140; // software-decoded BC4, not a hardware capability change
        return result;
    }
    if (offset==0x33cb8e8) {
        uint32_t (*test)(void *)=(void *)((uintptr_t)info.dli_fbase+0x33cb9b8);
        uint32_t passed=test(a);
        fprintf(stderr,"DE_MINSPEC_ACTUAL_RESULT passed=%u mask=%u message=%s\n",passed,*(const uint32_t *)a,DEMinSpecMessage(a).UTF8String);
        return passed;
    }
    if (offset!=0x33cb928 || b!=0x9000 || !e) DEUnsupported("reserved graphics import or unknown minimum-spec dialog call");
    if (NSThread.isMainThread) DEUnsupported("minimum-spec dialog expected game worker thread");
    NSString *message=DEMinSpecMessage(e);
    if (!message.length) message=@"This device does not meet the game's minimum specifications.";
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    __block long response=0;
    dispatch_async(dispatch_get_main_queue(),^{
        UIWindow *window=nil;
        for (UIWindow *candidate in UIApplication.sharedApplication.windows) if(candidate.isKeyWindow){window=candidate;break;}
        UIViewController *presenter=window.rootViewController;
        if (!presenter || presenter.presentedViewController) DEUnsupported("minimum-spec warning requires available UIKit presenter");
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Hardware warning" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Exit Game" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){response=0x9001;dispatch_semaphore_signal(finished);}]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Continue Anyway" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){response=0x9002;dispatch_semaphore_signal(finished);}]];
        [presenter presentViewController:alert animated:YES completion:nil];
        fprintf(stderr,"DE_MINSPEC_WARNING_VISIBLE awaiting actual action\n");
    });
    dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
    fprintf(stderr,"DE_MINSPEC_WARNING_RESPONSE value=%ld\n",response);
    return response;
}
