#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <GameController/GameController.h>
#include "UnsupportedBoundary.h"
#include "HardwareKeyMapping.h"
#include <dlfcn.h>
extern CGPoint DEUIKitPointerPosition(void);
// App-owned input domain: iOS has no macOS login-session event stream.
@interface DEAppEventSource : NSObject
@property(nonatomic) int32_t stateID;
@end
@implementation DEAppEventSource
@end
const void *CGEventSourceCreate(int32_t stateID) {
    if (!getenv("AGEPAD_POINTER_STATE")) DEUnsupported("CGEvent source disabled");
    fprintf(stderr,"DE_EVENT_SOURCE_CREATE state=%d domain=app\n",stateID);
    if (stateID < -1 || stateID > 1) return NULL;
    DEAppEventSource *source=[DEAppEventSource new];
    source.stateID=stateID;
    return CFBridgingRetain(source);
}
void CGEventSourceSetLocalEventsSuppressionInterval(const void *source,double seconds) {
    if (![(__bridge id)source isKindOfClass:DEAppEventSource.class])
        DEUnsupported("suppression interval foreign source");
    fprintf(stderr,"DE_EVENT_SOURCE_SUPPRESSION seconds=%g\n",seconds);
    // UIKit delivers app input without synthetic-event suppression. Zero
    // requests precisely that behavior; nonzero suppression needs a real filter.
    if (seconds!=0) DEUnsupported("nonzero local event suppression");
}
const void *CGEventCreate(const void *source) {
    if (!getenv("AGEPAD_POINTER_STATE")) DEUnsupported("CGEvent source not supported");
    if (source && ![(__bridge id)source isKindOfClass:DEAppEventSource.class])
        DEUnsupported("CGEvent foreign source");
    if (source && [(__bridge DEAppEventSource *)source stateID] == -1)
        DEUnsupported("CGEvent private source snapshot not implemented");
    CGPoint point=DEUIKitPointerPosition();
    NSDictionary *snapshot=@{@"DEPointerSnapshot":@YES,@"x":@(point.x),@"y":@(point.y)};
    if (!getenv("AGEPAD_QUIET_RENDER_TRACE")) fprintf(stderr,"DE_POINTER_SNAPSHOT x=%g y=%g\n",point.x,point.y);
    return CFBridgingRetain(snapshot);
}
CGPoint CGEventGetLocation(const void *event) {
    id object=(__bridge id)event;
    if (![object isKindOfClass:NSDictionary.class] || ![object[@"DEPointerSnapshot"] boolValue])
        DEUnsupported("CGEvent location requires pointer snapshot");
    return CGPointMake([object[@"x"] doubleValue],[object[@"y"] doubleValue]);
}
bool CGEventSourceKeyState(int32_t source,uint16_t key) {
    if (!getenv("AGEPAD_POINTER_STATE") || (source!=0 && source!=1)) DEUnsupported("keyboard source state");
    static bool (*virtualHeld)(uint16_t);
    if (!virtualHeld) virtualHeld=dlsym(RTLD_DEFAULT,"DEVirtualKeyIsHeld");
    if (virtualHeld && virtualHeld(key)) return true;
    GCKeyboardInput *keyboard=GCKeyboard.coalescedKeyboard.keyboardInput;
    if(getenv("AGEPAD_KEY_DELIVERY_TRACE"))fprintf(stderr,"DE_KEY_STATE source=%d mac_key=%u hardware_keyboard=%d\n",source,key,keyboard!=nil);
    if (!keyboard) return false;
    NSInteger code=DEHardwareUsageForMac(key);
    if(code<0)DEUnsupported("unmapped Mac virtual keyboard code");
    GCDeviceButtonInput *button=[keyboard buttonForKeyCode:code];
    return button.isPressed;
}

extern void DEUIKitSetPointerPosition(CGPoint point);
int32_t CGWarpMouseCursorPosition(CGPoint point) {
    if (!isfinite(point.x) || !isfinite(point.y)) return 1001; // illegal argument
    DEUIKitSetPointerPosition(point);
    return 0;
}
