#include "../../native/spatial/panel.hpp"
#include <cassert>
#include <cstdio>
using namespace moxi::spatial;
int main() {
  Session session;
  assert(session.setObjects({}));
  Camera camera; camera.yaw=0; camera.pitch=0; camera.distance=6;
  assert(session.setCamera(camera));
  auto f=session.frame();
  Panel panel;
  assert(panel.configure({}));
  auto p=project(panel.point(100,100),f.camera,f.viewport);
  assert(panel.route(PanelPhase::Down,p.x,p.y,f,{}).result==PanelResult::Hit);
  auto outside=project(panel.point(500,100),f.camera,f.viewport);
  auto hit=panel.route(PanelPhase::Move,outside.x,outside.y,f,{});
  assert(hit.result==PanelResult::Hit && std::abs(hit.x-500)<1e-6 && panel.captured);
  assert(panel.route(PanelPhase::Up,outside.x,outside.y,f,{}).result==PanelResult::Hit);
  assert(!panel.captured);
  assert(panel.route(PanelPhase::Probe,outside.x,outside.y,f,{}).result==PanelResult::Outside);
  assert(panel.route(PanelPhase::Down,p.x,p.y,f,{}).result==PanelResult::Hit);
  auto stale=f; stale.revision.lifecycle++;
  assert(panel.route(PanelPhase::Move,p.x,p.y,stale,{}).result==PanelResult::Stale);
  assert(!panel.captured);
  panel.cancel(); assert(panel.route(PanelPhase::Move,p.x,p.y,f,{}).result==PanelResult::Idle);
  assert(panel.mapRay({{0,0,1},{1,0,0}},f,{},false).result==PanelResult::Invalid);
  assert(panel.mapRay({{0,0,1},{0,0,0}},f,{},false).result==PanelResult::Invalid);
  assert(panel.mapRay({{0,0,1},{0,0,-2}},f,{},false).result==PanelResult::Invalid);
  assert(panel.mapRay({{NAN,0,1},{0,0,-1}},f,{},false).result==PanelResult::Invalid);
  auto invalid=panel.pose; invalid.down=invalid.right;
  assert(!panel.configure(invalid));
  invalid=panel.pose; invalid.width=NAN; assert(!panel.configure(invalid));
  invalid=panel.pose; invalid.height=20.5; assert(!panel.configure(invalid));
  invalid=panel.pose; invalid.origin.z=5.95; assert(panel.configure(invalid));
  assert(panel.vertices(f,{}).empty());
  assert(panel.route(PanelPhase::Probe,p.x,p.y,f,{}).result==PanelResult::Hidden);
  invalid.origin.z=7; assert(panel.configure(invalid)); assert(panel.vertices(f,{}).empty());
  assert(panel.configure({}));
  ClipPlane clip{true,{1,0,0},0};
  assert(panel.route(PanelPhase::Down,p.x,p.y,f,clip).result==PanelResult::Hidden);
  auto vertices=panel.vertices(f,clip); assert(vertices.size()==6);
  for(auto v:vertices) assert(v.position[0]>=0 && v.color[0]>=.5);
  auto obstruction=f;
  obstruction.triangles={{{-2,-2,1},{2,-2,1},{0,2,1},7}};
  auto center=project({0,0,0},camera,f.viewport);
  assert(panel.route(PanelPhase::Down,center.x,center.y,obstruction,{}).result==PanelResult::Hidden);
  assert(!panel.captured);
  assert(panel.route(PanelPhase::Down,p.x,p.y,f,{}).result==PanelResult::Hit);
  assert(panel.route(PanelPhase::Move,center.x,center.y,obstruction,{}).result==PanelResult::Hidden);
  assert(!panel.captured);
  assert(panel.route(PanelPhase::Up,p.x,p.y,f,{}).result==PanelResult::Idle);
  obstruction.triangles={{{-2,-2,0},{2,-2,0},{0,2,0},7}};
  assert(panel.route(PanelPhase::Probe,center.x,center.y,obstruction,{}).result==PanelResult::Hidden);
  for(double scale : {.5,1.,2.}) {
    auto scaled=f; scaled.viewport.scale=scale;
    auto h=panel.route(PanelPhase::Probe,p.x,p.y,scaled,{});
    assert(h.result==PanelResult::Hit && std::abs(h.x-100)<1e-6);
  }
  puts("PASS D08 portable plane: perspective, capture, cancel, stale lifecycle, parallel/degenerate/nonfinite, near/behind, clip/occlusion, scale");
}
