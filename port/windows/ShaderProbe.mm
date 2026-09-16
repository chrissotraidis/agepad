// Native component test: DXBC -> DXMT -> Metal library. No Windows execution.
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#include "airconv_public.h"
#include "fixture.h"

static NSString *probe() {
    sm50_shader_t shader = nullptr;
    sm50_error_t error = nullptr;
    MTL_SHADER_REFLECTION reflection{};
    int status = SM50Initialize(shader_fixture, sizeof(shader_fixture), &shader, &reflection, &error);
    sm50_bitcode_t compiled = nullptr;
    if (!status) status = SM50Compile(shader, nullptr, "agepad_vertex", &compiled, &error);
    if (status) {
        char message[4096]{};
        if (error) { SM50GetErrorMessage(error, message, sizeof(message)); SM50FreeError(error); }
        if (shader) SM50Destroy(shader);
        return [NSString stringWithFormat:@"FAIL: DXMT compile %d: %s", status, message];
    }
    SM50_COMPILED_BITCODE data{};
    SM50GetCompiledBitcode(compiled, &data);
    NSData *bytes = [NSData dataWithBytes:(const void *)data.Data length:data.Size];
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [bytes writeToFile:[documents stringByAppendingPathComponent:@"translated.metallib"] atomically:YES];
    dispatch_data_t dispatchBytes = dispatch_data_create(bytes.bytes, bytes.length, nullptr, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSError *metalError = nil;
    id<MTLLibrary> library = [device newLibraryWithData:dispatchBytes error:&metalError];
    NSString *result;
    if (!library) {
        result = [NSString stringWithFormat:@"FAIL: Metal rejected DXMT shader (%llu bytes): %@", data.Size, metalError];
    } else {
        id<MTLFunction> vertex = [library newFunctionWithName:@"agepad_vertex"];
        fprintf(stderr, "SHADER: vertex attributes %s\n", vertex.stageInputAttributes.description.UTF8String);
        NSString *fragmentSource = @"#include <metal_stdlib>\nusing namespace metal; fragment float4 probe_fragment() { return float4(1,0,0,1); }";
        id<MTLLibrary> fragmentLibrary = [device newLibraryWithSource:fragmentSource options:nil error:&metalError];
        MTLRenderPipelineDescriptor *pd = [MTLRenderPipelineDescriptor new];
        pd.vertexFunction = vertex;
        pd.fragmentFunction = [fragmentLibrary newFunctionWithName:@"probe_fragment"];
        pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        pd.vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
        pd.vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
        pd.vertexDescriptor.attributes[0].bufferIndex = 0;
        pd.vertexDescriptor.layouts[0].stride = 16;
        id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:pd error:&metalError];
        if (!pipeline) {
            result = [NSString stringWithFormat:@"FAIL: translated library accepted, render pipeline rejected: %@", metalError];
        } else {
            MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:64 mipmapped:NO];
            td.storageMode = MTLStorageModeShared;
            td.usage = MTLTextureUsageRenderTarget;
            id<MTLTexture> texture = [device newTextureWithDescriptor:td];
            MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = texture;
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].storeAction = MTLStoreActionStore;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1);
            id<MTLCommandQueue> queue = [device newCommandQueue];
            id<MTLCommandBuffer> command = [queue commandBuffer];
            id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
            const float vertices[] = {-1,-1,0,1, 1,-1,0,1, 0,1,0,1};
            [encoder setRenderPipelineState:pipeline];
            [encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
            [encoder endEncoding];
            [command commit];
            [command waitUntilCompleted];
            uint8_t pixel[4]{};
            [texture getBytes:pixel bytesPerRow:4 fromRegion:MTLRegionMake2D(32,32,1,1) mipmapLevel:0];
            bool passed = command.status == MTLCommandBufferStatusCompleted && pixel[0] == 255 && pixel[1] == 0 && pixel[2] == 0;
            result = [NSString stringWithFormat:@"%@: DXBC vertex shader translated and rendered by %@.\nCenter RGBA: %u,%u,%u,%u. GPU status: %lu %@\nNative test fragment shader; Windows/D3D11 runtime and DE untested.", passed ? @"PASS" : @"FAIL", device.name, pixel[0],pixel[1],pixel[2],pixel[3], (unsigned long)command.status, command.error ?: @""];
        }
    }
    SM50DestroyBitcode(compiled);
    SM50Destroy(shader);
    return result;
}

@interface ShaderDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ShaderDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    UITextView *text = [[UITextView alloc] initWithFrame:self.window.bounds];
    text.editable = NO;
    text.textContainerInset = UIEdgeInsetsMake(64, 20, 20, 20);
    text.font = [UIFont monospacedSystemFontOfSize:22 weight:UIFontWeightRegular];
    text.text = @"AgePad shader translation probe…";
    vc.view = text;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *result = probe();
        fprintf(stderr, "SHADER RESULT: %s\n", result.UTF8String);
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"result.txt"];
        [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{ text.text = result; });
    });
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ShaderDelegate.class)); }
}
