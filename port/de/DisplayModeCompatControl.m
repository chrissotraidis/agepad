#import <UIKit/UIKit.h>
#include "ScreenCompat.m"
#include "DisplayModeCompat.m"
int main(void) {
    @autoreleasepool {
        UIScreen *screen=UIScreen.mainScreen;
        const void *mode=CGDisplayCopyDisplayMode(DEUIKitDisplayIdentifier(screen));
        BOOL dimensions=mode && CGDisplayModeGetWidth(mode)==(size_t)screen.bounds.size.width
            && CGDisplayModeGetHeight(mode)==(size_t)screen.bounds.size.height;
        BOOL absent=CGDisplayCopyDisplayMode(UINT32_MAX)==NULL && CGDisplayModeGetWidth(NULL)==0 && CGDisplayModeGetHeight(NULL)==0;
        if (mode) CFRetain(mode);
        CGDisplayModeRelease(mode);
        BOOL retained=mode && CGDisplayModeGetWidth(mode)==(size_t)screen.bounds.size.width;
        CGDisplayModeRelease(mode);CGDisplayModeRelease(NULL);
        CFArrayRef modes=CGDisplayCopyAllDisplayModes(DEUIKitDisplayIdentifier(screen),NULL);
        BOOL enumerated=modes && CFArrayGetCount(modes)==1;
        if (enumerated) {
            const void *entry=CFArrayGetValueAtIndex(modes,0);
            enumerated=CGDisplayModeGetWidth(entry)==(size_t)screen.bounds.size.width && CGDisplayModeGetIOFlags(entry)==3;
        }
        if (modes) CFRelease(modes);
        printf("{\"current_mode_enumeration_and_flags\":%s}\n",enumerated?"true":"false");
        printf("{\"dimensions_match_uikit\":%s,\"invalid_and_null_handled\":%s,\"retained_snapshot_survives_release\":%s}\n",dimensions?"true":"false",absent?"true":"false",retained?"true":"false");
        return dimensions && absent && retained && enumerated?0:1;
    }
}
