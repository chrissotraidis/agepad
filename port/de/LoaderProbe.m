#import <UIKit/UIKit.h>
#include <spawn.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>
#include <mach/mach.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#include <dlfcn.h>
#include <errno.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <fcntl.h>
#include <sys/stat.h>

// Opt-in, read-only main-thread watchdog for hardware runs. A main run-loop
// timer advances a heartbeat; if it stops, a background thread briefly
// suspends the main thread, walks its frame-pointer chain with checked reads,
// logs image+offset for each return address, and resumes it immediately.
static _Atomic uint64_t DEMainHeartbeat;
// Opt-in: send this process's stdout/stderr to a private container file so a
// hardware run does not depend on an attached console stream.
__attribute__((constructor)) static void DERedirectDeviceLog(void) {
    if (!getenv("AGEPAD_DEVICE_LOG_FILE")) return;
    const char *home=getenv("HOME");
    if (!home) return;
    char directory[1024],path[1100];
    snprintf(directory,sizeof(directory),"%s/Library/Caches/AgePadDiagnostics",home);
    mkdir(directory,0700);
    snprintf(path,sizeof(path),"%s/launch.log",directory);
    int fd=open(path,O_WRONLY|O_CREAT|O_TRUNC,0600);
    if (fd<0) return;
    dup2(fd,STDOUT_FILENO);dup2(fd,STDERR_FILENO);close(fd);
    setvbuf(stderr,NULL,_IONBF,0);
    fprintf(stderr,"DE_DEVICE_LOG_FILE active\n");
}
static mach_port_t DEMainThreadPort;
// Raw write(2): never waits on stdio's stderr lock, which another thread may hold.
static void DEWatchdogLog(const char *format,...) __attribute__((format(printf,1,2)));
static int DEWatchdogFD=-1;
static void DEWatchdogLog(const char *format,...) {
    char line[512];va_list arguments;va_start(arguments,format);
    int length=vsnprintf(line,sizeof(line),format,arguments);va_end(arguments);
    if (length<=0) return;
    size_t size=(size_t)length<sizeof(line)?(size_t)length:sizeof(line)-1;
    write(STDERR_FILENO,line,size);
    if (DEWatchdogFD>=0) write(DEWatchdogFD,line,size);
}
static void DELogAddress(unsigned index,uintptr_t address) {
    Dl_info info={0};
    const char *name="?";uintptr_t offset=address;
    if (dladdr((void *)address,&info) && info.dli_fname) {
        name=strrchr(info.dli_fname,'/')?strrchr(info.dli_fname,'/')+1:info.dli_fname;
        offset=address-(uintptr_t)info.dli_fbase;
    }
    DEWatchdogLog("DE_MAIN_STALL_FRAME %u %s+0x%lx %s\n",index,name,(unsigned long)offset,
            info.dli_sname?info.dli_sname:"");
}
static void DEDumpThread(mach_port_t thread,const char *label) {
    if (thread==mach_thread_self()) return;
    if (thread_suspend(thread)!=KERN_SUCCESS) return;
    arm_thread_state64_t state;mach_msg_type_number_t count=ARM_THREAD_STATE64_COUNT;
    kern_return_t status=thread_get_state(thread,ARM_THREAD_STATE64,(thread_state_t)&state,&count);
    uintptr_t pcs[40];unsigned n=0;
    if (status==KERN_SUCCESS) {
        pcs[n++]=(uintptr_t)arm_thread_state64_get_pc(state);
        pcs[n++]=(uintptr_t)arm_thread_state64_get_lr(state);
        uintptr_t fp=(uintptr_t)arm_thread_state64_get_fp(state);
        while (fp && n<40) {
            uintptr_t frame[2];vm_size_t copied=0;
            if (vm_read_overwrite(mach_task_self(),fp,sizeof(frame),(vm_address_t)frame,&copied)!=KERN_SUCCESS ||
                copied!=sizeof(frame) || frame[0]<=fp) break;
            pcs[n++]=frame[1]&0x0000000fffffffffULL;fp=frame[0];
        }
    }
    thread_resume(thread);
    char name[64]="";
    pthread_t pthread=pthread_from_mach_thread_np(thread);
    if (pthread) pthread_getname_np(pthread,name,sizeof(name));
    DEWatchdogLog("DE_THREAD_DUMP %s port=%u name=%s frames=%u\n",label,thread,name,n);
    for (unsigned i=0;i<n;i++) DELogAddress(i,pcs[i]);

}
static void DEDumpMainThread(void) { DEDumpThread(DEMainThreadPort,"main"); }
static void DEDumpAllThreads(void) {
    thread_act_array_t threads=NULL;mach_msg_type_number_t count=0;
    if (task_threads(mach_task_self(),&threads,&count)!=KERN_SUCCESS) return;
    DEWatchdogLog("DE_ALL_THREADS count=%u\n",count);
    for (mach_msg_type_number_t i=0;i<count && i<128;i++) DEDumpThread(threads[i],"any");
    for (mach_msg_type_number_t i=0;i<count;i++) mach_port_deallocate(mach_task_self(),threads[i]);
    vm_deallocate(mach_task_self(),(vm_address_t)threads,count*sizeof(*threads));
}
static void *DEMainWatchdogLoop(void *unused);
static void DEDumpAllThreads(void);
// The Steam fatal-assert path leaves through exit(); record every other
// thread and the exiting thread's own frame chain at that moment.
static void DEDumpThreadsAtExit(void) {
    DEWatchdogLog("DE_EXIT_DUMP begin\n");
    uintptr_t fp=(uintptr_t)__builtin_frame_address(0);
    for (unsigned i=0;fp && i<40;i++) {
        uintptr_t frame[2];vm_size_t copied=0;
        if (vm_read_overwrite(mach_task_self(),fp,sizeof(frame),(vm_address_t)frame,&copied)!=KERN_SUCCESS ||
            copied!=sizeof(frame) || frame[0]<=fp) break;
        DELogAddress(i,frame[1]&0x0000000fffffffffULL);fp=frame[0];
    }
    DEDumpAllThreads();
    DEWatchdogLog("DE_EXIT_DUMP end\n");
}
// Opt-in fault logger kept in front of later-installed handlers (the game's
// crash reporter). Async-signal-safe: fixed formatting and write(2) only. It
// then hands the signal to the handler it displaced, unchanged.
static const int DEFaultSignals[]={SIGSEGV,SIGBUS,SIGILL,SIGTRAP,SIGABRT,SIGFPE};
static struct sigaction DEFaultPrior[6];
static void DEFaultHex(char *out,uintptr_t value) {
    const char *hex="0123456789abcdef";
    for (int i=0;i<16;i++) out[i]=hex[(value>>((15-i)*4))&15];
}
static void DEFaultLogger(int signalNumber,siginfo_t *info,void *context) {
    ucontext_t *uc=(ucontext_t *)context;
    uintptr_t pc=uc&&uc->uc_mcontext?(uintptr_t)uc->uc_mcontext->__ss.__pc:0;
    uintptr_t lr=uc&&uc->uc_mcontext?(uintptr_t)uc->uc_mcontext->__ss.__lr:0;
    uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
    char line[]="DE_FAULT sig=00 addr=0000000000000000 pc=0000000000000000 lr=0000000000000000 main=0000000000000000\n";
    line[13]='0'+(signalNumber/10)%10;line[14]='0'+signalNumber%10;
    DEFaultHex(line+21,(uintptr_t)(info?info->si_addr:0));
    DEFaultHex(line+41,pc);DEFaultHex(line+61,lr);DEFaultHex(line+83,base);
    write(STDERR_FILENO,line,sizeof(line)-1);
    if (DEWatchdogFD>=0) write(DEWatchdogFD,line,sizeof(line)-1);
    // Not async-signal-safe, but the raw line above is already durable.
    {
        const char *queue=dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        char label[300];
        int length=snprintf(label,sizeof(label),"DE_FAULT_QUEUE %s\n",queue?queue:"none");
        if (length>0) {write(STDERR_FILENO,label,(size_t)length);if (DEWatchdogFD>=0) write(DEWatchdogFD,label,(size_t)length);}
    }
    uintptr_t addresses[40]={pc,lr};int count=2;
    uintptr_t fp=uc&&uc->uc_mcontext?(uintptr_t)uc->uc_mcontext->__ss.__fp:0;
    while (fp && count<40) {
        uintptr_t frame[2];vm_size_t copied=0;
        if (vm_read_overwrite(mach_task_self(),fp,sizeof(frame),(vm_address_t)frame,&copied)!=KERN_SUCCESS ||
            copied!=sizeof(frame) || frame[0]<=fp) break;
        addresses[count++]=frame[1]&0x0000000fffffffffULL;fp=frame[0];
    }
    for (int i=0;i<count;i++) {
        Dl_info where={0};
        if (!dladdr((void *)addresses[i],&where) || !where.dli_fname) continue;
        char symbol[600];
        int length=snprintf(symbol,sizeof(symbol),"DE_FAULT_FRAME %d %s+0x%lx %s+0x%lx\n",i,
            strrchr(where.dli_fname,'/')?strrchr(where.dli_fname,'/')+1:where.dli_fname,
            (unsigned long)(addresses[i]-(uintptr_t)where.dli_fbase),
            where.dli_sname?where.dli_sname:"?",
            (unsigned long)(where.dli_saddr?addresses[i]-(uintptr_t)where.dli_saddr:0));
        if (length>0) {
            write(STDERR_FILENO,symbol,(size_t)length);
            if (DEWatchdogFD>=0) write(DEWatchdogFD,symbol,(size_t)length);
        }
    }
    for (int i=0;i<6;i++) if (DEFaultSignals[i]==signalNumber) {
        sigaction(signalNumber,&DEFaultPrior[i],NULL);
        break;
    }
}
static void DEEnsureFaultLogger(void) {
    for (int i=0;i<6;i++) {
        struct sigaction current;
        if (sigaction(DEFaultSignals[i],NULL,&current)!=0) continue;
        if ((current.sa_flags&SA_SIGINFO) && current.sa_sigaction==DEFaultLogger) continue;
        DEFaultPrior[i]=current;
        struct sigaction action={0};
        sigemptyset(&action.sa_mask);
        action.sa_sigaction=DEFaultLogger;action.sa_flags=SA_SIGINFO|SA_ONSTACK;
        sigaction(DEFaultSignals[i],&action,NULL);
        DEWatchdogLog("DE_FAULT_LOGGER installed signal=%d displaced_handler=%d\n",DEFaultSignals[i],
                      (current.sa_flags&SA_SIGINFO)?current.sa_sigaction!=NULL:current.sa_handler!=SIG_DFL);
    }
}
static void DEStartMainWatchdog(void) {
    if (!getenv("AGEPAD_DEVICE_MAIN_WATCHDOG") || DEMainThreadPort) return;
    DEMainThreadPort=mach_thread_self();
    CFRunLoopTimerRef timer=CFRunLoopTimerCreateWithHandler(NULL,CFAbsoluteTimeGetCurrent()+1,1,0,0,
        ^(CFRunLoopTimerRef t){ DEMainHeartbeat++; });
    CFRunLoopAddTimer(CFRunLoopGetMain(),timer,kCFRunLoopCommonModes);
    // A dedicated thread: shared dispatch pools can be exhausted by the game.
    pthread_t watchdog;
    atexit(DEDumpThreadsAtExit);
    pthread_create(&watchdog,NULL,DEMainWatchdogLoop,NULL);
    pthread_detach(watchdog);
    DEWatchdogLog("DE_MAIN_WATCHDOG installed\n");
}
static void *DEMainWatchdogLoop(void *unused) {
    pthread_setname_np("AgePadWatchdog");
    const char *home=getenv("HOME");
    if (home) {
        char path[1100];
        snprintf(path,sizeof(path),"%s/Library/Caches/AgePadDiagnostics/watchdog.log",home);
        DEWatchdogFD=open(path,O_WRONLY|O_CREAT|O_TRUNC,0600);
    }
    {
        uint64_t last=DEMainHeartbeat;unsigned stalled=0,dumps=0;
        DEWatchdogLog("DE_WATCHDOG_START\n");
        for (unsigned early=1;early<=12;early++) {
            DEEnsureFaultLogger();
            usleep(100000);
            DEEnsureFaultLogger();
            usleep(400000);
            DEWatchdogLog("DE_WATCHDOG_EARLY half_seconds=%u main_heartbeat=%llu\n",early,(unsigned long long)DEMainHeartbeat);
        }
        for (unsigned tick=1;;tick++) {
            sleep(2);
            if (tick%5==0) {
                char target[1024]="?";
                fcntl(STDERR_FILENO,F_GETPATH,target);
                DEWatchdogLog("DE_WATCHDOG_TICK seconds=%u main_heartbeat=%llu stderr=%s\n",tick*2,(unsigned long long)DEMainHeartbeat,target);
            }
            if (tick==10 && getenv("AGEPAD_DEVICE_THREAD_DUMP")) DEDumpAllThreads();
            uint64_t now=DEMainHeartbeat;
            if (now!=last) { if (stalled>=2) DEWatchdogLog("DE_MAIN_RESUMED after=%us\n",stalled*2); last=now;stalled=0;continue; }
            stalled++;
            if ((stalled==2 || stalled%15==0) && dumps<6) {
                dumps++;
                DEWatchdogLog("DE_MAIN_STALL seconds=%u heartbeat=%llu\n",stalled*2,(unsigned long long)now);
                DEDumpMainThread();
            }
        }
    }
    return NULL;
}

