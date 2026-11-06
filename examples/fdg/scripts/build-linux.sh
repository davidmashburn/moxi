#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "$app_dir/../.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo 'FDG GTK build requires a Linux runtime' >&2; exit 1; }
command -v mojo >/dev/null || { echo 'Run inside pixi run --locked' >&2; exit 1; }
pkg-config --exists 'gtk4 >= 4.14' || { echo 'Requires GTK >=4.14 development files (Ubuntu 24.04 libgtk-4-dev)' >&2; exit 1; }
read -r -a cflags <<< "$(pkg-config --cflags gtk4)"
read -r -a libs <<< "$(pkg-config --libs gtk4)"
mkdir -p "$app_dir/dist"
for source in "$repo/native/linux_window.c" "$repo/native/linux_text.c" "$app_dir/native/linux_services.c" "$app_dir/native/export.c"; do
  cc -std=c11 -O3 -Wall -Wextra -Werror "${cflags[@]}" -c "$source" -o "$app_dir/dist/$(basename "${source%.c}").o"
done
links=()
for object in linux_window linux_text linux_services export; do links+=(-Xlinker "$app_dir/dist/$object.o"); done
for flag in "${libs[@]}" -lm; do links+=(-Xlinker "$flag"); done
mojo build -I "$repo/src" -I "$app_dir/src" "${links[@]}" "$app_dir/src/main_linux.mojo" -o "$app_dir/dist/moxi-fdg"
echo 'Built Linux GTK FDG application'
