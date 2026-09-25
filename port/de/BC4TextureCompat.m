#include <string.h>
#include <execinfo.h>
// Experimental BC4 UNORM texture/upload compatibility; gated separately from
// hardware capabilities. Unknown compressed operations fail explicitly.
#include "AlphaTextureCompat.m"
#include "CubeArrayTextureCompat.m"
#include "BC4MetalDecode.m"
#include "BC7MetalDecode.m"
#include "BCMetalDecode.m"
#include "BCFormat.h"
#include "MetalCaptureCompat.m"
static DEBCMetalDecoder *DEAllBCDecoder;
static DEBC7MetalDecoder *DEBC7Decoder;
#import <objc/message.h>
@interface DEBC4Texture : NSProxy
@property(nonatomic,strong) id<MTLTexture> backing;
@property(nonatomic) MTLPixelFormat logicalFormat;
@property(nonatomic,strong) id<MTLTexture> sampled;
@property(nonatomic) BOOL allFormats;
@end
@implementation DEBC4Texture
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s { return [(NSObject *)self.backing methodSignatureForSelector:s]; }
- (void)forwardInvocation:(NSInvocation *)inv {
 NSString *s=NSStringFromSelector(inv.selector);
 if([s hasPrefix:@"replaceRegion:"] || [s hasPrefix:@"getBytes:"] || [s hasPrefix:@"newTextureView"] || [s isEqualToString:@"newSharedTextureHandle"])
  DEUnsupported(s.UTF8String);
 [inv invokeWithTarget:self.backing];
}
- (MTLPixelFormat)pixelFormat { return self.logicalFormat ?: MTLPixelFormatBC4_RUnorm; }
- (id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)format {
 return [self newTextureViewWithPixelFormat:format textureType:MTLTextureType2D levels:NSMakeRange(0,self.backing.mipmapLevelCount) slices:NSMakeRange(0,1)];
}
- (id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)format textureType:(MTLTextureType)type levels:(NSRange)levels slices:(NSRange)slices {
 DEBCFormat from,to;MTLPixelFormat storage,sample;
 if(!self.allFormats||type!=MTLTextureType2D||slices.location||slices.length!=1||!levels.length||levels.location>self.backing.mipmapLevelCount||levels.length>self.backing.mipmapLevelCount-levels.location||
    !DEBCFormatInfo(self.logicalFormat,&from,NULL,NULL)||!DEBCFormatInfo(format,&to,&storage,&sample)||from!=to)return nil;
 id<MTLTexture> actual=[self.backing newTextureViewWithPixelFormat:storage textureType:type levels:levels slices:slices];if(!actual)return nil;
 id<MTLTexture> sampled=[actual newTextureViewWithPixelFormat:sample];if(!sampled)return nil;
 DEBC4Texture *view=[DEBC4Texture alloc];view.backing=actual;view.sampled=sampled;view.logicalFormat=format;view.allFormats=YES;return (id)view;
}
- (BOOL)respondsToSelector:(SEL)s { return s==@selector(pixelFormat) || [self.backing respondsToSelector:s]; }
@end
static BOOL DEIsBC4(id value) { return value && object_getClass(value)==DEBC4Texture.class; }
static id DEBCSample(DEBC4Texture *value) { return value.sampled?:value.backing; }
@interface DEBC4Encoder : NSProxy
@property(nonatomic,strong) id target;
@property(nonatomic,strong) id<MTLCommandBuffer> command;
@property(nonatomic,strong) DEBC4MetalDecoder *decoder;
@property(nonatomic) BOOL blit;
@property(nonatomic) BOOL geometryTrace;
@end
// Single-resource bindings share exactly the array path's storage/sample policy.
static id DEEncoderBinding(id value,BOOL sampled) {
 if(DEIsCubeArray(value)) {
  if(sampled)DEUnsupported("cube-array shader sampling not translated");
  return DECubeArrayStorage(value);
 }
 if(DEIsBC4(value))return sampled?DEBCSample(value):((DEBC4Texture *)value).backing;
 if(DEIsAlpha(value))return sampled?DEAlphaSample(value):DEAlphaResource(value);
 return value;
}
static IMP DEOriginalBlitDescriptorFactory,DEOriginalBlitFactory,DEOriginalComputeFactory,DEOriginalRenderFactory;
@implementation DEBC4Encoder
// These APIs contain no textures or resource arrays to translate. Let the
// Objective-C runtime forward them without constructing NSInvocation objects.
// Keep diagnostics on the existing path so viewport/constant tracing survives.
- (id)forwardingTargetForSelector:(SEL)s {
 static BOOL geometryDiagnostics;static dispatch_once_t once;
 dispatch_once(&once,^{geometryDiagnostics=getenv("AGEPAD_GEOMETRY_TRACE")!=NULL;});
 if(geometryDiagnostics || self.geometryTrace)return nil;
 if(s==@selector(setVertexBuffer:offset:atIndex:) ||
    s==@selector(setFragmentBuffer:offset:atIndex:) ||
    s==@selector(setVertexBufferOffset:atIndex:) ||
    s==@selector(setFragmentBufferOffset:atIndex:) ||
    s==@selector(setVertexBytes:length:atIndex:) ||
    s==@selector(setFragmentBytes:length:atIndex:) ||
    s==@selector(setFragmentSamplerStates:withRange:) ||
    s==@selector(setVertexSamplerStates:withRange:) ||
    s==@selector(setSamplerStates:withRange:) ||
    s==@selector(setBlendColorRed:green:blue:alpha:) ||
    s==@selector(setStencilReferenceValue:) ||
    s==@selector(setFragmentSamplerState:atIndex:) ||
    s==@selector(setVertexSamplerState:atIndex:) ||
    s==@selector(setSamplerState:atIndex:) ||
    s==@selector(setFragmentSamplerState:lodMinClamp:lodMaxClamp:atIndex:) ||
    s==@selector(setVertexSamplerState:lodMinClamp:lodMaxClamp:atIndex:) ||
    s==@selector(setSamplerState:lodMinClamp:lodMaxClamp:atIndex:) ||
    s==@selector(setVertexBuffers:offsets:withRange:) ||
    s==@selector(setFragmentBuffers:offsets:withRange:) ||
    s==@selector(setBuffers:offsets:withRange:) ||
    s==@selector(setRenderPipelineState:) ||
    s==@selector(setDepthStencilState:) ||
    s==@selector(setViewport:) || s==@selector(setViewports:count:) ||
    s==@selector(setScissorRect:) || s==@selector(setScissorRects:count:) ||
    s==@selector(setCullMode:) || s==@selector(setFrontFacingWinding:) ||
    s==@selector(setTriangleFillMode:) || s==@selector(setDepthClipMode:) ||
    s==@selector(setDepthBias:slopeScale:clamp:) ||
    s==@selector(drawPrimitives:vertexStart:vertexCount:) ||
    s==@selector(drawPrimitives:vertexStart:vertexCount:instanceCount:) ||
    s==@selector(drawPrimitives:vertexStart:vertexCount:instanceCount:baseInstance:) ||
    s==@selector(drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:) ||
    s==@selector(drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:) ||
    s==@selector(drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:) ||
    s==@selector(setBuffer:offset:atIndex:) || s==@selector(setBufferOffset:atIndex:) ||
    s==@selector(setBytes:length:atIndex:) || s==@selector(setComputePipelineState:) ||
    s==@selector(dispatchThreadgroups:threadsPerThreadgroup:) ||
    s==@selector(dispatchThreads:threadsPerThreadgroup:) || s==@selector(endEncoding))return self.target;
 return nil;
}
- (void)setFragmentTexture:(id<MTLTexture>)texture atIndex:(NSUInteger)index {
 [(id<MTLRenderCommandEncoder>)self.target setFragmentTexture:DEEncoderBinding(texture,YES) atIndex:index];
}
- (void)setVertexTexture:(id<MTLTexture>)texture atIndex:(NSUInteger)index {
 [(id<MTLRenderCommandEncoder>)self.target setVertexTexture:DEEncoderBinding(texture,YES) atIndex:index];
}
- (void)setTexture:(id<MTLTexture>)texture atIndex:(NSUInteger)index {
 [(id<MTLComputeCommandEncoder>)self.target setTexture:DEEncoderBinding(texture,YES) atIndex:index];
}
- (void)useResource:(id<MTLResource>)resource usage:(MTLResourceUsage)usage {
 [(id<MTLComputeCommandEncoder>)self.target useResource:DEEncoderBinding(resource,NO) usage:usage];
}
- (void)useResource:(id<MTLResource>)resource usage:(MTLResourceUsage)usage stages:(MTLRenderStages)stages {
 [(id<MTLRenderCommandEncoder>)self.target useResource:DEEncoderBinding(resource,NO) usage:usage stages:stages];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s { return [self.target methodSignatureForSelector:s]; }
- (BOOL)respondsToSelector:(SEL)s { return [self.target respondsToSelector:s]; }
- (void)forwardInvocation:(NSInvocation *)inv {
 if(getenv("AGEPAD_GEOMETRY_TRACE") && inv.selector==@selector(setViewport:)) {
  MTLViewport v;[inv getArgument:&v atIndex:2];
  if(v.originX!=0 || v.originY!=0){static unsigned traces=0;if(traces++<3){void*frames[32];int n=backtrace(frames,32);fprintf(stderr,"DE_GEOMETRY_OFFSET_VIEWPORT encoder=%p x=%g y=%g w=%g h=%g\n",self,v.originX,v.originY,v.width,v.height);backtrace_symbols_fd(frames,n,2);self.geometryTrace=YES;}}

  static double epoch=0;double now=NSProcessInfo.processInfo.systemUptime;if(now-epoch>2)epoch=now;if(now-epoch<0.05)fprintf(stderr,"DE_GEOMETRY_VIEWPORT x=%g y=%g w=%g h=%g near=%g far=%g\n",v.originX,v.originY,v.width,v.height,v.znear,v.zfar);
 }
 if(self.geometryTrace && (inv.selector==@selector(setVertexBytes:length:atIndex:) || inv.selector==@selector(setFragmentBytes:length:atIndex:))) {
  const void *bytes=NULL;NSUInteger length=0,index=0;[inv getArgument:&bytes atIndex:2];[inv getArgument:&length atIndex:3];[inv getArgument:&index atIndex:4];
  fprintf(stderr,"DE_GEOMETRY_BYTES encoder=%p selector=%s index=%lu length=%lu floats=",self,sel_getName(inv.selector),(unsigned long)index,(unsigned long)length);
  for(NSUInteger i=0;bytes && i<MIN(length/4,32);i++){float v;memcpy(&v,(const char*)bytes+i*4,4);fprintf(stderr,"%g,",v);}fprintf(stderr,"\n");
 }
 if(self.geometryTrace && inv.selector==@selector(setRenderPipelineState:)) {__unsafe_unretained id state;[inv getArgument:&state atIndex:2];fprintf(stderr,"DE_GEOMETRY_PIPELINE_BIND encoder=%p pipeline=%p\n",self,state);}
 // Shader/resource bindings use actual backing textures, preserving index ranges.
 const char *selectorName=sel_getName(inv.selector);
 BOOL textureArray=strstr(selectorName,"Textures:")!=NULL;
 BOOL resourceArray=strstr(selectorName,"Resources:")!=NULL;
 NSString *name=NSStringFromSelector(inv.selector);
 if(textureArray || resourceArray) {
  NSUInteger count=0;
  if([@[@"setTextures:withRange:",@"setFragmentTextures:withRange:",@"setVertexTextures:withRange:",@"setTileTextures:withRange:",@"setObjectTextures:withRange:",@"setMeshTextures:withRange:"] containsObject:name]) {
   NSRange range;[inv getArgument:&range atIndex:3];count=range.length;
  } else if([name isEqualToString:@"useResources:count:usage:"] || [name isEqualToString:@"useResources:count:usage:stages:"]) [inv getArgument:&count atIndex:3];
  else DEUnsupported(name.UTF8String);
  __unsafe_unretained id *input=NULL;[inv getArgument:&input atIndex:2];
  if(count && !input)DEUnsupported("null resource array with nonzero count");
  if(count>SIZE_MAX/sizeof(id))DEUnsupported("resource array count overflow");
  __unsafe_unretained id *mapped=(__unsafe_unretained id *)calloc(count?:1,sizeof(id));
  if(!mapped)DEUnsupported("resource array allocation failed");
  NSUInteger converted=0;for(NSUInteger i=0;i<count;i++){id v=input[i];if(DEIsCubeArray(v)){if(textureArray)DEUnsupported("cube-array shader sampling not translated");mapped[i]=DECubeArrayStorage(v);converted++;}else if(DEIsBC4(v)){mapped[i]=textureArray?DEBCSample(v):((DEBC4Texture *)v).backing;converted++;}else if(DEIsAlpha(v)){mapped[i]=textureArray?DEAlphaSample(v):DEAlphaResource(v);converted++;}else mapped[i]=v;}
  [inv setArgument:&mapped atIndex:2];
  if(getenv("AGEPAD_RESOURCE_BINDING_TRACE"))
   fprintf(stderr,"DE_BC4_RESOURCE_ARRAY selector=%s count=%lu converted=%lu\n",name.UTF8String,(unsigned long)count,(unsigned long)converted);
  @try{[inv invokeWithTarget:self.target];}@finally{free(mapped);}return;
 }
 for(NSUInteger i=2;i<inv.methodSignature.numberOfArguments;i++) {
  const char *type=[inv.methodSignature getArgumentTypeAtIndex:i];
  if(type[0]=='@') {__unsafe_unretained id v=nil;[inv getArgument:&v atIndex:i];if(DEIsCubeArray(v)){if(!self.blit && ![name hasPrefix:@"useResource:"])DEUnsupported("cube-array shader sampling not translated");id backing=DECubeArrayStorage(v);[inv setArgument:&backing atIndex:i];}}
  if(type[0]=='@') {__unsafe_unretained id v=nil;[inv getArgument:&v atIndex:i];if(DEIsBC4(v)) {if(![name hasPrefix:@"setFragmentTexture:"] && ![name hasPrefix:@"setVertexTexture:"] && ![name hasPrefix:@"setTexture:"] && ![name hasPrefix:@"useResource:"])DEUnsupported(name.UTF8String);id backing=[name hasPrefix:@"useResource:"]?((DEBC4Texture *)v).backing:DEBCSample(v);[inv setArgument:&backing atIndex:i];}else if(DEIsAlpha(v)){if(![name hasPrefix:@"setFragmentTexture:"] && ![name hasPrefix:@"setVertexTexture:"] && ![name hasPrefix:@"setTexture:"] && ![name hasPrefix:@"useResource:"])DEUnsupported("A8 texture encoder operation not qualified");id mapped=[name hasPrefix:@"useResource:"]?DEAlphaResource(v):DEAlphaSample(v);[inv setArgument:&mapped atIndex:i];}}
 }
 [inv invokeWithTarget:self.target];
}
- (void)copyFromBuffer:(id<MTLBuffer>)source sourceOffset:(NSUInteger)offset sourceBytesPerRow:(NSUInteger)stride sourceBytesPerImage:(NSUInteger)imageStride sourceSize:(MTLSize)size toTexture:(id<MTLTexture>)destination destinationSlice:(NSUInteger)slice destinationLevel:(NSUInteger)level destinationOrigin:(MTLOrigin)origin options:(MTLBlitOption)options {
 if(DEIsCubeArray(destination))destination=DECubeArrayStorage(destination);
 if(DEIsAlpha(destination))DEUnsupported("A8 buffer upload not qualified");
 if(!DEIsBC4(destination)) {
  [(id<MTLBlitCommandEncoder>)self.target copyFromBuffer:source sourceOffset:offset sourceBytesPerRow:stride sourceBytesPerImage:imageStride sourceSize:size toTexture:destination destinationSlice:slice destinationLevel:level destinationOrigin:origin options:options];return;
 }
 fprintf(stderr,"DE_BC4_UPLOAD_OPTIONS value=%lu\n",(unsigned long)options);
 if(options!=MTLBlitOptionNone)DEUnsupported("BC4 upload options require explicit semantics");
 [self copyFromBuffer:source sourceOffset:offset sourceBytesPerRow:stride sourceBytesPerImage:imageStride sourceSize:size toTexture:destination destinationSlice:slice destinationLevel:level destinationOrigin:origin];
}
- (void)copyFromBuffer:(id<MTLBuffer>)source sourceOffset:(NSUInteger)offset sourceBytesPerRow:(NSUInteger)stride sourceBytesPerImage:(NSUInteger)imageStride sourceSize:(MTLSize)size toTexture:(id<MTLTexture>)destination destinationSlice:(NSUInteger)slice destinationLevel:(NSUInteger)level destinationOrigin:(MTLOrigin)origin {
 if(DEIsCubeArray(destination))destination=DECubeArrayStorage(destination);
 if(DEIsAlpha(destination))DEUnsupported("A8 buffer upload not qualified");
 if(!DEIsBC4(destination)) {
  [(id<MTLBlitCommandEncoder>)self.target copyFromBuffer:source sourceOffset:offset sourceBytesPerRow:stride sourceBytesPerImage:imageStride sourceSize:size toTexture:destination destinationSlice:slice destinationLevel:level destinationOrigin:origin];return;
 }
 id<MTLTexture> backing=((DEBC4Texture *)destination).backing;
 if(!self.blit || slice || level>=backing.mipmapLevelCount || size.depth!=1)DEUnsupported("compressed upload requires valid 2D mip and slice0");
 id<MTLTexture> target=backing;
 if(level){target=[backing newTextureViewWithPixelFormat:backing.pixelFormat textureType:MTLTextureType2D levels:NSMakeRange(level,1) slices:NSMakeRange(0,1)];if(!target)DEUnsupported("compressed mip view unavailable");}
 fprintf(stderr,"DE_COMPRESSED_UPLOAD_TARGET level=%lu width=%lu height=%lu retainedReferences=%d\n",(unsigned long)level,(unsigned long)target.width,(unsigned long)target.height,self.command.retainedReferences);
 // The game cannot retain this adapter-created mip view. Keep it alive until
 // execution completes even when its command buffer uses unretained resources.
 if(level && !self.command.retainedReferences) {
  [self.command addCompletedHandler:^(id<MTLCommandBuffer> completed) {
   (void)completed; (void)[target pixelFormat];
  }];
 }
 [(id<MTLBlitCommandEncoder>)self.target endEncoding];
 NSError *error=nil;
 BOOL isBC7=((DEBC4Texture *)destination).pixelFormat==MTLPixelFormatBC7_RGBAUnorm;
 BOOL encoded;
 if(((DEBC4Texture *)destination).allFormats) {
  DEBCFormat format;if(!DEBCFormatInfo(destination.pixelFormat,&format,NULL,NULL)||!DEAllBCDecoder)DEUnsupported("BC format decoder unavailable");
  encoded=[DEAllBCDecoder encodeFormat:format command:self.command source:source offset:offset bytesPerRow:stride destination:target origin:origin size:size error:&error];
 } else encoded=isBC7?[DEBC7Decoder encodeTo:self.command source:source offset:offset bytesPerRow:stride destination:target origin:origin size:size error:&error]:[self.decoder encodeTo:self.command source:source offset:offset bytesPerRow:stride destination:target origin:origin size:size error:&error];
 if(!encoded) {
  fprintf(stderr,"DE_BC4_UPLOAD_ERROR %s\n",error.description.UTF8String);DEUnsupported("BC4 decode encoding failed");
 }
 self.target=((id(*)(id,SEL))DEOriginalBlitFactory)(self.command,@selector(blitCommandEncoder));
 if(!self.target)DEUnsupported("BC4 continuation blit encoder unavailable");
 fprintf(stderr,"DE_COMPRESSED_UPLOAD format=%s\n",isBC7?"BC7_RGBA":"BC4_R");
 fprintf(stderr,"DE_BC4_UPLOAD_ENCODED width=%lu height=%lu stride=%lu\n",(unsigned long)size.width,(unsigned long)size.height,(unsigned long)stride);
}
@end
static DEBC4MetalDecoder *DEBC4Decoder;
static id DEWrapEncoder(id target,id command,BOOL blit) {
 if(!target)return nil;if(getenv("AGEPAD_COMMAND_TRACE"))fprintf(stderr,"DE_ENCODER_WRAPPED class=%s blit=%d\n",object_getClassName(target),blit);DEBC4Encoder *proxy=[DEBC4Encoder alloc];proxy.target=target;proxy.command=command;proxy.decoder=DEBC4Decoder;proxy.blit=blit;return proxy;
}
static id DEBC4BlitFactory(id command,SEL selector) {
 id encoder=((id(*)(id,SEL))DEOriginalBlitFactory)(command,selector);
 return DEAppImageCaller(__builtin_return_address(0))?DEWrapEncoder(encoder,command,YES):encoder;
}
static id DEBC4ComputeFactory(id command,SEL selector) {
 id encoder=((id(*)(id,SEL))DEOriginalComputeFactory)(command,selector);
 return DEAppImageCaller(__builtin_return_address(0))?DEWrapEncoder(encoder,command,NO):encoder;
}
static id DEBC4RenderFactory(id command,SEL selector,MTLRenderPassDescriptor *descriptor) {
 if(!DEAppImageCaller(__builtin_return_address(0)))return ((id(*)(id,SEL,id))DEOriginalRenderFactory)(command,selector,descriptor);
 DEBC4Encoder *proxy=DEWrapEncoder(((id(*)(id,SEL,id))DEOriginalRenderFactory)(command,selector,DEAlphaRenderPass(descriptor)),command,NO);
 if(getenv("AGEPAD_GEOMETRY_TRACE")){static double epoch=0;double now=NSProcessInfo.processInfo.systemUptime;if(now-epoch>2)epoch=now;proxy.geometryTrace=now-epoch<0.05;
 if(proxy.geometryTrace){id<MTLTexture> t=descriptor.colorAttachments[0].texture;fprintf(stderr,"DE_GEOMETRY_PASS encoder=%p texture=%p w=%lu h=%lu framebufferOnly=%d load=%lu store=%lu\n",proxy,t,(unsigned long)t.width,(unsigned long)t.height,t.framebufferOnly,(unsigned long)descriptor.colorAttachments[0].loadAction,(unsigned long)descriptor.colorAttachments[0].storeAction);}}
 return proxy;
}
static id DEBC4BlitDescriptorFactory(id command,SEL selector,id descriptor) {
 id encoder=((id(*)(id,SEL,id))DEOriginalBlitDescriptorFactory)(command,selector,descriptor);
 return DEAppImageCaller(__builtin_return_address(0))?DEWrapEncoder(encoder,command,YES):encoder;
}
static IMP DEOriginalCommit;
static void DETraceCommit(id<MTLCommandBuffer> command,SEL selector) {
 fprintf(stderr,"DE_METAL_COMMIT command=%p status=%lu\n",command,(unsigned long)command.status);
 [command addCompletedHandler:^(id<MTLCommandBuffer> completed){fprintf(stderr,"DE_METAL_COMPLETED command=%p status=%lu error=%s\n",completed,(unsigned long)completed.status,completed.error.description.UTF8String?:"none");}];
 ((void(*)(id,SEL))DEOriginalCommit)(command,selector);
}
static void DEInstallBC4(id<MTLDevice>device) {
 DEInstallGameCapture(device);
 if(getenv("AGEPAD_SOFTWARE_BC_ALL")&&!DEAllBCDecoder){NSError *error=nil;DEAllBCDecoder=[[DEBCMetalDecoder alloc]initWithDevice:device error:&error];if(!DEAllBCDecoder)DEUnsupported(error.description.UTF8String);}
 // Encoder wrapping is also required without software BC: A8 render-target
 // stand-ins (AGEPAD_ALPHA_RENDER_TARGET) must be swapped for their real
 // textures in render passes and bindings before reaching the GPU driver.
 // On the M2 iPad, the stand-in reached the driver unwrapped when a skirmish
 // started and AGX faulted in renderCommandEncoderWithDescriptor:.
 BOOL softwareBC=getenv("AGEPAD_SOFTWARE_BC4")||getenv("AGEPAD_SOFTWARE_BC_ALL");
 static BOOL encodersWrapped;
 if((!softwareBC && !getenv("AGEPAD_ALPHA_RENDER_TARGET")) || encodersWrapped)return;
 encodersWrapped=YES;
 NSError *error=nil;
 if(softwareBC){
  DEBC4Decoder=[[DEBC4MetalDecoder alloc]initWithDevice:device error:&error];
  if(!DEBC4Decoder){fprintf(stderr,"DE_BC4_COMPILE_ERROR %s\n",error.description.UTF8String);DEUnsupported("BC4 decoder compilation");}
  if(getenv("AGEPAD_SOFTWARE_BC7")){DEBC7Decoder=[[DEBC7MetalDecoder alloc]initWithDevice:device error:&error];if(!DEBC7Decoder)DEUnsupported(error.description.UTF8String);}
 }
 id<MTLCommandQueue>q=[device newCommandQueue];id<MTLCommandBuffer>cb=[q commandBuffer];Class cls=object_getClass(cb);
 SEL selectors[]={@selector(blitCommandEncoder),@selector(computeCommandEncoder),@selector(renderCommandEncoderWithDescriptor:)};
 IMP replacements[]={(IMP)DEBC4BlitFactory,(IMP)DEBC4ComputeFactory,(IMP)DEBC4RenderFactory};IMP *originals[]={&DEOriginalBlitFactory,&DEOriginalComputeFactory,&DEOriginalRenderFactory};
 for(int i=0;i<3;i++){Method m=class_getInstanceMethod(cls,selectors[i]);if(!m)DEUnsupported("BC4 encoder factory missing");*originals[i]=method_getImplementation(m);class_replaceMethod(cls,selectors[i],replacements[i],method_getTypeEncoding(m));}
 {SEL sel=@selector(blitCommandEncoderWithDescriptor:);Method m=class_getInstanceMethod(cls,sel);if(m){DEOriginalBlitDescriptorFactory=method_getImplementation(m);class_replaceMethod(cls,sel,(IMP)DEBC4BlitDescriptorFactory,method_getTypeEncoding(m));}}
 if(getenv("AGEPAD_COMMAND_TRACE")){Method m=class_getInstanceMethod(cls,@selector(commit));DEOriginalCommit=method_getImplementation(m);class_replaceMethod(cls,@selector(commit),(IMP)DETraceCommit,method_getTypeEncoding(m));}
 fprintf(stderr,"DE_BC4_COMPAT_INSTALLED encoder wrapping; software_bc=%d\n",(int)softwareBC);
}
