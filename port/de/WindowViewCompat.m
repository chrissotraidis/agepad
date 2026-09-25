// UIKit hosting for original AppKit window/view objects. Original engine
// layers are attached directly; this does not draw substitute game content.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/CAMetalLayer.h>
#import <GameController/GameController.h>
#include "UnsupportedBoundary.h"
#include <dlfcn.h>
#include "RenderScale.h"
#include "DrawablePresentationCompat.m"
@class NSWindow, DEGameTrackingController;
extern id DEUIKitScreenObject(UIScreen *screen);
@protocol DEColorObject
- (CGColorRef)CGColor;
@end
@protocol DEGameMouseEvent
@property(nonatomic) NSUInteger type,modifierFlags;
@property(nonatomic) CGPoint locationInWindow;
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) NSInteger windowNumber,buttonNumber,clickCount,eventNumber;
@property(nonatomic) CGFloat deltaX,deltaY;
@property(nonatomic) float pressure;
@property(nonatomic,weak) id window;
@property(nonatomic) unsigned short keyCode;
@property(nonatomic,copy) NSString *characters,*charactersIgnoringModifiers;
@property(nonatomic,getter=isARepeat) BOOL ARepeat;
@end
#include "OrderedMouseDelivery.h"
@interface DEGameViewHost : UIView <UIGestureRecognizerDelegate>
@property(nonatomic,strong) CALayer *gameLayer;
@property(nonatomic,weak) id originalView;
@property(nonatomic,strong) UITouch *gameTouch;
@property(nonatomic) NSInteger gameClickCount;
@property(nonatomic) UIEventButtonMask gameButtonMask;
@property(nonatomic) CGPoint previousTouchPoint;
@property(nonatomic,strong) UIButton *touchOrderButton;
@property(nonatomic,strong) NSArray<UIButton *> *touchShortcutButtons;
@property(nonatomic) BOOL touchCommandMode;
// Apple Pencil sticky orders (AGEPAD_PENCIL_STICKY_ORDER), gameplay only.
@property(nonatomic) BOOL pencilPending,pendingIsPencil,pencilDragging,forceSecondary,overrideActive;
@property(nonatomic) CGPoint pencilStart,overridePoint;
@property(nonatomic) NSTimeInterval pencilStartTime;
- (void)refreshTouchCommandButton;
- (void)installNativeGestures;
- (void)nativeMouse:(NSUInteger)type point:(CGPoint)point wheel:(CGFloat)wheel;
@end
static void DEPostGameKey(unsigned short macKey, NSString *characters, BOOL pressed);
static BOOL DEGlobalTouchCommandMode;
// Pencil: a tap or drag-box on the map selects and arms orders; further map
// taps are right-click orders; a hold is a left click that disarms. HUD taps
// (top bar, bottom panel/minimap) stay left clicks and disarm, so a build
// button followed by a map tap places the building.
static BOOL DEPencilOrderArmed;
static BOOL DEPencilMatchActive(void) {
    static int (*active)(void);static BOOL looked;
    if (!looked) { looked=YES;active=(int(*)(void))dlsym(RTLD_DEFAULT,"DEGameMatchActive"); }
    return active && active();
}
static NSHashTable<DEGameViewHost *> *DETouchCommandHosts;
static void DERefreshTouchCommandButtons(void) {
    for (DEGameViewHost *host in DETouchCommandHosts.allObjects) {
        host.touchCommandMode=DEGlobalTouchCommandMode;
        [host refreshTouchCommandButton];
    }
}
static void DELogHostGeometry(NSString *phase, UIView *host) {
    if (!getenv("AGEPAD_HOST_GEOMETRY_TRACE") || !host) return;
    UIWindow *window=host.window;
    UIView *root=window.rootViewController.view;
    UIScreen *screen=window.screen ?: UIScreen.mainScreen;
    UIWindowScene *scene=window.windowScene;
    UIInterfaceOrientation orientation=scene ? scene.interfaceOrientation : UIInterfaceOrientationUnknown;
    fprintf(stderr,
        "DE_HOST_GEOMETRY phase=%s orientation=%ld scale=%g screen=%s native=%s coordinate=%s window=%s root_frame=%s root_bounds=%s host_frame=%s host_bounds=%s layer_frame=%s layer_bounds=%s layer_transform=%g,%g,%g,%g\n",
        phase.UTF8String,(long)orientation,screen.scale,
        NSStringFromCGRect(screen.bounds).UTF8String,NSStringFromCGRect(screen.nativeBounds).UTF8String,
        NSStringFromCGRect(screen.coordinateSpace.bounds).UTF8String,
        NSStringFromCGRect(window.bounds).UTF8String,NSStringFromCGRect(root.frame).UTF8String,
        NSStringFromCGRect(root.bounds).UTF8String,NSStringFromCGRect(host.frame).UTF8String,
        NSStringFromCGRect(host.bounds).UTF8String,NSStringFromCGRect(host.layer.frame).UTF8String,
        NSStringFromCGRect(host.layer.bounds).UTF8String,host.layer.affineTransform.a,host.layer.affineTransform.b,
        host.layer.affineTransform.c,host.layer.affineTransform.d);
}
// Inspect existing methods without invoking the diagnostic resolveInstanceMethod.
static BOOL DEHasMouseHandler(Class cls,SEL action) {
 for(;cls;cls=class_getSuperclass(cls)){unsigned count=0;Method *methods=class_copyMethodList(cls,&count);BOOL found=NO;for(unsigned i=0;i<count;i++)if(method_getName(methods[i])==action){found=YES;break;}free(methods);if(found)return YES;}return NO;
}
static void DELogTouchDetail(UITouch *touch, NSUInteger type) {
    if (!getenv("AGEPAD_TOUCH_DETAIL_TRACE") || !touch) return;
    CGPoint precise=[touch preciseLocationInView:touch.view];
    fprintf(stderr,
        "DE_TOUCH_DETAIL type=%lu phase=%lu touch_type=%lu taps=%lu timestamp=%.6f force=%g max_force=%g major=%g tolerance=%g precise=%g,%g\n",
        (unsigned long)type,(unsigned long)touch.phase,(unsigned long)touch.type,
        (unsigned long)touch.tapCount,touch.timestamp,touch.force,
        touch.maximumPossibleForce,touch.majorRadius,touch.majorRadiusTolerance,
        precise.x,precise.y);
}
static void DELogButtonMask(UIEvent *event, NSUInteger type, UIEventButtonMask mask) {
    if (!getenv("AGEPAD_BUTTON_MASK_TRACE") || !event) return;
    fprintf(stderr,"DE_BUTTON_MASK type=%lu event_type=%ld mask=%lu primary=%d secondary=%d\n",
        (unsigned long)type,(long)event.type,(unsigned long)mask,
        (mask & UIEventButtonMaskPrimary) != 0,
        (mask & UIEventButtonMaskSecondary) != 0);
}
static void DELogSynthesizedMouse(NSUInteger phase, id<DEGameMouseEvent> event, UIEventButtonMask mask, SEL action) {
    if (!getenv("AGEPAD_BUTTON_MASK_TRACE") || !event) return;
    fprintf(stderr,"DE_SYNTH_MOUSE phase=%lu event_type=%lu button_number=%ld mask=%lu action=%s\n",
        (unsigned long)phase,(unsigned long)event.type,(long)event.buttonNumber,
        (unsigned long)mask,sel_getName(action));
}
@implementation DEGameViewHost
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame]) && getenv("AGEPAD_TOUCH_COMMAND_OVERLAY")) {
        if (!DETouchCommandHosts) DETouchCommandHosts=[NSHashTable weakObjectsHashTable];
        [DETouchCommandHosts addObject:self];
        _touchOrderButton=[UIButton buttonWithType:UIButtonTypeSystem];
        [_touchOrderButton addTarget:self action:@selector(toggleTouchCommand:) forControlEvents:UIControlEventTouchUpInside];
        [_touchOrderButton setTitleColor:[UIColor colorWithRed:0.16 green:0.09 blue:0.04 alpha:1.0] forState:UIControlStateNormal];
        _touchOrderButton.backgroundColor=[UIColor colorWithRed:0.78 green:0.66 blue:0.46 alpha:0.96];
        _touchOrderButton.layer.borderColor=[UIColor colorWithRed:0.37 green:0.20 blue:0.08 alpha:1.0].CGColor;
        _touchOrderButton.layer.borderWidth=2.0;
        _touchOrderButton.layer.cornerRadius=4.0;
        _touchOrderButton.titleLabel.font=[UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        _touchOrderButton.accessibilityLabel=@"Order command mode";
        [self addSubview:_touchOrderButton];
        NSMutableArray<UIButton *> *shortcuts=[NSMutableArray new];
        NSArray *titles=@[@"IDLE",@"TOWN",@"ZOOM +",@"ZOOM −",@"MENU"];
        for(NSUInteger i=0;i<titles.count;i++) {
            UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
            button.tag=i;[button setTitle:titles[i] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(touchShortcut:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];[shortcuts addObject:button];
        }
        self.touchShortcutButtons=shortcuts;
        for(UIButton *button in [@[_touchOrderButton] arrayByAddingObjectsFromArray:shortcuts]) {
            [button setTitleColor:[UIColor colorWithRed:0.98 green:0.85 blue:0.56 alpha:1] forState:UIControlStateNormal];
            button.backgroundColor=[UIColor colorWithRed:0.38 green:0.055 blue:0.035 alpha:0.96];
            button.layer.borderColor=[UIColor colorWithRed:0.75 green:0.55 blue:0.23 alpha:1].CGColor;
            button.layer.borderWidth=2;button.layer.cornerRadius=2;
            button.titleLabel.font=[UIFont fontWithName:@"Georgia-Bold" size:14];
        }
        _touchOrderButton.accessibilityHint=@"Tap a target to issue an order. Two-finger tap also orders.";
        shortcuts[0].accessibilityLabel=@"Select idle villager";
        shortcuts[1].accessibilityLabel=@"Select town center";
        shortcuts[2].accessibilityLabel=@"Zoom in";
        shortcuts[3].accessibilityLabel=@"Zoom out";
        shortcuts[4].accessibilityLabel=@"Game menu";
        [self refreshTouchCommandButton];
        [self installNativeGestures];
        fprintf(stderr,"DE_TOUCH_COMMAND_OVERLAY installed style=gold-red-side-strip\n");
    }
    return self;
}
- (void)touchShortcut:(UIButton *)button {
    if(button.tag==2 || button.tag==3) {
        [self nativeMouse:22 point:CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds)) wheel:button.tag==2?1:-1];return;
    }
    unsigned short key=button.tag==0?47:button.tag==1?4:109;
    NSString *characters=button.tag==0?@".":button.tag==1?@"h":@"\uF70D";
    DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();
    DEPencilOrderArmed=button.tag==0 || button.tag==1; // IDLE/TOWN select units; MENU does not.
    DEPostGameKey(key,characters,YES);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{DEPostGameKey(key,characters,NO);});
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)refreshTouchCommandButton {
    if (!self.touchOrderButton) return;
    [self.touchOrderButton setTitle:DEGlobalTouchCommandMode?@"CANCEL":@"ORDER" forState:UIControlStateNormal];
}
- (void)toggleTouchCommand:(UIButton *)sender {
    DEGlobalTouchCommandMode=!DEGlobalTouchCommandMode;
    DERefreshTouchCommandButtons();
    fprintf(stderr,"DE_TOUCH_COMMAND_MODE mode=%s\n",DEGlobalTouchCommandMode?"order":"select");
}
- (void)sendGameMouse:(NSUInteger)type touch:(UITouch *)touch cancelled:(BOOL)cancelled {
 id owner=self.originalView;
 DELogTouchDetail(touch,type);
 fprintf(stderr,"DE_GAME_TOUCH_HOST host=%s owner=%s type=%lu\n",object_getClassName(self),object_getClassName(owner),(unsigned long)type);
 SEL action=NSSelectorFromString(type==1?@"mouseDown:":type==2?@"mouseUp:":type==5?@"mouseMoved:":@"mouseDragged:");
 // UIKit clears buttonMask on release. Use the mask captured at touchesBegan
 // for the whole gesture, including drag and release, just like ORDER mode.
 BOOL secondary=(self.forceSecondary || DEGlobalTouchCommandMode || (self.gameButtonMask & UIEventButtonMaskSecondary)) && (type==1 || type==2 || type==6);
 NSUInteger eventType=type==1?(secondary?3:1):type==2?(secondary?4:2):type==6?(secondary?7:6):type;
 id<DEGameMouseEvent> e=[NSClassFromString(@"NSEvent") new];
 CGPoint point=cancelled?CGPointMake(-100,-100):self.overrideActive?self.overridePoint:[touch locationInView:self.window];
 e.type=eventType;e.locationInWindow=point;e.timestamp=self.overrideActive?NSProcessInfo.processInfo.systemUptime:touch.timestamp;e.modifierFlags=0;e.buttonNumber=secondary?1:0;e.clickCount=type==5?0:self.gameClickCount;e.pressure=(type==2 || type==5)?0:1;
 e.window=((id(*)(id,SEL))objc_msgSend)(owner,sel_registerName("window"));
 e.windowNumber=((NSInteger(*)(id,SEL))objc_msgSend)(e.window,sel_registerName("windowNumber"));
 id content=((id(*)(id,SEL))objc_msgSend)(e.window,sel_registerName("contentView"));
 UIView *contentHost=((id(*)(id,SEL))objc_msgSend)(content,sel_registerName("deHost"));
 CGPoint contentPoint=cancelled?CGPointMake(-100,-100):self.overrideActive?[self.window convertPoint:self.overridePoint toView:contentHost]:[touch locationInView:contentHost];
 e.locationInWindow=CGPointMake(contentPoint.x-contentHost.bounds.origin.x,CGRectGetMaxY(contentHost.bounds)-contentPoint.y);
 e.deltaX=type==6?(point.x-self.previousTouchPoint.x):0;e.deltaY=type==6?(point.y-self.previousTouchPoint.y):0;
 static NSInteger sequence=0;e.eventNumber=++sequence;self.previousTouchPoint=point;
 DELogSynthesizedMouse(type,e,self.gameButtonMask,action);
 if (secondary) fprintf(stderr,"DE_TOUCH_COMMAND_EVENT phase=%lu event_type=%lu button_number=%ld\n",(unsigned long)type,(unsigned long)eventType,(long)e.buttonNumber);
 fprintf(stderr,"DE_GAME_TOUCH type=%lu action=%s view=%s x=%g y=%g taps=%lu cancelled=%d\n",(unsigned long)type,sel_getName(action),object_getClassName(owner),point.x,point.y,(unsigned long)touch.tapCount,cancelled);
 id app=((id(*)(id,SEL))objc_msgSend)(NSClassFromString(@"NSApplication"),sel_registerName("sharedApplication"));
 void (^post)(void)=^{
     ((void(*)(id,SEL,id,BOOL))objc_msgSend)(app,sel_registerName("postEvent:atStart:"),e,NO);
     fprintf(stderr,"DE_GAME_TOUCH_ENQUEUED type=%lu\n",(unsigned long)type);
 };
 DEPostOrderedMouseEvent((id)e,self.gameLayer,post);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.gameTouch)return;self.gameTouch=touches.anyObject;
 // Simulator mouse-backed touches can report tapCount=0 on release after
 // reporting 1 on press. Preserve the click identity across the mouse pair.
 self.gameClickCount=MAX((NSInteger)self.gameTouch.tapCount,1);
 self.gameButtonMask=event.buttonMask;DELogButtonMask(event,1,self.gameButtonMask);
 self.pencilPending=NO;self.pencilDragging=NO;
 BOOL pencil=self.gameTouch.type==UITouchTypePencil;
 BOOL defer=!DEGlobalTouchCommandMode && DEPencilMatchActive() &&
     ((pencil && getenv("AGEPAD_PENCIL_STICKY_ORDER")) || (!pencil && getenv("AGEPAD_TOUCH_DEFER_PRESS")));
 if(defer) {
     // In a match, decide the button when the gesture resolves. Fingers wait
     // briefly so a second finger (two-finger order tap) never leaves a stray
     // left click or selection box behind; the Pencil waits for tap/hold/drag.
     self.pencilPending=YES;self.pendingIsPencil=pencil;
     self.pencilStart=[self.gameTouch locationInView:self.window];self.pencilStartTime=self.gameTouch.timestamp;
     [self sendGameMouse:5 touch:self.gameTouch cancelled:NO];
     if(!pencil) {
         UITouch *touch=self.gameTouch;
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW,150*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
             if(self.pencilPending && self.gameTouch==touch){[self commitPendingPress];fprintf(stderr,"DE_TOUCH_DEFERRED_PRESS reason=held\n");}
         });
     }
     return;
 }
 // A touch can relocate the virtual pointer without a hardware hover phase.
 // Preserve AppKit's move-before-button ordering at the same actual point.
 if(getenv("AGEPAD_TOUCH_MOVE_BEFORE_DOWN")) [self sendGameMouse:5 touch:self.gameTouch cancelled:NO];
 [self sendGameMouse:1 touch:self.gameTouch cancelled:NO];
}
// Left button down at the original contact point; the gesture continues as a
// normal press/drag (selection box) and releases in touchesEnded.
- (void)commitPendingPress {
 self.pencilPending=NO;self.pencilDragging=YES;self.gameClickCount=1;
 self.overrideActive=YES;self.overridePoint=self.pencilStart;
 [self sendGameMouse:5 touch:self.gameTouch cancelled:NO];[self sendGameMouse:1 touch:self.gameTouch cancelled:NO];
 self.overrideActive=NO;
}
// A complete single click at the original contact point with a real ~60 ms
// press. A same-instant down/up pair (or tapCount>1 double-clicks from quick
// repeated taps) was not handled as a plain click by the engine.
- (void)sendPendingClick:(BOOL)secondary {
 UITouch *touch=self.gameTouch;CGPoint point=self.pencilStart;
 self.gameClickCount=1;self.overrideActive=YES;self.overridePoint=point;self.forceSecondary=secondary;
 [self sendGameMouse:5 touch:touch cancelled:NO];[self sendGameMouse:1 touch:touch cancelled:NO];
 self.overrideActive=NO;self.forceSecondary=NO;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
     self.gameClickCount=1;self.overrideActive=YES;self.overridePoint=point;self.forceSecondary=secondary;
     [self sendGameMouse:2 touch:touch cancelled:NO];
     self.overrideActive=NO;self.forceSecondary=NO;
 });
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.pencilPending && self.gameTouch && [touches containsObject:self.gameTouch]) {
     CGPoint now=[self.gameTouch locationInView:self.window];
     if(hypot(now.x-self.pencilStart.x,now.y-self.pencilStart.y)<8){[self sendGameMouse:5 touch:self.gameTouch cancelled:NO];return;}
     [self commitPendingPress]; // Drag: selection box from the original point.
 }
 if(self.gameTouch && [touches containsObject:self.gameTouch]) DELogButtonMask(event,6,self.gameButtonMask);
 if(self.gameTouch && [touches containsObject:self.gameTouch])[self sendGameMouse:6 touch:self.gameTouch cancelled:NO];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.pencilPending && self.gameTouch && [touches containsObject:self.gameTouch]) {
     BOOL hud=[self pencilPointInHUD:self.pencilStart];
     NSTimeInterval held=self.gameTouch.timestamp-self.pencilStartTime;
     BOOL order=NO;const char *reason;
     if(!self.pendingIsPencil){reason="finger";if(!hud)DEPencilOrderArmed=YES;}
     else if(hud){DEPencilOrderArmed=NO;reason="hud";}
     else if(held>=0.45){DEPencilOrderArmed=NO;reason="hold";}
     else if(DEPencilOrderArmed){order=YES;reason="order";}
     else {DEPencilOrderArmed=YES;reason="select";}
     [self sendPendingClick:order];
     self.pencilPending=NO;self.gameTouch=nil;
     fprintf(stderr,"DE_PENCIL_TAP kind=%s held=%.2f armed=%d\n",reason,held,DEPencilOrderArmed);
     return;
 }
 if(self.pencilDragging && self.gameTouch && [touches containsObject:self.gameTouch]) {
     self.pencilDragging=NO;
     NSTimeInterval held=self.gameTouch.timestamp-self.pencilStartTime;
     CGPoint end=[self.gameTouch locationInView:self.window];
     BOOL box=hypot(end.x-self.pencilStart.x,end.y-self.pencilStart.y)>=8;
     // A drag-box selects (arm orders); a finger long-press without movement
     // behaves like a Pencil hold and disarms.
     DEPencilOrderArmed=box?![self pencilPointInHUD:self.pencilStart]:(held<0.45 && DEPencilOrderArmed);
     fprintf(stderr,"DE_PENCIL_DRAG box=%d armed=%d\n",box,DEPencilOrderArmed);
 }
 if(self.gameTouch && [touches containsObject:self.gameTouch]) DELogButtonMask(event,2,self.gameButtonMask);
 if(self.gameTouch && [touches containsObject:self.gameTouch]){
     // UIKit may coalesce a short drag into begin/end (also seen in Simulator).
     // Commit its final position before mouseUp so the original engine sees
     // the selection rectangle even when no touchesMoved callback was delivered.
     CGPoint finalPoint=[self.gameTouch locationInView:self.window];
     if(hypot(finalPoint.x-self.previousTouchPoint.x,finalPoint.y-self.previousTouchPoint.y)>1.0)
         [self sendGameMouse:6 touch:self.gameTouch cancelled:NO];
     [self sendGameMouse:2 touch:self.gameTouch cancelled:NO];self.gameTouch=nil;if(DEGlobalTouchCommandMode){DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();fprintf(stderr,"DE_TOUCH_COMMAND_MODE mode=select reason=target-complete\n");}}
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.pencilPending && self.gameTouch && [touches containsObject:self.gameTouch]) {
     self.pencilPending=NO;self.gameTouch=nil; // No button was pressed yet.
     fprintf(stderr,"DE_TOUCH_DEFERRED_CANCELLED\n");return;
 }
 self.pencilDragging=NO;
 if(self.gameTouch && [touches containsObject:self.gameTouch]) DELogButtonMask(event,2,self.gameButtonMask);
 if(self.gameTouch && [touches containsObject:self.gameTouch]){[self sendGameMouse:6 touch:self.gameTouch cancelled:YES];[self sendGameMouse:2 touch:self.gameTouch cancelled:YES];self.gameTouch=nil;if(DEGlobalTouchCommandMode){DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();fprintf(stderr,"DE_TOUCH_COMMAND_MODE mode=select reason=cancelled\n");}}
}
- (BOOL)pencilPointInHUD:(CGPoint)windowPoint {
    // DE's top resource bar and bottom command panel/minimap bands.
    CGPoint local=[self convertPoint:windowPoint fromView:self.window];CGFloat h=self.bounds.size.height;
    return local.y<h*0.05 || local.y>h*0.83;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.gameLayer) {
        [CATransaction begin];[CATransaction setDisableActions:YES];
        self.gameLayer.frame=self.bounds;self.gameLayer.contentsScale=DERenderScale(self.window.screen);
        [CATransaction commit];
    }
    if (self.touchOrderButton) {
        // Thumb strip stays above the minimap and outside the bottom command HUD.
        CGFloat width=76,height=44,gap=8;
        CGFloat x=CGRectGetMaxX(self.bounds)-self.safeAreaInsets.right-width-12;
        CGFloat y=CGRectGetMidY(self.bounds)-(6*height+5*gap)/2;
        NSArray *buttons=[@[self.touchOrderButton] arrayByAddingObjectsFromArray:self.touchShortcutButtons];
        for(NSUInteger i=0;i<buttons.count;i++) {
            UIButton *button=buttons[i];button.frame=CGRectMake(x,y+i*(height+gap),width,height);
            [self bringSubviewToFront:button];
        }
    }
}
@end
@interface NSView : UIResponder
@property(nonatomic,strong) DEGameViewHost *deHost;
@property(nonatomic,strong) DEGameTrackingController *deTracking;
@property(nonatomic,weak) NSView *superview;
@property(nonatomic,weak) NSWindow *deWindow;
@property(nonatomic,strong) NSMutableArray<NSView *> *deSubviews;
@property(nonatomic) BOOL wantsLayer;
@property(nonatomic,weak) UIResponder *deNextResponder;
- (instancetype)initWithFrame:(CGRect)frame;
- (CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (CGRect)bounds;
- (NSView *)hitTest:(CGPoint)point;
- (NSWindow *)window;
- (CALayer *)layer;
- (void)resetCursorRects;
@end
#include "LegacyWebViewHost.m"
@interface DEGameTrackingController : NSObject
@property(nonatomic,weak) UIView *host;
@property(nonatomic,strong) NSMutableArray<DEWebTrackingRecord *> *records;
- (void)hover:(UIHoverGestureRecognizer *)gesture;
@end
@implementation DEGameTrackingController
- (void)hover:(UIHoverGestureRecognizer *)gesture {
    UIView *host=self.host;
    CGPoint point=[gesture locationInView:host];
    BOOL ended=gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled;
    for (DEWebTrackingRecord *record in self.records.copy) {
        BOOL inside=!ended && CGRectContainsPoint([record.area rect],point);
        if (inside==record.inside) continue;
        record.inside=inside;
        SEL action=inside?@selector(mouseEntered:):@selector(mouseExited:);
        id owner=[record.area owner];
        if (![owner respondsToSelector:action]) continue;
        id<DEHoverEvent> event=[NSClassFromString(@"NSEvent") new];
        if (!event) DEUnsupported("game hover event unavailable");
        [event setType:inside?8:9];
        [event setLocationInWindow:[gesture locationInView:host.window]];
        [event setTimestamp:NSProcessInfo.processInfo.systemUptime];
        [event setTrackingArea:record.area];
        ((void(*)(id,SEL,id))objc_msgSend)(owner,action,event);
    }
}
@end

static UIView *DEHostView(id view) {
    if (!view) return nil;
    if ([view isKindOfClass:UIView.class]) return view;
    if ([view isKindOfClass:NSView.class]) return ((NSView *)view).deHost;
    Class wak=NSClassFromString(@"WAKView");
    if (wak && [view isKindOfClass:wak]) return DELegacyHost(view);
    DEUnsupported("unsupported view host object");
}
static void DEUIKitWantsLayer(id view,SEL selector,BOOL wants) {
    if (!wants) DEUnsupported("UIKit view cannot disable layer backing");
    fprintf(stderr,"DE_UIKIT_NATIVE_VIEW_LAYER existing UIKit layer\n");
}
void DEInstallNativeViewCompatibility(void) {
    Class cls=NSClassFromString(@"CFeralNSWebView");
    fprintf(stderr,"DE_NATIVE_VIEW_CLASS present=%d parent=%s uiview=%d\n",cls!=Nil,cls?class_getName(class_getSuperclass(cls)):"none",cls?[cls isSubclassOfClass:UIView.class]:0);
    Class wak=NSClassFromString(@"WAKView");
    if (cls && wak && [cls isSubclassOfClass:wak] && !class_getInstanceMethod(cls,@selector(setWantsLayer:)))
        class_addMethod(cls,@selector(setWantsLayer:),(IMP)DEWAKWantsLayer,"v@:B");
    if (cls && wak && [cls isSubclassOfClass:wak]) {
        if (!class_getInstanceMethod(cls,@selector(addTrackingArea:))) class_addMethod(cls,@selector(addTrackingArea:),(IMP)DEWAKAddTracking,"v@:@");
        if (!class_getInstanceMethod(cls,@selector(removeTrackingArea:))) class_addMethod(cls,@selector(removeTrackingArea:),(IMP)DEWAKRemoveTracking,"v@:@");
        if (!DEOriginalWebSetFrame) {
            Method method=class_getInstanceMethod(cls,@selector(setFrame:));
            if (!method) DEUnsupported("legacy web frame setter unavailable");
            DEOriginalWebSetFrame=method_getImplementation(method);
            class_replaceMethod(cls,@selector(setFrame:),(IMP)DEWAKSetFrame,method_getTypeEncoding(method));
        }
    }
    if (cls && [cls isSubclassOfClass:UIView.class] && !class_getInstanceMethod(cls,@selector(setWantsLayer:)))
        class_addMethod(cls,@selector(setWantsLayer:),(IMP)DEUIKitWantsLayer,"v@:B");
}
@interface NSWindow : UIResponder
@property(nonatomic,weak) id delegate;
@property(nonatomic,strong) NSView *contentView;
@property(nonatomic,weak) UIWindow *deUIKitWindow;
@property(nonatomic,copy) NSString *title;
@property(nonatomic) NSUInteger styleMask;
@property(nonatomic) BOOL releasedWhenClosed,acceptsMouseMovedEvents;
@property(nonatomic,getter=isMovable) BOOL movable;
@property(nonatomic) NSInteger level,collectionBehavior;
@property(nonatomic) CGSize minSize,maxSize;
@property(nonatomic) CGRect deFrame;
@property(nonatomic) BOOL deVisible;
@property(nonatomic) CGRect deWindowedFrame;
@property(nonatomic) BOOL deFullScreenTransition;
@property(nonatomic) NSInteger windowNumber;
@property(nonatomic,strong) id<DEColorObject> backgroundColor;
@property(nonatomic,weak) NSView *initialFirstResponder;
@property(nonatomic,weak) NSView *firstResponder;
@property(nonatomic,weak) id deMouseDownTarget;
- (void)update;
@end
static NSHashTable<NSWindow *> *DEGameWindows;
static __weak NSWindow *DEKeyGameWindow,*DEMainGameWindow;
static NSInteger DENextWindowNumber = 1;
#include "HardwareKeyMapping.h"
static void DEPostGameKeyWithModifiers(unsigned short macKey,NSString *characters,NSString *plain,NSUInteger flags,BOOL pressed) {
    NSTimeInterval timestamp=NSProcessInfo.processInfo.systemUptime;
    dispatch_async(dispatch_get_main_queue(),^{
        NSWindow *window=DEKeyGameWindow;
        if(!window || !window.deVisible || !window.deUIKitWindow.isKeyWindow)return;
        id<DEGameMouseEvent> event=[NSClassFromString(@"NSEvent") new];
        event.type=pressed?10:11;event.keyCode=macKey;
        event.characters=characters;event.charactersIgnoringModifiers=plain;
        event.modifierFlags=flags | ((characters.length && [characters characterAtIndex:0]>=0xF700)?(1UL<<23):0);
        event.timestamp=timestamp;event.window=window;
        id app=((id(*)(id,SEL))objc_msgSend)(NSClassFromString(@"NSApplication"),sel_registerName("sharedApplication"));
        ((void(*)(id,SEL,id,BOOL))objc_msgSend)(app,sel_registerName("postEvent:atStart:"),event,NO);
        if(getenv("AGEPAD_KEY_DELIVERY_TRACE"))fprintf(stderr,"DE_HARDWARE_KEY_ENQUEUED mac=%u pressed=%d flags=%lu\n",macKey,pressed,(unsigned long)flags);
    });
}
static void DEPostGameKey(unsigned short macKey, NSString *characters, BOOL pressed) {
    DEPostGameKeyWithModifiers(macKey,characters,characters,0,pressed);
}
static void DEConnectGameKeyboard(void) {
    GCKeyboardInput *keyboard=GCKeyboard.coalescedKeyboard.keyboardInput;
    if(!keyboard)return;
    keyboard.keyChangedHandler=^(GCKeyboardInput *input,GCControllerButtonInput *button,GCKeyCode code,BOOL pressed) {
        NSUInteger flags=0;
        // USB left/right modifier usages; preserve the AppKit modifier bits.
        if([input buttonForKeyCode:225].isPressed || [input buttonForKeyCode:229].isPressed)flags|=1UL<<17;
        if([input buttonForKeyCode:224].isPressed || [input buttonForKeyCode:228].isPressed)flags|=1UL<<18;
        if([input buttonForKeyCode:226].isPressed || [input buttonForKeyCode:230].isPressed)flags|=1UL<<19;
        if([input buttonForKeyCode:227].isPressed || [input buttonForKeyCode:231].isPressed)flags|=1UL<<20;
        unsigned short macKey;NSString *characters,*plain;
        if(!DEMapHardwareKey(code,(flags&(1UL<<17))!=0,&macKey,&plain,&characters))return;
        // Command-V is the only path that may read pasteboard contents.
        if(pressed && (flags&(1UL<<20)) && [plain isEqualToString:@"v"])DEArmUserPaste();
        DEPostGameKeyWithModifiers(macKey,characters,plain,flags,pressed);
    };
    fprintf(stderr,"DE_HARDWARE_KEYBOARD_CONNECTED layout=US letters_digits_punctuation_navigation_function_keys=1\n");
}
static void DEInstallGameKeyboard(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{
        [NSNotificationCenter.defaultCenter addObserverForName:GCKeyboardDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){DEConnectGameKeyboard();}];
        DEConnectGameKeyboard();
    });
}
static void DEPostWindowTransition(NSWindow *window,NSString *name,SEL action) {
    NSNotification *note=[NSNotification notificationWithName:name object:window];
    [NSNotificationCenter.defaultCenter postNotification:note];
    id delegate=window.delegate;
    if(delegate && DEHasMouseHandler(object_getClass(delegate),action))((void(*)(id,SEL,id))objc_msgSend)(delegate,action,note);
    fprintf(stderr,"DE_WINDOW_TRANSITION %s window=%p\n",name.UTF8String,(__bridge void*)window);
}
void DEUpdateVisibleGameWindows(void) {
    for(NSWindow *window in DEGameWindows.allObjects) if(window.deVisible) [window update];
}
@implementation NSView
- (instancetype)init { return [self initWithFrame:CGRectZero]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super init])) {
        _deHost=[[DEGameViewHost alloc] initWithFrame:frame];_deHost.backgroundColor=UIColor.clearColor;_deHost.originalView=self;
        _deSubviews=[NSMutableArray array];
    }return self;
}
- (CGRect)frame { return self.deHost.frame; }
- (void)setFrame:(CGRect)frame { self.deHost.frame=frame;[self.deHost setNeedsLayout];[self.deHost layoutIfNeeded];
    if(getenv("AGEPAD_LAYER_ATTACH_FLUSH")){[CATransaction flush];fprintf(stderr,"DE_LAYER_ATTACH_FLUSH actual transaction submitted\n");} }
