#!/usr/bin/env bash
set -euo pipefail

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check.sh"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package_consumer.sh"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/benchmark.sh"
mojo build -I src -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa \
  examples/wx_style.mojo -o dist/moxi-wx-style-demo
mojo build -I src -Xlinker native/macos_metal.o -Xlinker -framework -Xlinker Metal \
  -Xlinker -framework -Xlinker QuartzCore -Xlinker -framework -Xlinker Cocoa \
  -Xlinker -framework -Xlinker Foundation examples/metal_window.mojo \
  -o dist/moxi-metal-window-demo
mojo build -I src -Xlinker native/macos_text.o -Xlinker -framework -Xlinker CoreText \
  -Xlinker -framework -Xlinker Cocoa examples/coretext.mojo \
  -o dist/moxi-coretext-demo

echo "Moxi release validation passed"
