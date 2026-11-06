#pragma once
// Portable bounded spatial contract; no AppKit, Metal, or application loop.
#include <array>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <map>
#include <optional>
#include <thread>
#include <vector>
namespace moxi::spatial {
constexpr double pi = 3.14159265358979323846, epsilon = 1e-9;
constexpr size_t maxObjects = 16, maxVertices = 100000, maxHistory = 64;
struct Vec3 {
  double x = 0, y = 0, z = 0;
  bool operator==(const Vec3 &) const = default;
};
Vec3 operator+(Vec3, Vec3);
Vec3 operator-(Vec3, Vec3);
Vec3 operator*(Vec3, double);
double dot(Vec3, Vec3);
Vec3 cross(Vec3, Vec3);
double length(Vec3);
Vec3 unit(Vec3);
bool finite(Vec3);
struct Ray {
  Vec3 origin, direction;
};
struct Transform {
  Vec3 position;
  double angle = 0, scale = 1;
  bool operator==(const Transform &) const = default;
};
Vec3 world(Vec3, const Transform &);
bool valid(const Transform &);
enum class Projection : int { Perspective, Orthographic };
enum class Tool : int {
  Select,
  Orbit,
  Pan,
  AxisX,
  AxisY,
  AxisZ,
  PlaneXY,
  PlaneXZ,
  PlaneYZ,
  RotateZ,
  Scale
};
enum class State : int { Ready, Computing, Disposed, Unsupported, Failed };
enum class AnchorPolicy : int { HideOccluded, AlwaysVisible };
enum class AnchorState : int { Visible, Occluded, Offscreen, BehindCamera };
enum class Route : int { None, Selection, Navigation, Manipulation, Rejected };
struct Camera {
  Projection projection = Projection::Perspective;
  double yaw = .38, pitch = .24, distance = 7;
  Vec3 target;
  bool operator==(const Camera &) const = default;
};
struct Viewport {
  double x = 0, y = 0, width = 640, height = 440, scale = 1;
  bool operator==(const Viewport &) const = default;
};
struct Projected {
  double x = 0, y = 0, depth = 0;
  AnchorState state = AnchorState::Offscreen;
};
struct Revision {
  uint64_t document = 1, geometry = 1, camera = 1, viewport = 1, generation = 1,
           preview = 1, view = 1, lifecycle = 1;
  bool operator==(const Revision &) const = default;
};
struct Object {
  uint64_t id;
  Transform transform;
  Vec3 color;
  uint64_t parent = 0; // zero is world; stable application IDs, independent of order
  bool operator==(const Object &) const = default;
};
struct ClipPlane {
  bool enabled = false;
  Vec3 normal{1, 0, 0};
  double offset = 0; // retained half-space: dot(normal, worldPoint) >= offset
  bool operator==(const ClipPlane &) const = default;
};
struct Probe { uint64_t object = 0; Vec3 local; };
struct Measurement { Vec3 a, b; double distance = 0; };
struct Document {
  double parameter = .18;
  std::vector<Object> objects;
  ClipPlane clip;
  bool operator==(const Document &) const = default;
};
struct Vertex {
  float position[4], color[4];
};
struct Triangle {
  Vec3 a, b, c;
  uint64_t id;
};
struct Mesh {
  std::vector<Vec3> vertices;
  double parameter = 0;
};
struct Frame {
  Revision revision;
  Camera camera;
  Viewport viewport;
  std::vector<Triangle> triangles;
  std::vector<Vertex> vertices;
  std::array<float, 16> matrix;
};
struct ScreenLine {
  double x1, y1, x2, y2;
  Vec3 color;
  bool handle = false;
};
struct Pick {
  uint64_t id = 0;
  double distance = 0;
  Vec3 point;
};
struct Operation {
  Tool tool = Tool::AxisX;
  double a = 0, b = 0;
  bool snap = false;
  double grid = .25, angle = pi / 12;
};
struct Gesture {
  Tool tool;
  uint64_t id;
  Transform before, preview;
  Revision start;
  Vec3 anchor, pivot;
  double startScalar = 0;
};
struct Work {
  uint64_t generation, revision;
  double parameter;
  int delayMS;
};
struct WorkResult {
  Work input;
  Mesh mesh;
  bool failed = false;
};
struct Counters {
  uint64_t builds = 0, accepted = 0, rejected = 0, replaced = 0,
           frameBuilds = 0;
};
bool valid(const Camera &);
bool valid(const Viewport &);
Projected project(Vec3, const Camera &, const Viewport &);
std::optional<Ray> unproject(double, double, const Camera &, const Viewport &);
std::array<float, 16> matrix(const Camera &, const Viewport &);
std::optional<double> rayTriangle(Ray, Vec3, Vec3, Vec3);
std::optional<Vec3> rayPlane(Ray, Vec3, Vec3);
std::optional<double> rayAxis(Ray, Vec3, Vec3);
Pick pick(Ray, const std::vector<Triangle> &);
Mesh generate(double parameter);
std::optional<Transform> apply(const Transform &, Operation);
class Session {
public:
  Session();
  ~Session();
  Session(const Session &) = delete;
  Session &operator=(const Session &) = delete;
  const Document &document() const { return doc; }
  const Camera &camera() const { return v().camera; }
  const Viewport &viewport() const { return v().viewport; }
  Revision revision() const;
  uint64_t createView();
  bool activateView(uint64_t);
  void removeView(uint64_t);
  size_t viewCount() const { return views.size(); }
  std::optional<Transform> worldTransform(uint64_t, bool preview = true) const;
  std::optional<Transform> localTransform(uint64_t) const;
  bool clipping(ClipPlane);
  bool probe(double x, double y);
  bool setProbe(int endpoint, uint64_t object, Vec3 local);
  void clearProbes();
  std::optional<Measurement> measurement() const;
  const std::optional<Gesture> &gesture() const { return drag; }
  const Frame &frame();
  State state() const { return v().lifecycle == State::Ready ? status : v().lifecycle; }
  uint64_t selection() const { return selected; }
  double displayedParameter() const { return mesh.parameter; }
  size_t undoCount() const { return undoStack.size(); }
  size_t redoCount() const { return redoStack.size(); }
  Counters counters() const {
    auto c = counts;
    c.builds = buildCount.load();
    return c;
  }
  bool setCamera(Camera);
  bool setViewport(Viewport);
  bool select(uint64_t);
  void selectNext();
  bool setObjects(
      std::vector<Object>); // bounded neutral records, application IDs
  void orbit(double, double);
  void pan(double, double);
  void dolly(double);
  void fit();
  bool parameter(double, int delayMS = 0);
  bool poll();
  bool accept(WorkResult);
  Work currentWork() const {
    return {rev.generation, workRevision, doc.parameter, 0};
  }
  bool begin(Tool, double, double);
  bool update(double, double, bool snap);
  bool preview(Operation);
  bool commit();
  void cancel();
  bool operation(Operation);
  bool undo();
  bool redo();
  Route pointerDown(Tool, double, double);
  bool pointerMove(double, double, bool);
  bool pointerUp();
  void captureLost();
  void dispose();
  void recreate();
  void fail(State);
  Projected annotation(Vec3, AnchorPolicy);
  std::vector<ScreenLine> overlays(Tool);
  bool hitHandle(Tool, double, double);
  bool frameCurrent(Revision r) const {
    return r == revision() && usable();
  }

private:
  Document doc;
  struct ViewState {
    Camera camera;
    Viewport viewport;
    uint64_t cameraRevision = 1, viewportRevision = 1, epoch = 1;
    State lifecycle = State::Ready;
    Route route = Route::None;
    double pointerX = 0, pointerY = 0;
  };
  std::map<uint64_t, ViewState> views{{1, {}}};
  uint64_t activeView = 1, nextView = 2, dragView = 0;
  ViewState &v() { return views.at(activeView); }
  const ViewState &v() const { return views.at(activeView); }
  std::array<std::optional<Probe>, 2> probes;
  int nextProbe = 0;
  Revision rev;
  State status = State::Ready;
  uint64_t selected = 101, workRevision = 1;
  Mesh mesh;
  Frame cached;
  Counters counts;
  std::optional<Gesture> drag;
  std::vector<Document> undoStack, redoStack;
  Object *object(uint64_t);
  const Object *object(uint64_t) const;
  void history(Document);
  void changed(bool geometry);
  void queue(int);
  void worker();
  bool usable() const;
  bool constraint(Tool, Ray, Vec3, Vec3 &, double &) const;
  std::mutex mutex;
  std::condition_variable cv;
  bool stopping = false;
  std::optional<Work> pending;
  std::optional<WorkResult> completed;
  std::thread thread;
  std::atomic<uint64_t> buildCount{0};
};
} // namespace moxi::spatial
