#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * A small scene renderer for the 0.6 GPU slice. It batches rectangles and
 * line quads into one shared MTLBuffer and one draw call per frame. The
 * The same scene API can target either the retained offscreen texture used by
 * tests and benchmarks or an AppKit CAMetalLayer used by the visible demo.
 */

#define MOXI_METAL_INITIAL_VERTICES 262144
#define MOXI_METAL_MAX_VERTICES 4194304
#define MOXI_METAL_MAX_CLIP_DEPTH 64

@interface MoxiMetalView : NSView
@end

@interface MoxiMetalWindowDelegate : NSObject <NSWindowDelegate>
@end

typedef struct {
    vector_float2 position;
    vector_float4 color;
} MoxiMetalVertex;

static id<MTLDevice> moxi_metal_device;
static id<MTLCommandQueue> moxi_metal_queue;
static id<MTLRenderPipelineState> moxi_metal_pipeline;
static id<MTLTexture> moxi_metal_texture;
static id<MTLTexture> moxi_metal_render_texture;
static id<CAMetalDrawable> moxi_metal_drawable;
static id<MTLBuffer> moxi_metal_vertex_buffer;
static id<MTLCommandBuffer> moxi_metal_command_buffer;
static id<MTLRenderCommandEncoder> moxi_metal_encoder;
static MoxiMetalVertex *moxi_metal_vertices;
static int moxi_metal_width;
static int moxi_metal_height;
static NSUInteger moxi_metal_target_width;
static NSUInteger moxi_metal_target_height;
static float moxi_metal_scale;
static int moxi_metal_vertex_count;
static int moxi_metal_overflow_count;
static int moxi_metal_frame_count;
static NSUInteger moxi_metal_vertex_capacity;
static int moxi_metal_buffer_reallocation_count;
static int moxi_metal_draw_submission_count;
static int moxi_metal_resize_count;
static MTLScissorRect moxi_metal_clip_stack[MOXI_METAL_MAX_CLIP_DEPTH];
static NSUInteger moxi_metal_clip_depth;
static BOOL moxi_metal_initialized;
static NSWindow *moxi_metal_window;
static MoxiMetalWindowDelegate *moxi_metal_window_delegate;
static MoxiMetalView *moxi_metal_view;
static CAMetalLayer *moxi_metal_layer;
static BOOL moxi_metal_window_opened;

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

static MoxiMetalVertex moxi_vertex_at(float x, float y, const float color[4]) {
    return moxi_vertex(x, y, color);
}

static BOOL moxi_metal_reserve_vertices(int additional) {
    if (additional < 0 || moxi_metal_vertex_count < 0) return NO;
    NSUInteger required = (NSUInteger)moxi_metal_vertex_count + (NSUInteger)additional;
    if (required <= moxi_metal_vertex_capacity) return YES;
    if (required > MOXI_METAL_MAX_VERTICES) {
        moxi_metal_overflow_count += 1;
        return NO;
    }
    NSUInteger next_capacity = moxi_metal_vertex_capacity;
    if (next_capacity == 0) next_capacity = MOXI_METAL_INITIAL_VERTICES;
    while (next_capacity < required) {
        NSUInteger doubled = next_capacity * 2;
        if (doubled <= next_capacity || doubled > MOXI_METAL_MAX_VERTICES) {
            next_capacity = MOXI_METAL_MAX_VERTICES;
            break;
        }
        next_capacity = doubled;
    }
    id<MTLBuffer> next_buffer = [moxi_metal_device newBufferWithLength:
        sizeof(MoxiMetalVertex) * next_capacity options:MTLResourceStorageModeShared];
    if (next_buffer == nil) {
        moxi_metal_overflow_count += 1;
        return NO;
    }
    MoxiMetalVertex *next_vertices = (MoxiMetalVertex *)[next_buffer contents];
    if (moxi_metal_vertices != NULL && moxi_metal_vertex_count > 0) {
        memcpy(next_vertices, moxi_metal_vertices,
               sizeof(MoxiMetalVertex) * (NSUInteger)moxi_metal_vertex_count);
    }
    moxi_metal_vertex_buffer = next_buffer;
    moxi_metal_vertices = next_vertices;
    moxi_metal_vertex_capacity = next_capacity;
    moxi_metal_buffer_reallocation_count += 1;
    return YES;
}

