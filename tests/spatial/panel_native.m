#import "../../examples/spatial-world-panel/host.m"
#import "../../native/spatial/api.h"

static void source_field(const char *value, int clipped, NSRect clip) {
  moxi_window_begin_frame();
  moxi_window_ordered_paint_begin();
  moxi_window_set_clip(clipped,NSMinX(clip),NSMinY(clip),NSWidth(clip),NSHeight(clip));
  moxi_window_set_text_input_at(0,value,16,52,340,38,
      0,0,0,1,1,1,1,1,4,16,0,1,0,0,0,"",0,0);
  moxi_window_ordered_paint(5,0);
  moxi_window_end_frame();
}

int main(void) { @autoreleasepool {
  uint64_t a=moxi_window_create_instance();
  assert(moxi_window_select_instance(a));
  moxi_window_open("D08 snapshot owner A",400,240,0,0,0,0,1,0);
  [moxi_window orderOut:nil];
  moxi_window_begin_frame();
  moxi_window_set_surface(.1,.2,.3,1);
  moxi_window_end_frame();
  MoxiCanvasView *av=moxi_canvas;
  source_field("Synthetic panel",0,NSZeroRect);
  uint64_t b=moxi_window_create_instance();
  assert(moxi_window_select_instance(b));
  moxi_window_open("D08 snapshot owner B",500,300,0,0,0,0,1,0);
  [moxi_window orderOut:nil];
  MoxiCanvasView *bv=moxi_canvas;
  NSRange fallbackRange;
  NSRect fallback = [bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&fallbackRange];
  uint8_t bytes[400*240*4];
  assert(moxi_composition_snapshot(a,bytes,sizeof bytes,400,240));
  assert(moxi_canvas==bv);
  assert(!moxi_composition_snapshot(a,bytes,4,400,240));
  assert(!moxi_composition_snapshot(a,bytes,sizeof bytes,399,240));
  assert(moxi_canvas==bv);
  uint64_t s=ms_create();
  assert(ms_mount(s,b));
  assert(ms_panel_configure(s,-2,1.2,0,4,0,0,0,-2.4,0,400,240));
  assert(ms_objects_begin(s) && ms_objects_commit(s));
  assert(ms_viewport(s,0,0,500,300,1));
  assert(ms_camera(s,MS_PERSPECTIVE,.55,.22,6,0,0,0));
  wp_bind_geometry(s,a,0);
  wp_check_geometry(s,a,0);
  wp_bind_geometry(s,a,1);
  wp_check_geometry(s,a,1);
  assert(ms_clip(s,1,1,0,0,-1.9));
  wp_check_geometry(s,a,1);
  // The document clip cuts the interior of the 3+2 substring.
  NSTextView *editor = (NSTextView *)av.nativeTextEditor.currentEditor;
  NSRect substring = [editor firstRectForCharacterRange:NSMakeRange(3,2) actualRange:NULL];
  NSRect local = [av convertRect:[av.window convertRectFromScreen:substring] fromView:nil];
  assert(ms_clip(s,1,1,0,0,-2 + 4 * NSMidX(local) / 400));
  NSRange served;
  NSRect partial = [bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&served];
  assert(NSEqualRects(partial,NSZeroRect) && served.location == NSNotFound);
  assert(ms_clip(s,1,1,0,0,0));
  wp_check_geometry(s,a,0);
  assert(ms_clip(s,0,1,0,0,0));
  assert(ms_objects_begin(s) && ms_objects_add(s,1,0,0,1,0,1,1,0,0) && ms_objects_commit(s));
  wp_check_geometry(s,a,0);
  assert(ms_objects_begin(s) && ms_objects_commit(s));
  wp_check_geometry(s,a,1);
  // The ordinary host clips the source halfway through range 3+2. AppKit
  // shortens firstRect's width but still reports the entire requested range.
  assert(moxi_window_select_instance(a));
  NSRect full = local;
  id identity = av.nativeTextEditor;
  NSRange selection = editor.selectedRange;
  NSString *text = [editor.string copy];
  source_field("Synthetic panel",1,NSMakeRect(16,52,NSMidX(full)-16,38));
  NSRange nativeRange;
  NSRect native = [editor firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&nativeRange];
  NSRect shortened = [av convertRect:[av.window convertRectFromScreen:native] fromView:nil];
  assert(NSEqualRanges(nativeRange,NSMakeRange(3,2)));
  assert(fabs(NSWidth(shortened) - NSWidth(full)/2) < .01);
  assert(moxi_window_select_instance(b));
  NSRect rejected = [bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&served];
  fprintf(stderr,"NATIVE_PARTIAL_CLIP range=3+2 full=%s shortened=%s destination=%s actual=%s\n",
          NSStringFromRect(full).UTF8String,NSStringFromRect(shortened).UTF8String,
          NSStringFromRect(rejected).UTF8String,NSStringFromRange(served).UTF8String);
  assert(NSEqualRects(rejected,NSZeroRect) && served.location == NSNotFound);
  assert(NSEqualRects(rejected,[bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:NULL]));
  assert(moxi_canvas==bv && av.nativeTextEditor==identity && av.nativeTextEditor.currentEditor==editor);
  assert(NSEqualRanges(editor.selectedRange,selection) && [editor.string isEqualToString:text]);
  // A zero-width insertion before the same clip remains a valid range.
  NSRect insertion = [editor firstRectForCharacterRange:NSMakeRange(0,0) actualRange:NULL];
  assert(NSWidth(insertion)==0 && NSHeight(insertion)>0);
  NSRect retained = [bv firstRectForCharacterRange:NSMakeRange(0,0) actualRange:&served];
  assert(!NSEqualRects(retained,NSZeroRect) && NSEqualRanges(served,NSMakeRange(0,0)));
  // Exercise the other three partial boundaries and a fully hidden range
  // through ordinary ordered-paint clipping, without changing native views.
  NSRect clips[] = {
    NSMakeRect(NSMidX(full),52,356-NSMidX(full),38),
    NSMakeRect(16,NSMidY(full),340,90-NSMidY(full)),
    NSMakeRect(16,52,340,NSMidY(full)-52),
    NSMakeRect(16,52,NSMinX(full)-18,38)
  };
  for (NSUInteger i=0;i<sizeof clips/sizeof clips[0];i++) {
    assert(moxi_window_select_instance(a));
    source_field("Synthetic panel",1,clips[i]);
    assert(moxi_window_select_instance(b));
    rejected = [bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&served];
    assert(NSEqualRects(rejected,NSZeroRect) && served.location==NSNotFound && served.length==0);
    assert(moxi_canvas==bv && av.nativeTextEditor==identity && av.nativeTextEditor.currentEditor==editor);
    assert(NSEqualRanges(editor.selectedRange,selection) && [editor.string isEqualToString:text]);
  }
  assert(moxi_window_select_instance(a));
  source_field("Synthetic panel",1,NSMakeRect(16,52,NSMaxX(full)+1-16,38));
  assert(moxi_window_select_instance(b));
  wp_check_geometry(s,a,1);
  // Empty text still has a native insertion rectangle, with its own line height.
  assert(moxi_window_select_instance(a));
  source_field("",0,NSZeroRect);
  assert(moxi_window_select_instance(b));
  retained = [bv firstRectForCharacterRange:NSMakeRange(0,0) actualRange:&served];
  assert(!NSEqualRects(retained,NSZeroRect) && NSEqualRanges(served,NSMakeRange(0,0)));
  assert(moxi_window_select_instance(a));
  source_field("Synthetic panel",0,NSZeroRect);
  assert(moxi_window_select_instance(b));
  wp_check_geometry(s,a,1);
  wp_bind_geometry(0,a,0);
  retained = [bv firstRectForCharacterRange:NSMakeRange(3,2) actualRange:&served];
  assert(NSEqualRects(retained,fallback) && NSEqualRanges(served,fallbackRange));
  wp_bind_geometry(s,a,1);
  assert(!ms_panel_render(s,b,0));
  assert(ms_panel_render(s,a,0));
  assert(moxi_canvas==bv);
  assert(!ms_mount(s,a));
  moxi_window_destroy_instance(a);
  wp_check_geometry(s,a,0);
  assert(!moxi_composition_snapshot(a,bytes,sizeof bytes,400,240));
  assert(!ms_panel_render(s,a,0));
  assert(av!=bv);
  assert(ms_destroy(s));
  moxi_window_destroy_instance(b);
  puts("PASS D08 native projected ranges, focus, clipping, populated scene, snapshot isolation and retirement");
} }
