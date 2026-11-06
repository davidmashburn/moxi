/* Exercise the actual instance-owned AppKit ordered renderer. */
#import "../../native/macos_window.m"
#include <assert.h>

static NSBitmapImageRep *draw(MoxiCanvasView *view) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:300 pixelsHigh:300
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    [view drawRect:view.bounds];
    [NSGraphicsContext restoreGraphicsState];
    return bitmap;
}
static NSColor *pixel(NSBitmapImageRep *image, int x) {
    return [[image colorAtX:x y:150] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
}
int main(void) {
    @autoreleasepool {
        uint64_t a = moxi_window_create_instance();
        assert(moxi_window_select_instance(a));
        moxi_window_open("D03 paint layers A",300,300,0,0,0,0,1,0);
        MoxiCanvasView *av = moxi_canvas;
        moxi_window_begin_frame();
        moxi_window_set_surface(0,0,0,1);
        moxi_window_ordered_paint_begin();
        moxi_window_begin_custom_paint();
        moxi_window_set_custom_clip(50,0,200,300);
        moxi_window_add_custom_line(0,150,300,150,1,0,0,1,8);
        assert(moxi_window_ordered_custom_slice());
        moxi_window_set_panel_at(0,100,0,100,300,0,0,1,1,0,0,0,0,0,0);
        moxi_window_ordered_paint(3,0);
        moxi_window_set_custom_clip(145,0,10,300);
        moxi_window_add_custom_rect(0,0,300,300,0,1,0,1,0,0,0,0,0);
        assert(moxi_window_ordered_custom_slice());

        uint64_t b = moxi_window_create_instance();
        assert(moxi_window_select_instance(b));
        moxi_window_open("D03 paint layers B",300,300,0,0,0,0,1,0);
        MoxiCanvasView *bv = moxi_canvas;
        moxi_window_begin_frame();
        moxi_window_set_surface(0,0,0,1);
        moxi_window_ordered_paint_begin();
        moxi_window_begin_custom_paint();
        moxi_window_add_custom_rect(0,0,300,300,1,1,0,1,0,0,0,0,0);
        assert(moxi_window_ordered_custom_slice());
        NSBitmapImageRep *image = draw(av); // callback switches to A, restores B
        assert(moxi_canvas == bv);
        assert(pixel(image,70).redComponent > .9);
        assert(pixel(image,120).blueComponent > .9 && pixel(image,120).redComponent < .1);
        assert(pixel(image,150).greenComponent > .9 && pixel(image,150).blueComponent < .1);
        assert(pixel(image,30).redComponent < .1); // first slice's own clip
        assert(pixel(image,170).blueComponent > .9); // later slice cannot escape its clip
        assert(pixel(draw(bv),120).redComponent > .9 && pixel(draw(bv),120).greenComponent > .9);
        for (int i = 1; i < MoxiCustomSliceCapacity; i++) assert(moxi_window_ordered_custom_slice());
        assert(!moxi_window_ordered_custom_slice());
        assert(moxi_command_overflow_count == 1);
        moxi_window_begin_frame();
        assert(moxi_current_context()->customSliceCount == 0);
        moxi_window_destroy_instance(a);
        moxi_window_destroy_instance(b);
        puts("D03 native layer pixels, per-slice clipping, window isolation and capacity: PASS");
    }
}
