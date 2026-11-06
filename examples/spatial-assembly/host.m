// Example-only native shell/evidence hooks. Public window drawing and spatial APIs.
// The AppKit internals below are used only for capture and synthetic event delivery.
#import "../../native/macos_window.m"
#include <assert.h>
static int controlBuilds;
enum { AssemblyControlCount = 20 };
static NSRect controlFrames[AssemblyControlCount];
void sa_label(int slot,const char *text,float x,float y,float w,float h,float size) {
  moxi_window_set_label_at(slot,text,x,y,w,h,.80,.87,.95,1,size,1);
}
void sa_button(int slot,const char *text,float x,float y,float w,int active) {
  assert(slot >= 0 && slot < AssemblyControlCount);
  controlFrames[slot] = NSMakeRect(x,y,w,30);
  moxi_window_set_button_at(slot,text,x,y,w,30,active?.20:.085,active?.29:.13,active?.37:.19,1,.93,.96,1,1,5,13,0,0,0,0,1);
}
void sa_init(void) {
  moxi_window_set_surface(.028,.045,.07,1); moxi_window_begin_frame();
  sa_label(0,"ASSEMBLY / INSPECTOR",22,16,950,38,27);
  sa_label(1,"D07   •   One document / two views   •   Experimental copied-image Metal",24,55,1100,25,13);
  sa_label(2,"TRANSFORM HIERARCHY",24,104,210,24,12);
  sa_label(3,"PERSPECTIVE",252,104,420,25,13);
  sa_label(4,"ORTHOGRAPHIC / FRONT",728,104,420,25,13);
  sa_label(5,"MANIPULATE",24,328,200,24,12);
  sa_label(6,"O orbit   P pan   S select   M probe   X translate   R rotate   Esc cancel   Cmd Z undo",252,718,930,24,12);
  sa_label(7,"Right-handed +Y  •  world units  •  probe anchors follow transforms  •  clip has no cap",252,747,930,22,11);
}
void sa_controls(int selected,int tool,int measure,int clip,int disposed) {
  controlBuilds++;
  sa_button(0,"10  /  Carrier",24,138,204,selected==10);
  sa_button(1,"    72  /  Arm",24,178,204,selected==72);
  sa_button(2,"        405  /  Joint",24,218,204,selected==405);
  sa_button(3,"    93  /  Balance",24,258,204,selected==93);
  sa_button(4,"Select [S]",24,364,98,tool==0&&!measure);
  sa_button(5,"Orbit [O]",130,364,98,tool==1);
  sa_button(6,"Pan [P]",24,402,98,tool==2);
  sa_button(7,"X axis [X]",130,402,98,tool==3);
  sa_button(8,"Z rotation [R]",24,440,98,tool==9);
  sa_button(9,"Scale",130,440,98,tool==10);
  sa_button(10,"Apply numeric",24,524,204,0);
  sa_button(11,"Surface probe [M]",252,556,210,measure);
  sa_button(12,"Clear probes",476,556,210,0);
  sa_button(13,clip?"Disable clip":"Clip X >= 0",728,556,210,clip);
  sa_button(14,"Plane +0.25",952,556,210,0);
  sa_button(15,"Undo",24,576,98,0); sa_button(16,"Redo",130,576,98,0);
  sa_button(17,"Fit both",24,620,204,0);
  sa_button(18,disposed?"Recreate right":"Dispose right",728,650,210,disposed);
  sa_button(19,"Slow geometry",952,650,210,0);
}
int sa_controls_count(void) { return controlBuilds; }
int sa_hit(float x,float y) {
  for(int i=0;i<AssemblyControlCount;i++) if(NSPointInRect(NSMakePoint(x,y),controlFrames[i])) return i;
  return -1;
}
void sa_numeric(const char *text,int focused) {
  moxi_window_set_text_input_at(0,text,24,482,204,32,.07,.1,.15,1,.95,.95,1,1,4,16,0,focused,(int)strlen(text),(int)strlen(text),(int)strlen(text),"",0,0);
}
double sa_parse(const char *text) {
  char *end=NULL; double value=strtod(text,&end); while(end&&*end==' ')end++;
  return end&&end!=text&&!*end&&isfinite(value)?value:NAN;
}
void sa_numeric_input(const char *text) {
  moxi_canvas.nativeTextEditor.stringValue=[NSString stringWithUTF8String:text];
  [moxi_canvas controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:moxi_canvas.nativeTextEditor]];
}
void sa_paint(void) { moxi_window_begin_custom_paint(); }
void sa_unclip(void) { moxi_window_set_clip(0,0,0,0,0); }
void sa_clip(float x) { moxi_window_set_clip(1,x,140,440,390); }
void sa_line(float x1,float y1,float x2,float y2,float r,float g,float b,int handle) { moxi_window_add_custom_line(x1,y1,x2,y2,r,g,b,1,handle?3:1); }
void sa_finish(void) { moxi_window_set_clip(0,0,0,0,0); moxi_window_end_frame(); }
void sa_capture(const char *path) {
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
void sa_inject(int kind, float x, float y, int key, int modifiers) {
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