static void moxi_append_triangle(
    MoxiMetalVertex first,
    MoxiMetalVertex second,
    MoxiMetalVertex third
) {
    if (!moxi_metal_reserve_vertices(3)) return;
    moxi_metal_vertices[moxi_metal_vertex_count++] = first;
    moxi_metal_vertices[moxi_metal_vertex_count++] = second;
    moxi_metal_vertices[moxi_metal_vertex_count++] = third;
}

static float moxi_clamp(float value) {
    if (value < 0.0f) return 0.0f;
    if (value > 1.0f) return 1.0f;
    return value;
}

static void moxi_gradient_color(
    float x,
    float y,
    float start_x,
    float start_y,
    float end_x,
    float end_y,
    const float start_color[4],
    const float end_color[4],
    float result[4]
) {
    float dx = end_x - start_x;
    float dy = end_y - start_y;
    float span = dx * dx + dy * dy;
    float amount = span <= 0.0f ? 0.0f :
        ((x - start_x) * dx + (y - start_y) * dy) / span;
    amount = moxi_clamp(amount);
    for (int index = 0; index < 4; index++) {
        result[index] = start_color[index] +
            (end_color[index] - start_color[index]) * amount;
    }
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

static void moxi_append_gradient_rect(
    float x,
    float y,
    float width,
    float height,
    float start_x,
    float start_y,
    float end_x,
    float end_y,
    const float start_color[4],
    const float end_color[4]
) {
    if (width <= 0.0f || height <= 0.0f) return;
    float top_left_color[4];
    float top_right_color[4];
    float bottom_left_color[4];
    float bottom_right_color[4];
    moxi_gradient_color(x, y, start_x, start_y, end_x, end_y,
                        start_color, end_color, top_left_color);
    moxi_gradient_color(x + width, y, start_x, start_y, end_x, end_y,
                        start_color, end_color, top_right_color);
    moxi_gradient_color(x, y + height, start_x, start_y, end_x, end_y,
                        start_color, end_color, bottom_left_color);
    moxi_gradient_color(x + width, y + height, start_x, start_y, end_x, end_y,
                        start_color, end_color, bottom_right_color);
    MoxiMetalVertex top_left = moxi_vertex_at(x, y, top_left_color);
    MoxiMetalVertex top_right = moxi_vertex_at(x + width, y, top_right_color);
    MoxiMetalVertex bottom_left = moxi_vertex_at(x, y + height, bottom_left_color);
    MoxiMetalVertex bottom_right = moxi_vertex_at(
        x + width, y + height, bottom_right_color);
    moxi_append_triangle(top_left, top_right, bottom_left);
    moxi_append_triangle(bottom_left, top_right, bottom_right);
}

static void moxi_append_rounded_rect(
    float x,
    float y,
    float width,
    float height,
    float radius,
    const float color[4]
) {
    if (width <= 0.0f || height <= 0.0f) return;
    float max_radius = width < height ? width * 0.5f : height * 0.5f;
    if (radius <= 0.0f) {
        moxi_append_rect(x, y, width, height, color);
        return;
    }
    if (radius > max_radius) radius = max_radius;
    const int segments = 8;
    const int point_count = segments * 4;
    MoxiMetalVertex perimeter[32];
    const float pi = 3.14159265358979323846f;
    const float centers[4][2] = {
        {x + width - radius, y + radius},
        {x + width - radius, y + height - radius},
        {x + radius, y + height - radius},
        {x + radius, y + radius},
    };
    const float starts[4] = {-0.5f * pi, 0.0f, 0.5f * pi, pi};
    for (int corner = 0; corner < 4; corner++) {
        for (int segment = 0; segment < segments; segment++) {
            float angle = starts[corner] +
                (0.5f * pi) * ((float)segment / (float)segments);
            perimeter[corner * segments + segment] = moxi_vertex_at(
                centers[corner][0] + cosf(angle) * radius,
                centers[corner][1] + sinf(angle) * radius,
                color);
        }
    }
    MoxiMetalVertex center = moxi_vertex_at(x + width * 0.5f,
                                            y + height * 0.5f, color);
    if (!moxi_metal_reserve_vertices(point_count * 3)) return;
    for (int index = 0; index < point_count; index++) {
        int next = (index + 1) % point_count;
        moxi_metal_vertices[moxi_metal_vertex_count++] = center;
        moxi_metal_vertices[moxi_metal_vertex_count++] = perimeter[index];
        moxi_metal_vertices[moxi_metal_vertex_count++] = perimeter[next];
    }
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
    descriptor.colorAttachments[0].blendingEnabled = YES;
    descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
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
    id<MTLTexture> next_texture = [moxi_metal_device newTextureWithDescriptor:descriptor];
    if (next_texture == nil) return NO;
    moxi_metal_texture = next_texture;
    moxi_metal_target_width = (NSUInteger)width;
    moxi_metal_target_height = (NSUInteger)height;
    moxi_metal_scale = 1.0f;
    return YES;
}

int moxi_metal_available(void) {
    return MTLCreateSystemDefaultDevice() != nil ? 1 : 0;
}

int moxi_metal_init(int width, int height) {
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    if (moxi_metal_initialized) return 1;
    moxi_metal_device = MTLCreateSystemDefaultDevice();
    if (moxi_metal_device == nil) return 0;
    moxi_metal_queue = [moxi_metal_device newCommandQueue];
    if (moxi_metal_queue == nil || !moxi_metal_make_pipeline()) return 0;
    moxi_metal_width = width;
    moxi_metal_height = height;
    if (!moxi_metal_make_texture(width, height)) return 0;
    moxi_metal_vertex_buffer = [moxi_metal_device newBufferWithLength:sizeof(MoxiMetalVertex) * MOXI_METAL_INITIAL_VERTICES
                                                                 options:MTLResourceStorageModeShared];
    if (moxi_metal_vertex_buffer == nil) return 0;
    moxi_metal_vertices = (MoxiMetalVertex *)[moxi_metal_vertex_buffer contents];
    moxi_metal_vertex_capacity = MOXI_METAL_INITIAL_VERTICES;
    moxi_metal_vertex_count = 0;
    moxi_metal_overflow_count = 0;
    moxi_metal_frame_count = 0;
    moxi_metal_buffer_reallocation_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_resize_count = 0;
    moxi_metal_clip_depth = 0;
    moxi_metal_initialized = YES;
    return 1;
}

int moxi_metal_resize(int width, int height) {
    if (!moxi_metal_initialized) return 0;
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    if (width == moxi_metal_width && height == moxi_metal_height) return 1;
    if (!moxi_metal_make_texture(width, height)) return 0;
    moxi_metal_width = width;
    moxi_metal_height = height;
    moxi_metal_resize_count += 1;
    return 1;
}

void moxi_metal_begin(float red, float green, float blue, float alpha) {
    if (!moxi_metal_initialized) return;
    moxi_metal_vertex_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_clip_depth = 0;
    moxi_metal_command_buffer = [moxi_metal_queue commandBuffer];
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    moxi_metal_render_texture = moxi_metal_texture;
    moxi_metal_drawable = nil;
    moxi_metal_target_width = moxi_metal_texture.width;
    moxi_metal_target_height = moxi_metal_texture.height;
    moxi_metal_scale = 1.0f;
    if (moxi_metal_layer != nil) {
        moxi_metal_drawable = [moxi_metal_layer nextDrawable];
        if (moxi_metal_drawable != nil) {
            moxi_metal_render_texture = moxi_metal_drawable.texture;
            moxi_metal_target_width = moxi_metal_render_texture.width;
            moxi_metal_target_height = moxi_metal_render_texture.height;
            if (moxi_metal_width > 0) {
                moxi_metal_scale = (float)moxi_metal_target_width /
                    (float)moxi_metal_width;
            }
        }
    }
    pass.colorAttachments[0].texture = moxi_metal_render_texture;
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

void moxi_metal_draw_rounded_rect(float x, float y, float width, float height, float radius, float red, float green, float blue, float alpha) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) moxi_append_rounded_rect(x, y, width, height, radius, color);
}

