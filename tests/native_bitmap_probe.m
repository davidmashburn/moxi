#include "../native/macos_window.m"
#include <unistd.h>

#define BITMAP_CHECK(condition) do { \
    if (!(condition)) { \
        fprintf(stderr, "Bitmap probe failed at line %d: %s\n", __LINE__, #condition); \
        abort(); \
    } \
} while (0)

static NSBitmapImageRep *bitmap_probe_capture;
static uint8_t bitmap_probe_metal_rgb[16 * 16 * 3];

void moxi_bitmap_probe_capture_native(void) {
    bitmap_probe_capture = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:64 bitsPerPixel:32];
    memset(bitmap_probe_capture.bitmapData, 0, 16 * 16 * 4);
    NSGraphicsContext *bitmapContext = [NSGraphicsContext
        graphicsContextWithBitmapImageRep:bitmap_probe_capture];
    [NSGraphicsContext saveGraphicsState];
    CGContextRef cg = bitmapContext.CGContext;
    CGContextTranslateCTM(cg, 0, 16);
    CGContextScaleCTM(cg, 1, -1);
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES]];
    moxi_draw_custom_commands_uncached();
    [NSGraphicsContext restoreGraphicsState];
}

int moxi_bitmap_probe_native_channel(int x, int y, int channel) {
    NSColor *color = [[bitmap_probe_capture colorAtX:x y:y]
        colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    CGFloat channels[4] = {color.redComponent, color.greenComponent,
        color.blueComponent, color.alphaComponent};
    return (int)lround(channels[channel] * 255.0);
}

static void bitmap_probe_expect_native(int x, int y, int red, int green, int blue) {
    /* AppKit shape colors are converted from sRGB to the device RGB target. */
    const int tolerance = 8;
    if (abs(moxi_bitmap_probe_native_channel(x, y, 0) - red) > tolerance ||
        abs(moxi_bitmap_probe_native_channel(x, y, 1) - green) > tolerance ||
        abs(moxi_bitmap_probe_native_channel(x, y, 2) - blue) > tolerance) {
        fprintf(stderr, "Native bitmap pixel (%d, %d): %d %d %d; expected %d %d %d\n",
            x, y, moxi_bitmap_probe_native_channel(x, y, 0),
            moxi_bitmap_probe_native_channel(x, y, 1),
            moxi_bitmap_probe_native_channel(x, y, 2), red, green, blue);
    }
    BITMAP_CHECK(abs(moxi_bitmap_probe_native_channel(x, y, 0) - red) <= tolerance);
    BITMAP_CHECK(abs(moxi_bitmap_probe_native_channel(x, y, 1) - green) <= tolerance);
    BITMAP_CHECK(abs(moxi_bitmap_probe_native_channel(x, y, 2) - blue) <= tolerance);
}

void moxi_bitmap_probe_native_contract(void) {
    uint64_t first = moxi_window_create_instance();
    uint64_t second = moxi_window_create_instance();
    BITMAP_CHECK(first != 0 && second != 0);
    BITMAP_CHECK(moxi_window_select_instance(first));
    moxi_window_begin_custom_paint();
    moxi_window_add_custom_rect(0, 0, 16, 16, 1, 1, 1, 1, 0, 0, 0, 0, 0);
    moxi_window_set_custom_clip(4, 0, 8, 16);
    uint8_t rgba[16] = {255, 0, 0, 128, 255, 0, 0, 128,
        0, 0, 255, 255, 0, 0, 255, 255};
    BITMAP_CHECK(moxi_window_add_custom_bitmap(rgba, sizeof(rgba), 2, 2,
        0, 0, 16, 16, 1));
    memset(rgba, 0, sizeof(rgba)); /* Deferred paint must own a snapshot. */
    moxi_window_set_custom_clip(0, 0, 16, 16);
    uint8_t magenta[] = {255, 0, 255, 255};
    BITMAP_CHECK(moxi_window_add_custom_bitmap(magenta, sizeof(magenta), 1, 1,
        12, 12, 2, 2, 0.5f));
    moxi_window_add_custom_line(0, 8, 16, 8, 0, 1, 0, 1, 2);
    moxi_bitmap_probe_capture_native();
    bitmap_probe_expect_native(1, 2, 255, 255, 255);
    bitmap_probe_expect_native(6, 2, 255, 127, 127);
    bitmap_probe_expect_native(6, 13, 0, 0, 255);
    bitmap_probe_expect_native(6, 8, 0, 255, 0);
    bitmap_probe_expect_native(13, 13, 255, 127, 255);

    BITMAP_CHECK(moxi_window_select_instance(second));
    moxi_window_begin_custom_paint();
    uint8_t cyan[] = {0, 255, 255, 255};
    BITMAP_CHECK(moxi_window_add_custom_bitmap(cyan, sizeof(cyan), 1, 1,
        0, 0, 16, 16, 1));
    moxi_bitmap_probe_capture_native();
    bitmap_probe_expect_native(6, 2, 0, 255, 255);
    BITMAP_CHECK(moxi_window_select_instance(first));
    moxi_bitmap_probe_capture_native();
    bitmap_probe_expect_native(6, 2, 255, 127, 127);
    bitmap_probe_expect_native(13, 13, 255, 127, 255);

    moxi_window_begin_custom_paint();
    moxi_window_ordered_paint_begin();
    BITMAP_CHECK(moxi_window_add_custom_bitmap(cyan, sizeof(cyan), 1, 1,
        0, 0, 16, 16, 1));
    BITMAP_CHECK(moxi_window_ordered_custom_slice());
    BITMAP_CHECK(moxi_window_add_custom_bitmap(magenta, sizeof(magenta), 1, 1,
        0, 0, 16, 16, 1));
    BITMAP_CHECK(moxi_window_ordered_custom_slice());
    BITMAP_CHECK(moxi_current_context()->customSlices[0].bitmapStart == 0);
    BITMAP_CHECK(moxi_current_context()->customSlices[0].bitmapEnd == 1);
    BITMAP_CHECK(moxi_current_context()->customSlices[1].bitmapStart == 1);
    BITMAP_CHECK(moxi_current_context()->customSlices[1].bitmapEnd == 2);
    BITMAP_CHECK(!moxi_window_add_custom_bitmap(cyan, 3, 1, 1, 0, 0, 1, 1, 1));
    BITMAP_CHECK(!moxi_window_add_custom_bitmap(cyan, sizeof(cyan), 4097, 1, 0, 0, 1, 1, 1));
    moxi_window_begin_custom_paint();
    for (int i = 0; i < MOXI_MAX_CUSTOM_BITMAPS; i++) {
        BITMAP_CHECK(moxi_window_add_custom_bitmap(cyan, sizeof(cyan), 1, 1,
            0, 0, 1, 1, 1));
    }
    BITMAP_CHECK(!moxi_window_add_custom_bitmap(cyan, sizeof(cyan), 1, 1, 0, 0, 1, 1, 1));
    moxi_window_begin_custom_paint();
    BITMAP_CHECK(moxi_custom_bitmap_count == 0);
    BITMAP_CHECK(moxi_custom_bitmaps[0] == nil);
    BITMAP_CHECK(moxi_window_destroy_instance(first));
    BITMAP_CHECK(moxi_window_destroy_instance(second));
}

extern int moxi_metal_write_ppm(const char *path);

void moxi_bitmap_probe_capture_metal(void) {
    char path[] = "/tmp/moxi-bitmap-probe-XXXXXX";
    int descriptor = mkstemp(path);
    BITMAP_CHECK(descriptor >= 0);
    close(descriptor);
    BITMAP_CHECK(moxi_metal_write_ppm(path));
    FILE *image = fopen(path, "rb");
    BITMAP_CHECK(image != NULL);
    int width, height, maximum;
    BITMAP_CHECK(fscanf(image, "P6 %d %d %d", &width, &height, &maximum) == 3);
    BITMAP_CHECK(width == 16 && height == 16 && maximum == 255);
    BITMAP_CHECK(fgetc(image) == '\n');
    BITMAP_CHECK(fread(bitmap_probe_metal_rgb, 1, sizeof(bitmap_probe_metal_rgb), image)
        == sizeof(bitmap_probe_metal_rgb));
    fclose(image);
    unlink(path);
}

int moxi_bitmap_probe_metal_channel(int x, int y, int channel) {
    BITMAP_CHECK(x >= 0 && x < 16 && y >= 0 && y < 16 && channel >= 0 && channel < 3);
    return bitmap_probe_metal_rgb[(y * 16 + x) * 3 + channel];
}
