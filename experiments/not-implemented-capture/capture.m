// Private probe adapter: render the actual AppKit draw path into a bitmap.
#include "../../native/macos_window.m"

void n01_capture_init(int width, int height) {
    [NSApplication sharedApplication];
    moxi_canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0,0,width,height)];
}
int n01_capture_save(const char *path, int width, int height) {
    [moxi_canvas setFrame:NSMakeRect(0,0,width,height)];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context.CGContext flipped:YES]];
    CGContextTranslateCTM(context.CGContext,0,height);
    CGContextScaleCTM(context.CGContext,1,-1);
    [moxi_canvas drawRect:NSMakeRect(0,0,width,height)];
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
