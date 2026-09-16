#import "BC7MetalDecode.h"
#include "BC7Kernel.inc"
@implementation DEBC7MetalDecoder {
 id<MTLDevice> _device;
 id<MTLComputePipelineState> _pipeline;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error {
 if (!(self=[super init]))return nil;
 _device=device;MTLCompileOptions *options=[MTLCompileOptions new];options.mathMode=MTLMathModeSafe;
 id<MTLLibrary> library=[device newLibraryWithSource:DEBC7Kernel options:options error:error];if(!library)return nil;
 _pipeline=[device newComputePipelineStateWithFunction:[library newFunctionWithName:@"decode_bc7"] error:error];
 return _pipeline?self:nil;
}
- (BOOL)encodeTo:(id<MTLCommandBuffer>)command source:(id<MTLBuffer>)source offset:(NSUInteger)offset bytesPerRow:(NSUInteger)stride destination:(id<MTLTexture>)destination origin:(MTLOrigin)origin size:(MTLSize)size error:(NSError **)error {
 NSString *failure=nil;
 if(!source || !destination || !command || source.device!=_device || destination.device!=_device || command.device!=_device) failure=@"BC7 resources must belong to decoder device";
 else if(source.hazardTrackingMode==MTLHazardTrackingModeUntracked || destination.hazardTrackingMode==MTLHazardTrackingModeUntracked)failure=@"BC7 decoder requires tracked resources for encoder ordering";
 else if(destination.textureType!=MTLTextureType2D || destination.pixelFormat!=MTLPixelFormatRGBA8Unorm || !(destination.usage&MTLTextureUsageShaderWrite))failure=@"BC7 target must be writable RGBA8 2D texture";
 else if(!size.width || !size.height || size.depth!=1 || origin.z || size.width>UINT32_MAX-3 || size.height>UINT32_MAX-3 || stride>UINT32_MAX || origin.x>UINT32_MAX || origin.y>UINT32_MAX)failure=@"BC7 dimensions outside supported range";
 else if(origin.x>destination.width || origin.y>destination.height || size.width>destination.width-origin.x || size.height>destination.height-origin.y)failure=@"BC7 target region exceeds texture";
 else {
  NSUInteger columns=(size.width+3)/4,rows=(size.height+3)/4;
  if((offset&3) || stride<columns*16 || offset>source.length || (rows-1)>(NSUIntegerMax-columns*16)/stride || (rows-1)*stride+columns*16>source.length-offset)failure=@"BC7 source range exceeds buffer";
 }
 if(failure){if(error)*error=[NSError errorWithDomain:@"AgePad.BC7" code:1 userInfo:@{NSLocalizedDescriptionKey:failure}];return NO;}
 struct {uint32_t stride,width,height,x,y;} params={(uint32_t)stride,(uint32_t)size.width,(uint32_t)size.height,(uint32_t)origin.x,(uint32_t)origin.y};
 id<MTLComputeCommandEncoder> encoder=[command computeCommandEncoder];if(!encoder)return NO;
 [encoder setComputePipelineState:_pipeline];[encoder setBuffer:source offset:offset atIndex:0];[encoder setBytes:&params length:sizeof(params) atIndex:1];[encoder setTexture:destination atIndex:0];
 [encoder dispatchThreads:MTLSizeMake((size.width+3)/4,(size.height+3)/4,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[encoder endEncoding];return YES;
}
@end
