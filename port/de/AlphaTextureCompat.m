// A8 render targets on Simulator: preserve alpha in RGBA8 and expose (0,0,0,a)
// to shaders. Other storage-transfer operations remain explicit boundaries.
#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include "UnsupportedBoundary.h"
@interface DEAlphaTexture : NSProxy
@property(nonatomic,strong) id<MTLTexture> backing;
@property(nonatomic,strong) id<MTLTexture> sampled;
@end
@implementation DEAlphaTexture
- (MTLPixelFormat)pixelFormat{return MTLPixelFormatA8Unorm;}
- (NSMethodSignature*)methodSignatureForSelector:(SEL)s{return [(NSObject*)self.backing methodSignatureForSelector:s];}
- (BOOL)respondsToSelector:(SEL)s{return s==@selector(pixelFormat)||[self.backing respondsToSelector:s];}
- (void)forwardInvocation:(NSInvocation*)inv{
 NSString*s=NSStringFromSelector(inv.selector);
 if([s hasPrefix:@"replaceRegion:"]||[s hasPrefix:@"getBytes:"]||[s hasPrefix:@"newTextureView"]||[s isEqualToString:@"newSharedTextureHandle"])DEUnsupported("A8 texture transfer/view not qualified");
 [inv invokeWithTarget:self.backing];
}
@end
static BOOL DEIsAlpha(id value){return value&&object_getClass(value)==DEAlphaTexture.class;}
static id DEAlphaSample(id value){return DEIsAlpha(value)?((DEAlphaTexture*)value).sampled:value;}
static id DEAlphaResource(id value){return DEIsAlpha(value)?((DEAlphaTexture*)value).backing:value;}
static MTLRenderPassDescriptor*DEAlphaRenderPass(MTLRenderPassDescriptor*input){
 MTLRenderPassDescriptor*result=input;
 for(NSUInteger i=0;i<8;i++){
  id tex=input.colorAttachments[i].texture,resolve=input.colorAttachments[i].resolveTexture;
  if(DEIsAlpha(tex)||DEIsAlpha(resolve)){
   if(result==input)result=[input copy];
   if(DEIsAlpha(tex))result.colorAttachments[i].texture=DEAlphaResource(tex);
   if(DEIsAlpha(resolve))DEUnsupported("A8 MSAA resolve not qualified");
  }
 }
 return result;
}
static MTLRenderPipelineDescriptor*DEAlphaPipeline(MTLRenderPipelineDescriptor*input){
 if(!getenv("AGEPAD_ALPHA_RENDER_TARGET"))return input;
 MTLRenderPipelineDescriptor*result=input;
 for(NSUInteger i=0;i<8;i++)if(input.colorAttachments[i].pixelFormat==MTLPixelFormatA8Unorm){
  if(result==input)result=[input copy];
  MTLRenderPipelineColorAttachmentDescriptor*a=input.colorAttachments[i];
  fprintf(stderr,"DE_ALPHA_PIPELINE attachment=%lu mask=%lu blend=%d srcA=%lu dstA=%lu opA=%lu sampleCount=%lu fragment=%s\n",(unsigned long)i,(unsigned long)a.writeMask,a.blendingEnabled,(unsigned long)a.sourceAlphaBlendFactor,(unsigned long)a.destinationAlphaBlendFactor,(unsigned long)a.alphaBlendOperation,(unsigned long)input.rasterSampleCount,input.fragmentFunction.name.UTF8String);
  if(input.rasterSampleCount!=1)DEUnsupported("A8 multisample pipeline not qualified");
  result.colorAttachments[i].pixelFormat=MTLPixelFormatRGBA8Unorm;
 }
 return result;
}
static IMP DEOriginalAlphaPipeline,DEOriginalAlphaPipelineOptions;
typedef id (*DEAlphaPipelineFactory)(id,SEL,id,NSError**) NS_RETURNS_RETAINED;
typedef id (*DEAlphaPipelineOptionsFactory)(id,SEL,id,MTLPipelineOption,MTLRenderPipelineReflection**,NSError**) NS_RETURNS_RETAINED;
static id DECreateAlphaPipeline(id device,SEL sel,MTLRenderPipelineDescriptor*p,NSError**error) NS_RETURNS_RETAINED;
static id DECreateAlphaPipeline(id device,SEL sel,MTLRenderPipelineDescriptor*p,NSError**error){if(!DEAppImageCaller(__builtin_return_address(0)))return ((DEAlphaPipelineFactory)DEOriginalAlphaPipeline)(device,sel,p,error);id state=((DEAlphaPipelineFactory)DEOriginalAlphaPipeline)(device,sel,DEAlphaPipeline(p),error);if(getenv("AGEPAD_GEOMETRY_TRACE"))fprintf(stderr,"DE_GEOMETRY_PIPELINE state=%p vertex=%s fragment=%s\n",state,p.vertexFunction.name.UTF8String,p.fragmentFunction.name.UTF8String);return state;}
static id DECreateAlphaPipelineOptions(id device,SEL sel,MTLRenderPipelineDescriptor*p,MTLPipelineOption opts,MTLRenderPipelineReflection**reflection,NSError**error) NS_RETURNS_RETAINED;
static id DECreateAlphaPipelineOptions(id device,SEL sel,MTLRenderPipelineDescriptor*p,MTLPipelineOption opts,MTLRenderPipelineReflection**reflection,NSError**error){return ((DEAlphaPipelineOptionsFactory)DEOriginalAlphaPipelineOptions)(device,sel,DEAppImageCaller(__builtin_return_address(0))?DEAlphaPipeline(p):p,opts,reflection,error);}
static void DEInstallAlphaPipeline(id<MTLDevice>device){
 if(!getenv("AGEPAD_ALPHA_RENDER_TARGET")||DEOriginalAlphaPipeline)return;
 Class cls=object_getClass(device);SEL selectors[]={@selector(newRenderPipelineStateWithDescriptor:error:),@selector(newRenderPipelineStateWithDescriptor:options:reflection:error:)};
 IMP replacements[]={(IMP)DECreateAlphaPipeline,(IMP)DECreateAlphaPipelineOptions};IMP*originals[]={&DEOriginalAlphaPipeline,&DEOriginalAlphaPipelineOptions};
 for(int i=0;i<2;i++){Method m=class_getInstanceMethod(cls,selectors[i]);if(!m)DEUnsupported("A8 pipeline factory absent");*originals[i]=method_getImplementation(m);class_replaceMethod(cls,selectors[i],replacements[i],method_getTypeEncoding(m));}
}
