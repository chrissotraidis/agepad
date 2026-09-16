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
