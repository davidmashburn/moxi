// Emit unit-pitch accordion sections in the fixed Moxi orthographic camera.
// Coordinates are in centimetres. The sheet is four centimetres deep.
#include "core.hpp"
#include <cmath>
#include <iomanip>
#include <iostream>
using namespace moxi::spatial;

int main() {
  Camera camera;
  camera.projection = Projection::Orthographic;
  camera.distance = 10.5;
  camera.pitch = .87;
  camera.yaw = -.19;
  const Viewport viewport{0, 0, 500, 200, 1};
  std::cout << std::setprecision(12);
  auto point = [&](Vec3 p) {
    auto s = project(p, camera, viewport);
    std::cout << '[' << s.x << ',' << s.y << ']';
  };
  std::cout << "{\"back\":";
  point({0, 0, -2});
  std::cout << ",\"front\":";
  point({0, 0, 2});
  std::cout << ",\"sections\":[";
  for (int degrees = 0; degrees <= 75; ++degrees) {
    double angle = degrees * pi / 180;
    if (degrees) std::cout << ',';
    std::cout << "{\"run\":" << cos(angle) << ",\"rise\":" << sin(angle)
              << ",\"offsets\":[";
    for (int i = 0; i <= 6; ++i) {
      if (i) std::cout << ',';
      // Orthographic projection is affine. Cache screen displacements per cm
      // of pitch so the offline editor can scale them about either sheet edge.
      auto origin = project({}, camera, viewport);
      auto p = project({(i - 3) * cos(angle), (i % 2) * sin(angle), 0},
                       camera, viewport);
      std::cout << '[' << p.x - origin.x << ',' << p.y - origin.y << ']';
    }
    std::cout << "]}";
  }
  std::cout << "]}";
}
