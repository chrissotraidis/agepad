// Host the original WebKitLegacy WAKView; no replacement HTML or JS bridge.
// Signatures checked against the running Simulator and WebKit WAKWindow.h.
#include <dlfcn.h>
#import <objc/message.h>
@protocol DETrackingConfig
- (NSUInteger)options;
- (CGRect)rect;
- (id)owner;
@end
@protocol DEHoverEvent
- (void)setType:(NSUInteger)value;
- (void)setLocationInWindow:(CGPoint)value;
- (void)setTimestamp:(NSTimeInterval)value;
- (void)setTrackingArea:(id)value;
@end
@interface DEWebTrackingRecord : NSObject
@property(nonatomic,strong) id<DETrackingConfig> area;
@property(nonatomic) BOOL inside;
@end
@implementation DEWebTrackingRecord @end
@protocol DEWebMouseEventAPI
- (id)initWithMouseEventType:(int)type timeStamp:(CFTimeInterval)timeStamp location:(CGPoint)point modifiers:(unsigned)modifiers;
@end
@protocol DEWAKWindowAPI
- (id)initWithLayer:(CALayer *)layer;
- (void)setContentView:(id)view;
- (id)contentView;
- (void)close;
- (void)sendEventSynchronously:(id)event;
- (void)setVisible:(BOOL)visible;
- (void)setFrame:(CGRect)frame display:(BOOL)display;
- (void)setContentRect:(CGRect)rect;
- (void)setScreenSize:(CGSize)size;
- (void)setAvailableScreenSize:(CGSize)size;
- (void)setScreenScale:(CGFloat)scale;
- (void)setExposedScrollViewRect:(CGRect)rect;
- (void)layoutTiles;
- (void)layoutTilesNow;
- (void)setTilingMode:(NSInteger)mode;
- (void)removeAllTiles;
- (void)setNeedsDisplay;
- (CGRect)visibleRect;
@end
@protocol DEWebPreferencesAPI
- (void)setAcceleratedCompositingEnabled:(BOOL)enabled;
- (BOOL)acceleratedCompositingEnabled;
@end
@protocol DEWAKViewAPI
- (id<DEWebPreferencesAPI>)preferences;
- (CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (NSArray *)subviews;
- (CGRect)bounds;
- (BOOL)isHidden;
- (void)displayRectIgnoringOpacity:(CGRect)rect inContext:(CGContextRef)context;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
@end
static void DEWebLock(void) {
    if (!NSThread.isMainThread) DEUnsupported("legacy web host requires main thread");
    static void (*lock)(void);static dispatch_once_t once;
    dispatch_once(&once,^{void *handle=dlopen("/System/Library/PrivateFrameworks/WebCore.framework/WebCore",RTLD_NOW);lock=handle?dlsym(handle,"WebThreadLock"):NULL;});
    if (!lock) DEUnsupported("WebThreadLock unavailable");
    lock(); // WebKit releases this main-thread lock at the runloop boundary.
}
static void DELogWAKViews(id<DEWAKViewAPI> view,int depth) {
 if(depth>6)return;
 fprintf(stderr,"DE_WAK_VIEW depth=%d class=%s frame=%s bounds=%s hidden=%d\n",depth,class_getName([(id)view class]),NSStringFromCGRect([view frame]).UTF8String,NSStringFromCGRect([view bounds]).UTF8String,[(id)view respondsToSelector:@selector(isHidden)]?[view isHidden]:-1);
 for(id child in [view subviews])DELogWAKViews(child,depth+1);
}
static void DELogWebLayers(CALayer *layer,int depth) {
 if (depth>4)return;
 fprintf(stderr,"DE_WEB_LAYER depth=%d class=%s frame=%s bounds=%s hidden=%d opacity=%g contents=%d sublayers=%lu\n",depth,class_getName(layer.class),NSStringFromCGRect(layer.frame).UTF8String,NSStringFromCGRect(layer.bounds).UTF8String,layer.hidden,layer.opacity,layer.contents!=nil,(unsigned long)layer.sublayers.count);
 for(CALayer *child in layer.sublayers)DELogWebLayers(child,depth+1);
}
@interface DELegacyWebHost : UIView
@property(nonatomic,strong) id<DEWAKWindowAPI> wakWindow;
@property(nonatomic,strong) NSMutableArray<DEWebTrackingRecord *> *trackingRecords;
- (void)hover:(UIHoverGestureRecognizer *)gesture;
- (void)diagnose;
@property(nonatomic) BOOL diagnosticsScheduled;
@property(nonatomic,strong) NSTimer *paintTimer;
@property(nonatomic,weak) UITouch *activeTouch;
@end
@implementation DELegacyWebHost
- (void)sendMouseType:(int)type touch:(UITouch *)touch cancelled:(BOOL)cancelled {
 DEWebLock();CGPoint point=cancelled?CGPointMake(-100,-100):[touch locationInView:self];
 Class cls=NSClassFromString(@"WebEvent");
 id event=[(id<DEWebMouseEventAPI>)[cls alloc] initWithMouseEventType:type timeStamp:touch.timestamp location:point modifiers:0];
 if(!event)DEUnsupported("actual WebEvent allocation failed");
 [self.wakWindow sendEventSynchronously:event];[self setNeedsDisplay];
 fprintf(stderr,"DE_WEB_TOUCH_MOUSE type=%d x=%g y=%g\n",type,point.x,point.y);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.activeTouch)return;self.activeTouch=touches.anyObject;
 [self sendMouseType:0 touch:self.activeTouch cancelled:NO];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.activeTouch && [touches containsObject:self.activeTouch]) [self sendMouseType:2 touch:self.activeTouch cancelled:NO];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.activeTouch && [touches containsObject:self.activeTouch]) {[self sendMouseType:1 touch:self.activeTouch cancelled:NO];self.activeTouch=nil;}
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
 if(self.activeTouch && [touches containsObject:self.activeTouch]) {
  [self sendMouseType:2 touch:self.activeTouch cancelled:YES];[self sendMouseType:1 touch:self.activeTouch cancelled:YES];self.activeTouch=nil;
 }
}
- (void)drawRect:(CGRect)rect {
 if (!getenv("AGEPAD_WEB_DIRECT_PAINT")) return;
 DEWebLock();id<DEWAKViewAPI> web=[self.wakWindow contentView];
 CGContextRef context=UIGraphicsGetCurrentContext();
 if(context) [web displayRectIgnoringOpacity:rect inContext:context];
}
- (void)hover:(UIHoverGestureRecognizer *)gesture {
 CGPoint point=[gesture locationInView:self];
 BOOL ended=gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled;
 for (DEWebTrackingRecord *record in self.trackingRecords.copy) {
  BOOL inside=!ended && CGRectContainsPoint([record.area rect],point);
  if (inside==record.inside) continue;
  record.inside=inside;
  SEL action=inside?@selector(mouseEntered:):@selector(mouseExited:);
  id owner=[record.area owner];
  if (![owner respondsToSelector:action]) continue;
  id<DEHoverEvent> event=[NSClassFromString(@"NSEvent") new];
  if (!event) DEUnsupported("hover event class unavailable");
  [event setType:inside?8:9];[event setLocationInWindow:[gesture locationInView:self.window]];
  [event setTimestamp:NSProcessInfo.processInfo.systemUptime];[event setTrackingArea:record.area];
  ((void(*)(id,SEL,id))objc_msgSend)(owner,action,event);
 }
}
- (void)didMoveToWindow {
 [super didMoveToWindow];DEWebLock();[self.wakWindow setVisible:self.window!=nil];[self setNeedsLayout];
 if (getenv("AGEPAD_WEB_DIRECT_PAINT")) {
  [self.paintTimer invalidate];self.paintTimer=nil;
  if (self.window) {
   __weak DELegacyWebHost *weakSelf=self;
   self.paintTimer=[NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer){[weakSelf setNeedsDisplay];}];
   [self setNeedsDisplay];
  }
 }
 if (self.window && getenv("AGEPAD_WEB_DIAGNOSTICS") && !self.diagnosticsScheduled) {
  self.diagnosticsScheduled=YES;
  for (NSNumber *delay in @[@1,@5,@12]) [self performSelector:@selector(diagnose) withObject:nil afterDelay:delay.doubleValue];
 }
}
- (void)diagnose {
 DEWebLock();id<DEWAKViewAPI> web=[self.wakWindow contentView];
 fprintf(stderr,"DE_WEB_VISIBLE_RECT %s\n",NSStringFromCGRect([self.wakWindow visibleRect]).UTF8String);
 DELogWebLayers(self.layer,0);DELogWAKViews(web,0);
 if (getenv("AGEPAD_WEB_FORCE_TILES") && !getenv("AGEPAD_WEB_DIRECT_PAINT")) {
  [self.wakWindow setNeedsDisplay];[self.wakWindow layoutTilesNow];[self.layer displayIfNeeded];
  [CATransaction flush];
  fprintf(stderr,"DE_WEB_FORCE_TILES requested actual WAK paint/layout and CA flush\n");
 }

 NSString *script=@"JSON.stringify({ready:document.readyState,viewport:[innerWidth,innerHeight],body:document.body?{children:document.body.children.length,width:document.body.offsetWidth,height:document.body.offsetHeight,display:getComputedStyle(document.body).display}:null,images:Array.from(document.images).slice(0,20).map(i=>({src:i.src.split('?')[0],complete:i.complete,width:i.naturalWidth,height:i.naturalHeight})),styles:Array.from(document.styleSheets).map(s=>s.href),nodes:document.body?Array.from(document.body.children).slice(0,12).map(n=>({tag:n.tagName,id:n.id,cls:n.className,rect:[n.offsetLeft,n.offsetTop,n.offsetWidth,n.offsetHeight],display:getComputedStyle(n).display})):[]})";
 const char *output=getenv("AGEPAD_WEB_SNAPSHOT_DIR");
 if (output) {
  UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:self.bounds.size];
  UIImage *snapshot=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[self.layer renderInContext:context.CGContext];}];
  NSString *path=[@(output) stringByAppendingPathComponent:@"web-layer-snapshot.png"];
  BOOL wrote=[UIImagePNGRepresentation(snapshot) writeToFile:path atomically:YES];
  fprintf(stderr,"DE_WEB_LAYER_SNAPSHOT written=%d\n",wrote);
  UIImage *direct=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[web displayRectIgnoringOpacity:self.bounds inContext:context.CGContext];}];
  [UIImagePNGRepresentation(direct) writeToFile:[@(output) stringByAppendingPathComponent:@"web-direct-snapshot.png"] atomically:YES];
 }
 NSString *json=[web stringByEvaluatingJavaScriptFromString:script];
 fprintf(stderr,"DE_WEB_DIAGNOSTIC host=%s web=%s layers=%lu dom=%s\n",NSStringFromCGRect(self.frame).UTF8String,NSStringFromCGRect([web frame]).UTF8String,(unsigned long)self.layer.sublayers.count,json.UTF8String ?: "nil");
}