- (void)setFrameOrigin:(CGPoint)origin { CGRect f=self.frame;f.origin=origin;self.frame=f; }
- (void)setFrameSize:(CGSize)size { CGRect f=self.frame;f.size=size;self.frame=f; }
- (CGRect)bounds { return self.deHost.bounds; }
- (void)setBounds:(CGRect)bounds { self.deHost.bounds=bounds;[self.deHost setNeedsLayout]; }
- (BOOL)isFlipped { return YES; } // Host view coordinates are UIKit top-left.
- (void)resetCursorRects { } // Base NSView defines no cursor regions.
- (BOOL)isHidden { return self.deHost.hidden; }
- (NSView *)hitTest:(CGPoint)point {
    if (self.deHost.hidden) return nil;
    // AppKit receives superview coordinates; UIKit performs the actual
    // frame/bounds conversion, including any host transform.
    CGPoint local=[self.deHost convertPoint:point fromView:self.deHost.superview];
    if (!CGRectContainsPoint(self.deHost.bounds,local)) return nil;
    for (id child in self.deSubviews.reverseObjectEnumerator) {
        if (![child isKindOfClass:NSView.class]) DEUnsupported("hit test for non-AppKit child");
        NSView *hit=[(NSView *)child hitTest:local];
        if (hit) return hit;
    }
    fprintf(stderr,"DE_VIEW_HIT view=%s x=%g y=%g\n",object_getClassName(self),local.x,local.y);
    return self;
}
- (void)setHidden:(BOOL)hidden { self.deHost.hidden=hidden; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)setNextResponder:(UIResponder *)responder { self.deNextResponder=responder; }
- (UIResponder *)nextResponder { return self.deNextResponder ?: self.superview ?: self.window; }
- (void)keyDown:(id)event {
    id next=self.nextResponder;
    if(next)((void(*)(id,SEL,id))objc_msgSend)(next,sel_registerName("keyDown:"),event);
}
- (void)keyUp:(id)event {
    id next=self.nextResponder;
    if(next)((void(*)(id,SEL,id))objc_msgSend)(next,sel_registerName("keyUp:"),event);
}
- (void)interpretKeyEvents:(NSArray<id<DEGameMouseEvent>> *)events {
    for(id<DEGameMouseEvent> event in events) {
        if(event.type!=10)DEUnsupported("text interpretation requires key down");
        const char *command=event.keyCode==51?"deleteBackward:":event.keyCode==36?"insertNewline:":event.keyCode==48?"insertTab:":event.keyCode==123?"moveLeft:":event.keyCode==124?"moveRight:":event.keyCode==125?"moveDown:":event.keyCode==126?"moveUp:":NULL;
        if(command){((void(*)(id,SEL,SEL))objc_msgSend)(self,sel_registerName("doCommandBySelector:"),sel_registerName(command));continue;}
        if(event.modifierFlags & (1UL<<23))continue;
        if(event.keyCode!=53) {
            NSString *text=event.characters;
            if(!text.length || [text rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)
                DEUnsupported("text interpretation requires printable characters or Escape");
            // AppKit returns unbound printable input to the original responder.
            // This is text interpretation, not a synthetic game command.
            SEL modern=sel_registerName("insertText:replacementRange:");
            if(DEHasMouseHandler(object_getClass(self),modern))
                ((void(*)(id,SEL,id,NSRange))objc_msgSend)(self,modern,text,NSMakeRange(NSNotFound,0));
            else
                ((void(*)(id,SEL,id))objc_msgSend)(self,sel_registerName("insertText:"),text);
            fprintf(stderr,"DE_TEXT_INPUT_INSERT length=%lu\n",(unsigned long)text.length);
            continue;
        }
        // Verified against macOS StandardKeyBinding.dict. The original view's
        // command handler decides whether it implements this editing action.
        ((void(*)(id,SEL,SEL))objc_msgSend)(self,sel_registerName("doCommandBySelector:"),sel_registerName("cancelOperation:"));
    }
}
- (BOOL)respondsToSelector:(SEL)selector {
    // The original game's text-input responder probes editing commands before
    // dispatch. Answer those probes without triggering NSView's fail-closed
    // dynamic resolver for a command the view does not implement.
    for(NSString *name in @[@"cancelOperation:",@"deleteBackward:",@"insertNewline:",@"insertTab:",
                            @"moveLeft:",@"moveRight:",@"moveDown:",@"moveUp:"]) {
        if(selector==NSSelectorFromString(name))return DEHasMouseHandler(object_getClass(self),selector);
    }
    return [super respondsToSelector:selector];
}
- (BOOL)becomeFirstResponder { return [self.deHost becomeFirstResponder]; }
- (void)setAutoresizingMask:(NSUInteger)mask {
    // AppKit's six spring/strut bits correspond to UIView's positions, but
    // vertical top/bottom margins swap under UIKit's flipped coordinates.
    NSUInteger translated=(mask&7)|((mask&8)<<2)|(mask&16)|((mask&32)>>2);
    self.deHost.autoresizingMask=(UIViewAutoresizing)translated;
}
- (void)addTrackingArea:(id<DETrackingConfig>)area {
    if (!NSThread.isMainThread) DEUnsupported("game tracking attachment requires main thread");
    fprintf(stderr,"DE_GAME_TRACKING_REQUEST options=%lu\n",(unsigned long)[area options]);
    if ([area options]!=129) DEUnsupported("game tracking supports entered/exited active-always only");
    if (!self.deTracking) {
        self.deTracking=[DEGameTrackingController new];self.deTracking.host=self.deHost;
        self.deTracking.records=[NSMutableArray array];
        UIHoverGestureRecognizer *hover=[[UIHoverGestureRecognizer alloc] initWithTarget:self.deTracking action:@selector(hover:)];
        hover.cancelsTouchesInView=NO;[self.deHost addGestureRecognizer:hover];
    }
    for (DEWebTrackingRecord *record in self.deTracking.records) if (record.area==area) return;
    DEWebTrackingRecord *record=[DEWebTrackingRecord new];record.area=area;
    [self.deTracking.records addObject:record];
    fprintf(stderr,"DE_GAME_TRACKING_ATTACHED options=129 UIKit hover observer\n");
}
- (void)removeTrackingArea:(id)area {
    for (DEWebTrackingRecord *record in self.deTracking.records.copy)
        if (record.area==area) [self.deTracking.records removeObjectIdenticalTo:record];
}
- (NSArray *)trackingAreas {
    NSMutableArray *areas=[NSMutableArray array];
    for (DEWebTrackingRecord *record in self.deTracking.records) [areas addObject:record.area];
    return areas.copy;
}
- (NSArray *)subviews { return self.deSubviews.copy; }
- (void)setSubviews:(NSArray *)views {
    NSArray *incoming=views.copy ?: @[];
    __attribute__((objc_precise_lifetime)) NSMutableArray<UIView *> *hosts=[NSMutableArray array];
    for (id view in incoming) {
        UIView *host=DEHostView(view);
        if (view==self || [hosts containsObject:host]) DEUnsupported("duplicate or self subview");
        [hosts addObject:host];
    }
    for (id old in self.deSubviews.copy) {
        if ([old isKindOfClass:NSView.class]) [old removeFromSuperview];
        else [DEHostView(old) removeFromSuperview];
    }
    [self.deSubviews removeAllObjects];
    for (id view in incoming) [self addSubview:view];
}
- (void)addSubview:(NSView *)view {
    if ([view isKindOfClass:NSView.class]) {
        if (view.superview) [view removeFromSuperview];view.superview=self;
    }
    [self.deSubviews addObject:view];[self.deHost addSubview:DEHostView(view)];
    [self.deHost bringSubviewToFront:self.deHost.touchOrderButton];
}
- (void)removeFromSuperview { [self.superview.deSubviews removeObjectIdenticalTo:self];self.superview=nil;[self.deHost removeFromSuperview]; }
- (NSWindow *)window { return self.deWindow ?: self.superview.window; }
- (CALayer *)layer { return self.deHost.gameLayer ?: self.deHost.layer; }
- (void)setLayer:(CALayer *)layer {
    if ([layer isKindOfClass:CAMetalLayer.class]) DEInstallDrawablePresentationCompatibility();
    [self.deHost.gameLayer removeFromSuperlayer];self.deHost.gameLayer=layer;
    if (layer) [self.deHost.layer addSublayer:layer];
    [self.deHost setNeedsLayout];[self.deHost layoutIfNeeded];
    if(getenv("AGEPAD_LAYER_ATTACH_FLUSH")){[CATransaction flush];fprintf(stderr,"DE_LAYER_ATTACH_FLUSH actual transaction submitted\n");}
    fprintf(stderr,"DE_GAME_LAYER_ATTACHED class=%s metal=%d\n",class_getName(layer.class),[layer isKindOfClass:CAMetalLayer.class]);
    DELogHostGeometry(@"layer_attach",self.deHost);
}
- (void)setNeedsDisplay:(BOOL)needs { if (needs) [self.deHost setNeedsDisplay]; }
- (void)displayIfNeeded { [self.deHost.layer displayIfNeeded]; }
- (CGPoint)convertPoint:(CGPoint)point fromView:(NSView *)view {
    if(view)return [self.deHost convertPoint:point fromView:DEHostView(view)];
    UIView *root=self.window.contentView.deHost;
    CGPoint local=CGPointMake(point.x+root.bounds.origin.x,CGRectGetMaxY(root.bounds)-point.y);
    return [self.deHost convertPoint:local fromView:root];
}
- (CGPoint)convertPoint:(CGPoint)point toView:(NSView *)view {
    if(view)return [self.deHost convertPoint:point toView:DEHostView(view)];
    UIView *root=self.window.contentView.deHost;
    CGPoint local=[self.deHost convertPoint:point toView:root];
    return CGPointMake(local.x-root.bounds.origin.x,CGRectGetMaxY(root.bounds)-local.y);
}
- (CGRect)convertRectToBacking:(CGRect)r { CGFloat s=DERenderScale(self.deHost.window.screen);return CGRectMake(r.origin.x*s,r.origin.y*s,r.size.width*s,r.size.height*s); }
- (CGRect)convertRectFromBacking:(CGRect)r { CGFloat s=DERenderScale(self.deHost.window.screen);return CGRectMake(r.origin.x/s,r.origin.y/s,r.size.width/s,r.size.height/s); }
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSView %s]\n",sel_getName(sel));DEUnsupported("NSView");}
@end
@implementation NSWindow
- (void)mouseMoved:(id)event {
    // NSResponder's default forwards to the next responder. The original
    // CFeralNSWindow calls super for moves it does not consume.
    id next=self.nextResponder;
    NSMutableArray *visited=[NSMutableArray arrayWithObject:self];
    SEL action=sel_registerName("mouseMoved:");
    while(next && !DEHasMouseHandler(object_getClass(next),action)) {
        if([visited containsObject:next])DEUnsupported("cycle in move responder chain");
        [visited addObject:next];next=((id(*)(id,SEL))objc_msgSend)(next,sel_registerName("nextResponder"));
    }
    if(next==self)DEUnsupported("cycle in move responder chain");
    if(next)((void(*)(id,SEL,id))objc_msgSend)(next,action,event);
}
- (void)update {
    [self.contentView.deHost layoutIfNeeded];
    [NSNotificationCenter.defaultCenter postNotificationName:@"NSWindowDidUpdateNotification" object:self];
}
- (CGPoint)convertPointFromScreen:(CGPoint)point {
    UIView *root=self.contentView.deHost;UIScreen *screen=self.deUIKitWindow.screen;
    CGPoint ui=CGPointMake(point.x,CGRectGetMaxY(screen.bounds)-point.y);
    CGPoint local=[root convertPoint:ui fromCoordinateSpace:screen.coordinateSpace];
    CGPoint result=CGPointMake(local.x-root.bounds.origin.x,CGRectGetMaxY(root.bounds)-local.y);
    fprintf(stderr,"DE_INPUT_FROM_SCREEN in=%g,%g out=%g,%g root=%s\n",point.x,point.y,result.x,result.y,NSStringFromCGRect(root.frame).UTF8String);
    return result;
}
- (CGPoint)convertPointToScreen:(CGPoint)point {
    UIView *root=self.contentView.deHost;UIScreen *screen=self.deUIKitWindow.screen;
    CGPoint local=CGPointMake(point.x+root.bounds.origin.x,CGRectGetMaxY(root.bounds)-point.y);
    CGPoint ui=[root convertPoint:local toCoordinateSpace:screen.coordinateSpace];
    CGPoint result=CGPointMake(ui.x,CGRectGetMaxY(screen.bounds)-ui.y);
    fprintf(stderr,"DE_INPUT_TO_SCREEN in=%g,%g out=%g,%g\n",point.x,point.y,result.x,result.y);
    return result;
}
- (CGRect)convertRectToScreen:(CGRect)rect {
    CGPoint a=[self convertPointToScreen:rect.origin],b=[self convertPointToScreen:CGPointMake(CGRectGetMaxX(rect),CGRectGetMaxY(rect))];
    return CGRectMake(MIN(a.x,b.x),MIN(a.y,b.y),fabs(b.x-a.x),fabs(b.y-a.y));
}
- (CGRect)convertRectFromScreen:(CGRect)rect {
    CGPoint a=[self convertPointFromScreen:rect.origin],b=[self convertPointFromScreen:CGPointMake(CGRectGetMaxX(rect),CGRectGetMaxY(rect))];
    return CGRectMake(MIN(a.x,b.x),MIN(a.y,b.y),fabs(b.x-a.x),fabs(b.y-a.y));
}
- (void)sendEvent:(id<DEGameMouseEvent>)event {
    if (!NSThread.isMainThread || event.window!=self) DEUnsupported("window event requires owned main-thread event");
    NSUInteger type=event.type;
    // Touch recognition can deliver a coalesced begin/end after the pointer
    // observer already saw the endpoint. Match polled pointer state to the event
    // being consumed, not to whichever UIKit sample arrived most recently.
    if((type>=1 && type<=7) || type==22) {
        UIView *host=self.contentView.deHost;
        CGPoint local=CGPointMake(event.locationInWindow.x+host.bounds.origin.x,
                                  CGRectGetMaxY(host.bounds)-event.locationInWindow.y);
        if(CGRectContainsPoint(host.bounds,local) && host.window) {
            CGPoint inWindow=[host convertPoint:local toView:host.window];
            CGPoint global=[host.window convertPoint:inWindow toCoordinateSpace:host.window.screen.coordinateSpace];
            DEUIKitSetPointerPosition(global);
        }
    }
    for(NSString *name in @[@"cachedIsActive",@"cachedIsMain",@"cachedIsVisible"]) {
        SEL getter=NSSelectorFromString(name);
        if(DEHasMouseHandler(object_getClass(self),getter))fprintf(stderr,"DE_INPUT_WINDOW_STATE %s=%d\n",name.UTF8String,((BOOL(*)(id,SEL))objc_msgSend)(self,getter));
    }
    if(type==10 || type==11) {
        SEL action=sel_registerName(type==10?"keyDown:":"keyUp:");
        id target=self.firstResponder ?: self;
        NSMutableArray *visited=[NSMutableArray array];
        while(target && !DEHasMouseHandler(object_getClass(target),action)) {
            if([visited containsObject:target])DEUnsupported("cycle in key responder chain");
            [visited addObject:target];target=((id(*)(id,SEL))objc_msgSend)(target,sel_registerName("nextResponder"));
        }
        if(target)((void(*)(id,SEL,id))objc_msgSend)(target,action,event);
        return;
    }
    BOOL down=type==1 || type==3, up=type==2 || type==4, dragged=type==6 || type==7;
    BOOL moved=type==5, scroll=type==22;
    if (!down && !up && !dragged && !moved && !scroll) DEUnsupported("window dispatch currently supports mouse and key events");
    // AppKit chooses a distinct responder method for secondary-button events.
    // Original games may encode the button in that method, independently of
    // NSEvent.buttonNumber. Sending a right event to mouseDown: loses that contract.
    BOOL secondary=type==3 || type==4 || type==7;
    SEL action=sel_registerName(scroll?"scrollWheel:":secondary ?
        (down?"rightMouseDown:":up?"rightMouseUp:":"rightMouseDragged:") :
        (down?"mouseDown:":up?"mouseUp:":moved?"mouseMoved:":"mouseDragged:"));
    id target=self.deMouseDownTarget;
    if(down || moved || scroll) {
        UIView *parent=self.contentView.deHost.superview;
        UIView *root=self.contentView.deHost;
        CGPoint local=CGPointMake(event.locationInWindow.x,event.locationInWindow.y);
        local.y=CGRectGetMaxY(root.bounds)-local.y;
        local.x+=root.bounds.origin.x;local.y+=root.bounds.origin.y;
        CGPoint point=[parent convertPoint:local fromView:root];
        target=[self.contentView hitTest:point];
        if(down)self.deMouseDownTarget=target;
    }
    // AppKit's default view mouse handlers forward along the responder chain.
    // Look up existing handlers without triggering unsupported-method resolution.
    NSMutableArray *visited=[NSMutableArray array];
    while(target && !DEHasMouseHandler(object_getClass(target),action)) {
        if([visited containsObject:target]) DEUnsupported("cycle in mouse responder chain");
        [visited addObject:target];
        target=((id(*)(id,SEL))objc_msgSend)(target,sel_registerName("nextResponder"));
    }
    fprintf(stderr,"DE_WINDOW_MOUSE_DISPATCH type=%lu action=%s target=%s\n",(unsigned long)type,sel_getName(action),target?object_getClassName(target):"none");
    if(target)((void(*)(id,SEL,id))objc_msgSend)(target,action,event);
    if(up)self.deMouseDownTarget=nil;
}
- (instancetype)initWithContentRect:(CGRect)rect styleMask:(NSUInteger)style backing:(NSUInteger)backing defer:(BOOL)defer {
    if (!NSThread.isMainThread || backing!=2) DEUnsupported("window requires main thread and buffered backing");
    if ((self=[super init])) {
        _deFrame=rect;_styleMask=style;_title=@"";_windowNumber=DENextWindowNumber++;
        if(!DEGameWindows)DEGameWindows=[NSHashTable weakObjectsHashTable];
        [DEGameWindows addObject:self];
        for (UIWindow *window in UIApplication.sharedApplication.windows) if (window.isKeyWindow) {_deUIKitWindow=window;break;}
        if (!_deUIKitWindow) DEUnsupported("game window requires existing UIKit window");
        self.contentView=[[NSView alloc] initWithFrame:CGRectMake(0,0,rect.size.width,rect.size.height)];
        fprintf(stderr,"DE_GAME_WINDOW_CREATED size=%gx%g style=%lu\n",rect.size.width,rect.size.height,(unsigned long)style);
    }return self;
}
- (void)setContentView:(NSView *)view {
    [_contentView.deHost removeFromSuperview];_contentView.deWindow=nil;_contentView=view;view.deWindow=self;
    if (self.deVisible) [self makeKeyAndOrderFront:nil];
}
- (void)setBackgroundColor:(id<DEColorObject>)color { _backgroundColor=color;self.contentView.deHost.backgroundColor=color?[UIColor colorWithCGColor:color.CGColor]:nil; }
- (BOOL)makeFirstResponder:(NSView *)view {
    if (!view) { BOOL result=[DEHostView(self.firstResponder) resignFirstResponder];self.firstResponder=nil;return result; }
    BOOL result=[view becomeFirstResponder];if (result) self.firstResponder=view;return result;
}
- (void)setTouchBar:(id)bar { if (bar) DEUnsupported("non-nil Touch Bar on UIKit window");fprintf(stderr,"DE_WINDOW_TOUCHBAR_CLEAR no Touch Bar attached\n"); }
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)invalidateCursorRectsForView:(NSView *)view {
    if (!NSThread.isMainThread || view.window!=self) DEUnsupported("cursor invalidation requires owned main-thread view");
    // No regions have been registered yet in this adapter. Ask the original
    // view to rebuild them; any unsupported registration still fails explicitly.
    [view resetCursorRects];
    fprintf(stderr,"DE_WINDOW_CURSOR_RECTS_RESET original_view=%s\n",class_getName(object_getClass(view)));
}
- (id)standardWindowButton:(NSUInteger)button {
    // UIKit owns scene chrome; this content host has no AppKit title-bar
    // close/minimize/zoom/full-screen buttons. AppKit permits absent buttons.
    fprintf(stderr,"DE_WINDOW_STANDARD_BUTTON absent desktop chrome type=%lu\n",(unsigned long)button);
    return nil;
}
- (BOOL)canBecomeMainWindow { return YES; }
- (CGRect)frame { return self.deFrame; }
- (id)screen { return DEUIKitScreenObject(self.deUIKitWindow.screen); }
- (CGFloat)backingScaleFactor { return DERenderScale(self.deUIKitWindow.screen); }
- (CGRect)frameRectForContentRect:(CGRect)rect { return rect; } // UIKit host has no desktop decorations.
- (CGRect)contentRectForFrameRect:(CGRect)rect { return rect; } // No desktop decorations.
+ (CGRect)contentRectForFrameRect:(CGRect)rect styleMask:(NSUInteger)style { return rect; }
+ (CGRect)frameRectForContentRect:(CGRect)rect styleMask:(NSUInteger)style { return rect; }
- (BOOL)isVisible { return self.deVisible && !self.deUIKitWindow.hidden; }
- (NSInteger)windowNumber { return _windowNumber; }
- (BOOL)isKeyWindow { return DEKeyGameWindow==self && self.deVisible && self.deUIKitWindow.isKeyWindow; }
- (BOOL)isMainWindow { return DEMainGameWindow==self && self.deVisible; }
- (void)resignKeyWindow {
    if(DEKeyGameWindow!=self)return;DEKeyGameWindow=nil;
    DEPostWindowTransition(self,@"NSWindowDidResignKeyNotification",sel_registerName("windowDidResignKey:"));
}
- (void)resignMainWindow {
    if(DEMainGameWindow!=self)return;DEMainGameWindow=nil;
    DEPostWindowTransition(self,@"NSWindowDidResignMainNotification",sel_registerName("windowDidResignMain:"));
}
- (void)makeKeyWindow {
    DEInstallGameKeyboard();
    if(!self.deVisible || !self.deUIKitWindow.isKeyWindow || ![self canBecomeKeyWindow])return;
    if(DEKeyGameWindow==self)return;
    [DEKeyGameWindow resignKeyWindow];DEKeyGameWindow=self;
    DEPostWindowTransition(self,@"NSWindowDidBecomeKeyNotification",sel_registerName("windowDidBecomeKey:"));
}
- (void)makeMainWindow {
    if(!self.deVisible || ![self canBecomeMainWindow])return;
    if(DEMainGameWindow==self)return;
    [DEMainGameWindow resignMainWindow];DEMainGameWindow=self;
    DEPostWindowTransition(self,@"NSWindowDidBecomeMainNotification",sel_registerName("windowDidBecomeMain:"));
}
- (BOOL)isMiniaturized { return NO; }
- (BOOL)inLiveResize { return NO; } // This host exposes no interactive window-border resizing.
- (BOOL)isOnActiveSpace { return UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground; }
- (void)center {
    CGRect bounds=self.deUIKitWindow.rootViewController.view.bounds;
    CGRect frame=self.deFrame;frame.origin=CGPointMake(CGRectGetMidX(bounds)-frame.size.width/2,CGRectGetMidY(bounds)-frame.size.height/2);self.deFrame=frame;
    if (self.deVisible) self.contentView.deHost.frame=frame;
}
- (void)makeKeyAndOrderFront:(id)sender {
    [self orderFront:sender];
    [self makeKeyWindow];[self makeMainWindow];
}
- (void)orderFront:(id)sender {
    UIView *root=self.deUIKitWindow.rootViewController.view;
    // Ordering another window front must not close/detach existing windows.
    // The original renderer may still submit to them until orderOut:/close.
    fprintf(stderr,"DE_WINDOW_ORDER_FRONT existing_hosts=%lu newhost=%p\n",(unsigned long)root.subviews.count,(__bridge void *)self.contentView.deHost);
    self.contentView.deHost.frame=self.deFrame;
    [root addSubview:self.contentView.deHost];[self.deUIKitWindow makeKeyAndVisible];self.deVisible=YES;
    if(getenv("AGEPAD_LAYER_ATTACH_FLUSH")){[root layoutIfNeeded];[CATransaction flush];fprintf(stderr,"DE_WINDOW_SHOW_FLUSH actual transaction submitted\n");}
    if (self.initialFirstResponder) [self makeFirstResponder:self.initialFirstResponder];
    fprintf(stderr,"DE_GAME_WINDOW_VISIBLE size=%gx%g\n",self.deFrame.size.width,self.deFrame.size.height);
    DELogHostGeometry(@"order_front",self.contentView.deHost);
}
- (void)toggleFullScreen:(id)sender {
    if (!NSThread.isMainThread || !self.deVisible || self.deFullScreenTransition)
        DEUnsupported("full-screen transition requires visible idle main-thread window");
    BOOL entering=(self.styleMask & (1UL<<14))==0;
    self.deFullScreenTransition=YES;
    NSString *will=entering?@"NSWindowWillEnterFullScreenNotification":@"NSWindowWillExitFullScreenNotification";
    SEL willSelector=NSSelectorFromString(entering?@"windowWillEnterFullScreen:":@"windowWillExitFullScreen:");
    NSNotification *note=[NSNotification notificationWithName:will object:self];
    [NSNotificationCenter.defaultCenter postNotification:note];
    if ([self.delegate respondsToSelector:willSelector]) ((void(*)(id,SEL,id))objc_msgSend)(self.delegate,willSelector,note);
    UIView *root=self.deUIKitWindow.rootViewController.view;
    if (entering) { self.deWindowedFrame=self.deFrame;self.deFrame=root.bounds;self.styleMask|=(1UL<<14); }
    else { self.deFrame=self.deWindowedFrame;self.styleMask&=~(1UL<<14); }
    self.contentView.frame=self.deFrame;
    self.contentView.deHost.autoresizingMask=entering?(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight):UIViewAutoresizingNone;
    [root layoutIfNeeded];[self.contentView.deHost layoutIfNeeded];
    // UIKit owns the scene; full screen means filling its actual content area.
    // Complete after layout on the next main-queue turn, with the real layer.
    dispatch_async(dispatch_get_main_queue(),^{
        self.deFullScreenTransition=NO;
        NSString *did=entering?@"NSWindowDidEnterFullScreenNotification":@"NSWindowDidExitFullScreenNotification";
        SEL didSelector=NSSelectorFromString(entering?@"windowDidEnterFullScreen:":@"windowDidExitFullScreen:");
        NSNotification *completion=[NSNotification notificationWithName:did object:self];
        [NSNotificationCenter.defaultCenter postNotification:completion];
        if ([self.delegate respondsToSelector:didSelector]) ((void(*)(id,SEL,id))objc_msgSend)(self.delegate,didSelector,completion);
        fprintf(stderr,"DE_WINDOW_FULLSCREEN actual_scene_fill=%d size=%gx%g\n",entering,self.contentView.bounds.size.width,self.contentView.bounds.size.height);
        DELogHostGeometry(entering?@"fullscreen_enter":@"fullscreen_exit",self.contentView.deHost);
    });
}
- (void)setFrame:(CGRect)frame display:(BOOL)display { self.deFrame=frame;self.contentView.frame=CGRectMake(0,0,frame.size.width,frame.size.height); }
- (void)setContentSize:(CGSize)size { CGRect frame=self.deFrame;frame.size=size;[self setFrame:frame display:YES]; }
- (void)orderOut:(id)sender { fprintf(stderr,"DE_WINDOW_DETACH window=%p host=%p layer=%p\n",(__bridge void *)self,(__bridge void *)self.contentView.deHost,(__bridge void *)self.contentView.layer); [self.contentView.deHost removeFromSuperview];self.deVisible=NO;[self resignKeyWindow];[self resignMainWindow]; }
- (void)close { [self orderOut:nil]; }
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSWindow %s]\n",sel_getName(sel));DEUnsupported("NSWindow");}
@end

#include "NativeTouchGestures.m"
