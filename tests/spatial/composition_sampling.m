// Focused public composition sampling and owner/lifecycle regression.
#import "../../native/macos_window.m"
#include <assert.h>
int main(void) {
  @autoreleasepool {
    uint64_t a=moxi_window_create_instance();
    assert(moxi_window_select_instance(a));
    moxi_window_open("sampling A",200,160,200,160,400,400,1,0);
    uint64_t ta=moxi_composition_acquire(a);
    uint8_t pixels[]={255,0,0,255,0,255,0,255,0,0,255,255,255,255,0,255};
    assert(moxi_composition_publish(a,ta,1,pixels,sizeof pixels,2,2,8));
    uint64_t b=moxi_window_create_instance();
    assert(moxi_window_select_instance(b));
    moxi_window_open("sampling B",200,160,200,160,400,400,1,0);
    MoxiWindowState *selected=moxi_active_context;
    assert(moxi_composition_compose_sampled(a,ta,0,10,10,100,100,MoxiImageSamplingNearest));
    assert(moxi_active_context==selected); // no cross-window state routing
    assert(!moxi_composition_compose_sampled(b,ta,0,10,10,100,100,MoxiImageSamplingNearest));
    assert(!moxi_composition_compose_sampled(a,ta,0,10,10,100,100,(MoxiImageSampling)9));
    assert(moxi_window_select_instance(a));
    assert(moxi_image_nearest[0]);
    assert(moxi_composition_compose(a,ta,0,10,10,100,100));
    assert(!moxi_image_nearest[0]); // existing API retains default interpolation
    assert(moxi_composition_compose_sampled(a,ta,0,10,10,100,100,MoxiImageSamplingNearest));
    moxi_window_begin_frame();
    assert(!moxi_image_nearest[0]);
    assert(moxi_composition_compose_sampled(a,ta,0,10,10,100,100,MoxiImageSamplingNearest));
    assert(moxi_composition_release(a,ta));
    assert(moxi_image_resources[0]==nil);
    assert(!moxi_composition_compose_sampled(a,ta,0,10,10,100,100,MoxiImageSamplingNearest));
    assert(moxi_window_destroy_instance(a));
    assert(!moxi_composition_publish(a,ta,2,pixels,sizeof pixels,2,2,8));
    assert(moxi_window_select_instance(b));
    assert(moxi_window_is_open());
    assert(moxi_window_destroy_instance(b));
    puts("PASS sampled image default/nearest/invalid, frame reset, two owners, release/retire");
  }
  return 0;
}
