// Simulator-only experiment: preserve the original wait predicate while letting
// UIKit/Core Animation deliver real composition callbacks on the main thread.
#include <condition_variable>
#include <mutex>
#include <pthread.h>
#include <dlfcn.h>
#include <cstdlib>
#include <cstdio>
#include <CoreFoundation/CoreFoundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
extern "C" void DEOriginalConditionWait(std::condition_variable *,std::unique_lock<std::mutex> *) __asm__("__ZNSt3__118condition_variable4waitERNS_11unique_lockINS_5mutexEEE");
static void DEPumpGraphicsWait(std::unique_lock<std::mutex> &lock) {
 lock.unlock();
 if (getenv("AGEPAD_GRAPHICS_WAIT_FLUSH")) ((void(*)(id,SEL))objc_msgSend)((id)objc_getClass("CATransaction"),sel_registerName("flush"));
 // Each pump adds up to this much latency to every main-thread GPU wait;
 // 5 ms per frame measurably slowed the simulation clock. Default to 1 ms.
 static double interval=-1;
 if(interval<0){const char *v=getenv("AGEPAD_GRAPHICS_WAIT_PUMP_MS");interval=(v&&*v?atof(v):1.0)/1000.0;}
 CFRunLoopRunInMode(kCFRunLoopDefaultMode,interval,true);
 lock.lock();
}
static void DEConditionWait(std::condition_variable *condition,std::unique_lock<std::mutex> *lock) {
 Dl_info info={};void *caller=__builtin_return_address(0);
 if(getenv("AGEPAD_MAIN_GRAPHICS_WAIT") && pthread_main_np() && dladdr(caller,&info) && (uintptr_t)caller-(uintptr_t)info.dli_fbase==0xa6689c) {
  static bool reported=false;if(!reported){fprintf(stderr,"DE_GRAPHICS_WAIT_MAIN_PUMP original predicate retained; real run-loop callbacks only\n");reported=true;}
  DEPumpGraphicsWait(*lock);return; // legal spurious wake; original loop rechecks counter
 }
 DEOriginalConditionWait(condition,lock);
}
__attribute__((used,section("__DATA,__interpose")))static const struct {const void *replacement,*original;} map[]={{(void *)DEConditionWait,(void *)DEOriginalConditionWait}};
