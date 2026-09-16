#import <AppKit/AppKit.h>
static BOOL didFinish;

@interface LaunchProbeDelegate : NSObject <NSApplicationDelegate>
@end
@implementation LaunchProbeDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)note {
    fprintf(stderr, "HOST_LAUNCH delegate will object_is_app=%d\n", note.object == NSApp);
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    didFinish = YES;
    fprintf(stderr, "HOST_LAUNCH delegate did object_is_app=%d\n", note.object == NSApp);
}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyProhibited];
        LaunchProbeDelegate *delegate = [LaunchProbeDelegate new];
        app.delegate = delegate;
        NSMutableArray *tokens = [NSMutableArray new];
        for (NSString *name in @[NSApplicationWillFinishLaunchingNotification,
                                  NSApplicationDidFinishLaunchingNotification]) {
            [tokens addObject:[NSNotificationCenter.defaultCenter
                addObserverForName:name object:app queue:nil usingBlock:^(NSNotification *note) {
                    fprintf(stderr, "HOST_LAUNCH observer %s object_is_app=%d\n",
                            note.name.UTF8String, note.object == NSApp);
                }]];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [app stop:nil];
            [app postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
                location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0
                context:nil subtype:0 data1:0 data2:0] atStart:YES];
        });
        [app run];
        fprintf(stderr, "HOST_LAUNCH run returned\n");
        fprintf(stderr, "HOST_LAUNCH did_received=%d\n", didFinish);
        for (id token in tokens) [NSNotificationCenter.defaultCenter removeObserver:token];
        app.delegate = nil;
    }
    return didFinish ? 0 : 1;
}
