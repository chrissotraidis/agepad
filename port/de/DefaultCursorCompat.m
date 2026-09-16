// App-owned original bitmap cursor, following the UIKit logical pointer.
// Cursor stacks and hide/unhide remain unimplemented.
#include "UnsupportedBoundary.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
extern CGPoint DEUIKitPointerPosition(void);
#import <CoreGraphics/CoreGraphics.h>
#include <stdlib.h>
@class NSImage;
@interface NSCursor : NSObject {
    NSImage *_deImage;
    CGPoint _deHotSpot;
}
+ (NSCursor *)arrowCursor;
+ (NSCursor *)currentCursor;
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)point;
@property(nonatomic,readonly) NSImage *image;
@property(nonatomic,readonly) CGPoint hotSpot;
- (void)set;
@end
static NSCursor *DECurrentCursor;
static UIImageView *DECursorView;
static CADisplayLink *DECursorDisplayLink;
@implementation NSCursor
+ (NSCursor *)currentCursor {
    @synchronized(self) { return DECurrentCursor?:[self arrowCursor]; }
}
+ (NSCursor *)arrowCursor {
    if (!getenv("AGEPAD_DEFAULT_UIKIT_CURSOR")) DEUnsupported("+[NSCursor arrowCursor]");
    static NSCursor *cursor;static dispatch_once_t once;
    dispatch_once(&once,^{cursor=[NSCursor new];
        fprintf(stderr,"DE_DEFAULT_CURSOR UIKit pointer appearance retained\n");fflush(stderr);});
    return cursor;
}
- (instancetype)initWithImage:(NSImage *)image hotSpot:(CGPoint)point {
    if (!getenv("AGEPAD_CURSOR_IMAGES")) DEUnsupported("-[NSCursor initWithImage:hotSpot:]");
    if (!image) return nil;
    self=[super init];
    if (self) {
        _deImage=image;_deHotSpot=point;
        fprintf(stderr,"DE_CURSOR_IMAGE_STORED hotspot=%g,%g\n",point.x,point.y);fflush(stderr);
    }
    return self;
}
- (NSImage *)image {
    if (!_deImage) DEUnsupported("-[NSCursor image] platform default has no exported bitmap");
    return _deImage;
}
- (CGPoint)hotSpot { return _deHotSpot; }
- (void)deUpdateCursor:(CADisplayLink *)link {
    NSCursor *cursor=[NSCursor currentCursor];
    if(!cursor->_deImage || !DECursorView.superview)return;
    UIWindow *window=DECursorView.window;
    CGPoint p=[window convertPoint:DEUIKitPointerPosition() fromCoordinateSpace:window.screen.coordinateSpace];
    CGRect frame=DECursorView.frame;frame.origin=CGPointMake(p.x-cursor->_deHotSpot.x,p.y-cursor->_deHotSpot.y);DECursorView.frame=frame;
    [DECursorView.superview bringSubviewToFront:DECursorView];
}
- (void)set {
    if (!_deImage && self!=[NSCursor arrowCursor]) DEUnsupported("-[NSCursor set] non-default cursor");
    dispatch_async(dispatch_get_main_queue(),^{
        @synchronized(NSCursor.class) { DECurrentCursor=self; }
        if(!self->_deImage){DECursorView.hidden=YES;return;}
        UIWindow *window=nil;for(UIWindow *candidate in UIApplication.sharedApplication.windows)if(candidate.isKeyWindow){window=candidate;break;}
        if(!window)DEUnsupported("custom cursor requires UIKit window");
        CGImageRef pixels=((CGImageRef(*)(id,SEL,CGRect *,id,id))objc_msgSend)(self->_deImage,sel_registerName("CGImageForProposedRect:context:hints:"),NULL,nil,nil);
        CGSize size=((CGSize(*)(id,SEL))objc_msgSend)(self->_deImage,sel_registerName("size"));
        if(!pixels || size.width<=0 || size.height<=0)DEUnsupported("custom cursor requires real bitmap and size");
        if(!DECursorView){DECursorView=[UIImageView new];DECursorView.userInteractionEnabled=NO;DECursorView.accessibilityElementsHidden=YES;}
        DECursorView.image=[UIImage imageWithCGImage:pixels];DECursorView.frame=(CGRect){CGPointZero,size};DECursorView.hidden=NO;
        [window addSubview:DECursorView];
        if(!DECursorDisplayLink){DECursorDisplayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(deUpdateCursor:)];[DECursorDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];}
        [self deUpdateCursor:nil];
        fprintf(stderr,"DE_CUSTOM_CURSOR_DISPLAYED bitmap=%zux%zu points=%gx%g hotspot=%g,%g\n",CGImageGetWidth(pixels),CGImageGetHeight(pixels),size.width,size.height,self->_deHotSpot.x,self->_deHotSpot.y);
    });
}
+ (BOOL)resolveClassMethod:(SEL)selector {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSCursor %s]\n",sel_getName(selector));
    DEUnsupported("NSCursor");
}
+ (BOOL)resolveInstanceMethod:(SEL)selector {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSCursor %s]\n",sel_getName(selector));
    DEUnsupported("NSCursor");
}
@end
