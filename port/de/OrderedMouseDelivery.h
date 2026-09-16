#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include "PresentationProgress.h"
#include "OrderedPointerOwnership.h"
#include <stdatomic.h>
static _Atomic unsigned DEOrderedPointerOwners;
BOOL DEOrderedMousePointerIsHeld(void){return atomic_load(&DEOrderedPointerOwners)>0;}
@protocol DEOrderedMouseEvent
@property(nonatomic) NSUInteger type;
@property(nonatomic) NSTimeInterval timestamp;
@end

// The original game can miss an automation-length press delivered entirely
// between simulation polls. Keep a minimum press interval, but serialize ALL
// later mouse events behind its release rather than delaying releases alone.
#ifndef DE_MOUSE_MIN_PRESS_INTERVAL
#define DE_MOUSE_MIN_PRESS_INTERVAL 0.1
#endif
@interface DEOrderedMouseDelivery : NSObject
@property(nonatomic,strong) NSMutableArray *pending;
@property(nonatomic) BOOL waiting;
@property(nonatomic) CFTimeInterval primaryDown, secondaryDown;
@property(nonatomic,strong) id primaryLayer,secondaryLayer;
@property(nonatomic) uint64_t primarySerial,secondarySerial;
@property(nonatomic) uint64_t primaryMotionSerial,secondaryMotionSerial;
@property(nonatomic) CFTimeInterval primaryMotionTime,secondaryMotionTime;
@property(nonatomic) BOOL primaryDragged,secondaryDragged;
@property(nonatomic) BOOL sourcePrimaryDown,sourceSecondaryDown;
- (void)drain;
- (void)enqueue:(id)event layer:(id)layer post:(void (^)(void))post;
@end
@implementation DEOrderedMouseDelivery
- (instancetype)init {
    if ((self=[super init])) _pending=[NSMutableArray new];
    return self;
}
- (void)enqueue:(id)event layer:(id)layer post:(void (^)(void))post {
    NSAssert(NSThread.isMainThread, @"Mouse delivery belongs to the main thread");
    NSUInteger type=[(id<DEOrderedMouseEvent>)event type];BOOL ownsRelease=NO;
    if(type==1 && !self.sourcePrimaryDown){self.sourcePrimaryDown=YES;atomic_fetch_add(&DEOrderedPointerOwners,1);}
    if(type==3 && !self.sourceSecondaryDown){self.sourceSecondaryDown=YES;atomic_fetch_add(&DEOrderedPointerOwners,1);}
    if(type==2 && self.sourcePrimaryDown){self.sourcePrimaryDown=NO;ownsRelease=YES;}
    if(type==4 && self.sourceSecondaryDown){self.sourceSecondaryDown=NO;ownsRelease=YES;}
    [self.pending addObject:@[event,[post copy],layer?:NSNull.null,@(ownsRelease)]];
    [self drain];
}
- (void)dealloc {
    if(_sourcePrimaryDown)atomic_fetch_sub(&DEOrderedPointerOwners,1);
    if(_sourceSecondaryDown)atomic_fetch_sub(&DEOrderedPointerOwners,1);
}
- (void)drain {
    if(self.waiting)return;
    while(self.pending.count) {
        NSArray *item=self.pending.firstObject;
        id<DEOrderedMouseEvent> event=item[0]; NSUInteger type=event.type;
        CFTimeInterval now=CACurrentMediaTime();
        BOOL secondary=type==4 || type==7;
        CFTimeInterval down=secondary?self.secondaryDown:self.primaryDown;
        double remaining=(type==2 || type==4) && down>0 ? MAX(0,down+DE_MOUSE_MIN_PRESS_INTERVAL-now):0;
        // Two later compositions give a polled consumer a chance to observe
        // the press even when its frame interval exceeds the minimum delay.
        // This is not an acknowledgement from the game. Bound the wait so a
        // renderer that stops progressing cannot hold the button forever.
        id layer=secondary?self.secondaryLayer:self.primaryLayer;
        uint64_t serial=secondary?self.secondarySerial:self.primarySerial;
        BOOL release=type==2 || type==4;
        BOOL motion=type==6 || type==7;
        BOOL dragged=secondary?self.secondaryDragged:self.primaryDragged;
        CFTimeInterval phaseTime=down;
        if(release && dragged) {
            serial=secondary?self.secondaryMotionSerial:self.primaryMotionSerial;
            phaseTime=secondary?self.secondaryMotionTime:self.primaryMotionTime;
        }
        // Preserve the initial pointer position until the press can be seen.
        // After that, moves may flow freely; retain the final drag position
        // while pressed before delivering its release. Do not queue one frame
        // per movement, which would accumulate seconds of input lag.
        BOOL observePhase=release || (motion && !dragged);
        if(observePhase && down>0 && serial>0 && DEObservedPresentationSerial(layer)-serial<2 && now-phaseTime<1.0)
            remaining=MAX(remaining,MIN(0.016,1.0-(now-phaseTime)));
        if(remaining>0) {
            self.waiting=YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(remaining*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                self.waiting=NO;[self drain];
            });
            return;
        }
        if(release && down>0 && getenv("AGEPAD_INPUT_TIMING"))
            fprintf(stderr,"DE_MOUSE_RELEASE_GATE type=%lu held_ms=%.3f observed_frames=%llu progress_available=%d timeout=%d\n",(unsigned long)type,1000*(now-down),(unsigned long long)(serial?DEObservedPresentationSerial(layer)-serial:0),serial>0,serial>0 && DEObservedPresentationSerial(layer)-serial<2);
        [self.pending removeObjectAtIndex:0];
        id eventLayer=item[2]==NSNull.null?nil:item[2];
        if(type==1){self.primaryDown=now;self.primaryLayer=eventLayer;self.primarySerial=DEObservedPresentationSerial(eventLayer);self.primaryDragged=NO;}
        if(type==3){self.secondaryDown=now;self.secondaryLayer=eventLayer;self.secondarySerial=DEObservedPresentationSerial(eventLayer);self.secondaryDragged=NO;}
        if(type==6 && self.primaryDown>0){self.primaryDragged=YES;self.primaryMotionSerial=DEObservedPresentationSerial(self.primaryLayer);self.primaryMotionTime=now;}
        if(type==7 && self.secondaryDown>0){self.secondaryDragged=YES;self.secondaryMotionSerial=DEObservedPresentationSerial(self.secondaryLayer);self.secondaryMotionTime=now;}
        if(type==2){self.primaryDown=0;self.primaryLayer=nil;}
        if(type==4){self.secondaryDown=0;self.secondaryLayer=nil;}
        // Retain monotonically ordered timestamps for the delivered stream.
        [event setTimestamp:MAX([event timestamp],now)];
        void (^post)(void)=item[1];
        @try{post();}@finally{if([item[3] boolValue])atomic_fetch_sub(&DEOrderedPointerOwners,1);}
    }
}
@end
static void DEPostOrderedMouseEvent(id event,id layer,void (^post)(void)) {
    static DEOrderedMouseDelivery *delivery;
    static dispatch_once_t once;
    dispatch_once(&once,^{delivery=[DEOrderedMouseDelivery new];});
    [delivery enqueue:event layer:layer post:post];
}
