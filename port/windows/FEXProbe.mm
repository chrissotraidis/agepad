// CPU-only qualification harness. This is not Wine, DE, or an FPS benchmark.
#import <UIKit/UIKit.h>
#include <FEXCore/Config/Config.h>
#include <FEXCore/Core/Context.h>
#include <FEXCore/Core/CoreState.h>
#include <FEXCore/Debug/InternalThreadState.h>
#include <FEXCore/Core/HostFeatures.h>
#include <FEXCore/Core/SignalDelegator.h>
#include <FEXCore/HLE/SyscallHandler.h>
#include <FEXCore/Utils/LogManager.h>
#include <FEXCore/Utils/AllocatorHooks.h>
#include <libkern/OSCacheControl.h>
#include <sys/mman.h>
#include <pthread.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <csetjmp>
#include <cstring>

extern "C" void __clear_cache(void *start, void *end) {
    sys_icache_invalidate(start, (char *)end - (char *)start);
}
extern "C" void agepad_set_jit_write_hooks(void (*enter)(void), void (*leave)(void));
static void (*jit_protect)(int) = nullptr;
static thread_local unsigned jit_write_depth = 0;
static unsigned jit_write_scopes = 0;
static void probe_write_enter(void) {
    if (jit_protect && jit_write_depth++ == 0) { jit_protect(false); ++jit_write_scopes; }
}
static void probe_write_leave(void) {
    if (jit_protect && --jit_write_depth == 0) jit_protect(true);
}
static jmp_buf guest_exit;
static volatile uint64_t observed = UINT64_MAX;
static void *probe_map(void *addr, size_t size, int prot, int flags, int fd, off_t offset) {
    if (prot & PROT_EXEC) {
        static uint8_t *pool = nullptr;
        static size_t used = 0;
        constexpr size_t capacity = 64 * 1024 * 1024;
        if (!pool) {
            pool = (uint8_t *)mmap(nullptr, capacity, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_PRIVATE|MAP_ANON|MAP_JIT, -1, 0);
            if (pool == MAP_FAILED) { perror("JIT pool"); abort(); }
        }
        size = (size + 16383) & ~size_t(16383);
        if (addr || used + size > capacity) { fprintf(stderr, "Unsupported JIT pool request\n"); abort(); }
        void *result = pool + used;
        used += size;
        return result;
    }
    void *mapped = mmap(addr, size, prot, flags, fd, offset);
    if (mapped == MAP_FAILED) {
        fprintf(stderr, "PROBE allocation failure: size=%zu prot=%d flags=%d errno=%d %s\n", size, prot, flags, errno, strerror(errno));
        abort();
    }
    return mapped;
}
class ProbeCalls : public FEXCore::HLE::SyscallHandler {
public:
    ProbeCalls() { OSABI = FEXCore::HLE::SyscallOSABI::OS_LINUX64; }
    uint64_t HandleSyscall(FEXCore::Core::CpuStateFrame *, FEXCore::HLE::SyscallArguments *args) override {
        if (args->Argument[0] == 60) {
            observed = args->Argument[1];
            longjmp(guest_exit, 1);
        }
        return -38;
    }
    FEXCore::HLE::ExecutableRangeInfo QueryGuestExecutableRange(FEXCore::Core::InternalThreadState *, uint64_t) override {
        return {0, UINT64_MAX, true};
    }
    std::optional<FEXCore::ExecutableFileSectionInfo> LookupExecutableFileSection(FEXCore::Core::InternalThreadState *, uint64_t) override {
        return std::nullopt;
    }
};

