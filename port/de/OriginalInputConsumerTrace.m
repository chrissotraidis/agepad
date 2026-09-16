#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdatomic.h>
#include <string.h>

// This library observes the first original consumer below CFeralNSWindow's
// mouseDown:/mouseUp: boundary. It never changes arguments, return values, or
// event state, and refuses to install when the private ABI is not exact.
typedef struct {
    int32_t first;
    int32_t second;
    double timestamp;
    void *dictionary;
    void *vectorBegin;
    void *vectorEnd;
    void *vectorCapacity;
} DEOriginalEventResult;

typedef DEOriginalEventResult (*DEOriginalEventIMP)(id, SEL, int, id);
static DEOriginalEventIMP originalMouseClick;
static DEOriginalEventIMP originalMouseEvent;
static atomic_uint traceCount;

static long eventInteger(id event, SEL selector) {
    if (!event || ![event respondsToSelector:selector]) return -1;
    return ((long (*)(id, SEL))objc_msgSend)(event, selector);
}

static double eventDouble(id event, SEL selector) {
    if (!event || ![event respondsToSelector:selector]) return -1.0;
    return ((double (*)(id, SEL))objc_msgSend)(event, selector);
}

static CGPoint eventPoint(id event) {
    SEL selector = sel_registerName("locationInWindow");
    if (!event || ![event respondsToSelector:selector]) return CGPointMake(-1.0, -1.0);
    return ((CGPoint (*)(id, SEL))objc_msgSend)(event, selector);
}

static void logEvent(const char *label, id event) {
    CGPoint point = eventPoint(event);
    fprintf(stderr,
            "DE_ORIGINAL_CONSUMER_EVENT %s class=%s window=%s windowNumber=%ld number=%ld type=%ld flags=%ld subtype=%ld data1=%ld data2=%ld clicks=%ld button=%ld timestamp=%.6f x=%.3f y=%.3f\n",
            label,
            event ? object_getClassName(event) : "nil",
            eventInteger(event, sel_registerName("window")) >= 0 ? object_getClassName(((id(*)(id, SEL))objc_msgSend)(event, sel_registerName("window"))) : "nil",
            eventInteger(event, sel_registerName("windowNumber")),
            eventInteger(event, sel_registerName("eventNumber")),
            eventInteger(event, sel_registerName("type")),
            eventInteger(event, sel_registerName("modifierFlags")),
            eventInteger(event, sel_registerName("subtype")),
            eventInteger(event, sel_registerName("data1")),
            eventInteger(event, sel_registerName("data2")),
            eventInteger(event, sel_registerName("clickCount")),
            eventInteger(event, sel_registerName("buttonNumber")),
            eventDouble(event, sel_registerName("timestamp")),
            point.x,
            point.y);
}

static DEOriginalEventResult traceMouseClick(id object, SEL selector, int button, id source) {
    unsigned ticket = atomic_fetch_add(&traceCount, 1);
    if (ticket < 256) {
        long before = eventInteger(object, sel_registerName("lastClickedButton"));
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_BEGIN selector=%s ticket=%u button=%d lastClicked=%ld\n",
                sel_getName(selector), ticket, button, before);
        logEvent("source", source);
    }
    DEOriginalEventResult result = originalMouseClick(object, selector, button, source);
    if (ticket < 256) {
        long after = eventInteger(object, sel_registerName("lastClickedButton"));
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_END selector=%s ticket=%u lastClicked=%ld result_kind=%d result_action=%d\n",
                sel_getName(selector), ticket, after, result.first, result.second);
    }
    return result;
}

static DEOriginalEventResult traceMouseEvent(id object, SEL selector, int button, id source) {
    unsigned ticket = atomic_fetch_add(&traceCount, 1);
    if (ticket < 256) {
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_BEGIN selector=%s ticket=%u button=%d\n",
                sel_getName(selector), ticket, button);
        logEvent("source", source);
    }
    DEOriginalEventResult result = originalMouseEvent(object, selector, button, source);
    if (ticket < 256) {
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_END selector=%s ticket=%u\n",
                sel_getName(selector), ticket);
    }
    return result;
}

static atomic_bool traceInstalled;

static void retryInstall(unsigned attempt);

static void retryInstall(unsigned attempt) {
    if (!getenv("AGEPAD_ORIGINAL_CONSUMER_TRACE") || atomic_load(&traceInstalled)) return;

    Class cls = objc_getClass("CFeralNSWindow");
    SEL clickSelector = sel_registerName("mouseClickEvent:fromEvent:");
    SEL mouseSelector = sel_registerName("mouseEvent:fromEvent:");
    Method click = class_getInstanceMethod(cls, clickSelector);
    Method mouse = class_getInstanceMethod(cls, mouseSelector);
    if (!cls || !click || !mouse) {
        if (attempt < 300)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ retryInstall(attempt + 1); });
        else
            fprintf(stderr, "DE_ORIGINAL_CONSUMER_TRACE_TIMEOUT attempts=%u\n", attempt);
        return;
    }
    const char *clickEncoding = click ? method_getTypeEncoding(click) : "missing";
    const char *mouseEncoding = mouse ? method_getTypeEncoding(mouse) : "missing";
    fprintf(stderr, "DE_ORIGINAL_CONSUMER_ABI click=%s mouse=%s\n", clickEncoding, mouseEncoding);

    if (!click || strcmp(clickEncoding, "{CFeralEvent=iid{NDictionary=^{SharedValue}}{vector<CFeralEvent, std::allocator<CFeralEvent>>=^{CFeralEvent}^{CFeralEvent}^{CFeralEvent}}}28@0:8i16@20")) {
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_CLICK_SKIPPED expected=CFeralEvent_int_event\n");
    } else {
        originalMouseClick = (DEOriginalEventIMP)method_getImplementation(click);
        method_setImplementation(click, (IMP)traceMouseClick);
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_CLICK_INSTALLED=1\n");
    }

    if (!mouse || strcmp(mouseEncoding, "{CFeralEvent=iid{NDictionary=^{SharedValue}}{vector<CFeralEvent, std::allocator<CFeralEvent>>=^{CFeralEvent}^{CFeralEvent}^{CFeralEvent}}}28@0:8i16@20")) {
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_MOUSE_SKIPPED expected=CFeralEvent_int_event\n");
    } else {
        originalMouseEvent = (DEOriginalEventIMP)method_getImplementation(mouse);
        method_setImplementation(mouse, (IMP)traceMouseEvent);
        fprintf(stderr, "DE_ORIGINAL_CONSUMER_MOUSE_INSTALLED=1\n");
    }
    atomic_store(&traceInstalled, true);
}

__attribute__((constructor)) static void install(void) {
    if (!getenv("AGEPAD_ORIGINAL_CONSUMER_TRACE")) return;
    dispatch_async(dispatch_get_main_queue(), ^{ retryInstall(0); });
}
