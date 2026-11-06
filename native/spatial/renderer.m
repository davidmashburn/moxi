// Bounded D05 bridge continuation. No SceneKit, no production renderer claim.
#import "renderer.h"
#import "../macos_composition.h"
#import "../macos_metal.m"
#import "api.h"
#include <sys/resource.h>
@interface MSRenderer : NSObject
@property uint64_t owner, resource, serial, uploads, submissions;
@property id<MTLRenderPipelineState> pipeline;
@property id<MTLDepthStencilState> depthState;
@property id<MTLBuffer> vertices;
@property id<MTLTexture> color, depth;
@property size_t count;
@property(nonatomic) double cpu, encode, wait, gpu, readback, publication,
    total;
@end
@implementation MSRenderer
@end
static MSRenderer *renderers[32];
static uint64_t rendererIDs[32], nextRenderer = 1;
static double cpuSeconds(void) {
  struct rusage r;
  getrusage(RUSAGE_SELF, &r);
  return r.ru_utime.tv_sec + r.ru_stime.tv_sec +
         (r.ru_utime.tv_usec + r.ru_stime.tv_usec) / 1e6;
}
static MSRenderer *lookup(uint64_t handle) {
  if (!NSThread.isMainThread)
    return nil;
  for (int i = 0; i < 32; i++)
    if (rendererIDs[i] == handle && handle)
      return renderers[i];
  return nil;
}
uint64_t ms_renderer_create(uint64_t owner) {
  if (!NSThread.isMainThread || !nextRenderer)
    return 0;
  int slot = -1;
  for (int i = 0; i < 32; i++)
    if (!renderers[i]) {
      slot = i;
      break;
    }
  if (slot < 0)
    return 0;
  uint64_t resource = moxi_composition_acquire(owner);
  if (!resource)
    return 0;
  MSRenderer *r = [MSRenderer new];
  r.owner = owner;
  r.resource = resource;
  if (!moxi_metal_init(16, 16)) {
    moxi_composition_release(owner, resource);
    return 0;
  }
  NSError *error = nil;
  NSString *source =
      @"#include <metal_stdlib>\nusing namespace metal;\nstruct V{float4 "
      @"p;float4 c;};struct O{float4 p [[position]];float4 c;};vertex O v(uint "
      @"i [[vertex_id]],const device V*a [[buffer(0)]],constant float4x4&m "
      @"[[buffer(1)]]){O o;o.p=m*a[i].p;o.c=a[i].c;return o;}fragment float4 "
      @"f(O o [[stage_in]]){return o.c;}";
  id<MTLLibrary> library = [moxi_metal_device newLibraryWithSource:source
                                                           options:nil
                                                             error:&error];
  MTLRenderPipelineDescriptor *p = [MTLRenderPipelineDescriptor new];
  p.vertexFunction = [library newFunctionWithName:@"v"];
  p.fragmentFunction = [library newFunctionWithName:@"f"];
  p.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm_sRGB;
  p.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
  if (library)
    r.pipeline =
        [moxi_metal_device newRenderPipelineStateWithDescriptor:p error:&error];
  MTLDepthStencilDescriptor *d = [MTLDepthStencilDescriptor new];
  d.depthCompareFunction = MTLCompareFunctionLess;
  d.depthWriteEnabled = YES;
  r.depthState = [moxi_metal_device newDepthStencilStateWithDescriptor:d];
  if (!r.pipeline || !r.depthState) {
    moxi_composition_release(owner, resource);
    return 0;
  }
  renderers[slot] = r;
  rendererIDs[slot] = nextRenderer++;
  return rendererIDs[slot];
}
void ms_renderer_destroy(uint64_t handle) {
  for (int i = 0; i < 32; i++)
    if (rendererIDs[i] == handle && handle) {
      MSRenderer *r = renderers[i];
      moxi_composition_release(r.owner, r.resource);
      renderers[i] = nil;
      rendererIDs[i] = 0;
    }
}
int ms_renderer_frame(uint64_t handle, const void *vertices, size_t count,
                      int upload, const float *matrix, int width, int height,
                      int slot, float x, float y, float w, float h) {
  MSRenderer *r = lookup(handle);
  if (!r || count > 100000 || width < 1 || height < 1 || width > 2048 ||
      height > 2048 || !matrix)
    return 0;
  @autoreleasepool {
    double start = CACurrentMediaTime(), cpu = cpuSeconds();
    // A null vertices pointer means compose the already published snapshot.
    if (!vertices)
      return moxi_composition_compose(r.owner, r.resource, slot, x, y, w, h);
    if (upload) {
      r.vertices =
          [moxi_metal_device newBufferWithBytes:vertices
                                         length:MAX(count, 1) * 32
                                        options:MTLResourceStorageModeShared];
      r.count = count;
      if (!r.vertices)
        return 0;
      r.uploads++;
    }
    if (!r.color || r.color.width != (NSUInteger)width ||
        r.color.height != (NSUInteger)height) {
      MTLTextureDescriptor *t = [MTLTextureDescriptor
          texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB
                                       width:width
                                      height:height
                                   mipmapped:NO];
      t.usage = MTLTextureUsageRenderTarget;
      t.storageMode = MTLStorageModeShared;
      r.color = [moxi_metal_device newTextureWithDescriptor:t];
      t.pixelFormat = MTLPixelFormatDepth32Float;
      t.storageMode = MTLStorageModePrivate;
      r.depth = [moxi_metal_device newTextureWithDescriptor:t];
    }
    if (!r.color || !r.depth || !r.vertices)
      return 0;
    MTLRenderPassDescriptor *p = [MTLRenderPassDescriptor renderPassDescriptor];
    p.colorAttachments[0].texture = r.color;
    p.colorAttachments[0].loadAction = MTLLoadActionClear;
    p.colorAttachments[0].storeAction = MTLStoreActionStore;
    p.colorAttachments[0].clearColor = MTLClearColorMake(.018, .028, .045, 1);
    p.depthAttachment.texture = r.depth;
    p.depthAttachment.loadAction = MTLLoadActionClear;
    p.depthAttachment.storeAction = MTLStoreActionDontCare;
    p.depthAttachment.clearDepth = 1;
    id<MTLCommandBuffer> cmd = [moxi_metal_queue commandBuffer];
    id<MTLRenderCommandEncoder> e = [cmd renderCommandEncoderWithDescriptor:p];
    [e setRenderPipelineState:r.pipeline];
    [e setDepthStencilState:r.depthState];
    [e setCullMode:MTLCullModeNone];
    [e setVertexBuffer:r.vertices offset:0 atIndex:0];
    [e setVertexBytes:matrix length:64 atIndex:1];
    [e drawPrimitives:MTLPrimitiveTypeTriangle
          vertexStart:0
          vertexCount:r.count];
    [e endEncoding];
    double encoded = CACurrentMediaTime();
    [cmd commit];
    [cmd waitUntilCompleted];
    double done = CACurrentMediaTime();
    r.submissions++;
    if (cmd.status != MTLCommandBufferStatusCompleted)
      return 0;
    NSMutableData *data =
        [NSMutableData dataWithLength:(size_t)width * height * 4];
    [r.color getBytes:data.mutableBytes
          bytesPerRow:width * 4
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    double read = CACurrentMediaTime();
    // Opaque output: premultiplied sRGB and straight sRGB coincide. Background
    // alpha is exactly one; translucent material support is intentionally
    // absent.
    int ok =
        moxi_composition_publish(r.owner, r.resource, ++r.serial, data.bytes,
                                 data.length, width, height, width * 4) &&
        moxi_composition_compose(r.owner, r.resource, slot, x, y, w, h);
    double end = CACurrentMediaTime();
    r.cpu = (cpuSeconds() - cpu) * 1000;
    r.encode = (encoded - start) * 1000;
    r.wait = (done - encoded) * 1000;
    r.gpu = cmd.GPUEndTime > cmd.GPUStartTime
                ? (cmd.GPUEndTime - cmd.GPUStartTime) * 1000
                : NAN;
    r.readback = (read - done) * 1000;
    r.publication = (end - read) * 1000;
    r.total = (end - start) * 1000;
    return ok;
  }
}
uint64_t ms_renderer_metric(uint64_t handle, int metric) {
  MSRenderer *r = lookup(handle);
  return metric == MS_UPLOADS       ? r.uploads
         : metric == MS_SUBMISSIONS ? r.submissions
                                    : 0;
}
double ms_renderer_timing(uint64_t handle, int metric) {
  MSRenderer *r = lookup(handle);
  if (!r)
    return NAN;
  switch (metric) {
  case MS_CPU:
    return r.cpu;
  case MS_ENCODE:
    return r.encode;
  case MS_WAIT:
    return r.wait;
  case MS_GPU:
    return r.gpu;
  case MS_READBACK:
    return r.readback;
  case MS_PUBLICATION:
    return r.publication;
  case MS_TOTAL:
    return r.total;
  default:
    return NAN;
  }
}
