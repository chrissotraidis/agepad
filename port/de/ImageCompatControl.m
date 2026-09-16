#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <TargetConditionals.h>
#include <stdio.h>
#if TARGET_OS_SIMULATOR
#include "ImageCompat.m"
#include "DefaultCursorCompat.m"
#else
#import <AppKit/AppKit.h>
#endif
int main(void) {
    @autoreleasepool {
        const unsigned char pixels[8]={255,0,0,255,0,0,255,255};
        CFDataRef bytes=CFDataCreate(NULL,pixels,sizeof(pixels));
        CGDataProviderRef provider=CGDataProviderCreateWithCFData(bytes);
        CGColorSpaceRef colors=CGColorSpaceCreateDeviceRGB();
        CGImageRef original=CGImageCreate(2,1,8,32,8,colors,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,provider,NULL,false,kCGRenderingIntentDefault);
        NSImage *automatic=[[NSImage alloc] initWithCGImage:original size:CGSizeZero];
        NSImage *explicit=[[NSImage alloc] initWithCGImage:original size:CGSizeMake(4,6)];
        CGImageRelease(original);CGColorSpaceRelease(colors);CGDataProviderRelease(provider);CFRelease(bytes);
        BOOL sizes=CGSizeEqualToSize(automatic.size,CGSizeMake(2,1)) && CGSizeEqualToSize(explicit.size,CGSizeMake(4,6));
        NSImage *copy=[explicit copy];BOOL copied=CGSizeEqualToSize(copy.size,explicit.size);
        NSCursor *cursor=[[NSCursor alloc] initWithImage:explicit hotSpot:CGPointMake(.5,.25)];
        explicit=nil;
        BOOL cursorStored=CGSizeEqualToSize(cursor.image.size,CGSizeMake(4,6)) && CGPointEqualToPoint(cursor.hotSpot,CGPointMake(.5,.25));
        CGImageRef borrowed=[automatic CGImageForProposedRect:NULL context:nil hints:nil];
        automatic=nil;
        CFDataRef result=CGDataProviderCopyData(CGImageGetDataProvider(borrowed));
        BOOL retained=CGImageGetWidth(borrowed)==2 && CGImageGetHeight(borrowed)==1 &&
            CFDataGetLength(result)==8 && memcmp(CFDataGetBytePtr(result),pixels,8)==0;
        CFRelease(result);
        printf("{\"simulator\":%s,\"sizes_match\":%s,\"copy_size_match\":%s,\"pixels_survive_wrapper_release\":%s,\"cursor_image_and_hotspot_match\":%s}\n",
            TARGET_OS_SIMULATOR?"true":"false",sizes?"true":"false",copied?"true":"false",retained?"true":"false",cursorStored?"true":"false");
        return sizes && copied && retained && cursorStored?0:1;
    }
}
