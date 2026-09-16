// Exercise the actual proxy, including bindings which must never fast-forward.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include "../port/de/BC4TextureCompat.m"
@interface DispatchTarget:NSObject
@property(nonatomic) NSUInteger calls,offset,index;
@property(nonatomic,strong) id value;
@property(nonatomic) MTLViewport viewport;
@property(nonatomic,strong) NSArray *values;
@property(nonatomic) NSRange range;
- (void)setVertexBuffer:(id)b offset:(NSUInteger)o atIndex:(NSUInteger)i;
- (void)setViewport:(MTLViewport)v;
- (void)setFragmentTexture:(id)t atIndex:(NSUInteger)i;
- (void)setFragmentTextures:(const id[])t withRange:(NSRange)r;
- (void)useResources:(const id[])r count:(NSUInteger)c usage:(MTLResourceUsage)u;
- (void)setFragmentSamplerStates:(const id[])s withRange:(NSRange)r;
@end
@implementation DispatchTarget
- (void)setVertexBuffer:(id)b offset:(NSUInteger)o atIndex:(NSUInteger)i{self.calls++;self.value=b;self.offset=o;self.index=i;}
- (void)setViewport:(MTLViewport)v{_viewport=v;}
- (void)setFragmentTexture:(id)t atIndex:(NSUInteger)i{self.value=t;self.index=i;}
- (void)setFragmentTextures:(const id[])t withRange:(NSRange)r{self.values=[NSArray arrayWithObjects:t count:r.length];self.range=r;}
- (void)setFragmentSamplerStates:(const id[])s withRange:(NSRange)r{self.values=[NSArray arrayWithObjects:s count:r.length];self.range=r;}
- (void)useResources:(const id[])r count:(NSUInteger)c usage:(MTLResourceUsage)u{self.values=[NSArray arrayWithObjects:r count:c];self.offset=u;}
@end
int main(void){@autoreleasepool{
 DispatchTarget *target=[DispatchTarget new];DEBC4Encoder *proxy=[DEBC4Encoder alloc];proxy.target=target;id<MTLRenderCommandEncoder>encoder=(id)proxy;
 id buffer=[NSObject new];CFTimeInterval start=CACurrentMediaTime();
 for(NSUInteger i=0;i<10000;i++){@autoreleasepool{[encoder setVertexBuffer:buffer offset:i atIndex:7];}}
 double seconds=CACurrentMediaTime()-start;
 assert(target.calls==10000 && target.value==buffer && target.offset==9999 && target.index==7);
 MTLViewport viewport={3,5,123,456,0.25,0.75};[encoder setViewport:viewport];MTLViewport actual=target.viewport;assert(!memcmp(&viewport,&actual,sizeof(viewport)));
 DEBC4Texture *bc=[DEBC4Texture alloc];bc.backing=(id)[NSObject new];bc.sampled=(id)[NSObject new];
 DEAlphaTexture *alpha=[DEAlphaTexture alloc];alpha.backing=(id)[NSObject new];alpha.sampled=(id)[NSObject new];
 DECubeArrayTexture *cube=[DECubeArrayTexture alloc];cube.backing=(id)[NSObject new];id plain=[NSObject new];
 assert([proxy forwardingTargetForSelector:@selector(setFragmentTexture:atIndex:)]==nil);
 assert([proxy forwardingTargetForSelector:@selector(useResources:count:usage:)]==nil);
 [encoder setFragmentTexture:(id)bc atIndex:9];assert(target.value==bc.sampled && target.index==9);
 [encoder setFragmentTexture:(id)alpha atIndex:3];assert(target.value==alpha.sampled && target.index==3);
 [encoder setFragmentTexture:nil atIndex:2];assert(target.value==nil && target.index==2);
 id samplers[]={[NSObject new],[NSObject new]};
 [encoder setFragmentSamplerStates:(const id<MTLSamplerState>*)samplers withRange:NSMakeRange(5,2)];
 assert(target.values[0]==samplers[0] && target.values[1]==samplers[1] && NSEqualRanges(target.range,NSMakeRange(5,2)));
 id textures[]={plain,bc,alpha};[encoder setFragmentTextures:(const id<MTLTexture>*)textures withRange:NSMakeRange(4,3)];
 assert(NSEqualRanges(target.range,NSMakeRange(4,3)) && target.values[0]==plain && target.values[1]==bc.sampled && target.values[2]==alpha.sampled);
 id resources[]={plain,bc,alpha,cube};[encoder useResources:(const id<MTLResource>*)resources count:4 usage:MTLResourceUsageRead];
 assert(target.values[0]==plain && target.values[1]==bc.backing && target.values[2]==alpha.backing && target.values[3]==cube.backing && target.offset==MTLResourceUsageRead);
 proxy.geometryTrace=YES;assert([proxy forwardingTargetForSelector:@selector(setVertexBuffer:offset:atIndex:)]==nil);
 [encoder setVertexBuffer:buffer offset:17 atIndex:6];assert(target.offset==17 && target.index==6);
 printf("{\"buffer_calls\":10000,\"seconds\":%.6f,\"texture_and_resource_mapping\":true,\"diagnostic_fallback\":true}\n",seconds);
}return 0;}
