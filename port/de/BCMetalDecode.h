#import <Metal/Metal.h>
#include "BCDecode.h"
// Checked BC1–BC7 compute upload. Finish the current encoder before calling.
// This never commits or waits; tracked resource hazards preserve GPU ordering.
// sRGB formats must use a linear writable backing and an sRGB sampling view.
// Views, compressed storage/readback and allocation are the caller's concerns.
@interface DEBCMetalDecoder : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (BOOL)encodeFormat:(DEBCFormat)format command:(id<MTLCommandBuffer>)command
              source:(id<MTLBuffer>)source offset:(NSUInteger)offset bytesPerRow:(NSUInteger)stride
         destination:(id<MTLTexture>)destination origin:(MTLOrigin)origin
                size:(MTLSize)size error:(NSError **)error;
@end
