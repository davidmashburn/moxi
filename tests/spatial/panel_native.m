#import "../../examples/spatial-world-panel/host.m"
#import "../../native/spatial/api.h"
int main(void) { @autoreleasepool {
  uint64_t a=moxi_window_create_instance();
  assert(moxi_window_select_instance(a));
  moxi_window_open("D08 snapshot owner A",400,240,0,0,0,0,1,0);
  [moxi_window orderOut:nil];
  moxi_window_begin_frame();
  moxi_window_set_surface(.1,.2,.3,1);
  moxi_window_end_frame();
  MoxiCanvasView *av=moxi_canvas;
  uint64_t b=moxi_window_create_instance();
  assert(moxi_window_select_instance(b));
  moxi_window_open("D08 snapshot owner B",500,300,0,0,0,0,1,0);
  [moxi_window orderOut:nil];
  MoxiCanvasView *bv=moxi_canvas;
  uint8_t bytes[400*240*4];
  assert(moxi_composition_snapshot(a,bytes,sizeof bytes,400,240));
  assert(moxi_canvas==bv);
  assert(!moxi_composition_snapshot(a,bytes,4,400,240));
  assert(!moxi_composition_snapshot(a,bytes,sizeof bytes,399,240));
  assert(moxi_canvas==bv);
  uint64_t s=ms_create();
  assert(ms_mount(s,b));
  assert(ms_panel_configure(s,-2,1.2,0,4,0,0,0,-2.4,0,400,240));
  assert(!ms_panel_render(s,b,0));
  assert(ms_panel_render(s,a,0));
  assert(moxi_canvas==bv);
  assert(!ms_mount(s,a));
  moxi_window_destroy_instance(a);
  assert(!moxi_composition_snapshot(a,bytes,sizeof bytes,400,240));
  assert(!ms_panel_render(s,a,0));
  assert(av!=bv);
  assert(ms_destroy(s));
  moxi_window_destroy_instance(b);
  puts("PASS D08 native owner snapshot isolation, bounds, source retirement and mount rejection");
} }
