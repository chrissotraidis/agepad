#import "BCMetalDecode.h"
#include "BCBasicKernel.inc"
#include "BC6Kernel.inc"
#include "BC7Kernel.inc"
@implementation DEBCMetalDecoder {
 id<MTLDevice> _device;
 id<MTLComputePipelineState> _basic, _bc6, _bc7;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error {
 if(!(self=[super init]))return nil;_device=device;
 MTLCompileOptions *options=[MTLCompileOptions new];options.mathMode=MTLMathModeSafe;
 NSArray *sources=@[DEBCBasicKernel,DEBC6Kernel,DEBC7Kernel],*names=@[@"decode_bc_basic",@"decode_bc6",@"decode_bc7"];
 id<MTLComputePipelineState> states[3];
 for(unsigned i=0;i<3;i++) {
  id<MTLLibrary> library=[device newLibraryWithSource:sources[i] options:options error:error];if(!library)return nil;
  states[i]=[device newComputePipelineStateWithFunction:[library newFunctionWithName:names[i]] error:error];if(!states[i])return nil;
 }
 _basic=states[0];_bc6=states[1];_bc7=states[2];return self;
}
- (BOOL)encodeFormat:(DEBCFormat)format command:(id<MTLCommandBuffer>)command
              source:(id<MTLBuffer>)source offset:(NSUInteger)offset bytesPerRow:(NSUInteger)stride
         destination:(id<MTLTexture>)destination origin:(MTLOrigin)origin
                size:(MTLSize)size error:(NSError **)error {
 NSString *failure=nil;
 BOOL basicColor=format<=DEBC3||format==DEBC7;
 BOOL single=format==DEBC4U||format==DEBC4S;
 BOOL dual=format==DEBC5U||format==DEBC5S;
 MTLPixelFormat pixel=destination.pixelFormat;
 BOOL backing=pixel==MTLPixelFormatRGBA32Float ||
  (basicColor&&pixel==MTLPixelFormatRGBA8Unorm) ||
  (single&&(pixel==MTLPixelFormatR16Float||pixel==MTLPixelFormatR32Float)) ||
  (dual&&(pixel==MTLPixelFormatRG16Float||pixel==MTLPixelFormatRG32Float)) ||
  ((format==DEBC6U||format==DEBC6S)&&pixel==MTLPixelFormatRGBA16Float);
 if((unsigned)format>DEBC7)failure=@"Unknown BC format";
 else if(!source||!destination||!command||source.device!=_device||destination.device!=_device||command.device!=_device)failure=@"BC resources must belong to decoder device";
 else if(source.hazardTrackingMode==MTLHazardTrackingModeUntracked||destination.hazardTrackingMode==MTLHazardTrackingModeUntracked)failure=@"BC decoder requires tracked hazards";
 else if(command.status>MTLCommandBufferStatusEnqueued)failure=@"BC command buffer already committed";
 else if(destination.textureType!=MTLTextureType2D||destination.sampleCount!=1||!(destination.usage&MTLTextureUsageShaderWrite)||!backing)failure=@"Unsupported writable BC backing";
 else if(!size.width||!size.height||size.depth!=1||origin.z||size.width>UINT32_MAX-3||size.height>UINT32_MAX-3||stride>UINT32_MAX||origin.x>UINT32_MAX||origin.y>UINT32_MAX)failure=@"BC dimensions outside supported range";
 else if(origin.x>destination.width||origin.y>destination.height||size.width>destination.width-origin.x||size.height>destination.height-origin.y)failure=@"BC destination range exceeds texture";
 else {
  NSUInteger block=(format==DEBC1||single)?8:16,columns=(size.width+3)/4,rows=(size.height+3)/4,row=columns*block;
  if((offset&3)||stride<row||offset>source.length||(rows-1)>(NSUIntegerMax-row)/stride||(rows-1)*stride+row>source.length-offset)failure=@"BC source range exceeds buffer";
 }
 if(failure){if(error)*error=[NSError errorWithDomain:@"AgePad.BC" code:1 userInfo:@{NSLocalizedDescriptionKey:failure}];return NO;}
 struct {uint32_t stride,width,height,x,y,format;} p={(uint32_t)stride,(uint32_t)size.width,(uint32_t)size.height,(uint32_t)origin.x,(uint32_t)origin.y,(uint32_t)format};
 id<MTLComputeCommandEncoder> encoder=[command computeCommandEncoder];if(!encoder)return NO;
 [encoder setComputePipelineState:format==DEBC7?_bc7:format>=DEBC6U?_bc6:_basic];
 [encoder setBuffer:source offset:offset atIndex:0];[encoder setBytes:&p length:sizeof p atIndex:1];[encoder setTexture:destination atIndex:0];
 [encoder dispatchThreads:MTLSizeMake((size.width+3)/4,(size.height+3)/4,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[encoder endEncoding];return YES;
}
@end
