// Isolated real-SDK connectivity test. No game/service success is fabricated.
#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <unistd.h>
#include "MachDiscovery.h"
#include "CodeIdentityProbe.h"
@interface DESteamProbeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation DESteamProbeDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *view=[UIViewController new]; self.window.rootViewController=view;
    view.view.backgroundColor=UIColor.systemBackgroundColor;
    UITextView *label=[[UITextView alloc] initWithFrame:view.view.bounds];
    label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    label.editable=NO; label.font=[UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightRegular];
    [view.view addSubview:label]; [self.window makeKeyAndVisible];
    NSMutableDictionary *result=[@{@"claim":@"Real supplied Steam SDK test only; no game or multiplayer proof",
        @"simulator":@(TARGET_OS_SIMULATOR),@"pid":@(getpid()),@"app_id_hint":NSBundle.mainBundle.infoDictionary[@"DEAppID"] ?: @0} mutableCopy];
    NSString *root=NSBundle.mainBundle.bundlePath;
    result[@"mach_discovery"]=DESteamMachDiscovery();
    result[@"code_identity"]=DEProbeRealCodeIdentity();
    NSString *library=[root stringByAppendingPathComponent:@"Frameworks/libsteam_api.dylib"];
    void *handle=dlopen(library.fileSystemRepresentation,RTLD_NOW|RTLD_GLOBAL);
    result[@"library_loaded"]=@(handle!=NULL);
    if (!handle) result[@"load_error"]=@(dlerror());
    if (handle) {
        bool (*initialize)(void)=dlsym(handle,"SteamAPI_Init");
        void (*shutdown)(void)=dlsym(handle,"SteamAPI_Shutdown");
        result[@"init_export"]=@(initialize!=NULL);
        NSString *previous=NSFileManager.defaultManager.currentDirectoryPath;
        BOOL changed=[NSFileManager.defaultManager changeCurrentDirectoryPath:root];
        result[@"appid_directory_selected"]=@(changed);
        if (initialize && shutdown && changed) {
            fprintf(stderr,"DE_REAL_STEAM_INIT_BEGIN\n"); fflush(stderr);
            bool initialized=initialize();
            result[@"initialized"]=@(initialized);
            fprintf(stderr,"DE_REAL_STEAM_INIT_RESULT %d\n",initialized); fflush(stderr);
            if (initialized) shutdown();
        }
        [NSFileManager.defaultManager changeCurrentDirectoryPath:previous];
    }
    NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
    label.text=[@"DE STEAM CONNECTIVITY DIAGNOSTIC\n\n" stringByAppendingString:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    NSString *output=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"steam-result.json"];
    [json writeToFile:output atomically:YES];
    NSLog(@"DE_STEAM_RESULT %@",label.text);
    return YES;
}
@end
int main(int argc,char **argv) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(DESteamProbeDelegate.class)); }
}
