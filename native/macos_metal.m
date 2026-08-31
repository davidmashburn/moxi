#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <simd/simd.h>
#include <ctype.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * A small scene renderer for the 0.6 GPU slice. It batches rectangles and
 * line quads into one shared MTLBuffer and one draw call per frame. Text that
 * needs real Unicode shaping is rasterized by CoreText into a bounded cached
 * Metal texture, while the compact ASCII geometry path remains allocation
 * free. The same scene API can target either the retained offscreen texture
 * used by tests and benchmarks or an AppKit CAMetalLayer used by the visible
 * demo.
 */

#define MOXI_METAL_INITIAL_VERTICES 262144
#define MOXI_METAL_MAX_VERTICES 4194304
#define MOXI_METAL_MAX_CLIP_DEPTH 64
#define MOXI_METAL_MAX_IMAGES 64
#define MOXI_METAL_MAX_TEXT_TEXTURES 128
#define MOXI_METAL_MAX_TEXT_CACHE 64
#define MOXI_METAL_MAX_TEXT_CACHE_BYTES (32u * 1024u * 1024u)
#define MOXI_METAL_MAX_TEXT_TEXTURE_DIMENSION 4096
#define MOXI_METAL_MAX_PATH_POINTS 4096
#define MOXI_METAL_MAX_PATH_SUBPATHS 128
#define MOXI_METAL_MAX_SCANLINE_INTERSECTIONS 4096
#define MOXI_METAL_MAX_TESSELLATION_TRIANGLES 131072

@interface MoxiMetalView : NSView
@end

@interface MoxiMetalWindowDelegate : NSObject <NSWindowDelegate>
@end

/* The regular AppKit host owns the content view used by the interactive
 * examples.  The Metal canvas is an optional child of that view, so the
 * AppKit-only binaries do not need to link against this bridge. */
extern void *moxi_window_canvas_view(void);

typedef struct {
    vector_float2 position;
    vector_float4 color;
} MoxiMetalVertex;

typedef struct {
    vector_float2 position;
    vector_float2 texcoord;
    vector_float4 color;
} MoxiMetalImageVertex;

static id<MTLDevice> moxi_metal_device;
static id<MTLCommandQueue> moxi_metal_queue;
static id<MTLRenderPipelineState> moxi_metal_pipeline;
static id<MTLRenderPipelineState> moxi_metal_image_pipeline;
static id<MTLSamplerState> moxi_metal_image_sampler;
static id<MTLTexture> moxi_metal_texture;
static id<MTLTexture> moxi_metal_render_texture;
static id<CAMetalDrawable> moxi_metal_drawable;
static id<MTLBuffer> moxi_metal_vertex_buffer;
static id<MTLBuffer> moxi_metal_image_buffer;
static id<MTLCommandBuffer> moxi_metal_command_buffer;
static id<MTLRenderCommandEncoder> moxi_metal_encoder;
static MoxiMetalVertex *moxi_metal_vertices;
static MoxiMetalImageVertex *moxi_metal_image_vertices;
static int moxi_metal_width;
static int moxi_metal_height;
static NSUInteger moxi_metal_target_width;
static NSUInteger moxi_metal_target_height;
static float moxi_metal_scale;
static int moxi_metal_vertex_count;
static int moxi_metal_submitted_vertex_count;
static int moxi_metal_overflow_count;
static int moxi_metal_frame_count;
static NSUInteger moxi_metal_vertex_capacity;
static int moxi_metal_buffer_reallocation_count;
static int moxi_metal_draw_submission_count;
static int moxi_metal_resize_count;
static float moxi_metal_last_gpu_time_ms;
static float moxi_metal_last_cpu_encode_time_ms;
static float moxi_metal_last_cpu_wait_time_ms;
static float moxi_metal_last_frame_time_ms;
static BOOL moxi_metal_gpu_timing_available;
static CFTimeInterval moxi_metal_frame_start_time;
static CFTimeInterval moxi_metal_encode_start_time;
static MTLScissorRect moxi_metal_clip_stack[MOXI_METAL_MAX_CLIP_DEPTH];
static NSUInteger moxi_metal_clip_depth;
static BOOL moxi_metal_initialized;
static NSWindow *moxi_metal_window;
static MoxiMetalWindowDelegate *moxi_metal_window_delegate;
static MoxiMetalView *moxi_metal_view;
static MoxiMetalView *moxi_metal_canvas_view;
static CAMetalLayer *moxi_metal_layer;
static BOOL moxi_metal_window_opened;
static id<MTLTexture> moxi_metal_images[MOXI_METAL_MAX_IMAGES];
static int moxi_metal_image_ids[MOXI_METAL_MAX_IMAGES];
static id<MTLTexture> moxi_metal_textures[MOXI_METAL_MAX_TEXT_TEXTURES];
static int moxi_metal_text_texture_count;
static int moxi_metal_text_texture_draw_count;
static NSString *moxi_metal_text_cache_keys[MOXI_METAL_MAX_TEXT_CACHE];
static id<MTLTexture> moxi_metal_text_cache_textures[MOXI_METAL_MAX_TEXT_CACHE];
static int moxi_metal_text_cache_glyph_counts[MOXI_METAL_MAX_TEXT_CACHE];
static int moxi_metal_text_cache_count;
static size_t moxi_metal_text_cache_bytes;
static int moxi_metal_text_texture_cache_hit_count;
static int moxi_metal_text_texture_raster_count;
static CFTimeInterval moxi_metal_line_geometry_start_time;
static float moxi_metal_last_line_geometry_time_ms;

static const char *moxi_metal_shader_source =
    "#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct Vertex { float2 position; float4 color; };\n"
     "struct Raster { float4 position [[position]]; float4 color; };\n"
     "vertex Raster moxi_vertex(const device Vertex *vertices [[buffer(0)]], uint id [[vertex_id]]) {\n"
     "  Raster out; out.position = float4(vertices[id].position, 0.0, 1.0); out.color = vertices[id].color; return out;\n"
     "}\n"
     "fragment float4 moxi_fragment(Raster in [[stage_in]]) { return in.color; }\n"
     "struct ImageVertex { float2 position; float2 texcoord; float4 color; };\n"
     "struct ImageRaster { float4 position [[position]]; float2 texcoord; float4 color; };\n"
     "vertex ImageRaster moxi_image_vertex(const device ImageVertex *vertices [[buffer(0)]], uint id [[vertex_id]]) {\n"
     "  ImageRaster out; out.position = float4(vertices[id].position, 0.0, 1.0); out.texcoord = vertices[id].texcoord; out.color = vertices[id].color; return out;\n"
     "}\n"
     "fragment float4 moxi_image_fragment(ImageRaster in [[stage_in]], texture2d<float> image [[texture(0)]], sampler imageSampler [[sampler(0)]]) { return image.sample(imageSampler, in.texcoord) * in.color; }\n";

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

static void moxi_append_triangle(
    MoxiMetalVertex first,
    MoxiMetalVertex second,
    MoxiMetalVertex third
);

static void moxi_metal_flush_geometry(void);

static int moxi_metal_draw_texture_quad(
    id<MTLTexture> texture,
    float x,
    float y,
    float width,
    float height,
    float alpha,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
);

static vector_float2 moxi_transform_point(
    float x,
    float y,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    return (vector_float2){
        m11 * x + m21 * y + tx,
        m12 * x + m22 * y + ty,
    };
}

static MoxiMetalVertex moxi_transformed_vertex(
    float x,
    float y,
    const float color[4],
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    vector_float2 point = moxi_transform_point(x, y, m11, m12, m21, m22, tx, ty);
    return moxi_vertex(point.x, point.y, color);
}