- (void)layoutSubviews {
    [super layoutSubviews];DEWebLock();
    [self.wakWindow setContentRect:self.bounds];
    UIScreen *screen=self.window.screen ?: UIScreen.mainScreen;
    [self.wakWindow setScreenSize:screen.bounds.size];
    [self.wakWindow setAvailableScreenSize:screen.bounds.size];
    [self.wakWindow setScreenScale:screen.scale];
    [self.wakWindow setExposedScrollViewRect:self.bounds];
    [self.wakWindow layoutTiles];
}
- (void)dealloc { [_paintTimer invalidate];DEWebLock();[_wakWindow close]; }
@end
@interface DEWeakWebHost : NSObject
@property(nonatomic,weak) DELegacyWebHost *host;
@end
@implementation DEWeakWebHost @end
static char DEWebHostKey;
static UIView *DELegacyHost(id<DEWAKViewAPI> view) {
    DEWeakWebHost *box=objc_getAssociatedObject(view,&DEWebHostKey);
    DELegacyWebHost *host=box.host;
    if (host) return host;
    DEWebLock();
    if (getenv("AGEPAD_WEB_SOFTWARE_COMPOSITING")) {
      id<DEWebPreferencesAPI> prefs=[view preferences];
      if (![(id)prefs respondsToSelector:@selector(setAcceleratedCompositingEnabled:)]) DEUnsupported("web compositing preference unavailable");
      [prefs setAcceleratedCompositingEnabled:NO];
      fprintf(stderr,"DE_WEB_SOFTWARE_COMPOSITING enabled=%d\n",![prefs acceleratedCompositingEnabled]);
    }
    host=[[DELegacyWebHost alloc] initWithFrame:[view frame]];
    Class cls=NSClassFromString(@"WAKWindow");
    if (!cls || ![cls instancesRespondToSelector:@selector(initWithLayer:)]) DEUnsupported("WAK layer host unavailable");
    host.wakWindow=[(id<DEWAKWindowAPI>)[cls alloc] initWithLayer:host.layer];
    [host.wakWindow setContentView:view];
    if(getenv("AGEPAD_WEB_DIRECT_PAINT")) {
      [host.wakWindow setTilingMode:4]; // kWAKTilingModeDisabled from upstream WAKWindow.h.
      [host.wakWindow removeAllTiles];
      host.contentMode=UIViewContentModeRedraw;
      fprintf(stderr,"DE_WEB_DIRECT_PAINT UIKit drawRect uses original WebView; launcher refresh 10Hz\n");
    }
    // UIKit hierarchy owns host, host owns WAKWindow, WAKWindow owns WebView.
    // The reverse lookup is weak, preventing a WebView -> window retain cycle.
    box=[DEWeakWebHost new];box.host=host;objc_setAssociatedObject(view,&DEWebHostKey,box,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    fprintf(stderr,"DE_LEGACY_WEB_HOST_CREATED size=%gx%g\n",host.frame.size.width,host.frame.size.height);
    return host;
}
static void DEWAKWantsLayer(id view,SEL selector,BOOL wants) {
    if (!wants) DEUnsupported("legacy UIKit host requires layer backing");
    // Actual WAKWindow layer host is allocated when added to the UIKit hierarchy.
    fprintf(stderr,"DE_LEGACY_WEB_LAYER_REQUEST pending hierarchy attachment\n");
}

static void DEWAKAddTracking(id view,SEL selector,id<DETrackingConfig> area) {
 if ([area options]!=129) DEUnsupported("legacy tracking supports entered/exited active-always only");
 DELegacyWebHost *host=(id)DELegacyHost(view);
 if (!host.superview) DEUnsupported("tracking requires attached UIKit host");
 if (!host.trackingRecords) {
  host.trackingRecords=[NSMutableArray array];
  UIHoverGestureRecognizer *hover=[[UIHoverGestureRecognizer alloc] initWithTarget:host action:@selector(hover:)];
  hover.cancelsTouchesInView=NO;[host addGestureRecognizer:hover];
 }
 for (DEWebTrackingRecord *old in host.trackingRecords) if (old.area==area) return;
 DEWebTrackingRecord *record=[DEWebTrackingRecord new];record.area=area;[host.trackingRecords addObject:record];
 fprintf(stderr,"DE_WEB_TRACKING_ATTACHED options=129 actual UIKit hover observer\n");
}
static void DEWAKRemoveTracking(id view,SEL selector,id area) {
 DEWeakWebHost *box=objc_getAssociatedObject(view,&DEWebHostKey);
 for (DEWebTrackingRecord *old in box.host.trackingRecords.copy) if (old.area==area) [box.host.trackingRecords removeObjectIdenticalTo:old];
}
static IMP DEOriginalWebSetFrame;
static void DEWAKSetFrame(id view,SEL selector,CGRect frame) {
 ((void(*)(id,SEL,CGRect))DEOriginalWebSetFrame)(view,selector,frame);
 DEWeakWebHost *box=objc_getAssociatedObject(view,&DEWebHostKey);
 box.host.frame=frame;[box.host setNeedsLayout];
}
