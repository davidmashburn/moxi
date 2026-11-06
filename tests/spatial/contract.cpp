#include <algorithm>

#include "../../native/spatial/core.hpp"
#include <cassert>
#include <chrono>
#include <cmath>
#include <iostream>
#include <limits>
using namespace moxi::spatial;
static int checks = 0;
#define CHECK(x)                                                               \
  do {                                                                         \
    ++checks;                                                                  \
    if (!(x)) {                                                                \
      std::cerr << __LINE__ << ": " << #x << "\n";                             \
      std::abort();                                                            \
    }                                                                          \
  } while (0)
static bool near(double a, double b, double tolerance = 1e-7) {
  return std::abs(a - b) < tolerance;
}
static void ready(Session &s) {
  auto end = std::chrono::steady_clock::now() + std::chrono::seconds(3);
  while (s.state() == State::Computing &&
         std::chrono::steady_clock::now() < end) {
    s.poll();
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  CHECK(s.state() == State::Ready);
}
static void math() {
  Camera c;
  c.yaw = c.pitch = 0;
  c.distance = 5;
  Viewport v{20, 30, 800, 400, 1};
  auto center = project({0, 0, 0}, c, v);
  CHECK(near(center.x, 420) && near(center.y, 230) && near(center.depth, 5));
  auto point = project({1, 1, 0}, c, v);
  CHECK(near(point.x, 516.5685424949, 1e-6) &&
        near(point.y, 133.4314575051, 1e-6));
  auto r = unproject(420, 230, c, v);
  CHECK(r && near(r->origin.z, 4.9) && near(r->direction.z, -1));
  CHECK(project({0, 0, 6}, c, v).state == AnchorState::BehindCamera);
  CHECK(project({100, 0, 0}, c, v).state == AnchorState::Offscreen);
  for (auto projection : {Projection::Perspective, Projection::Orthographic}) {
    c.projection = projection;
    for (Vec3 p : {Vec3{.2, -.3, .6}, Vec3{-1.2, .7, -2}, Vec3{0, 0, 0}}) {
      auto q = project(p, c, v);
      auto ray = unproject(q.x, q.y, c, v);
      CHECK(ray);
      auto hit = rayPlane(*ray, p, {0, 0, 1});
      CHECK(hit && length(*hit - p) < 1e-7);
      auto m = matrix(c, v);
      double in[4] = {p.x, p.y, p.z, 1}, clip[4] = {};
      for (int row = 0; row < 4; row++)
        for (int col = 0; col < 4; col++)
          clip[row] += m[col * 4 + row] * in[col];
      CHECK(near(v.x + (clip[0] / clip[3] + 1) * v.width / 2, q.x, 1e-4));
      CHECK(near(v.y + (1 - clip[1] / clip[3]) * v.height / 2, q.y, 1e-4));
      CHECK(clip[2] / clip[3] >= 0 && clip[2] / clip[3] <= 1);
    }
    auto left = unproject(20, 230, c, v), right = unproject(820, 230, c, v);
    CHECK(left && right);
    if (projection == Projection::Orthographic)
      CHECK(length(left->direction - right->direction) < 1e-10);
    else
      CHECK(length(left->direction - right->direction) > .5);
  }
  c.pitch = 2;
  CHECK(!valid(c));
  c.pitch = 0;
  c.distance = NAN;
  CHECK(!valid(c));
  CHECK(!valid(Viewport{0, 0, 2049, 200, 1}));
  CHECK(!unproject(NAN, 0, Camera{}, v));
  Ray forward{{0, 0, 5}, {0, 0, -1}};
  CHECK(near(*rayTriangle(forward, {-1, -1, 0}, {1, -1, 0}, {0, 1, 0}), 5));
  CHECK(!rayTriangle(forward, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}));
  CHECK(!rayTriangle(forward, {-1, -1, 6}, {1, -1, 6}, {0, 1, 6}));
  CHECK(
      rayTriangle(forward, {-1, -1, 0}, {0, 1, 0}, {1, -1, 0})); // double sided
  CHECK(!rayPlane({{0, 0, 1}, {1, 0, 1e-8}}, {0, 0, 0}, {0, 0, 1}));
  CHECK(!rayAxis({{0, 1, 0}, {1, 0, 0}}, {0, 0, 0}, {1, 0, 0}));
  CHECK(near(*rayAxis({{2, 3, 4}, {0, 0, -1}}, {0, 0, 0}, {1, 0, 0}), 2));
  std::vector<Triangle> overlap = {{{-1, -1, 0}, {1, -1, 0}, {0, 1, 0}, 202},
                                   {{-1, -1, 0}, {1, -1, 0}, {0, 1, 0}, 101},
                                   {{-1, -1, -2}, {1, -1, -2}, {0, 1, -2}, 1}};
  CHECK(pick(forward, overlap).id == 101);
  std::reverse(overlap.begin(), overlap.end());
  CHECK(pick(forward, overlap).id == 101);
  std::vector<Triangle> chain = {
      {{-1, -1, 0}, {1, -1, 0}, {0, 1, 0}, 300},
      {{-1, -1, -.9e-7}, {1, -1, -.9e-7}, {0, 1, -.9e-7}, 200},
      {{-1, -1, -1.8e-7}, {1, -1, -1.8e-7}, {0, 1, -1.8e-7}, 100}};
  for (int direction = 0; direction < 2; direction++) {
    for (int rotation = 0; rotation < 3; rotation++) {
      CHECK(pick(forward, chain).id == 200);
      std::rotate(chain.begin(), chain.begin() + 1, chain.end());
    }
    std::reverse(chain.begin(), chain.end());
  }
  auto g = generate(.18), changed = generate(.6);
  CHECK(g.vertices.size() == 4560 &&
        g.vertices.size() == changed.vertices.size());
  CHECK(g.vertices[30] != changed.vertices[30]);
  CHECK(generate(NAN).vertices.empty());
  for (size_t i = 0; i < g.vertices.size(); i += 3)
    CHECK(length(cross(g.vertices[i + 1] - g.vertices[i],
                       g.vertices[i + 2] - g.vertices[i])) > 1e-7);
  std::cout << "PASS projection/unprojection, Metal matrix, rays, "
               "near-parallel, stable ties, adversarial mesh\n";
}
static void interactions() {
  Session s;
  Camera c;
  c.yaw = c.pitch = 0;
  c.distance = 6;
  CHECK(s.setCamera(c));
  CHECK(s.select(101));
  auto before = s.document().objects[0].transform;
  auto p = project(before.position, c, s.viewport());
  size_t history = s.undoCount();
  CHECK(s.begin(Tool::AxisX, p.x, p.y));
  CHECK(s.update(p.x + 60, p.y, false));
  CHECK(s.document().objects[0].transform == before);
  CHECK(s.gesture()->preview.position.x > before.position.x);
  CHECK(s.commit());
  CHECK(s.undoCount() == history + 1);
  CHECK(s.undo());
  CHECK(s.document().objects[0].transform == before);
  CHECK(s.redo());
  CHECK(s.undo());
  CHECK(s.begin(Tool::PlaneXY, p.x, p.y));
  CHECK(s.preview({Tool::PlaneXY, .63, -.38, true}));
  CHECK(near(s.gesture()->preview.position.x, before.position.x + .75));
  CHECK(near(s.gesture()->preview.position.y, before.position.y - .5));
  s.cancel();
  CHECK(s.document().objects[0].transform == before);
  history = s.undoCount();
  CHECK(s.begin(Tool::AxisX, p.x, p.y));
  CHECK(!s.commit());
  CHECK(s.undoCount() == history);
  CHECK(s.begin(Tool::AxisX, p.x, p.y));
  CHECK(!s.preview({Tool::AxisX, NAN, 0, false}));
  s.captureLost();
  CHECK(!s.gesture());
  CHECK(s.operation({Tool::RotateZ, .31, 0, true}));
  CHECK(near(s.document().objects[0].transform.angle, pi / 12));
  CHECK(s.undo());
  CHECK(s.operation({Tool::Scale, 1.35, 0, false}));
  CHECK(near(s.document().objects[0].transform.scale, 1.35));
  CHECK(s.undo());
  CHECK(!s.operation({Tool::Scale, -1, 0, false}));
  CHECK(!s.operation({Tool::AxisX, 1000, 0, false}));
  CHECK(s.begin(Tool::AxisX, p.x, p.y));
  CHECK(s.preview({Tool::AxisX, 1, 0, false}));
  s.orbit(.2, 0);
  CHECK(!s.gesture());
  CHECK(s.document().objects[0].transform == before);
  c.target = before.position;
  s.setCamera(c);
  p = project(before.position, c, s.viewport());
  CHECK(!s.begin(Tool::AxisZ, p.x,
                 p.y)); // ray nearly parallel tested exactly below
  CHECK(!s.begin(Tool::PlaneXZ, p.x, p.y));
  CHECK(s.pointerDown(Tool::Select, p.x, p.y) == Route::Selection);
  CHECK(s.selection() == 101);
  CHECK(s.pointerDown(Tool::Orbit, p.x, p.y) == Route::Navigation);
  auto uploads = s.counters().frameBuilds;
  s.frame();
  uploads = s.counters().frameBuilds;
  CHECK(s.pointerMove(p.x + 20, p.y + 10, false));
  s.frame();
  s.pointerUp();
  s.frame();
  CHECK(s.counters().frameBuilds == uploads);
  CHECK(s.pointerDown(Tool::AxisX, -10, -10) == Route::None);
  CHECK(s.select(202));
  CHECK(s.selection() == 202);
  CHECK(!s.select(999));
  s.selectNext();
  CHECK(s.selection() == 303);
  CHECK(s.setObjects({{77, {}, {1, 0, 0}}, {44, {}, {0, 1, 0}}}));
  CHECK(s.selection() == 77);
  c.target = {};
  s.setCamera(c);
  auto ray = unproject(320, 220, c, s.viewport());
  CHECK(pick(*ray, s.frame().triangles).id == 44);
  CHECK(!s.setObjects({{77, {}, {1, 0, 0}}, {77, {}, {0, 1, 0}}}));
  auto anno = s.annotation({0, 0, -1}, AnchorPolicy::HideOccluded);
  CHECK(anno.state == AnchorState::Occluded);
  CHECK(s.annotation({0, 0, -1}, AnchorPolicy::AlwaysVisible).state ==
        AnchorState::Visible);
  CHECK(s.setObjects({}));
  CHECK(s.frame().vertices.empty());
  CHECK(s.selection() == 0);
  CHECK(!s.begin(Tool::AxisX, 320, 220));
  CHECK(s.undo());
  for (int i = 0; i < 80; i++) {
    CHECK(s.operation({Tool::RotateZ, .01, 0, false}));
  }
  CHECK(s.undoCount() == 64);
  std::cout
      << "PASS gesture previews, constraints, snap, one commit, numeric/key "
         "operations, cancel, history, routing, annotations\n";
}
static void replayContracts() {
  Session s;
  CHECK(s.setObjects({{700, {}, {1, .5, .2}}}));
  Camera c;
  c.yaw = c.pitch = 0;
  c.distance = 6;
  c.projection = Projection::Orthographic;
  CHECK(s.setCamera(c));
  auto screen = [&](Vec3 p) { return project(p, s.camera(), s.viewport()); };
  // Independent world-space targets exercise the inverse constraints, not
  // expected screen deltas computed by the implementation under test.
  auto a = screen({1, 0, 0}), b = screen({0, 1, 0});
  auto history = s.undoCount();
  CHECK(s.begin(Tool::RotateZ, a.x, a.y));
  CHECK(s.update(b.x, b.y, false));
  CHECK(near(s.gesture()->preview.angle, pi / 2));
  CHECK(s.commit());
  CHECK(s.undoCount() == history + 1);
  CHECK(s.undo());
  b = screen({1.5, 0, 0});
  CHECK(s.begin(Tool::Scale, a.x, a.y));
  CHECK(s.update(b.x, b.y, false));
  CHECK(near(s.gesture()->preview.scale, 1.5));
  CHECK(s.commit());
  CHECK(s.undo());
  c.yaw = .6;
  c.pitch = .4;
  CHECK(s.setCamera(c));
  for (auto tool : {Tool::AxisX, Tool::AxisY, Tool::AxisZ, Tool::PlaneXY,
                    Tool::PlaneXZ, Tool::PlaneYZ}) {
    Vec3 target = tool == Tool::AxisX     ? Vec3{.5, 0, 0}
                  : tool == Tool::AxisY   ? Vec3{0, .5, 0}
                  : tool == Tool::AxisZ   ? Vec3{0, 0, .5}
                  : tool == Tool::PlaneXY ? Vec3{.5, -.25, 0}
                  : tool == Tool::PlaneXZ ? Vec3{.5, 0, -.25}
                                          : Vec3{0, .5, -.25};
    auto origin = screen({0, 0, 0}), end = screen(target);
    CHECK(s.begin(tool, origin.x, origin.y));
    CHECK(s.update(end.x, end.y, false));
    CHECK(length(s.gesture()->preview.position - target) < 1e-7);
    s.cancel();
    CHECK(s.document().objects[0].transform == Transform{});
  }
  // Handles win over coincident scene geometry; away from a handle, a
  // transform tool selects the object without starting a drag.
  auto lines = s.overlays(Tool::AxisX);
  auto handle =
      std::find_if(lines.begin(), lines.end(), [](auto l) { return l.handle; });
  CHECK(handle != lines.end());
  CHECK(s.pointerDown(Tool::AxisX, (handle->x1 + handle->x2) / 2,
                      (handle->y1 + handle->y2) / 2) == Route::Manipulation);
  CHECK(s.pointerMove((handle->x1 + handle->x2) / 2 + 20,
                      (handle->y1 + handle->y2) / 2, false));
  s.captureLost();
  CHECK(!s.pointerUp());
  CHECK(s.document().objects[0].transform == Transform{});
  auto origin = screen({0, 0, 0});
  CHECK(s.begin(Tool::AxisX, origin.x, origin.y));
  CHECK(s.preview({Tool::AxisX, 1}));
  auto viewport = s.viewport();
  viewport.scale = 2;
  CHECK(s.setViewport(viewport));
  CHECK(!s.gesture());
  CHECK(s.begin(Tool::AxisX, origin.x, origin.y));
  CHECK(s.preview({Tool::AxisX, 1}));
  s.dispose();
  CHECK(!s.gesture());
  CHECK(s.document().objects[0].transform == Transform{});
  s.recreate();
  ready(s);
  CHECK(s.parameter(.5, 150));
  CHECK(s.begin(Tool::AxisX, origin.x, origin.y));
  CHECK(s.preview({Tool::AxisX, 1}));
  CHECK(s.accept({s.currentWork(), generate(.5), false}));
  CHECK(!s.gesture());
  CHECK(!s.commit());
  // A replacement mesh invalidates the drag's geometry agreement, but a
  // camera-only frame retains the exact vertex allocation and pick triangles.
  auto vertices = s.frame().vertices.data();
  auto triangles = s.frame().triangles.data();
  auto frozen = s.frame().revision;
  auto count = s.counters().frameBuilds;
  s.orbit(.1, 0);
  CHECK(!s.frameCurrent(frozen));
  CHECK(s.frame().vertices.data() == vertices);
  CHECK(s.frame().triangles.data() == triangles);
  CHECK(s.counters().frameBuilds == count);
  CHECK(s.frame().camera == s.camera() && s.frame().viewport == s.viewport());
  c.yaw = c.pitch = 0;
  CHECK(s.setCamera(c));
  CHECK(s.annotation({100, 0, 0}, AnchorPolicy::AlwaysVisible).state ==
        AnchorState::Offscreen);
  auto nochange = s.undoCount();
  CHECK(!s.operation({Tool::AxisX, 0}));
  CHECK(s.undoCount() == nochange);
  CHECK(s.select(0));
  s.selectNext();
  CHECK(s.selection() == 700);
  std::cout << "PASS deterministic constraint replay, pointer rotation/scale, "
               "handle precedence, frozen frame, cancellation on "
               "viewport/geometry/disposal\n";
}
static void clipping() {
  Session s;
  Camera c;
  c.yaw = c.pitch = 0;
  c.distance = 60;
  c.target = {0, 0, 30};
  CHECK(s.setCamera(c));
  CHECK(s.setObjects({{555, {{17, 0, -9.8}, 0, 1}, {1, 0, 0}}}));
  auto p = project({17, 0, -9.8}, c, s.viewport());
  CHECK(p.state == AnchorState::Visible);
  auto ray = unproject(p.x, p.y, c, s.viewport());
  auto hit = pick(*ray, s.frame().triangles);
  CHECK(hit.id == 555 && hit.distance > 100); // distance != camera-depth clip
  CHECK(s.pointerDown(Tool::Select, p.x, p.y) == Route::Selection);
  CHECK(s.selection() == 555);
  CHECK(s.setObjects({{666, {{0, 0, -15}, 0, 1}, {1, 0, 0}}}));
  CHECK(s.pointerDown(Tool::Select, 320, 220) == Route::Selection);
  CHECK(s.selection() == 0);
  CHECK(s.pointerDown(Tool::Orbit, NAN, 220) == Route::None);
  CHECK(!s.gesture());
  std::cout
      << "PASS far-plane projection/pick agreement and nonfinite routing\n";
}
static void work() {
  Session s;
  auto work = s.currentWork();
  auto original = s.revision();
  CHECK(s.parameter(.4, 150));
  CHECK(!s.accept({work, generate(.18), false}));
  CHECK(s.counters().rejected == 1);
  auto latest = s.currentWork();
  CHECK(s.accept({latest, generate(.4), false}));
  CHECK(s.state() == State::Ready);
  CHECK(s.revision().geometry == original.geometry + 1);
  CHECK(!s.frameCurrent(original));
  auto frame = s.frame().revision;
  CHECK(s.frameCurrent(frame));
  s.orbit(.1, .1);
  CHECK(!s.frameCurrent(frame));
  CHECK(s.parameter(.2, 100));
  CHECK(s.parameter(.3, 100));
  CHECK(s.parameter(.5, 100));
  ready(s);
  CHECK(s.document().parameter == .5);
  CHECK(s.undo());
  ready(s);
  CHECK(s.document().parameter == .3);
  CHECK(s.redo());
  ready(s);
  CHECK(s.document().parameter == .5);
  work = s.currentWork();
  s.dispose();
  CHECK(s.state() == State::Disposed);
  CHECK(!s.accept({work, generate(.5), false}));
  CHECK(!s.parameter(.4));
  s.recreate();
  ready(s);
  CHECK(s.revision().generation > work.generation);
  s.fail(State::Unsupported);
  CHECK(s.state() == State::Unsupported);
  s.recreate();
  ready(s);
  CHECK(!s.parameter(INFINITY));
  CHECK(!s.parameter(.7));
  CHECK(!s.parameter(.4, 2001));
  // Old generation completion cannot resurrect a disposed/recreated document.
  auto dead = s.currentWork();
  s.dispose();
  s.recreate();
  CHECK(!s.accept({dead, generate(dead.parameter), false}));
  ready(s);
  std::cout << "PASS bounded work, stale generation/revision, shared parameter "
               "undo, disposal/recreation\n";
}
int main() {
  math();
  interactions();
  replayContracts();
  clipping();
  work();
  std::cout << "PASS spatial-contract + spatial-interaction: " << checks
            << " assertions\n";
}
