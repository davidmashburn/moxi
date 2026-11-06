// Native example shell and evidence hooks. All spatial math/operations are in
// the public package. Includes the real host to capture its content view; never
// reads/writes its private image registry. No second application loop here.
#import "../../native/macos_window.m"
#include <assert.h>
static int sx_control_builds = 0;
void sx_label(int slot, const char *text, float x, float y, float w, float h,
              float size, float r, float g, float b) {
  moxi_window_set_label_at(slot, text, x, y, w, h, r, g, b, 1, size, 1);
}
void sx_button(int slot, const char *text, float x, float y, float w, float h,
               int active, int focused) {
  moxi_window_set_button_at(slot, text, x, y, w, h, active ? .22 : .095,
                            active ? .27 : .13, active ? .4 : .19, 1, .93, .96,
                            1, 1, 6, 13, 0, focused, 0, 0, 1);
}
void sx_init(void) {
  moxi_window_set_surface(.035, .05, .075, 1);
  moxi_window_begin_frame();
  sx_label(0, "GEOMETRY EXPLORER", 24, 18, 700, 36, 26, .95, .96, 1);
  sx_label(1, "D06  /  Experimental spatial interactions  /  Moxi + Metal", 24,
           57, 1000, 25, 14, .55, .72, .9);
  sx_label(2, "VIEW & GEOMETRY", 24, 102, 190, 25, 12, .48, .69, .88);
  sx_label(3, "CONSTRAINT", 24, 330, 190, 25, 12, .48, .69, .88);
  sx_label(4, "DOCUMENT OUTLINE", 884, 102, 190, 25, 12, .48, .69, .88);
  sx_label(5, "SELECTED OBJECT", 884, 290, 190, 25, 12, .48, .69, .88);
  sx_label(6, "PUBLIC SPATIAL VIEWPORT", 244, 99, 620, 24, 12, .48, .69, .88);
  sx_label(7, "World +Y up • window +Y down • units: world • radians", 244, 612,
           620, 22, 12, .55, .65, .76);
  sx_label(8,
           "Handles / bounds / floor: always-on-top overlays. Anchors: hide if "
           "occluded or offscreen.",
           244, 638, 620, 40, 12, .55, .65, .76);
  sx_label(9,
           "Tab: controls  •  V: viewport  •  N: next object  •  Esc: cancel  "
           "•  Cmd Z / Shift Cmd Z: undo / redo",
           24, 715, 1050, 24, 12, .65, .75, .85);
}
void sx_controls(int tool, int snap, int projection, int focus, int state) {
  sx_control_builds++;
  sx_button(0, "Orbit  [O]", 24, 134, 90, 34, tool == 1, focus == 0);
  sx_button(1, "Pan  [P]", 122, 134, 90, 34, tool == 2, focus == 1);
  sx_button(2, projection ? "Perspective" : "Orthographic", 24, 178, 188, 34,
            projection, focus == 2);
  sx_button(3, "Fit all  [F]", 24, 222, 188, 34, 0, focus == 3);
  sx_button(4, "Parameter +0.12", 24, 266, 188, 34, 0, focus == 4);
  const char *names[] = {"X axis",   "Y axis",   "Z axis",     "XY plane",
                         "XZ plane", "YZ plane", "Z rotation", "Uniform scale"};
  for (int i = 0; i < 8; i++)
    sx_button(5 + i, names[i], 24, 362 + i * 35, 188, 29, tool == 3 + i,
              focus == 5 + i);
  sx_button(13, snap ? "Snap ON · .25 / 15°" : "Snap OFF", 24, 653, 188, 34,
            snap, focus == 13);
  sx_button(14, "101  •  Coral surface", 884, 138, 190, 34, 0, focus == 14);
  sx_button(15, "202  •  Blue surface", 884, 180, 190, 34, 0, focus == 15);
  sx_button(16, "303  •  Lime satellite", 884, 222, 190, 34, 0, focus == 16);
  sx_button(17, "Undo", 884, 540, 90, 34, 0, focus == 17);
  sx_button(18, "Redo", 984, 540, 90, 34, 0, focus == 18);
  sx_button(19,
            state == 2 || state == 3 || state == 4 ? "Recreate viewport"
                                                   : "Dispose viewport",
            884, 586, 190, 34, 0, focus == 19);
  sx_button(20, "Slow parameter update", 884, 632, 190, 34, 0, focus == 20);
  sx_button(21, "Select  [S]", 244, 128, 120, 30, tool == 0, focus == 21);
  sx_button(22, "Apply numeric", 884, 488, 190, 32, 0, focus == 22);
}
int sx_controls_count(void) { return sx_control_builds; }
int sx_hit(float x, float y) {
  for (int i = 0; i < moxi_button_count; i++)
    if (NSPointInRect(NSMakePoint(x, y), moxi_button_frames[i]))
      return i;
  return -1;
}
void sx_numeric(const char *text, int focused) {
  moxi_window_set_text_input_at(0, text, 884, 436, 190, 36, .07, .1, .15, 1,
                                .95, .95, 1, 1, 4, 16, 0, focused,
                                (int)strlen(text), (int)strlen(text),
                                (int)strlen(text), "", 0, 0);
  if (!focused) {
    [moxi_canvas hideNativeTextEditor];
    moxi_active_text_input_index = -1;
    [moxi_window makeFirstResponder:moxi_canvas];
  }
}
double sx_parse(const char *text) {
  char *end = NULL;
  double value = strtod(text, &end);
  while (end && *end == ' ')
    end++;
  return end && end != text && !*end && isfinite(value) ? value : NAN;
}
void sx_numeric_input(const char *text) {
  moxi_canvas.nativeTextEditor.stringValue =
      [NSString stringWithUTF8String:text];
  [moxi_canvas controlTextDidChange:
                   [NSNotification
                       notificationWithName:NSControlTextDidChangeNotification
                                     object:moxi_canvas.nativeTextEditor]];
}

