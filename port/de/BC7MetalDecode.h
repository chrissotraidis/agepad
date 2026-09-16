#import <Metal/Metal.h>
// Experimental BC7 UNORM upload operation. Caller must finish any current
// encoder before calling. Encodes work without committing or waiting; preceding
// GPU writes and subsequent reads remain ordered in this command buffer.
@interface DEBC7MetalDecoder : NSObject
- (instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (BOOL)encodeTo:(id<MTLCommandBuffer>)command source:(id<MTLBuffer>)source
          offset:(NSUInteger)offset bytesPerRow:(NSUInteger)stride
     destination:(id<MTLTexture>)destination origin:(MTLOrigin)origin
            size:(MTLSize)size error:(NSError **)error;
@end