// Qualify separate write/execute aliases before adapting the full runtime.
extern "C" { void *agepad_debugger_memory = nullptr; }
__attribute__((noinline, optnone)) static NSString *run_dualmap_probe() {
    constexpr size_t bytes = 16384;
    const int jitflag = [NSProcessInfo.processInfo.arguments containsObject:@"--debugger-rwx"] ? 0 : MAP_JIT;
    void *rx = agepad_debugger_memory ? agepad_debugger_memory : mmap(nullptr, bytes, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_PRIVATE|MAP_ANON|jitflag, -1, 0);
    if (agepad_debugger_memory == MAP_FAILED) return @"FAIL: debugger AllocateMemory returned invalid address";
    if (rx == MAP_FAILED) return [NSString stringWithFormat:@"FAIL: executable mmap flags=%d errno=%d", jitflag, errno];
    vm_address_t rw = 0;
    vm_prot_t current = 0, maximum = 0;
    kern_return_t kr = vm_remap(mach_task_self(), &rw, bytes, 0, VM_FLAGS_ANYWHERE,
        mach_task_self(), (vm_address_t)rx, FALSE, &current, &maximum, VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) return [NSString stringWithFormat:@"FAIL: Simulator vm_remap: %s", mach_error_string(kr)];
    kr = vm_protect(mach_task_self(), rw, bytes, FALSE, VM_PROT_READ|VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) return [NSString stringWithFormat:@"FAIL: Simulator RW alias protection: %s", mach_error_string(kr)];
    fprintf(stderr, "DUALMAP: RX=%p RW=%p current=%d max=%d before write\n", rx, (void *)rw, current, maximum);
    uint32_t program[] = {0x52800540, 0xd65f03c0}; // mov w0,#42; ret
    memcpy((void *)rw, program, sizeof(program));
    sys_icache_invalidate(rx, sizeof(program));
    int first = ((int (*)(void))rx)();
    program[0] = 0x52800560; // mov w0,#43
    memcpy((void *)rw, program, sizeof(program));
    sys_icache_invalidate(rx, sizeof(program));
    int second = ((int (*)(void))rx)();
    return [NSString stringWithFormat:@"%@: Simulator dual-map returned %d then %d.\nNot a physical-device JIT qualification.", first == 42 && second == 43 ? @"PASS" : @"FAIL", first, second];
}