static void moxi_append_transformed_rect(
    float x,
    float y,
    float width,
    float height,
    const float color[4],
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (width <= 0.0f || height <= 0.0f) return;
    MoxiMetalVertex top_left = moxi_transformed_vertex(
        x, y, color, m11, m12, m21, m22, tx, ty);
    MoxiMetalVertex top_right = moxi_transformed_vertex(
        x + width, y, color, m11, m12, m21, m22, tx, ty);
    MoxiMetalVertex bottom_left = moxi_transformed_vertex(
        x, y + height, color, m11, m12, m21, m22, tx, ty);
    MoxiMetalVertex bottom_right = moxi_transformed_vertex(
        x + width, y + height, color, m11, m12, m21, m22, tx, ty);
    moxi_append_triangle(top_left, top_right, bottom_left);
    moxi_append_triangle(bottom_left, top_right, bottom_right);
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

static void moxi_append_circle(
    float center_x,
    float center_y,
    float radius,
    const float color[4]
) {
    if (radius <= 0.0f) return;
    const int segments = 32;
    if (!moxi_metal_reserve_vertices((segments - 2) * 3)) return;
    MoxiMetalVertex center = moxi_vertex(center_x, center_y, color);
    MoxiMetalVertex perimeter[32];
    const float pi = 3.14159265358979323846f;
    for (int index = 0; index < segments; index++) {
        float angle = (2.0f * pi * (float)index) / (float)segments;
        perimeter[index] = moxi_vertex(
            center_x + cosf(angle) * radius,
            center_y + sinf(angle) * radius,
            color
        );
    }
    for (int index = 1; index < segments - 1; index++) {
        moxi_metal_vertices[moxi_metal_vertex_count++] = center;
        moxi_metal_vertices[moxi_metal_vertex_count++] = perimeter[index];
        moxi_metal_vertices[moxi_metal_vertex_count++] = perimeter[index + 1];
    }
}

static void moxi_append_circle_ring(
    float center_x,
    float center_y,
    float inner_radius,
    float outer_radius,
    const float color[4]
) {
    if (outer_radius <= 0.0f) return;
    if (inner_radius <= 0.0f) {
        moxi_append_circle(center_x, center_y, outer_radius, color);
        return;
    }
    if (inner_radius >= outer_radius) return;
    const int segments = 32;
    if (!moxi_metal_reserve_vertices(segments * 6)) return;
    const float pi = 3.14159265358979323846f;
    for (int index = 0; index < segments; index++) {
        int next = (index + 1) % segments;
        float angle = (2.0f * pi * (float)index) / (float)segments;
        float next_angle = (2.0f * pi * (float)next) / (float)segments;
        MoxiMetalVertex outer = moxi_vertex(
            center_x + cosf(angle) * outer_radius,
            center_y + sinf(angle) * outer_radius,
            color
        );
        MoxiMetalVertex outer_next = moxi_vertex(
            center_x + cosf(next_angle) * outer_radius,
            center_y + sinf(next_angle) * outer_radius,
            color
        );
        MoxiMetalVertex inner = moxi_vertex(
            center_x + cosf(angle) * inner_radius,
            center_y + sinf(angle) * inner_radius,
            color
        );
        MoxiMetalVertex inner_next = moxi_vertex(
            center_x + cosf(next_angle) * inner_radius,
            center_y + sinf(next_angle) * inner_radius,
            color
        );
        moxi_metal_vertices[moxi_metal_vertex_count++] = outer;
        moxi_metal_vertices[moxi_metal_vertex_count++] = outer_next;
        moxi_metal_vertices[moxi_metal_vertex_count++] = inner;
        moxi_metal_vertices[moxi_metal_vertex_count++] = inner;
        moxi_metal_vertices[moxi_metal_vertex_count++] = outer_next;
        moxi_metal_vertices[moxi_metal_vertex_count++] = inner_next;
    }
}

/* A compact built-in glyph set keeps the GPU text path deterministic and
 * dependency-free. The platform text shapers still own production typography;
 * this path is intentionally limited to printable ASCII. */
static const uint8_t moxi_ascii_font[36][7] = {
    {0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E},
    {0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E},
    {0x1E, 0x01, 0x01, 0x0E, 0x10, 0x10, 0x1F},
    {0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E},
    {0x12, 0x12, 0x12, 0x1F, 0x02, 0x02, 0x02},
    {0x1F, 0x10, 0x10, 0x1E, 0x01, 0x01, 0x1E},
    {0x0E, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x0E},
    {0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08},
    {0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E},
    {0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E},
    {0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
    {0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E},
    {0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E},
    {0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E},
    {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F},
    {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10},
    {0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E},
    {0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
    {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1F},
    {0x01, 0x01, 0x01, 0x01, 0x11, 0x11, 0x0E},
    {0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11},
    {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F},
    {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11},
    {0x11, 0x19, 0x1D, 0x15, 0x17, 0x13, 0x11},
    {0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E},
    {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10},
    {0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D},
    {0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11},
    {0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E},
    {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04},
    {0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E},
    {0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04},
    {0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11},
    {0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11},
    {0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04},
    {0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F},
};

static int moxi_ascii_font_index(unsigned char value) {
    if (value >= 'a' && value <= 'z') value = (unsigned char)(value - 'a' + 'A');
    if (value >= '0' && value <= '9') return (int)(value - '0');
    if (value >= 'A' && value <= 'Z') return 10 + (int)(value - 'A');
    return -1;
}

static BOOL moxi_ascii_supported(unsigned char value) {
    if (moxi_ascii_font_index(value) >= 0) return YES;
    switch (value) {
        case ' ':
        case '.':
        case ',':
        case ':':
        case ';':
        case '!':
        case '?':
        case '-':
        case '_':
        case '+':
        case '=':
        case '/':
        case '(':
        case ')':
        case '[':
        case ']':
        case '#':
        case '%':
        case '\'':
        case '"':
            return YES;
        default:
            return NO;
    }
}

static uint8_t moxi_ascii_glyph_row(unsigned char value, int row) {
    int index = moxi_ascii_font_index(value);
    if (index >= 0) return moxi_ascii_font[index][row];
    switch (value) {
        case '.': return row == 6 ? 0x04 : 0;
        case ',': return row == 5 ? 0x04 : (row == 6 ? 0x08 : 0);
        case ':': return (row == 2 || row == 5) ? 0x04 : 0;
        case ';': return row == 2 ? 0x04 : (row == 5 ? 0x04 : (row == 6 ? 0x08 : 0));
        case '!': return row == 6 ? 0x04 : (row < 5 ? 0x04 : 0);
        case '?': {
            static const uint8_t rows[7] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04};
            return rows[row];
        }
        case '-': return row == 3 ? 0x1F : 0;
        case '_': return row == 6 ? 0x1F : 0;
        case '+': return row == 3 ? 0x1F : (row == 1 || row == 2 || row == 4 || row == 5 ? 0x04 : 0);
        case '=': return (row == 2 || row == 4) ? 0x1F : 0;
        case '/': return (uint8_t)(1 << (row < 5 ? 4 - row : 0));
        case '(' : return row == 0 || row == 6 ? 0x02 : 0x04;
        case ')' : return row == 0 || row == 6 ? 0x08 : 0x04;
        case '[' : return 0x0E;
        case ']' : return 0x1C;
        case '#': return (row == 2 || row == 4) ? 0x1F : (row == 1 || row == 3 || row == 5 ? 0x0A : 0);
        case '%': return row == 1 || row == 5 ? 0x19 : (row == 2 || row == 4 ? 0x04 : 0x13);
        case '\'': return row == 0 ? 0x04 : 0;
        case '"': return row == 0 ? 0x0A : 0;
        default: return 0;
    }
}

static int moxi_metal_find_text_cache(NSString *key) {
    if (key == nil) return -1;
    for (int index = 0; index < moxi_metal_text_cache_count; index++) {
        if (moxi_metal_text_cache_keys[index] != nil &&
            moxi_metal_text_cache_textures[index] != nil &&
            [moxi_metal_text_cache_keys[index] isEqualToString:key]) {
            return index;
        }
    }
    return -1;
}

static int moxi_metal_draw_coretext_text(
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (moxi_metal_encoder == nil || text == NULL) {
        return -1;
    }
    @autoreleasepool {
        NSString *string = [NSString stringWithUTF8String:text];
        if (string == nil) return -1;
        if ([string length] == 0) return 0;

        /* Scene text supplies a box height rather than a font size. Leave
         * enough leading for CoreText's ascent/descent so a one-line label
         * fits in the same box that the ASCII fast path accepts. */
        CGFloat fontSize = height > 0.0f ? (CGFloat)height * 0.80 : 14.0;
        fontSize = MAX(1.0, MIN(fontSize, 256.0));
        CTFontRef font = CTFontCreateUIFontForLanguage(
            kCTFontUIFontSystem,
            fontSize,
            NULL
        );
        if (font == NULL) {
            font = CTFontCreateWithName(CFSTR("Helvetica"), fontSize, NULL);
        }
        if (font == NULL) return -1;

        CGColorRef textColor = CGColorCreateGenericRGB(red, green, blue, alpha);
        if (textColor == NULL) {
            CFRelease(font);
            return -1;
        }
        NSDictionary *attributes = @{
            (__bridge id)kCTFontAttributeName: (__bridge id)font,
            (__bridge id)kCTForegroundColorAttributeName: (__bridge id)textColor,
        };
        NSAttributedString *attributed = [[NSAttributedString alloc]
            initWithString:string
            attributes:attributes];
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(
            (__bridge CFAttributedStringRef)attributed
        );
        if (framesetter == NULL) {
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }

        CGFloat constrainedWidth = width > 0.0f ? (CGFloat)width : CGFLOAT_MAX;
        CGFloat constrainedHeight = height > 0.0f ? (CGFloat)height : CGFLOAT_MAX;
        CGSize suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            NULL,
            CGSizeMake(constrainedWidth, constrainedHeight),
            NULL
        );
        CGFloat logicalWidth = width > 0.0f
            ? (CGFloat)width
            : MAX(1.0, ceil(suggested.width + 2.0));
        CGFloat logicalHeight = height > 0.0f
            ? (CGFloat)height
            : MAX(1.0, ceil(suggested.height + 2.0));
        if (logicalWidth > MOXI_METAL_MAX_TEXT_TEXTURE_DIMENSION ||
            logicalHeight > MOXI_METAL_MAX_TEXT_TEXTURE_DIMENSION) {
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }

        size_t pixelWidth = (size_t)ceil(logicalWidth * moxi_metal_scale);
        size_t pixelHeight = (size_t)ceil(logicalHeight * moxi_metal_scale);
        if (pixelWidth == 0 || pixelHeight == 0 ||
            pixelWidth > MOXI_METAL_MAX_TEXT_TEXTURE_DIMENSION ||
            pixelHeight > MOXI_METAL_MAX_TEXT_TEXTURE_DIMENSION) {
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }
        size_t byteCount = pixelWidth * pixelHeight * 4;

        NSString *cacheKey = [NSString stringWithFormat:
            @"%@|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f",
            string,
            logicalWidth,
            logicalHeight,
            red,
            green,
            blue,
            alpha,
            moxi_metal_scale
        ];
        int cachedSlot = moxi_metal_find_text_cache(cacheKey);
        if (cachedSlot >= 0) {
            int glyphCount = moxi_metal_text_cache_glyph_counts[cachedSlot];
            int drawn = moxi_metal_draw_texture_quad(
                moxi_metal_text_cache_textures[cachedSlot],
                x,
                y,
                (float)logicalWidth,
                (float)logicalHeight,
                1.0f,
                m11,
                m12,
                m21,
                m22,
                tx,
                ty
            );
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            if (!drawn) return -1;
            moxi_metal_text_texture_draw_count += 1;
            moxi_metal_text_texture_cache_hit_count += 1;
            return glyphCount;
        }
        if (moxi_metal_text_texture_count >= MOXI_METAL_MAX_TEXT_TEXTURES) {
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }
        uint8_t *bytes = (uint8_t *)calloc(1, byteCount);
        if (bytes == NULL) {
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(
            bytes,
            pixelWidth,
            pixelHeight,
            8,
            pixelWidth * 4,
            colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
        );
        if (context == NULL || colorSpace == NULL) {
            if (context != NULL) CGContextRelease(context);
            if (colorSpace != NULL) CGColorSpaceRelease(colorSpace);
            free(bytes);
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextTranslateCTM(context, 0.0, (CGFloat)pixelHeight);
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextScaleCTM(context, moxi_metal_scale, moxi_metal_scale);
        CGPathRef path = CGPathCreateWithRect(
            CGRectMake(0.0, 0.0, logicalWidth, logicalHeight),
            NULL
        );
        CTFrameRef frame = CTFramesetterCreateFrame(
            framesetter,
            CFRangeMake(0, 0),
            path,
            NULL
        );
        if (frame == NULL) {
            CGPathRelease(path);
            CGContextRelease(context);
            CGColorSpaceRelease(colorSpace);
            free(bytes);
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }
        CTFrameDraw(frame, context);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        CGPathRelease(path);

        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
            width:pixelWidth
            height:pixelHeight
            mipmapped:NO];
        descriptor.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [moxi_metal_device newTextureWithDescriptor:descriptor];
        if (texture == nil) {
            free(bytes);
            CFRelease(frame);
            CFRelease(framesetter);
            CGColorRelease(textColor);
            CFRelease(font);
            return -1;
        }
        MTLRegion region = MTLRegionMake2D(0, 0, pixelWidth, pixelHeight);
        [texture replaceRegion:region mipmapLevel:0 withBytes:bytes bytesPerRow:pixelWidth * 4];
        free(bytes);

        int glyphCount = 0;
        CFArrayRef lines = CTFrameGetLines(frame);
        for (CFIndex index = 0; index < CFArrayGetCount(lines); index++) {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, index);
            glyphCount += (int)CTLineGetGlyphCount(line);
        }
        int slot = moxi_metal_text_texture_count++;
        moxi_metal_textures[slot] = texture;
        int drawn = moxi_metal_draw_texture_quad(
            texture,
            x,
            y,
            (float)logicalWidth,
            (float)logicalHeight,
            1.0f,
            m11,
            m12,
            m21,
            m22,
            tx,
            ty
        );
        if (!drawn) {
            moxi_metal_textures[slot] = nil;
            moxi_metal_text_texture_count -= 1;
            glyphCount = -1;
        } else {
            moxi_metal_text_texture_draw_count += 1;
            moxi_metal_text_texture_raster_count += 1;
            if (moxi_metal_text_cache_count < MOXI_METAL_MAX_TEXT_CACHE &&
                byteCount <= MOXI_METAL_MAX_TEXT_CACHE_BYTES -
                    moxi_metal_text_cache_bytes) {
                int cacheSlot = moxi_metal_text_cache_count++;
                moxi_metal_text_cache_keys[cacheSlot] = [cacheKey copy];
                moxi_metal_text_cache_textures[cacheSlot] = texture;
                moxi_metal_text_cache_glyph_counts[cacheSlot] = glyphCount;
                moxi_metal_text_cache_bytes += byteCount;
            }
        }
        CFRelease(frame);
        CFRelease(framesetter);
        CGColorRelease(textColor);
        CFRelease(font);
        return glyphCount;
    }
}

int moxi_metal_draw_text(
    const char *text,
    float x,
    float y,
    float width,
    float height,
    float red,
    float green,
    float blue,
    float alpha,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (moxi_metal_encoder == nil || text == NULL) return -1;
    BOOL ascii = YES;
    for (const unsigned char *cursor = (const unsigned char *)text; *cursor != 0; cursor++) {
        if (*cursor >= 128 || (*cursor != '\n' && *cursor != '\r' && *cursor != '\t' &&
            !moxi_ascii_supported(*cursor))) {
            ascii = NO;
            break;
        }
    }
    if (!ascii) {
        return moxi_metal_draw_coretext_text(
            text, x, y, width, height, red, green, blue, alpha,
            m11, m12, m21, m22, tx, ty
        );
    }
    if (height <= 0.0f) return 0;
    float scale = height / 7.0f;
    float advance = scale * 6.0f;
    float line_height = scale * 8.0f;
    float current_x = x;
    float current_y = y;
    float right = x + (width > 0.0f ? width : 1000000.0f);
    float color[4] = {red, green, blue, alpha};
    int glyph_count = 0;
    for (const unsigned char *cursor = (const unsigned char *)text; *cursor != 0; cursor++) {
        unsigned char value = *cursor;
        if (value == '\n' || value == '\r') {
            if (value == '\n') {
                current_x = x;
                current_y += line_height;
            }
            continue;
        }
        if (value == '\t') {
            current_x += advance * 4.0f;
            continue;
        }
        if (width > 0.0f && current_x > x && current_x + scale * 5.0f > right) {
            current_x = x;
            current_y += line_height;
        }
        for (int row = 0; row < 7; row++) {
            uint8_t bits = moxi_ascii_glyph_row(value, row);
            for (int column = 0; column < 5; column++) {
                if ((bits & (uint8_t)(1 << (4 - column))) != 0) {
                    moxi_append_transformed_rect(
                        current_x + (float)column * scale,
                        current_y + (float)row * scale,
                        scale,
                        scale,
                        color,
                        m11, m12, m21, m22, tx, ty
                    );
                }
            }
        }
        current_x += advance;
        glyph_count += 1;
    }
    return glyph_count;
}

static void moxi_skip_path_separators(const char **cursor) {
    while (**cursor != 0 && (isspace((unsigned char)**cursor) || **cursor == ',')) {
        *cursor += 1;
    }
}

static BOOL moxi_read_path_number(const char **cursor, float *value) {
    moxi_skip_path_separators(cursor);
    if (**cursor == 0) return NO;
    char *end = NULL;
    const char *start = *cursor;
    float result = strtof(start, &end);
    if (end == start || !isfinite(result)) return NO;
    *cursor = end;
    *value = result;
    return YES;
}

static BOOL moxi_append_path_point(
    vector_float2 *points,
    int *count,
    int limit,
    vector_float2 point
) {
    if (*count >= limit) return NO;
    if (*count > 0) {
        vector_float2 previous = points[*count - 1];
        if (fabsf(previous.x - point.x) < 0.0001f &&
            fabsf(previous.y - point.y) < 0.0001f) {
            return YES;
        }
    }
    points[(*count)++] = point;
    return YES;
}

static vector_float2 moxi_quadratic_point(
    vector_float2 start,
    vector_float2 control,
    vector_float2 end,
    float amount
) {
    float inverse = 1.0f - amount;
    return (vector_float2){
        inverse * inverse * start.x + 2.0f * inverse * amount * control.x + amount * amount * end.x,
        inverse * inverse * start.y + 2.0f * inverse * amount * control.y + amount * amount * end.y,
    };
}

static vector_float2 moxi_cubic_point(
    vector_float2 start,
    vector_float2 first_control,
    vector_float2 second_control,
    vector_float2 end,
    float amount
) {
    float inverse = 1.0f - amount;
    float inverse_squared = inverse * inverse;
    float amount_squared = amount * amount;
    return (vector_float2){
        inverse_squared * inverse * start.x +
            3.0f * inverse_squared * amount * first_control.x +
            3.0f * inverse * amount_squared * second_control.x +
            amount_squared * amount * end.x,
        inverse_squared * inverse * start.y +
            3.0f * inverse_squared * amount * first_control.y +
            3.0f * inverse * amount_squared * second_control.y +
            amount_squared * amount * end.y,
    };
}

static BOOL moxi_append_quadratic_path(
    vector_float2 *points,
    int *count,
    int limit,
    vector_float2 start,
    vector_float2 control,
    vector_float2 end
) {
    const int segments = 16;
    for (int segment = 1; segment <= segments; segment++) {
        float amount = (float)segment / (float)segments;
        if (!moxi_append_path_point(
                points, count, limit,
                moxi_quadratic_point(start, control, end, amount))) {
            return NO;
        }
    }
    return YES;
}

static BOOL moxi_append_cubic_path(
    vector_float2 *points,
    int *count,
    int limit,
    vector_float2 start,
    vector_float2 first_control,
    vector_float2 second_control,
    vector_float2 end
) {
    const int segments = 20;
    for (int segment = 1; segment <= segments; segment++) {
        float amount = (float)segment / (float)segments;
        if (!moxi_append_path_point(
                points, count, limit,
                moxi_cubic_point(start, first_control, second_control, end, amount))) {
            return NO;
        }
    }
    return YES;
}

static BOOL moxi_append_arc_path(
    vector_float2 *points,
    int *count,
    int limit,
    vector_float2 start,
    float radius_x,
    float radius_y,
    float rotation_degrees,
    BOOL large_arc,
    BOOL sweep,
    vector_float2 end
) {
    radius_x = fabsf(radius_x);
    radius_y = fabsf(radius_y);
    if (radius_x <= 0.0001f || radius_y <= 0.0001f ||
        (fabsf(start.x - end.x) < 0.0001f &&
         fabsf(start.y - end.y) < 0.0001f)) {
        return moxi_append_path_point(points, count, limit, end);
    }

    const float pi = 3.14159265358979323846f;
    const float two_pi = 2.0f * pi;
    float phi = fmodf(rotation_degrees * pi / 180.0f, two_pi);
    float cosine = cosf(phi);
    float sine = sinf(phi);
    float delta_x = (start.x - end.x) * 0.5f;
    float delta_y = (start.y - end.y) * 0.5f;
    float prime_x = cosine * delta_x + sine * delta_y;
    float prime_y = -sine * delta_x + cosine * delta_y;
    float radius_x_squared = radius_x * radius_x;
    float radius_y_squared = radius_y * radius_y;
    float prime_x_squared = prime_x * prime_x;
    float prime_y_squared = prime_y * prime_y;
    float radius_ratio = prime_x_squared / radius_x_squared +
        prime_y_squared / radius_y_squared;
    if (radius_ratio > 1.0f) {
        float correction = sqrtf(radius_ratio);
        radius_x *= correction;
        radius_y *= correction;
        radius_x_squared = radius_x * radius_x;
        radius_y_squared = radius_y * radius_y;
    }

    float denominator = radius_x_squared * prime_y_squared +
        radius_y_squared * prime_x_squared;
    if (denominator <= 0.000001f) {
        return moxi_append_path_point(points, count, limit, end);
    }
    float numerator = radius_x_squared * radius_y_squared -
        radius_x_squared * prime_y_squared -
        radius_y_squared * prime_x_squared;
    float coefficient = sqrtf(fmaxf(0.0f, numerator / denominator));
    if (large_arc == sweep) coefficient = -coefficient;
    float center_prime_x = coefficient * radius_x * prime_y / radius_y;
    float center_prime_y = -coefficient * radius_y * prime_x / radius_x;
    float midpoint_x = (start.x + end.x) * 0.5f;
    float midpoint_y = (start.y + end.y) * 0.5f;
    float center_x = cosine * center_prime_x - sine * center_prime_y + midpoint_x;
    float center_y = sine * center_prime_x + cosine * center_prime_y + midpoint_y;

    float unit_start_x = (prime_x - center_prime_x) / radius_x;
    float unit_start_y = (prime_y - center_prime_y) / radius_y;
    float unit_end_x = (-prime_x - center_prime_x) / radius_x;
    float unit_end_y = (-prime_y - center_prime_y) / radius_y;
    float start_angle = atan2f(unit_start_y, unit_start_x);
    float delta_angle = atan2f(
        unit_start_x * unit_end_y - unit_start_y * unit_end_x,
        unit_start_x * unit_end_x + unit_start_y * unit_end_y
    );
    if (!sweep && delta_angle > 0.0f) delta_angle -= two_pi;
    if (sweep && delta_angle < 0.0f) delta_angle += two_pi;
    int segments = (int)ceilf(fabsf(delta_angle) / (pi / 16.0f));
    if (segments < 1) segments = 1;
    if (segments > 256) segments = 256;
    for (int segment = 1; segment <= segments; segment++) {
        float amount = (float)segment / (float)segments;
        float angle = start_angle + delta_angle * amount;
        vector_float2 point = {
            center_x + cosine * radius_x * cosf(angle) -
                sine * radius_y * sinf(angle),
            center_y + sine * radius_x * cosf(angle) +
                cosine * radius_y * sinf(angle),
        };
        if (segment == segments) point = end;
        if (!moxi_append_path_point(points, count, limit, point)) return NO;
    }
    return YES;
}

typedef struct {
    int start;
    int count;
    BOOL closed;
} MoxiPathSubpath;

static BOOL moxi_finish_path_subpath(
    vector_float2 *points,
    int *point_count,
    MoxiPathSubpath *subpaths,
    int *subpath_count,
    int subpath_limit,
    int start,
    BOOL closed
) {
    if (start < 0) return YES;
    int count = *point_count - start;
    while (count > 1) {
        vector_float2 first = points[start];
        vector_float2 last = points[start + count - 1];
        if (fabsf(first.x - last.x) >= 0.0001f ||
            fabsf(first.y - last.y) >= 0.0001f) {
            break;
        }
        *point_count -= 1;
        count -= 1;
    }
    if (count < 2 || *subpath_count >= subpath_limit) return NO;
    subpaths[*subpath_count] = (MoxiPathSubpath){start, count, closed};
    *subpath_count += 1;
    return YES;
}

static int moxi_parse_compound_path(
    const char *data,
    vector_float2 *points,
    int point_limit,
    MoxiPathSubpath *subpaths,
    int subpath_limit,
    int *subpath_count
) {
    if (data == NULL || points == NULL || subpaths == NULL ||
        subpath_count == NULL || point_limit < 3 || subpath_limit < 1) return -1;
    const char *cursor = data;
    char command = 0;
    int point_count = 0;
    int subpath_start = -1;
    BOOL subpath_closed = NO;
    vector_float2 current = {0.0f, 0.0f};
    vector_float2 previous_cubic_control = {0.0f, 0.0f};
    vector_float2 previous_quadratic_control = {0.0f, 0.0f};
    BOOL previous_was_cubic = NO;
    BOOL previous_was_quadratic = NO;
    *subpath_count = 0;
    while (1) {
        moxi_skip_path_separators(&cursor);
        if (*cursor == 0) break;
        if (isalpha((unsigned char)*cursor)) {
            command = *cursor++;
            if (command == 'Z' || command == 'z') {
                if (subpath_start < 0 || point_count - subpath_start < 2) return -1;
                subpath_closed = YES;
                current = points[subpath_start];
                command = 0;
                previous_was_cubic = NO;
                previous_was_quadratic = NO;
                continue;
            }
        } else if (command == 0) {
            return -1;
        }
        BOOL relative = command >= 'a' && command <= 'z';
        char normalized = relative ? (char)(command - 'a' + 'A') : command;
        float first = 0.0f;
        float second = 0.0f;
        if (normalized == 'M' || normalized == 'L') {
            if (!moxi_read_path_number(&cursor, &first) ||
                !moxi_read_path_number(&cursor, &second)) return -1;
            vector_float2 next = {first, second};
            if (relative) {
                next.x += current.x;
                next.y += current.y;
            }
            if (normalized == 'M') {
                if (!moxi_finish_path_subpath(
                        points, &point_count, subpaths, subpath_count,
                        subpath_limit, subpath_start, subpath_closed)) return -1;
                subpath_start = point_count;
                subpath_closed = NO;
                if (point_count >= point_limit) return -1;
                points[point_count++] = next;
                current = next;
                previous_was_cubic = NO;
                previous_was_quadratic = NO;
                command = relative ? 'l' : 'L';
                continue;
            }
            if (subpath_start < 0 ||
                !moxi_append_path_point(points, &point_count, point_limit, next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_was_cubic = NO;
            previous_was_quadratic = NO;
        } else if (normalized == 'H') {
            if (!moxi_read_path_number(&cursor, &first)) return -1;
            if (subpath_start < 0) return -1;
            vector_float2 next = {relative ? current.x + first : first, current.y};
            if (!moxi_append_path_point(points, &point_count, point_limit, next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_was_cubic = NO;
            previous_was_quadratic = NO;
        } else if (normalized == 'V') {
            if (!moxi_read_path_number(&cursor, &first)) return -1;
            if (subpath_start < 0) return -1;
            vector_float2 next = {current.x, relative ? current.y + first : first};
            if (!moxi_append_path_point(points, &point_count, point_limit, next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_was_cubic = NO;
            previous_was_quadratic = NO;
        } else if (normalized == 'A') {
            if (subpath_start < 0) return -1;
            float radius_x = 0.0f;
            float radius_y = 0.0f;
            float rotation = 0.0f;
            float large_arc_value = 0.0f;
            float sweep_value = 0.0f;
            float end_x = 0.0f;
            float end_y = 0.0f;
            if (!moxi_read_path_number(&cursor, &radius_x) ||
                !moxi_read_path_number(&cursor, &radius_y) ||
                !moxi_read_path_number(&cursor, &rotation) ||
                !moxi_read_path_number(&cursor, &large_arc_value) ||
                !moxi_read_path_number(&cursor, &sweep_value) ||
                !moxi_read_path_number(&cursor, &end_x) ||
                !moxi_read_path_number(&cursor, &end_y)) return -1;
            if ((fabsf(large_arc_value) > 0.0001f &&
                 fabsf(large_arc_value - 1.0f) > 0.0001f) ||
                (fabsf(sweep_value) > 0.0001f &&
                 fabsf(sweep_value - 1.0f) > 0.0001f)) return -1;
            vector_float2 next = {end_x, end_y};
            if (relative) {
                next.x += current.x;
                next.y += current.y;
            }
            if (!moxi_append_arc_path(
                    points, &point_count, point_limit, current, radius_x, radius_y,
                    rotation, large_arc_value > 0.5f, sweep_value > 0.5f,
                    next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_was_cubic = NO;
            previous_was_quadratic = NO;
        } else if (normalized == 'Q' || normalized == 'T') {
            if (subpath_start < 0) return -1;
            vector_float2 control = current;
            vector_float2 next = current;
            if (normalized == 'Q') {
                if (!moxi_read_path_number(&cursor, &first) ||
                    !moxi_read_path_number(&cursor, &second)) return -1;
                control = (vector_float2){first, second};
                if (relative) {
                    control.x += current.x;
                    control.y += current.y;
                }
                if (!moxi_read_path_number(&cursor, &first) ||
                    !moxi_read_path_number(&cursor, &second)) return -1;
                next = (vector_float2){first, second};
                if (relative) {
                    next.x += current.x;
                    next.y += current.y;
                }
            } else {
                if (!moxi_read_path_number(&cursor, &first) ||
                    !moxi_read_path_number(&cursor, &second)) return -1;
                next = (vector_float2){first, second};
                if (relative) {
                    next.x += current.x;
                    next.y += current.y;
                }
                if (previous_was_quadratic) {
                    control = (vector_float2){
                        2.0f * current.x - previous_quadratic_control.x,
                        2.0f * current.y - previous_quadratic_control.y,
                    };
                }
            }
            if (!moxi_append_quadratic_path(
                    points, &point_count, point_limit, current, control, next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_quadratic_control = control;
            previous_was_quadratic = YES;
            previous_was_cubic = NO;
        } else if (normalized == 'C' || normalized == 'S') {
            if (subpath_start < 0) return -1;
            vector_float2 first_control = current;
            vector_float2 second_control = current;
            vector_float2 next = current;
            if (normalized == 'C') {
                float third = 0.0f;
                float fourth = 0.0f;
                if (!moxi_read_path_number(&cursor, &first) ||
                    !moxi_read_path_number(&cursor, &second) ||
                    !moxi_read_path_number(&cursor, &third) ||
                    !moxi_read_path_number(&cursor, &fourth)) return -1;
                first_control = (vector_float2){first, second};
                second_control = (vector_float2){third, fourth};
                if (relative) {
                    first_control.x += current.x;
                    first_control.y += current.y;
                    second_control.x += current.x;
                    second_control.y += current.y;
                }
                if (!moxi_read_path_number(&cursor, &first) ||
                    !moxi_read_path_number(&cursor, &second)) return -1;
                next = (vector_float2){first, second};
                if (relative) {
                    next.x += current.x;
                    next.y += current.y;
                }
            } else {
                float second_x = 0.0f;
                float second_y = 0.0f;
                float end_x = 0.0f;
                float end_y = 0.0f;
                if (!moxi_read_path_number(&cursor, &second_x) ||
                    !moxi_read_path_number(&cursor, &second_y) ||
                    !moxi_read_path_number(&cursor, &end_x) ||
                    !moxi_read_path_number(&cursor, &end_y)) return -1;
                if (previous_was_cubic) {
                    first_control = (vector_float2){
                        2.0f * current.x - previous_cubic_control.x,
                        2.0f * current.y - previous_cubic_control.y,
                    };
                }
                second_control = (vector_float2){second_x, second_y};
                next = (vector_float2){end_x, end_y};
                if (relative) {
                    second_control.x += current.x;
                    second_control.y += current.y;
                    next.x += current.x;
                    next.y += current.y;
                }
            }
            if (!moxi_append_cubic_path(
                    points, &point_count, point_limit, current,
                    first_control, second_control, next)) return -1;
            current = next;
            subpath_closed = NO;
            previous_cubic_control = second_control;
            previous_was_cubic = YES;
            previous_was_quadratic = NO;
        } else {
            return -1;
        }
    }
    if (!moxi_finish_path_subpath(
            points, &point_count, subpaths, subpath_count,
            subpath_limit, subpath_start, subpath_closed)) return -1;
    return point_count >= 2 && *subpath_count > 0 ? point_count : -1;
}

static float moxi_path_cross(
    vector_float2 first,
    vector_float2 second,
    vector_float2 third
) {
    return (second.x - first.x) * (third.y - first.y) -
        (second.y - first.y) * (third.x - first.x);
}

static BOOL moxi_path_point_in_triangle(
    vector_float2 point,
    vector_float2 first,
    vector_float2 second,
    vector_float2 third,
    float orientation
) {
    const float epsilon = 0.00001f;
    float first_cross = orientation * moxi_path_cross(first, second, point);
    float second_cross = orientation * moxi_path_cross(second, third, point);
    float third_cross = orientation * moxi_path_cross(third, first, point);
    return first_cross >= -epsilon && second_cross >= -epsilon && third_cross >= -epsilon;
}

static BOOL moxi_append_polygon_fill(
    vector_float2 *points,
    int count,
    const float color[4],
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (count < 3) return NO;
    while (count > 3) {
        vector_float2 first = points[0];
        vector_float2 last = points[count - 1];
        if (fabsf(first.x - last.x) >= 0.0001f ||
            fabsf(first.y - last.y) >= 0.0001f) break;
        count -= 1;
    }
    if (count < 3) return NO;

    float area = 0.0f;
    for (int index = 0; index < count; index++) {
        vector_float2 first = points[index];
        vector_float2 second = points[(index + 1) % count];
        area += first.x * second.y - second.x * first.y;
    }
    if (fabsf(area) < 0.00001f) return NO;
    float orientation = area > 0.0f ? 1.0f : -1.0f;
    int original_vertex_count = moxi_metal_vertex_count;
    if (!moxi_metal_reserve_vertices((count - 2) * 3)) return NO;

    int indices[4096];
    for (int index = 0; index < count; index++) indices[index] = index;
    int remaining = count;
    int guard = 0;
    while (remaining > 3 && guard < count * count) {
        BOOL found_ear = NO;
        for (int index = 0; index < remaining; index++) {
            int previous_index = indices[(index + remaining - 1) % remaining];
            int current_index = indices[index];
            int next_index = indices[(index + 1) % remaining];
            vector_float2 previous = points[previous_index];
            vector_float2 current = points[current_index];
            vector_float2 next = points[next_index];
            if (orientation * moxi_path_cross(previous, current, next) <= 0.00001f) {
                continue;
            }
            BOOL contains_point = NO;
            for (int candidate = 0; candidate < remaining; candidate++) {
                int candidate_index = indices[candidate];
                if (candidate_index == previous_index ||
                    candidate_index == current_index ||
                    candidate_index == next_index) {
                    continue;
                }
                if (moxi_path_point_in_triangle(
                        points[candidate_index], previous, current, next, orientation)) {
                    contains_point = YES;
                    break;
                }
            }
            if (contains_point) continue;
            moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
                previous.x, previous.y, color, m11, m12, m21, m22, tx, ty);
            moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
                current.x, current.y, color, m11, m12, m21, m22, tx, ty);
            moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
                next.x, next.y, color, m11, m12, m21, m22, tx, ty);
            for (int shift = index; shift < remaining - 1; shift++) {
                indices[shift] = indices[shift + 1];
            }
            remaining -= 1;
            found_ear = YES;
            break;
        }
        if (!found_ear) {
            moxi_metal_vertex_count = original_vertex_count;
            return NO;
        }
        guard += 1;
    }
    if (remaining != 3) {
        moxi_metal_vertex_count = original_vertex_count;
        return NO;
    }
    moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
        points[indices[0]].x, points[indices[0]].y, color, m11, m12, m21, m22, tx, ty);
    moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
        points[indices[1]].x, points[indices[1]].y, color, m11, m12, m21, m22, tx, ty);
    moxi_metal_vertices[moxi_metal_vertex_count++] = moxi_transformed_vertex(
        points[indices[2]].x, points[indices[2]].y, color, m11, m12, m21, m22, tx, ty);
    return YES;
}

typedef struct {
    float x_at_sample;
    float x_at_top;
    float x_at_bottom;
} MoxiScanlineIntersection;

static int moxi_compare_float_values(const void *left, const void *right) {
    float first = *(const float *)left;
    float second = *(const float *)right;
    if (first < second) return -1;
    if (first > second) return 1;
    return 0;
}

static int moxi_compare_scanline_intersections(
    const void *left,
    const void *right
) {
    float first = ((const MoxiScanlineIntersection *)left)->x_at_sample;
    float second = ((const MoxiScanlineIntersection *)right)->x_at_sample;
    if (first < second) return -1;
    if (first > second) return 1;
    return 0;
}

static float moxi_clamp_path_amount(float value) {
    if (value < 0.0f) return 0.0f;
    if (value > 1.0f) return 1.0f;
    return value;
}

static BOOL moxi_append_compound_even_odd_fill(
    vector_float2 *points,
    int point_count,
    MoxiPathSubpath *subpaths,
    int subpath_count,
    const float color[4],
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (points == NULL || subpaths == NULL || point_count < 3 ||
        subpath_count < 1) return NO;
    float y_values[MOXI_METAL_MAX_PATH_POINTS];
    int y_count = 0;
    for (int index = 0; index < point_count; index++) {
        if (y_count >= MOXI_METAL_MAX_PATH_POINTS) return NO;
        y_values[y_count++] = points[index].y;
    }
    qsort(y_values, (size_t)y_count, sizeof(float), moxi_compare_float_values);
    int unique_y_count = 0;
    for (int index = 0; index < y_count; index++) {
        if (unique_y_count == 0 ||
            fabsf(y_values[index] - y_values[unique_y_count - 1]) >= 0.0001f) {
            y_values[unique_y_count++] = y_values[index];
        }
    }

    int original_vertex_count = moxi_metal_vertex_count;
    int triangle_count = 0;
    for (int y_index = 0; y_index + 1 < unique_y_count; y_index++) {
        float top = y_values[y_index];
        float bottom = y_values[y_index + 1];
        if (bottom - top <= 0.0001f) continue;
        float sample = (top + bottom) * 0.5f;
        MoxiScanlineIntersection intersections[MOXI_METAL_MAX_SCANLINE_INTERSECTIONS];
        int intersection_count = 0;
        for (int subpath_index = 0; subpath_index < subpath_count; subpath_index++) {
            MoxiPathSubpath subpath = subpaths[subpath_index];
            if (subpath.count < 2) continue;
            for (int edge_index = 0; edge_index < subpath.count; edge_index++) {
                int first_index = subpath.start + edge_index;
                int second_index = subpath.start + ((edge_index + 1) % subpath.count);
                vector_float2 first = points[first_index];
                vector_float2 second = points[second_index];
                float delta_y = second.y - first.y;
                if (fabsf(delta_y) <= 0.0001f) continue;
                float lower = first.y < second.y ? first.y : second.y;
                float upper = first.y > second.y ? first.y : second.y;
                if (sample <= lower || sample >= upper) continue;
                if (intersection_count >= MOXI_METAL_MAX_SCANLINE_INTERSECTIONS) {
                    moxi_metal_overflow_count += 1;
                    moxi_metal_vertex_count = original_vertex_count;
                    return NO;
                }
                float sample_amount = moxi_clamp_path_amount(
                    (sample - first.y) / delta_y);
                float top_amount = moxi_clamp_path_amount(
                    (top - first.y) / delta_y);
                float bottom_amount = moxi_clamp_path_amount(
                    (bottom - first.y) / delta_y);
                intersections[intersection_count++] = (MoxiScanlineIntersection){
                    first.x + (second.x - first.x) * sample_amount,
                    first.x + (second.x - first.x) * top_amount,
                    first.x + (second.x - first.x) * bottom_amount,
                };
            }
        }
        if (intersection_count == 0) continue;
        if ((intersection_count & 1) != 0) {
            moxi_metal_vertex_count = original_vertex_count;
            return NO;
        }
        qsort(
            intersections,
            (size_t)intersection_count,
            sizeof(MoxiScanlineIntersection),
            moxi_compare_scanline_intersections
        );
        for (int intersection_index = 0;
             intersection_index + 1 < intersection_count;
             intersection_index += 2) {
            MoxiScanlineIntersection left = intersections[intersection_index];
            MoxiScanlineIntersection right = intersections[intersection_index + 1];
            if (right.x_at_sample - left.x_at_sample <= 0.0001f) continue;
            if (triangle_count + 2 > MOXI_METAL_MAX_TESSELLATION_TRIANGLES ||
                !moxi_metal_reserve_vertices(6)) {
                moxi_metal_vertex_count = original_vertex_count;
                return NO;
            }
            MoxiMetalVertex top_left = moxi_transformed_vertex(
                left.x_at_top, top, color, m11, m12, m21, m22, tx, ty);
            MoxiMetalVertex top_right = moxi_transformed_vertex(
                right.x_at_top, top, color, m11, m12, m21, m22, tx, ty);
            MoxiMetalVertex bottom_left = moxi_transformed_vertex(
                left.x_at_bottom, bottom, color, m11, m12, m21, m22, tx, ty);
            MoxiMetalVertex bottom_right = moxi_transformed_vertex(
                right.x_at_bottom, bottom, color, m11, m12, m21, m22, tx, ty);
            moxi_metal_vertices[moxi_metal_vertex_count++] = top_left;
            moxi_metal_vertices[moxi_metal_vertex_count++] = top_right;
            moxi_metal_vertices[moxi_metal_vertex_count++] = bottom_left;
            moxi_metal_vertices[moxi_metal_vertex_count++] = bottom_left;
            moxi_metal_vertices[moxi_metal_vertex_count++] = top_right;
            moxi_metal_vertices[moxi_metal_vertex_count++] = bottom_right;
            triangle_count += 2;
        }
    }
    if (triangle_count == 0) {
        moxi_metal_vertex_count = original_vertex_count;
        return NO;
    }
    return YES;
}

int moxi_metal_draw_path(
    const char *path_data,
    float fill_red,
    float fill_green,
    float fill_blue,
    float fill_alpha,
    float stroke_red,
    float stroke_green,
    float stroke_blue,
    float stroke_alpha,
    float stroke_width,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (moxi_metal_encoder == nil) return -1;
    vector_float2 points[MOXI_METAL_MAX_PATH_POINTS];
    MoxiPathSubpath subpaths[MOXI_METAL_MAX_PATH_SUBPATHS];
    int subpath_count = 0;
    int point_count = moxi_parse_compound_path(
        path_data,
        points,
        MOXI_METAL_MAX_PATH_POINTS,
        subpaths,
        MOXI_METAL_MAX_PATH_SUBPATHS,
        &subpath_count
    );
    if (point_count < 0 || subpath_count < 1) return -1;
    float fill[4] = {fill_red, fill_green, fill_blue, fill_alpha};
    if (fill_alpha > 0.0f) {
        BOOL filled = NO;
        if (subpath_count == 1 && subpaths[0].count >= 3) {
            filled = moxi_append_polygon_fill(
                points + subpaths[0].start,
                subpaths[0].count,
                fill,
                m11,
                m12,
                m21,
                m22,
                tx,
                ty
            );
        }
        if (!filled) {
            filled = moxi_append_compound_even_odd_fill(
                points,
                point_count,
                subpaths,
                subpath_count,
                fill,
                m11,
                m12,
                m21,
                m22,
                tx,
                ty
            );
        }
        if (!filled) return -1;
    }
    if (stroke_alpha > 0.0f && stroke_width > 0.0f) {
        float stroke[4] = {stroke_red, stroke_green, stroke_blue, stroke_alpha};
        for (int subpath_index = 0; subpath_index < subpath_count; subpath_index++) {
            MoxiPathSubpath subpath = subpaths[subpath_index];
            int segment_count = subpath.closed ? subpath.count : subpath.count - 1;
            for (int index = 0; index < segment_count; index++) {
                int first_index = subpath.start + index;
                int next_index = subpath.start + ((index + 1) % subpath.count);
                vector_float2 start = moxi_transform_point(
                    points[first_index].x,
                    points[first_index].y,
                    m11,
                    m12,
                    m21,
                    m22,
                    tx,
                    ty
                );
                vector_float2 end = moxi_transform_point(
                    points[next_index].x,
                    points[next_index].y,
                    m11,
                    m12,
                    m21,
                    m22,
                    tx,
                    ty
                );
                moxi_append_line(start.x, start.y, end.x, end.y, stroke_width, stroke);
            }
        }
    }
    return point_count;
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
    id<MTLFunction> imageVertex = [library newFunctionWithName:@"moxi_image_vertex"];
    id<MTLFunction> imageFragment = [library newFunctionWithName:@"moxi_image_fragment"];
    if (vertex == nil || fragment == nil || imageVertex == nil || imageFragment == nil) {
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
    if (moxi_metal_pipeline == nil) return NO;
    MTLRenderPipelineDescriptor *imageDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    imageDescriptor.vertexFunction = imageVertex;
    imageDescriptor.fragmentFunction = imageFragment;
    imageDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    imageDescriptor.colorAttachments[0].blendingEnabled = YES;
    imageDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    imageDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    imageDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    imageDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    imageDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    imageDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    moxi_metal_image_pipeline = [moxi_metal_device newRenderPipelineStateWithDescriptor:imageDescriptor error:&error];
    if (moxi_metal_image_pipeline == nil) return NO;
    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    moxi_metal_image_sampler = [moxi_metal_device newSamplerStateWithDescriptor:samplerDescriptor];
    return moxi_metal_image_sampler != nil;
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

static int moxi_metal_find_image(int resource_id) {
    for (int index = 0; index < MOXI_METAL_MAX_IMAGES; index++) {
        if (moxi_metal_image_ids[index] == resource_id && moxi_metal_images[index] != nil) {
            return index;
        }
    }
    return -1;
}

int moxi_metal_register_image_file(int resource_id, const char *source) {
    if (!moxi_metal_initialized || moxi_metal_device == nil || source == NULL || resource_id < 0) {
        return 0;
    }
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:source];
        if (path == nil) return 0;
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        if (image == nil) image = [NSImage imageNamed:path];
        if (image == nil) return 0;
        NSRect proposed = NSMakeRect(0.0, 0.0, image.size.width, image.size.height);
        CGImageRef cgImage = [image CGImageForProposedRect:&proposed context:nil hints:nil];
        if (cgImage == NULL) return 0;
        size_t width = CGImageGetWidth(cgImage);
        size_t height = CGImageGetHeight(cgImage);
        if (width == 0 || height == 0) return 0;
        size_t byteCount = width * height * 4;
        uint8_t *bytes = (uint8_t *)calloc(1, byteCount);
        if (bytes == NULL) return 0;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(
            bytes, width, height, 8, width * 4, colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
        );
        if (context == NULL) {
            CGColorSpaceRelease(colorSpace);
            free(bytes);
            return 0;
        }
        CGContextDrawImage(context, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), cgImage);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                                 width:width
                                                                                                height:height
                                                                                             mipmapped:NO];
        descriptor.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [moxi_metal_device newTextureWithDescriptor:descriptor];
        if (texture == nil) {
            free(bytes);
            return 0;
        }
        MTLRegion region = MTLRegionMake2D(0, 0, width, height);
        [texture replaceRegion:region mipmapLevel:0 withBytes:bytes bytesPerRow:width * 4];
        free(bytes);
        int slot = moxi_metal_find_image(resource_id);
        if (slot < 0) {
            for (int index = 0; index < MOXI_METAL_MAX_IMAGES; index++) {
                if (moxi_metal_image_ids[index] < 0) {
                    slot = index;
                    break;
                }
            }
        }
        if (slot < 0) return 0;
        moxi_metal_image_ids[slot] = resource_id;
        moxi_metal_images[slot] = texture;
        return 1;
    }
}

void moxi_metal_release_image(int resource_id) {
    int slot = moxi_metal_find_image(resource_id);
    if (slot < 0) return;
    moxi_metal_images[slot] = nil;
    moxi_metal_image_ids[slot] = -1;
}

static void moxi_metal_flush_geometry(void) {
    if (moxi_metal_encoder == nil || moxi_metal_vertex_count <= 0) return;
    [moxi_metal_encoder setRenderPipelineState:moxi_metal_pipeline];
    [moxi_metal_encoder setVertexBuffer:moxi_metal_vertex_buffer offset:0 atIndex:0];
    [moxi_metal_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:(NSUInteger)moxi_metal_vertex_count];
    moxi_metal_draw_submission_count += 1;
    moxi_metal_submitted_vertex_count += moxi_metal_vertex_count;
    moxi_metal_vertex_count = 0;
}

static int moxi_metal_draw_texture_quad(
    id<MTLTexture> texture,
    float x,
    float y,
    float width,
    float height,
    float alpha,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (moxi_metal_encoder == nil || texture == nil ||
        moxi_metal_image_buffer == nil || moxi_metal_image_pipeline == nil ||
        width <= 0.0f || height <= 0.0f) {
        return 0;
    }
    vector_float2 topLeft = moxi_transform_point(x, y, m11, m12, m21, m22, tx, ty);
    vector_float2 topRight = moxi_transform_point(x + width, y, m11, m12, m21, m22, tx, ty);
    vector_float2 bottomLeft = moxi_transform_point(x, y + height, m11, m12, m21, m22, tx, ty);
    vector_float2 bottomRight = moxi_transform_point(x + width, y + height, m11, m12, m21, m22, tx, ty);
    vector_float4 color = (vector_float4){1.0f, 1.0f, 1.0f, moxi_clamp(alpha)};
    MoxiMetalImageVertex *vertices = moxi_metal_image_vertices;
    vertices[0] = (MoxiMetalImageVertex){moxi_ndc(topLeft.x, topLeft.y), (vector_float2){0.0f, 0.0f}, color};
    vertices[1] = (MoxiMetalImageVertex){moxi_ndc(topRight.x, topRight.y), (vector_float2){1.0f, 0.0f}, color};
    vertices[2] = (MoxiMetalImageVertex){moxi_ndc(bottomLeft.x, bottomLeft.y), (vector_float2){0.0f, 1.0f}, color};
    vertices[3] = vertices[2];
    vertices[4] = vertices[1];
    vertices[5] = (MoxiMetalImageVertex){moxi_ndc(bottomRight.x, bottomRight.y), (vector_float2){1.0f, 1.0f}, color};
    moxi_metal_flush_geometry();
    [moxi_metal_encoder setRenderPipelineState:moxi_metal_image_pipeline];
    [moxi_metal_encoder setVertexBuffer:moxi_metal_image_buffer offset:0 atIndex:0];
    [moxi_metal_encoder setFragmentTexture:texture atIndex:0];
    [moxi_metal_encoder setFragmentSamplerState:moxi_metal_image_sampler atIndex:0];
    [moxi_metal_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    moxi_metal_draw_submission_count += 1;
    [moxi_metal_encoder setRenderPipelineState:moxi_metal_pipeline];
    return 1;
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
    moxi_metal_image_buffer = [moxi_metal_device newBufferWithLength:sizeof(MoxiMetalImageVertex) * 6
                                                                options:MTLResourceStorageModeShared];
    if (moxi_metal_image_buffer == nil) return 0;
    moxi_metal_vertices = (MoxiMetalVertex *)[moxi_metal_vertex_buffer contents];
    moxi_metal_image_vertices = (MoxiMetalImageVertex *)[moxi_metal_image_buffer contents];
    moxi_metal_vertex_capacity = MOXI_METAL_INITIAL_VERTICES;
    moxi_metal_vertex_count = 0;
    moxi_metal_submitted_vertex_count = 0;
    moxi_metal_overflow_count = 0;
    moxi_metal_frame_count = 0;
    moxi_metal_buffer_reallocation_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_resize_count = 0;
    moxi_metal_last_gpu_time_ms = 0.0f;
    moxi_metal_last_cpu_encode_time_ms = 0.0f;
    moxi_metal_last_cpu_wait_time_ms = 0.0f;
    moxi_metal_last_frame_time_ms = 0.0f;
    moxi_metal_gpu_timing_available = NO;
    moxi_metal_frame_start_time = 0.0;
    moxi_metal_encode_start_time = 0.0;
    moxi_metal_line_geometry_start_time = 0.0;
    moxi_metal_last_line_geometry_time_ms = 0.0f;
    moxi_metal_clip_depth = 0;
    for (int index = 0; index < MOXI_METAL_MAX_IMAGES; index++) {
        moxi_metal_image_ids[index] = -1;
        moxi_metal_images[index] = nil;
    }
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_TEXTURES; index++) {
        moxi_metal_textures[index] = nil;
    }
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_CACHE; index++) {
        moxi_metal_text_cache_keys[index] = nil;
        moxi_metal_text_cache_textures[index] = nil;
        moxi_metal_text_cache_glyph_counts[index] = 0;
    }
    moxi_metal_text_texture_count = 0;
    moxi_metal_text_texture_draw_count = 0;
    moxi_metal_text_cache_count = 0;
    moxi_metal_text_cache_bytes = 0;
    moxi_metal_text_texture_cache_hit_count = 0;
    moxi_metal_text_texture_raster_count = 0;
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
    moxi_metal_submitted_vertex_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_clip_depth = 0;
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_TEXTURES; index++) {
        moxi_metal_textures[index] = nil;
    }
    moxi_metal_text_texture_count = 0;
    moxi_metal_text_texture_draw_count = 0;
    moxi_metal_text_texture_cache_hit_count = 0;
    moxi_metal_text_texture_raster_count = 0;
    moxi_metal_last_gpu_time_ms = 0.0f;
    moxi_metal_last_cpu_encode_time_ms = 0.0f;
    moxi_metal_last_cpu_wait_time_ms = 0.0f;
    moxi_metal_last_frame_time_ms = 0.0f;
    moxi_metal_gpu_timing_available = NO;
    moxi_metal_line_geometry_start_time = 0.0;
    moxi_metal_last_line_geometry_time_ms = 0.0f;
    moxi_metal_frame_start_time = CFAbsoluteTimeGetCurrent();
    moxi_metal_encode_start_time = moxi_metal_frame_start_time;
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

void moxi_metal_draw_circle(
    float center_x,
    float center_y,
    float radius,
    float red,
    float green,
    float blue,
    float alpha
) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) {
        moxi_append_circle(center_x, center_y, radius, color);
    }
}

void moxi_metal_draw_circle_ring(
    float center_x,
    float center_y,
    float inner_radius,
    float outer_radius,
    float red,
    float green,
    float blue,
    float alpha
) {
    float color[4] = {red, green, blue, alpha};
    if (moxi_metal_encoder != nil) {
        moxi_append_circle_ring(
            center_x,
            center_y,
            inner_radius,
            outer_radius,
            color
        );
    }
}

void moxi_metal_begin_line_geometry(void) {
    if (moxi_metal_encoder != nil) {
        moxi_metal_line_geometry_start_time = CFAbsoluteTimeGetCurrent();
    }
}

void moxi_metal_end_line_geometry(void) {
    if (moxi_metal_line_geometry_start_time <= 0.0) return;
    moxi_metal_last_line_geometry_time_ms = (float)(
        (CFAbsoluteTimeGetCurrent() - moxi_metal_line_geometry_start_time) * 1000.0
    );
    moxi_metal_line_geometry_start_time = 0.0;
}

int moxi_metal_draw_image(
    int resource_id,
    float x,
    float y,
    float width,
    float height,
    float alpha,
    float m11,
    float m12,
    float m21,
    float m22,
    float tx,
    float ty
) {
    if (moxi_metal_encoder == nil || moxi_metal_image_buffer == nil ||
        moxi_metal_image_pipeline == nil) return 0;
    int slot = moxi_metal_find_image(resource_id);
    if (slot < 0 || width <= 0.0f || height <= 0.0f) return 0;
    return moxi_metal_draw_texture_quad(
        moxi_metal_images[slot],
        x,
        y,
        width,
        height,
        alpha,
        m11,
        m12,
        m21,
        m22,
        tx,
        ty
    );
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
    moxi_metal_flush_geometry();
    [moxi_metal_encoder endEncoding];
    if (moxi_metal_drawable != nil) {
        [moxi_metal_command_buffer presentDrawable:moxi_metal_drawable];
    }
    CFTimeInterval encode_end = CFAbsoluteTimeGetCurrent();
    moxi_metal_last_cpu_encode_time_ms =
        (float)((encode_end - moxi_metal_encode_start_time) * 1000.0);
    [moxi_metal_command_buffer commit];
    CFTimeInterval wait_start = CFAbsoluteTimeGetCurrent();
    [moxi_metal_command_buffer waitUntilCompleted];
    CFTimeInterval wait_end = CFAbsoluteTimeGetCurrent();
    moxi_metal_last_cpu_wait_time_ms =
        (float)((wait_end - wait_start) * 1000.0);
    moxi_metal_last_frame_time_ms =
        (float)((wait_end - moxi_metal_frame_start_time) * 1000.0);
    if (moxi_metal_command_buffer.GPUStartTime > 0.0 &&
        moxi_metal_command_buffer.GPUEndTime >= moxi_metal_command_buffer.GPUStartTime) {
        moxi_metal_last_gpu_time_ms = (float)(
            (moxi_metal_command_buffer.GPUEndTime -
             moxi_metal_command_buffer.GPUStartTime) * 1000.0
        );
        moxi_metal_gpu_timing_available = YES;
    }
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_drawable = nil;
    moxi_metal_render_texture = nil;
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_TEXTURES; index++) {
        moxi_metal_textures[index] = nil;
    }
    moxi_metal_text_texture_count = 0;
    moxi_metal_frame_count += 1;
}

