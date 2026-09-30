// Native UIKit gesture recognition; routes commands into the original engine.
// One multi-finger gesture is either a zoom or a map drag, decided once:
// three or more fingers always drag; with two, whichever the fingers do
// first (spread 7% or move 16 points) wins until they lift.
typedef NS_ENUM(NSInteger, DEMapGestureMode) { DEMapGestureUndecided, DEMapGestureZoom, DEMapGestureScroll };
static DEMapGestureMode DEMapMode;
static BOOL DEGestureActive(UIGestureRecognizer *gesture) {
    return gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged;
}
@implementation DEGameViewHost (NativeTouch)
// iPadOS turns three-finger swipes and pinches into undo, redo, copy and
// paste (with a banner) and takes the touches; the map drag needs them.
- (UIEditingInteractionConfiguration)editingInteractionConfiguration API_AVAILABLE(ios(13.0)) {
    return UIEditingInteractionConfigurationNone;
}
- (void)installNativeGestures {
    self.multipleTouchEnabled=YES;
    UITapGestureRecognizer *order=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nativeOrder:)];
    // A two-finger tap must not buffer the entire one-finger drag while it
    // waits for a second contact. Deliver the primary pointer immediately;
    // UIKit cancels that stream if a multi-finger gesture wins recognition.
    order.numberOfTouchesRequired=2;order.delaysTouchesBegan=NO;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(nativeMapPan:)];
    // Two or three fingers drag the map (fingers only, so a hand resting while
    // the Pencil draws doesn't scroll). A two-finger tap barely moves, so it
    // stays a right click; a pinch that zooms doesn't scroll.
    pan.minimumNumberOfTouches=2;pan.maximumNumberOfTouches=4;
    pan.allowedTouchTypes=@[@(UITouchTypeDirect)];
    UIPinchGestureRecognizer *pinch=[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(nativeZoom:)];
    // The order tap no longer waits for pinch/pan to fail: two fingers landing
    // a few ms apart register a small scale change, which previously made the
    // pinch win and silently swallowed the right-click. A real pinch moves the
    // fingers beyond the tap's allowable movement, so the tap fails by itself.
    // Two-finger taps are recognised by the game view itself (touchesBegan);
    // this recognizer remains only as the object pinch coordinates with.
    order.enabled=NO;
    for(UIGestureRecognizer *gesture in @[order,pan,pinch]) {
        gesture.delegate=self;gesture.cancelsTouchesInView=YES;[self addGestureRecognizer:gesture];
    }
    // The map drag only watches: two-finger taps keep reaching the game view
    // (a tap that rolls a few points must stay a right click), and a real
    // drag moves too far to count as a tap.
    pan.cancelsTouchesInView=NO;
    self.orderTap=order;self.zoomPinch=pinch;self.mapPan=pan;
    // A mouse wheel or two-finger trackpad scroll arrives as a scroll-only
    // pan (no touches); send it as the Mac mouse wheel, which zooms in DE.
    UIPanGestureRecognizer *wheel=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(nativeWheel:)];
    wheel.allowedScrollTypesMask=UIScrollTypeMaskAll;wheel.allowedTouchTypes=@[];
    wheel.delegate=self;[self addGestureRecognizer:wheel];
    [self startTestInput];
    // Apple Pencil (2nd gen / Pro) barrel double-tap: deselect and stop
    // Pencil orders. Sent as Escape plus a disarm of sticky orders.
    if (@available(iOS 12.1,*)) {
        UIPencilInteraction *pencil=[UIPencilInteraction new];pencil.delegate=(id<UIPencilInteractionDelegate>)self;
        [self addInteraction:pencil];
    }
}
- (void)pencilInteractionDidTap:(UIPencilInteraction *)interaction API_AVAILABLE(ios(12.1)) {
    if (UIPencilInteraction.preferredTapAction!=UIPencilPreferredActionIgnore) [self pencilDeselect:"double-tap"];
}
// iPadOS 17.5+ delivers the double-tap here, and Apple Pencil Pro's squeeze.
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveTap:(UIPencilInteractionTap *)tap API_AVAILABLE(ios(17.5)) {
    if (UIPencilInteraction.preferredTapAction!=UIPencilPreferredActionIgnore) [self pencilDeselect:"double-tap"];
}
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveSqueeze:(UIPencilInteractionSqueeze *)squeeze API_AVAILABLE(ios(17.5)) {
    if(squeeze.phase==UIPencilInteractionPhaseEnded && UIPencilInteraction.preferredSqueezeAction!=UIPencilPreferredActionIgnore)
        [self pencilDeselect:"squeeze"];
}
- (void)pencilDeselect:(const char *)how {
    DEPencilOrderArmed=NO;DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();
    // One Escape per gesture: iPadOS may report it through two APIs, and this
    // code is loaded twice, so the guard is kept once per process. A second
    // Escape (or one with nothing selected) opened the game menu.
    NSMutableDictionary *shared=NSThread.mainThread.threadDictionary;
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if(now-[shared[@"AgePadPencilDeselectAt"] doubleValue]<0.3)return;
    shared[@"AgePadPencilDeselectAt"]=@(now);
    BOOL escape=DEMaybeSelected() || DEMenuOpen;
    fprintf(stderr,"DE_PENCIL_DOUBLE_TAP gesture=%s action=deselect escape=%d\n",how,escape);
    if(!escape)return;
    DESetMaybeSelected(NO);DEMenuOpen=NO;
    DEPostGameKey(53,@"\e",YES);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{DEPostGameKey(53,@"\e",NO);});
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    NSArray *together=@[self.zoomPinch?:NSNull.null,self.orderTap?:NSNull.null,self.mapPan?:NSNull.null];
    return a!=b && [together containsObject:a] && [together containsObject:b];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for(UIView *view=touch.view;view && view!=self;view=view.superview)
        if([view isKindOfClass:UIControl.class])return NO;
    return YES;
}
- (void)nativeMouse:(NSUInteger)type point:(CGPoint)point wheel:(CGFloat)wheel {
    id window=((id(*)(id,SEL))objc_msgSend)(self.originalView,sel_registerName("window"));
    id content=((id(*)(id,SEL))objc_msgSend)(window,sel_registerName("contentView"));
    UIView *host=((id(*)(id,SEL))objc_msgSend)(content,sel_registerName("deHost"));
    CGPoint local=[self convertPoint:point toView:host];
    id<DEGameMouseEvent> e=[NSClassFromString(@"NSEvent") new];
    e.type=type;e.window=window;e.timestamp=CACurrentMediaTime();e.clickCount=1;
    e.buttonNumber=(type==3 || type==4)?1:(type>=25 && type<=27)?2:0;
    if(type==3 || type==7 || type==25 || type==27)e.pressure=1;
    e.locationInWindow=CGPointMake(local.x-host.bounds.origin.x,CGRectGetMaxY(host.bounds)-local.y);
    static CGPoint previous;
    if(type==7 || type==27){e.deltaX=point.x-previous.x;e.deltaY=point.y-previous.y;}
    previous=point;
    if(type==22){e.deltaY=wheel;[(id)e setValue:@(wheel) forKey:@"scrollingDeltaY"];}
    id app=((id(*)(id,SEL))objc_msgSend)(NSClassFromString(@"NSApplication"),sel_registerName("sharedApplication"));
    DEPostOrderedMouseEvent((id)e,self.gameLayer,^{
        ((void(*)(id,SEL,id,BOOL))objc_msgSend)(app,sel_registerName("postEvent:atStart:"),e,NO);
    });
}
- (void)nativeOrder:(UITapGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateRecognized)return;
    DEMenuOpen=NO;
    CGPoint point=[gesture locationInView:self];
    fprintf(stderr,"DE_TWO_FINGER_ORDER x=%g y=%g\n",point.x,point.y);
    [self nativeMouse:5 point:point wheel:0];[self nativeMouse:3 point:point wheel:0];
    [self nativeMouse:4 point:point wheel:0];
    DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();
}
- (void)nativeMapPan:(UIPanGestureRecognizer *)gesture {
    // The pan reports the fingers' centre, which jumps when a finger lands or
    // lifts mid-drag; carry an offset so the map doesn't jump with it.
    static CGPoint offset,last;static NSUInteger fingers;
    CGPoint centre=[gesture locationInView:self];
    UIGestureRecognizerState state=gesture.state;
    if(state==UIGestureRecognizerStateBegan){offset=CGPointZero;fingers=gesture.numberOfTouches;
        if(!DEGestureActive(self.zoomPinch))DEMapMode=DEMapGestureUndecided;}
    else if(gesture.numberOfTouches!=fingers){fingers=gesture.numberOfTouches;offset=CGPointMake(last.x-centre.x,last.y-centre.y);}
    if(gesture.numberOfTouches>=3 && DEMapMode!=DEMapGestureZoom)DEMapMode=DEMapGestureScroll;
    CGPoint point=CGPointMake(centre.x+offset.x,centre.y+offset.y);last=point;
    [self nativeMapScrollPhase:state==UIGestureRecognizerStateBegan?0:state==UIGestureRecognizerStateChanged?1:
        (state==UIGestureRecognizerStateEnded || state==UIGestureRecognizerStateCancelled || state==UIGestureRecognizerStateFailed)?2:-1 point:point];
}
// Map drag. DE's click-drag scrolling (right button, the game's default) is a
// joystick, not a grab: while the button is held the view scrolls away from
// the press point, faster the further the pointer is, and not at all within
// about 68 points. Measured on the iPad Pro 12.9 (30 September, default zoom),
// the map content moves opposite the pointer offset (dx, dy) at
//   v = 3.84 e + 0.0622 e^2 points/s,  e = r - 68,  r = |(dx, 1.78 dy)|,
// in the direction of (dx, 1.78 dy). So a finger's own position as the
// pointer scrolled the wrong way, did nothing for small moves and ran away on
// big ones. Instead AgePad presses once in the middle of the map and, 60
// times a second, puts the pointer at the offset whose speed moves the view by
// what the fingers still need (their movement minus what the view has
// already moved), then releases once the view has caught up and the button
// has been held 0.35 s (a shorter right press would be an order). A new drag
// before that continues the same press. Phase 0 begin, 1 move, 2 end.
static const CGFloat DEScrollDeadZone=68,DEScrollLinear=3.84,DEScrollSquare=0.0622,DEScrollYStretch=1.78;
// The map moves 1.2 times as far as the fingers (Chris, 30 September: 1:1
// felt a little slow on the 12.9-inch screen).
static const CGFloat DEScrollMaxSpeed=1800,DEScrollCatchUp=0.08,DEScrollGain=1.2;
static CGFloat DEScrollRadiusForSpeed(CGFloat v) { // inverse of v(e)
    return DEScrollDeadZone+(sqrt(DEScrollLinear*DEScrollLinear+4*DEScrollSquare*v)-DEScrollLinear)/(2*DEScrollSquare);
}
static struct { BOOL active,started,pressed; CGPoint fingerStart,finger,base,target,moved,velocity,anchor;
    NSTimeInterval pressedAt,tick; __unsafe_unretained NSTimer *timer; } DEScroll;
