#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include "../port/de/OrderedMouseDelivery.h"
@interface DeliveryEvent:NSObject <DEOrderedMouseEvent>
@property(nonatomic) NSUInteger type;
@property(nonatomic) NSTimeInterval timestamp;
@end
@implementation DeliveryEvent @end
static void pump(double seconds){CFTimeInterval end=CACurrentMediaTime()+seconds;while(CACurrentMediaTime()<end)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];}
static void send(DEOrderedMouseDelivery *delivery,NSUInteger type,id layer,NSMutableArray *events){DeliveryEvent*e=[DeliveryEvent new];e.type=type;e.timestamp=CACurrentMediaTime();[delivery enqueue:e layer:layer post:^{[events addObject:@(e.type)];}];}
int main(void){@autoreleasepool{
 id layer=[NSObject new],other=[NSObject new];DERecordObservedPresentation(layer);
 DEOrderedMouseDelivery *delivery=[DEOrderedMouseDelivery new];NSMutableArray *events=[NSMutableArray new];
 send(delivery,1,layer,events);send(delivery,2,layer,events);send(delivery,1,layer,events);
 pump(0.13);assert(events.count==1);
 DERecordObservedPresentation(other);DERecordObservedPresentation(other);pump(0.03);assert(events.count==1);
 DERecordObservedPresentation(layer);pump(0.03);assert(events.count==1);
 DERecordObservedPresentation(layer);pump(0.04);assert(([events isEqualToArray:@[@1,@2,@1]]));
 // A fast drag must expose both its initial press and final held position.
 delivery=[DEOrderedMouseDelivery new];events=[NSMutableArray new];
 send(delivery,1,layer,events);send(delivery,6,layer,events);send(delivery,6,layer,events);send(delivery,2,layer,events);
 pump(0.12);assert(([events isEqualToArray:@[@1]]));
 DERecordObservedPresentation(layer);DERecordObservedPresentation(layer);pump(0.04);
 assert(([events isEqualToArray:@[@1,@6,@6]]));
 DERecordObservedPresentation(layer);pump(0.03);assert(events.count==3);
 DERecordObservedPresentation(layer);pump(0.04);assert(([events isEqualToArray:@[@1,@6,@6,@2]]));
 // Right click and a later wheel/primary event cannot overtake its release.
 delivery=[DEOrderedMouseDelivery new];events=[NSMutableArray new];
 send(delivery,3,layer,events);send(delivery,4,layer,events);send(delivery,22,layer,events);send(delivery,1,layer,events);
 pump(0.12);assert(events.count==1);DERecordObservedPresentation(layer);DERecordObservedPresentation(layer);pump(0.04);
 assert(([events isEqualToArray:@[@3,@4,@22,@1]]));
 // No presentation progress must not cause a permanently held mouse button.
 delivery=[DEOrderedMouseDelivery new];events=[NSMutableArray new];CFTimeInterval start=CACurrentMediaTime();
 send(delivery,1,layer,events);send(delivery,2,layer,events);pump(0.2);assert(events.count==1);pump(0.9);
 assert(([events isEqualToArray:@[@1,@2]]));assert(CACurrentMediaTime()-start<1.3);
 puts("PASS ordered primary/secondary, same-layer presentation progress, bounded stalled-renderer release");
}return 0;}
