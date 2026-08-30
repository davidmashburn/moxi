#!/usr/bin/env bash
set -euo pipefail

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check.sh"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package_consumer.sh"
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/benchmark.sh"
mojo build -I src -Xlinker native/macos_window.o -Xlinker -framework -Xlinker Cocoa \
  examples/wx_style.mojo -o dist/moxi-wx-style-demo

echo "Moxi release validation passed"
