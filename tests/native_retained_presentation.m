#import "../native/macos_window.m"
#include <assert.h>

static NSBitmapImageRep *render(MoxiCanvasView *canvas) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:80 pixelsHigh:80
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    [canvas drawRect:canvas.bounds];
    [NSGraphicsContext restoreGraphicsState];
    return bitmap;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        MoxiCanvasView *canvas = [[MoxiCanvasView alloc] initWithFrame:NSMakeRect(0,0,80,80)];
        moxi_reset_commands();
        moxi_button_count = 2;
        for (int i=0; i<2; i++) {
            moxi_button_frames[i] = NSMakeRect(0,0,80,80);
            moxi_button_texts[i] = @"";
            moxi_button_font_sizes[i] = 14;
            moxi_button_enabled[i] = YES;
            moxi_copy_color(moxi_button_fill_colors[i], i==0, 0, i==1, 1);
        }
        moxi_window_ordered_paint_begin();
        moxi_window_ordered_paint(2,1);
        moxi_window_ordered_paint(2,0);
        NSColor *red = [[render(canvas) colorAtX:40 y:40] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        assert(red.redComponent>0.9 && red.blueComponent<0.1);
        moxi_window_add_custom_rect(0,0,80,80,0,1,0,1,0,0,0,0,0);
        moxi_window_ordered_paint_begin();
        moxi_window_ordered_paint(2,0);
        moxi_window_ordered_paint(100,0);
        moxi_window_ordered_paint(2,1);
        NSColor *blue = [[render(canvas) colorAtX:40 y:40] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        assert(blue.blueComponent>0.9 && blue.greenComponent<0.3);
        // Clip movement preserves the editor object and its full logical size.
        moxi_text_input_count = 1;
        moxi_text_input_frames[0] = NSMakeRect(10,10,60,40);
        moxi_text_input_clip_enabled[0] = YES;
        moxi_text_input_clip_frames[0] = NSMakeRect(10,30,60,20);
        moxi_text_input_font_sizes[0] = 14;
        moxi_text_input_texts[0] = @"日本語";
        [canvas showNativeTextEditorForIndex:0];
        NSTextField *editor = canvas.nativeTextEditor;
        assert(NSEqualRects(canvas.nativeTextEditorClip.frame, NSMakeRect(10,30,60,20)));
        assert(NSEqualRects(editor.frame, NSMakeRect(0,-20,60,40)));
        moxi_text_input_clip_frames[0] = NSMakeRect(10,60,60,10);
        [canvas showNativeTextEditorForIndex:0];
        assert(canvas.nativeTextEditor==editor);
        assert(NSIsEmptyRect(canvas.nativeTextEditorClip.frame));
        assert(!editor.hidden);
        // Per-frame opt-in does not change the legacy host's draw ordering.
        moxi_window_begin_frame();
        assert(!moxi_ordered_paint_enabled && moxi_ordered_paint_count==0);
        puts("Retained native paint order, custom layering and editor clipping passed");
    }
    return 0;
}
