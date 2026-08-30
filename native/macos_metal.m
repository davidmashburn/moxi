#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>

/*
 * A small scene renderer for the 0.6 GPU slice. It batches rectangles and
 * line quads into one shared MTLBuffer and one draw call per frame. The
 * surface is offscreen for now; a later AppKit/Metal layer adapter can attach
 * the same encoder to a CAMetalLayer without changing the Mojo scene API.
 */

#define MOXI_METAL_MAX_VERTICES 262144

typedef struct {
    vector_float2 position;
    vector_float4 color;
} MoxiMetalVertex;

static id<MTLDevice> moxi_metal_device;
static id<MTLCommandQueue> moxi_metal_queue;
static id<MTLRenderPipelineState> moxi_metal_pipeline;
static id<MTLTexture> moxi_metal_texture;
static id<MTLBuffer> moxi_metal_vertex_buffer;
static id<MTLCommandBuffer> moxi_metal_command_buffer;
static id<MTLRenderCommandEncoder> moxi_metal_encoder;
static MoxiMetalVertex *moxi_metal_vertices;
static int moxi_metal_width;
static int moxi_metal_height;
static int moxi_metal_vertex_count;
static int moxi_metal_overflow_count;
static int moxi_metal_frame_count;
static BOOL moxi_metal_initialized;

static const char *moxi_metal_shader_source =
    "#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct Vertex { float2 position; float4 color; };\n"
     "struct Raster { float4 position [[position]]; float4 color; };\n"
     "vertex Raster moxi_vertex(const device Vertex *vertices [[buffer(0)]], uint id [[vertex_id]]) {\n"
     "  Raster out; out.position = float4(vertices[id].position, 0.0, 1.0); out.color = vertices[id].color; return out;\n"
     "}\n"
     "fragment float4 moxi_fragment(Raster in [[stage_in]]) { return in.color; }\n";

static vector_float2 moxi_ndc(float x, float y) {
    return (vector_float2){
        (x / (float)moxi_metal_width) * 2.0f - 1.0f,
        1.0f - (y / (float)moxi_metal_height) * 2.0f,
    };
}

static MoxiMetalVertex moxi_vertex(float x, float y, const float color[4]) {
    MoxiMetalVertex result;
    result.position = moxi_ndc(x, y);
    result.color = (vector_float4){color[0], color[1], color[2], color[3]};
    return result;
}

static void moxi_append_triangle(
    MoxiMetalVertex first,
    MoxiMetalVertex second,
    MoxiMetalVertex third
) {
    if (moxi_metal_vertex_count + 3 > MOXI_METAL_MAX_VERTICES) {
        moxi_metal_overflow_count += 1;
        return;
    }
    moxi_metal_vertices[moxi_metal_vertex_count++] = first;
    moxi_metal_vertices[moxi_metal_vertex_count++] = second;
    moxi_metal_vertices[moxi_metal_vertex_count++] = third;
}

static void moxi_append_rect(float x, float y, float width, float height, const float color[4]) {
    if (width <= 0.0f || height <= 0.0f) {
        return;
    }
    MoxiMetalVertex top_left = moxi_vertex(x, y, color);
    MoxiMetalVertex top_right = moxi_vertex(x + width, y, color);
    MoxiMetalVertex bottom_left = moxi_vertex(x, y + height, color);
    MoxiMetalVertex bottom_right = moxi_vertex(x + width, y + height, color);
    moxi_append_triangle(top_left, top_right, bottom_left);
    moxi_append_triangle(bottom_left, top_right, bottom_right);
}

static void moxi_append_line(
    float x1,
    float y1,
    float x2,
    float y2,
    float width,
    const float color[4]
) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    float length = sqrtf(dx * dx + dy * dy);
    if (length <= 0.0f) {
        moxi_append_rect(x1 - width * 0.5f, y1 - width * 0.5f, width, width, color);
        return;
    }
    float half = width > 0.0f ? width * 0.5f : 0.5f;
    float nx = -dy / length * half;
    float ny = dx / length * half;
    MoxiMetalVertex a = moxi_vertex(x1 + nx, y1 + ny, color);
    MoxiMetalVertex b = moxi_vertex(x2 + nx, y2 + ny, color);
    MoxiMetalVertex c = moxi_vertex(x1 - nx, y1 - ny, color);
    MoxiMetalVertex d = moxi_vertex(x2 - nx, y2 - ny, color);
    moxi_append_triangle(a, b, c);
    moxi_append_triangle(c, b, d);
}

