// First real application-state adapter. Launch/nib/event-loop support is still
// incomplete and explicitly stops. This never reports a successful game launch.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include "UnsupportedBoundary.h"
#include <dlfcn.h>
#include <stdatomic.h>
#include "ContextDispatchTrace.h"
#include <mach-o/dyld.h>
// Launch options for Home Screen launches, like Steam's per-game "launch
// options" (AGEPAD_GAME_ARGUMENTS, e.g. "SKIPINTRO", which the game itself
// documents as "Skip the intro movies"). A Home Screen launch has no command
// line, and the game's main() has already copied argv into Feral's own list
// by now, so that same copy routine is run again with the extra words. The
// two routines are pinned to the imported build; unless their instructions
// match exactly, nothing is called and the game starts unchanged.
static void DEAddGameArguments(int argc,const char **argv) {
    const char *extra=getenv("AGEPAD_GAME_ARGUMENTS");
    if (!extra || !*extra) return;
    static const uint32_t getterCode[]={0xf0029088,0x910be108,0x38bfc108,0x36000088};
    static const uint32_t copyCode[]={0xd101c3ff,0xa90457f6,0xa9054ff4,0xa9067bfd,0x910183fd,0xaa0203f4,0xaa0103f5,0xaa0003f3};
    uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
    const uint32_t *getter=(const uint32_t *)(base+0x94210),*copy=(const uint32_t *)(base+0x93278);
    if (memcmp(getter,getterCode,sizeof getterCode) || memcmp(copy,copyCode,sizeof copyCode)) {
        fprintf(stderr,"DE_GAME_ARGUMENTS skipped=build-mismatch\n");return;
    }
    static const char *combined[64];
    int count=0;
    for (int i=0;i<argc && count<48;i++) combined[count++]=argv[i];
    static char words[512];
    strlcpy(words,extra,sizeof words);
    for (char *save=NULL,*word=strtok_r(words," ",&save);word && count<63;word=strtok_r(NULL," ",&save)) {
        BOOL present=NO;
        for (int i=1;i<argc;i++) if (strcmp(argv[i],word)==0) present=YES;
        if (!present) combined[count++]=word;
    }
    combined[count]=NULL;
    void *(*commandLine)(void)=(void *(*)(void))getter;
    void (*setArguments)(void *,int,const char **)=(void (*)(void *,int,const char **))copy;
    setArguments(commandLine(),count,combined);
    fprintf(stderr,"DE_GAME_ARGUMENTS applied=%s count=%d\n",extra,count);fflush(stderr);
}
#include "EventQueueCompat.m"
#include "TouchPointerCompat.m"
extern void DEInstallNativeViewCompatibility(void) __attribute__((weak_import));
extern void DEUpdateVisibleGameWindows(void);

@interface NSApplication : UIResponder
@property(nonatomic,weak) id delegate;
@property(nonatomic,strong) NSMutableArray *lifecycleObservers;
@property(nonatomic,strong) DEEventQueue *eventQueue;
@property(nonatomic,strong) id deMainMenu;
@property(nonatomic) NSUInteger dePresentationOptions;
+ (instancetype)sharedApplication;
- (BOOL)isActive;
- (BOOL)isHidden;
- (id)dockTile;
@end

NSApplication *NSApp;
static atomic_bool DEApplicationLoopRunning;

@protocol DEOriginalLaunchDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
@end

