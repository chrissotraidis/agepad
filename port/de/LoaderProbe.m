#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>

@interface DEProbeViewController : UIViewController
@property(nonatomic) CGSize lastLayoutSize;
@end
@implementation DEProbeViewController
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIWindowScene *scene=self.view.window.windowScene;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [self setNeedsUpdateOfSupportedInterfaceOrientations];
    if (@available(iOS 16.0,*)) {
        UIWindowSceneGeometryPreferencesIOS *preferences=
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
        [scene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
            fprintf(stderr,"DE_UIKIT_LANDSCAPE_REQUEST_FAILED %s\n",error.localizedDescription.UTF8String);
        }];
        fprintf(stderr,"DE_UIKIT_LANDSCAPE_REQUESTED scene=%p\n",scene);
    }
    // The translated engine is a legacy UIApplication host rather than a
    // scene-delegate app. On the Simulator, the public geometry request can
    // be accepted without rotating the legacy device orientation.
    UIDeviceOrientation deviceOrientation=UIDevice.currentDevice.orientation;
    if (deviceOrientation==UIDeviceOrientationPortrait ||
        deviceOrientation==UIDeviceOrientationPortraitUpsideDown ||
        deviceOrientation==UIDeviceOrientationFaceUp ||
        deviceOrientation==UIDeviceOrientationFaceDown) {
        [UIDevice.currentDevice setValue:@(UIDeviceOrientationLandscapeRight) forKey:@"orientation"];
        fprintf(stderr,"DE_UIKIT_LEGACY_LANDSCAPE_HANDOFF orientation=landscape-right\n");
    }
    [UIViewController attemptRotationToDeviceOrientation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
        [UIViewController attemptRotationToDeviceOrientation];
        UIWindowScene *nextScene=self.view.window.windowScene;
        if (@available(iOS 16.0,*)) {
            UIWindowSceneGeometryPreferencesIOS *nextPreferences=
                [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
            [nextScene requestGeometryUpdateWithPreferences:nextPreferences errorHandler:^(NSError *error) {
                fprintf(stderr,"DE_UIKIT_LANDSCAPE_RETRY_FAILED %s\n",error.localizedDescription.UTF8String);
            }];
            fprintf(stderr,"DE_UIKIT_LANDSCAPE_RETRY_REQUESTED scene=%p\n",nextScene);
        }
    });
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size=self.view.bounds.size;
    if (!CGSizeEqualToSize(self.lastLayoutSize,CGSizeZero) && !CGSizeEqualToSize(self.lastLayoutSize,size) && self.view.window.screen)
        [NSNotificationCenter.defaultCenter postNotificationName:@"DEUIKitDisplayGeometryDidChange" object:self.view.window.screen];
    self.lastLayoutSize=size;
}
@end

@interface DEProbeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end

