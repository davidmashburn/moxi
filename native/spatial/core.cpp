#include "core.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <limits>
#include <set>
namespace moxi::spatial {
Vec3 operator+(Vec3 a, Vec3 b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
Vec3 operator-(Vec3 a, Vec3 b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
Vec3 operator*(Vec3 a, double s) { return {a.x * s, a.y * s, a.z * s}; }
double dot(Vec3 a, Vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
Vec3 cross(Vec3 a, Vec3 b) {
  return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
}
double length(Vec3 a) { return std::sqrt(dot(a, a)); }
Vec3 unit(Vec3 a) {
  double n = length(a);
  return n > epsilon ? a * (1 / n) : Vec3{};
}
bool finite(Vec3 a) {
  return std::isfinite(a.x) && std::isfinite(a.y) && std::isfinite(a.z);
}
Vec3 world(Vec3 a, const Transform &t) {
  double c = cos(t.angle), s = sin(t.angle);
  return t.position + Vec3{a.x * c - a.y * s, a.x * s + a.y * c, a.z} * t.scale;
}
bool valid(const Transform &t) {
  return finite(t.position) && length(t.position) <= 20 &&
         std::isfinite(t.angle) && fabs(t.angle) <= 100 * pi &&
         std::isfinite(t.scale) && t.scale >= .1 && t.scale <= 5;
}
bool valid(const Camera &c) {
  return (c.projection == Projection::Perspective ||
          c.projection == Projection::Orthographic) &&
         finite(c.target) && length(c.target) <= 30 && std::isfinite(c.yaw) &&
         fabs(c.yaw) < 1e6 && std::isfinite(c.pitch) && fabs(c.pitch) <= 1.4 &&
         std::isfinite(c.distance) && c.distance >= .5 && c.distance <= 60;
}
bool valid(const Viewport &v) {
  return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.width) &&
         std::isfinite(v.height) && std::isfinite(v.scale) && v.width >= 1 &&
         v.height >= 1 && v.scale >= .5 && v.scale <= 4 &&
         v.width * v.scale <= 2048 && v.height * v.scale <= 2048;
}
struct Basis {
  Vec3 right, up, back, eye;
};
static Basis basis(const Camera &c) {
  Vec3 back = {sin(c.yaw) * cos(c.pitch), sin(c.pitch),
               cos(c.yaw) * cos(c.pitch)};
  Vec3 right = unit(cross({0, 1, 0}, back));
  return {right, cross(back, right), back, c.target + back * c.distance};
}
Projected project(Vec3 p, const Camera &c, const Viewport &v) {
  Projected out;
  if (!finite(p) || !valid(c) || !valid(v))
    return out;
  auto b = basis(c);
  Vec3 d = p - b.eye;
  double depth = -dot(d, b.back);
  out.depth = depth;
  if (depth < .1) {
    out.state = AnchorState::BehindCamera;
    return out;
  }
  double h = (c.projection == Projection::Perspective ? depth : c.distance) *
             tan(pi / 8);
  double nx = dot(d, b.right) / (h * v.width / v.height), ny = dot(d, b.up) / h;
  out.x = v.x + (nx + 1) * v.width / 2;
  out.y = v.y + (1 - ny) * v.height / 2;
  out.state = (depth <= 100 && fabs(nx) <= 1 && fabs(ny) <= 1)
                  ? AnchorState::Visible
                  : AnchorState::Offscreen;
  return out;
}
std::optional<Ray> unproject(double x, double y, const Camera &c,
                             const Viewport &v) {
  if (!valid(c) || !valid(v) || !std::isfinite(x) || !std::isfinite(y))
    return {};
  auto b = basis(c);
  double nx = 2 * (x - v.x) / v.width - 1, ny = 1 - 2 * (y - v.y) / v.height;
  double h =
      (c.projection == Projection::Perspective ? .1 : c.distance) * tan(pi / 8);
  Vec3 origin = b.eye - b.back * .1 + b.right * (nx * h * v.width / v.height) +
                b.up * (ny * h);
  return Ray{origin, c.projection == Projection::Perspective
                         ? unit(origin - b.eye)
                         : b.back * (-1)};
}
std::array<float, 16> matrix(const Camera &c, const Viewport &v) {
  auto b = basis(c);
  double V[16] = {b.right.x,
                  b.up.x,
                  b.back.x,
                  0,
                  b.right.y,
                  b.up.y,
                  b.back.y,
                  0,
                  b.right.z,
                  b.up.z,
                  b.back.z,
                  0,
                  -dot(b.right, b.eye),
                  -dot(b.up, b.eye),
                  -dot(b.back, b.eye),
                  1};
  double P[16] = {};
  double f = 1 / tan(pi / 8), aspect = v.width / v.height;
  if (c.projection == Projection::Perspective) {
    P[0] = f / aspect;
    P[5] = f;
    P[10] = 100 / (.1 - 100);
    P[11] = -1;
    P[14] = .1 * 100 / (.1 - 100);
  } else {
    P[0] = f / (c.distance * aspect);
    P[5] = f / c.distance;
    P[10] = 1 / (.1 - 100);
    P[14] = .1 / (.1 - 100);
    P[15] = 1;
  }
  std::array<float, 16> M{};
  for (int col = 0; col < 4; col++)
    for (int row = 0; row < 4; row++)
      for (int k = 0; k < 4; k++)
        M[col * 4 + row] += float(P[k * 4 + row] * V[col * 4 + k]);
  return M;
}
std::optional<double> rayTriangle(Ray r, Vec3 a, Vec3 b, Vec3 c) {
  if (!finite(r.origin) || !finite(r.direction) || !finite(a) || !finite(b) ||
      !finite(c))
    return {};
  Vec3 e1 = b - a, e2 = c - a, p = cross(r.direction, e2);
  double det = dot(e1, p);
  if (fabs(det) < 1e-10)
    return {};
  double inv = 1 / det;
  Vec3 t = r.origin - a;
  double u = dot(t, p) * inv;
  if (u < -1e-9 || u > 1 + 1e-9)
    return {};
  Vec3 q = cross(t, e1);
  double v = dot(r.direction, q) * inv;
  if (v < -1e-9 || u + v > 1 + 1e-9)
    return {};
  double distance = dot(e2, q) * inv;
  if (distance < 0 || !std::isfinite(distance))
    return {};
  return distance;
}
std::optional<Vec3> rayPlane(Ray r, Vec3 p, Vec3 n) {
  double d = dot(r.direction, n);
  if (!finite(r.origin) || !finite(r.direction) || !finite(p) || !finite(n) ||
      fabs(d) < 1e-5)
    return {};
  double t = dot(p - r.origin, n) / d;
  if (t < 0 || t > 1000)
    return {};
  return r.origin + r.direction * t;
}
std::optional<double> rayAxis(Ray r, Vec3 p, Vec3 axis) {
  // Closest points on unit ray and unit line. Reject near-parallel; never
  // substitute a discontinuous screen-space axis during an active gesture.
  axis = unit(axis);
  double b = dot(r.direction, axis), d = 1 - b * b;
  if (d < 1e-5 || length(axis) < .5)
    return {};
  Vec3 w = r.origin - p;
  double s = (dot(axis, w) - b * dot(r.direction, w)) / d;
  double t = b * s - dot(r.direction, w);
  if (t < 0 || !std::isfinite(s))
    return {};
  return s;
}
Pick pick(Ray r, const std::vector<Triangle> &ts) {
  // Determine the global nearest distance before choosing a tie ID. Updating
  // the minimum to a farther tied candidate makes chained ties order-dependent.
  double nearest = std::numeric_limits<double>::infinity();
  for (auto &t : ts)
    if (auto d = rayTriangle(r, t.a, t.b, t.c))
      nearest = std::min(nearest, *d);
  Pick out;
  for (auto &t : ts) {
    auto d = rayTriangle(r, t.a, t.b, t.c);
    if (d && *d <= nearest + 1e-7 && (!out.id || t.id < out.id))
      out = {t.id, *d, r.origin + r.direction * (*d)};
  }
  return out;
}
Mesh generate(double parameter) {
  Mesh m;
  m.parameter = parameter;
  if (!std::isfinite(parameter) || parameter < 0 || parameter > .65)
    return m;
  // Fixed bounded tessellation, parameter changes actual vertices. Polar
  // triangles are emitted once (no degenerate second triangles at poles).
  constexpr int rings = 20, slices = 40;
  auto at = [&](int i, int j) {
    double a = pi * i / rings, b = 2 * pi * j / slices;
    double r =
        .68 * (1 + parameter * sin(3 * b) * sin(a) * sin(a) * cos(2 * a));
    return Vec3{r * sin(a) * cos(b), r * cos(a), r * sin(a) * sin(b)};
  };
  for (int i = 0; i < rings; i++)
    for (int j = 0; j < slices; j++) {
      Vec3 a = at(i, j), b = at(i + 1, j), c = at(i + 1, j + 1),
           d = at(i, j + 1);
      if (i > 0) {
        m.vertices.push_back(a);
        m.vertices.push_back(b);
        m.vertices.push_back(d);
      }
      if (i < rings - 1) {
        m.vertices.push_back(b);
        m.vertices.push_back(c);
        m.vertices.push_back(d);
      }
    }
  return m;
}
static bool transformTool(Tool t) {
  return t >= Tool::AxisX && t <= Tool::Scale;
}
static Vec3 axis(Tool t) {
  return t == Tool::AxisX   ? Vec3{1, 0, 0}
         : t == Tool::AxisY ? Vec3{0, 1, 0}
                            : Vec3{0, 0, 1};
}
static Vec3 normal(Tool t) {
  return t == Tool::PlaneXZ   ? Vec3{0, 1, 0}
         : t == Tool::PlaneYZ ? Vec3{1, 0, 0}
                              : Vec3{0, 0, 1};
}
std::optional<Transform> apply(const Transform &before, Operation op) {
  if (!valid(before) || !transformTool(op.tool) || !std::isfinite(op.a) ||
      !std::isfinite(op.b) || !std::isfinite(op.grid) ||
      !std::isfinite(op.angle) || op.grid <= 0 || op.angle <= 0)
    return {};
  auto snap = [&](double x, double grid) {
    return op.snap ? std::round(x / grid) * grid : x;
  };
  Transform t = before;
  double a = snap(op.a, op.tool == Tool::RotateZ ? op.angle : op.grid),
         b = snap(op.b, op.grid);
  switch (op.tool) {
  case Tool::AxisX:
  case Tool::AxisY:
  case Tool::AxisZ:
    t.position = t.position + axis(op.tool) * a;
    break;
  case Tool::PlaneXY:
    t.position = t.position + Vec3{a, b, 0};
    break;
  case Tool::PlaneXZ:
    t.position = t.position + Vec3{a, 0, b};
    break;
  case Tool::PlaneYZ:
    t.position = t.position + Vec3{0, a, b};
    break;
  case Tool::RotateZ:
    t.angle += a;
    break;
  case Tool::Scale:
    t.scale *= op.snap ? snap(op.a, .1) : op.a;
    break;
  default:
    return {};
  }
  return valid(t) ? std::optional<Transform>(t) : std::nullopt;
}
namespace {
Transform compose(const Transform &parent, const Transform &local) {
  return {world(local.position, parent), parent.angle + local.angle, parent.scale * local.scale};
}
Vec3 inversePoint(Vec3 p, const Transform &t) {
  p = (p - t.position) * (1 / t.scale);
  double c = cos(t.angle), s = sin(t.angle);
  return {c*p.x+s*p.y, -s*p.x+c*p.y, p.z};
}
std::optional<Transform> resolve(const std::vector<Object> &objects, uint64_t id,
                                 const std::optional<Gesture> &drag, size_t depth = 0) {
  if (depth >= maxObjects) return {};
  for (auto &o : objects) if (o.id == id) {
    if (drag && drag->id == id) return drag->preview;
    if (!o.parent) return o.transform;
    auto parent = resolve(objects, o.parent, drag, depth + 1);
    if (!parent) return {};
    return compose(*parent, o.transform);
  }
  return {};
}
bool hierarchyValid(const std::vector<Object> &objects, const std::optional<Gesture> &drag = {}) {
  for (auto &o : objects) {
    auto t = resolve(objects, o.id, drag);
    if (!t || !valid(*t)) return false;
  }
  return true;
}
}
Revision Session::revision() const {
  auto r = rev;
  r.camera = v().cameraRevision; r.viewport = v().viewportRevision;
  r.view = activeView; r.lifecycle = v().epoch;
  return r;
}
uint64_t Session::createView() {
  if (!usable() || views.size() >= 16 || !nextView) return 0;
  auto id = nextView++;
  views.emplace(id, ViewState{});
  return id;
}
bool Session::activateView(uint64_t id) {
  if (!views.count(id)) return false;
  activeView = id;
  return true;
}
void Session::removeView(uint64_t id) {
  if (!views.count(id)) return;
  auto old = activeView;
  activateView(id); dispose(); views.erase(id);
  if (!views.empty()) activeView = views.count(old) ? old : views.begin()->first;
}
std::optional<Transform> Session::worldTransform(uint64_t id, bool preview) const {
  return resolve(doc.objects, id, preview ? drag : std::optional<Gesture>{});
}
std::optional<Transform> Session::localTransform(uint64_t id) const {
  auto o = object(id); if (!o) return {};
  auto t = worldTransform(id);
  if (!o->parent) return t;
  auto parent = *worldTransform(o->parent);
  return Transform{inversePoint(t->position,parent),t->angle-parent.angle,t->scale/parent.scale};
}
bool Session::clipping(ClipPlane plane) {
  double n = length(plane.normal);
  if (!usable() || !finite(plane.normal) || !std::isfinite(plane.offset) ||
      n < epsilon || !std::isfinite(n) || fabs(plane.offset / n) > 40 ||
      (plane.enabled && mesh.vertices.size() * doc.objects.size() * 2 > maxVertices)) return false;
  plane.normal = plane.normal * (1/n); plane.offset /= n;
  if (plane == doc.clip) return true;
  cancel(); auto before = doc; doc.clip = plane; history(before); changed(false);
  return true;
}
bool Session::setProbe(int endpoint, uint64_t id, Vec3 local) {
  if (!usable() || endpoint < 0 || endpoint > 1 || !object(id) || !finite(local) || length(local) > 2) return false;
  probes[endpoint] = Probe{id, local};
  return true;
}
void Session::clearProbes() { probes = {}; nextProbe = 0; }
std::optional<Measurement> Session::measurement() const {
  if (!probes[0] || !probes[1]) return {};
  auto a = worldTransform(probes[0]->object), b = worldTransform(probes[1]->object);
  if (!a || !b) return {};
  auto p = world(probes[0]->local, *a), q = world(probes[1]->local, *b);
  return Measurement{p, q, length(q-p)};
}
bool Session::probe(double x, double y) {
  if (!usable()) return false;
  auto ray = unproject(x, y, v().camera, v().viewport);
  if (!ray) return false;
  auto hit = pick(*ray, frame().triangles);
  if (!hit.id || project(hit.point, v().camera, v().viewport).state != AnchorState::Visible) return false;
  auto transform = *worldTransform(hit.id);
  if (!setProbe(nextProbe, hit.id, inversePoint(hit.point, transform))) return false;
  nextProbe = (nextProbe + 1) % 2;
  return true;
}
Session::Session() {
  doc.objects = {{101, {{-1.1, 0, .25}, 0, 1}, {1, .26, .08}},
                 {202, {{.55, .1, -.45}, 0, 1}, {.08, .65, 1}},
                 {303, {{1.55, -.65, -1.3}, 0, .6}, {.55, .8, .2}}};
  mesh = generate(doc.parameter);
  counts.accepted = 1;
  buildCount = 1;
  cached.revision = {0, 0, 0, 0, 0, 0};
  thread = std::thread(&Session::worker, this);
}
Session::~Session() {
  {
    std::lock_guard lock(mutex);
    stopping = true;
    pending.reset();
  }
  cv.notify_all();
  thread.join();
}
bool Session::usable() const {
  return state() == State::Ready || state() == State::Computing;
}
Object *Session::object(uint64_t id) {
  for (auto &o : doc.objects)
    if (o.id == id)
      return &o;
  return nullptr;
}
const Object *Session::object(uint64_t id) const {
  for (auto &o : doc.objects)
    if (o.id == id)
      return &o;
  return nullptr;
}
bool Session::setObjects(std::vector<Object> objects) {
  if (!usable() || objects.size() > maxObjects ||
      objects.size() * mesh.vertices.size() * (doc.clip.enabled ? 2 : 1) > maxVertices)
    return false;
  std::set<uint64_t> ids;
  for (auto &o : objects)
    if (!o.id || !ids.insert(o.id).second || !valid(o.transform) ||
        !finite(o.color) || std::min({o.color.x, o.color.y, o.color.z}) < 0 ||
        std::max({o.color.x, o.color.y, o.color.z}) > 1)
      return false;
  if (!hierarchyValid(objects)) return false;
  cancel();
  Document before = doc;
  doc.objects = std::move(objects);
  if (!object(selected))
    selected = doc.objects.empty() ? 0 : doc.objects[0].id;
  history(before);
  changed(false);
  return true;
}
bool Session::setCamera(Camera c) {
  if (!usable() || !valid(c))
    return false;
  if (c == v().camera)
    return true;
  if (dragView == activeView) cancel();
  v().camera = c;
  v().cameraRevision++;
  return true;
}
bool Session::setViewport(Viewport value) {
  if (!valid(value))
    return false;
  if (value == v().viewport)
    return true;
  if (dragView == activeView) cancel();
  v().viewport = value;
  v().viewportRevision++;
  return true;
}
bool Session::select(uint64_t id) {
  if (!usable() || (id && !object(id)))
    return false;
  if (id != selected)
    cancel();
  selected = id;
  return true;
}
void Session::selectNext() {
  if (doc.objects.empty())
    return;
  size_t i = 0;
  if (!selected) {
    select(doc.objects[0].id);
    return;
  }
  for (; i < doc.objects.size(); i++)
    if (doc.objects[i].id == selected)
      break;
  select(doc.objects[(i + 1) % doc.objects.size()].id);
}
void Session::orbit(double x, double y) {
  Camera c = v().camera;
  c.yaw += x;
  c.pitch = std::clamp(c.pitch + y, -1.4, 1.4);
  setCamera(c);
}
void Session::pan(double x, double y) {
  auto b = basis(v().camera);
  Camera c = v().camera;
  c.target = c.target + b.right * x + b.up * y;
  setCamera(c);
}
void Session::dolly(double x) {
  Camera c = v().camera;
  c.distance = std::clamp(c.distance + x, .5, 60.);
  setCamera(c);
}
void Session::fit() {
  if (doc.objects.empty())
    return;
  Vec3 min{100, 100, 100}, max{-100, -100, -100};
  for (auto &o : doc.objects) {
    auto t = *worldTransform(o.id);
    double r = 1.15 * t.scale;
    auto p = t.position;
    min = {std::min(min.x, p.x - r), std::min(min.y, p.y - r),
           std::min(min.z, p.z - r)};
    max = {std::max(max.x, p.x + r), std::max(max.y, p.y + r),
           std::max(max.z, p.z + r)};
  }
  Camera c = v().camera;
  c.target = (min + max) * .5;
  double angle = atan(tan(pi / 8) * std::min(1., v().viewport.width / v().viewport.height));
  c.distance = std::clamp(length(max - min) * .5 / sin(angle), .5, 60.);
  setCamera(c);
}
void Session::history(Document before) {
  if (before == doc)
    return;
  undoStack.push_back(std::move(before));
  if (undoStack.size() > maxHistory)
    undoStack.erase(undoStack.begin());
  redoStack.clear();
}
void Session::queue(int delay) {
  std::lock_guard lock(mutex);
  if (pending)
    counts.replaced++;
  pending = Work{rev.generation, workRevision, doc.parameter, delay};
  cv.notify_all();
}
void Session::changed(bool geometry) {
  rev.document++;
  workRevision++;
  if (geometry || status == State::Computing) {
    status = State::Computing;
    queue(0);
  }
}
bool Session::parameter(double p, int delay) {
  if (!usable() || !std::isfinite(p) || p < 0 || p > .65 || delay < 0 ||
      delay > 2000)
    return false;
  if (p == doc.parameter)
    return true;
  cancel();
  Document before = doc;
  doc.parameter = p;
  history(before);
  rev.document++;
  workRevision++;
  status = State::Computing;
  queue(delay);
  return true;
}
void Session::worker() {
  for (;;) {
    Work w;
    {
      std::unique_lock lock(mutex);
      cv.wait(lock, [&] { return stopping || pending.has_value(); });
      if (stopping)
        return;
      w = *pending;
      pending.reset();
      if (w.delayMS && cv.wait_for(lock, std::chrono::milliseconds(w.delayMS),
                                   [&] { return stopping; }))
        return;
    }
    WorkResult result{w, {}, false};
    try {
      result.mesh = generate(w.parameter);
    } catch (...) {
      result.failed = true;
    }
    buildCount++;
    {
      std::lock_guard lock(mutex);
      completed = std::move(result);
    }
  }
}
bool Session::accept(WorkResult result) {
  if ((status != State::Ready && status != State::Computing) || result.input.generation != rev.generation ||
      result.input.revision != workRevision ||
      result.input.parameter != doc.parameter) {
    counts.rejected++;
    return false;
  }
  if (result.failed || result.mesh.vertices.empty() ||
      result.mesh.vertices.size() * doc.objects.size() * (doc.clip.enabled ? 2 : 1) > maxVertices) {
    status = State::Failed;
    cancel();
    return false;
  }
  if (drag && transformTool(drag->tool))
    cancel();
  clearProbes();
  mesh = std::move(result.mesh);
  rev.geometry++;
  status = State::Ready;
  counts.accepted++;
  return true;
}
bool Session::poll() {
  std::optional<WorkResult> r;
  {
    std::lock_guard lock(mutex);
    r = std::move(completed);
    completed.reset();
  }
  return r ? accept(std::move(*r)) : false;
}
const Frame &Session::frame() {
  if (cached.revision == revision())
    return cached;
  bool verticesChanged = cached.revision.geometry != rev.geometry ||
                         cached.revision.document != rev.document ||
                         cached.revision.preview != rev.preview ||
                         cached.revision.generation != rev.generation;
  if (verticesChanged) {
    cached.triangles.clear();
    cached.vertices.clear();
    for (auto &o : doc.objects) {
      Transform t = *worldTransform(o.id);
      for (size_t i = 0; i < mesh.vertices.size(); i += 3) {
        Vec3 a = world(mesh.vertices[i], t), b = world(mesh.vertices[i + 1], t),
             c = world(mesh.vertices[i + 2], t);
        Vec3 n = unit(cross(b - a, c - a));
        double shade = .40 + .60 * fabs(dot(n, unit({.4, .8, 1})));
        std::array<Vec3, 4> polygon{a,b,c,{}};
        size_t count = 3;
        if (doc.clip.enabled) {
          count = 0;
          std::array<Vec3, 3> input{a,b,c};
          for (size_t edge = 0; edge < 3; ++edge) {
            auto p = input[edge], q = input[(edge+1)%3];
            double dp = dot(doc.clip.normal,p)-doc.clip.offset;
            double dq = dot(doc.clip.normal,q)-doc.clip.offset;
            if (dp >= 0) polygon[count++] = p;
            if ((dp >= 0) != (dq >= 0)) polygon[count++] = p+(q-p)*(dp/(dp-dq));
          }
        }
        for (size_t j = 1; j+1 < count; ++j) {
          auto p = polygon[0], q = polygon[j], r = polygon[j+1];
          if (doc.clip.enabled && length(cross(q-p,r-p)) <= epsilon) continue;
          cached.triangles.push_back({p,q,r,o.id});
          for (auto point : {p,q,r})
            cached.vertices.push_back(
                {{float(point.x), float(point.y), float(point.z), 1},
                 {float(o.color.x * shade), float(o.color.y * shade),
                  float(o.color.z * shade), 1}});
        }
      }
    }
    counts.frameBuilds++;
  }
  cached.revision = revision();
  cached.camera = v().camera;
  cached.viewport = v().viewport;
  cached.matrix = matrix(v().camera, v().viewport);
  return cached;
}
bool Session::constraint(Tool t, Ray r, Vec3 pivot, Vec3 &point,
                         double &scalar) const {
  if (t >= Tool::AxisX && t <= Tool::AxisZ) {
    auto s = rayAxis(r, pivot, axis(t));
    if (!s)
      return false;
    scalar = *s;
    point = pivot + axis(t) * scalar;
    return true;
  }
  auto p = rayPlane(r, pivot, normal(t));
  if (!p)
    return false;
  point = *p;
  scalar = length(*p - pivot);
  return true;
}
bool Session::begin(Tool t, double x, double y) {
  if (!usable() || drag || !transformTool(t))
    return false;
  auto o = object(selected);
  auto ray = unproject(x, y, v().camera, v().viewport);
  if (!o || !ray)
    return false;
  Vec3 anchor;
  double scalar = 0;
  auto transform = *worldTransform(o->id);
  if (!constraint(t, *ray, transform.position, anchor, scalar))
    return false;
  if ((t == Tool::RotateZ || t == Tool::Scale) && scalar < .05)
    return false;
  dragView = activeView;
  drag = Gesture{t,   selected, transform, transform,
                 revision(), anchor, transform.position, scalar};
  return true;
}
bool Session::preview(Operation op) {
  if (!drag || dragView != activeView || op.tool != drag->tool || drag->start.document != rev.document ||
      drag->start.geometry != rev.geometry ||
      drag->start.camera != v().cameraRevision ||
      drag->start.viewport != v().viewportRevision ||
      drag->start.generation != rev.generation)
    return false;
  auto t = apply(drag->before, op);
  if (!t)
    return false;
  if (*t == drag->preview)
    return true;
  auto selectedObject = object(drag->id);
  if (selectedObject->parent) {
    auto parent = *worldTransform(selectedObject->parent);
    Transform local{inversePoint(t->position,parent), t->angle-parent.angle, t->scale/parent.scale};
    if (!valid(local)) return false;
  }
  auto candidate = *drag; candidate.preview = *t;
  if (!hierarchyValid(doc.objects, candidate)) return false;
  drag->preview = *t;
  rev.preview++;
  return true;
}
bool Session::update(double x, double y, bool snap) {
  if (!drag || dragView != activeView)
    return false;
  auto ray = unproject(x, y, v().camera, v().viewport);
  Vec3 p;
  double scalar = 0;
  if (!ray || !constraint(drag->tool, *ray, drag->pivot, p, scalar))
    return false;
  Operation op{drag->tool, 0, 0, snap};
  Vec3 d = p - drag->anchor;
  switch (op.tool) {
  case Tool::AxisX:
  case Tool::AxisY:
  case Tool::AxisZ:
    op.a = scalar - drag->startScalar;
    break;
  case Tool::PlaneXY:
    op.a = d.x;
    op.b = d.y;
    break;
  case Tool::PlaneXZ:
    op.a = d.x;
    op.b = d.z;
    break;
  case Tool::PlaneYZ:
    op.a = d.y;
    op.b = d.z;
    break;
  case Tool::RotateZ: {
    Vec3 a = drag->anchor - drag->pivot, b = p - drag->pivot;
    op.a = atan2(a.x * b.y - a.y * b.x, dot(a, b));
    break;
  }
  case Tool::Scale:
    op.a = scalar / drag->startScalar;
    break;
  default:
    return false;
  }
  return preview(op);
}
bool Session::commit() {
  if (!drag || dragView != activeView)
    return false;
  Gesture g = *drag;
  auto o = object(g.id);
  if (!o) {
    cancel();
    return false;
  }
  bool change = length(g.preview.position - g.before.position) > 1e-8 ||
                fabs(g.preview.angle - g.before.angle) > 1e-8 ||
                fabs(g.preview.scale - g.before.scale) > 1e-8;
  Document before = doc;
  drag.reset();
  v().route = Route::None;
  rev.preview++;
  if (!change)
    return false;
  o->transform = g.preview;
  if (o->parent) {
    auto parent = *worldTransform(o->parent, false);
    o->transform = {inversePoint(g.preview.position, parent), g.preview.angle-parent.angle, g.preview.scale/parent.scale};
  }
  history(before);
  changed(false);
  return true;
}
void Session::cancel() {
  if (drag) {
    if (transformTool(drag->tool))
      rev.preview++;
    drag.reset();
  }
  for (auto &[id, viewState] : views) viewState.route = Route::None;
}
bool Session::operation(Operation op) {
  if (!usable() || drag)
    return false;
  auto o = object(selected);
  if (!o || !transformTool(op.tool))
    return false;
  auto transform = *worldTransform(o->id);
  dragView = activeView;
  drag = Gesture{op.tool, selected, transform, transform,
                 revision(), {}, transform.position, 0};
  if (!preview(op)) {
    cancel();
    return false;
  }
  return commit();
}
bool Session::undo() {
  if (!usable() || undoStack.empty())
    return false;
  cancel();
  bool geometry = undoStack.back().parameter != doc.parameter;
  redoStack.push_back(doc);
  doc = undoStack.back();
  undoStack.pop_back();
  if (!object(selected))
    selected = doc.objects.empty() ? 0 : doc.objects[0].id;
  changed(geometry);
  return true;
}
bool Session::redo() {
  if (!usable() || redoStack.empty())
    return false;
  cancel();
  bool geometry = redoStack.back().parameter != doc.parameter;
  undoStack.push_back(doc);
  doc = redoStack.back();
  redoStack.pop_back();
  if (!object(selected))
    selected = doc.objects.empty() ? 0 : doc.objects[0].id;
  changed(geometry);
  return true;
}
Route Session::pointerDown(Tool t, double x, double y) {
  captureLost();
  if (!usable() || !std::isfinite(x) || !std::isfinite(y) || x < v().viewport.x ||
      x > v().viewport.x + v().viewport.width || y < v().viewport.y || y > v().viewport.y + v().viewport.height)
    return Route::None;
  if (drag && dragView != activeView) return Route::Rejected;
  v().pointerX = x;
  v().pointerY = y;
  if (t == Tool::Orbit || t == Tool::Pan) {
    v().route = Route::Navigation;
    dragView = activeView;
  drag = Gesture{t, 0, {}, {}, revision(), {}, {}, 0};
    return v().route;
  }
  if (transformTool(t) && hitHandle(t, x, y)) {
    v().route = begin(t, x, y) ? Route::Manipulation : Route::Rejected;
    return v().route;
  }
  if (t != Tool::Select && !transformTool(t))
    return Route::Rejected;
  auto ray = unproject(x, y, v().camera, v().viewport);
  auto hit = ray ? pick(*ray, frame().triangles) : Pick{};
  // Far clipping is camera depth, not Euclidean ray distance.
  if (hit.id && project(hit.point, v().camera, v().viewport).state != AnchorState::Visible)
    hit = {};
  select(hit.id);
  v().route = Route::Selection;
  return v().route;
}
bool Session::pointerMove(double x, double y, bool snap) {
  if (!std::isfinite(x) || !std::isfinite(y))
    return false;
  if (v().route == Route::Manipulation)
    return update(x, y, snap);
  if (v().route == Route::Navigation && drag && dragView == activeView) {
    Tool t = drag->tool;
    double dx = x - v().pointerX, dy = y - v().pointerY;
    drag.reset();
    if (t == Tool::Orbit)
      orbit(dx * .008, dy * .008);
    else
      pan(-dx * .008, dy * .008);
    dragView = activeView;
  drag = Gesture{t, 0, {}, {}, revision(), {}, {}, 0};
    v().route = Route::Navigation;
    v().pointerX = x;
    v().pointerY = y;
    return true;
  }
  return false;
}
bool Session::pointerUp() {
  if (v().route == Route::Manipulation)
    return commit();
  captureLost();
  return false;
}
void Session::captureLost() { if (dragView == activeView) cancel(); v().route = Route::None; }
void Session::dispose() {
  captureLost();
  v().lifecycle = State::Disposed;
  v().epoch++;
  for (auto &[id, viewState] : views)
    if (viewState.lifecycle == State::Ready) return;
  rev.generation++;
  status = State::Disposed;
  std::lock_guard lock(mutex);
  pending.reset(); completed.reset();
}
void Session::recreate() {
  if (usable()) return;
  v().lifecycle = State::Ready;
  v().epoch++;
  if (status == State::Ready || status == State::Computing) return;
  rev.generation++;
  status = State::Computing;
  workRevision++;
  queue(0);
}
void Session::fail(State s) {
  if (s != State::Failed && s != State::Unsupported) return;
  dispose();
  v().lifecycle = s;
}

std::vector<ScreenLine> Session::overlays(Tool tool) {
  std::vector<ScreenLine> lines;
  auto line = [&](Vec3 a, Vec3 b, Vec3 color, bool handle) {
    auto p = project(a, v().camera, v().viewport), q = project(b, v().camera, v().viewport);
    if (p.state == AnchorState::Visible && q.state == AnchorState::Visible)
      lines.push_back({p.x, p.y, q.x, q.y, color, handle});
  };
  // Decorative world floor; screen overlay, no depth claim.
  for (int i = -4; i <= 4; i++) {
    line({double(i), -1.2, -4}, {double(i), -1.2, 4}, {.16, .22, .28}, false);
    line({-4, -1.2, double(i)}, {4, -1.2, double(i)}, {.16, .22, .28}, false);
  }
  if (auto m = measurement()) {
    line(m->a, m->b, {.3,1,1}, false);
    for (auto p : {m->a,m->b}) {
      line(p-Vec3{.08,0,0},p+Vec3{.08,0,0},{.3,1,1},false);
      line(p-Vec3{0,.08,0},p+Vec3{0,.08,0},{.3,1,1},false);
    }
  }
  if (doc.clip.enabled) {
    auto n = doc.clip.normal;
    auto a = unit(cross(n, fabs(n.y) < .9 ? Vec3{0,1,0} : Vec3{1,0,0}))*2.5;
    auto b = unit(cross(n,a))*2.5, center = n*doc.clip.offset;
    std::array<Vec3,4> points{center+a+b, center-a+b, center-a-b, center+a-b};
    for (int i=0;i<4;++i) line(points[i], points[(i+1)%4], {.9,.45,1}, false);
  }
  auto o = object(selected);
  if (!o) return lines;
  Transform t = *worldTransform(selected);
  Vec3 p = t.position;
  // Fixed conservative object bounds, independent of tessellation. Outlines
  // and handles are explicitly always-on-top overlays, clipped to viewport.
  Vec3 corners[8];
  for (int i = 0; i < 8; i++)
    corners[i] = world({(i & 1) ? 1.13 : -1.13, (i & 2) ? 1.13 : -1.13,
                        (i & 4) ? 1.13 : -1.13},
                       t);
  for (int i = 0; i < 8; i++)
    for (int bit = 1; bit <= 4; bit *= 2)
      if (!(i & bit))
        line(corners[i], corners[i | bit], {1, .74, .25}, false);
  if (tool >= Tool::AxisX && tool <= Tool::AxisZ) {
    Vec3 d = axis(tool);
    line(p, p + d * 1.2,
         tool == Tool::AxisX   ? Vec3{1, .3, .2}
         : tool == Tool::AxisY ? Vec3{.3, 1, .4}
                               : Vec3{.3, .65, 1},
         true);
  } else if (tool >= Tool::PlaneXY && tool <= Tool::PlaneYZ) {
    Vec3 a = tool == Tool::PlaneYZ ? Vec3{0, 1, 0} : Vec3{1, 0, 0},
         b = tool == Tool::PlaneXY ? Vec3{0, 1, 0} : Vec3{0, 0, 1};
    Vec3 q[4] = {p + a * .2 + b * .2, p + a * .7 + b * .2, p + a * .7 + b * .7,
                 p + a * .2 + b * .7};
    for (int i = 0; i < 4; i++)
      line(q[i], q[(i + 1) % 4], {.4, 1, .8}, true);
  } else if (tool == Tool::RotateZ) {
    for (int i = 0; i < 48; i++) {
      double a = 2 * pi * i / 48, b = 2 * pi * (i + 1) / 48;
      line(p + Vec3{cos(a), sin(a), 0}, p + Vec3{cos(b), sin(b), 0},
           {.85, .5, 1}, true);
    }
  } else if (tool == Tool::Scale) {
    line(p, p + Vec3{.9, .9, 0}, {1, .8, .3}, true);
  }
  return lines;
}
bool Session::hitHandle(Tool tool, double x, double y) {
  if (!std::isfinite(x) || !std::isfinite(y))
    return false;
  for (auto l : overlays(tool))
    if (l.handle) {
      double dx = l.x2 - l.x1, dy = l.y2 - l.y1, n = dx * dx + dy * dy;
      double t =
          n > epsilon
              ? std::clamp(((x - l.x1) * dx + (y - l.y1) * dy) / n, 0., 1.)
              : 0.;
      if (std::hypot(x - l.x1 - t * dx, y - l.y1 - t * dy) <= 8)
        return true;
    }
  return false;
}

Projected Session::annotation(Vec3 point, AnchorPolicy policy) {
  auto p = project(point, v().camera, v().viewport);
  if (p.state != AnchorState::Visible || policy == AnchorPolicy::AlwaysVisible)
    return p;
  if (doc.clip.enabled && dot(doc.clip.normal, point) < doc.clip.offset) { p.state = AnchorState::Occluded; return p; }
  auto ray = unproject(p.x, p.y, v().camera, v().viewport);
  auto hit = pick(*ray, frame().triangles);
  double distance = length(point - ray->origin);
  if (hit.id && hit.distance < distance - 1e-4)
    p.state = AnchorState::Occluded;
  return p;
}
} // namespace moxi::spatial