// The original game searches Feral's per-user Application Support folder for
// AgeOfEmpires2Data before asking for a folder. On iPad that folder is inside
// this app's own container, so a relative link can expose the verified import
// in Documents without copying, moving or modifying it. Never replace an
// existing entry. Returns the game-facing path, or nil if unavailable.
static NSString *DEDeviceLinkFeralDataFolder(NSString *imported) {
    NSString *support=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject
        stringByAppendingPathComponent:@"Feral Interactive/Age Of Empires II"];
    NSString *link=[support stringByAppendingPathComponent:@"AgeOfEmpires2Data"];
    NSString *home=NSHomeDirectory();
    if (![imported hasPrefix:[home stringByAppendingString:@"/"]] ||
        ![support hasPrefix:[home stringByAppendingString:@"/"]]) return nil;
    NSFileManager *files=NSFileManager.defaultManager;
    [files createDirectoryAtPath:support withIntermediateDirectories:YES attributes:nil error:NULL];
    // Relative to support, which is Library/Application Support/Feral Interactive/Age Of Empires II.
    NSString *target=[@"../../../.." stringByAppendingPathComponent:
        [imported substringFromIndex:home.length+1]];
    NSString *existing=[files destinationOfSymbolicLinkAtPath:link error:NULL];
    BOOL created=NO;
    if (!existing && ![files fileExistsAtPath:link]) {
        created=symlink(target.fileSystemRepresentation,link.fileSystemRepresentation)==0;
        existing=[files destinationOfSymbolicLinkAtPath:link error:NULL];
    }
    char resolved[PATH_MAX]={0},expected[PATH_MAX]={0};
    BOOL matches=realpath(link.fileSystemRepresentation,resolved) &&
                 realpath(imported.fileSystemRepresentation,expected) && strcmp(resolved,expected)==0;
    fprintf(stderr,"DE_DEVICE_DATA_LINK created=%d link=%d matches=%d\n",created,existing!=nil,matches);
    return matches?link:nil;
}

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
    // Normal launch keeps the current device readiness visible. The paired-Mac
    // Steam test and original game startup require explicit diagnostic flags.
    if ([NSFileManager.defaultManager fileExistsAtPath:
            [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"DeviceSetupGate"]]) {
        NSString *child = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"DeviceChildProbe"];
        pid_t childPID = 0;
        char *childArgv[] = {(char *)child.fileSystemRepresentation, NULL};
        int spawnError = posix_spawn(&childPID, child.fileSystemRepresentation, NULL, NULL, childArgv, NULL);
        int childStatus = 0;
        int waited = spawnError ? -1 : waitpid(childPID, &childStatus, 0);
        fprintf(stderr, "DE_DEVICE_CHILD_PROCESS spawn=%d pid=%d wait=%d status=%d\n",
                spawnError, childPID, waited, childStatus);
        mach_port_t *bootstrap = dlsym(RTLD_DEFAULT, "bootstrap_port");
        kern_return_t (*lookup)(mach_port_t, const char *, mach_port_t *) =
            dlsym(RTLD_DEFAULT, "bootstrap_look_up");
        kern_return_t (*checkIn)(mach_port_t, const char *, mach_port_t *) =
            dlsym(RTLD_DEFAULT, "bootstrap_check_in");
        mach_port_t service = MACH_PORT_NULL;
        kern_return_t lookupStatus = bootstrap && lookup ?
            lookup(*bootstrap, "com.valvesoftware.steam.ipctool", &service) : KERN_NOT_SUPPORTED;
        if (MACH_PORT_VALID(service)) mach_port_deallocate(mach_task_self(), service);
        service = MACH_PORT_NULL;
        // A pre-existing service belongs to another process; never claim it.
        kern_return_t checkInStatus = lookupStatus != KERN_SUCCESS && bootstrap && checkIn ?
            checkIn(*bootstrap, "com.valvesoftware.steam.ipctool", &service) : KERN_NOT_SUPPORTED;
        if (MACH_PORT_VALID(service)) mach_port_deallocate(mach_task_self(), service);
        fprintf(stderr, "DE_DEVICE_STEAM_BOOTSTRAP lookup=%d check_in=%d\n",
                lookupStatus, checkInStatus);
        mach_port_t localPort = MACH_PORT_NULL;
        kern_return_t allocateStatus = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &localPort);
        kern_return_t rightStatus = allocateStatus == KERN_SUCCESS ?
            mach_port_insert_right(mach_task_self(), localPort, localPort, MACH_MSG_TYPE_MAKE_SEND) : KERN_FAILURE;
        mach_msg_header_t echo = {0};
        echo.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
        echo.msgh_size = sizeof(echo);
        echo.msgh_remote_port = localPort;
        echo.msgh_id = 0x414745;
        mach_msg_return_t sendStatus = rightStatus == KERN_SUCCESS ?
            mach_msg(&echo, MACH_SEND_MSG, sizeof(echo), 0, MACH_PORT_NULL, 1000, MACH_PORT_NULL) : KERN_FAILURE;
        struct { mach_msg_header_t header; unsigned char trailer[64]; } received = {0};
        mach_msg_return_t receiveStatus = sendStatus == MACH_MSG_SUCCESS ?
            mach_msg(&received.header, MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof(received), localPort, 1000, MACH_PORT_NULL) : KERN_FAILURE;
        fprintf(stderr, "DE_DEVICE_LOCAL_MACH allocate=%d right=%d send=%d receive=%d id_match=%d\n",
                allocateStatus, rightStatus, sendStatus, receiveStatus,
                receiveStatus == MACH_MSG_SUCCESS && received.header.msgh_id == echo.msgh_id);
        if (MACH_PORT_VALID(localPort)) mach_port_destroy(mach_task_self(), localPort);
        NSString *helperImage = [NSBundle.mainBundle.bundlePath
            stringByAppendingPathComponent:@"Frameworks/IPCHelperDevice.dylib"];
        if ([NSFileManager.defaultManager fileExistsAtPath:helperImage]) {
            setenv("AGEPAD_DEVICE_LOCAL_IPC_PROBE", "1", 1);
            dlerror();
            void *loaded = dlopen(helperImage.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            const char *loadError = dlerror();
            fprintf(stderr, "DE_DEVICE_IPC_HELPER_LOAD loaded=%d error=%s\n",
                    loaded != NULL, loadError ?: "none");
            if (loaded) {
                NSString *shimImage = [NSBundle.mainBundle.bundlePath
                    stringByAppendingPathComponent:@"Frameworks/IPCSystemCompat.dylib"];
                void *shim = dlopen(shimImage.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
                void (*markThread)(void) = shim ? dlsym(shim, "DEIPCMarkHelperThread") : NULL;
                int (*ready)(void) = shim ? dlsym(shim, "DELocalServiceReady") : NULL;
                const struct mach_header *header = NULL;
                for (uint32_t i = 0; i < _dyld_image_count(); i++) {
                    if (strcmp(_dyld_get_image_name(i), helperImage.fileSystemRepresentation) == 0) {
                        header = _dyld_get_image_header(i);
                        break;
                    }
                }
                if (header && markThread && ready) {
                    // LC_MAIN entryoff from the owned helper, verified before
                    // metadata adaptation. It runs on a separate app thread.
                    int (*helperMain)(int, char **) = (void *)((uintptr_t)header + 6888);
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                        markThread();
                        char *arguments[] = {(char *)"ipcserver", NULL};
                        int code = helperMain(1, arguments);
                        fprintf(stderr, "DE_DEVICE_IPC_HELPER_RETURN code=%d\n", code);
                        fflush(stderr);
                    });
                    for (int i = 0; i < 100 && !ready(); i++) usleep(10000);
                    fprintf(stderr, "DE_DEVICE_IPC_HELPER_READY ready=%d\n", ready());
                } else {
                    fprintf(stderr, "DE_DEVICE_IPC_HELPER_ENTRY_AVAILABLE header=%d mark=%d ready=%d\n",
                            header != NULL, markThread != NULL, ready != NULL);
                }
            }
        }
        bool sessionLoggedOn = false;
        // Experiment switch: leave the in-process Steam client untouched until
        // the game's own SteamAPI_Init, which then performs the real check.
        bool skipPreflight = getenv("AGEPAD_DEVICE_SKIP_STEAM_PREFLIGHT") && getenv("AGEPAD_DEVICE_RUN_ORIGINAL");
        NSString *steamClient = [NSBundle.mainBundle.bundlePath
            stringByAppendingPathComponent:@"Frameworks/steamclient.dylib"];
        dlerror();
        void *clientLoaded = dlopen(steamClient.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
        const char *clientError = dlerror();
        fprintf(stderr, "DE_DEVICE_STEAM_CLIENT_LOAD loaded=%d error=%s\n",
                clientLoaded != NULL, clientError ?: "none");
        if (skipPreflight) {
            sessionLoggedOn = true;
            fprintf(stderr, "DE_DEVICE_STEAM_PREFLIGHT skipped=1 game_performs_init=1\n");
        }
        if (clientLoaded && !skipPreflight) {
            void *(*createInterface)(const char *, int *) = dlsym(clientLoaded, "CreateInterface");
            int interfaceStatus = -1;
            void *steamInterface = createInterface ? createInterface("SteamClient020", &interfaceStatus) : NULL;
            fprintf(stderr, "DE_DEVICE_STEAM_FACTORY present=%d interface=%d status=%d\n",
                    createInterface != NULL, steamInterface != NULL, interfaceStatus);
            if (steamInterface) {
                // Use the same published interface slots as the Simulator
                // client probe; release a real pipe if one is returned.
                void **methods = *(void ***)steamInterface;
                int32_t (*createPipe)(void *) = (int32_t (*)(void *))methods[0];
                bool (*releasePipe)(void *, int32_t) = (bool (*)(void *, int32_t))methods[1];
                int32_t (*globalUser)(void *, int32_t) = (int32_t (*)(void *, int32_t))methods[2];
                void (*releaseUser)(void *, int32_t, int32_t) =
                    (void (*)(void *, int32_t, int32_t))methods[4];
                Dl_info pipeImage = {0};
                int located = dladdr(methods[0], &pipeImage);
                const char *imageName = located && pipeImage.dli_fname ? pipeImage.dli_fname : "unknown";
                const char *lastSlash = strrchr(imageName, '/');
                fprintf(stderr, "DE_DEVICE_STEAM_PIPE_BEGIN image=%s offset=0x%lx\n",
                        lastSlash ? lastSlash + 1 : imageName,
                        located ? (unsigned long)((uintptr_t)methods[0] - (uintptr_t)pipeImage.dli_fbase) : 0);
                fflush(stderr);
                errno = 0;
                int32_t pipe = createPipe(steamInterface);
                fprintf(stderr, "DE_DEVICE_STEAM_PIPE_RESULT nonzero=%d errno=%d\n", pipe != 0, errno);
                if (pipe) {
                    int32_t user = globalUser(steamInterface, pipe);
                    fprintf(stderr, "DE_DEVICE_STEAM_GLOBAL_USER nonzero=%d\n", user != 0);
                    if (user) {
                        void *(*getUser)(void *, int32_t, int32_t, const char *) =
                            (void *(*)(void *, int32_t, int32_t, const char *))methods[5];
                        void *userInterface = getUser(steamInterface, user, pipe, "SteamUser021");
                        fprintf(stderr, "DE_DEVICE_STEAM_USER_INTERFACE present=%d\n",
                                userInterface != NULL);
                        if (userInterface) {
                            void **userMethods = *(void ***)userInterface;
                            bool (*loggedOn)(void *) = (bool (*)(void *))userMethods[1];
                            sessionLoggedOn = loggedOn(userInterface);
                            fprintf(stderr, "DE_DEVICE_STEAM_LOGGED_ON logged_on=%d\n", sessionLoggedOn);
                        }
                        releaseUser(steamInterface, pipe, user);
                    }
                    fprintf(stderr, "DE_DEVICE_STEAM_PIPE_RELEASED released=%d\n",
                            releasePipe(steamInterface, pipe));
                }
            }
        }
        bool steamInitialized = false;
        // For the original launch, the released pipe/user/logged-on check above
        // is the preflight. A second, never-released SteamAPI_Init in this
        // process conflicts with the game's own Steam API session.
        bool gameOwnsSession = getenv("AGEPAD_DEVICE_RUN_ORIGINAL") != NULL;
        if (gameOwnsSession) {
            steamInitialized = sessionLoggedOn;
            fprintf(stderr, "DE_DEVICE_STEAM_API_PREFLIGHT vendor_init=skipped logged_on=%d\n", sessionLoggedOn);
        }
        NSString *steamAPI = gameOwnsSession ? nil : [NSBundle.mainBundle.bundlePath
            stringByAppendingPathComponent:@"Vendor_libsteam_api.dylib.dylib"];
        dlerror();
        void *apiLoaded = steamAPI ? dlopen(steamAPI.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL) : NULL;
        const char *apiError = dlerror();
        if (steamAPI) fprintf(stderr, "DE_DEVICE_STEAM_API_LOAD loaded=%d error=%s\n",
                              apiLoaded != NULL, apiError ?: "none");
        if (apiLoaded) {
            bool (*initializeSteam)(void) = dlsym(apiLoaded, "SteamAPI_Init");
            fprintf(stderr, "DE_DEVICE_STEAM_API_INIT_BEGIN present=%d\n", initializeSteam != NULL);
            fflush(stderr);
            if (initializeSteam) {
                bool initialized = initializeSteam();
                steamInitialized = initialized;
                fprintf(stderr, "DE_DEVICE_STEAM_API_INIT_RESULT success=%d\n", initialized);
                void *(*getUtils)(void) = dlsym(apiLoaded, "SteamAPI_SteamUtils_v010");
                fprintf(stderr, "DE_DEVICE_STEAM_UTILS export=%d interface=%d\n",
                        getUtils != NULL, getUtils && getUtils() != NULL);
            }
        }
        fflush(stderr);
        NSString *data = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
            stringByAppendingPathComponent:@"AgeOfEmpires2Data"];
        BOOL hasData = [[NSFileManager.defaultManager contentsOfDirectoryAtPath:data error:NULL] count] > 0;
        // This opt-in is a launch diagnostic. A partial import may be enough
        // to reveal the next original-engine dependency, but is not gameplay.
        if (getenv("AGEPAD_DEVICE_RUN_ORIGINAL") && steamInitialized && hasData) {
            NSString *gameData=DEDeviceLinkFeralDataFolder(data);
            DEStartMainWatchdog();
            // The game spells its data root through the Feral link with the
            // real /private prefix; the case resolver matches that raw prefix.
            char supportReal[PATH_MAX]={0};
            NSString *caseRoot=data;
            if (gameData && realpath(gameData.stringByDeletingLastPathComponent.fileSystemRepresentation,supportReal))
                caseRoot=[@(supportReal) stringByAppendingPathComponent:@"AgeOfEmpires2Data"];
            setenv("AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT", caseRoot.fileSystemRepresentation, 1);
            fprintf(stderr, "DE_DEVICE_CASE_ROOT %s\n", caseRoot.fileSystemRepresentation);
            setenv("AGEPAD_DEVICE_DATA_ROOT", data.fileSystemRepresentation, 1);
            NSString *appkitPath = [NSBundle.mainBundle.bundlePath
                stringByAppendingPathComponent:@"DEBoundary_AppKit.dylib"];
            void *appkit = dlopen(appkitPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            void (*launch)(void) = appkit ? dlsym(appkit, "DEInvokeOriginalLaunchAfterUIKitReady") : NULL;
            fprintf(stderr, "DE_DEVICE_GAME_LAUNCH_READY steam=%d data_present=%d launch=%d\n",
                    steamInitialized, hasData, launch != NULL);
            fflush(stderr);
            if (launch) {
                dispatch_async(dispatch_get_main_queue(), ^{ launch(); });
                return YES;
            }
        }
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:vc.view.bounds];
        scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scroll.backgroundColor = [UIColor colorWithRed:.10 green:.14 blue:.17 alpha:1];
        [vc.view addSubview:scroll];
        UIStackView *stack = [UIStackView new];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 18;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [scroll addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:40],
            [stack.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-40],
            [stack.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
            [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:56],
            [stack.bottomAnchor constraintLessThanOrEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-56],
            [stack.widthAnchor constraintLessThanOrEqualToConstant:850],
            [scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
            [scroll.contentLayoutGuide.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor]
        ]];
        void (^addLine)(NSString *, CGFloat, UIFontWeight, UIColor *) =
            ^(NSString *message, CGFloat size, UIFontWeight weight, UIColor *color) {
                UILabel *label = [UILabel new];
                label.text = message;
                label.font = [UIFont systemFontOfSize:size weight:weight];
                label.textColor = color;
                label.numberOfLines = 0;
                [stack addArrangedSubview:label];
            };
        UIColor *muted = [UIColor colorWithRed:.75 green:.81 blue:.84 alpha:1];
        UIColor *gold = [UIColor colorWithRed:.88 green:.71 blue:.40 alpha:1];
        BOOL inventoryChecked = [NSFileManager.defaultManager fileExistsAtPath:
            [data stringByAppendingPathComponent:@".agepad-import-inventory-checked"]];
        NSDictionary *disk = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
        unsigned long long freeBytes = [disk[NSFileSystemFreeSize] unsignedLongLongValue];
        NSString *freeSpace = [NSByteCountFormatter stringFromByteCount:(long long)freeBytes countStyle:NSByteCountFormatterCountStyleFile];
        addLine(@"AGEPAD", 20, UIFontWeightBold, gold);
        addLine(@"Age of Empires II: Definitive Edition", 34, UIFontWeightBold, UIColor.whiteColor);
        addLine(@"iPad setup is still in testing. Play is not available in this build.",
                23, UIFontWeightSemibold, UIColor.whiteColor);
        addLine(inventoryChecked ? @"Game files · Imported inventory checked" :
                hasData ? @"Game files · Import incomplete or unchecked" : @"Game files · Not imported",
                19, UIFontWeightMedium, UIColor.whiteColor);
        addLine([NSString stringWithFormat:@"Available iPad storage · %@",freeSpace],
                19, UIFontWeightMedium, UIColor.whiteColor);
        addLine(steamInitialized ? @"Steam · Connected through the paired Mac for this test" :
                @"Steam · No active connection. Pairing with the Mac works only in the engineering test.",
                19, UIFontWeightMedium, UIColor.whiteColor);
        addLine(inventoryChecked ?
                @"Next: keep your Steam Mac copy installed and signed in. AgePad still needs a dependable Steam connection and a successful original-game startup before a match can begin on this iPad." :
                @"Next: keep your Steam Mac copy installed and signed in. AgePad still needs a guided data import and a successful original-game startup before a match can begin on this iPad.",
                18, UIFontWeightRegular, muted);
        fprintf(stderr, "DE_DEVICE_SETUP_GATE data_folder_present=%d inventory_checked=%d steam_connection=%d original_launch=skipped\n",
                hasData, inventoryChecked, steamInitialized);
        fflush(stderr);
        return YES;
    }
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
