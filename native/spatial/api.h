#ifndef MOXI_SPATIAL_API_H
#define MOXI_SPATIAL_API_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Experimental C ABI used by the public Mojo module. Handles are non-reused,
 * main-thread confined; worker threads never touch documents or native owners.
 */
enum MSTool {
  MS_SELECT,
  MS_ORBIT,
  MS_PAN,
  MS_AXIS_X,
  MS_AXIS_Y,
  MS_AXIS_Z,
  MS_PLANE_XY,
  MS_PLANE_XZ,
  MS_PLANE_YZ,
  MS_ROTATE_Z,
  MS_SCALE
};
enum MSState { MS_READY, MS_COMPUTING, MS_DISPOSED, MS_UNSUPPORTED, MS_FAILED };
enum MSProjection { MS_PERSPECTIVE, MS_ORTHOGRAPHIC };
enum MSCommand {
  MS_FIT,
  MS_NEXT,
  MS_UNDO,
  MS_REDO,
  MS_CANCEL,
  MS_DISPOSE,
  MS_RECREATE
};
enum MSMetric {
  MS_DOCUMENT,
  MS_GEOMETRY,
  MS_CAMERA,
  MS_VIEWPORT,
  MS_GENERATION,
  MS_PREVIEW,
  MS_SELECTED,
  MS_HISTORY,
  MS_BUILDS,
  MS_ACCEPTED,
  MS_REJECTED,
  MS_REPLACED,
  MS_FRAME_BUILDS,
  MS_UPLOADS,
  MS_SUBMISSIONS,
  MS_DOCUMENT_ID, MS_VIEWS, MS_VERTICES, MS_GEOMETRY_ID, MS_TARGET_ID, MS_GPU_BYTES
};
enum MSTiming {
  MS_CPU,
  MS_ENCODE,
  MS_WAIT,
  MS_GPU,
  MS_READBACK,
  MS_PUBLICATION,
  MS_TOTAL
};
uint64_t ms_create(void);
/* Linked views share document/history/selection/worker/geometry, but have their
 * own camera, viewport, lifecycle and composition owner. Total handles <=16. */
uint64_t ms_link(uint64_t source);
int ms_objects_parent(uint64_t session, uint64_t object, uint64_t parent);
uint64_t ms_parent(uint64_t session, uint64_t object);
double ms_world_transform(uint64_t session, uint64_t object, int component, int preview);
/* Normal is normalized together with offset. Keep dot(n,p)>=offset, no caps.
 * Clip is document history; measurements are ephemeral local object anchors. */
int ms_clip(uint64_t session, int enabled, double nx, double ny, double nz, double offset);
double ms_clip_value(uint64_t session, int field);
int ms_probe(uint64_t session, double x, double y);
int ms_probe_set(uint64_t session, int endpoint, uint64_t object, double x, double y, double z);
int ms_probe_clear(uint64_t session);
double ms_measurement(uint64_t session, int component);
int ms_destroy(uint64_t session);
int ms_state(uint64_t session);
int ms_viewport(uint64_t session, double x, double y, double width,
                double height, double scale);
int ms_camera(uint64_t session, int projection, double yaw, double pitch,
              double distance, double x, double y, double z);
int ms_parameter(uint64_t session, double parameter, int delay_ms);
int ms_poll(uint64_t session);
int ms_objects_begin(uint64_t session);
int ms_objects_add(uint64_t session, uint64_t object, double x, double y,
                   double z, double angle, double scale, double r, double g,
                   double b);
int ms_objects_commit(uint64_t session);
double ms_camera_value(uint64_t session, int component);
double ms_displayed_parameter(uint64_t session);
int ms_select(uint64_t session, uint64_t object);
int ms_command(uint64_t session, int command);
int ms_operation(uint64_t session, int tool, double a, double b, int snap);
int ms_pointer_down(uint64_t session, int tool, double x, double y);
int ms_pointer_move(uint64_t session, double x, double y, int snap);
int ms_pointer_up(uint64_t session);
int ms_navigate(uint64_t session, double yaw, double pitch, double pan_x,
                double pan_y, double dolly);
uint64_t ms_metric(uint64_t session, int metric);
double ms_parameter_value(uint64_t session);
double ms_transform_value(uint64_t session, uint64_t object, int component,
                          int preview);
/* Projected anchors: 0 visible, 1 occluded, 2 offscreen, 3 behind camera.
 * The following coordinate getters refer to the same last anchor query. */
int ms_overlay_prepare(uint64_t session, int tool);
double ms_overlay_value(uint64_t session, int line, int field);
int ms_anchor(uint64_t session, double x, double y, double z,
              int always_visible);
double ms_anchor_x(uint64_t session);
double ms_anchor_y(uint64_t session);
/* Native boundary. Mount binds once to an owner; a different owner is rejected.
 * Render freezes camera/geometry/viewport/revisions, publishes only on exact
 * agreement, then composes the snapshot into an ordinary Moxi image slot.
 * No event pump, timers, window creation, or global renderer ownership here. */
int ms_mount(uint64_t session, uint64_t owner);
int ms_render(uint64_t session, int image_slot);
double ms_timing(uint64_t session, int metric);
#ifdef __cplusplus
}
#endif
#endif
