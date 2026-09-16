#include "EventQueueCompat.m"
@interface DEEventFixture : NSObject <DEQueuedEvent>
@property(nonatomic) NSUInteger type;
@end
@implementation DEEventFixture @end
int main(void) { @autoreleasepool {
    DEEventQueue *q=[DEEventQueue new];DEEventFixture *a=[DEEventFixture new],*b=[DEEventFixture new];a.type=1;b.type=2;
    [q post:a atStart:NO];[q post:b atStart:NO];NSDate *past=NSDate.distantPast;
    BOOL filtering=[q next:4 until:past mode:NSDefaultRunLoopMode dequeue:NO]==b
        && [q next:4 until:past mode:NSDefaultRunLoopMode dequeue:YES]==b
        && [q next:2 until:past mode:NSDefaultRunLoopMode dequeue:YES]==a;
    __block BOOL fired=NO;
    [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:NO block:^(NSTimer *t){fired=YES;[q post:a atStart:YES];}];
    CFAbsoluteTime begin=CFAbsoluteTimeGetCurrent();
    BOOL delivered=[q next:2 until:[NSDate dateWithTimeIntervalSinceNow:0.2] mode:NSDefaultRunLoopMode dequeue:YES]==a;
    double delivery=CFAbsoluteTimeGetCurrent()-begin;begin=CFAbsoluteTimeGetCurrent();
    BOOL expired=[q next:~0ULL until:[NSDate dateWithTimeIntervalSinceNow:0.04] mode:NSDefaultRunLoopMode dequeue:YES]==nil;
    double timeout=CFAbsoluteTimeGetCurrent()-begin;
    BOOL pass=filtering && fired && delivered && expired && delivery>=0.01 && delivery<0.2 && timeout>=0.035 && timeout<0.2;
    printf("{\"filter_and_peek\":%s,\"timer_event_delivered\":%s,\"delivery_seconds\":%g,\"timeout_seconds\":%g,\"pass\":%s}\n",filtering?"true":"false",delivered&&fired?"true":"false",delivery,timeout,pass?"true":"false");
    return pass?0:1;
} }