@implementation DEProbeDelegate
- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [DEProbeViewController new];
    self.window.rootViewController = vc;
    self.window.backgroundColor = UIColor.blackColor;
    vc.view.backgroundColor = UIColor.blackColor;
    UITextView *text = [[UITextView alloc] initWithFrame:vc.view.bounds];
    text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    text.editable = NO;
    text.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
    text.hidden = YES;
    [vc.view addSubview:text];
    [self.window makeKeyAndVisible];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"simulator"] = @(TARGET_OS_SIMULATOR);
    result[@"os"] = NSProcessInfo.processInfo.operatingSystemVersionString;
    result[@"pid"] = @(NSProcessInfo.processInfo.processIdentifier);
    result[@"claim"] = @"Loader and shader feasibility only; no game execution or FPS claim";
    NSString *root = NSBundle.mainBundle.bundlePath;
    NSDictionary *boundaryConfig=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"BoundaryDiagnostic.json"]] ?: [NSData data] options:0 error:NULL];
    BOOL engineIsMain=[boundaryConfig[@"engine_is_main_executable"] boolValue];
    result[@"engine_is_main_executable"]=@(engineIsMain);
    if ([NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"BoundaryDiagnostic.json"]]) {
        result[@"claim"]=@"Fail-fast dependency diagnostic. Missing APIs abort; NULL data exports are not implementations. No gameplay/FPS/multiplayer claim.";
        result[@"boundary_diagnostic"]=@YES;
    }
    // The original-engine executable owns the real launch path. Do not make
    // it wait for the probe's synchronous Metal feasibility survey before the
    // engine receives UIKit control; that XPC call can block the launch scene.
    id<MTLDevice> gpu = engineIsMain ? nil : MTLCreateSystemDefaultDevice();
    result[@"gpu"] = gpu.name ?: (engineIsMain ? @"deferred-to-original-engine" : @"unavailable");
    NSError *error = nil;
    NSString *shaderName = [NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:@"feral-retargeted.metallib"]] ? @"feral-retargeted.metallib" : @"feral.metallib";
    result[@"shader_file"]=shaderName;
    id<MTLLibrary> lib = nil;
    if (!engineIsMain) {
        lib = [gpu newLibraryWithURL:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:shaderName]] error:&error];
        result[@"shader"] = lib ? @{@"loaded":@YES,@"functions":lib.functionNames} : @{@"loaded":@NO,@"error":error.description ?: @"unknown"};
    } else {
        result[@"shader"] = @{@"loaded":@NO,@"error":@"deferred until original engine launch"};
    }
    if (lib) {
        id<MTLFunction> function = [lib newFunctionWithName:@"BufferToBufferComputeFill"];
        MTLComputePipelineReflection *reflection = nil;
        NSError *pipelineError = nil;
        id<MTLComputePipelineState> pipeline = [gpu newComputePipelineStateWithFunction:function options:MTLPipelineOptionArgumentInfo|MTLPipelineOptionBufferTypeInfo reflection:&reflection error:&pipelineError];
        NSMutableArray *arguments = [NSMutableArray array];
        for (MTLArgument *argument in reflection.arguments) {
            NSMutableDictionary *entry = [@{@"name":argument.name,@"index":@(argument.index),@"type":@(argument.type),@"access":@(argument.access)} mutableCopy];
            if (argument.type==MTLArgumentTypeBuffer) {
                entry[@"data_size"]=@(argument.bufferDataSize);
                entry[@"data_type"]=@(argument.bufferDataType);
                NSMutableArray *members=[NSMutableArray array];
                for (MTLStructMember *member in argument.bufferStructType.members)
                    [members addObject:@{@"name":member.name,@"offset":@(member.offset),@"type":@(member.dataType)}];
                entry[@"members"]=members;
            }
            [arguments addObject:entry];
        }
        result[@"original_compute_pipeline"]=@{@"compiled":@(pipeline!=nil),@"error":pipelineError.description ?: @"",@"arguments":arguments};
        NSError *copyError=nil;
        id<MTLComputePipelineState> copyPipeline=[gpu newComputePipelineStateWithFunction:[lib newFunctionWithName:@"FERAL_ComputeCopy"] error:&copyError];
        NSMutableArray *copyCases=[NSMutableArray array];
        if (copyPipeline) {
            id<MTLCommandQueue> queue=[gpu newCommandQueue];
            for (NSNumber *count in @[@1,@63,@64,@65,@4096]) {
                NSUInteger length=count.unsignedIntegerValue;
                id<MTLBuffer> source=[gpu newBufferWithLength:length+32 options:MTLResourceStorageModeShared];
                id<MTLBuffer> dest=[gpu newBufferWithLength:length+32 options:MTLResourceStorageModeShared];
                for (NSUInteger i=0;i<length+32;i++) ((uint8_t *)source.contents)[i]=(uint8_t)(i*37+11);
                memset(dest.contents,0xcd,length+32);
                id<MTLCommandBuffer> command=[queue commandBuffer];
                id<MTLComputeCommandEncoder> encoder=[command computeCommandEncoder];
                [encoder setComputePipelineState:copyPipeline];
                [encoder setBuffer:source offset:16 atIndex:0];
                [encoder setBuffer:dest offset:16 atIndex:1];
                [encoder dispatchThreads:MTLSizeMake(length,1,1) threadsPerThreadgroup:MTLSizeMake(MIN((NSUInteger)64,copyPipeline.maxTotalThreadsPerThreadgroup),1,1)];
                [encoder endEncoding];
                [command commit];
                [command waitUntilCompleted];
                BOOL same=memcmp((uint8_t *)source.contents+16,(uint8_t *)dest.contents+16,length)==0;
                BOOL guards=YES;
                for (NSUInteger i=0;i<16;i++) guards &= ((uint8_t *)dest.contents)[i]==0xcd && ((uint8_t *)dest.contents)[16+length+i]==0xcd;
                [copyCases addObject:@{@"bytes":count,@"equal":@(same),@"guards":@(guards),@"status":@(command.status),@"error":command.error.description ?: @""}];
            }
        }
        result[@"original_copy_kernel"]=@{@"compiled":@(copyPipeline!=nil),@"error":copyError.description ?: @"",@"cases":copyCases};
    }
    NSString *importsPath = [root stringByAppendingPathComponent:@"Imports.json"];
    NSData *importsData = [NSData dataWithContentsOfFile:importsPath];
    if (importsData) {
        NSArray *imports = [NSJSONSerialization JSONObjectWithData:importsData options:0 error:nil];
        NSMutableArray *survey = [NSMutableArray array];
        for (NSDictionary *item in imports) {
            NSString *path = item[@"path"];
            void *framework = dlopen(path.fileSystemRepresentation, RTLD_LAZY | RTLD_LOCAL);
            const char *loadError = framework ? NULL : dlerror();
            NSMutableDictionary *entry = [@{@"path":path,@"loaded":@(framework!=NULL)} mutableCopy];
            if (loadError) entry[@"error"] = @(loadError);
            NSMutableArray *missing = [NSMutableArray array];
            for (NSString *symbol in item[@"symbols"]) {
                NSString *name = [symbol hasPrefix:@"_"] ? [symbol substringFromIndex:1] : symbol;
                if (!framework || !dlsym(framework,name.UTF8String)) [missing addObject:symbol];
            }
            entry[@"missing_symbols"] = missing;
            entry[@"import_count"] = @([item[@"symbols"] count]);
            [survey addObject:entry];
        }
        result[@"platform_survey"] = survey;
    }
    NSString *raw = [root stringByAppendingPathComponent:@"OriginalEngine"];
    void *handle = dlopen(raw.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    const char *err = handle ? NULL : dlerror();
    result[@"original_load"] = @{@"loaded":@(handle != NULL),@"error":err ? @(err) : @""};
    NSString *adapted = [root stringByAppendingPathComponent:@"Engine.dylib"];
    if (engineIsMain) {
        adapted=NSBundle.mainBundle.executablePath;
        result[@"adapted_load"]=@{@"loaded":@YES,@"error":@"",@"mode":@"original process executable"};
        unsigned int count=0;
        const char **classes=objc_copyClassNamesForImage(adapted.fileSystemRepresentation,&count);
        result[@"original_class_count"]=@(count); free(classes);
    } else if ([NSFileManager.defaultManager fileExistsAtPath:adapted]) {
        NSString *checkpoint = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"before-engine-load.json"];
        [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:checkpoint atomically:YES];
        fprintf(stderr,"DE_ADAPTED_LOAD_BEGIN\n"); fflush(stderr);
        void *adaptedHandle = dlopen(adapted.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
        const char *adaptedErr = adaptedHandle ? NULL : dlerror();
        result[@"adapted_load"] = @{@"loaded":@(adaptedHandle != NULL),@"error":adaptedErr ? @(adaptedErr) : @""};
        if (adaptedHandle) {
            unsigned int count=0;
            const char **classes=objc_copyClassNamesForImage(adapted.fileSystemRepresentation,&count);
            result[@"original_class_count"]=@(count);
            free(classes);
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    text.text = [@"DE ORIGINAL-ENGINE FEASIBILITY PROBE\n\n" stringByAppendingString:json];
    NSLog(@"DE_PROBE_RESULT %@", json);
    NSString *output = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"result.json"];
    [data writeToFile:output atomically:YES];
    if (([NSProcessInfo.processInfo.arguments containsObject:@"--invoke-original-launch"] ||
         [NSProcessInfo.processInfo.arguments containsObject:@"--run-original"] || engineIsMain) &&
        [result[@"adapted_load"][@"loaded"] boolValue]) {
        void *appkit=dlopen([[root stringByAppendingPathComponent:@"DEBoundary_AppKit.dylib"] fileSystemRepresentation],RTLD_NOW|RTLD_LOCAL);
        void (*launch)(void)=appkit?dlsym(appkit,"DEInvokeOriginalLaunchAfterUIKitReady"):NULL;
        if (launch) dispatch_async(dispatch_get_main_queue(),^{ launch(); });
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--invoke-engine-entry"] &&
        [result[@"adapted_load"][@"loaded"] boolValue]) {
        NSDictionary *entry = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"EngineEntry.json"]] options:0 error:NULL];
        uintptr_t header=0;
        for (uint32_t i=0;i<_dyld_image_count();i++)
            if ([adapted isEqualToString:@(_dyld_get_image_name(i))]) header=(uintptr_t)_dyld_get_image_header(i);
        if (header && entry[@"file_offset"]) {
            uintptr_t address=header+[entry[@"file_offset"] unsignedLongLongValue];
            dispatch_async(dispatch_get_main_queue(),^{
                fprintf(stderr,"DE_ORIGINAL_ENTRY_BEGIN offset=%llu\n",[entry[@"file_offset"] unsignedLongLongValue]);
                fflush(stderr);
                int (*gameMain)(int,char **)=(void *)address;
                char *argv[]={(char *)adapted.fileSystemRepresentation,NULL};
                int code=gameMain(1,argv);
                fprintf(stderr,"DE_ORIGINAL_ENTRY_RETURN %d\n",code); fflush(stderr);
            });
        }
    }
    return YES;
}
@end

