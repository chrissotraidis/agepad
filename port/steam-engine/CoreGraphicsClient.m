#include "AppPresence.h"
#import <CoreGraphics/CoreGraphics.h>
// Steam engine client questions about input idle time and displays, answered
// from this iPad (one built-in screen). The macOS types are plain integers:
// CGEventSourceStateID int32_t, CGEventType uint32_t, CGDirectDisplayID uint32_t.
typedef uint32_t AgePadDisplayID;
CFTimeInterval CGEventSourceSecondsSinceLastEventType(int32_t state,uint32_t type) {
    (void)state;(void)type;
    return atomic_load(&AgePadAppActive)?0:NSProcessInfo.processInfo.systemUptime-atomic_load(&AgePadInactiveSince);
}
AgePadDisplayID CGMainDisplayID(void) { return 1; }
CGError CGGetActiveDisplayList(uint32_t max,AgePadDisplayID *displays,uint32_t *count) {
    if (displays && max>0) displays[0]=1;
    if (count) *count=displays?(max>0?1:0):1;
    return kCGErrorSuccess;
}
static CGSize AgePadScreenPixels(void) {
    CGSize size=UIScreen.mainScreen.nativeBounds.size; // portrait pixels
    return CGSizeMake(MAX(size.width,size.height),MIN(size.width,size.height)); // the game runs landscape
}
size_t CGDisplayPixelsWide(AgePadDisplayID display) { return display==1?(size_t)AgePadScreenPixels().width:0; }
size_t CGDisplayPixelsHigh(AgePadDisplayID display) { return display==1?(size_t)AgePadScreenPixels().height:0; }
