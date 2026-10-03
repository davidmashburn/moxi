#import <Cocoa/Cocoa.h>
static NSMutableArray *focusNotifications;
static void recordAccessibilityNotification(id element, NSAccessibilityNotificationName notification) {
    if ([notification isEqualToString:NSAccessibilityFocusedUIElementChangedNotification])
        [focusNotifications addObject:element];
}
#define NSAccessibilityPostNotification recordAccessibilityNotification
#import "../native/macos_window.m"
#undef NSAccessibilityPostNotification
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
        focusNotifications = [[NSMutableArray alloc] init];
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
        // Retained AX identity follows keys, not frame order; retired keys leave the cache.
        moxi_canvas = canvas;
        moxi_window_begin_accessibility();
        moxi_accessibility_count = 2;
        moxi_accessibility_ids[0] = 1;
        moxi_accessibility_roles[0] = MOXI_ROLE_CONTAINER;
        moxi_accessibility_ids[1] = 2;
        moxi_accessibility_parent_ids[1] = 1;
        moxi_accessibility_roles[1] = MOXI_ROLE_LABEL;
        moxi_accessibility_labels[1] = @"Dataset";
        moxi_accessibility_frames[1] = NSMakeRect(10,10,20,20);
        moxi_window_end_accessibility();
        NSAccessibilityElement *retainedRoot = moxi_accessibility_elements[0];
        NSAccessibilityElement *retainedLabel = moxi_accessibility_elements[1];
        for (int frame=0; frame<100; frame++) {
            moxi_window_begin_accessibility();
            moxi_accessibility_count = 2;
            moxi_accessibility_ids[0] = 1;
            moxi_accessibility_roles[0] = MOXI_ROLE_CONTAINER;
            moxi_accessibility_ids[1] = 2;
            moxi_accessibility_parent_ids[1] = 1;
            moxi_accessibility_roles[1] = MOXI_ROLE_LABEL;
            moxi_accessibility_labels[1] = @"Dataset";
            moxi_accessibility_frames[1] = NSMakeRect(10+frame,10,20,20);
            moxi_window_end_accessibility();
            assert(moxi_accessibility_elements[0]==retainedRoot);
            assert(moxi_accessibility_elements[1]==retainedLabel);
            assert(((MoxiAccessibilityElement *)retainedRoot).moxiChildren.count==1);
            assert(moxi_retained_accessibility_elements.count==2);
        }
        moxi_window_begin_accessibility();
        moxi_accessibility_count = 1;
        moxi_accessibility_ids[0] = 1;
        moxi_accessibility_roles[0] = MOXI_ROLE_CONTAINER;
        moxi_window_end_accessibility();
        assert(moxi_accessibility_elements[0]==retainedRoot);
        assert(moxi_retained_accessibility_elements.count==1);
        assert(((MoxiAccessibilityElement *)retainedRoot).moxiChildren.count==0);
        // A scoped modal publishes only its dialog and descendants, and announces
        // a newly mounted focused control even though it had no previous AX entry.
        for (int frame=0; frame<2; frame++) {
            moxi_window_begin_accessibility();
            moxi_accessibility_count = 2;
            moxi_accessibility_ids[0] = 90;
            moxi_accessibility_roles[0] = MOXI_ROLE_DIALOG;
            moxi_accessibility_labels[0] = @"Layout dialog";
            moxi_accessibility_expanded[0] = YES;
            moxi_accessibility_ids[1] = 92;
            moxi_accessibility_parent_ids[1] = 90;
            moxi_accessibility_roles[1] = MOXI_ROLE_BUTTON;
            moxi_accessibility_focused[1] = YES;
            moxi_window_end_accessibility();
            NSArray *roots = [canvas accessibilityChildrenInNavigationOrder];
            assert(roots.count==1 && roots[0]==moxi_accessibility_elements[0]);
            NSArray *children = [roots[0] accessibilityChildrenInNavigationOrder];
            assert(children.count==1 && children[0]==moxi_accessibility_elements[1]);
            assert([canvas accessibilityFocusedUIElement]==children[0]);
            assert(focusNotifications.count==1 && focusNotifications[0]==children[0]);
        }
        moxi_window_begin_accessibility();
        moxi_accessibility_count = 1;
        moxi_accessibility_ids[0] = 1;
        moxi_accessibility_roles[0] = MOXI_ROLE_CONTAINER;
        moxi_accessibility_focused[0] = YES;
        moxi_window_end_accessibility();
        assert([canvas accessibilityChildrenInNavigationOrder].count==1);
        assert([canvas accessibilityFocusedUIElement]==moxi_accessibility_elements[0]);
        assert(focusNotifications.count==2 && focusNotifications[1]==moxi_accessibility_elements[0]);
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
        // Exercise the real AppKit field editor's marked range across clip movement.
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,80,80)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.contentView = canvas;
        moxi_window_text_editor_key(13);
        moxi_text_input_clip_frames[0] = NSMakeRect(10,10,60,40);
        [canvas showNativeTextEditorForIndex:0];
        NSTextView *fieldEditor = (NSTextView *)[window fieldEditor:YES forObject:editor];
        assert([window makeFirstResponder:editor]);
        [fieldEditor setMarkedText:@"かな" selectedRange:NSMakeRange(1,0)
            replacementRange:NSMakeRange(NSNotFound,0)];
        assert(fieldEditor.hasMarkedText);
        NSRange marked = fieldEditor.markedRange;
        // Normal native edit notifications submit the live value back to the model.
        moxi_text_input_texts[0] = editor.stringValue;
        canvas.nativeTextEditorValue = editor.stringValue;
        moxi_text_input_clip_frames[0] = NSMakeRect(10,60,60,10);
        moxi_window_text_editor_key(13);
        [canvas showNativeTextEditorForIndex:0];
        assert(canvas.nativeTextEditor==editor && fieldEditor.hasMarkedText);
        assert(NSEqualRanges(fieldEditor.markedRange,marked));
        moxi_window_text_editor_key(14);
        assert(!fieldEditor.hasMarkedText);
        // Per-frame opt-in does not change the legacy host's draw ordering.
        moxi_window_begin_frame();
        assert(!moxi_ordered_paint_enabled && moxi_ordered_paint_count==0);
        moxi_window_begin_accessibility();
        assert(moxi_retained_accessibility_elements==nil);
        puts("Retained native paint, AX identity and field-editor marked-range retention passed");
    }
    return 0;
}