@implementation NSApplication
+ (instancetype)sharedApplication {
    if (!NSApp) NSApp=[[self alloc] init];
    return (id)NSApp;
}
- (instancetype)init {
    if ((self=[super init])) {
        NSApp=self;
        self.lifecycleObservers=[NSMutableArray array];
        self.eventQueue=[DEEventQueue new];
        __weak NSApplication *weakSelf=self;
        NSArray *transitions=@[
            @[UIApplicationDidBecomeActiveNotification,@"NSApplicationDidBecomeActiveNotification",@"applicationDidBecomeActive:"],
            @[UIApplicationWillResignActiveNotification,@"NSApplicationWillResignActiveNotification",@"applicationDidResignActive:"]];
        for (NSArray *transition in transitions) {
            id token=[NSNotificationCenter.defaultCenter addObserverForName:transition[0] object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                NSApplication *application=weakSelf;
                if (!application) return;
                NSNotification *mapped=[NSNotification notificationWithName:transition[1] object:application];
                [NSNotificationCenter.defaultCenter postNotification:mapped];
                SEL selector=NSSelectorFromString(transition[2]);
                id delegate=application.delegate;
                if ([delegate respondsToSelector:selector]) {
                    void (*call)(id,SEL,id)=(void *)[delegate methodForSelector:selector];
                    call(delegate,selector,mapped);
                }
            }];
            [self.lifecycleObservers addObject:token];
        }
    }
    return self;
}
- (BOOL)isActive { return UIApplication.sharedApplication.applicationState==UIApplicationStateActive; }
- (BOOL)isHidden { return UIApplication.sharedApplication.applicationState==UIApplicationStateBackground; }
- (BOOL)isRunning { return atomic_load(&DEApplicationLoopRunning); }
- (void)activateIgnoringOtherApps:(BOOL)ignore {
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)
        DEUnsupported("application activation requires active UIKit scene");
    // The app is already foreground-active; no desktop app switching needed.
    fprintf(stderr,"DE_APPLICATION_ACTIVATION already UIKit-active\n");
}
- (id)mainMenu {
    // No desktop menu bar has been installed in this UIKit application.
    if (!self.deMainMenu) fprintf(stderr,"DE_UNAVAILABLE_OPTIONAL_UI main menu bar\n");
    return self.deMainMenu;
}
- (void)setMainMenu:(id)menu { self.deMainMenu=menu; }
- (void)setPresentationOptions:(NSUInteger)options {
    fprintf(stderr,"DE_APPLICATION_PRESENTATION requested=%lu\n",(unsigned long)options);
    // These options govern desktop Dock/menu/toolbar chrome, absent in this
    // UIKit host. Window full-screen sizing is implemented by NSWindow.
    // Never pretend UIKit can disable switching, force-quit, or logout.
    const NSUInteger desktopChrome=0x1f | (1UL<<8) | (1UL<<9) | (1UL<<10) | (1UL<<11) | (1UL<<12);
    if (!NSThread.isMainThread || (options & ~desktopChrome)) DEUnsupported("unsupported UIKit application presentation restrictions");
    self.dePresentationOptions=options;
}
- (NSUInteger)presentationOptions { return self.dePresentationOptions; }
- (id)nextEventMatchingMask:(NSUInteger)mask untilDate:(NSDate *)date inMode:(NSString *)mode dequeue:(BOOL)dequeue {
    if (getenv("AGEPAD_EVENT_QUEUE")) return [self.eventQueue next:mask until:date mode:mode dequeue:dequeue];
    fprintf(stderr,"DE_EVENT_POLL mask=%llx timeout=%g mode=%s dequeue=%d\n",
        (unsigned long long)mask,date?[date timeIntervalSinceNow]:0,mode.UTF8String ?: "(null)",dequeue);
    DEUnsupported("NSApplication event queue needs UIKit integration");
}
- (void)postEvent:(id<DEQueuedEvent>)event atStart:(BOOL)atStart {
    if (!getenv("AGEPAD_EVENT_QUEUE")) DEUnsupported("NSApplication postEvent");
    [self.eventQueue post:event atStart:atStart];
}
- (void)sendEvent:(id)event {
 if(!NSThread.isMainThread || !event)DEUnsupported("application input dispatch requires main thread and event");
 id window=((id(*)(id,SEL))objc_msgSend)(event,sel_registerName("window"));
 fprintf(stderr,"DE_APPLICATION_SEND_EVENT event=%s window=%s\n",object_getClassName(event),object_getClassName(window));
 if(!window)DEUnsupported("input event has no original window");
 ((void(*)(id,SEL,id))objc_msgSend)(window,sel_registerName("sendEvent:"),event);
}
- (void)updateWindows {
 if(!NSThread.isMainThread)DEUnsupported("window updates require main thread");
 [NSNotificationCenter.defaultCenter postNotificationName:@"NSApplicationWillUpdateNotification" object:self];
 DEUpdateVisibleGameWindows();
 [NSNotificationCenter.defaultCenter postNotificationName:@"NSApplicationDidUpdateNotification" object:self];
}
- (id)dockTile {
    // Desktop Dock tile customization has no UIKit counterpart. Expose its
    // absence explicitly; this is optional desktop chrome, not game rendering.
    fprintf(stderr,"DE_UNAVAILABLE_OPTIONAL_UI desktop Dock tile\n");
    return nil;
}
+ (BOOL)resolveClassMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSApplication %s]\n",sel_getName(sel));
    DEUnsupported("NSApplication");
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSApplication %s]\n",sel_getName(sel));
    DEUnsupported("NSApplication");
}
@end

@interface NSWorkspace : NSObject
@property(nonatomic,strong,readonly) NSNotificationCenter *notificationCenter;
+ (instancetype)sharedWorkspace;
@end
@implementation NSWorkspace
+ (instancetype)sharedWorkspace {
    static NSWorkspace *workspace;
    static dispatch_once_t once;
    dispatch_once(&once,^{ workspace=[self new]; });
    return workspace;
}
- (instancetype)init {
    if ((self=[super init])) _notificationCenter=[NSNotificationCenter new];
    return self;
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSWorkspace %s]\n",sel_getName(sel));
    DEUnsupported("NSWorkspace");
}
@end