static NSString *run_probe() {
    LogMan::Msg::InstallHandler([](LogMan::DebugLevels, const char *s) { fprintf(stderr, "FEX: %s\n", s); });
    LogMan::Throw::InstallHandler([](const char *s) { fprintf(stderr, "FEX FATAL: %s\n", s); abort(); });
    FEXCore::Config::Initialize();
    FEXCore::Allocator::mmap = probe_map;
    // Diagnostic lookup only: this is not a public iPadOS API or a device solution.
    auto write_protect = (void (*)(int))dlsym(RTLD_DEFAULT, "pthread_jit_write_protect_np");
    if (!write_protect) return @"FAIL: Simulator JIT write-protection API unavailable";
    jit_protect = write_protect;
    agepad_set_jit_write_hooks(probe_write_enter, probe_write_leave);
    write_protect(false);
    FEXCore::Config::Set(FEXCore::Config::ConfigOption::CONFIG_IS64BIT_MODE, "1");
    FEXCore::Config::Set(FEXCore::Config::ConfigOption::CONFIG_MULTIBLOCK, "0");
    FEXCore::HostFeatures features{};
    features.DCacheLineSize = 64;
    features.ICacheLineSize = 64;
    features.SupportsCacheMaintenanceOps = true;
    ProbeCalls calls;
    FEXCore::SignalDelegator signals;
    auto context = FEXCore::Context::Context::CreateNewContext(features);
    context->SetSyscallHandler(&calls);
    context->SetSignalDelegator(&signals);
    context->SetHardwareTSOSupport(false);
    fprintf(stderr, "PROBE: initializing CPU translator\n");
    if (!context->InitCore()) return @"FAIL: FEX InitCore";
    const size_t pages = 16384, stack_size = 1024 * 1024;
    auto *code = (uint8_t *)mmap(nullptr, pages, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0);
    void *stack = mmap(nullptr, stack_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0);
    if (code == MAP_FAILED || stack == MAP_FAILED) return @"FAIL: guest allocation";
    // mov edi,40; add edi,2; mov eax,60; syscall. Guest exit receives 42.
    const uint8_t program[] = {0xbf,40,0,0,0, 0x83,0xc7,2, 0xb8,60,0,0,0, 0x0f,0x05,0x0f,0x0b};
    memcpy(code, program, sizeof(program));
    bool dynamic = [NSProcessInfo.processInfo.arguments containsObject:@"--dynamic"];
    if (dynamic) {
        // Indirect jumps prevent the initial translator pass discovering each
        // next block statically. 40 increments + initial value 2 must yield 42.
        for (unsigned i = 0; i < 40; ++i) {
            uint8_t *block = code + i * 64;
            unsigned n = 0;
            if (i == 0) { block[n++]=0xbf; uint32_t two=2; memcpy(block+n,&two,4); n+=4; }
            block[n++]=0x83; block[n++]=0xc7; block[n++]=1; // add edi,1
            block[n++]=0x48; block[n++]=0xb8; // movabs rax,next
            uint64_t next=(uint64_t)(code+(i+1)*64); memcpy(block+n,&next,8); n+=8;
            block[n++]=0xff; block[n++]=0xe0; // jmp rax
        }
        const uint8_t finish[]={0xb8,60,0,0,0,0x0f,0x05,0x0f,0x0b};
        memcpy(code+40*64,finish,sizeof(finish));
    }
    bool branch = [NSProcessInfo.processInfo.arguments containsObject:@"--branch-loop"];
    if (branch) {
        const uint8_t loop[]={0xbf,0,0,0,0, 0xb9,0x40,0x42,0x0f,0, 0x83,0xc7,1, 0xff,0xc9, 0x75,0xf9, 0xb8,60,0,0,0, 0x0f,0x05,0x0f,0x0b};
        memcpy(code,loop,sizeof(loop));
    }
    const uint64_t expected = branch ? 1000000 : 42;
    auto *thread = context->CreateThread((uint64_t)code, ((uint64_t)stack + stack_size - 16));
    if (!thread) return @"FAIL: CreateThread";
    const size_t shadow_size = FEXCore::Core::InternalThreadState::CALLRET_STACK_SIZE;
    void *shadow = mmap(nullptr, shadow_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0);
    if (shadow == MAP_FAILED) return @"FAIL: shadow stack";
    thread->CallRetStackBase = shadow;
    thread->CurrentFrame->State.callret_sp = (uint64_t)shadow + shadow_size/4;
    FEXCore::Core::CPUState::gdt_segment gdt[1]{};
    gdt[0].L=1; gdt[0].P=1; gdt[0].S=1; gdt[0].Type=11;
    thread->CurrentFrame->State.segment_arrays[0] = gdt;
    thread->CurrentFrame->State.cs_idx = 0;
    fprintf(stderr, "PROBE: executing x64 arithmetic\n");
    // Simulator-only W^X qualification: compile this bounded guest block while
    // writable, then execute it after returning JIT pages to executable mode.
    // This does not yet qualify interleaved compilation in the Windows runtime.
    context->CompileRIP(thread, (uint64_t)code);
    write_protect(true);
    if (setjmp(guest_exit) == 0) context->ExecuteThread(thread);
    NSString *result = [NSString stringWithFormat:@"%@: x64 result = %llu; dynamic=%d branch-loop=%d; write scopes=%u\nCPU probe only; Windows/DE untested.", observed == expected && (!(dynamic || branch) || jit_write_scopes > 1) ? @"PASS" : @"FAIL", observed, dynamic, branch, jit_write_scopes];
    fprintf(stderr, "PROBE RESULT: %s\n", result.UTF8String);
    // The bounded harness owns this context until process exit; do not destroy
    // a thread escaped through the syscall trampoline before cleanup is qualified.
    context.release();
    return result;
}

@interface ProbeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ProbeDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    UITextView *text = [[UITextView alloc] initWithFrame:self.window.bounds];
    text.editable = NO;
    text.textContainerInset = UIEdgeInsetsMake(64, 20, 20, 20);
    text.font = [UIFont monospacedSystemFontOfSize:23 weight:UIFontWeightRegular];
    text.text = @"AgePad CPU compatibility probe\nRunning x64 translation test…";
    vc.view = text;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *result = [NSProcessInfo.processInfo.arguments containsObject:@"--dualmap"] ? run_dualmap_probe() : run_probe();
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"result.txt"];
        [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{ text.text = result; });
    });
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--early-dualmap"]) {
            NSString *result = run_dualmap_probe();
            fprintf(stderr, "EARLY DUALMAP: %s\n", result.UTF8String);
            NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"early-result.txt"];
            [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return [result hasPrefix:@"PASS"] ? 0 : 1;
        }
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(ProbeDelegate.class));
    }
}
