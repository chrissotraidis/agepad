// The Mac engine's CoreVideo display link has no iOS counterpart. Drive its
// callback from the actual UIKit display refresh while keeping the original
// CoreVideo call shape at the binary boundary.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CVBase.h>
#import <CoreVideo/CVReturn.h>
#import <mach/mach_time.h>

typedef void *DECVDisplayLinkRef;
typedef CVReturn (*DECVDisplayLinkOutputCallback)(DECVDisplayLinkRef,
    const CVTimeStamp *, const CVTimeStamp *, CVOptionFlags, CVOptionFlags *, void *);

@interface DECVDisplayLink : NSObject
@property(nonatomic,strong) CADisplayLink *timer;
@property(nonatomic) DECVDisplayLinkOutputCallback callback;
@property(nonatomic) void *context;
@end

@implementation DECVDisplayLink
- (void)tick:(CADisplayLink *)timer {
    if (!self.callback) return;
    CVTimeStamp now={0}, output={0};
    now.hostTime=mach_absolute_time();
    now.flags=kCVTimeStampHostTimeValid;
    output=now;
    mach_timebase_info_data_t scale;
    mach_timebase_info(&scale);
    output.hostTime += (uint64_t)((timer.targetTimestamp-timer.timestamp)*1e9*
                                  scale.denom/scale.numer);
    CVOptionFlags flags=0;
    self.callback((__bridge void *)self,&now,&output,0,&flags,self.context);
}
@end

CVReturn DECVDisplayLinkCreateWithActiveCGDisplays(DECVDisplayLinkRef *out)
    __asm__("_CVDisplayLinkCreateWithActiveCGDisplays");
CVReturn DECVDisplayLinkCreateWithActiveCGDisplays(DECVDisplayLinkRef *out) {
    if (!out) return kCVReturnInvalidArgument;
    *out=(__bridge_retained void *)[DECVDisplayLink new];
    return kCVReturnSuccess;
}
CVReturn DECVDisplayLinkSetCurrentCGDisplay(DECVDisplayLinkRef link, uint32_t display)
    __asm__("_CVDisplayLinkSetCurrentCGDisplay");
CVReturn DECVDisplayLinkSetCurrentCGDisplay(DECVDisplayLinkRef link, uint32_t display) {
    (void)display;
    return link ? kCVReturnSuccess : kCVReturnInvalidArgument;
}
CVReturn DECVDisplayLinkSetOutputCallback(DECVDisplayLinkRef link,
    DECVDisplayLinkOutputCallback callback, void *context)
    __asm__("_CVDisplayLinkSetOutputCallback");
CVReturn DECVDisplayLinkSetOutputCallback(DECVDisplayLinkRef link,
    DECVDisplayLinkOutputCallback callback, void *context) {
    if (!link) return kCVReturnInvalidArgument;
    DECVDisplayLink *owner=(__bridge DECVDisplayLink *)link;
    owner.callback=callback;owner.context=context;
    return kCVReturnSuccess;
}
CVReturn DECVDisplayLinkStart(DECVDisplayLinkRef link) __asm__("_CVDisplayLinkStart");
CVReturn DECVDisplayLinkStart(DECVDisplayLinkRef link) {
    if (!link) return kCVReturnInvalidArgument;
    DECVDisplayLink *owner=(__bridge DECVDisplayLink *)link;
    dispatch_block_t start=^{
        if (owner.timer) return;
        owner.timer=[CADisplayLink displayLinkWithTarget:owner selector:@selector(tick:)];
        [owner.timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    };
    if (NSThread.isMainThread) start(); else dispatch_async(dispatch_get_main_queue(),start);
    return kCVReturnSuccess;
}
CVReturn DECVDisplayLinkStop(DECVDisplayLinkRef link) __asm__("_CVDisplayLinkStop");
CVReturn DECVDisplayLinkStop(DECVDisplayLinkRef link) {
    if (!link) return kCVReturnInvalidArgument;
    DECVDisplayLink *owner=(__bridge DECVDisplayLink *)link;
    dispatch_block_t stop=^{[owner.timer invalidate];owner.timer=nil;};
    if (NSThread.isMainThread) stop(); else dispatch_async(dispatch_get_main_queue(),stop);
    return kCVReturnSuccess;
}
void DECVDisplayLinkRelease(DECVDisplayLinkRef link) __asm__("_CVDisplayLinkRelease");
void DECVDisplayLinkRelease(DECVDisplayLinkRef link) {
    if (!link) return;
    DECVDisplayLinkStop(link);
    DECVDisplayLink *released=(__bridge_transfer DECVDisplayLink *)link;
    (void)released;
}
