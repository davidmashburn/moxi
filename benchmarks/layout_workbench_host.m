/* Test-only bitmap host: includes the production painter, not another backend. */
#import "../native/macos_window.m"
static NSBitmapImageRep *layout_benchmark_bitmap;
static NSGraphicsContext *layout_benchmark_context;

void moxi_layout_benchmark_host(int width, int height) {
    [NSApplication sharedApplication];
    moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0,0,width,height)];
    layout_benchmark_bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    layout_benchmark_context = [NSGraphicsContext graphicsContextWithBitmapImageRep:layout_benchmark_bitmap];
}
void moxi_layout_benchmark_draw(void) {
    @autoreleasepool {
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:layout_benchmark_context];
        [moxi_canvas drawRect:moxi_canvas.bounds];
        [layout_benchmark_context flushGraphics];
        [NSGraphicsContext restoreGraphicsState];
    }
}
