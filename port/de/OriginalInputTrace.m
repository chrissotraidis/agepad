#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdatomic.h>
static IMP downIMP,upIMP,dragIMP,moveIMP,dispatchIMP;
static _Thread_local long currentEvent;
static _Thread_local unsigned currentType;
static atomic_uint count;
static void mouse(id object,SEL selector,id event,IMP original,unsigned type){
 unsigned ticket=atomic_fetch_add(&count,1);long previous=currentEvent;unsigned previousType=currentType;
 currentEvent=ticket<256?((long(*)(id,SEL))objc_msgSend)(event,sel_registerName("eventNumber")):0;currentType=type;
 double start=CACurrentMediaTime();
 if(currentEvent)fprintf(stderr,"DE_ORIGINAL_MOUSE_BEGIN event=%ld type=%u time=%.6f\n",currentEvent,type,start);
 @try {((void(*)(id,SEL,id))original)(object,selector,event);}
 @finally {if(currentEvent)fprintf(stderr,"DE_ORIGINAL_MOUSE_END event=%ld type=%u handler_ms=%.3f\n",currentEvent,type,1000*(CACurrentMediaTime()-start));currentEvent=previous;currentType=previousType;}
}
static void down(id o,SEL s,id e){mouse(o,s,e,downIMP,1);}
static void up(id o,SEL s,id e){mouse(o,s,e,upIMP,2);}
static void drag(id o,SEL s,id e){mouse(o,s,e,dragIMP,6);}
static void move(id o,SEL s,id e){mouse(o,s,e,moveIMP,5);}
static int dispatch(id object,SEL selector,void *event){
 double start=currentEvent?CACurrentMediaTime():0;
 int result=((int(*)(id,SEL,void*))dispatchIMP)(object,selector,event);
 if(currentEvent)fprintf(stderr,"DE_ORIGINAL_INPUT_DISPATCH event=%ld type=%u status=%d dispatch_ms=%.3f\n",currentEvent,currentType,result,1000*(CACurrentMediaTime()-start));
 return result;
}
__attribute__((constructor))static void install(void){
 if(!getenv("AGEPAD_ORIGINAL_INPUT_TRACE"))return;
 Class cls=objc_getClass("CFeralNSWindow");
 SEL ds=sel_registerName("mouseDown:"),us=sel_registerName("mouseUp:"),es=sel_registerName("dispatchEvent:");
 Method g=class_getInstanceMethod(cls,sel_registerName("mouseDragged:")),m=class_getInstanceMethod(cls,sel_registerName("mouseMoved:"));
 Method d=class_getInstanceMethod(cls,ds),u=class_getInstanceMethod(cls,us),e=class_getInstanceMethod(cls,es);
 if(!g||!m||strcmp(method_getTypeEncoding(g),"v24@0:8@16")||strcmp(method_getTypeEncoding(m),"v24@0:8@16")||!d||!u||!e||strcmp(method_getTypeEncoding(d),"v24@0:8@16")||strcmp(method_getTypeEncoding(u),"v24@0:8@16")||strcmp(method_getTypeEncoding(e),"i24@0:8^v16")){fprintf(stderr,"DE_ORIGINAL_INPUT_TRACE_SKIPPED class_or_ABI_mismatch\n");return;}
 dragIMP=method_getImplementation(g);moveIMP=method_getImplementation(m);
 downIMP=method_getImplementation(d);upIMP=method_getImplementation(u);dispatchIMP=method_getImplementation(e);
 method_setImplementation(g,(IMP)drag);method_setImplementation(m,(IMP)move);
 method_setImplementation(d,(IMP)down);method_setImplementation(u,(IMP)up);method_setImplementation(e,(IMP)dispatch);
 fprintf(stderr,"DE_ORIGINAL_INPUT_TRACE_INSTALLED bounded=256 mouse_move_drag=1 return_values_preserved=1\n");
}
