// Read-only observation at the original renderer's viewport comparison.
// Interpose the imported libc boundary; leave executable instructions, viewport
// data and the real comparison result unchanged.
#include <dlfcn.h>
#include <errno.h>
#include <execinfo.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mach/mach.h>

// Follow the runtime indirections used by the rectangle transform and its
// statically identified state writers. Kernel-assisted reads fail cleanly during initialization; an
// unavailable value must never be reported as zero or dereferenced directly.
static int DEReadMemory(uintptr_t address,void *out,size_t size) {
    vm_size_t copied=0;
    _Static_assert(sizeof(vm_address_t)==sizeof(uintptr_t),"64-bit diagnostic addresses required");
    return vm_read_overwrite(mach_task_self(),address,size,
        (vm_address_t)out,&copied)==KERN_SUCCESS && copied==size;
}
static void DETraceTransformInputs(uintptr_t base) {
    const uintptr_t slots[2]={base+0x5995540,base+0x5995680};
    const uintptr_t indices[2]={base+0x5995518,base+0x5995670};
    for(unsigned i=0;i<2;i++) {
        uint64_t encoded=0,pointer=0;int32_t index=0;uint32_t value=0;
        int available=DEReadMemory(slots[i]+8,&encoded,8) && DEReadMemory(indices[i],&index,4);
        uintptr_t entry=i==0?((slots[i]^~encoded)+(uint64_t)(int64_t)index)<<2:
            ((slots[i]^encoded)-(uint64_t)(int64_t)index)<<4;
        available=available && DEReadMemory(entry,&pointer,8) && DEReadMemory(pointer,&value,4);
        if(available)fprintf(stderr,"DE_TRANSFORM_INPUT kind=%s address=0x%llx value=%u\n",i==0?"scale":"motion",(unsigned long long)pointer,value);
        else fprintf(stderr,"DE_TRANSFORM_INPUT kind=%s unavailable\n",i==0?"scale":"motion");
    }
    // Additional indirections read by callback 0xd8b3e4. These are addresses
    // to compare with the transform inputs, not assumed aliases or causes.
    const struct { const char *name; uintptr_t slot,index; unsigned shift; int inverted,subtract; } callback[] = {
        {"callback-output",0x59956a0,0x5995678,4,1,0},
        {"callback-candidate-a",0x59956f8,0x59956d0,2,1,0},
        {"callback-candidate-b",0x5995730,0x5995720,4,0,1},
        // Scale writer 0xd8a75c, store 0xd8abd8. Static address formulas
        // match its original instructions; snapshots are not writer events.
        {"scale-candidate-a",0x5995578,0x5995568,2,0,1},
        {"scale-candidate-b",0x59955f0,0x59955c8,3,1,0},
        {"scale-comparison-current",0x5995628,0x5995618,1,0,1},
        // Original read-only constants at 0x465c4ac and 0x45f44fc are 2.
        {"scale-comparison-reference",0x59947d8,0x59947b0,2,1,0},
        {"scale-predicate-bits",0x598aef8,0x598aedc,2,1,1},
    };
    for(unsigned i=0;i<sizeof(callback)/sizeof(callback[0]);i++) {
        uintptr_t slot=base+callback[i].slot;
        uint64_t encoded=0,pointer=0;int32_t index=0;uint32_t value=0;
        int available=DEReadMemory(slot+8,&encoded,8) && DEReadMemory(base+callback[i].index,&index,4);
        uintptr_t entry=slot^(callback[i].inverted?~encoded:encoded);
        entry=callback[i].subtract?entry-(uint64_t)(int64_t)index:entry+(uint64_t)(int64_t)index;
        entry<<=callback[i].shift;
        available=available && DEReadMemory(entry,&pointer,8) && DEReadMemory(pointer,&value,4);
        if(available)fprintf(stderr,"DE_CALLBACK_INPUT kind=%s address=0x%llx value=%u\n",callback[i].name,(unsigned long long)pointer,value);
        else fprintf(stderr,"DE_CALLBACK_INPUT kind=%s unavailable\n",callback[i].name);
    }
}