- (void)nativeMapScrollPhase:(NSInteger)phase point:(CGPoint)point {
    if(phase==0) {
        DEMenuOpen=NO;DEScroll.active=YES;DEScroll.started=NO;DEScroll.fingerStart=DEScroll.finger=point;
        DEScroll.base=DEScroll.target;
        fprintf(stderr,"DE_GESTURE_SCROLL state=began x=%g y=%g continuing=%d\n",point.x,point.y,DEScroll.pressed);
        return;
    }
    if(!DEScroll.active)return;
    if(DEMapMode==DEMapGestureZoom && !DEScroll.started){if(phase==2)DEScroll.active=NO;return;}
    if(!DEScroll.started) {
        CGFloat moved=hypot(point.x-DEScroll.fingerStart.x,point.y-DEScroll.fingerStart.y);
        if(phase==1 && moved>=(DEMapMode==DEMapGestureScroll || DEScroll.pressed?6:16)) {
            DEScroll.started=YES;DEMapMode=DEMapGestureScroll;
        }
    }
    if(DEScroll.started) {
        DEScroll.finger=point;
        DEScroll.target=CGPointMake(DEScroll.base.x+(point.x-DEScroll.fingerStart.x)*DEScrollGain,
                                    DEScroll.base.y+(point.y-DEScroll.fingerStart.y)*DEScrollGain);
        if(!DEScroll.pressed) {
            DEScroll.pressed=YES;DEScroll.pressedAt=DEScroll.tick=CACurrentMediaTime();
            DEScroll.moved=DEScroll.velocity=CGPointZero;
            DEScroll.anchor=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetHeight(self.bounds)*0.43);
            [self nativeMouse:5 point:DEScroll.anchor wheel:0];[self nativeMouse:3 point:DEScroll.anchor wheel:0];
            __weak DEGameViewHost *weakSelf=self;
            NSTimer *timer=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *t){[weakSelf mapScrollTick];}];
            [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];DEScroll.timer=timer;
        }
    }
    if(phase==2) {
        DEScroll.active=NO;
        if(!DEGestureActive(self.zoomPinch))DEMapMode=DEMapGestureUndecided; // the fingers are up
        fprintf(stderr,"DE_GESTURE_SCROLL state=end x=%g y=%g target=%g,%g\n",point.x,point.y,DEScroll.target.x,DEScroll.target.y);
    }
}
- (void)mapScrollTick {
    NSTimeInterval now=CACurrentMediaTime(),dt=MIN(now-DEScroll.tick,0.1);DEScroll.tick=now;
    DEScroll.moved.x+=DEScroll.velocity.x*dt;DEScroll.moved.y+=DEScroll.velocity.y*dt;
    CGPoint need=CGPointMake(DEScroll.target.x-DEScroll.moved.x,DEScroll.target.y-DEScroll.moved.y);
    CGFloat distance=hypot(need.x,need.y);
    if(distance<1.5 && !DEScroll.active && now-DEScroll.pressedAt>=0.35) {
        [DEScroll.timer invalidate];DEScroll.timer=nil;DEScroll.pressed=NO;DEScroll.velocity=CGPointZero;
        [self nativeMouse:7 point:DEScroll.anchor wheel:0];[self nativeMouse:4 point:DEScroll.anchor wheel:0];
        [self nativeMouse:5 point:DEScroll.finger wheel:0]; // leave the pointer where the fingers lifted
        fprintf(stderr,"DE_GESTURE_SCROLL state=released moved=%g,%g\n",DEScroll.moved.x,DEScroll.moved.y);
        DEScroll.target=DEScroll.moved=CGPointZero;
        return;
    }
    CGFloat speed=distance<1.5?0:MIN(distance/DEScrollCatchUp,DEScrollMaxSpeed);
    DEScroll.velocity=speed>0?CGPointMake(need.x/distance*speed,need.y/distance*speed):CGPointZero;
    CGPoint pointer=DEScroll.anchor;
    if(speed>0) {
        // Content moves opposite the pointer; in the game's measure y counts 1.78 times.
        CGFloat r=DEScrollRadiusForSpeed(speed);
        pointer=CGPointMake(DEScroll.anchor.x-need.x/distance*r,DEScroll.anchor.y-need.y/distance*r/DEScrollYStretch);
    }
    [self nativeMouse:7 point:pointer wheel:0];
}
// Zoom in whole wheel clicks, the same step as ZOOM +/−; fractional wheel
// amounts zoomed far less than the fingers moved.
- (void)sendZoomSteps:(CGFloat *)pending point:(CGPoint)point source:(const char *)source {
    int steps=0;
    while(fabs(*pending)>=1){CGFloat step=*pending>0?1:-1;[self nativeMouse:22 point:point wheel:step];*pending-=step;steps+=(int)step;}
    if(steps)fprintf(stderr,"DE_GESTURE_ZOOM source=%s steps=%d\n",source,steps);
}
- (void)nativeZoom:(UIPinchGestureRecognizer *)gesture {
    static CGFloat pending;
    if(gesture.state==UIGestureRecognizerStateBegan){pending=0;if(!DEGestureActive(self.mapPan))DEMapMode=DEMapGestureUndecided;}
    if(gesture.state!=UIGestureRecognizerStateChanged)return;
    // Zoom is a two-finger gesture; a third finger or a started drag ignores it.
    if(gesture.numberOfTouches!=2 || DEMapMode==DEMapGestureScroll){gesture.scale=1;pending=0;return;}
    // One step per 5% change in finger spread (spreading them to double
    // their distance is about 14 steps; 10 felt slow).
    pending+=log(gesture.scale)*21.0;gesture.scale=1;
    if(fabs(pending)>=1)DEMapMode=DEMapGestureZoom;
    [self sendZoomSteps:&pending point:[gesture locationInView:self] source:"pinch"];
}
- (void)nativeWheel:(UIPanGestureRecognizer *)gesture {
    static CGFloat pending;
    if(gesture.state==UIGestureRecognizerStateBegan)pending=0;
    if(gesture.state!=UIGestureRecognizerStateChanged)return;
    // Trackpad two-finger scroll or mouse wheel: one step per 8 points.
    pending+=[gesture translationInView:self].y/8.0;
    [gesture setTranslation:CGPointZero inView:self];
    [self sendZoomSteps:&pending point:[gesture locationInView:self] source:"wheel"];
}
// Test-only input (AGEPAD_TEST_INPUT=1): lines written to
// Documents/agepad-test-input.txt from the Mac are played through the same
// mouse/key paths as touches, in screen points, on the largest visible game
// view, then the file is removed:
//   click X Y | rclick X Y | key MACKEYCODE | text lowercase0to9 | wait MS
//   mdrag X1 Y1 X2 Y2 (three-finger map scroll) | pdtap (Pencil double-tap)
//   mhold X Y DX DY MS (right button held at an offset: calibrates click-drag scrolling)
- (void)startTestInput {
    if (!getenv("AGEPAD_TEST_INPUT")) return;
    static NSHashTable<DEGameViewHost *> *hosts;
    static dispatch_once_t once;
    dispatch_once(&once,^{ hosts=[NSHashTable weakObjectsHashTable]; });
    [hosts addObject:self];
    static BOOL started;
    if (started) return;
    started=YES;
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject
        stringByAppendingPathComponent:@"agepad-test-input.txt"];
    __block BOOL busy=NO;
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        NSString *text=busy?nil:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!text) return;
        DEGameViewHost *host=nil;
        for (DEGameViewHost *candidate in hosts)
            if (candidate.window && !candidate.hidden && candidate.bounds.size.width*candidate.bounds.size.height>host.bounds.size.width*host.bounds.size.height)
                host=candidate;
        if (!host) return;
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        busy=YES;
        double at=0;
        for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSArray<NSString *> *word=[line componentsSeparatedByString:@" "];
            if (!line.length) continue;
            if ([word[0] isEqualToString:@"wait"] && word.count>1) { at+=word[1].doubleValue/1000;continue; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(at*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                fprintf(stderr,"DE_TEST_INPUT %s view=%gx%g\n",line.UTF8String,host.bounds.size.width,host.bounds.size.height);
                if ([word[0] isEqualToString:@"pdtap"]) {
                    [host pencilDeselect:"test"];
                } else if (word.count>5 && [word[0] isEqualToString:@"mhold"]) {
                    // Right button pressed at X Y, pointer held DX DY away for MS: measures
                    // how DE's click-drag scrolling responds to a held offset.
                    CGPoint from=CGPointMake(word[1].doubleValue,word[2].doubleValue);
                    CGPoint to=CGPointMake(from.x+word[3].doubleValue,from.y+word[4].doubleValue);
                    double ms=word[5].doubleValue;
                    [host nativeMouse:5 point:from wheel:0];[host nativeMouse:3 point:from wheel:0];
                    for (int step=1;step*16<ms;step++)
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,step*16*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ [host nativeMouse:7 point:to wheel:0]; });
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(ms*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{ [host nativeMouse:4 point:to wheel:0]; });
                } else if (word.count>4 && [word[0] isEqualToString:@"mdrag"]) {
                    // The three-finger scroll's own event sequence, from X1 Y1 to X2 Y2.
                    CGPoint from=CGPointMake(word[1].doubleValue,word[2].doubleValue),to=CGPointMake(word[3].doubleValue,word[4].doubleValue);
                    [host nativeMapScrollPhase:0 point:from];
                    for (int step=1;step<=12;step++)
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,step*25*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                            [host nativeMapScrollPhase:1 point:CGPointMake(from.x+(to.x-from.x)*step/12,from.y+(to.y-from.y)*step/12)]; });
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,350*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ [host nativeMapScrollPhase:2 point:to]; });
                } else if (word.count>2 && ([word[0] isEqualToString:@"click"] || [word[0] isEqualToString:@"rclick"])) {
                    BOOL right=[word[0] isEqualToString:@"rclick"];
                    CGPoint point=CGPointMake(word[1].doubleValue,word[2].doubleValue);
                    [host nativeMouse:5 point:point wheel:0];[host nativeMouse:right?3:1 point:point wheel:0];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                        [host nativeMouse:right?4:2 point:point wheel:0]; });
                } else if ([word[0] isEqualToString:@"text"] && word.count>1) {
                    // Mac key codes for a–z and 0–9.
                    static const char *letters="asdfhgzxcv?bqweryt123465=97-80]ou[ip?lj'k;?,/nm";
                    double delay=0;
                    for (NSUInteger i=0;i<word[1].length;i++) {
                        unichar c=[word[1] characterAtIndex:i];
                        const char *found=c<128?strchr(letters,(char)c):NULL;
                        if (!found || c=='?') continue;
                        unsigned short code=(unsigned short)(found-letters);
                        NSString *chars=[NSString stringWithFormat:@"%C",c];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ DEPostGameKey(code,chars,YES); });
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((delay+0.06)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ DEPostGameKey(code,chars,NO); });
                        delay+=0.15;
                    }
                } else if ([word[0] isEqualToString:@"key"] && word.count>1) {
                    unsigned short code=(unsigned short)word[1].intValue;
                    // Return, Escape, or F1–F12 (their AppKit function-key characters).
                    static const unsigned short functionKeys[12]={122,120,99,118,96,97,98,100,101,109,103,111};
                    NSString *chars=code==36?@"\r":code==53?@"\e":nil;
                    for (int f=0;f<12 && !chars;f++) if (functionKeys[f]==code) chars=[NSString stringWithFormat:@"%C",(unichar)(0xF704+f)];
                    if (!chars) { fprintf(stderr,"DE_TEST_INPUT unsupported key %u\n",code);return; }
                    DEPostGameKey(code,chars,YES);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ DEPostGameKey(code,chars,NO); });
                }
            });
            at+=0.25;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(at*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ busy=NO; });
    }];
    fprintf(stderr,"DE_TEST_INPUT ready file=%s\n",path.UTF8String);
}
@end
