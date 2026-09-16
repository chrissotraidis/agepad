// UIKit exposes no desktop display gamma table. Advertise zero available entries
// and fail table operations explicitly; never claim a display-wide gamma change.
#include <stdint.h>
#include <stdio.h>
uint32_t CGDisplayGammaTableCapacity(uint32_t display) {
    fprintf(stderr,"DE_UNAVAILABLE_OPTIONAL_UI display gamma table (display %u)\n",display);
    return 0;
}
int32_t CGGetDisplayTransferByTable(uint32_t display,uint32_t capacity,float *red,float *green,float *blue,uint32_t *count) {
    if (count) *count=0;
    return 1006; // kCGErrorNotImplemented.
}
int32_t CGSetDisplayTransferByTable(uint32_t display,uint32_t count,const float *red,const float *green,const float *blue) {
    return 1006;
}