int moxi_metal_frame_count_value(void) { return moxi_metal_frame_count; }
int moxi_metal_vertex_count_value(void) { return moxi_metal_submitted_vertex_count; }
int moxi_metal_overflow_count_value(void) { return moxi_metal_overflow_count; }
int moxi_metal_buffer_capacity_value(void) { return (int)moxi_metal_vertex_capacity; }
int moxi_metal_buffer_reallocation_count_value(void) { return moxi_metal_buffer_reallocation_count; }
int moxi_metal_draw_submission_count_value(void) { return moxi_metal_draw_submission_count; }
int moxi_metal_resize_count_value(void) { return moxi_metal_resize_count; }
float moxi_metal_gpu_time_ms_value(void) { return moxi_metal_last_gpu_time_ms; }
float moxi_metal_cpu_encode_time_ms_value(void) {
    return moxi_metal_last_cpu_encode_time_ms;
}
float moxi_metal_cpu_wait_time_ms_value(void) {
    return moxi_metal_last_cpu_wait_time_ms;
}
float moxi_metal_frame_time_ms_value(void) {
    return moxi_metal_last_frame_time_ms;
}
float moxi_metal_line_geometry_time_ms_value(void) {
    return moxi_metal_last_line_geometry_time_ms;
}
int moxi_metal_gpu_timing_available_value(void) {
    return moxi_metal_gpu_timing_available ? 1 : 0;
}
int moxi_metal_text_texture_count_value(void) { return moxi_metal_text_texture_draw_count; }
int moxi_metal_text_texture_cache_hit_count_value(void) {
    return moxi_metal_text_texture_cache_hit_count;
}
int moxi_metal_text_texture_raster_count_value(void) {
    return moxi_metal_text_texture_raster_count;
}

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

