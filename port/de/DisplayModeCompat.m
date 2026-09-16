// Current display geometry from UIKit. Other mode operations remain fail-fast.
#import <UIKit/UIKit.h>
#include "UnsupportedBoundary.h"
extern uint32_t DEUIKitDisplayIdentifier(UIScreen *screen);

static UIScreen *DECurrentDisplay(uint32_t display) {
    if (!getenv("AGEPAD_UIKIT_DISPLAY_MODE")) DEUnsupported("UIKit display mode");
    for (UIScreen *screen in UIScreen.screens)
        if (DEUIKitDisplayIdentifier(screen)==display) return screen;
    return nil;
}
CGRect CGDisplayBounds(uint32_t display) {
    UIScreen *screen=DECurrentDisplay(display);
    return screen?screen.bounds:CGRectZero;
}
const void *CGDisplayCopyDisplayMode(uint32_t display) {
    UIScreen *screen=DECurrentDisplay(display);
    if (!screen || !screen.currentMode) return NULL;
    // CGDisplayModeGetWidth/Height are points, not backing pixel dimensions.
    CGSize points=screen.bounds.size;
    NSDictionary *mode=@{@"DEUIKitMode":@YES,@"width":@(points.width),@"height":@(points.height),@"refreshRate":@(screen.maximumFramesPerSecond)};
    fprintf(stderr,"DE_UIKIT_DISPLAY_MODE display=%u points=%gx%g backing=%gx%g\n",
        display,points.width,points.height,screen.currentMode.size.width,screen.currentMode.size.height);
    return CFBridgingRetain(mode);
}
static NSDictionary *DEDisplayModeObject(const void *mode) {
    if (!mode) return nil;
    id object=(__bridge id)mode;
    if (![object isKindOfClass:NSDictionary.class] || ![object[@"DEUIKitMode"] boolValue])
        DEUnsupported("foreign CGDisplayMode representation");
    return object;
}
size_t CGDisplayModeGetWidth(const void *mode) { return [DEDisplayModeObject(mode)[@"width"] unsignedLongValue]; }
size_t CGDisplayModeGetHeight(const void *mode) { return [DEDisplayModeObject(mode)[@"height"] unsignedLongValue]; }
double CGDisplayModeGetRefreshRate(const void *mode) { return [DEDisplayModeObject(mode)[@"refreshRate"] doubleValue]; }
void CGDisplayModeRelease(const void *mode) {
    if (mode) { DEDisplayModeObject(mode); CFRelease(mode); }
}
uint32_t CGDisplayModeGetIOFlags(const void *mode) {
    if (!DEDisplayModeObject(mode)) return 0;
    // Policy for the existing UIKit drawing surface: usable without changing
    // physical display timing, no interlaced fields or aspect stretching.
    // This describes the adapter's presentation contract, not an IOKit query.
    fprintf(stderr,"DE_UIKIT_MODE_FLAGS current surface valid/safe; compositor policy\n");
    return 0x3; // kDisplayModeValidFlag | kDisplayModeSafeFlag (Mac SDK).
}
CFArrayRef CGDisplayCopyAllDisplayModes(uint32_t display,CFDictionaryRef options) {
    // This adapter supports rendering in the existing UIKit mode only.
    // Hardware mode switching is deliberately not advertised.
    if (options && CFDictionaryGetCount(options)) DEUnsupported("display enumeration options");
    const void *mode=CGDisplayCopyDisplayMode(display);
    if (!mode) return NULL;
    CFArrayRef modes=CFArrayCreate(NULL,&mode,1,&kCFTypeArrayCallBacks);
    CGDisplayModeRelease(mode);
    fprintf(stderr,"DE_UIKIT_MODES current supported mode only\n");
    return modes;
}
