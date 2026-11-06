#import "../native/macos_window.m"
#include <assert.h>
static MoxiAccessibilityElement *capturedEditor;
static MoxiCanvasView *capturedCanvas;

/* Optional evidence from the real running NSWindow content view. Scripted
 * callbacks drive the test; this does not claim physical input/compositor QA. */
void moxi_lifecycle_snapshot(const char *name, int sheet) {
    const char *directory = getenv("MOXI_LIFECYCLE_CAPTURE_DIR");
    if (directory == NULL || directory[0] == '\0') return;
    NSWindow *window = moxi_window;
    if (sheet) {
        MoxiWindowState *owner = moxi_current_context();
        assert(owner->dialog != nil);
        window = owner->dialog.window;
    }
    NSView *view = window.contentView;
    assert(view != nil);
    [view layoutSubtreeIfNeeded];
    [view displayIfNeeded];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    assert(bitmap != nil);
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *path = [[NSString stringWithUTF8String:directory]
        stringByAppendingPathComponent:[NSString stringWithUTF8String:name]];
    assert([png writeToFile:path atomically:YES]);
}

void moxi_lifecycle_capture(void) {
    int index=moxi_accessibility_index_for_id(20);
    assert(index>=0);
    capturedEditor=(MoxiAccessibilityElement *)moxi_accessibility_elements[index];
    capturedCanvas=moxi_canvas;
}
void moxi_lifecycle_edit_captured(const char *text) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [capturedEditor accessibilitySetValue:[NSString stringWithUTF8String:text]
        forAttribute:NSAccessibilityValueAttribute];
#pragma clang diagnostic pop
}
void moxi_lifecycle_assert_ax(const char *value, int row, int selected) {
    int editor=moxi_accessibility_index_for_id(20);
    assert(editor>=0 && moxi_accessibility_roles[editor]==MOXI_ROLE_TEXT_INPUT);
    assert(moxi_accessibility_parent_ids[editor]==1000+row);
    assert([moxi_accessibility_values[editor] isEqual:[NSString stringWithUTF8String:value]]);
    int rowIndex=moxi_accessibility_index_for_id(1000+row);
    assert(rowIndex>=0 && moxi_accessibility_selected[rowIndex]==(selected!=0));
    assert(moxi_accessibility_parent_ids[rowIndex]==2);
    assert(moxi_canvas.accessibilityChildren.count==1);
    assert(moxi_accessibility_count<32); // bounded mounted view, not 100k AX elements
    assert(moxi_event_dropped_count==0 && moxi_command_overflow_count==0);
}
void moxi_lifecycle_press(int id) {
    int index=moxi_accessibility_index_for_id(id);
    assert(index>=0);
    assert([(MoxiAccessibilityElement *)moxi_accessibility_elements[index] accessibilityPerformPress]);
}
void moxi_lifecycle_assert_native_selection(void) {
    NSText *editor=[moxi_window fieldEditor:NO forObject:moxi_canvas.nativeTextEditor];
    assert(editor!=nil);
    assert(NSEqualRanges(editor.selectedRange,NSMakeRange(0,editor.string.length)));
}
void moxi_lifecycle_menu_choose(int result) {
    moxi_window_menu_begin();
    moxi_window_menu_add("Start",0);
    moxi_window_menu_add("Deep",1);
    MoxiWindowState *owner=moxi_current_context();
    NSMenuItem *item=[owner->menu itemAtIndex:result];
    assert(item.target==moxi_delegate);
    [moxi_delegate moxiMenuSelected:item];
    assert(owner->menuResult==result);
    owner->menu=nil;
}
void moxi_lifecycle_resolve_dialog(int apply) {
    MoxiWindowState *owner=moxi_current_context();
    assert(owner->dialog!=nil && owner->dialog.window.sheetParent==moxi_window);
    [moxi_window endSheet:owner->dialog.window returnCode:apply ? NSAlertFirstButtonReturn : NSAlertSecondButtonReturn];
    [owner->dialog.window orderOut:nil];
    // AppKit dispatches sheet completion on the main run loop.
    NSDate *until=[NSDate dateWithTimeIntervalSinceNow:2];
    while(owner->dialog!=nil && until.timeIntervalSinceNow>0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    assert(owner->dialog==nil);
}
void moxi_lifecycle_drag(void) {
    // Deliver the real canvas mouse callbacks in another selected context.
    // Source row 50001 at y=178; drop row 50003 at y=262.
    const NSEventType types[]={NSEventTypeLeftMouseDown,NSEventTypeLeftMouseDragged,NSEventTypeLeftMouseUp};
    for(int i=0;i<3;i++) {
        NSPoint point=[capturedCanvas convertPoint:NSMakePoint(80,i==0?178:262) toView:nil];
        NSEvent *event=[NSEvent mouseEventWithType:types[i] location:point modifierFlags:0
            timestamp:0 windowNumber:capturedCanvas.window.windowNumber context:nil eventNumber:i clickCount:1 pressure:1];
        if(i==0) [capturedCanvas mouseDown:event];
        if(i==1) [capturedCanvas mouseDragged:event];
        if(i==2) [capturedCanvas mouseUp:event];
    }
}