int moxi_metal_attach_canvas(float x, float y, float width, float height) {
    @autoreleasepool {
        void *parent_pointer = moxi_window_canvas_view();
        if (parent_pointer == NULL) return 0;
        NSView *parent = (__bridge NSView *)parent_pointer;
        int logical_width = width > 0.0f ? (int)width : 1;
        int logical_height = height > 0.0f ? (int)height : 1;
        if (!moxi_metal_initialized &&
            !moxi_metal_init(logical_width, logical_height)) {
            return 0;
        }
        if (moxi_metal_width != logical_width ||
            moxi_metal_height != logical_height) {
            if (!moxi_metal_resize(logical_width, logical_height)) return 0;
        }
        if (moxi_metal_canvas_view == nil ||
            [moxi_metal_canvas_view superview] != parent) {
            [moxi_metal_canvas_view removeFromSuperview];
            moxi_metal_canvas_view = [[MoxiMetalView alloc]
                initWithFrame:NSMakeRect(x, y, width, height)];
            moxi_metal_canvas_view.wantsLayer = YES;
            moxi_metal_canvas_view.autoresizingMask = NSViewNotSizable;
            [parent addSubview:moxi_metal_canvas_view];
        }
        [moxi_metal_canvas_view setFrame:NSMakeRect(x, y, width, height)];
        moxi_metal_canvas_view.hidden = NO;
        moxi_metal_layer = (CAMetalLayer *)moxi_metal_canvas_view.layer;
        if (moxi_metal_layer == nil) return 0;
        moxi_metal_layer.device = moxi_metal_device;
        moxi_metal_layer.pixelFormat = MTLPixelFormatRGBA8Unorm;
        moxi_metal_layer.framebufferOnly = NO;
        moxi_metal_layer.opaque = NO;
        [moxi_metal_canvas_view setNeedsLayout:YES];
        [moxi_metal_canvas_view layoutSubtreeIfNeeded];
        return 1;
    }
}