#if !DE_EMBEDDED_DELEGATE
int main(int argc,char **argv) {
    @autoreleasepool {
        if ([NSFileManager.defaultManager fileExistsAtPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"BoundaryBuildIncomplete"]]) {
            fprintf(stderr,"DE_INCOMPLETE_BUILD_REFUSED\n");
            return 78;
        }
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--run-original"]) {
            NSString *root=NSBundle.mainBundle.bundlePath;
            NSString *engine=[root stringByAppendingPathComponent:@"Engine.dylib"];
            fprintf(stderr,"DE_ORIGINAL_PROCESS_ENTRY_LOAD_BEGIN\n"); fflush(stderr);
            if (!dlopen(engine.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL)) {
                fprintf(stderr,"DE_ORIGINAL_PROCESS_ENTRY_LOAD_ERROR %s\n",dlerror());
                return 69;
            }
            NSDictionary *entry=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"EngineEntry.json"]] options:0 error:NULL];
            uintptr_t header=0;
            for (uint32_t i=0;i<_dyld_image_count();i++)
                if ([engine isEqualToString:@(_dyld_get_image_name(i))]) header=(uintptr_t)_dyld_get_image_header(i);
            if (!header || !entry[@"file_offset"]) return 70;
            fprintf(stderr,"DE_ORIGINAL_PROCESS_ENTRY_BEGIN\n"); fflush(stderr);
            int (*gameMain)(int,char **)=(void *)(header+[entry[@"file_offset"] unsignedLongLongValue]);
            char *gameArgv[]={(char *)engine.fileSystemRepresentation,NULL};
            return gameMain(1,gameArgv);
        }
        return UIApplicationMain(argc,argv,nil,NSStringFromClass(DEProbeDelegate.class));
    }
}
#endif
