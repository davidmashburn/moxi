#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
cargo fmt --manifest-path native/retained_layout/Cargo.toml --check
cargo check --locked --manifest-path native/retained_layout/Cargo.toml
cargo clippy --locked --manifest-path native/retained_layout/Cargo.toml --all-targets -- -D warnings
cargo test --locked --manifest-path native/retained_layout/Cargo.toml
cargo build --release --locked --manifest-path native/retained_layout/Cargo.toml
mkdir -p dist
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_text.m -o native/macos_text.o
clang -O3 -Wall -Wextra -Werror -fobjc-arc -fmodules -c native/macos_window.m -o native/macos_window.o
mojo build -I src -Xlinker native/retained_layout/target/release/libmoxi_retained_layout.a \
  -Xlinker native/macos_text.o -Xlinker native/macos_window.o \
  -Xlinker -framework -Xlinker Cocoa -Xlinker -framework -Xlinker CoreText \
  tests/retained_layout.mojo -o dist/moxi-retained-layout-test
./dist/moxi-retained-layout-test
