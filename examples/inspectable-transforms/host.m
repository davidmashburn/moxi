// Example-local native shell and replay hooks; public Moxi owns documents,
// projections, manipulation, history, composition and normal event delivery.
#import "../../native/macos_window.m"
#include <assert.h>
#include <limits.h>

// The native field editor normally owns Escape and Cmd-Z. This example's
// document commands must also work while exact entry owns keyboard focus.
static id it_key_monitor;
static NSEvent *it_document_key(NSEvent *event) {
  if(event.window!=moxi_window || event.type!=NSEventTypeKeyDown) return event;
  NSString *text=event.charactersIgnoringModifiers;
  if(text.length!=1)return event;
  unichar ch=[text characterAtIndex:0];
  int modifiers=moxi_event_modifiers_for_flags(event.modifierFlags);
  if(ch==MOXI_KEY_ESCAPE || ch==MOXI_KEY_ENTER ||
      ((ch=='z' || ch=='Z') && modifiers==MOXI_MOD_COMMAND)){
    moxi_enqueue_event(MOXI_EVENT_KEY_DOWN,ch=='Z'?'z':ch,modifiers,0,nil,0,0,0,0,0,0);
    return nil;
  }
  return event;
}

void it_label(int slot, const char *text, float x, float y, float w, float h,
              float size) {
  moxi_window_set_label_at(slot,text,x,y,w,h,.86,.91,.98,1,size,1);
}
void it_init(const char *title, const char *units) {
  it_key_monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
    handler:^NSEvent *(NSEvent *event){return it_document_key(event);}];
  moxi_window_set_surface(.035,.05,.075,1);
  moxi_window_begin_frame();
  it_label(0,title,24,16,1100,34,25);
  it_label(1,units,24,53,1100,26,13);
  it_label(2,"SOURCE  /  drag the card or red X handle; release keeps preview",24,158,540,24,12);
  it_label(3,"REPLAY COPY  /  independent document, same initial revision",644,158,530,24,12);
  it_label(4,"Exact X",24,86,64,25,13);
  it_label(5,"Enter: commit  /  Escape: cancel  /  Cmd-Z: undo  /  Left & Right: preview",24,706,1130,25,13);
  it_label(6,"Versioned semantic command (world value, never screen coordinates)",24,572,1130,24,13);
  const char *names[]={"Preview","Cancel","Commit","Undo","Reproject / resize","Replay command","Undo copy"};
  const float xs[]={218,316,414,512,644,840,1020};
  const float widths[]={90,90,90,90,186,170,154};
  for(int i=0;i<7;i++)
    moxi_window_set_button_at(i,names[i],xs[i],86,widths[i],34,.10,.16,.24,1,.94,.96,1,1,5,13,0,0,0,0,1);
}
void it_numeric(const char *text,int focused) {
  moxi_window_set_text_input_at(0,text,88,84,114,38,.07,.10,.15,1,.95,.95,1,1,4,16,0,focused,
                                (int)strlen(text),(int)strlen(text),(int)strlen(text),"",0,0);
  if(!focused){
    [moxi_canvas hideNativeTextEditor];
    moxi_active_text_input_index=-1;
    [moxi_window makeFirstResponder:moxi_canvas];
  }
}
int it_hit(float x,float y) {
  for(int i=0;i<moxi_button_count;i++)
    if(NSPointInRect(NSMakePoint(x,y),moxi_button_frames[i])) return i;
  return -1;
}
int64_t it_integer(const char *text) {
  char *end=NULL;
  errno=0;
  long value=strtol(text,&end,10);
  while(end && *end==' ')end++;
  return !errno && end && end!=text && !*end && value>=INT_MIN && value<=INT_MAX ? value : INT64_MIN;
}
// Boundary parser: independently validate literal wire keys and numeric types.
// The consumer supplies its named operation and stable target identities.
static int64_t it_values[3];
int it_decode(const char *text,const char *operation,const char *target) {
  NSData *data=[[NSString stringWithUTF8String:text] dataUsingEncoding:NSUTF8StringEncoding];
  id obj=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
  if(![obj isKindOfClass:NSDictionary.class]) return 0;
  NSDictionary *d=obj;
  if(![d[@"operation"] isEqual:[NSString stringWithUTF8String:operation]] ||
     ![d[@"target"] isEqual:[NSString stringWithUTF8String:target]]) return 0;
  NSArray *keys=@[@"version",@"revision",@"from",@"to"];
  int64_t values[4];
  for(int i=0;i<4;i++){
    id n=d[keys[i]];
    if(![n isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)n)==CFBooleanGetTypeID()) return 0;
    double v=[n doubleValue];
    if(!isfinite(v) || floor(v)!=v || fabs(v)>9007199254740991.)return 0;
    values[i]=[n longLongValue];
  }
  if(values[0]!=1 || values[1]<0 || values[2]==values[3])return 0;
  for(int i=0;i<3;i++)it_values[i]=values[i+1];
  return 1;
}
int64_t it_value(int field){return it_values[field];}