static BOOL moxi_metal_make_pipeline(void) {
    if (moxi_metal_device == nil) {
        return NO;
    }
    NSError *error = nil;
    NSString *source = [NSString stringWithUTF8String:moxi_metal_shader_source];
    id<MTLLibrary> library = [moxi_metal_device newLibraryWithSource:source options:nil error:&error];
    if (library == nil) {
        return NO;
    }
    id<MTLFunction> vertex = [library newFunctionWithName:@"moxi_vertex"];
    id<MTLFunction> fragment = [library newFunctionWithName:@"moxi_fragment"];
    if (vertex == nil || fragment == nil) {
        return NO;
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertex;
    descriptor.fragmentFunction = fragment;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    moxi_metal_pipeline = [moxi_metal_device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    return moxi_metal_pipeline != nil;
}

static BOOL moxi_metal_make_texture(int width, int height) {
    if (moxi_metal_device == nil) {
        return NO;
    }
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                             width:(NSUInteger)width
                                                                                            height:(NSUInteger)height
                                                                                         mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    moxi_metal_texture = [moxi_metal_device newTextureWithDescriptor:descriptor];
    return moxi_metal_texture != nil;
}

int moxi_metal_available(void) {
    return MTLCreateSystemDefaultDevice() != nil ? 1 : 0;
}

int moxi_metal_init(int width, int height) {
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    moxi_metal_device = MTLCreateSystemDefaultDevice();
    if (moxi_metal_device == nil) return 0;
    moxi_metal_queue = [moxi_metal_device newCommandQueue];
    if (moxi_metal_queue == nil || !moxi_metal_make_pipeline()) return 0;
    moxi_metal_width = width;
    moxi_metal_height = height;
    if (!moxi_metal_make_texture(width, height)) return 0;
    moxi_metal_vertex_buffer = [moxi_metal_device newBufferWithLength:sizeof(MoxiMetalVertex) * MOXI_METAL_MAX_VERTICES
                                                                 options:MTLResourceStorageModeShared];
    if (moxi_metal_vertex_buffer == nil) return 0;
    moxi_metal_vertices = (MoxiMetalVertex *)[moxi_metal_vertex_buffer contents];
    moxi_metal_vertex_count = 0;
    moxi_metal_overflow_count = 0;
    moxi_metal_frame_count = 0;
    moxi_metal_initialized = YES;
    return 1;
}

int moxi_metal_resize(int width, int height) {
    if (!moxi_metal_initialized) return 0;
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    moxi_metal_width = width;
    moxi_metal_height = height;
    return moxi_metal_make_texture(width, height) ? 1 : 0;
}

void moxi_metal_begin(float red, float green, float blue, float alpha) {
    if (!moxi_metal_initialized) return;
    moxi_metal_vertex_count = 0;
    moxi_metal_command_buffer = [moxi_metal_queue commandBuffer];
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = moxi_metal_texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(red, green, blue, alpha);
    moxi_metal_encoder = [moxi_metal_command_buffer renderCommandEncoderWithDescriptor:pass];
    [moxi_metal_encoder setRenderPipelineState:moxi_metal_pipeline];
}

void moxi_metal_draw_rect(float x, float y, float width, float height, float red, float green, float blue, float alpha) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) moxi_append_rect(x, y, width, height, color);
}

void moxi_metal_draw_line(float x1, float y1, float x2, float y2, float width, float red, float green, float blue, float alpha) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) moxi_append_line(x1, y1, x2, y2, width, color);
}

void moxi_metal_push_clip(float x, float y, float width, float height) {
    if (moxi_metal_encoder == nil) return;
    MTLScissorRect rect;
    rect.x = x < 0.0f ? 0 : (NSUInteger)x;
    rect.y = y < 0.0f ? 0 : (NSUInteger)y;
    rect.width = width > 0.0f ? (NSUInteger)width : 0;
    rect.height = height > 0.0f ? (NSUInteger)height : 0;
    if (rect.x + rect.width > (NSUInteger)moxi_metal_width) rect.width = (NSUInteger)moxi_metal_width - rect.x;
    if (rect.y + rect.height > (NSUInteger)moxi_metal_height) rect.height = (NSUInteger)moxi_metal_height - rect.y;
    [moxi_metal_encoder setScissorRect:rect];
}

void moxi_metal_pop_clip(void) {
    if (moxi_metal_encoder == nil) return;
    MTLScissorRect rect = {0, 0, (NSUInteger)moxi_metal_width, (NSUInteger)moxi_metal_height};
    [moxi_metal_encoder setScissorRect:rect];
}

void moxi_metal_end(void) {
    if (moxi_metal_encoder == nil || moxi_metal_command_buffer == nil) return;
    if (moxi_metal_vertex_count > 0) {
        [moxi_metal_encoder setVertexBuffer:moxi_metal_vertex_buffer offset:0 atIndex:0];
        [moxi_metal_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:(NSUInteger)moxi_metal_vertex_count];
    }
    [moxi_metal_encoder endEncoding];
    [moxi_metal_command_buffer commit];
    [moxi_metal_command_buffer waitUntilCompleted];
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_frame_count += 1;
}

int moxi_metal_frame_count_value(void) { return moxi_metal_frame_count; }
int moxi_metal_vertex_count_value(void) { return moxi_metal_vertex_count; }
int moxi_metal_overflow_count_value(void) { return moxi_metal_overflow_count; }

int64_t moxi_metal_checksum(void) {
    if (!moxi_metal_initialized || moxi_metal_texture == nil) return 0;
    NSUInteger byteCount = (NSUInteger)moxi_metal_width * (NSUInteger)moxi_metal_height * 4;
    uint8_t *bytes = (uint8_t *)malloc(byteCount);
    if (bytes == NULL) return 0;
    MTLRegion region = MTLRegionMake2D(0, 0, (NSUInteger)moxi_metal_width, (NSUInteger)moxi_metal_height);
    [moxi_metal_texture getBytes:bytes bytesPerRow:(NSUInteger)moxi_metal_width * 4 fromRegion:region mipmapLevel:0];
    int64_t result = 0;
    for (NSUInteger index = 0; index < byteCount; index++) {
        result += (int64_t)bytes[index] * (int64_t)((index % 31) + 1);
    }
    free(bytes);
    return result;
}

void moxi_metal_shutdown(void) {
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_texture = nil;
    moxi_metal_vertex_buffer = nil;
    moxi_metal_pipeline = nil;
    moxi_metal_queue = nil;
    moxi_metal_device = nil;
    moxi_metal_vertices = NULL;
    moxi_metal_initialized = NO;
}
