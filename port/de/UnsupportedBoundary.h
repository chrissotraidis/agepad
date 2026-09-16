#pragma once
// Diagnostic only. Missing APIs stop execution; they never report success.
#import <Foundation/Foundation.h>
#include <execinfo.h>
#include <stdio.h>
#include <unistd.h>

__attribute__((noreturn)) static void DEUnsupported(const char *name) {
    fprintf(stderr,"DE_UNSUPPORTED_BOUNDARY %s\n",name);
    void *frames[32];
    int count=backtrace(frames,32);
    backtrace_symbols_fd(frames,count,STDERR_FILENO);
    fflush(stderr);
    _exit(78);
}

// These declarations establish superclass references for a loader experiment.
// They are NOT AppKit implementations. Even construction stops the probe.
#define DE_DIAGNOSTIC_CLASS(NAME) \
    @interface NAME : NSObject @end \
    @implementation NAME \
    - (instancetype)init { DEUnsupported("- [" #NAME " init]"); } \
    + (BOOL)resolveClassMethod:(SEL)sel { \
        fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[%s %s]\n",#NAME,sel_getName(sel)); \
        DEUnsupported(#NAME); \
    } \
    + (BOOL)resolveInstanceMethod:(SEL)sel { \
        fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[%s %s]\n",#NAME,sel_getName(sel)); \
        DEUnsupported(#NAME); \
    } \
    @end
