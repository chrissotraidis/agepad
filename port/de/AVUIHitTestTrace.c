// Read-only observation of the original AVUI hit-test callbacks.
// The wrappers forward both machine arguments and return values unchanged.
#include <errno.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

typedef uint32_t (*DEAVUICallback)(void *, void *);

extern uint32_t DEOriginalInputHitTestResultCallback(void *, void *)
    __asm("__ZN4AVUI18InputHitTestResult26InputHitTestResultCallbackEPNS_13HitTestResultE");
extern uint32_t DEOriginalNoNested2DFilter(void *, void *)
    __asm("__ZN4AVUI16TopMostHitResult16NoNested2DFilterEPNS_16DependencyObjectE");

static _Thread_local int DETracing;
static unsigned DEInputRecords;
static unsigned DEFilterRecords;
static _Atomic int DEInstallationLogged;

// Startup and menu layout can consume hundreds of callbacks before the first
// gameplay touch. Keep the observer finite, but large enough to retain one
// complete launch-to-command fixture.
enum { DEAVUIRecordBudget = 4096 };

static int DEFindGameImage(uintptr_t *slide, const char **name);

static unsigned DELogBegin(const char *name, void *receiver, void *argument,
                           unsigned *count) {
    if (!getenv("AGEPAD_AVUI_HIT_TRACE") || DETracing ||
        *count >= DEAVUIRecordBudget)
        return UINT32_MAX;
    unsigned sequence = *count;
    DETracing = 1;
    fprintf(stderr,
            "DE_AVUI_HIT_BEGIN name=%s receiver=%p argument=%p sequence=%u\n",
            name, receiver, argument, sequence);
    fflush(stderr);
    (*count)++;
    DETracing = 0;
    return sequence;
}

static void DELogEnd(const char *name, uint32_t result, unsigned sequence) {
    if (sequence == UINT32_MAX || DETracing) return;
    DETracing = 1;
    fprintf(stderr, "DE_AVUI_HIT_END name=%s result=%u sequence=%u\n",
            name, result, sequence);
    fflush(stderr);
    DETracing = 0;
}

static uintptr_t DEOriginalAddress(uintptr_t unslid) {
    uintptr_t slide = 0;
    const char *name = NULL;
    return DEFindGameImage(&slide, &name) ? unslid + slide : 0;
}

static uint32_t DEInputHitTestResultCallback(void *receiver, void *argument) {
    int saved = errno;
    unsigned sequence = DELogBegin("InputHitTestResultCallback", receiver,
                                   argument, &DEInputRecords);
    DEAVUICallback original =
        (DEAVUICallback)DEOriginalAddress(0x10278a950ULL);
    uint32_t result = original ? original(receiver, argument) : 0;
    DELogEnd("InputHitTestResultCallback", result, sequence);
    errno = saved;
    return result;
}

static uint32_t DENoNested2DFilter(void *receiver, void *argument) {
    int saved = errno;
    unsigned sequence = DELogBegin("NoNested2DFilter", receiver, argument,
                                   &DEFilterRecords);
    DEAVUICallback original =
        (DEAVUICallback)DEOriginalAddress(0x1027cb5d0ULL);
    uint32_t result = original ? original(receiver, argument) : 0;
    DELogEnd("NoNested2DFilter", result, sequence);
    errno = saved;
    return result;
}

__attribute__((used, section("__DATA,__interpose")))
static const struct {
    const void *replacement;
    const void *original;
} DEAVUIInterpose[] = {
    {(const void *)DEInputHitTestResultCallback,
     (const void *)DEOriginalInputHitTestResultCallback},
    {(const void *)DENoNested2DFilter,
     (const void *)DEOriginalNoNested2DFilter},
};

static int DEFindGameImage(uintptr_t *slide, const char **name) {
    for (uint32_t index = 0; index < _dyld_image_count(); index++) {
        const char *image = _dyld_get_image_name(index);
        if (image && strstr(image, "/DEOriginalGame")) {
            *slide = (uintptr_t)_dyld_get_image_vmaddr_slide(index);
            *name = image;
            return 1;
        }
    }
    return 0;
}

static void DECheckInstallation(void) {
    uintptr_t slide = 0;
    const char *name = NULL;
    if (!DEFindGameImage(&slide, &name)) return;

    const uintptr_t inputSlot = 0x104b045c8ULL + slide;
    const uintptr_t filterSlot = 0x104b04478ULL + slide;
    uintptr_t inputTarget = *(const volatile uintptr_t *)inputSlot;
    uintptr_t filterTarget = *(const volatile uintptr_t *)filterSlot;
    int inputInstalled = inputTarget == (uintptr_t)&DEInputHitTestResultCallback;
    int filterInstalled = filterTarget == (uintptr_t)&DENoNested2DFilter;
    if (atomic_exchange(&DEInstallationLogged, 1)) return;
    fprintf(stderr,
            "DE_AVUI_HIT_INSTALL image=%s slide=0x%llx input_got=%p filter_got=%p input=%d filter=%d\n",
            name, (unsigned long long)slide, (void *)inputTarget,
            (void *)filterTarget, inputInstalled, filterInstalled);
    fflush(stderr);
}

static void DEObserveImage(const struct mach_header *header, intptr_t slide) {
    (void)header;
    (void)slide;
    DECheckInstallation();
}

__attribute__((constructor)) static void DEInstallAVUITrace(void) {
    if (!getenv("AGEPAD_AVUI_HIT_TRACE")) return;
    _dyld_register_func_for_add_image(DEObserveImage);
    DECheckInstallation();
}