void moxi_metal_detach_canvas(void) {
    [moxi_metal_canvas_view removeFromSuperview];
    moxi_metal_canvas_view = nil;
    if (moxi_metal_view != nil) {
        moxi_metal_layer = (CAMetalLayer *)moxi_metal_view.layer;
    } else {
        moxi_metal_layer = nil;
    }
}

void moxi_metal_shutdown(void) {
    moxi_metal_detach_canvas();
    [moxi_metal_window close];
    moxi_metal_window = nil;
    moxi_metal_window_delegate = nil;
    moxi_metal_view = nil;
    moxi_metal_layer = nil;
    moxi_metal_window_opened = NO;
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_texture = nil;
    moxi_metal_image_buffer = nil;
    moxi_metal_image_vertices = NULL;
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_TEXTURES; index++) {
        moxi_metal_textures[index] = nil;
    }
    moxi_metal_text_texture_count = 0;
    moxi_metal_text_texture_draw_count = 0;
    for (int index = 0; index < MOXI_METAL_MAX_TEXT_CACHE; index++) {
        moxi_metal_text_cache_keys[index] = nil;
        moxi_metal_text_cache_textures[index] = nil;
        moxi_metal_text_cache_glyph_counts[index] = 0;
    }
    moxi_metal_text_cache_count = 0;
    moxi_metal_text_cache_bytes = 0;
    moxi_metal_text_texture_cache_hit_count = 0;
    moxi_metal_text_texture_raster_count = 0;
    for (int index = 0; index < MOXI_METAL_MAX_IMAGES; index++) {
        moxi_metal_images[index] = nil;
        moxi_metal_image_ids[index] = -1;
    }
    moxi_metal_vertex_buffer = nil;
    moxi_metal_image_pipeline = nil;
    moxi_metal_image_sampler = nil;
    moxi_metal_pipeline = nil;
    moxi_metal_queue = nil;
    moxi_metal_device = nil;
    moxi_metal_vertices = NULL;
    moxi_metal_submitted_vertex_count = 0;
    moxi_metal_vertex_capacity = 0;
    moxi_metal_buffer_reallocation_count = 0;
    moxi_metal_draw_submission_count = 0;
    moxi_metal_resize_count = 0;
    moxi_metal_last_gpu_time_ms = 0.0f;
    moxi_metal_last_cpu_encode_time_ms = 0.0f;
    moxi_metal_last_cpu_wait_time_ms = 0.0f;
    moxi_metal_last_frame_time_ms = 0.0f;
    moxi_metal_gpu_timing_available = NO;
    moxi_metal_line_geometry_start_time = 0.0;
    moxi_metal_last_line_geometry_time_ms = 0.0f;
    moxi_metal_frame_start_time = 0.0;
    moxi_metal_encode_start_time = 0.0;
    moxi_metal_clip_depth = 0;
    moxi_metal_target_width = 0;
    moxi_metal_target_height = 0;
    moxi_metal_scale = 1.0f;
    moxi_metal_initialized = NO;
}

@implementation MoxiMetalView
- (BOOL)isFlipped { return YES; }
- (CALayer *)makeBackingLayer { return [CAMetalLayer layer]; }
- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}
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
