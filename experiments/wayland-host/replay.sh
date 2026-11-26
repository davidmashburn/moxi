#!/usr/bin/env bash
# Run in a Linux environment with sway, wtype, grim and a built workbench.
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(realpath -m "${1:?supply a fresh evidence directory}")
mkdir "$out"
export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=$(mktemp -d)
cleanup() {
  if [[ -n ${keyboard:-} ]]; then kill "$keyboard" 2>/dev/null || true; fi
  if [[ -n ${compositor:-} ]]; then
    kill "$compositor" 2>/dev/null || true
    wait "$compositor" 2>/dev/null || true
  fi
  rm -rf "$XDG_RUNTIME_DIR"
}
trap cleanup EXIT
unset DISPLAY SWAYSOCK WAYLAND_DISPLAY
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1
cat >"$XDG_RUNTIME_DIR/config" <<'CONFIG'
xwayland disable
output HEADLESS-1 mode 1024x768 scale 1
default_border none
for_window [shell="xdg_shell"] fullscreen enable
CONFIG
sway -c "$XDG_RUNTIME_DIR/config" >"$out/compositor.log" 2>&1 &
compositor=$!
for ((i=0; i<200; i++)); do
  sockets=("$XDG_RUNTIME_DIR"/sway-ipc.*.sock)
  displays=("$XDG_RUNTIME_DIR"/wayland-*)
  if [[ -S ${sockets[0]} && -S ${displays[0]} ]]; then break; fi
  kill -0 "$compositor"
  sleep .1
done
[[ -S ${sockets[0]} && -S ${displays[0]} ]]
export XDG_CONFIG_HOME="$XDG_RUNTIME_DIR/config-home" XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache"
export SWAYSOCK="${sockets[0]}" WAYLAND_DISPLAY="${displays[0]##*/}"
export GDK_BACKEND=wayland GSK_RENDERER=cairo GTK_IM_MODULE=simple
# Keep keyboard capability on the headless seat throughout GTK startup and input.
wtype -s 300000 &
keyboard=$!
dbus-run-session -- python3 experiments/wayland-host/replay.py "$out"
