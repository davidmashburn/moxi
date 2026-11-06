#include "api.h"
#include "core.hpp"
#include "renderer.h"
#include <cmath>
#include <map>
#include <memory>
#include <thread>
using namespace moxi::spatial;
namespace {
struct Entry {
  Session model;
  uint64_t owner = 0, renderer = 0;
  Revision published{0, 0, 0, 0, 0, 0};
  Projected anchor;
  std::vector<ScreenLine> lines;
  std::optional<std::vector<Object>> staging;
  bool stagingValid = false;
  ~Entry() {
    if (renderer)
      ms_renderer_destroy(renderer);
  }
};
std::map<uint64_t, std::unique_ptr<Entry>> entries;
uint64_t nextID = 1;
const std::thread::id hostThread = std::this_thread::get_id();
Entry *get(uint64_t id) {
  if (std::this_thread::get_id() != hostThread)
    return nullptr;
  auto i = entries.find(id);
  return i == entries.end() ? nullptr : i->second.get();
}
bool tool(int t) { return t >= MS_SELECT && t <= MS_SCALE; }
} // namespace
extern "C" {
uint64_t ms_create() {
  if (std::this_thread::get_id() != hostThread || entries.size() >= 16 ||
      !nextID)
    return 0;
  try {
    auto e = std::make_unique<Entry>();
    uint64_t id = nextID++;
    entries.emplace(id, std::move(e));
    return id;
  } catch (...) {
    return 0;
  }
}
int ms_destroy(uint64_t id) {
  if (!get(id))
    return 0;
  entries.erase(id);
  return 1;
}
int ms_state(uint64_t id) {
  auto e = get(id);
  return e ? int(e->model.state()) : MS_DISPOSED;
}
int ms_viewport(uint64_t id, double x, double y, double w, double h,
                double scale) {
  auto e = get(id);
  return e && e->model.setViewport({x, y, w, h, scale});
}
int ms_camera(uint64_t id, int p, double yaw, double pitch, double distance,
              double x, double y, double z) {
  auto e = get(id);
  if (!e || (p != MS_PERSPECTIVE && p != MS_ORTHOGRAPHIC))
    return 0;
  return e->model.setCamera({Projection(p), yaw, pitch, distance, {x, y, z}});
}
int ms_parameter(uint64_t id, double p, int delay) {
  auto e = get(id);
  return e && e->model.parameter(p, delay);
}
int ms_poll(uint64_t id) {
  auto e = get(id);
  return e && e->model.poll();
}
int ms_objects_begin(uint64_t id) {
  auto e = get(id);
  if (!e)
    return 0;
  e->staging = std::vector<Object>{};
  e->stagingValid = true;
  return 1;
}
int ms_objects_add(uint64_t id, uint64_t object, double x, double y, double z,
                   double angle, double scale, double r, double g, double b) {
  auto e = get(id);
  if (!e || !e->staging)
    return 0;
  if (e->staging->size() >= maxObjects) {
    e->stagingValid = false;
    return 0;
  }
  e->staging->push_back({object, {{x, y, z}, angle, scale}, {r, g, b}});
  return 1;
}
int ms_objects_commit(uint64_t id) {
  auto e = get(id);
  if (!e || !e->staging)
    return 0;
  bool ok = e->stagingValid && e->model.setObjects(std::move(*e->staging));
  e->staging.reset();
  return ok;
}
double ms_camera_value(uint64_t id, int component) {
  auto e = get(id);
  if (!e)
    return NAN;
  auto c = e->model.camera();
  switch (component) {
  case 0:
    return int(c.projection);
  case 1:
    return c.yaw;
  case 2:
    return c.pitch;
  case 3:
    return c.distance;
  case 4:
    return c.target.x;
  case 5:
    return c.target.y;
  case 6:
    return c.target.z;
  default:
    return NAN;
  }
}
double ms_displayed_parameter(uint64_t id) {
  auto e = get(id);
  return e ? e->model.displayedParameter() : NAN;
}
int ms_select(uint64_t id, uint64_t object) {
  auto e = get(id);
  return e && e->model.select(object);
}
int ms_command(uint64_t id, int command) {
  auto e = get(id);
  if (!e)
    return 0;
  auto &m = e->model;
  switch (command) {
  case MS_FIT:
    m.fit();
    return 1;
  case MS_NEXT:
    m.selectNext();
    return 1;
  case MS_UNDO:
    return m.undo();
  case MS_REDO:
    return m.redo();
  case MS_CANCEL:
    m.captureLost();
    return 1;
  case MS_DISPOSE:
    m.dispose();
    if (e->renderer)
      ms_renderer_destroy(e->renderer);
    e->renderer = 0;
    return 1;
  case MS_RECREATE:
    m.recreate();
    return 1;
  default:
    return 0;
  }
}
int ms_operation(uint64_t id, int t, double a, double b, int snap) {
  auto e = get(id);
  return e && tool(t) && e->model.operation({Tool(t), a, b, snap != 0});
}
int ms_pointer_down(uint64_t id, int t, double x, double y) {
  auto e = get(id);
  return e && tool(t) ? int(e->model.pointerDown(Tool(t), x, y))
                      : int(Route::Rejected);
}
int ms_pointer_move(uint64_t id, double x, double y, int snap) {
  auto e = get(id);
  return e && e->model.pointerMove(x, y, snap != 0);
}
int ms_pointer_up(uint64_t id) {
  auto e = get(id);
  return e && e->model.pointerUp();
}
int ms_navigate(uint64_t id, double yaw, double pitch, double x, double y,
                double dolly) {
  auto e = get(id);
  if (!e || !std::isfinite(yaw) || !std::isfinite(pitch) || !std::isfinite(x) ||
      !std::isfinite(y) || !std::isfinite(dolly))
    return 0;
  e->model.orbit(yaw, pitch);
  e->model.pan(x, y);
  e->model.dolly(dolly);
  return 1;
}
uint64_t ms_metric(uint64_t id, int metric) {
  auto e = get(id);
  if (!e)
    return 0;
  auto r = e->model.revision();
  auto c = e->model.counters();
  switch (metric) {
  case MS_DOCUMENT:
    return r.document;
  case MS_GEOMETRY:
    return r.geometry;
  case MS_CAMERA:
    return r.camera;
  case MS_VIEWPORT:
    return r.viewport;
  case MS_GENERATION:
    return r.generation;
  case MS_PREVIEW:
    return r.preview;
  case MS_SELECTED:
    return e->model.selection();
  case MS_HISTORY:
    return e->model.undoCount();
  case MS_BUILDS:
    return c.builds;
  case MS_ACCEPTED:
    return c.accepted;
  case MS_REJECTED:
    return c.rejected;
  case MS_REPLACED:
    return c.replaced;
  case MS_FRAME_BUILDS:
    return c.frameBuilds;
  case MS_UPLOADS:
  case MS_SUBMISSIONS:
    return ms_renderer_metric(e->renderer, metric);
  default:
    return 0;
  }
}
double ms_parameter_value(uint64_t id) {
  auto e = get(id);
  return e ? e->model.document().parameter : NAN;
}
double ms_transform_value(uint64_t id, uint64_t object, int component,
                          int preview) {
  auto e = get(id);
  if (!e)
    return NAN;
  for (auto &o : e->model.document().objects)
    if (o.id == object) {
      auto t = o.transform;
      auto g = e->model.gesture();
      if (preview && g && g->id == object)
        t = g->preview;
      switch (component) {
      case 0:
        return t.position.x;
      case 1:
        return t.position.y;
      case 2:
        return t.position.z;
      case 3:
        return t.angle;
      case 4:
        return t.scale;
      default:
        return NAN;
      }
    }
  return NAN;
}
int ms_overlay_prepare(uint64_t id, int t) {
  auto e = get(id);
  if (!e || !tool(t))
    return 0;
  e->lines = e->model.overlays(Tool(t));
  return int(e->lines.size());
}
double ms_overlay_value(uint64_t id, int line, int field) {
  auto e = get(id);
  if (!e || line < 0 || size_t(line) >= e->lines.size())
    return NAN;
  auto l = e->lines[line];
  switch (field) {
  case 0:
    return l.x1;
  case 1:
    return l.y1;
  case 2:
    return l.x2;
  case 3:
    return l.y2;
  case 4:
    return l.color.x;
  case 5:
    return l.color.y;
  case 6:
    return l.color.z;
  case 7:
    return l.handle;
  default:
    return NAN;
  }
}
int ms_anchor(uint64_t id, double x, double y, double z, int always) {
  auto e = get(id);
  if (!e)
    return int(AnchorState::Offscreen);
  e->anchor =
      e->model.annotation({x, y, z}, always ? AnchorPolicy::AlwaysVisible
                                            : AnchorPolicy::HideOccluded);
  return int(e->anchor.state);
}
double ms_anchor_x(uint64_t id) {
  auto e = get(id);
  return e ? e->anchor.x : NAN;
}
double ms_anchor_y(uint64_t id) {
  auto e = get(id);
  return e ? e->anchor.y : NAN;
}
int ms_mount(uint64_t id, uint64_t owner) {
  auto e = get(id);
  if (!e || !owner || (e->owner && e->owner != owner))
    return 0;
  if (e->renderer)
    return 1;
  uint64_t r = ms_renderer_create(owner);
  if (!r) {
    e->model.fail(State::Unsupported);
    return 0;
  }
  e->owner = owner;
  e->renderer = r;
  e->published = {0, 0, 0, 0, 0, 0};
  return 1;
}
int ms_render(uint64_t id, int slot) {
  auto e = get(id);
  if (!e)
    return 0;
  auto state = e->model.state();
  if (state != State::Ready && state != State::Computing)
    return 0;
  if (!e->renderer && (!e->owner || !ms_mount(id, e->owner)))
    return 0;
  const auto &f = e->model.frame();
  auto v = f.viewport;
  bool same = f.revision == e->published;
  bool upload = f.revision.document != e->published.document ||
                f.revision.geometry != e->published.geometry ||
                f.revision.preview != e->published.preview ||
                f.revision.generation != e->published.generation;
  const Vertex empty{};
  const void *data = same                 ? nullptr
                     : f.vertices.empty() ? &empty
                                          : f.vertices.data();
  if (!e->model.frameCurrent(f.revision))
    return 0;
  int ok = ms_renderer_frame(
      e->renderer, data, f.vertices.size(), upload, f.matrix.data(),
      int(std::lround(v.width * v.scale)), int(std::lround(v.height * v.scale)),
      slot, float(v.x), float(v.y), float(v.width), float(v.height));
  if (ok)
    e->published = f.revision;
  else {
    e->model.fail(State::Failed);
    ms_renderer_destroy(e->renderer);
    e->renderer = 0;
  }
  return ok;
}
double ms_timing(uint64_t id, int metric) {
  auto e = get(id);
  return e ? ms_renderer_timing(e->renderer, metric) : NAN;
}
}
