#import "BC4MetalDecode.h"
static NSString *const DEBC4Kernel=@"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct Params { uint stride; uint width; uint height; uint x; uint y; };\n"
"kernel void decode_bc4(device const uchar *src [[buffer(0)]], constant Params &p [[buffer(1)]], texture2d<float,access::write> dst [[texture(0)]], uint2 block [[thread_position_in_grid]]) {\n"
" uint2 base=block*4; if(base.x>=p.width || base.y>=p.height)return;\n"
" device const uchar *b=src+ulong(block.y)*p.stride+ulong(block.x)*8;\n"
" float a=b[0], z=b[1]; float values[8];values[0]=a;values[1]=z;\n"
" for(uint i=2;i<8;i++) values[i]=a>z?((8-i)*a+(i-1)*z)/7.0f:i<6?((6-i)*a+(i-1)*z)/5.0f:i==6?0.0f:255.0f;\n"
" for(uint y=0;y<4;y++)for(uint x=0;x<4;x++){uint2 q=base+uint2(x,y);if(q.x>=p.width || q.y>=p.height)continue;\n"
" uint bit=3*(y*4+x);uint byte=2+bit/8;uint pair=uint(b[byte]);if(byte<7)pair|=uint(b[byte+1])<<8;\n"
" uint index=(pair>>(bit%8))&7;dst.write(float4(values[index]/255.0f,0,0,1),q+uint2(p.x,p.y));}\n"
"}\n";
@implementation DEBC4MetalDecoder {
 id<MTLDevice> _device;
 id<MTLComputePipelineState> _pipeline;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device error:(NSError **)error {
 if (!(self=[super init]))return nil;
 _device=device;MTLCompileOptions *options=[MTLCompileOptions new];options.mathMode=MTLMathModeSafe;
 id<MTLLibrary> library=[device newLibraryWithSource:DEBC4Kernel options:options error:error];if(!library)return nil;
 _pipeline=[device newComputePipelineStateWithFunction:[library newFunctionWithName:@"decode_bc4"] error:error];
 return _pipeline?self:nil;
}
- (BOOL)encodeTo:(id<MTLCommandBuffer>)command source:(id<MTLBuffer>)source offset:(NSUInteger)offset bytesPerRow:(NSUInteger)stride destination:(id<MTLTexture>)destination origin:(MTLOrigin)origin size:(MTLSize)size error:(NSError **)error {
 NSString *failure=nil;
 if(!source || !destination || !command || source.device!=_device || destination.device!=_device || command.device!=_device) failure=@"BC4 resources must belong to decoder device";
 else if(source.hazardTrackingMode==MTLHazardTrackingModeUntracked || destination.hazardTrackingMode==MTLHazardTrackingModeUntracked)failure=@"BC4 decoder requires tracked resources for encoder ordering";
 else if(destination.textureType!=MTLTextureType2D || destination.pixelFormat!=MTLPixelFormatR8Unorm || !(destination.usage&MTLTextureUsageShaderWrite))failure=@"BC4 target must be writable R8 2D texture";
 else if(!size.width || !size.height || size.depth!=1 || origin.z || size.width>UINT32_MAX-3 || size.height>UINT32_MAX-3 || stride>UINT32_MAX || origin.x>UINT32_MAX || origin.y>UINT32_MAX)failure=@"BC4 dimensions outside supported range";
 else if(origin.x>destination.width || origin.y>destination.height || size.width>destination.width-origin.x || size.height>destination.height-origin.y)failure=@"BC4 target region exceeds texture";
 else {
  NSUInteger columns=(size.width+3)/4,rows=(size.height+3)/4;
  if((offset&3) || stride<columns*8 || offset>source.length || (rows-1)>(NSUIntegerMax-columns*8)/stride || (rows-1)*stride+columns*8>source.length-offset)failure=@"BC4 source range exceeds buffer";
 }
 if(failure){if(error)*error=[NSError errorWithDomain:@"AgePad.BC4" code:1 userInfo:@{NSLocalizedDescriptionKey:failure}];return NO;}
 struct {uint32_t stride,width,height,x,y;} params={(uint32_t)stride,(uint32_t)size.width,(uint32_t)size.height,(uint32_t)origin.x,(uint32_t)origin.y};
 id<MTLComputeCommandEncoder> encoder=[command computeCommandEncoder];if(!encoder)return NO;
 [encoder setComputePipelineState:_pipeline];[encoder setBuffer:source offset:offset atIndex:0];[encoder setBytes:&params length:sizeof(params) atIndex:1];[encoder setTexture:destination atIndex:0];
 [encoder dispatchThreads:MTLSizeMake((size.width+3)/4,(size.height+3)/4,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[encoder endEncoding];return YES;
}
@end
