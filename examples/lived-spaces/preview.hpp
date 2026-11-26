#pragma once
#include "score.hpp"
#include <limits>

namespace exhibition {
// A bounded, stylized perspective view, aimed at the existing exhibit point.
// The sphere is a display glyph for that point, not an exhibit visibility model.
enum class PreviewSurface { Background, Floor, Partition, ExhibitMarker };
struct PreviewSample {
  PreviewSurface surface = PreviewSurface::Background;
  Vec3 color{.94, .95, .97};
  double distance = std::numeric_limits<double>::infinity();
};
struct VisitorPreview {
  Vec3 origin, forward, right, up;
  std::vector<Triangle> wall;
  double intensity;
  static constexpr double markerRadius = .22;
  static constexpr double verticalFov = 50 * pi / 180;

  VisitorPreview(Score score, Path path, double time)
      : origin(eye(path, time)), forward(unit(exhibit - origin)),
        right(unit(cross(forward, {0, 1, 0}))), up(cross(right, forward)),
        wall(partitionMesh(score)), intensity(light(score, time)) {}

  // x/y are normalized image coordinates; positive y points up.
  Ray ray(double x, double y, double aspect) const {
    double halfHeight = std::tan(verticalFov / 2);
    return {origin, unit(forward + right * (x * aspect * halfHeight) +
                         up * (y * halfHeight))};
  }
  PreviewSample sample(double x, double y, double aspect) const {
    auto r = ray(x, y, aspect);
    PreviewSample result;
    if (r.direction.y < -epsilon) {
      double distance = -origin.y / r.direction.y;
      auto point = origin + r.direction * distance;
      if (point.x >= -4 && point.x <= 4 && point.z >= -3 && point.z <= 3) {
        bool grid = std::abs(point.x - std::round(point.x)) < .025 ||
                    std::abs(point.z - std::round(point.z)) < .025;
        result = {PreviewSurface::Floor,
                  grid ? Vec3{.65, .69, .73} : Vec3{.84, .87, .89}, distance};
      }
    }
    if (auto hit = pick(r, wall); hit.id && hit.distance < result.distance)
      result = {PreviewSurface::Partition, {.30, .27, .62}, hit.distance};
    auto offset = origin - exhibit;
    double b = dot(offset, r.direction);
    double discriminant = b * b - dot(offset, offset) + markerRadius * markerRadius;
    if (discriminant >= 0) {
      double distance = -b - std::sqrt(discriminant);
      if (distance > epsilon && distance < result.distance)
        result = {PreviewSurface::ExhibitMarker,
                  {.4 + .6 * intensity, .24 + .36 * intensity, .08}, distance};
    }
    return result;
  }
};
} // namespace exhibition
