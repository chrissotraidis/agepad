// Retain events the original application explicitly constructs. No input is
// generated here; native touch/keyboard event translation remains separate.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include "UnsupportedBoundary.h"
#import <UIKit/UIKit.h>
extern CGPoint DEUIKitPointerPosition(void);
@interface NSEvent : NSObject
@property(nonatomic) NSUInteger type,modifierFlags;
@property(nonatomic) CGPoint locationInWindow;
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) NSTimeInterval deEnqueuedTime;
@property(nonatomic) NSInteger windowNumber,data1,data2;
@property(nonatomic) int16_t subtype;
@property(nonatomic) NSInteger buttonNumber,clickCount,eventNumber;
@property(nonatomic) CGFloat deltaX,deltaY,deltaZ;
@property(nonatomic) CGFloat scrollingDeltaX,scrollingDeltaY;
@property(nonatomic) BOOL hasPreciseScrollingDeltas,isDirectionInvertedFromDevice;
@property(nonatomic) NSUInteger phase,momentumPhase;
@property(nonatomic) float pressure;
@property(nonatomic,weak) id window;
@property(nonatomic) unsigned short keyCode;
@property(nonatomic,copy) NSString *characters,*charactersIgnoringModifiers;
@property(nonatomic,getter=isARepeat) BOOL ARepeat;
@property(nonatomic,strong) id context,trackingArea;
@end
@implementation NSEvent
+ (CGPoint)mouseLocation {
    CGPoint point=DEUIKitPointerPosition();
    CGSize screen=UIScreen.mainScreen.bounds.size;
    fprintf(stderr,"DE_NSEVENT_MOUSE_LOCATION UIKit=%g,%g screenHeight=%g\n",point.x,point.y,screen.height);
    return CGPointMake(point.x,screen.height-point.y);
}
+ (NSTimeInterval)doubleClickInterval {
    // App-owned gesture policy; UIKit does not export the macOS preference.
    // The engine consumes this threshold for its click timing.
    const char *value=getenv("AGEPAD_DOUBLE_CLICK_INTERVAL");
    char *end=NULL;double seconds=value?strtod(value,&end):0.3;
    if(value && (!end || *end || !(seconds>=0.1 && seconds<=1.0)))DEUnsupported("invalid app double-click interval");
    fprintf(stderr,"DE_DOUBLE_CLICK_INTERVAL app_policy=%g seconds\n",seconds);
    return seconds;
}

+ (NSEvent *)otherEventWithType:(NSUInteger)type location:(CGPoint)location modifierFlags:(NSUInteger)flags timestamp:(NSTimeInterval)timestamp windowNumber:(NSInteger)number context:(id)context subtype:(int16_t)subtype data1:(NSInteger)data1 data2:(NSInteger)data2 {
    if (type<13 || type>16) DEUnsupported("non-other NSEvent factory type");
    NSEvent *event=[self new];event.type=type;event.locationInWindow=location;event.modifierFlags=flags;event.timestamp=timestamp;event.windowNumber=number;event.context=context;event.subtype=subtype;event.data1=data1;event.data2=data2;
    fprintf(stderr,"DE_ORIGINAL_EVENT_CREATED type=%lu subtype=%d\n",(unsigned long)type,subtype);
    return event;
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSEvent %s]\n",sel_getName(sel));DEUnsupported("NSEvent");}
+ (BOOL)resolveClassMethod:(SEL)sel {fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSEvent %s]\n",sel_getName(sel));DEUnsupported("NSEvent");}
@end
