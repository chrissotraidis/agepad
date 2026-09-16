#import <Foundation/Foundation.h>
#import "../port/de/BCMetalDecode.h"
#import "../port/de/BCFormat.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#ifdef DE_TEST_BC_PROXY
#include "../port/de/MetalDevicesCompat.m"
#endif
int main(void) {@autoreleasepool {
 id<MTLDevice>d=MTLCreateSystemDefaultDevice();NSError*e=nil;DEBCMetalDecoder*decoder=[[DEBCMetalDecoder alloc]initWithDevice:d error:&e];assert(decoder);
#ifdef DE_TEST_BC_PROXY
 setenv("AGEPAD_SOFTWARE_BC_ALL","1",1);DEInstallMissingDeviceMetadata(@[d]);
#endif
 NSString*s=@"#include <metal_stdlib>\nusing namespace metal;kernel void readback(texture2d<float,access::read> t[[texture(0)]],device float4*out[[buffer(0)]],uint2 p[[thread_position_in_grid]]){out[p.y*64+p.x]=t.read(p);}";
 id<MTLLibrary>lib=[d newLibraryWithSource:s options:nil error:&e];assert(lib);id<MTLComputePipelineState>pipe=[d newComputePipelineStateWithFunction:[lib newFunctionWithName:@"readback"] error:&e];assert(pipe);
 MTLPixelFormat formats[]={130,131,132,133,134,135,140,141,142,143,150,151,152,153};
 id<MTLCommandQueue>q=[d newCommandQueue];unsigned checked=0;
 for(unsigned f=0;f<14;f++) {
  DEBCFormat kind;MTLPixelFormat storage,sample;assert(DEBCFormatInfo(formats[f],&kind,&storage,&sample));
  unsigned block=(kind==DEBC1||kind==DEBC4U||kind==DEBC4S)?8:16,stride=16*block;
  id<MTLBuffer>in=[d newBufferWithLength:stride*16 options:MTLResourceStorageModeShared];uint32_t state=5476;uint8_t*b=in.contents;
  for(unsigned i=0;i<in.length;i++){state^=state<<13;state^=state>>17;state^=state<<5;b[i]=state;}
  MTLTextureDescriptor*td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:storage width:64 height:64 mipmapped:NO];td.storageMode=MTLStorageModePrivate;td.usage=MTLTextureUsageShaderWrite|MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView;
#ifdef DE_TEST_BC_PROXY
  td.pixelFormat=formats[f];td.usage=MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView;
#endif
  id<MTLTexture>backing=[d newTextureWithDescriptor:td];assert(backing);
#ifdef DE_TEST_BC_PROXY
  assert(backing.pixelFormat==formats[f]);id<MTLTexture>view=[backing newTextureViewWithPixelFormat:formats[f]];assert(view&&view.pixelFormat==formats[f]);
  assert(![backing newTextureViewWithPixelFormat:MTLPixelFormatInvalid]);
#else
  id<MTLTexture>view=[backing newTextureViewWithPixelFormat:sample];assert(view);
#endif
  id<MTLBuffer>out=[d newBufferWithLength:64*64*16 options:MTLResourceStorageModeShared];id<MTLCommandBuffer>cb=[q commandBuffer];
#ifdef DE_TEST_BC_PROXY
  id<MTLBlitCommandEncoder>upload=[cb blitCommandEncoder];[upload copyFromBuffer:in sourceOffset:0 sourceBytesPerRow:stride sourceBytesPerImage:in.length sourceSize:MTLSizeMake(64,64,1) toTexture:backing destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];[upload endEncoding];
#else
  assert([decoder encodeFormat:kind command:cb source:in offset:0 bytesPerRow:stride destination:backing origin:MTLOriginMake(0,0,0) size:MTLSizeMake(64,64,1) error:&e]);
#endif
  id<MTLComputeCommandEncoder>enc=[cb computeCommandEncoder];[enc setComputePipelineState:pipe];[enc setTexture:view atIndex:0];[enc setBuffer:out offset:0 atIndex:0];[enc dispatchThreads:MTLSizeMake(64,64,1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];[enc endEncoding];[cb commit];[cb waitUntilCompleted];assert(!cb.error);
  float*ref=malloc(out.length),*actual=out.contents;assert(DEDecodeBCFloat(kind,b,in.length,stride,ref,out.length,64*16,64,64));double maxError=0;unsigned failures=0;
  for(unsigned i=0;i<64*64*4;i++) {
   double expected=ref[i];if(sample==MTLPixelFormatRGBA8Unorm_sRGB&&i%4!=3)expected=expected<=0.04045?expected/12.92:pow((expected+0.055)/1.055,2.4);
   double delta=fabs(actual[i]-expected)/fmax(1,fabs(expected));maxError=fmax(maxError,delta);
   // Half storage rounding and the GPU's sRGB transfer approximation.
   if(!isfinite(actual[i])||delta>0.001)failures++;
  }
  printf("logical=%lu storage=%lu sample=%lu pixels=4096 max_relative=%g failures=%u\n",(unsigned long)formats[f],(unsigned long)storage,(unsigned long)sample,maxError,failures);assert(!failures);free(ref);checked+=4096;
 }
 assert(!DEBCFormatInfo(MTLPixelFormatInvalid,NULL,NULL,NULL));
 printf("PASS typed storage and sampling views pixels=%u\n",checked);return 0;
}}
