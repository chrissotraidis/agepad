// Initial NSScreen adapter backed by real UIKit display objects.
#import <UIKit/UIKit.h>
#include "UnsupportedBoundary.h"
@interface NSScreen : NSObject
@property(nonatomic,strong) UIScreen *uiScreen;
@property(nonatomic) uint32_t displayIdentifier;
+ (NSArray<NSScreen *> *)screens;
+ (NSScreen *)mainScreen;
@end
static NSMapTable<UIScreen *,NSScreen *> *wrappers;
static NSScreen *DEWrapScreen(UIScreen *screen) {
    static dispatch_once_t once;
    dispatch_once(&once,^{ wrappers=[NSMapTable strongToStrongObjectsMapTable]; });
    static uint32_t nextIdentifier=1;
    @synchronized(wrappers) {
        NSScreen *wrapper=[wrappers objectForKey:screen];
        if (!wrapper) {
            wrapper=[NSScreen new]; wrapper.uiScreen=screen;
            wrapper.displayIdentifier=nextIdentifier++;
            [wrappers setObject:wrapper forKey:screen];
        }
        return wrapper;
    }
}
id DEUIKitScreenObject(UIScreen *screen) { return screen?DEWrapScreen(screen):nil; }
uint32_t DEUIKitDisplayIdentifier(UIScreen *screen) { return screen?DEWrapScreen(screen).displayIdentifier:0; }
@implementation NSScreen
+ (NSArray<NSScreen *> *)screens {
    NSMutableArray *result=[NSMutableArray array];
    for (UIScreen *screen in UIScreen.screens) [result addObject:DEWrapScreen(screen)];
    return result;
}
+ (NSScreen *)mainScreen { return self.screens.firstObject; }
+ (BOOL)screensHaveSeparateSpaces { return NO; } // No macOS Spaces in UIKit.
- (CGRect)frame { return self.uiScreen.bounds; }
- (CGRect)visibleFrame { return self.uiScreen.bounds; } // No desktop menu/Dock exclusion.
- (CGFloat)backingScaleFactor { return self.uiScreen.scale; }
- (NSTimeInterval)minimumRefreshInterval {
 NSInteger fps=self.uiScreen.maximumFramesPerSecond;
 if(fps<=0)DEUnsupported("UIKit screen has no maximum refresh rate");
 fprintf(stderr,"DE_SCREEN_MIN_REFRESH UIKit maximum_fps=%ld\n",(long)fps);
 return 1.0/(double)fps;
}
- (NSTimeInterval)maximumRefreshInterval {
 // The compatibility display exposes a fixed refresh cadence. UIKit provides
 // its maximum rate, but not the panel's variable-refresh lower bound. Do not
 // advertise a variable-refresh range that this adapter cannot describe.
 fprintf(stderr,"DE_SCREEN_MAX_REFRESH adapter fixed-cadence contract\n");
 return [self minimumRefreshInterval];
}
- (NSInteger)maximumFramesPerSecond { return self.uiScreen.maximumFramesPerSecond; }
- (NSDictionary *)deviceDescription { return @{@"NSScreenNumber":@(self.displayIdentifier)}; }
// UIKit exposes a rectangular safe area, not macOS's separate top-of-screen
// regions beside a camera housing. Do not advertise extra drawing regions.
- (CGRect)auxiliaryTopLeftArea {
    fprintf(stderr,"DE_SCREEN_AUXILIARY no additional UIKit top-left region\n");
    return CGRectZero;
}
- (CGRect)auxiliaryTopRightArea {
    fprintf(stderr,"DE_SCREEN_AUXILIARY no additional UIKit top-right region\n");
    return CGRectZero;
}
+ (BOOL)resolveClassMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSScreen %s]\n",sel_getName(sel));
    DEUnsupported("NSScreen");
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSScreen %s]\n",sel_getName(sel));
    DEUnsupported("NSScreen");
}
@end
