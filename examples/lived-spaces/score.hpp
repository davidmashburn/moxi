#pragma once
#include "../../native/spatial/core.hpp"
#include <algorithm>
#include <cmath>

namespace exhibition {
using namespace moxi::spatial;
enum class Path { North, South };
struct Score {
  int partition = 0; // Offset along Z, metres.
  int peak = 6;      // Elapsed seconds.
  bool operator==(const Score &) const = default;
};
struct StudioSession {
  Score score;
  std::vector<Score> history;
  Path route = Path::North;
  double time = 7;

  bool edit(Score next) {
    if (next.partition < -2 || next.partition > 2 || next.peak < 2 ||
        next.peak > 9 || next == score)
      return false;
    history.push_back(score);
    score = next;
    return true;
  }
  bool undo() {
    if (history.empty())
      return false;
    score = history.back();
    history.pop_back();
    return true;
  }
};
constexpr Vec3 exhibit{3, 1, 0};
inline int duration(Path path) { return path == Path::North ? 14 : 10; }
inline Vec3 eye(Path path, double time) {
  return {-4 + 7 * std::clamp(time / duration(path), 0., 1.), 1,
          path == Path::North ? 2. : -2.};
}
inline std::array<Vec3, 4> corners(Score s) {
  double low = s.partition - 1.5, high = s.partition + 1.5;
  return {Vec3{0, 0, low}, {0, 2, low}, {0, 2, high}, {0, 0, high}};
}
inline std::vector<Triangle> partitionMesh(Score score) {
  auto p = corners(score);
  return {{p[0], p[1], p[2], 1}, {p[0], p[2], p[3], 1}};
}
inline bool visible(Score score, Path path, double time) {
  auto start = eye(path, time);
  auto direction = exhibit - start;
  auto hit = pick({start, unit(direction)}, partitionMesh(score));
  return !hit.id || hit.distance >= length(direction);
}
inline double light(Score score, double time) {
  double halfWidth = time < score.peak ? 2 : 4;
  return std::max(0., 1 - std::abs(time - score.peak) / halfWidth);
}
} // namespace exhibition
