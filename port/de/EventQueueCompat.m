// Foundation queue and run-loop pumping. UIKit-to-NSEvent translation is a
// separate, still-required input adapter; this does not synthesize input.
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include "UnsupportedBoundary.h"
@protocol DEQueuedEvent
- (NSUInteger)type;
@property(nonatomic) NSTimeInterval deEnqueuedTime;
@property(nonatomic,readonly) NSTimeInterval timestamp;
@property(nonatomic,readonly) NSInteger eventNumber,clickCount;
@end
@interface DEEventQueue : NSObject
@property(nonatomic,strong) NSMutableArray *events;
- (void)post:(id<DEQueuedEvent>)event atStart:(BOOL)atStart;
- (id)next:(NSUInteger)mask until:(NSDate *)date mode:(NSString *)mode dequeue:(BOOL)dequeue;
@end
@implementation DEEventQueue
- (instancetype)init { if ((self=[super init])) _events=[NSMutableArray array];return self; }
- (void)post:(id<DEQueuedEvent>)event atStart:(BOOL)atStart {
    if (!event) DEUnsupported("nil queued event");
    if (getenv("AGEPAD_INPUT_TIMING") && event.type>=1 && event.type<=7) {
        event.deEnqueuedTime=CACurrentMediaTime();
        fprintf(stderr,"DE_INPUT_TIMING_POST event=%ld type=%lu source=%.6f posted=%.6f clicks=%ld\n",(long)event.eventNumber,(unsigned long)event.type,event.timestamp,event.deEnqueuedTime,(long)event.clickCount);
    }
    @synchronized(self) {
        if (atStart) [self.events insertObject:event atIndex:0];
        else [self.events addObject:event];
    }
    CFRunLoopWakeUp(CFRunLoopGetMain());
}
- (id)next:(NSUInteger)mask until:(NSDate *)date mode:(NSString *)mode dequeue:(BOOL)dequeue {
    if (!NSThread.isMainThread || !date || ![mode isEqualToString:NSDefaultRunLoopMode])
        DEUnsupported("event queue requires main thread, explicit deadline and default mode");
    for (;;) {
        @synchronized(self) {
            for (NSUInteger i=0;i<self.events.count;i++) {
                id<DEQueuedEvent> event=self.events[i];NSUInteger type=event.type;
                if (type<64 && (mask & (1ULL<<type))) {
                    id result=event;
                    if (dequeue) [self.events removeObjectAtIndex:i];
                    if (dequeue && getenv("AGEPAD_INPUT_TIMING") && type>=1 && type<=7) {
                        double now=CACurrentMediaTime();
                        fprintf(stderr,"DE_INPUT_TIMING_TAKE event=%ld type=%lu taken=%.6f queue_ms=%.3f source_age_ms=%.3f\n",(long)event.eventNumber,(unsigned long)type,now,1000*(now-event.deEnqueuedTime),1000*(now-event.timestamp));
                    }
                    if(type<13)fprintf(stderr,"DE_GAME_INPUT_DEQUEUED type=%lu dequeue=%d\n",(unsigned long)type,dequeue);
                    return result;
                }
            }
        }
        NSTimeInterval remaining=date.timeIntervalSinceNow;
        if (remaining<=0) return nil;
        // Bound the interval so a post from another thread is observed even
        // when no UIKit source is ready. Existing run-loop sources still run.
        SInt32 result=CFRunLoopRunInMode((__bridge CFStringRef)mode,MIN(remaining,0.01),true);
        if (result==kCFRunLoopRunFinished) [NSThread sleepForTimeInterval:MIN(MAX(0,date.timeIntervalSinceNow),0.01)];
    }
}
@end