void it_paint_begin(void){moxi_window_begin_custom_paint();}
void it_clip(float x,float y,float w,float h){moxi_window_set_clip(1,x,y,w,h);}
void it_line(float x1,float y1,float x2,float y2,float r,float g,float b,float width){
  moxi_window_add_custom_line(x1,y1,x2,y2,r,g,b,1,width);
}
void it_card(float x,float y,float w,float h){
  moxi_window_add_custom_rounded_rect(x,y,w,h,.09,.40,.39,1,.35,.85,.75,1,2,12);
}
void it_paint_end(void){moxi_window_set_clip(0,0,0,0,0);moxi_window_end_frame();}
void it_capture(const char *path){
  [moxi_canvas layoutSubtreeIfNeeded];[moxi_canvas displayIfNeeded];
  NSBitmapImageRep *b=[moxi_canvas bitmapImageRepForCachingDisplayInRect:moxi_canvas.bounds];
  [moxi_canvas cacheDisplayInRect:moxi_canvas.bounds toBitmapImageRep:b];
  NSData *data=[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  assert([data writeToFile:[NSString stringWithUTF8String:path] atomically:YES]);
}
void it_write(const char *path,const char *text){
  assert([[NSString stringWithUTF8String:text] writeToFile:[NSString stringWithUTF8String:path]
    atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
}
// Replays use actual native callbacks, not direct calls to app actions.
void it_input(const char *text){
  NSTextView *editor=(NSTextView *)[moxi_window fieldEditor:YES forObject:moxi_canvas.nativeTextEditor];
  [editor insertText:[NSString stringWithUTF8String:text] replacementRange:NSMakeRange(0,editor.string.length)];
}
void it_inject(int kind,float x,float y,int key,int modifiers){
  if(kind==MOXI_EVENT_POINTER_DOWN || kind==MOXI_EVENT_POINTER_UP || kind==MOXI_EVENT_DRAG_UPDATE){
    NSEventType type=kind==MOXI_EVENT_POINTER_DOWN?NSEventTypeLeftMouseDown:
      kind==MOXI_EVENT_POINTER_UP?NSEventTypeLeftMouseUp:NSEventTypeLeftMouseDragged;
    NSEvent *event=[NSEvent mouseEventWithType:type location:[moxi_canvas convertPoint:NSMakePoint(x,y) toView:nil]
      modifierFlags:0 timestamp:0 windowNumber:moxi_window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    if(kind==MOXI_EVENT_POINTER_DOWN)[moxi_canvas mouseDown:event];
    else if(kind==MOXI_EVENT_POINTER_UP)[moxi_canvas mouseUp:event];
    else [moxi_canvas mouseDragged:event];
  }else if(kind==MOXI_EVENT_KEY_DOWN){
    unichar ch=key==MOXI_KEY_LEFT?NSLeftArrowFunctionKey:key==MOXI_KEY_RIGHT?NSRightArrowFunctionKey:key;
    NSString *text=[NSString stringWithCharacters:&ch length:1];
    NSEventModifierFlags flags=0;
    if(modifiers&MOXI_MOD_SHIFT)flags|=NSEventModifierFlagShift;
    if(modifiers&MOXI_MOD_COMMAND)flags|=NSEventModifierFlagCommand;
    if(modifiers&MOXI_MOD_CONTROL)flags|=NSEventModifierFlagControl;
    if(modifiers&MOXI_MOD_OPTION)flags|=NSEventModifierFlagOption;
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
      timestamp:0 windowNumber:moxi_window.windowNumber context:nil characters:text charactersIgnoringModifiers:text
      isARepeat:NO keyCode:0];
    [NSApp sendEvent:event];
  }else moxi_enqueue_event(kind,key,modifiers,0,nil,0,0,x,y,0,0);
}
void it_resize(int width,int height){
  [moxi_window setContentSize:NSMakeSize(width,height)];
}
double it_extent(int axis){
  return axis==0?moxi_canvas.bounds.size.width:moxi_canvas.bounds.size.height;
}
