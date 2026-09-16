// Opt-in absence of Carbon Gestalt selectors on UIKit. No fabricated OS data.
#include "UnsupportedBoundary.h"
#include <stdint.h>
#include <stdlib.h>
int16_t Gestalt(uint32_t selector,int32_t *response) {
    if (!getenv("AGEPAD_UNAVAILABLE_GESTALT")) DEUnsupported("Gestalt");
    char name[5]={0};
    for(unsigned i=0;i<4;i++) { unsigned c=(selector>>(24-8*i))&255;name[i]=c>=32 && c<127?(char)c:'?'; }
    fprintf(stderr,"DE_GESTALT_UNAVAILABLE selector=%s code=%08x\n",name,selector);fflush(stderr);
    if (!response) return -50; // paramErr
    *response=0;
    return -5551; // gestaltUndefSelectorErr, from native CarbonCore MacErrors.h
}