void moxi_metal_draw_gradient(
    float x,
    float y,
    float width,
    float height,
    float start_x,
    float start_y,
    float end_x,
    float end_y,
    float start_red,
    float start_green,
    float start_blue,
    float start_alpha,
    float end_red,
    float end_green,
    float end_blue,
    float end_alpha
) {
    float start_color[4] = {start_red, start_green, start_blue, start_alpha};
    float end_color[4] = {end_red, end_green, end_blue, end_alpha};
    if (moxi_metal_encoder != nil) {
        moxi_append_gradient_rect(x, y, width, height, start_x, start_y,
                                   end_x, end_y, start_color, end_color);
    }
}

void moxi_metal_draw_line(float x1, float y1, float x2, float y2, float width, float red, float green, float blue, float alpha) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) moxi_append_line(x1, y1, x2, y2, width, color);
}

void moxi_metal_push_clip(float x, float y, float width, float height) {
    if (moxi_metal_encoder == nil) return;
    if (moxi_metal_clip_depth >= MOXI_METAL_MAX_CLIP_DEPTH) {
        moxi_metal_overflow_count += 1;
        return;
    }
    MTLScissorRect rect;
    rect.x = x <= 0.0f ? 0 : (NSUInteger)(x * moxi_metal_scale);
    rect.y = y <= 0.0f ? 0 : (NSUInteger)(y * moxi_metal_scale);
    rect.width = width > 0.0f ? (NSUInteger)(width * moxi_metal_scale) : 0;
    rect.height = height > 0.0f ? (NSUInteger)(height * moxi_metal_scale) : 0;
    if (rect.x >= moxi_metal_target_width) {
        rect.x = moxi_metal_target_width;
        rect.width = 0;
    } else if (rect.x + rect.width > moxi_metal_target_width) {
        rect.width = moxi_metal_target_width - rect.x;
    }
    if (rect.y >= moxi_metal_target_height) {
        rect.y = moxi_metal_target_height;
        rect.height = 0;
    } else if (rect.y + rect.height > moxi_metal_target_height) {
        rect.height = moxi_metal_target_height - rect.y;
    }
    if (moxi_metal_clip_depth > 0) {
        MTLScissorRect parent = moxi_metal_clip_stack[moxi_metal_clip_depth - 1];
        NSUInteger right = rect.x + rect.width;
        NSUInteger bottom = rect.y + rect.height;
        NSUInteger parent_right = parent.x + parent.width;
        NSUInteger parent_bottom = parent.y + parent.height;
        if (rect.x < parent.x) rect.x = parent.x;
        if (rect.y < parent.y) rect.y = parent.y;
        if (right > parent_right) right = parent_right;
        if (bottom > parent_bottom) bottom = parent_bottom;
        rect.width = right > rect.x ? right - rect.x : 0;
        rect.height = bottom > rect.y ? bottom - rect.y : 0;
    }
    moxi_metal_clip_stack[moxi_metal_clip_depth++] = rect;
    [moxi_metal_encoder setScissorRect:rect];
}

