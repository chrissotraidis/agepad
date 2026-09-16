#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include "../port/de/OrderedMouseDelivery.h"
#include "../port/de/TouchPointerCompat.m"
@interface PointerFixtureWindow:NSObject
- (id)screen;
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id)space;
@end
@implementation PointerFixtureWindow
- (id)screen{return nil;}
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id)space{return p;}
@end
@interface PointerFixtureGesture:NSObject
@property(nonatomic) CGPoint point;
- (NSInteger)state;
- (CGPoint)locationInView:(id)view;
@end
@implementation PointerFixtureGesture
- (NSInteger)state{return UIGestureRecognizerStateChanged;}
- (CGPoint)locationInView:(id)view{return self.point;}
@end
@interface PointerFixtureEvent:NSObject <DEOrderedMouseEvent>
@property(nonatomic) NSUInteger type;
@property(nonatomic) NSTimeInterval timestamp;
@end
@implementation PointerFixtureEvent @end
static void send(DEOrderedMouseDelivery*d,NSUInteger type){PointerFixtureEvent*e=[PointerFixtureEvent new];e.type=type;e.timestamp=CACurrentMediaTime();[d enqueue:e layer:nil post:^{}];}
static void pump(double seconds){double end=CACurrentMediaTime()+seconds;while(CACurrentMediaTime()<end)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];}
int main(void){@autoreleasepool{
 setenv("AGEPAD_POINTER_STATE","1",1);
 __attribute__((objc_precise_lifetime)) PointerFixtureWindow*w=[PointerFixtureWindow new];
 DEPointer=[DEPointerTracker new];DEPointer.window=(id)w;DEPointer.position=CGPointMake(10,20);
 PointerFixtureGesture*g=[PointerFixtureGesture new];g.point=CGPointMake(40,50);
 DEOrderedMouseDelivery*d=[DEOrderedMouseDelivery new];assert(!DEOrderedMousePointerIsHeld());
 send(d,1);assert(DEOrderedMousePointerIsHeld());[DEPointer track:(id)g];assert(CGPointEqualToPoint(DEUIKitPointerPosition(),CGPointMake(10,20)));
 // Only delivery by the original window changes the polled position while held.
 DEUIKitSetPointerPosition(CGPointMake(25,30));[DEPointer track:(id)g];assert(CGPointEqualToPoint(DEUIKitPointerPosition(),CGPointMake(25,30)));
 send(d,2);send(d,1);pump(0.13);assert(DEOrderedMousePointerIsHeld());
 send(d,2);pump(0.13);assert(!DEOrderedMousePointerIsHeld());
 [DEPointer track:(id)g];assert(CGPointEqualToPoint(DEUIKitPointerPosition(),g.point));
 send(d,2);assert(!DEOrderedMousePointerIsHeld());
 puts("PASS raw UIKit cannot overtake queued button interactions; logical warps and post-release hover remain available");
}return 0;}
