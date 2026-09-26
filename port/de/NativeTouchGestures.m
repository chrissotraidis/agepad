// Native UIKit gesture recognition; routes commands into the original engine.
@implementation DEGameViewHost (NativeTouch)
- (void)installNativeGestures {
    self.multipleTouchEnabled=YES;
    UITapGestureRecognizer *order=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nativeOrder:)];
    // A two-finger tap must not buffer the entire one-finger drag while it
    // waits for a second contact. Deliver the primary pointer immediately;
    // UIKit cancels that stream if a multi-finger gesture wins recognition.
    order.numberOfTouchesRequired=2;order.delaysTouchesBegan=NO;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(nativeMapPan:)];
    // Three fingers scroll the map; two fingers are reserved for the
    // right-click tap and pinch zoom so they never compete with a scroll.
    // Three or four fingers (fingers rarely land together; a fourth is fine).
    pan.minimumNumberOfTouches=3;pan.maximumNumberOfTouches=4;
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
    self.orderTap=order;self.zoomPinch=pinch;
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
    [self pencilDeselect:"double-tap"];
}
// iPadOS 17.5+ delivers the double-tap here, and Apple Pencil Pro's squeeze.
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveTap:(UIPencilInteractionTap *)tap API_AVAILABLE(ios(17.5)) {
    [self pencilDeselect:"double-tap"];
}
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveSqueeze:(UIPencilInteractionSqueeze *)squeeze API_AVAILABLE(ios(17.5)) {
    if(squeeze.phase==UIPencilInteractionPhaseEnded)[self pencilDeselect:"squeeze"];
}
- (void)pencilDeselect:(const char *)how {
    DEPencilOrderArmed=NO;DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();
    fprintf(stderr,"DE_PENCIL_DOUBLE_TAP gesture=%s action=deselect key=escape\n",how);
    DEPostGameKey(53,@"\e",YES);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{DEPostGameKey(53,@"\e",NO);});
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return (a==self.orderTap && b==self.zoomPinch) || (a==self.zoomPinch && b==self.orderTap);
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
    if(type==25 || type==27)e.pressure=1;
    e.locationInWindow=CGPointMake(local.x-host.bounds.origin.x,CGRectGetMaxY(host.bounds)-local.y);
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
    CGPoint point=[gesture locationInView:self];
    UIGestureRecognizerState state=gesture.state;
    [self nativeMapScrollPhase:state==UIGestureRecognizerStateBegan?0:state==UIGestureRecognizerStateChanged?1:
        (state==UIGestureRecognizerStateEnded || state==UIGestureRecognizerStateCancelled || state==UIGestureRecognizerStateFailed)?2:-1 point:point];
}
// DE scrolls when the map is dragged with its click-drag-scroll mouse button
// (Options → Controls, middle button by default on Mac) while the
// CLICK_DRAG_SCROLL hotkey (slash) may also be held. Send both: a middle
// (other) button drag with slash down, so either setting scrolls.
// Phase 0 begin, 1 move, 2 end.
// Three fingers move the map like a joystick: the arrow keys DE scrolls with
// by default are held in the direction the fingers moved from where they
// landed (content follows the fingers: dragging left shows what is to the
// right), and released when the fingers lift. A dead zone stops jitter.
- (void)nativeMapScrollPhase:(NSInteger)phase point:(CGPoint)point {
    static CGPoint start;
    static BOOL held[4]; // left, right, down, up
    static const unsigned short keys[4]={123,124,125,126};
    static NSString *chars[4];
    if(!chars[0]){chars[0]=@"\uF702";chars[1]=@"\uF703";chars[2]=@"\uF701";chars[3]=@"\uF700";}
    BOOL want[4]={NO,NO,NO,NO};
    if(phase==0){start=point;DEMenuOpen=NO;fprintf(stderr,"DE_GESTURE_SCROLL state=began x=%g y=%g\n",point.x,point.y);}
    if(phase==1) {
        CGFloat dx=point.x-start.x,dy=point.y-start.y,dead=18;
        want[0]=dx>dead;want[1]=dx<-dead;want[2]=dy<-dead;want[3]=dy>dead;
    }
    for(int i=0;i<4;i++) if(want[i]!=held[i]) {
        held[i]=want[i];DEPostGameKey(keys[i],chars[i],want[i]);
    }
    if(phase==2)fprintf(stderr,"DE_GESTURE_SCROLL state=end x=%g y=%g\n",point.x,point.y);
}
- (void)nativeZoom:(UIPinchGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateChanged)return;
    CGFloat amount=log(gesture.scale)*8.0;
    if(fabs(amount)<0.2)return;
    fprintf(stderr,"DE_GESTURE_ZOOM amount=%g\n",amount);
    [self nativeMouse:22 point:[gesture locationInView:self] wheel:amount];gesture.scale=1;
}
- (void)nativeWheel:(UIPanGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateChanged)return;
    CGFloat amount=[gesture translationInView:self].y/12.0;
    if(fabs(amount)<0.5)return;
    fprintf(stderr,"DE_WHEEL amount=%g\n",amount);
    [self nativeMouse:22 point:[gesture locationInView:self] wheel:amount];
    [gesture setTranslation:CGPointZero inView:self];
}
// Test-only input (AGEPAD_TEST_INPUT=1): lines written to
// Documents/agepad-test-input.txt from the Mac are played through the same
// mouse/key paths as touches, in screen points, on the largest visible game
// view, then the file is removed:
//   click X Y | rclick X Y | key MACKEYCODE | text lowercase0to9 | wait MS
//   mdrag X1 Y1 X2 Y2 (three-finger map scroll) | pdtap (Pencil double-tap)| rclick X Y | key MACKEYCODE | text lowercaseletters0to9 | wait MS
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
