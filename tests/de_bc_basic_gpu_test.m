#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "../port/de/BCDecode.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#ifdef DE_TEST_CHECKED_BC
#import "../port/de/BCMetalDecode.h"
#endif
int main(int argc,char **argv) { @autoreleasepool {
 assert(argc==2||argc==3);BOOL bc6=argc==3&&!strcmp(argv[2],"bc6");NSError *error=nil;id<MTLDevice> device=MTLCreateSystemDefaultDevice();
 NSString *sourceText=[NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:&error];assert(sourceText);
 MTLCompileOptions *options=[MTLCompileOptions new];options.mathMode=MTLMathModeSafe;
 id<MTLLibrary> library=[device newLibraryWithSource:sourceText options:options error:&error];if(!library)fprintf(stderr,"%s\n",error.description.UTF8String);assert(library);
 id<MTLComputePipelineState> pipeline=[device newComputePipelineStateWithFunction:[library newFunctionWithName:bc6?@"decode_bc6":@"decode_bc_basic"] error:&error];assert(pipeline);
 id<MTLCommandQueue> queue=[device newCommandQueue];unsigned checked=0;
#ifdef DE_TEST_CHECKED_BC
 DEBCMetalDecoder *decoder=[[DEBCMetalDecoder alloc]initWithDevice:device error:&error];assert(decoder);
#endif
 const unsigned width=125,height=119,tw=136,th=132,ox=5,oy=7;
#ifdef DE_TEST_CHECKED_BC
 for(unsigned format=0;format<10;format++) {
#else
 for(unsigned format=bc6?7:0;format<(bc6?9:7);format++) {
#endif
  unsigned blockBytes=(format==0||format==3||format==4)?8:16,stride=32*blockBytes+32,bytes=stride*30+256;
  id<MTLBuffer> input=[device newBufferWithLength:bytes options:MTLResourceStorageModeShared];
  uint8_t *data=input.contents;uint32_t rng=76531;
  for(unsigned i=0;i<bytes;i++){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;data[i]=rng;}
  id<MTLBuffer> privateInput=[device newBufferWithLength:bytes options:MTLResourceStorageModePrivate];
  MTLTextureDescriptor *desc=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:tw height:th mipmapped:NO];desc.storageMode=MTLStorageModeShared;desc.usage=MTLTextureUsageShaderWrite;
  id<MTLTexture> output=[device newTextureWithDescriptor:desc];assert(output);
  float *pixels=calloc(tw*th,16);[output replaceRegion:MTLRegionMake2D(0,0,tw,th) mipmapLevel:0 withBytes:pixels bytesPerRow:tw*16];
  id<MTLCommandBuffer> command=[queue commandBuffer];
#ifdef DE_TEST_CHECKED_BC
  [command enqueue];
#endif
  id<MTLBlitCommandEncoder> blit=[command blitCommandEncoder];[blit copyFromBuffer:input sourceOffset:0 toBuffer:privateInput destinationOffset:0 size:bytes];[blit endEncoding];
  struct {uint32_t stride,width,height,x,y,format;} params={stride,width,height,ox,oy,format};
#ifdef DE_TEST_CHECKED_BC
  assert(![decoder encodeFormat:format command:command source:privateInput offset:bytes bytesPerRow:stride destination:output origin:MTLOriginMake(ox,oy,0) size:MTLSizeMake(width,height,1) error:&error]);
  assert(![decoder encodeFormat:format command:command source:privateInput offset:256 bytesPerRow:1 destination:output origin:MTLOriginMake(ox,oy,0) size:MTLSizeMake(width,height,1) error:&error]);
  assert(![decoder encodeFormat:format command:command source:privateInput offset:256 bytesPerRow:stride destination:output origin:MTLOriginMake(tw,oy,0) size:MTLSizeMake(width,height,1) error:&error]);
  assert([decoder encodeFormat:format command:command source:privateInput offset:256 bytesPerRow:stride destination:output origin:MTLOriginMake(ox,oy,0) size:MTLSizeMake(width,height,1) error:&error]);
#else
  id<MTLComputeCommandEncoder> compute=[command computeCommandEncoder];[compute setComputePipelineState:pipeline];[compute setBuffer:privateInput offset:256 atIndex:0];[compute setBytes:&params length:sizeof params atIndex:1];[compute setTexture:output atIndex:0];[compute dispatchThreads:MTLSizeMake(32,30,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[compute endEncoding];
#endif
  [command commit];[command waitUntilCompleted];assert(!command.error);
#ifdef DE_TEST_CHECKED_BC
  assert(![decoder encodeFormat:format command:command source:privateInput offset:256 bytesPerRow:stride destination:output origin:MTLOriginMake(ox,oy,0) size:MTLSizeMake(width,height,1) error:&error]);
#endif
  [output getBytes:pixels bytesPerRow:tw*16 fromRegion:MTLRegionMake2D(0,0,tw,th) mipmapLevel:0];
  float *expected=malloc(width*height*16);assert(DEDecodeBCFloat(format,data+256,bytes-256,stride,expected,width*height*16,width*16,width,height));
  double maximum=0;unsigned mismatch=0;
  for(unsigned y=0;y<th;y++)for(unsigned x=0;x<tw;x++)for(unsigned c=0;c<4;c++) {
   bool inside=x>=ox&&x<ox+width&&y>=oy&&y<oy+height;
   float e=inside?expected[((y-oy)*width+x-ox)*4+c]:0,a=pixels[(y*tw+x)*4+c];
   double delta=fabs(a-e);maximum=fmax(maximum,delta);
   if(!isfinite(a)||delta>0.000001)mismatch++;
  }
  printf("format=%u pixels=%u maximum_error=%g mismatches=%u private-upload padded-stride cropped-edge border\n",format,width*height,maximum,mismatch);assert(!mismatch);
  checked+=width*height;free(pixels);free(expected);
 }
 printf("PASS GPU reference pixels=%u\n",checked);return 0;
}}
