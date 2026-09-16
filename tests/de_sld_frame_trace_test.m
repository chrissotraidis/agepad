#import <Foundation/Foundation.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include "../port/de/SLDParseTrace.h"

static unsigned calls;
static uint16_t layerHeader[]={0,0,4,8,28,40};
static void *observedObject;
static void *frameFixture(void *object,uint32_t frame,uint32_t layer) {
    assert(object==observedObject);calls++;
    errno=EAGAIN;
    return frame==3 && layer==1?layerHeader:NULL;
}
int main(void) {
    unsigned char object[64]={0};uint32_t count=10;
    memcpy(object+0x28,&count,sizeof(count));observedObject=object;
    DEOriginalSLDFrame=frameFixture;
    DESLDRemember(object,"fixture_idle_x1.sld");
    setenv("AGEPAD_SLD_FRAME_TRACE_ARM","/agepad-nonexistent-trace-arm",1);
    assert(DESLDFrame(object,3,1)==layerHeader);
    assert(errno==EAGAIN && atomic_load(&DESLDFrameCount)==0);
    unsetenv("AGEPAD_SLD_FRAME_TRACE_ARM");
    assert(DESLDFrame(object,3,1)==layerHeader);
    assert(errno==EAGAIN && calls==2 && atomic_load(&DESLDFrameCount)==1);
    assert(DESLDFrame(object,5,1)==NULL && errno==EAGAIN);
    assert(calls==3 && layerHeader[2]==4 && layerHeader[5]==40);
    puts("SLD frame trace preserves arguments, return, errno and data; arm gate passed");
}
