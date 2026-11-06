#include "../../native/spatial/core.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
using namespace moxi::spatial;
static int checks;
#define CHECK(x) do { ++checks; if (!(x)) { fprintf(stderr,"line %d: %s\n",__LINE__,#x); abort(); } } while(0)
static bool near(double a,double b) { return fabs(a-b)<1e-7; }
static std::vector<Object> fixture() {
  // Deliberately child-before-parent, nonconsecutive IDs.
  return {{72,{{1,0,0},0,.5},{.2,.7,1},10},
          {10,{{0,0,0},pi/2,1.5},{1,.3,.1}},
          {405,{{0,1,0},0,.5},{.3,1,.4},72}};
}
int main() {
  Session s;
  CHECK(s.setObjects(fixture()));
  CHECK(s.worldTransform(72)->position == (Vec3{world({1,0,0},s.document().objects[1].transform)}));
  CHECK(near(s.worldTransform(405)->position.x,-.75));
  CHECK(near(s.worldTransform(405)->position.y,1.5));
  CHECK(near(s.worldTransform(405)->scale,.375));
  auto baseline=s.document(); auto rev=s.revision();
  for (int mode=0;mode<7;++mode) {
    auto bad=fixture();
    switch(mode) {
      case 0:bad[0].parent=999;break;
      case 1:bad[1].parent=405;break;
      case 2:bad[0].parent=72;break;
      case 3:bad[0].id=10;break;
      case 4:bad[0].id=0;break;
      case 5:bad[0].transform.scale=5;break; // composed scale > 5
      case 6:bad[0].transform.position.x=NAN;break;
    }
    CHECK(!s.setObjects(bad)); CHECK(s.document()==baseline); CHECK(s.revision()==rev);
  }
  auto ids=fixture(); std::reverse(ids.begin(),ids.end());
  CHECK(s.setObjects(ids)); CHECK(s.select(405)); CHECK(s.selection()==405);
  auto child=*s.worldTransform(405);
  CHECK(s.select(10)); CHECK(s.operation({Tool::AxisX,.5}));
  CHECK(near(s.worldTransform(405)->position.x,child.position.x+.5));
  CHECK(s.undo()); CHECK(near(s.worldTransform(405)->position.x,child.position.x));
  CHECK(s.redo()); CHECK(s.undo());
  CHECK(s.select(72)); CHECK(s.operation({Tool::AxisX,.3}));
  CHECK(near(s.localTransform(72)->position.y,-.2));
  CHECK(s.undo());
  auto second=s.createView(); CHECK(second);
  auto vertices=s.frame().vertices.data(); auto triangles=s.frame().triangles.data();
  auto builds=s.counters().frameBuilds; auto geom=s.counters().builds;
  CHECK(s.activateView(second));
  Camera orthographic{Projection::Orthographic,0,0,7,{}};
  CHECK(s.setCamera(orthographic)); CHECK(s.setViewport({700,30,400,300,1}));
  CHECK(s.frame().vertices.data()==vertices); CHECK(s.frame().triangles.data()==triangles);
  CHECK(s.counters().frameBuilds==builds); CHECK(s.counters().builds==geom);
  auto secondRevision=s.revision();
  auto secondFrame=s.frame().revision;
  CHECK(s.activateView(1)); s.orbit(.2,.1); CHECK(s.camera().projection==Projection::Perspective);
  CHECK(!s.frameCurrent(secondFrame));
  CHECK(s.frame().vertices.data()==vertices); CHECK(s.activateView(second));
  CHECK(s.camera()==orthographic); CHECK(s.revision()==secondRevision);
  CHECK(s.select(10)); auto pivot=*s.worldTransform(10);
  auto p=project(pivot.position+Vec3{.6,0,0},s.camera(),s.viewport());
  auto history=s.undoCount();
  CHECK(s.pointerDown(Tool::AxisX,p.x,p.y)==Route::Manipulation);
  CHECK(s.pointerMove(p.x+25,p.y,false)); auto preview=*s.worldTransform(405);
  CHECK(s.undoCount()==history); CHECK(s.activateView(1));
  s.orbit(.01,0); CHECK(s.gesture().has_value());
  CHECK(s.worldTransform(405)==preview); CHECK(!s.pointerMove(p.x+40,p.y,false)); CHECK(!s.pointerUp());
  CHECK(s.pointerDown(Tool::Orbit,320,200)==Route::Rejected);
  CHECK(s.gesture().has_value());
  CHECK(s.activateView(second)); CHECK(s.pointerUp()); CHECK(s.undoCount()==history+1);
  CHECK(s.activateView(1)); CHECK(s.undo());
  CHECK(s.activateView(second));
  CHECK(s.pointerDown(Tool::AxisX,p.x,p.y)==Route::Manipulation);
  CHECK(s.pointerMove(p.x+25,p.y,true)); s.captureLost(); CHECK(!s.pointerUp()); CHECK(s.undoCount()==history);
  CHECK(s.setProbe(0,10,{0,0,0})); CHECK(s.setProbe(1,72,{0,0,0})); CHECK(near(s.measurement()->distance,1.5));
  CHECK(s.select(10)); CHECK(s.operation({Tool::AxisX,.75})); CHECK(near(s.measurement()->distance,1.5));
  CHECK(s.select(72)); CHECK(s.operation({Tool::AxisY,.25})); CHECK(near(s.measurement()->distance,1.75));
  CHECK(!s.setProbe(2,10,{})); CHECK(!s.setProbe(0,999,{})); CHECK(!s.setProbe(0,10,{NAN,0,0}));
  CHECK(s.undo()); CHECK(s.undo());
  // Known axial ray intersects unclipped surface; clipping uses the very same triangles.
  CHECK(s.setObjects({{1,{}, {1,.3,.2}}})); CHECK(!s.measurement());
  CHECK(s.setCamera(orthographic)); CHECK(s.setViewport({0,0,600,400,1}));
  CHECK(s.probe(300,200)); CHECK(s.probe(320,200)); CHECK(s.measurement()->distance>0);
  CHECK(s.clipping({true,{0,0,-2},0}));
  auto clippedBuilds=s.counters().frameBuilds;
  for (const auto &t:s.frame().triangles)
    for (auto vertex:{t.a,t.b,t.c}) CHECK(vertex.z<=1e-8);
  CHECK(s.counters().frameBuilds==clippedBuilds+1);
  auto ray=*unproject(300,200,s.camera(),s.viewport()); auto hit=pick(ray,s.frame().triangles);
  CHECK(hit.id==1); CHECK(hit.point.z<=0); // no artificial clipping cap
  CHECK(s.probe(300,200)); CHECK(!s.probe(-1,200));
  auto clipBefore=s.document();
  CHECK(!s.clipping({true,{0,0,0},0})); CHECK(!s.clipping({true,{NAN,0,0},0})); CHECK(!s.clipping({true,{1,0,0},INFINITY}));
  CHECK(s.document()==clipBefore); CHECK(s.undo()); CHECK(!s.document().clip.enabled); CHECK(s.redo());
  CHECK(s.clipping({true,{0,0,1},40})); CHECK(s.frame().vertices.empty()); CHECK(!s.probe(300,200));
  CHECK(s.undo()); CHECK(!s.frame().vertices.empty());
  // The conservative two-triangle clipping budget is checked before mutation.
  auto saved = s.document();
  std::vector<Object> crowded;
  for (uint64_t id = 1; id <= maxObjects; ++id)
    crowded.push_back({id, {}, {1,.3,.2}});
  CHECK(!s.setObjects(crowded)); CHECK(s.document() == saved);
  CHECK(s.clipping({false,{1,0,0},0}));
  CHECK(s.setObjects(crowded)); CHECK(s.frame().vertices.size() <= maxVertices);
  auto crowdedRevision = s.revision();
  CHECK(!s.clipping({true,{1,0,0},0})); CHECK(s.revision() == crowdedRevision);
  crowded.push_back({maxObjects+1, {}, {1,.3,.2}});
  CHECK(!s.setObjects(crowded)); CHECK(s.revision() == crowdedRevision);
  CHECK(s.setObjects({{1,{}, {1,.3,.2}}}));
  CHECK(!s.setProbe(0,1,{2.01,0,0}));
  // Stale work rejected across linked views, even when originating view is disposed.
  CHECK(s.parameter(.3,100)); auto stale=s.currentWork();
  CHECK(s.activateView(1)); CHECK(s.parameter(.4,100)); auto latest=s.currentWork();
  CHECK(!s.accept({stale,generate(stale.parameter),false}));
  auto beforeGeneration=s.revision().generation; s.dispose(); CHECK(s.state()==State::Disposed);
  CHECK(s.activateView(second)); CHECK(s.state()==State::Computing); CHECK(s.revision().generation==beforeGeneration);
  CHECK(s.accept({latest,generate(latest.parameter),false})); CHECK(s.state()==State::Ready); CHECK(!s.measurement());
  auto accepted=s.counters().accepted;
  CHECK(s.activateView(1)); s.recreate(); CHECK(s.state()==State::Ready); CHECK(s.counters().accepted==accepted);
  s.removeView(1); CHECK(s.activateView(second)); CHECK(s.viewCount()==1); CHECK(s.frame().vertices.size()>0);
  for (int i=0;i<15;++i) CHECK(s.createView()); CHECK(!s.createView()); CHECK(!s.activateView(999));
  CHECK(s.select(1));
  for (int i=0;i<80;++i) CHECK(s.operation({Tool::RotateZ,.01})); CHECK(s.undoCount()==maxHistory);
  printf("PASS assembly hierarchy/shared views/probes/clipping/lifecycle: %d assertions\n",checks);
}
