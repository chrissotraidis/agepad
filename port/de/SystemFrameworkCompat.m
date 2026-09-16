// macOS System.framework is a compatibility location for libSystem. Resolve
// the observed allocator lookup to the actual platform implementation.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>
static void *DEBundleFunction(CFBundleRef bundle,CFStringRef name) {
 void *result=CFBundleGetFunctionPointerForName(bundle,name);
 if(result)return result;
 CFURLRef url=bundle?CFBundleCopyBundleURL(bundle):NULL;
 CFStringRef path=url?CFURLCopyFileSystemPath(url,kCFURLPOSIXPathStyle):NULL;
 BOOL system=path && CFEqual(path,CFSTR("/System/Library/Frameworks/System.framework"));
 if(system && CFEqual(name,CFSTR("free"))) {
  static void *handle;static dispatch_once_t once;
  dispatch_once(&once,^{handle=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW|RTLD_LOCAL);});
  result=handle?dlsym(handle,"free"):NULL;
  fprintf(stderr,"DE_SYSTEM_FRAMEWORK_REAL_FREE resolved=%d\n",result!=NULL);
 }else{
  fprintf(stderr,"DE_BUNDLE_LOOKUP_MISSING bundle=%s name=%s\n",path?[(__bridge NSString *)path UTF8String]:"nil",name?[(__bridge NSString *)name UTF8String]:"nil");
 }
 if(path)CFRelease(path);if(url)CFRelease(url);return result;
}
__attribute__((used,section("__DATA,__interpose")))static const struct{const void *replacement,*original;} DESystemInterpose[]={ {(const void *)DEBundleFunction,(const void *)CFBundleGetFunctionPointerForName} };