@interface NSRunningApplication : NSObject
+ (NSArray *)runningApplicationsWithBundleIdentifier:(NSString *)identifier;
+ (instancetype)currentApplication;
@end
@implementation NSRunningApplication
+ (instancetype)currentApplication {
    static NSRunningApplication *application;
    static dispatch_once_t once;
    dispatch_once(&once,^{ application=[self new]; });
    return application;
}
+ (NSArray *)runningApplicationsWithBundleIdentifier:(NSString *)identifier {
    fprintf(stderr,"DE_RUNNING_APPLICATION_QUERY %s\n",identifier.UTF8String ?: "(null)");
    DETraceContextDispatch();
    // UIKit launches one application process for this installed bundle. Only
    // the current app is represented; no other-app/service presence is invented.
    if ([identifier isEqualToString:NSBundle.mainBundle.bundleIdentifier]) return @[self.currentApplication];
    DEUnsupported("NSRunningApplication enumeration outside current application unavailable");
}
- (pid_t)processIdentifier { return getpid(); }
- (NSString *)bundleIdentifier { return NSBundle.mainBundle.bundleIdentifier; }
- (NSURL *)bundleURL { return NSBundle.mainBundle.bundleURL; }
- (NSURL *)executableURL { return NSBundle.mainBundle.executableURL; }
- (BOOL)isTerminated { return NO; } // This object represents the executing process.
- (BOOL)isActive { return UIApplication.sharedApplication.applicationState==UIApplicationStateActive; }
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSRunningApplication %s]\n",sel_getName(sel));
    DEUnsupported("NSRunningApplication");
}
@end

static NSApplication *DECreateOriginalApplication(void) {
    fprintf(stderr,"DE_APPLICATION_BOOTSTRAP_BEGIN\n"); fflush(stderr);
    NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"BoundaryDiagnostic.json"];
    NSDictionary *config=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:NULL];
    Class principal=NSClassFromString(config[@"principal_class"] ?: @"");
    if (!principal || ![principal isSubclassOfClass:NSApplication.class])
        DEUnsupported("Original principal application class missing");
    NSApplication *application=[principal sharedApplication];
    fprintf(stderr,"DE_ORIGINAL_APPLICATION_CREATED %s\n",class_getName(application.class)); fflush(stderr);
    return application;
}

void DEInvokeOriginalLaunchAfterUIKitReady(void) {
    if (DEInstallNativeViewCompatibility) DEInstallNativeViewCompatibility();
    DEInstallTouchPointer();
    NSApplication *application=DECreateOriginalApplication();
    // Verified by native NSNib instantiation for this supplied build. Menu
    // objects are still unimplemented and their use stops at a diagnostic API.
    application.delegate=application;
    BOOL launchNotifications=getenv("AGEPAD_MAC_LAUNCH_NOTIFICATIONS") != NULL;
    if (launchNotifications) {
        NSNotification *will=[NSNotification notificationWithName:@"NSApplicationWillFinishLaunchingNotification" object:application];
        SEL selector=NSSelectorFromString(@"applicationWillFinishLaunching:");
        // Optional delegate lookup must not invoke our diagnostic resolver:
        // respondsToSelector: can otherwise trap on an absent optional method.
        IMP implementation=NULL;
        for (Class cls=object_getClass(application.delegate); cls && !implementation; cls=class_getSuperclass(cls)) {
            unsigned count=0;
            Method *methods=class_copyMethodList(cls,&count);
            for (unsigned i=0; i<count; ++i) {
                if (sel_isEqual(method_getName(methods[i]),selector)) {
                    implementation=method_getImplementation(methods[i]);
                    break;
                }
            }
            free(methods);
        }
        if (implementation) {
            void (*call)(id,SEL,id)=(void *)implementation;
            call(application.delegate,selector,will);
        }
        [NSNotificationCenter.defaultCenter postNotification:will];
        fprintf(stderr,"DE_LAUNCH_NOTIFICATION will posted\n"); fflush(stderr);
    }
    fprintf(stderr,"DE_ORIGINAL_LAUNCH_CALLBACK_BEGIN\n"); fflush(stderr);
    [(id<DEOriginalLaunchDelegate>)application.delegate applicationDidFinishLaunching:
        [NSNotification notificationWithName:@"NSApplicationDidFinishLaunchingNotification" object:application]];
    fprintf(stderr,"DE_ORIGINAL_LAUNCH_CALLBACK_RETURN\n"); fflush(stderr);
    if (launchNotifications) {
        [NSNotificationCenter.defaultCenter postNotificationName:@"NSApplicationDidFinishLaunchingNotification" object:application];
        fprintf(stderr,"DE_LAUNCH_NOTIFICATION did posted\n"); fflush(stderr);
    }
}

int NSApplicationMain(int argc,const char **argv) {
    DEAddGameArguments(argc,argv);
    NSApplication *application=DECreateOriginalApplication();
    NSDictionary *config=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"BoundaryDiagnostic.json"]] options:0 error:NULL];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--run-original"] || [config[@"engine_is_main_executable"] boolValue]) {
        application.delegate=application;
        fprintf(stderr,"DE_ORIGINAL_ENTRY_HANDOFF_TO_UIKIT\n"); fflush(stderr);
        atomic_store(&DEApplicationLoopRunning,true);
        int result=UIApplicationMain(argc,(char **)argv,nil,@"DEProbeDelegate");
        atomic_store(&DEApplicationLoopRunning,false);
        return result;
    }
    DEUnsupported("NSApplicationMain: launch nib and UIKit lifecycle integration incomplete");
}
