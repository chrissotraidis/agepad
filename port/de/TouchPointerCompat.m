// App-owned pointer state. Initial center is an explicit touch-control policy,
// not a query of the host Mac cursor. UIKit gestures update the stored point.
#import <UIKit/UIKit.h>
#include "UnsupportedBoundary.h"
#include "OrderedPointerOwnership.h"
@interface DEPointerTracker : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic) CGPoint position;
@property(nonatomic,weak) UIWindow *window;
@end
@implementation DEPointerTracker
- (void)track:(UIGestureRecognizer *)gesture {
    if (gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) return;
    CGPoint local=[gesture locationInView:self.window];
    if([gesture isKindOfClass:UILongPressGestureRecognizer.class]){UIView *hit=[self.window hitTest:local withEvent:nil];fprintf(stderr,"DE_TOUCH_HIT state=%ld view=%s super=%s\n",(long)gesture.state,object_getClassName(hit),object_getClassName(hit.superview));}
    CGPoint global=[self.window convertPoint:local toCoordinateSpace:self.window.screen.coordinateSpace];
    if(DEOrderedMousePointerIsHeld()) {
        if(getenv("AGEPAD_INPUT_TIMING"))fprintf(stderr,"DE_POINTER_UIKIT_DEFERRED x=%g y=%g ordered_button_active=1\n",global.x,global.y);
        return;
    }
    @synchronized(self) { self.position=global; }
    fprintf(stderr,"DE_POINTER_UIKIT_UPDATE x=%g y=%g\n",global.x,global.y);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { return YES; }
@end
static DEPointerTracker *DEPointer;
void DEInstallTouchPointer(void) {
    if (!getenv("AGEPAD_POINTER_STATE") || DEPointer) return;
    if (!NSThread.isMainThread) DEUnsupported("pointer installation requires main thread");
    UIWindow *window=nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) if (candidate.isKeyWindow) { window=candidate;break; }
    if (!window) DEUnsupported("pointer requires an actual UIKit window");
    DEPointer=[DEPointerTracker new];DEPointer.window=window;
    DEPointer.position=[window convertPoint:CGPointMake(CGRectGetMidX(window.bounds),CGRectGetMidY(window.bounds)) toCoordinateSpace:window.screen.coordinateSpace];
    UILongPressGestureRecognizer *touch=[[UILongPressGestureRecognizer alloc] initWithTarget:DEPointer action:@selector(track:)];
    touch.minimumPressDuration=0;touch.allowableMovement=CGFLOAT_MAX;touch.cancelsTouchesInView=NO;touch.delaysTouchesBegan=NO;touch.delaysTouchesEnded=NO;touch.delegate=DEPointer;
    [window addGestureRecognizer:touch];
    UIHoverGestureRecognizer *hover=[[UIHoverGestureRecognizer alloc] initWithTarget:DEPointer action:@selector(track:)];
    hover.cancelsTouchesInView=NO;hover.delegate=DEPointer;[window addGestureRecognizer:hover];
    fprintf(stderr,"DE_POINTER_INITIALIZED policy=window-center x=%g y=%g; touch/hover observers installed\n",DEPointer.position.x,DEPointer.position.y);
}
CGPoint DEUIKitPointerPosition(void) {
    if (!getenv("AGEPAD_POINTER_STATE") || !DEPointer) DEUnsupported("uninitialized UIKit pointer state");
    @synchronized(DEPointer) { return DEPointer.position; }
}

// Reposition the app's logical pointer. Never moves the host Mac cursor.
void DEUIKitSetPointerPosition(CGPoint point) {
    if (!getenv("AGEPAD_POINTER_STATE") || !DEPointer)
        DEUnsupported("warp requires initialized UIKit pointer");
    @synchronized(DEPointer) { DEPointer.position=point; }
    fprintf(stderr,"DE_POINTER_WARP x=%g y=%g domain=app\n",point.x,point.y);
}
