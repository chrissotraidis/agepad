// UIKit has no Carbon keyboard-layout object to expose here. Opt-in startup
// diagnostic only: the observed game caller handles NULL as no translation.
// This does not implement keyboard translation or touch text entry.
#include "UnsupportedBoundary.h"
#include <stdatomic.h>
#include <stdlib.h>
static const void *DENoCarbonLayout(const char *name) {
    if (!getenv("AGEPAD_NO_CARBON_LAYOUT")) DEUnsupported(name);
    static atomic_flag reported=ATOMIC_FLAG_INIT;
    if (!atomic_flag_test_and_set(&reported)) {
        fprintf(stderr,"DE_KEYBOARD_LAYOUT_UNAVAILABLE no Carbon layout; character translation unavailable\n");fflush(stderr);
    }
    return NULL;
}
const void *TISCopyCurrentKeyboardLayoutInputSource(void) {
    return DENoCarbonLayout("TISCopyCurrentKeyboardLayoutInputSource");
}
const void *TISCopyCurrentASCIICapableKeyboardLayoutInputSource(void) {
    return DENoCarbonLayout("TISCopyCurrentASCIICapableKeyboardLayoutInputSource");
}
void *TISGetInputSourceProperty(const void *source,CFStringRef key) {
    if (!getenv("AGEPAD_NO_CARBON_LAYOUT")) DEUnsupported("TISGetInputSourceProperty");
    char name[160]="<unavailable>";
    if (key) CFStringGetCString(key,name,sizeof(name),kCFStringEncodingUTF8);
    fprintf(stderr,"DE_KEYBOARD_PROPERTY source_present=%d key=%s\n",source!=NULL,name);fflush(stderr);
    if (source) DEUnsupported("TISGetInputSourceProperty for unimplemented source");
    return NULL;
}