void moxi_metal_pop_clip(void) {
    if (moxi_metal_encoder == nil) return;
    if (moxi_metal_clip_depth > 0) moxi_metal_clip_depth -= 1;
    MTLScissorRect rect = {0, 0, moxi_metal_target_width, moxi_metal_target_height};
    if (moxi_metal_clip_depth > 0) rect = moxi_metal_clip_stack[moxi_metal_clip_depth - 1];
    [moxi_metal_encoder setScissorRect:rect];
}

void moxi_metal_end(void) {
    if (moxi_metal_encoder == nil || moxi_metal_command_buffer == nil) return;
    if (moxi_metal_vertex_count > 0) {
        [moxi_metal_encoder setVertexBuffer:moxi_metal_vertex_buffer offset:0 atIndex:0];
        [moxi_metal_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:(NSUInteger)moxi_metal_vertex_count];
        moxi_metal_draw_submission_count += 1;
    }
    [moxi_metal_encoder endEncoding];
    if (moxi_metal_drawable != nil) {
        [moxi_metal_command_buffer presentDrawable:moxi_metal_drawable];
    }
    [moxi_metal_command_buffer commit];
    [moxi_metal_command_buffer waitUntilCompleted];
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_drawable = nil;
    moxi_metal_render_texture = nil;
    moxi_metal_frame_count += 1;
}

int moxi_metal_frame_count_value(void) { return moxi_metal_frame_count; }
int moxi_metal_vertex_count_value(void) { return moxi_metal_vertex_count; }
int moxi_metal_overflow_count_value(void) { return moxi_metal_overflow_count; }
int moxi_metal_buffer_capacity_value(void) { return (int)moxi_metal_vertex_capacity; }
int moxi_metal_buffer_reallocation_count_value(void) { return moxi_metal_buffer_reallocation_count; }
int moxi_metal_draw_submission_count_value(void) { return moxi_metal_draw_submission_count; }
int moxi_metal_resize_count_value(void) { return moxi_metal_resize_count; }

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
    [moxi_metal_window close];
    moxi_metal_window = nil;
    moxi_metal_window_delegate = nil;
    moxi_metal_view = nil;
    moxi_metal_layer = nil;
    moxi_metal_window_opened = NO;
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_texture = nil;
    moxi_metal_vertex_buffer = nil;
    moxi_metal_pipeline = nil;
    moxi_metal_queue = nil;
    moxi_metal_device = nil;
    moxi_metal_vertices = NULL;
    moxi_metal_vertex_capacity = 0;
    moxi_metal_buffer_reallocation_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_resize_count = 0;
    moxi_metal_clip_depth = 0;
    moxi_metal_target_width = 0;
    moxi_metal_target_height = 0;
    moxi_metal_scale = 1.0f;
    moxi_metal_initialized = NO;
}

