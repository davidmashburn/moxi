#import <Cocoa/Cocoa.h>
int moxi_canvas_capture(const char *path) {
    @autoreleasepool {
        NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
        if (!window) window = NSApp.windows.firstObject;
        if (!window || !window.contentView) { fprintf(stderr, "No native view (%lu windows)\n", (unsigned long)NSApp.windows.count); return 0; }
        NSView *view = window.contentView;
        [view layoutSubtreeIfNeeded];
        [view displayIfNeeded];
        NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
        if (!bitmap) return 0;
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES] ? 1 : 0;
    }
}

static NSTextField *canvas_editor(NSView *view) {
    if ([view isKindOfClass:NSTextField.class] && !view.hidden) return (NSTextField *)view;
    for (NSView *child in view.subviews) { NSTextField *found = canvas_editor(child); if (found) return found; }
    return nil;
}
uint64_t moxi_canvas_editor_identity(void) {
    NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow ?: NSApp.windows.firstObject;
    return (uint64_t)(__bridge void *)canvas_editor(window.contentView);
}

int moxi_canvas_editor_geometry(float x, float y, float w, float h,
                               float cx, float cy, float cw, float ch, float font) {
    NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow ?: NSApp.windows.firstObject;
    NSView *root = window.contentView;
    NSTextField *editor = canvas_editor(root);
    if (!editor) return 0;
    NSRect actual = [editor convertRect:editor.bounds toView:root];
    NSRect clip = [editor.superview convertRect:editor.superview.bounds toView:root];
    BOOL same = fabs(actual.origin.x-x)<0.5 && fabs(actual.origin.y-y)<0.5 &&
        fabs(actual.size.width-w)<0.5 && fabs(actual.size.height-h)<0.5 &&
        fabs(clip.origin.x-cx)<0.5 && fabs(clip.origin.y-cy)<0.5 &&
        fabs(clip.size.width-cw)<0.5 && fabs(clip.size.height-ch)<0.5 &&
        fabs(editor.font.pointSize-font)<0.1;
    if (!same) fprintf(stderr, "Native geometry actual=%s expected=%s clip=%s expectedClip=%s font=%.2f expectedFont=%.2f\n",
        NSStringFromRect(actual).UTF8String, NSStringFromRect(NSMakeRect(x,y,w,h)).UTF8String,
        NSStringFromRect(clip).UTF8String, NSStringFromRect(NSMakeRect(cx,cy,cw,ch)).UTF8String, editor.font.pointSize, font);
    return same ? 1 : 0;
}
