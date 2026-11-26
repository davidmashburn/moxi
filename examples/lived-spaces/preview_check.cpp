#include "preview.hpp"
#include <cstdio>
#include <cstdlib>
using namespace exhibition;

static void require(bool ok, const char *claim) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", claim);
    std::exit(1);
  }
}
int main() {
  constexpr double aspect = 328. / 101;
  size_t cases = 0;
  for (auto path : {Path::North, Path::South}) {
    for (int partition = -2; partition <= 2; ++partition) {
      for (int tick = 0; tick <= 140; ++tick) {
        double time = tick / 10.;
        Score score{partition, 6};
        VisitorPreview preview(score, path, time);
        require(preview.origin == eye(path, time), "camera uses actual route eye");
        auto sample = preview.sample(0, 0, aspect);
        // Independent intersection with the x=0 plane and partition's z bounds.
        auto start = eye(path, time);
        bool blocked = false;
        if (start.x <= 0) {
          double u = -start.x / (exhibit.x - start.x);
          double z = start.z + u * (exhibit.z - start.z);
          blocked = z >= partition - 1.5 && z <= partition + 1.5;
        }
        require(blocked == !visible(score, path, time), "finite segment visibility");
        require(sample.surface == (blocked ? PreviewSurface::Partition :
                                             PreviewSurface::ExhibitMarker),
                "raster center agrees with geometric visibility");
        require(std::isfinite(sample.distance) && sample.distance >= 0,
                "nearest surface is at or in front of eye");
        ++cases;
      }
    }
  }
  VisitorPreview north({}, Path::North, 7), south({}, Path::South, 7);
  require(north.origin != south.origin &&
          north.sample(-.5, 0, aspect).surface == PreviewSurface::Partition &&
          south.sample(-.5, 0, aspect).surface == PreviewSurface::Background,
          "same time gives distinct route perspectives and off-center wall");
  require(north.sample(0, -.8, aspect).surface == PreviewSurface::Floor &&
          north.sample(0, .8, aspect).surface == PreviewSurface::Background,
          "floor below horizon; sky above");
  for (int peak = 2; peak <= 9; ++peak) {
    for (auto path : {Path::North, Path::South}) {
      for (double time : {double(peak - 2), double(peak), double(peak + 4)}) {
        VisitorPreview preview({2, peak}, path, time);
        auto expected = light({2, peak}, time);
        require(preview.intensity == expected, "one shared envelope at selected time");
      }
    }
  }
  auto before = south.sample(0, 0, aspect);
  auto later = VisitorPreview({0, 7}, Path::South, 7).sample(0, 0, aspect);
  require(before.surface == PreviewSurface::ExhibitMarker &&
          later.surface == before.surface && later.color.x > before.color.x &&
          later.color.y > before.color.y && later.distance == before.distance,
          "cue changes marker color without moving the exhibit");
  require(VisitorPreview({1, 6}, Path::North, 7).sample(0, 0, aspect).surface ==
          PreviewSurface::Partition, "partition occludes glyph before exhibit depth");
  auto ended = VisitorPreview({}, Path::South, 12);
  require(ended.origin == eye(Path::South, 10) && ended.intensity == light({}, 12),
          "short route stops moving while shared cue time continues");
  std::printf("PASS: %zu route/time/partition cases, perspective, depth, horizon, cue and endpoint\n", cases);
}
