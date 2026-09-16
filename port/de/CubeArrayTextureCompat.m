// Cube-array storage over six 2D slices per cube. Sampling requires a shader
// translation and is deliberately rejected until that path is implemented.
#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include "UnsupportedBoundary.h"
@interface DECubeArrayTexture : NSProxy
@property(nonatomic,strong) id<MTLTexture> backing;
@end
@implementation DECubeArrayTexture
- (MTLTextureType)textureType { return MTLTextureTypeCubeArray; }
- (NSUInteger)arrayLength { return self.backing.arrayLength / 6; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)s { return [(NSObject *)self.backing methodSignatureForSelector:s]; }
- (BOOL)respondsToSelector:(SEL)s { return [self.backing respondsToSelector:s]; }
- (void)forwardInvocation:(NSInvocation *)inv {
 NSString *name=NSStringFromSelector(inv.selector);
 if([name hasPrefix:@"newTextureView"] || [name isEqualToString:@"newSharedTextureHandle"] || [name isEqualToString:@"gpuResourceID"])
  DEUnsupported("cube-array view/indirect binding requires explicit translation");
 [inv invokeWithTarget:self.backing];
}
- (id<MTLTexture>)newTextureViewWithPixelFormat:(MTLPixelFormat)format {
 id<MTLTexture> view=[self.backing newTextureViewWithPixelFormat:format];
 if(!view)return nil;
 DECubeArrayTexture *result=[DECubeArrayTexture alloc];result.backing=view;
 return (id<MTLTexture>)result;
}
@end
static BOOL DEIsCubeArray(id value) { return value && object_getClass(value)==DECubeArrayTexture.class; }
static id<MTLTexture> DECubeArrayStorage(id value) { return ((DECubeArrayTexture *)value).backing; }
