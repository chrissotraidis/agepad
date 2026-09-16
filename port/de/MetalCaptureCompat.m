// Opt-in, one-shot capture of original game commands. All output stays private.
// Launch with MTL_CAPTURE_ENABLED=1 and AGEPAD_GPU_CAPTURE_OUTPUT, then create
// <output>.arm after reaching the reproducible world state.
static void DEInstallGameCapture(id<MTLDevice> device) {
    const char *path=getenv("AGEPAD_GPU_CAPTURE_OUTPUT");
    if(!path || !*path)return;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSString *output=[NSString stringWithUTF8String:path];
        NSString *arm=[output stringByAppendingString:@".arm"];
        MTLCaptureManager *manager=MTLCaptureManager.sharedCaptureManager;
        if(![manager supportsDestination:MTLCaptureDestinationGPUTraceDocument]) {
            fprintf(stderr,"DE_GPU_CAPTURE_UNAVAILABLE enable MTL_CAPTURE_ENABLED at launch\n");
            return;
        }
        static dispatch_source_t timer;
        timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(timer,DISPATCH_TIME_NOW,NSEC_PER_SEC/4,NSEC_PER_SEC/20);
        dispatch_source_set_event_handler(timer,^{
            if(![NSFileManager.defaultManager fileExistsAtPath:arm])return;
            dispatch_source_cancel(timer);
            [NSFileManager.defaultManager removeItemAtPath:arm error:nil];
            MTLCaptureDescriptor *descriptor=[MTLCaptureDescriptor new];
            descriptor.captureObject=device;
            descriptor.destination=MTLCaptureDestinationGPUTraceDocument;
            descriptor.outputURL=[NSURL fileURLWithPath:output];
            NSError *error=nil;
            if(![manager startCaptureWithDescriptor:descriptor error:&error]) {
                fprintf(stderr,"DE_GPU_CAPTURE_ERROR %s\n",error.description.UTF8String);
                return;
            }
            fprintf(stderr,"DE_GPU_CAPTURE_STARTED path=%s\n",output.UTF8String);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{
                [manager stopCapture];
                fprintf(stderr,"DE_GPU_CAPTURE_STOPPED path=%s\n",output.UTF8String);
            });
        });
        dispatch_resume(timer);
        fprintf(stderr,"DE_GPU_CAPTURE_READY arm=%s\n",arm.UTF8String);
    });
}
