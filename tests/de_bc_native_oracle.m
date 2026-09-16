#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "../port/de/BCDecode.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void) { @autoreleasepool {
 id<MTLDevice> device=MTLCreateSystemDefaultDevice();
 assert(device.supportsBCTextureCompression);
 NSError *error=nil;
 NSString *shader=@"#include <metal_stdlib>\nusing namespace metal;kernel void read_blocks(texture2d<float,access::read> t[[texture(0)]],device float4*out[[buffer(0)]],uint2 p[[thread_position_in_grid]]){out[p.y*128+p.x]=t.read(p);}";
 id<MTLLibrary> library=[device newLibraryWithSource:shader options:nil error:&error];assert(library);
 id<MTLComputePipelineState> pipeline=[device newComputePipelineStateWithFunction:[library newFunctionWithName:@"read_blocks"] error:&error];assert(pipeline);
 id<MTLCommandQueue> queue=[device newCommandQueue];
 MTLPixelFormat formats[]={MTLPixelFormatBC1_RGBA,MTLPixelFormatBC2_RGBA,MTLPixelFormatBC3_RGBA,MTLPixelFormatBC4_RUnorm,MTLPixelFormatBC4_RSnorm,MTLPixelFormatBC5_RGUnorm,MTLPixelFormatBC5_RGSnorm,MTLPixelFormatBC6H_RGBUfloat,MTLPixelFormatBC6H_RGBFloat,MTLPixelFormatBC7_RGBAUnorm};
 unsigned failures=0;
 for(unsigned format=0;format<10;format++) {
  NSUInteger blockBytes=(format==DEBC1||format==DEBC4U||format==DEBC4S)?8:16,stride=32*blockBytes;
  id<MTLBuffer> source=[device newBufferWithLength:32*stride options:MTLResourceStorageModeShared];
  uint8_t *bytes=source.contents;uint32_t rng=98765;
  for(NSUInteger i=0;i<source.length;i++){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;bytes[i]=rng;}
  // BC7: all eight valid modes; reserved prefixes were qualified separately.
  if(format==DEBC7)for(unsigned b=0;b<1024;b++){unsigned m=b%8;bytes[b*16]=(bytes[b*16]&~((1u<<(m+1))-1))|(1u<<m);}
  MTLTextureDescriptor *desc=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:formats[format] width:128 height:128 mipmapped:NO];desc.storageMode=MTLStorageModePrivate;desc.usage=MTLTextureUsageShaderRead;
  id<MTLTexture> texture=[device newTextureWithDescriptor:desc];assert(texture);
  id<MTLBuffer> output=[device newBufferWithLength:128*128*16 options:MTLResourceStorageModeShared];
  id<MTLCommandBuffer> command=[queue commandBuffer];id<MTLBlitCommandEncoder> blit=[command blitCommandEncoder];
  [blit copyFromBuffer:source sourceOffset:0 sourceBytesPerRow:stride sourceBytesPerImage:source.length sourceSize:MTLSizeMake(128,128,1) toTexture:texture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];[blit endEncoding];
  id<MTLComputeCommandEncoder> compute=[command computeCommandEncoder];[compute setComputePipelineState:pipeline];[compute setTexture:texture atIndex:0];[compute setBuffer:output offset:0 atIndex:0];[compute dispatchThreads:MTLSizeMake(128,128,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[compute endEncoding];[command commit];[command waitUntilCompleted];assert(!command.error);
  float *expected=malloc(output.length);assert(DEDecodeBCFloat(format,bytes,source.length,stride,expected,output.length,128*16,128,128));
  float *actual=output.contents;double maxAbsolute=0,maxRelative=0;unsigned mismatches=0,skipped=0;
  for(unsigned p=0;p<128*128;p++) {
   unsigned block=(p/128/4)*32+(p%128/4);
   // BC6H has reserved modes. Their alpha result is hardware-specific.
   unsigned m=bytes[block*blockBytes]&31;
   if((format==DEBC6U||format==DEBC6S)&&(m==19||m==23||m==27||m==31)){skipped++;continue;}
   for(unsigned c=0;c<4;c++) {
    double a=actual[p*4+c],e=expected[p*4+c],delta=fabs(a-e),relative=delta/fmax(fabs(e),1);
    maxAbsolute=fmax(maxAbsolute,delta);maxRelative=fmax(maxRelative,relative);
    double tolerance=(format<=DEBC3||format==DEBC7)?1.01/255:0.00002;
    if(!isfinite(a)||!isfinite(e)||relative>tolerance){if(mismatches<2)fprintf(stderr,"format=%u pixel=%u channel=%u gpu=%g cpu=%g\n",format,p,c,a,e);mismatches++;}
   }
  }
  printf("format=%u pixels=%u reserved=%u mismatched_components=%u max_absolute=%g max_relative=%g\n",format,128*128-skipped,skipped,mismatches,maxAbsolute,maxRelative);
  if(mismatches)failures++;free(expected);
 }
 return failures?1:0;
}}
