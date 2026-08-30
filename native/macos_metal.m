#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <simd/simd.h>
#include <ctype.h>
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
#define MOXI_METAL_MAX_IMAGES 64

@interface MoxiMetalView : NSView
@end

@interface MoxiMetalWindowDelegate : NSObject <NSWindowDelegate>
@end

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
static MTLScissorRect moxi_metal_clip_stack[MOXI_METAL_MAX_CLIP_DEPTH];
static NSUInteger moxi_metal_clip_depth;
static BOOL moxi_metal_initialized;
static NSWindow *moxi_metal_window;
static MoxiMetalWindowDelegate *moxi_metal_window_delegate;
static MoxiMetalView *moxi_metal_view;
static CAMetalLayer *moxi_metal_layer;
static BOOL moxi_metal_window_opened;
static id<MTLTexture> moxi_metal_images[MOXI_METAL_MAX_IMAGES];
static int moxi_metal_image_ids[MOXI_METAL_MAX_IMAGES];

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
    for (const unsigned char *cursor = (const unsigned char *)text; *cursor != 0; cursor++) {
        if (*cursor >= 128 || (*cursor != '\n' && *cursor != '\r' && *cursor != '\t' &&
            !moxi_ascii_supported(*cursor))) return -1;
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

static int moxi_parse_polygon_path(const char *data, vector_float2 *points, int limit, BOOL *closed) {
    if (data == NULL || points == NULL || limit < 3) return -1;
    const char *cursor = data;
    char command = 0;
    int count = 0;
    vector_float2 current = {0.0f, 0.0f};
    *closed = NO;
    while (1) {
        moxi_skip_path_separators(&cursor);
        if (*cursor == 0) break;
        if (isalpha((unsigned char)*cursor)) {
            command = *cursor++;
            if (command == 'Z' || command == 'z') {
                if (count < 3) return -1;
                *closed = YES;
                command = 0;
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
                if (count != 0) return -1;
            }
            if (count >= limit) return -1;
            points[count++] = next;
            current = next;
            if (normalized == 'M') command = relative ? 'l' : 'L';
        } else if (normalized == 'H') {
            if (!moxi_read_path_number(&cursor, &first)) return -1;
            vector_float2 next = {relative ? current.x + first : first, current.y};
            if (count >= limit) return -1;
            points[count++] = next;
            current = next;
        } else if (normalized == 'V') {
            if (!moxi_read_path_number(&cursor, &first)) return -1;
            vector_float2 next = {current.x, relative ? current.y + first : first};
            if (count >= limit) return -1;
            points[count++] = next;
            current = next;
        } else {
            return -1;
        }
    }
    return count >= 3 ? count : -1;
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
    vector_float2 points[4096];
    BOOL closed = NO;
    int count = moxi_parse_polygon_path(path_data, points, 4096, &closed);
    if (count < 0) return -1;
    float fill[4] = {fill_red, fill_green, fill_blue, fill_alpha};
    if (fill_alpha > 0.0f) {
        if (!moxi_metal_reserve_vertices((count - 2) * 3)) return -1;
        MoxiMetalVertex first = moxi_transformed_vertex(
            points[0].x, points[0].y, fill, m11, m12, m21, m22, tx, ty);
        for (int index = 1; index < count - 1; index++) {
            MoxiMetalVertex second = moxi_transformed_vertex(
                points[index].x, points[index].y, fill, m11, m12, m21, m22, tx, ty);
            MoxiMetalVertex third = moxi_transformed_vertex(
                points[index + 1].x, points[index + 1].y, fill, m11, m12, m21, m22, tx, ty);
            moxi_metal_vertices[moxi_metal_vertex_count++] = first;
            moxi_metal_vertices[moxi_metal_vertex_count++] = second;
            moxi_metal_vertices[moxi_metal_vertex_count++] = third;
        }
    }
    if (stroke_alpha > 0.0f && stroke_width > 0.0f) {
        float stroke[4] = {stroke_red, stroke_green, stroke_blue, stroke_alpha};
        int segment_count = closed ? count : count - 1;
        for (int index = 0; index < segment_count; index++) {
            int next = (index + 1) % count;
            vector_float2 start = moxi_transform_point(
                points[index].x, points[index].y, m11, m12, m21, m22, tx, ty);
            vector_float2 end = moxi_transform_point(
                points[next].x, points[next].y, m11, m12, m21, m22, tx, ty);
            moxi_append_line(start.x, start.y, end.x, end.y, stroke_width, stroke);
        }
    }
    return count;
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
    moxi_metal_clip_depth = 0;
    for (int index = 0; index < MOXI_METAL_MAX_IMAGES; index++) {
        moxi_metal_image_ids[index] = -1;
        moxi_metal_images[index] = nil;
    }
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
    vector_float2 topLeft = moxi_transform_point(x, y, m11, m12, m21, m22, tx, ty);
    vector_float2 topRight = moxi_transform_point(x + width, y, m11, m12, m21, m22, tx, ty);
    vector_float2 bottomLeft = moxi_transform_point(x, y + height, m11, m12, m21, m22, tx, ty);
    vector_float2 bottomRight = moxi_transform_point(x + width, y + height, m11, m12, m21, m22, tx, ty);
    float clampedAlpha = moxi_clamp(alpha);
    vector_float4 color = (vector_float4){1.0f, 1.0f, 1.0f, clampedAlpha};
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
    [moxi_metal_encoder setFragmentTexture:moxi_metal_images[slot] atIndex:0];
    [moxi_metal_encoder setFragmentSamplerState:moxi_metal_image_sampler atIndex:0];
    [moxi_metal_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    moxi_metal_draw_submission_count += 1;
    [moxi_metal_encoder setRenderPipelineState:moxi_metal_pipeline];
    return 1;
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
    [moxi_metal_command_buffer commit];
    [moxi_metal_command_buffer waitUntilCompleted];
    moxi_metal_encoder = nil;
    moxi_metal_command_buffer = nil;
    moxi_metal_drawable = nil;
    moxi_metal_render_texture = nil;
    moxi_metal_frame_count += 1;
}

int moxi_metal_frame_count_value(void) { return moxi_metal_frame_count; }
int moxi_metal_vertex_count_value(void) { return moxi_metal_submitted_vertex_count; }
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
    moxi_metal_image_buffer = nil;
    moxi_metal_image_vertices = NULL;
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
