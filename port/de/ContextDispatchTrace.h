// Read-only diagnostic for the audited supplied Mac DE 1.1.2 image.
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <unistd.h>
static uintptr_t DEContextImageBase;
static struct sigaction DEPriorSegv, DEPriorBus;
static BOOL DEDeviceLinkerTrace;
static BOOL DEReadWord(uintptr_t address, uintptr_t *value) {
    vm_size_t copied=0;
    return vm_read_overwrite(mach_task_self(),address,sizeof(*value),
        (vm_address_t)value,&copied)==KERN_SUCCESS && copied==sizeof(*value);
}
static void DEFaultWriteHex(const char *label, size_t length, uintptr_t value) {
    char digits[17];
    const char *hex="0123456789abcdef";
    for (unsigned i=0;i<16;i++) digits[i]=hex[(value >> ((15-i)*4))&15];
    digits[16]='\n';
    write(STDERR_FILENO,label,length);
    write(STDERR_FILENO,digits,sizeof(digits));
}
static void DEContextFatal(int signalNumber, siginfo_t *info, void *context) {
    uintptr_t override=0,fallback=0,table=0,target=0,argument=0,handle=0;
    if (DEDeviceLinkerTrace) {
        // Pinned September 24 DE build only; enabled solely by the device trace switch.
        uintptr_t dynamic=0,feral=0,epic=0;
        DEReadWord(DEContextImageBase+0x52a6d50,&dynamic);
        DEReadWord(DEContextImageBase+0x52a6d58,&feral);
        DEReadWord(DEContextImageBase+0x52a6d60,&epic);
#define DE_DEVICE_FAULT_VALUE(label,value) DEFaultWriteHex(label,sizeof(label)-1,value)
        DE_DEVICE_FAULT_VALUE("DE_FATAL dynamic=",dynamic);
        DE_DEVICE_FAULT_VALUE("DE_FATAL feral=",feral);
        DE_DEVICE_FAULT_VALUE("DE_FATAL epic=",epic);
#undef DE_DEVICE_FAULT_VALUE
        DEReadWord(DEContextImageBase+0x5bc3a98,&override);
        DEReadWord(DEContextImageBase+0x52a7268,&fallback);
    } else {
        DEReadWord(DEContextImageBase+0x5989718,&override);
        DEReadWord(DEContextImageBase+0x5082fe8,&fallback);
    }
    uintptr_t object=override?override:fallback;
    if (override) DEReadWord(override+8,&handle);
    if (object && DEReadWord(object,&table)) DEReadWord(table+0x1a8,&target);
    if (!DEDeviceLinkerTrace) DEReadWord(DEContextImageBase+0x4b08728,&argument);
    // Only fixed-buffer writes and read-only VM RPCs in this diagnostic handler.
    // No allocation, Objective-C, dladdr, or altered guest return values.
#define DE_FAULT_VALUE(label,value) DEFaultWriteHex(label,sizeof(label)-1,value)
    DE_FAULT_VALUE("DE_FATAL base=",DEContextImageBase);
    DE_FAULT_VALUE("DE_FATAL override=",override);
    DE_FAULT_VALUE("DE_FATAL fallback=",fallback);
    DE_FAULT_VALUE("DE_FATAL table=",table);
    DE_FAULT_VALUE("DE_FATAL target=",target);
    DE_FAULT_VALUE("DE_FATAL argument=",argument);
    DE_FAULT_VALUE("DE_FATAL library_handle=",handle);
    DE_FAULT_VALUE("DE_FATAL fault=",(uintptr_t)info->si_addr);
#undef DE_FAULT_VALUE
    // Returning retries the unchanged faulting instruction with its previous
    // signal disposition. Do not convert a fatal fault into successful execution.
    sigaction(signalNumber,signalNumber==SIGSEGV?&DEPriorSegv:&DEPriorBus,NULL);
}
static void DEInstallContextFatalTrace(void) {
    if (!getenv("AGEPAD_MAC_FATAL_CONTEXT_TRACE") && !getenv("AGEPAD_DEVICE_LINKER_TRACE")) return;
    static BOOL installed;
    if (installed) return;
    installed=YES;
    DEDeviceLinkerTrace=getenv("AGEPAD_DEVICE_LINKER_TRACE")!=NULL;
    DEContextImageBase=(uintptr_t)_dyld_get_image_header(0);
    struct sigaction action={0};
    sigemptyset(&action.sa_mask);
    action.sa_sigaction=DEContextFatal;
    action.sa_flags=SA_SIGINFO;
    sigaction(SIGSEGV,&action,&DEPriorSegv);
    sigaction(SIGBUS,&action,&DEPriorBus);
}
static void DETraceContextDispatch(void) {
    DEInstallContextFatalTrace();
    if (getenv("AGEPAD_DEVICE_LINKER_TRACE")) {
        uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
        uintptr_t dynamic=0,feral=0,epic=0,selected=0,fallback=0,object=0,table=0,target=0;
        DEReadWord(base+0x52a6d50,&dynamic);
        DEReadWord(base+0x52a6d58,&feral);
        DEReadWord(base+0x52a6d60,&epic);
        DEReadWord(base+0x5bc3a98,&selected);
        DEReadWord(base+0x52a7268,&fallback);
        object=selected?selected:fallback;
        if (object && DEReadWord(object,&table)) DEReadWord(table+0x1a8,&target);
        fprintf(stderr,"DE_DEVICE_LINKER_QUERY dynamic=%p feral=%p epic=%p selected=%p fallback=%p table=%p method=%p method_offset=0x%llx\n",
            (void *)dynamic,(void *)feral,(void *)epic,(void *)selected,(void *)fallback,
            (void *)table,(void *)target,(unsigned long long)(target?target-base:0));
        fflush(stderr);
    }
    if (!getenv("AGEPAD_MAC_CONTEXT_TRACE")) return;
    uintptr_t base=(uintptr_t)_dyld_get_image_header(0);
    uintptr_t override=0,fallback=0,object=0,table=0,target=0,argument=0;
    BOOL a=DEReadWord(base+0x5989718,&override);
    BOOL b=DEReadWord(base+0x5082fe8,&fallback);
    object=override?override:fallback;
    BOOL c=object && DEReadWord(object,&table) && DEReadWord(table+0x1a8,&target);
    BOOL d=DEReadWord(base+0x4b08728,&argument);
    Dl_info info={0};
    if (target) dladdr((void *)target,&info);
    fprintf(stderr,"DE_CONTEXT_DISPATCH reads=%d%d%d%d override=%d fallback=%d argument_nonnull=%d target_image=%s target_offset=0x%llx\n",
        a,b,c,d,override!=0,fallback!=0,argument!=0,
        info.dli_fname?strrchr(info.dli_fname,'/')?strrchr(info.dli_fname,'/')+1:info.dli_fname:"unknown",
        (unsigned long long)(info.dli_fbase?target-(uintptr_t)info.dli_fbase:0));
    fflush(stderr);
}
