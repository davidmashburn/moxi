// App shell + native evidence only. No camera/ray math or image-table injection.
#import "../../native/macos_window.m"
#include <assert.h>
#import "../../native/spatial/api.h"

// Inclusive edges keep zero-width insertion rectangles valid.
static BOOL wp_range_is_visible(NSRect rect, NSRect visible) {
  return NSWidth(rect) >= 0 && NSHeight(rect) > 0 &&
      NSMinX(rect) >= NSMinX(visible) && NSMaxX(rect) <= NSMaxX(visible) &&
      NSMinY(rect) >= NSMinY(visible) && NSMaxY(rect) <= NSMaxY(visible);
}

// Install only on the destination canvas. AppKit supplies UTF-16 range
// geometry (including horizontal scrolling) from the source field editor.
void wp_bind_geometry(uint64_t view, uint64_t source, int focused) {
  __weak MoxiCanvasView *destination = moxi_canvas;
  if (!view) {
    moxi_canvas.composedCharacterRect = nil;
  } else {
    moxi_canvas.composedCharacterRect = ^NSRect(NSRange range, NSRangePointer actual) {
      if (actual) *actual = NSMakeRange(NSNotFound,0);
      __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous = moxi_active_context;
      if (!focused || !moxi_window_select_instance(source) || !moxi_window_opened) return NSZeroRect;
      NSTextField *field = moxi_canvas.nativeTextEditor;
      NSTextView *editor = (NSTextView *)field.currentEditor;
      if (!editor || editor != moxi_window.firstResponder) return NSZeroRect;
      if (range.location > editor.string.length ||
          range.length > editor.string.length - range.location) return NSZeroRect;
      NSRange resolved;
      NSRect screen = [editor firstRectForCharacterRange:range actualRange:&resolved];
      NSRect local = [moxi_canvas convertRect:[moxi_window convertRectFromScreen:screen] fromView:nil];
      NSRect visible = NSIntersectionRect(
          [field convertRect:field.visibleRect toView:moxi_canvas],
          [editor convertRect:editor.visibleRect toView:moxi_canvas]);
      if (!wp_range_is_visible(local,visible) || resolved.location > editor.string.length ||
          resolved.length > editor.string.length - resolved.location) return NSZeroRect;
      // firstRect may already be clipped while actualRange still names the
      // entire substring. Check the unclipped layout before projecting it.
      NSLayoutManager *layout = editor.layoutManager;
      NSTextContainer *container = editor.textContainer;
      if (!layout || !container) return NSZeroRect;
      NSRange glyphs = [layout glyphRangeForCharacterRange:resolved actualCharacterRange:NULL];
      NSPoint origin = editor.textContainerOrigin;
      __block BOOL measured = NO, contained = YES;
      [layout enumerateEnclosingRectsForGlyphRange:glyphs
          withinSelectedGlyphRange:NSMakeRange(NSNotFound,0) inTextContainer:container
          usingBlock:^(NSRect rect, BOOL *stop) {
            // View conversion includes the field editor's scroll offset.
            NSRect bounds = [moxi_canvas convertRect:NSOffsetRect(rect,origin.x,origin.y) fromView:editor];
            measured = YES;
            if (!wp_range_is_visible(bounds,visible)) { contained = NO; *stop = YES; }
          }];
      if (!measured || !contained) return NSZeroRect;
      double projected[4];
      if (!ms_panel_caret_bounds(view,local.origin.x,local.origin.y,
                                 local.size.width,local.size.height,projected)) return NSZeroRect;
      MoxiCanvasView *canvas = destination;
      if (!canvas.window) return NSZeroRect;
      NSRect rect = NSMakeRect(projected[0],projected[1],projected[2],projected[3]);
      if (actual) *actual = resolved;
      return [canvas.window convertRectToScreen:[canvas convertRect:rect toView:nil]];
    };
  }
  [moxi_canvas.inputContext invalidateCharacterCoordinates];
}
void wp_hide(void) { [moxi_window orderOut:nil]; }
void wp_chrome(const char *mode,const char *message) {
  moxi_window_set_clip(0,0,0,0,0);
  moxi_window_set_label_at(40,"S4 / WORLD PANEL FEASIBILITY",24,18,950,40,.93,.96,1,1,27,1);
  moxi_window_set_label_at(41,mode,26,65,940,30,.40,.76,1,1,16,1);
  moxi_window_set_label_at(42,message,26,560,940,54,.92,.76,.40,1,15,1);
  moxi_window_set_label_at(43,"F6 / click mode title: switch  •  Tab: controls  •  Escape: cancel / leave controls",26,632,940,26,.75,.82,.9,1,14,1);
  moxi_window_set_label_at(44,"Experimental copied-image Metal. Experimental range geometry; use screen mode for editing. VoiceOver paused.",26,665,950,25,.64,.72,.82,1,13,1);
  moxi_window_end_frame();
}
void wp_begin(void) { moxi_window_begin_frame(); moxi_window_set_surface(.025,.04,.065,1); }
void wp_hide_semantics(void) {
  moxi_window_begin_accessibility(); moxi_window_end_accessibility();
  assert(moxi_canvas.accessibilityChildren.count==0);
  assert(moxi_canvas.accessibilityFocusedUIElement==nil);
}
void wp_capture(const char *path) {
  [moxi_canvas layoutSubtreeIfNeeded];
  NSBitmapImageRep *b=[moxi_canvas bitmapImageRepForCachingDisplayInRect:moxi_canvas.bounds];
  [moxi_canvas cacheDisplayInRect:moxi_canvas.bounds toBitmapImageRep:b];
  assert([[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:path] atomically:YES]);
}
// Replay annotation outlines the queried substring, never an IME candidate UI.
void wp_capture_range(const char *path) {
  id<NSTextInputClient> client = moxi_canvas;
  if (!moxi_canvas.composedCharacterRect)
    client = (NSTextView *)moxi_canvas.nativeTextEditor.currentEditor;
  assert(client);
  NSRect screen = [client firstRectForCharacterRange:NSMakeRange(3,2) actualRange:NULL];
  NSRect rect = [moxi_canvas convertRect:[moxi_window convertRectFromScreen:screen] fromView:nil];
  assert(!NSIsEmptyRect(rect));
  NSBox *outline = [[NSBox alloc] initWithFrame:NSInsetRect(rect,-1,-1)];
  outline.boxType = NSBoxCustom;
  outline.borderColor = NSColor.systemYellowColor;
  outline.borderWidth = 1;
  outline.fillColor = NSColor.clearColor;
  [moxi_canvas addSubview:outline];
  wp_capture(path);
  [outline removeFromSuperview];
}
void wp_pointer(int phase,double x,double y) {
  NSPoint p=[moxi_canvas convertPoint:NSMakePoint(x,y) toView:nil];
  NSEventType type=phase==0?NSEventTypeLeftMouseDown:phase==1?NSEventTypeLeftMouseDragged:NSEventTypeLeftMouseUp;
  NSEvent *e=[NSEvent mouseEventWithType:type location:p modifierFlags:0 timestamp:0 windowNumber:moxi_window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
  if(phase==0) [moxi_canvas mouseDown:e]; else if(phase==1) [moxi_canvas mouseDragged:e]; else [moxi_canvas mouseUp:e];
}
// Protocol callbacks are synthetic evidence, not physical IME acceptance.
void wp_marked(void) {
  [moxi_canvas setMarkedText:@"試" selectedRange:NSMakeRange(1,0) replacementRange:NSMakeRange(NSNotFound,0)];
  assert([moxi_canvas hasMarkedText]);
  assert([moxi_canvas markedRange].length==1);
  [moxi_canvas unmarkText];
  assert(![moxi_canvas hasMarkedText]);
}
void wp_insert(void) { [moxi_canvas insertText:@" · native" replacementRange:NSMakeRange(NSNotFound,0)]; }
double wp_caret(int axis) {
  NSRect r=[moxi_canvas firstRectForCharacterRange:NSMakeRange(0,0) actualRange:NULL];
  NSRect w=[moxi_window convertRectFromScreen:r];
  NSRect local=[moxi_canvas convertRect:w fromView:nil];
  return axis==0 ? local.origin.x : local.origin.y;
}
int wp_contract(void) {
  assert(moxi_text_input_count==1 && moxi_button_count==1 && moxi_slider_count==1);
  assert(moxi_canvas.nativeTextEditor!=nil);
  int roles=0;
  for (MoxiAccessibilityElement *e in [moxi_canvas accessibilityChildren]) {
    NSString *role=[e accessibilityRole];
    if([role isEqualToString:NSAccessibilityTextFieldRole]) roles|=1;
    if([role isEqualToString:NSAccessibilityButtonRole]) roles|=2;
    if([role isEqualToString:NSAccessibilitySliderRole]) roles|=4;
  }
  assert(roles==7);
  for(int i=0;i<moxi_accessibility_count;i++) {
    NSRect expected=NSAccessibilityFrameInView(moxi_canvas,moxi_accessibility_frames[i]);
    assert(NSEqualRects(moxi_accessibility_elements[i].accessibilityFrame,expected));
  }
  assert([moxi_canvas firstRectForCharacterRange:NSMakeRange(0,0) actualRange:NULL].size.height>0);
  return roles;
}
uint64_t wp_editor_identity(void) { return (uint64_t)(__bridge void *)moxi_canvas.nativeTextEditor; }
void wp_clear_events(void) { moxi_reset_event_queue(); }

void wp_field_protocol(void) {
  NSTextView *editor=(NSTextView *)[moxi_window fieldEditor:YES forObject:moxi_canvas.nativeTextEditor];
  assert(editor && moxi_window.firstResponder==editor);
  assert(!moxi_canvas.composedCharacterRect);
  NSRange served;
  NSRect screen = [editor firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&served];
  NSRect local = [moxi_canvas convertRect:[moxi_window convertRectFromScreen:screen] fromView:nil];
  NSRect field = [moxi_canvas.nativeTextEditor convertRect:moxi_canvas.nativeTextEditor.visibleRect toView:moxi_canvas];
  assert(NSEqualRanges(served,NSMakeRange(3,2)) && NSContainsRect(field,local));
  fprintf(stderr,"SCREEN_RANGE 3+2 field-editor=(%.2f %.2f %.2f %.2f)\n",
          NSMinX(local),NSMinY(local),NSWidth(local),NSHeight(local));
  NSString *before=[editor.string copy];
  [editor setSelectedRange:NSMakeRange(0,editor.string.length)];
  NSPasteboard *board=[NSPasteboard pasteboardWithUniqueName];
  assert(editor.selectedRange.length>0);
  assert([editor writeSelectionToPasteboard:board types:editor.writablePasteboardTypes]);
  assert([[board stringForType:NSPasteboardTypeString] isEqualToString:before]);
  assert([editor readSelectionFromPasteboard:board]);
  assert([editor.string isEqualToString:before]);
  [board releaseGlobally];
  [editor setSelectedRange:NSMakeRange(editor.string.length,0)];
  [editor setMarkedText:@"試" selectedRange:NSMakeRange(1,0) replacementRange:NSMakeRange(NSNotFound,0)];
  assert(editor.hasMarkedText);
  [editor insertText:@"" replacementRange:editor.markedRange];
  assert(!editor.hasMarkedText && [editor.string isEqualToString:before]);
  puts("PASS native NSTextView selection / named AppKit clipboard / marked-text protocol; synthetic only");
}

// Replay oracle: independently project all four corners of the field editor's
// measured range, then compare in destination screen coordinates.
void wp_check_geometry(uint64_t view, uint64_t source, int visible) {
  MoxiCanvasView *destination = moxi_canvas;
  for (NSValue *value in @[[NSValue valueWithRange:NSMakeRange(0,0)],
                           [NSValue valueWithRange:NSMakeRange(3,2)]]) {
    NSRange request = value.rangeValue;
    NSRange actual;
    NSRect result = [destination firstRectForCharacterRange:request actualRange:&actual];
    assert(destination == moxi_canvas);
    if (!visible) {
      assert(NSEqualRects(result, NSZeroRect) && actual.location == NSNotFound);
      continue;
    }
    __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous = moxi_active_context;
    assert(moxi_window_select_instance(source));
    NSTextView *editor = (NSTextView *)moxi_canvas.nativeTextEditor.currentEditor;
    assert(editor && editor == moxi_window.firstResponder);
    NSRange served;
    NSRect src = [editor firstRectForCharacterRange:request actualRange:&served];
    NSRect local = [moxi_canvas convertRect:[moxi_window convertRectFromScreen:src] fromView:nil];
    NSRect dest = [destination convertRect:[destination.window convertRectFromScreen:result] fromView:nil];
    double xmin=INFINITY, xmax=-INFINITY, ymin=INFINITY, ymax=-INFINITY;
    for (int i=0;i<4;i++) {
      double x = i&1 ? NSMaxX(local) : NSMinX(local);
      double y = i&2 ? NSMaxY(local) : NSMinY(local);
      double px = ms_panel_project(view,x,y,0), py = ms_panel_project(view,x,y,1);
      xmin=fmin(xmin,px); xmax=fmax(xmax,px);
      ymin=fmin(ymin,py); ymax=fmax(ymax,py);
    }
    fprintf(stderr,"WORLD_RANGE %lu+%lu source=(%.2f %.2f %.2f %.2f) destination=(%.2f %.2f %.2f %.2f)\n",
            (unsigned long)request.location,(unsigned long)request.length,
            NSMinX(local),NSMinY(local),NSWidth(local),NSHeight(local),
            NSMinX(dest),NSMinY(dest),NSWidth(dest),NSHeight(dest));
    assert(NSEqualRanges(served,actual) && NSEqualRanges(request,actual));
    assert(fabs(NSMinX(dest)-xmin)<0.01 && fabs(NSMinY(dest)-ymin)<0.01);
    assert(fabs(NSMaxX(dest)-xmax)<0.01 && fabs(NSMaxY(dest)-ymax)<0.01);
  }
}
