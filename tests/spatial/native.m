// Real AppKit/Metal composition and F02 isolation, using private state only as
// an independent test oracle (never as the consumer's publication path).
#import "../../examples/spatial-explorer/host.m"
#import "../../native/spatial/api.h"
static int checks = 0;
#define CHECK(x)                                                               \
  do {                                                                         \
    checks++;                                                                  \
    if (!(x)) {                                                                \
      fprintf(stderr, "line %d: %s\n", __LINE__, #x);                          \
      abort();                                                                 \
    }                                                                          \
  } while (0)
static uint64_t owner(const char *name) {
  uint64_t id = moxi_window_create_instance();
  CHECK(id);
  CHECK(moxi_window_select_instance(id));
  moxi_window_open(name, 400, 300, 0, 0, 0, 0, 0, 0);
  moxi_reset_event_queue();
  return id;
}
int main(void) {
  @autoreleasepool {
    uint64_t a = owner("D06 owner A"), b = owner("D06 owner B");
    MoxiWindowState *bState = moxi_active_context;
    uint64_t ra = moxi_composition_acquire(a), rb = moxi_composition_acquire(b);
    CHECK(ra && rb && ra != rb);
    CHECK(moxi_active_context == bState);
    uint8_t red[4] = {255, 0, 0, 255}, green[4] = {0, 255, 0, 255};
    CHECK(!moxi_composition_publish(b, ra, 1, red, 4, 1, 1, 4));
    CHECK(!moxi_composition_publish(a, ra, 1, red, 4, 2049, 1, 8196));
    CHECK(!moxi_composition_publish(a, ra, 1, red, 3, 1, 1, 4));
    CHECK(moxi_composition_publish(a, ra, 1, red, 4, 1, 1, 4));
    red[0] = 0;
    CHECK(moxi_composition_compose(a, ra, 0, 0, 0, 100, 100));
    CHECK(moxi_active_context == bState);
    CHECK(!moxi_composition_compose(a, ra, 1, 0, 0, 100,
                                    100)); // stable slot binding
    CHECK(
        !moxi_composition_publish(a, ra, 1, green, 4, 1, 1, 4)); // stale serial
    CHECK(moxi_window_select_instance(a));
    NSImage *snapshot = moxi_image_resources[0];
    NSBitmapImageRep *bitmap = (NSBitmapImageRep *)snapshot.representations[0];
    CHECK(bitmap.bitmapData[0] == 255);
    CHECK(moxi_composition_publish(a, ra, 2, green, 4, 1, 1, 4));
    CHECK(moxi_image_resources[0] == snapshot); // immutable composed snapshot
    CHECK(moxi_composition_publish(b, rb, 1, green, 4, 1, 1, 4));
    CHECK(moxi_composition_compose(b, rb, 0, 0, 0, 100, 100));
    CHECK(moxi_image_resources[0] == snapshot);
    CHECK(!moxi_composition_release(b, ra));
    CHECK(moxi_composition_release(a, ra));
    CHECK(moxi_image_resources[0] == nil);
    CHECK(!moxi_composition_compose(a, ra, 0, 0, 0, 100, 100));
    CHECK(moxi_window_select_instance(b));
    CHECK(moxi_image_resources[0] != nil);
    uint64_t session = ms_create(), other = ms_create();
    CHECK(session && other);
    CHECK(ms_mount(session, a));
    CHECK(!ms_mount(session, b));
    CHECK(ms_mount(other, b));
    CHECK(ms_viewport(session, 20, 20, 256, 180, 1));
    CHECK(ms_viewport(other, 20, 20, 256, 180, 1));
    CHECK(ms_render(session, 1));
    CHECK(ms_render(other, 1));
    CHECK(ms_metric(session, MS_UPLOADS) == 1 &&
          ms_metric(session, MS_SUBMISSIONS) == 1);
    uint64_t frames = ms_metric(session, MS_FRAME_BUILDS);
    CHECK(ms_navigate(session, .2, 0, 0, 0, 0));
    CHECK(ms_render(session, 1));
    CHECK(ms_metric(session, MS_UPLOADS) == 1 &&
          ms_metric(session, MS_SUBMISSIONS) == 2);
    CHECK(ms_metric(session, MS_FRAME_BUILDS) == frames);
    CHECK(ms_metric(other, MS_UPLOADS) == 1 &&
          ms_metric(other, MS_SUBMISSIONS) == 1);
    CHECK(ms_render(session, 1));
    CHECK(ms_metric(session, MS_SUBMISSIONS) == 2);
    CHECK(!ms_viewport(session, 0, 0, 4096, 180, 1));
    CHECK(ms_render(session, 1));
    CHECK(ms_select(session, 202));
    CHECK(ms_operation(session, MS_AXIS_X, .25, 0, 1));
    CHECK(ms_metric(session, MS_HISTORY) == 1);
    CHECK(ms_render(session, 1));
    CHECK(ms_metric(session, MS_UPLOADS) == 2);
    CHECK(ms_objects_begin(session));
    CHECK(ms_objects_commit(session));
    CHECK(ms_render(session, 1)); // honest empty frame
    CHECK(ms_command(session, MS_DISPOSE));
    CHECK(!ms_render(session, 1));
    CHECK(ms_command(session, MS_RECREATE));
    for (int i = 0; i < 100 && ms_state(session) == MS_COMPUTING; i++) {
      [NSThread sleepForTimeInterval:.005];
      ms_poll(session);
    }
    CHECK(ms_state(session) == MS_READY);
    CHECK(ms_render(session, 1));
    CHECK(moxi_window_destroy_instance(a));
    CHECK(!ms_render(session, 1));
    CHECK(ms_state(session) == MS_FAILED);
    uint64_t c = owner("D06 recreated owner");
    CHECK(c != a);
    CHECK(!moxi_composition_publish(a, ra, 3, green, 4, 1, 1, 4));
    CHECK(!ms_mount(session, c));
    CHECK(ms_destroy(session));
    CHECK(!ms_destroy(session));
    CHECK(ms_destroy(other));
    CHECK(moxi_composition_release(b, rb));
    uint64_t resources[32];
    for (int i = 0; i < 32; i++) {
      resources[i] = moxi_composition_acquire(c);
      CHECK(resources[i]);
    }
    CHECK(!moxi_composition_acquire(c));
    for (int i = 0; i < 32; i++)
      CHECK(moxi_composition_release(c, resources[i]));
    uint64_t closed = moxi_composition_acquire(c);
    CHECK(closed);
    CHECK(moxi_window_select_instance(c));
    moxi_window_close();
    CHECK(moxi_window_select_instance(b));
    MoxiWindowState *selected = moxi_active_context;
    CHECK(!moxi_composition_publish(c, closed, 1, green, 4, 1, 1, 4));
    CHECK(!moxi_composition_acquire(c));
    CHECK(moxi_active_context == selected);
    CHECK(moxi_window_destroy_instance(b));
    CHECK(moxi_window_destroy_instance(c));
    printf("PASS spatial native composition/F02/Metal: %d assertions\n",
           checks);
  }
  return 0;
}
