// Opt-in reduced render scale for memory-limited devices. The original
// engine sizes its drawable and render targets from the reported backing
// scale; every backing-scale answer uses this one value so input mapping and
// presentation stay consistent. Core Animation upscales the result.
#pragma once
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <stdlib.h>
static inline CGFloat DERenderScale(UIScreen *screen) {
    CGFloat native=screen.scale ?: UIScreen.mainScreen.scale;
    const char *value=getenv("AGEPAD_DEVICE_RENDER_SCALE");
    if (!value) return native;
    double requested=atof(value);
    CGFloat scale=(requested>=1.0 && requested<native)?(CGFloat)requested:native;
    static int logged;
    if (!logged) { logged=1; fprintf(stderr,"DE_RENDER_SCALE native=%g requested=%s used=%g\n",native,value,scale); }
    return scale;
}
