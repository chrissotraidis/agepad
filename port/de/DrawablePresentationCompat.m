// Simulator lacks MTLDrawable presentation notifications. Deliver callbacks only
// after its real Core Animation drawable reports composition, never at submission.
// The timestamp below is observation time, not a measured display scanout time.
#import <objc/message.h>
#include "PresentationProgress.h"
@interface DEDrawablePresentationState : NSObject
@property(nonatomic,strong) NSMutableArray *handlers;
@property(nonatomic) CFTimeInterval observedCompositionTime;
@property(nonatomic) BOOL terminal, immediateFIFO;
@property(nonatomic) uint64_t submissionSequence;
@end
@implementation DEDrawablePresentationState
- (void)dealloc {if(!getenv("AGEPAD_QUIET_RENDER_TRACE"))fprintf(stderr,"DE_DRAWABLE_STATE_RELEASE pending=%lu observed=%d\n",(unsigned long)_handlers.count,_observedCompositionTime!=0);}
@end
static char DEDrawableStateKey;
static NSMutableSet *DEPendingDrawables(void) {
 static NSMutableSet *set;static dispatch_once_t once;dispatch_once(&once,^{set=[NSMutableSet new];});return set;
}
static IMP DEOriginalDidComposite;
static void DEAdvancePresentation(id drawable);
static DEDrawablePresentationState *DEDrawableState(id drawable) {
    @synchronized(drawable) {
        DEDrawablePresentationState *state=objc_getAssociatedObject(drawable,&DEDrawableStateKey);
        if (!state) {state=[DEDrawablePresentationState new];state.handlers=[NSMutableArray array];objc_setAssociatedObject(drawable,&DEDrawableStateKey,state,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
        return state;
    }
}
static void DEFinishDrawable(id drawable,BOOL displayed) {
 DEDrawablePresentationState *state=DEDrawableState(drawable);NSArray *handlers;
 @synchronized(state){if(state.terminal)return;state.terminal=YES;state.observedCompositionTime=displayed?CACurrentMediaTime():0;handlers=state.handlers.copy;[state.handlers removeAllObjects];}
 fprintf(stderr,"DE_DRAWABLE_TERMINAL drawable=%p displayed=%d callbacks=%lu time=%s\n",(__bridge void *)drawable,displayed,(unsigned long)handlers.count,displayed?"composition-observation":"zero-dropped");
 if(displayed)DERecordObservedPresentation([drawable layer]);
 for(void (^handler)(id) in handlers)handler(drawable);
 NSMutableSet *pending=DEPendingDrawables();@synchronized(pending){[pending removeObject:drawable];}
}
static void DEDrawableDidComposite(id drawable,SEL selector,BOOL composed) {
 ((void(*)(id,SEL,BOOL))DEOriginalDidComposite)(drawable,selector,composed);
 if(!composed)return;
 DEDrawablePresentationState *current=DEDrawableState(drawable);
 if(getenv("AGEPAD_SUPERSEDED_FIFO_DROP") && current.immediateFIFO && current.submissionSequence){
  NSMutableSet *pending=DEPendingDrawables();NSArray *older;@synchronized(pending){older=pending.allObjects;}
  double nowCall=((double(*)(id,SEL))objc_msgSend)(drawable,sel_registerName("timePresentCalled"));
  for(id old in older){if(old==drawable || [old layer]!=[drawable layer])continue;
   DEDrawablePresentationState *state=DEDrawableState(old);
   if(!state.immediateFIFO || !state.submissionSequence || state.submissionSequence>=current.submissionSequence || state.terminal)continue;
   double oldCall=((double(*)(id,SEL))objc_msgSend)(old,sel_registerName("timePresentCalled"));
   if(oldCall<=0 || nowCall<oldCall || ((BOOL(*)(id,SEL))objc_msgSend)(old,sel_registerName("didComposite")))continue;
   fprintf(stderr,"DE_DRAWABLE_SUPERSEDED_FIFO old=%p sequence=%llu newer=%p sequence=%llu actual_later_composition=1\n",(__bridge void *)old,(unsigned long long)state.submissionSequence,(__bridge void *)drawable,(unsigned long long)current.submissionSequence);
   DEFinishDrawable(old,NO);
  }
 }
 DEFinishDrawable(drawable,YES);DEAdvancePresentation(drawable);
}
static void DEInspectDrawable(id d) {
 if(!d || getenv("AGEPAD_QUIET_RENDER_TRACE"))return;
 for(NSString *name in @[@"timePresentCalled",@"targetPresentationTimestamp",@"targetTimestamp",@"timeAcquired"])
  fprintf(stderr,"DE_DRAWABLE_CLOCK drawable=%p name=%s value=%.9f\n",(__bridge void *)d,name.UTF8String,((double(*)(id,SEL))objc_msgSend)(d,NSSelectorFromString(name)));
 id<MTLTexture> texture=[d texture];CAMetalLayer *layer=[d layer];
 fprintf(stderr,"DE_DRAWABLE_SIZE drawable=%p texture=%lux%lu layer=%gx%g transaction=%d\n",(__bridge void *)d,(unsigned long)[texture width],(unsigned long)[texture height],layer.drawableSize.width,layer.drawableSize.height,layer.presentsWithTransaction);
 for(NSString *name in @[@"surfaceID",@"updateSeed",@"insertSeed",@"presentScheduledInsertSeed"])
  fprintf(stderr,"DE_DRAWABLE_SEED drawable=%p name=%s value=%u\n",(__bridge void *)d,name.UTF8String,((unsigned(*)(id,SEL))objc_msgSend)(d,NSSelectorFromString(name)));
}
static void DEDrawableAddPresentedHandler(id drawable,SEL selector,void (^handler)(id)) {
    if (!handler) DEUnsupported("nil drawable presentation handler");
    NSMutableSet *pending=DEPendingDrawables();@synchronized(pending){[pending addObject:drawable];}
    DEDrawablePresentationState *state=DEDrawableState(drawable);
    BOOL composed;
    @synchronized(state) {composed=state.terminal;if (!composed) [state.handlers addObject:[handler copy]];}
    if(!getenv("AGEPAD_QUIET_RENDER_TRACE"))fprintf(stderr,"DE_DRAWABLE_PRESENT_HANDLER drawable=%p layer=%p parent=%p retained_waiting_for_real_composition=%d\n",(__bridge void *)drawable,(__bridge void *)[drawable layer],(__bridge void *)[[drawable layer] superlayer],!composed);
    static unsigned observations=0;
    if(observations++<3 && !getenv("AGEPAD_QUIET_RENDER_TRACE")) {
      fprintf(stderr,"DE_DRAWABLE_QUERY_NOW drawable=%p composed=%d finished=%d\n",(__bridge void *)drawable,((BOOL(*)(id,SEL))objc_msgSend)(drawable,sel_registerName("didComposite")),((BOOL(*)(id,SEL))objc_msgSend)(drawable,sel_registerName("didFinish")));
      __weak id weakDrawable=drawable;uintptr_t address=(uintptr_t)(__bridge void *)drawable;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{id d=weakDrawable;DEInspectDrawable(d);fprintf(stderr,"DE_DRAWABLE_QUERY_LATER original=%p alive=%d composed=%d finished=%d\n",(void *)address,d!=nil,d?((BOOL(*)(id,SEL))objc_msgSend)(d,sel_registerName("didComposite")):0,d?((BOOL(*)(id,SEL))objc_msgSend)(d,sel_registerName("didFinish")):0);});
    }
    if (composed) {handler(drawable);@synchronized(pending){[pending removeObject:drawable];}}
}
static CFTimeInterval DEDrawablePresentedTime(id drawable,SEL selector) {
    DEDrawablePresentationState *state=DEDrawableState(drawable);
    @synchronized(state) {return state.observedCompositionTime;}
}
static IMP DEOriginalPresentOptions;
// Diagnostic FIFO: allow only one actual presentation per layer until real
// composition. Prevent startup frames being replaced before observation.
@interface DEPresentationFIFO : NSObject
@property(nonatomic,strong) NSMutableArray *pending;
@property(nonatomic,strong) id inFlight;
@end
@implementation DEPresentationFIFO @end
static char DEPresentationFIFOKey;
static dispatch_queue_t DEPresentationQueue(void) {
 static dispatch_queue_t q;static dispatch_once_t once;
 dispatch_once(&once,^{q=dispatch_queue_create("agepad.presentation.fifo",DISPATCH_QUEUE_SERIAL);});return q;
}
static DEPresentationFIFO *DEFIFO(id layer) {
 DEPresentationFIFO *s=objc_getAssociatedObject(layer,&DEPresentationFIFOKey);
 if(!s){s=[DEPresentationFIFO new];s.pending=[NSMutableArray array];objc_setAssociatedObject(layer,&DEPresentationFIFOKey,s,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return s;
}
static void DEStartNextPresentation(DEPresentationFIFO *s) {
 if(s.inFlight || !s.pending.count)return;
 NSArray *request=s.pending.firstObject;[s.pending removeObjectAtIndex:0];
 s.inFlight=request[0];id options=request[1]==NSNull.null?nil:request[1];
 fprintf(stderr,"DE_PRESENT_FIFO_START drawable=%p\n",(__bridge void *)s.inFlight);
 ((void(*)(id,SEL,id))DEOriginalPresentOptions)(s.inFlight,sel_registerName("presentWithOptions:"),options);
}
static void DEAdvancePresentation(id drawable) {
 if(!getenv("AGEPAD_PRESENT_FIFO"))return;
 dispatch_async(DEPresentationQueue(),^{DEPresentationFIFO *s=DEFIFO([drawable layer]);if(s.inFlight==drawable){s.inFlight=nil;DEStartNextPresentation(s);}});
}
static void DETracePresentOptions(id drawable,SEL sel,id options) {
    DEDrawablePresentationState *state=DEDrawableState(drawable);
    NSMutableSet *pending=DEPendingDrawables();@synchronized(pending){static uint64_t sequence=0;state.submissionSequence=++sequence;}
    state.immediateFIFO=[options isKindOfClass:NSDictionary.class] && [options[@"enableFIFO"] boolValue] && [options[@"presentationMode"] integerValue]==0 && [options[@"presentTimeInterval"] doubleValue]==0;
    if(!getenv("AGEPAD_QUIET_RENDER_TRACE"))fprintf(stderr,"DE_DRAWABLE_SUBMIT drawable=%p layer=%p main=%d\n",(__bridge void *)drawable,(__bridge void *)[drawable layer],NSThread.isMainThread);
    DEInspectDrawable(drawable);if(!getenv("AGEPAD_QUIET_RENDER_TRACE"))fprintf(stderr,"DE_DRAWABLE_OPTIONS %s\n",[[options description] UTF8String]);
    CALayer *layer=[drawable layer];
    for(unsigned i=0;!getenv("AGEPAD_QUIET_RENDER_TRACE") && layer && i<12;i++,layer=layer.superlayer)
        fprintf(stderr,"DE_DRAWABLE_ANCESTOR depth=%u layer=%p class=%s hidden=%d bounds=%gx%g\n",i,(__bridge void *)layer,class_getName(layer.class),layer.hidden,layer.bounds.size.width,layer.bounds.size.height);
    if(getenv("AGEPAD_GEOMETRY_TRACE")) {
      static CFTimeInterval last=0;CFTimeInterval now=CACurrentMediaTime();
      if(now-last>2){last=now;CALayer *l=[drawable layer];
        for(unsigned depth=0;l && depth<12;depth++,l=l.superlayer){
          CALayer *p=l.presentationLayer;CATransform3D t=l.transform,st=l.sublayerTransform,pt=p.transform;
          fprintf(stderr,"DE_GEOMETRY_LAYER depth=%u frame=%s bounds=%s position=%s transform=%g,%g,%g,%g sub=%g,%g,%g,%g presentation=%s pt=%g,%g,%g,%g contents=%s gravity=%s animations=%s\n",depth,NSStringFromCGRect(l.frame).UTF8String,NSStringFromCGRect(l.bounds).UTF8String,NSStringFromCGPoint(l.position).UTF8String,t.m11,t.m22,t.m41,t.m42,st.m11,st.m22,st.m41,st.m42,NSStringFromCGRect(p.frame).UTF8String,pt.m11,pt.m22,pt.m41,pt.m42,NSStringFromCGRect(l.contentsRect).UTF8String,l.contentsGravity.UTF8String,l.animationKeys.description.UTF8String);
        }
      }
    }
    if(getenv("AGEPAD_PRESENT_FIFO")){dispatch_async(DEPresentationQueue(),^{DEPresentationFIFO *s=DEFIFO([drawable layer]);[s.pending addObject:@[drawable,options ?: NSNull.null]];DEStartNextPresentation(s);});}
    else ((void(*)(id,SEL,id))DEOriginalPresentOptions)(drawable,sel,options);
}
static IMP DEOriginalDidFinish;
static void DETraceDidFinish(id drawable,SEL sel,BOOL finished) {
    if(!getenv("AGEPAD_QUIET_RENDER_TRACE"))fprintf(stderr,"DE_DRAWABLE_FINISH drawable=%p finished=%d composed=%d main=%d\n",(__bridge void *)drawable,finished,((BOOL(*)(id,SEL))objc_msgSend)(drawable,sel_registerName("didComposite")),NSThread.isMainThread);
    ((void(*)(id,SEL,BOOL))DEOriginalDidFinish)(drawable,sel,finished);
}
static void DEInstallDrawablePresentationCompatibility(void) {
    Class cls=NSClassFromString(@"CAMetalDrawable");
    if (!cls) DEUnsupported("Simulator drawable class unavailable");
    SEL add=sel_registerName("addPresentedHandler:");
    if (class_getInstanceMethod(cls,add)) return;
    Method finish=class_getInstanceMethod(cls,sel_registerName("setDidFinish:"));
    if(finish && !strcmp(method_getTypeEncoding(finish),"v20@0:8B16")){DEOriginalDidFinish=method_getImplementation(finish);class_replaceMethod(cls,sel_registerName("setDidFinish:"),(IMP)DETraceDidFinish,method_getTypeEncoding(finish));}
    Method present=class_getInstanceMethod(cls,sel_registerName("presentWithOptions:"));
    if(present && !strcmp(method_getTypeEncoding(present),"v24@0:8@16")){DEOriginalPresentOptions=method_getImplementation(present);class_replaceMethod(cls,sel_registerName("presentWithOptions:"),(IMP)DETracePresentOptions,method_getTypeEncoding(present));}
    Method composite=class_getInstanceMethod(cls,sel_registerName("setDidComposite:"));
    if (!composite || strcmp(method_getTypeEncoding(composite),"v20@0:8B16")) DEUnsupported("unknown drawable composition callback ABI");
    DEOriginalDidComposite=method_getImplementation(composite);
    class_replaceMethod(cls,sel_registerName("setDidComposite:"),(IMP)DEDrawableDidComposite,method_getTypeEncoding(composite));
    if (!class_addMethod(cls,add,(IMP)DEDrawableAddPresentedHandler,"v@:@?")) DEUnsupported("drawable presentation callback installation");
    SEL time=sel_registerName("presentedTime");
    if (!class_getInstanceMethod(cls,time)) class_addMethod(cls,time,(IMP)DEDrawablePresentedTime,"d@:");
    fprintf(stderr,"DE_DRAWABLE_PRESENTATION_BRIDGE installed; composition observation timing only\n");
}
