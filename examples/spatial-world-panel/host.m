// App shell + native evidence only. No camera/ray math or image-table injection.
#import "../../native/macos_window.m"
#include <assert.h>
void wp_hide(void) { [moxi_window orderOut:nil]; }
void wp_chrome(const char *mode,const char *message) {
  moxi_window_set_clip(0,0,0,0,0);
  moxi_window_set_label_at(40,"S4 / WORLD PANEL FEASIBILITY",24,18,950,40,.93,.96,1,1,27,1);
  moxi_window_set_label_at(41,mode,26,65,940,30,.40,.76,1,1,16,1);
  moxi_window_set_label_at(42,message,26,560,940,54,.92,.76,.40,1,15,1);
  moxi_window_set_label_at(43,"F6 / click mode title: switch  •  Tab: controls  •  Escape: cancel / leave controls",26,632,940,26,.75,.82,.9,1,14,1);
  moxi_window_set_label_at(44,"Experimental copied-image Metal. World IME / AX geometry unsupported. VoiceOver paused.",26,665,950,25,.64,.72,.82,1,13,1);
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
