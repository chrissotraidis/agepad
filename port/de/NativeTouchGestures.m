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
    pan.minimumNumberOfTouches=2;pan.maximumNumberOfTouches=2;
    UIPinchGestureRecognizer *pinch=[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(nativeZoom:)];
    [order requireGestureRecognizerToFail:pan];[order requireGestureRecognizerToFail:pinch];
    // Pan and pinch are exclusive: a zoom must not issue a move order.
    for(UIGestureRecognizer *gesture in @[order,pan,pinch]) {
        gesture.delegate=self;gesture.cancelsTouchesInView=YES;[self addGestureRecognizer:gesture];
    }
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
    e.buttonNumber=(type==3 || type==4)?1:0;
    e.locationInWindow=CGPointMake(local.x-host.bounds.origin.x,CGRectGetMaxY(host.bounds)-local.y);
    if(type==22){e.deltaY=wheel;[(id)e setValue:@(wheel) forKey:@"scrollingDeltaY"];}
    id app=((id(*)(id,SEL))objc_msgSend)(NSClassFromString(@"NSApplication"),sel_registerName("sharedApplication"));
    DEPostOrderedMouseEvent((id)e,self.gameLayer,^{
        ((void(*)(id,SEL,id,BOOL))objc_msgSend)(app,sel_registerName("postEvent:atStart:"),e,NO);
    });
}
- (void)nativeOrder:(UITapGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateRecognized)return;
    CGPoint point=[gesture locationInView:self];
    [self nativeMouse:5 point:point wheel:0];[self nativeMouse:3 point:point wheel:0];
    [self nativeMouse:4 point:point wheel:0];
    DEGlobalTouchCommandMode=NO;DERefreshTouchCommandButtons();
}
- (void)nativeMapPan:(UIPanGestureRecognizer *)gesture {
    // The shipped hotkeys.json binds click-drag scroll to slash.
    CGPoint point=[gesture locationInView:self];
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self nativeMouse:5 point:point wheel:0];DEPostGameKey(44,@"/",YES);
    } else if(gesture.state==UIGestureRecognizerStateChanged) {
        [self nativeMouse:5 point:point wheel:0];
    } else if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        DEPostGameKey(44,@"/",NO);
    }
}
- (void)nativeZoom:(UIPinchGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateChanged)return;
    CGFloat amount=log(gesture.scale)*8.0;
    if(fabs(amount)<0.2)return;
    [self nativeMouse:22 point:[gesture locationInView:self] wheel:amount];gesture.scale=1;
}
@end