void sx_overlay_begin(void) {
  moxi_window_begin_custom_paint();
  moxi_window_set_clip(1, 244, 124, 620, 480);
}
void sx_line(float x1, float y1, float x2, float y2, float r, float g, float b,
             int handle) {
  moxi_window_add_custom_line(x1, y1, x2, y2, r, g, b, 1, handle ? 3 : 1);
}
void sx_overlay_end(void) { moxi_window_set_clip(0, 0, 0, 0, 0); }
void sx_finish(void) { moxi_window_end_frame(); }
void sx_capture(const char *path) {
  @autoreleasepool {
    [moxi_canvas layoutSubtreeIfNeeded];
    [moxi_canvas displayIfNeeded];
    NSBitmapImageRep *b =
        [moxi_canvas bitmapImageRepForCachingDisplayInRect:moxi_canvas.bounds];
    [moxi_canvas cacheDisplayInRect:moxi_canvas.bounds toBitmapImageRep:b];
    NSData *d = [b representationUsingType:NSBitmapImageFileTypePNG
                                properties:@{}];
    assert([d writeToFile:[NSString stringWithUTF8String:path] atomically:YES]);
  }
}
void sx_inject(int kind, float x, float y, int key, int modifiers) {
  // Synthetic events through real AppKit pointer callbacks, including the
  // native DRAG_BEGIN/DRAG_UPDATE/DROP sequence. Keys use the host queue.
  // This is not hardware or human acceptance evidence.
  if (kind == MOXI_EVENT_POINTER_DOWN || kind == MOXI_EVENT_POINTER_UP ||
      kind == MOXI_EVENT_DRAG_UPDATE) {
    NSEventType type =
        kind == MOXI_EVENT_POINTER_DOWN ? NSEventTypeLeftMouseDown
        : kind == MOXI_EVENT_POINTER_UP ? NSEventTypeLeftMouseUp
                                        : NSEventTypeLeftMouseDragged;
    NSEventModifierFlags flags =
        (modifiers & MOXI_MOD_SHIFT) ? NSEventModifierFlagShift : 0;
    NSEvent *event =
        [NSEvent mouseEventWithType:type
                           location:[moxi_canvas convertPoint:NSMakePoint(x, y)
                                                       toView:nil]
                      modifierFlags:flags
                          timestamp:0
                       windowNumber:moxi_window.windowNumber
                            context:nil
                        eventNumber:1
                         clickCount:1
                           pressure:1];
    if (kind == MOXI_EVENT_POINTER_DOWN)
      [moxi_canvas mouseDown:event];
    else if (kind == MOXI_EVENT_POINTER_UP)
      [moxi_canvas mouseUp:event];
    else
      [moxi_canvas mouseDragged:event];
  } else if (kind == MOXI_EVENT_FOCUS && key == 0) {
    [moxi_delegate windowDidResignKey:
                       [NSNotification
                           notificationWithName:NSWindowDidResignKeyNotification
                                         object:moxi_window]];
  } else
    moxi_enqueue_event(kind, key, modifiers, 0, nil, 0, 0, x, y, 0, 0);
}
