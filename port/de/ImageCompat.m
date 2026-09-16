// Single CGImage-backed representation. No file decoding or drawing API stubs.
#include "UnsupportedBoundary.h"
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <stdlib.h>
@interface NSImage : NSObject <NSCopying> {
    CGImageRef _dePixels;
    CGSize _deSize;
}
- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size;
@property CGSize size;
- (CGImageRef)CGImageForProposedRect:(CGRect *)rect context:(id)context hints:(NSDictionary *)hints CF_RETURNS_NOT_RETAINED;
@end
@implementation NSImage
- (instancetype)initWithCGImage:(CGImageRef)image size:(CGSize)size {
    if (!getenv("AGEPAD_CGIMAGE_WRAPPER")) DEUnsupported("-[NSImage initWithCGImage:size:]");
    if (!image) return nil;
    self=[super init];
    if (self) {
        _dePixels=CGImageRetain(image);
        _deSize=CGSizeEqualToSize(size,CGSizeZero)?CGSizeMake(CGImageGetWidth(image),CGImageGetHeight(image)):size;
        fprintf(stderr,"DE_CGIMAGE_WRAPPER pixels=%zux%zu size=%gx%g\n",CGImageGetWidth(image),CGImageGetHeight(image),_deSize.width,_deSize.height);fflush(stderr);
    }
    return self;
}
- (void)dealloc { if (_dePixels) CGImageRelease(_dePixels); }
- (CGSize)size { return _deSize; }
- (void)setSize:(CGSize)size { _deSize=size; }
- (id)copyWithZone:(NSZone *)zone {
    NSImage *copy=[[NSImage allocWithZone:zone] initWithCGImage:_dePixels size:_deSize];
    copy.size=_deSize;return copy;
}
- (CGImageRef)CGImageForProposedRect:(CGRect *)rect context:(id)context hints:(NSDictionary *)hints {
    // The native API permits an existing representation regardless of hints.
    // Retain/autorelease keeps it valid through this pool even if self is freed.
    return _dePixels?(CGImageRef)CFAutorelease(CGImageRetain(_dePixels)):NULL;
}
+ (BOOL)resolveClassMethod:(SEL)selector {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR +[NSImage %s]\n",sel_getName(selector));DEUnsupported("NSImage");
}
+ (BOOL)resolveInstanceMethod:(SEL)selector {
    fprintf(stderr,"DE_UNSUPPORTED_SELECTOR -[NSImage %s]\n",sel_getName(selector));DEUnsupported("NSImage");
}
@end
