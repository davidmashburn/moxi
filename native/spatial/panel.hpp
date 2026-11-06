#pragma once
#include "core.hpp"
#include <cmath>
namespace moxi::spatial {
// D08 only: one rectangular affine plane per view, one pointer, no curved UI.
enum class PanelPhase : int { Probe, Down, Move, Up, Cancel };
enum class PanelResult : int { Hit, Outside, Hidden, Invalid, Stale, Idle };
struct PanelPose {
  Vec3 origin{-2, 1.2, 0}, right{4, 0, 0}, down{0, -2.4, 0};
  double width = 400, height = 240;
};
inline bool valid(const PanelPose &p) {
  return finite(p.origin) && finite(p.right) && finite(p.down) &&
    length(p.origin) <= 30 && length(p.right) >= .01 && length(p.right) <= 20 &&
    length(p.down) >= .01 && length(p.down) <= 20 &&
    dot(cross(p.right,p.down),cross(p.right,p.down)) > epsilon &&
    std::isfinite(p.width) && std::isfinite(p.height) &&
    std::floor(p.width)==p.width && std::floor(p.height)==p.height && p.width >= 1 && p.height >= 1 && p.width <= 1024 && p.height <= 1024;
}
struct PanelHit { PanelResult result = PanelResult::Invalid; double x = NAN, y = NAN; };
class Panel {
public:
  PanelPose pose;
  bool captured = false, configured = false;
  Revision start;
  PanelHit last;
  bool configure(PanelPose p) {
    if (!valid(p)) return false;
    pose = p; configured = true; cancel(); return true;
  }
  void cancel() { captured = false; last = {PanelResult::Idle}; }
  Vec3 point(double x,double y) const {
    return pose.origin + pose.right*(x/pose.width) + pose.down*(y/pose.height);
  }
  // Reject a plane crossing near/far or camera plane as a whole. GPU clipping
  // and hit testing therefore never disagree about a partially usable editor.
  bool visibleDepth(const Frame &f) const {
    if (!configured) return false;
    for (auto uv : {std::pair{0.,0.}, {1.,0.}, {0.,1.}, {1.,1.}}) {
      auto q = project(point(uv.first*pose.width,uv.second*pose.height),f.camera,f.viewport);
      if (!std::isfinite(q.depth) || q.depth <= .1 || q.depth >= 100) return false;
    }
    return true;
  }
  PanelHit mapRay(Ray ray,const Frame &f,ClipPlane clip,bool outside) const {
    if (!configured || !valid(pose) || !finite(ray.origin) || !finite(ray.direction) || std::abs(length(ray.direction)-1)>epsilon) return {};
    if (!visibleDepth(f)) return {PanelResult::Hidden};
    auto hit = rayPlane(ray,pose.origin,cross(pose.right,pose.down));
    if (!hit) return {};
    auto delta = *hit-pose.origin;
    double a=dot(pose.right,pose.right), b=dot(pose.right,pose.down), c=dot(pose.down,pose.down);
    double det=a*c-b*b;
    if (det<=epsilon) return {};
    double u=(dot(delta,pose.right)*c-dot(delta,pose.down)*b)/det;
    double v=(dot(delta,pose.down)*a-dot(delta,pose.right)*b)/det;
    auto q=project(*hit,f.camera,f.viewport);
    if (q.depth<=.1 || q.depth>=100 || !std::isfinite(u) || !std::isfinite(v)) return {PanelResult::Hidden};
    if (clip.enabled && dot(clip.normal,*hit)<clip.offset) return {PanelResult::Hidden};
    auto obstruction=pick(ray,f.triangles);
    // Scene is drawn first with strict Less depth; equal-depth scene wins.
    if (obstruction.id && obstruction.distance <= length(*hit-ray.origin)+epsilon) return {PanelResult::Hidden};
    if (!outside && (u<0 || u>1 || v<0 || v>1 || q.state!=AnchorState::Visible)) return {PanelResult::Outside};
    return {PanelResult::Hit,u*pose.width,v*pose.height};
  }
  PanelHit route(PanelPhase phase,double x,double y,const Frame &f,ClipPlane clip) {
    if (phase==PanelPhase::Cancel) { cancel(); return last; }
    if (captured && start!=f.revision) { cancel(); return last={PanelResult::Stale}; }
    if ((phase==PanelPhase::Move || phase==PanelPhase::Up) && !captured) return last={PanelResult::Idle};
    auto ray=unproject(x,y,f.camera,f.viewport);
    last=ray ? mapRay(*ray,f,clip,captured) : PanelHit{};
    if (phase==PanelPhase::Down) { captured=last.result==PanelResult::Hit; start=f.revision; }
    if (phase==PanelPhase::Up || (captured && last.result!=PanelResult::Hit)) captured=false;
    return last;
  }
  // CPU half-space clipping preserves affine UVs; perspective interpolation is
  // performed by Metal. Scene triangles already use the same document clip.
  std::vector<Vertex> vertices(const Frame &f,ClipPlane clip) const {
    if (!visibleDepth(f)) return {};
    struct UV { Vec3 p; double u,v; };
    std::vector<UV> polygon={{point(0,0),0,0},{point(pose.width,0),1,0},
      {point(pose.width,pose.height),1,1},{point(0,pose.height),0,1}};
    if (clip.enabled) {
      std::vector<UV> out;
      for(size_t i=0;i<polygon.size();i++) {
        auto a=polygon[i], b=polygon[(i+1)%polygon.size()];
        double da=dot(clip.normal,a.p)-clip.offset, db=dot(clip.normal,b.p)-clip.offset;
        if(da>=0) out.push_back(a);
        if((da>=0)!=(db>=0)) { double t=da/(da-db); out.push_back({a.p+(b.p-a.p)*t,a.u+(b.u-a.u)*t,a.v+(b.v-a.v)*t}); }
      }
      polygon=std::move(out);
    }
    std::vector<Vertex> result;
    for(size_t i=1;i+1<polygon.size();i++) for(auto q:{polygon[0],polygon[i],polygon[i+1]})
      result.push_back({{float(q.p.x),float(q.p.y),float(q.p.z),1},{float(q.u),float(q.v),0,1}});
    return result;
  }
};
}
