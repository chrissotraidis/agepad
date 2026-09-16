#include "PointerEventCompat.m"
static CGPoint testPosition;
CGPoint DEUIKitPointerPosition(void) { return testPosition; }
int main(void) { @autoreleasepool {
    testPosition=CGPointMake(17.25,33.5);const void *first=CGEventCreate(NULL);
    testPosition=CGPointMake(200,100);const void *second=CGEventCreate(NULL);
    BOOL independent=CGPointEqualToPoint(CGEventGetLocation(first),CGPointMake(17.25,33.5)) && CGPointEqualToPoint(CGEventGetLocation(second),testPosition);
    CFRetain(first);CFRelease(first);BOOL owned=CGPointEqualToPoint(CGEventGetLocation(first),CGPointMake(17.25,33.5));CFRelease(first);CFRelease(second);
    printf("{\"independent_snapshots\":%s,\"retained_snapshot\":%s}\n",independent?"true":"false",owned?"true":"false");
    return independent&&owned?0:1;
} }
