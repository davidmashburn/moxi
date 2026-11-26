// Repeated real Metal target resizing and owner teardown in one process.
#import "../../native/macos_window.m"
#import "../../native/spatial/api.h"
#include <assert.h>
#include <stdio.h>

static void exercise(int linked) {
  uint64_t owner = moxi_window_create_instance();
  assert(owner && moxi_window_select_instance(owner));
  moxi_window_open("Spatial lifecycle fixture", 500, 350, 0, 0, 0, 0, 0, 0);
  uint64_t views[2] = {ms_create(), 0};
  if (linked) views[1] = ms_link(views[0]);
  for (int i = 0; i <= linked; i++) {
    assert(views[i] && ms_mount(views[i], owner));
  }
  for (int step = 0; step < 6; step++) {
    for (int i = 0; i <= linked; i++) {
      uint64_t view = views[i];
      int width = step % 2 ? 220 : 180;
      int height = step % 2 ? 160 : 140;
      assert(ms_viewport(view, i * 240, 10, width, height, 1));
      assert(ms_navigate(view, .01, 0, 0, 0, 0));
      uint64_t frames = ms_metric(view, MS_SUBMISSIONS);
      assert(ms_render(view, i));
      assert(ms_metric(view, MS_SUBMISSIONS) == frames + 1);
    }
  }
  for (int i = linked; i >= 0; i--) assert(ms_destroy(views[i]));
  moxi_window_close();
  assert(moxi_window_destroy_instance(owner));
}

int main(void) {
  for (int linked = 0; linked <= 1; linked++) {
    for (int cycle = 0; cycle < 20; cycle++) {
      @autoreleasepool { exercise(linked); }
    }
    printf("PASS %s: 20 open/close cycles, 6 camera + viewport resizes per view per cycle\n",
           linked ? "linked" : "single");
  }
  return 0;
}
