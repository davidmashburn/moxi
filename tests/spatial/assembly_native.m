#import "../../examples/spatial-explorer/host.m"
#import "../../native/spatial/api.h"
static int checks;
#define CHECK(x) do { ++checks; if (!(x)) { fprintf(stderr,"line %d: %s\n",__LINE__,#x); abort(); } } while(0)
static uint64_t owner(void) {
  uint64_t id=moxi_window_create_instance(); CHECK(id); CHECK(moxi_window_select_instance(id));
  moxi_window_open("D07 linked owner",500,350,0,0,0,0,0,0); moxi_reset_event_queue(); return id;
}
int main(void) { @autoreleasepool {
  uint64_t a=owner(),b=owner(),left=ms_create(),right=ms_link(left);
  CHECK(left && right && left!=right);
  CHECK(ms_metric(left,MS_DOCUMENT_ID)==ms_metric(right,MS_DOCUMENT_ID));
  CHECK(ms_metric(left,MS_VIEWS)==2);
  CHECK(ms_mount(left,a)); CHECK(ms_mount(right,b));
  CHECK(ms_viewport(left,10,10,320,240,1)); CHECK(ms_viewport(right,10,10,320,240,1));
  CHECK(ms_camera(right,MS_ORTHOGRAPHIC,0,0,7,0,0,0));
  CHECK(ms_render(left,0)); CHECK(ms_render(right,0));
  CHECK(ms_metric(left,MS_GEOMETRY_ID)==ms_metric(right,MS_GEOMETRY_ID));
  CHECK(ms_metric(left,MS_TARGET_ID)!=ms_metric(right,MS_TARGET_ID));
  CHECK(ms_metric(left,MS_UPLOADS)==1); CHECK(ms_metric(right,MS_UPLOADS)==1);
  CHECK(ms_metric(left,MS_FRAME_BUILDS)==1);
  CHECK(ms_metric(left,MS_GPU_BYTES)==ms_metric(left,MS_VERTICES)*32);
  uint64_t geometry=ms_metric(right,MS_GEOMETRY_ID),target=ms_metric(right,MS_TARGET_ID);
  uint64_t camera=ms_metric(right,MS_CAMERA),rframes=ms_metric(right,MS_SUBMISSIONS);
  for (int i=0;i<10;i++) { CHECK(ms_navigate(left,.01,0,0,0,0)); CHECK(ms_render(left,0)); CHECK(ms_render(right,0)); }
  CHECK(ms_metric(right,MS_CAMERA)==camera); CHECK(ms_metric(right,MS_SUBMISSIONS)==rframes);
  CHECK(ms_metric(right,MS_UPLOADS)==1); CHECK(ms_metric(right,MS_FRAME_BUILDS)==1);
  CHECK(ms_select(right,202)); CHECK(ms_metric(left,MS_SELECTED)==202);
  CHECK(ms_operation(right,MS_AXIS_X,.25,0,0)); CHECK(ms_metric(left,MS_DOCUMENT)==ms_metric(right,MS_DOCUMENT));
  CHECK(ms_render(right,0)); CHECK(ms_render(left,0)); CHECK(ms_metric(left,MS_UPLOADS)==2);
  CHECK(ms_metric(left,MS_FRAME_BUILDS)==2);
  CHECK(ms_clip(left,1,1,0,0,0)); CHECK(ms_render(left,0)); CHECK(ms_render(right,0)); CHECK(ms_metric(left,MS_UPLOADS)==3);
  CHECK(ms_command(right,MS_UNDO)); CHECK(ms_clip_value(left,0)==0); CHECK(ms_render(right,0)); CHECK(ms_render(left,0));
  CHECK(ms_command(left,MS_DISPOSE)); CHECK(ms_state(right)==MS_READY); CHECK(ms_render(right,0));
  CHECK(ms_metric(right,MS_GEOMETRY_ID)==geometry); CHECK(ms_metric(right,MS_TARGET_ID)==target);
  uint64_t uploads=ms_metric(right,MS_UPLOADS),builds=ms_metric(right,MS_FRAME_BUILDS);
  CHECK(ms_command(left,MS_RECREATE)); CHECK(ms_render(left,0)); CHECK(ms_metric(left,MS_GEOMETRY_ID)==geometry);
  CHECK(ms_metric(right,MS_UPLOADS)==uploads); CHECK(ms_metric(right,MS_FRAME_BUILDS)==builds);
  // An independently closed owner fails only its view; survivor keeps GPU buffer.
  CHECK(moxi_window_destroy_instance(a)); CHECK(!ms_render(left,0)); CHECK(ms_state(left)==MS_FAILED);
  CHECK(ms_render(right,0)); CHECK(ms_state(right)==MS_READY);
  CHECK(ms_destroy(left)); CHECK(ms_metric(right,MS_VIEWS)==1);
  CHECK(ms_navigate(right,.05,0,0,0,0)); CHECK(ms_render(right,0));
  CHECK(ms_metric(right,MS_GEOMETRY_ID)==geometry); CHECK(ms_metric(right,MS_UPLOADS)==uploads);
  uint64_t c=owner(),replacement=ms_link(right); CHECK(replacement && replacement!=left); CHECK(ms_mount(replacement,c));
  CHECK(ms_render(replacement,0)); CHECK(ms_metric(replacement,MS_GEOMETRY_ID)==geometry); CHECK(ms_metric(replacement,MS_UPLOADS)==uploads);
  CHECK(ms_objects_begin(right)); CHECK(ms_objects_add(right,8,0,0,0,0,1,1,0,0)); CHECK(ms_objects_parent(right,8,8)); CHECK(!ms_objects_commit(right));
  CHECK(ms_metric(right,MS_DOCUMENT)==ms_metric(replacement,MS_DOCUMENT));
  // Maximum 16 view handles, no stale ID or owner resurrection.
  uint64_t handles[14]; for(int i=0;i<14;i++){handles[i]=ms_link(right);CHECK(handles[i]);}
  CHECK(!ms_link(right)); CHECK(!ms_create());
  for(int i=0;i<14;i++) CHECK(ms_destroy(handles[i]));
  CHECK(!ms_mount(left,c)); CHECK(!ms_render(left,0));
  CHECK(ms_destroy(right)); CHECK(ms_render(replacement,0)); CHECK(ms_destroy(replacement));
  CHECK(moxi_window_destroy_instance(b)); CHECK(moxi_window_destroy_instance(c));
  printf("PASS assembly native shared Metal geometry/independent owners: %d assertions\n",checks);
} return 0; }