@implementation MoxiMetalView
- (BOOL)isFlipped { return YES; }
- (CALayer *)makeBackingLayer { return [CAMetalLayer layer]; }
- (void)layout {
    [super layout];
    if (moxi_metal_layer != nil) {
        CGFloat scale = self.window == nil ? 1.0 : self.window.backingScaleFactor;
        moxi_metal_layer.contentsScale = scale;
        moxi_metal_layer.drawableSize = CGSizeMake(
            self.bounds.size.width * scale,
            self.bounds.size.height * scale
        );
    }
}
@end

@implementation MoxiMetalWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    moxi_metal_window_opened = NO;
    [NSApp stop:nil];
}
@end

int moxi_metal_open_window(const char *title, float width, float height) {
    @autoreleasepool {
        if (!moxi_metal_initialized && !moxi_metal_init((int)width, (int)height)) {
            return 0;
        }
        if (moxi_metal_window_opened) return 1;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        NSRect frame = NSMakeRect(0.0, 0.0, width > 0.0f ? width : 1.0f, height > 0.0f ? height : 1.0f);
        NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
        moxi_metal_window = [[NSWindow alloc] initWithContentRect:frame
                                                           styleMask:style
                                                             backing:NSBackingStoreBuffered
                                                               defer:NO];
        moxi_metal_window_delegate = [[MoxiMetalWindowDelegate alloc] init];
        moxi_metal_window.delegate = moxi_metal_window_delegate;
        NSString *windowTitle = title == NULL ? @"Moxi Metal" : [NSString stringWithUTF8String:title];
        moxi_metal_window.title = windowTitle == nil ? @"Moxi Metal" : windowTitle;
        MoxiMetalView *view = [[MoxiMetalView alloc] initWithFrame:frame];
        view.wantsLayer = YES;
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        moxi_metal_view = view;
        moxi_metal_layer = (CAMetalLayer *)view.layer;
        moxi_metal_layer.device = moxi_metal_device;
        moxi_metal_layer.pixelFormat = MTLPixelFormatRGBA8Unorm;
        moxi_metal_layer.framebufferOnly = NO;
        moxi_metal_layer.drawableSize = CGSizeMake(frame.size.width, frame.size.height);
        moxi_metal_window.contentView = view;
        [view setNeedsLayout:YES];
        [view layoutSubtreeIfNeeded];
        [moxi_metal_window center];
        [moxi_metal_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        moxi_metal_window_opened = YES;
        return 1;
    }
}

void moxi_metal_pump_window(void) {
    @autoreleasepool {
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.016];
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                             untilDate:deadline
                                                inMode:NSDefaultRunLoopMode
                                               dequeue:YES];
        if (event != nil) [NSApp sendEvent:event];
        [NSApp updateWindows];
        if (moxi_metal_view != nil) {
            NSRect bounds = moxi_metal_view.bounds;
            int width = (int)MAX(1.0, floor(bounds.size.width));
            int height = (int)MAX(1.0, floor(bounds.size.height));
            if (width != moxi_metal_width || height != moxi_metal_height) {
                moxi_metal_resize(width, height);
            }
        }
    }
}

int moxi_metal_window_is_open(void) { return moxi_metal_window_opened ? 1 : 0; }
void moxi_metal_close_window(void) {
    [moxi_metal_window close];
    moxi_metal_window = nil;
    moxi_metal_view = nil;
    moxi_metal_layer = nil;
    moxi_metal_window_opened = NO;
}

float moxi_metal_window_width(void) {
    return moxi_metal_view == nil ? (float)moxi_metal_width : (float)moxi_metal_view.bounds.size.width;
}

float moxi_metal_window_height(void) {
    return moxi_metal_view == nil ? (float)moxi_metal_height : (float)moxi_metal_view.bounds.size.height;
}
