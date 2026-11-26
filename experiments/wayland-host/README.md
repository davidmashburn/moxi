# Reproduce the Wayland workbench replay

The canonical Linux build runs from a fresh x86-64 checkout with the
repository's native build prerequisites, D-Bus and Python 3. These commands
stage the additional compositor tools and a Japanese font under a private
directory using Ubuntu's package index.

```bash
set -euo pipefail
scratch=$(mktemp -d)
mkdir "$scratch/debs" "$scratch/root"
(
  cd "$scratch/debs"
  apt-get download fonts-ipafont-gothic
  apt-get -s install --no-install-recommends sway grim wtype |
    awk '/^Inst/{print $2}' | xargs -r apt-get download
  for deb in ./*.deb; do
    test ! -f "$deb" || dpkg-deb -x "$deb" "$scratch/root"
  done
)
export XDG_DATA_HOME="$scratch/data"
mkdir -p "$XDG_DATA_HOME/fonts"
cp "$scratch/root/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf" "$XDG_DATA_HOME/fonts/"
pixi run --locked linux-native-build
export PATH="$scratch/root/usr/bin:$PATH"
export LD_LIBRARY_PATH="$scratch/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
bash experiments/wayland-host/replay.sh "$scratch/evidence"
```

The replay starts a private headless compositor, disables Xwayland, clears
DISPLAY, requires GDK Wayland and checks the launched PID's xdg-shell surface.
A virtual keyboard stays attached while GTK runs. The driver waits for matching
Moxi frame publication and GTK draw records, and captures Sway's output with
grim. The fresh evidence directory holds the original PNGs, state checks, trace
and logs. The compositor exits after the run.

See the [offline sequence](../../artifacts/demo-slideshows/p11-wayland/index.html)
and [recorded checks](../../artifacts/demo-slideshows/p11-wayland/results.json).


## Recorded build and result

The retained run used a network-disabled Ubuntu 24.04.5 x86-64 container,
GTK 4.14.5, Sway 1.9, wlroots 0.17.1, grim 1.4 and wtype 0.4, with IPAGothic
available through Fontconfig. The workbench, C presenter and text bridge came
from source commit `0da6f295b6d20cdf663aaf66a039a43e8fb66dd0`.
An initial native-only build in the emulated Ubuntu guest was slow. For the
retained binary, macOS Mojo 1.1.0 (8189361e) emitted the Linux object and
Linux GCC compiled and linked the GTK host:

```bash
# On the compiler host, inside the locked environment
mojo build --target-triple x86_64-unknown-linux-gnu --emit object \
  -I src -I examples examples/layout_workbench_linux.mojo -o workbench.o

# On Linux, with workbench.o and the Linux Mojo runtime libraries available
mkdir -p dist
for part in linux_window linux_text; do
  cc -std=c11 -O3 -Wall -Wextra -Werror $(pkg-config --cflags gtk4) \
    -c "native/$part.c" -o "dist/$part.o"
done
cc workbench.o dist/linux_window.o dist/linux_text.o "$KIWI_LIB" \
  -L"$MOJO_LIB" -lKGENCompilerRTShared -l:libstdc++.so.6 -lm \
  $(pkg-config --libs gtk4) -o dist/layout-workbench-linux
export LD_LIBRARY_PATH="$MOJO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

`MOJO_LIB` contains the locked Linux runtime. `KIWI_LIB` points to the static
library from `experiments/layout-kiwi/scripts/build.sh`. The recorded link
reused the guest's library from `bd16cde`. The Kiwi bridge sources, build
script and dependency pin are identical at the recorded revision. Its SHA-256
was `eda050dadde5f63a4872e35b1470a83a5c51c42e5b1ec32028b46d1b9f688999`.

The private xdg-shell surface showed the form, virtual collection and chart.
Tab moved focus from Dataset to Summary. Space moved the body from y=64 to
y=119. Opening Dialog scoped the published controls to the modal and focused
its first button. Escape restored focus to the launcher. At 680 pixels the
splitter disappeared and the panes stacked. Restoring 1024 pixels brought back
the splitter and preserved the dataset value. The window closed with exit 0.

The session did not exercise pointer or touch input, IME, clipboard, physical
display scaling, desktop integration or GPU presentation. GTK reported an
unavailable accessibility bus in the container. External accessibility and
screen-reader behavior remain open on Wayland.

To regenerate just this offline page after copying the seven PNGs into the
gallery, run from the repository root:

```bash
PYTHONPATH=scripts python3 - <<'PYTHON'
from pathlib import Path
from demo_slideshows import load_manifest, render
gallery = Path("artifacts/demo-slideshows/p11-wayland")
(gallery / "index.html").write_text(render(load_manifest(gallery / "manifest.json")))
PYTHON
```

The seven PNG dimensions and SHA-256 values were checked against the manifest
and run results. The four consecutive wide-state transitions changed pixels.
After restoring the wide viewport, the image matched the pre-resize state
pixel for pixel. Offline Chrome 158 opened the file, decoded all seven slides,
and passed previous, next, keyboard wraparound and contact-sheet navigation.