static _Thread_local int tracing;
static _Atomic unsigned records;
static _Atomic unsigned comparisons;
unsigned DEViewportTraceObservedComparisons(void) { return atomic_load(&comparisons); }
static int DEViewportMemcmp(const void *left,const void *right,size_t size) {
    int result=memcmp(left,right,size);
    int saved=errno;
    if(size==24 && !tracing && getenv("AGEPAD_VIEWPORT_STATE_TRACE")) {
        tracing=1;
        atomic_fetch_add(&comparisons,1);
        Dl_info info={0};void *caller=__builtin_return_address(0);
        if(dladdr(caller,&info) && info.dli_fname &&
           strstr(info.dli_fname,"/DEOriginalGame") &&
           (uintptr_t)caller-(uintptr_t)info.dli_fbase==0xa6b5fc) {
            float old[6],next[6];memcpy(old,left,sizeof(old));memcpy(next,right,sizeof(next));
            // Keep normal full-screen traffic quiet; retain the first three
            // actual offset requests and their producer stacks.
            if((next[0]!=0 || next[1]!=0) && atomic_fetch_add(&records,1)<3) {
                void *frames[48];int count=backtrace(frames,48);
                fprintf(stderr,"DE_VIEWPORT_STATE base=%p old=%g,%g,%g,%g,%g,%g next=%g,%g,%g,%g,%g,%g comparison=%d\n",
                    info.dli_fbase,old[0],old[1],old[2],old[3],old[4],old[5],
                    next[0],next[1],next[2],next[3],next[4],next[5],result);
                backtrace_symbols_fd(frames,count,2);
            }
        }
        tracing=0;
    }
    errno=saved;return result;
}
__attribute__((used)) static struct {const void *replacement,*original;}
interpose_viewport __attribute__((section("__DATA,__interpose"))) =
    {(const void *)DEViewportMemcmp,(const void *)memcmp};

// The compositor has a second viewport path that does not call the setter
// above. At its imported pool-push boundary, x23 is its optional float rect.
// Capture the preserved register before a C prologue can reuse it. Observe
// only the verified callsite; never dereference registers from other callers.
extern void *objc_autoreleasePoolPush(void);
static _Atomic unsigned poolCalls, compositorCalls, offsetCalls;
unsigned DEViewportTraceObservedPoolCalls(void) { return atomic_load(&poolCalls); }
__attribute__((used,noinline)) static void DEObserveCompositor(void *caller,const void *rect) {
    int saved=errno;
    atomic_fetch_add(&poolCalls,1);
    if(!tracing && getenv("AGEPAD_VIEWPORT_STATE_TRACE")) {
        tracing=1;
        Dl_info info={0};
        if(dladdr(caller,&info) && info.dli_fname &&
           strstr(info.dli_fname,"/DEOriginalGame") &&
           (uintptr_t)caller-(uintptr_t)info.dli_fbase==0xa6d300) {
            float v[4]={0};if(rect)memcpy(v,rect,sizeof(v));
            unsigned normal=atomic_fetch_add(&compositorCalls,1);
            int offset=rect && (v[0]!=0 || v[1]!=0);
            if(normal<3 || (offset && atomic_fetch_add(&offsetCalls,1)<3)) {
                fprintf(stderr,"DE_COMPOSITOR_RECT base=%p supplied=%d rect=%g,%g,%g,%g\n",info.dli_fbase,rect!=NULL,v[0],v[1],v[2],v[3]);
                DETraceTransformInputs((uintptr_t)info.dli_fbase);
                void *frames[48];int n=backtrace(frames,48);backtrace_symbols_fd(frames,n,2);
            }
        }
        tracing=0;
    }
    errno=saved;
}
__attribute__((naked)) static void *DEViewportPoolPush(void) {
    __asm__ volatile(
        "stp x29, x30, [sp, #-16]!\n"
        "mov x29, sp\n"
        "mov x0, x30\n"
        "mov x1, x23\n"
        "bl _DEObserveCompositor\n"
        "ldp x29, x30, [sp], #16\n"
        "b _objc_autoreleasePoolPush\n");
}
__attribute__((used)) static struct {const void *replacement,*original;}
interpose_pool __attribute__((section("__DATA,__interpose"))) =
    {(const void *)DEViewportPoolPush,(const void *)objc_autoreleasePoolPush};
