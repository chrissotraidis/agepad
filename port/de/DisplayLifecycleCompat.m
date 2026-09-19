#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

// A single UIKit display cannot be mirrored inside this host. Returning the
// real topology fact lets the original activation path continue without
// inventing an external display or desktop mirror state.
Boolean DECGDisplayIsInMirrorSet(uint32_t display) __asm__("_CGDisplayIsInMirrorSet");
Boolean DECGDisplayIsInMirrorSet(uint32_t display) {
    (void)display;
    return false;
}
// The game enumerates online displays when it resigns active (backgrounding
// on iPad). Report the actual UIKit screens with the same identifiers the
// mode/callback bridges use, instead of aborting the deactivation path.
extern uint32_t DEUIKitDisplayIdentifier(UIScreen *screen);
int32_t DECGGetOnlineDisplayList(uint32_t maxDisplays,uint32_t *displays,uint32_t *count) __asm__("_CGGetOnlineDisplayList");
int32_t DECGGetOnlineDisplayList(uint32_t maxDisplays,uint32_t *displays,uint32_t *count) {
    uint32_t found=0;
    for (UIScreen *screen in UIScreen.screens) {
        if (displays && found<maxDisplays) displays[found]=DEUIKitDisplayIdentifier(screen);
        found++;
    }
    if (count) *count=displays?MIN(found,maxDisplays):found;
    fprintf(stderr,"DE_ONLINE_DISPLAY_LIST count=%u max=%u\n",found,maxDisplays);
    return 0;
}
