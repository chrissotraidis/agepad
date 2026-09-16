#pragma once
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <unistd.h>
#include <errno.h>
static NSDictionary *DEProbeRealCodeIdentity(void) {
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    void *security=dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_NOW|RTLD_LOCAL|RTLD_FIRST);
    int32_t (*copySelf)(uint32_t,CFTypeRef *)=security?dlsym(security,"SecCodeCopySelf"):NULL;
    int32_t (*createStatic)(CFURLRef,uint32_t,CFTypeRef *)=security?dlsym(security,"SecStaticCodeCreateWithPath"):NULL;
    int32_t (*checkStatic)(CFTypeRef,uint32_t,CFTypeRef)=security?dlsym(security,"SecStaticCodeCheckValidity"):NULL;
    CFTypeRef code=NULL;
    if (copySelf) {
        result[@"copy_self_status"]=@(copySelf(0,&code));
        if (code) CFRelease(code);
    }
    code=NULL;
    if (createStatic) {
        int32_t status=createStatic((__bridge CFURLRef)NSBundle.mainBundle.bundleURL,0,&code);
        result[@"create_static_status"]=@(status);
        if (status==0 && code && checkStatic) result[@"static_validation_status"]=@(checkStatic(code,0,NULL));
        if (code) CFRelease(code);
    }
    CFTypeRef (*createTask)(CFAllocatorRef)=security?dlsym(security,"SecTaskCreateFromSelf"):NULL;
    if (createTask) {
        CFTypeRef task=createTask(kCFAllocatorDefault);
        result[@"sec_task_created"]=@(task!=NULL);
        if (task) CFRelease(task);
    }
    int (*csopsFunction)(pid_t,unsigned int,void *,size_t)=dlsym(RTLD_DEFAULT,"csops");
    if (csopsFunction) {
        uint32_t flags=0;
        errno=0;
        int status=csopsFunction(getpid(),0,&flags,sizeof(flags)); // CS_OPS_STATUS, read only.
        int saved=errno;
        result[@"csops_result"]=@(status);result[@"csops_errno"]=@(saved);result[@"csops_flags"]=@(flags);
    }
    return result;
}
