# Linux workbench scene adapter (P09)

Set `MOXI_LINUX_SCENE=gsk GSK_RENDERER=ngl` when launching the compiled Linux workbench on GTK 4.14. The default remains its GTK drawing area and Cairo painter. The opt-in widget converts solid rectangles and butt-ended line segments into GSK color nodes, uses GDK memory textures for owned RGBA8 bitmaps and applies the canvas clip around the entire custom layer. Retained controls, paragraph layout and editor composition still use the existing Cairo/Pango painter. Their position before or after the custom layer follows the Mojo packet's paint order. Custom text, rounded shapes and outlined rectangles also use Cairo nodes. The host ABI rejects malformed image lengths. External image IDs, nested Scene clip commands, arbitrary transforms and general Scene path coverage are outside this adapter's declared subset.

The application is the repository's `examples/layout_workbench_linux.mojo`. It submits `LayoutWorkbench` packets and the 125-command `layout_workbench_chart` at layer 22. GTK's GSK OpenGL renderer was selected for this experiment because GTK already owns the window, device scale, renderer selection and text lifetimes. This exercises a second graphics API through the existing ABI without introducing another native runtime. The GTK integration is Linux-specific. GSK's backend may run on a CPU driver. wgpu was considered as a separate native bridge and was not benchmarked.

## Reproduce on Linux

Use a fresh checkout, the locked Mojo 1.1.0 environment, GTK 4.14+ development files, libepoxy, the repository's Linux native build prerequisites, Xvfb, xauth, Openbox, xdotool, scrot, dbus-run-session and Python 3.10+ with PyGObject, GdkPixbuf and Pillow. Run the build and oracle compilation in the locked Pixi environment. All subsequent commands are from the checkout root. Use a fresh capture directory on each run. The screenshot session must support the 2× window.

```sh
pixi run --locked bash scripts/linux_native_build.sh
pixi run --locked mojo build -I src experiments/linux-gsk/oracle.mojo -o dist/chart-oracle
cc -std=c11 -O2 -Wall -Wextra -Werror experiments/linux-gsk/resources.c native/linux_text.c \
  $(pkg-config --cflags --libs gtk4 epoxy) -lm -o dist/resources
dbus-run-session -- xvfb-run -a env MOXI_LINUX_SCENE=gsk GSK_RENDERER=ngl dist/resources
dbus-run-session -- xvfb-run -a -s '-screen 0 2560x1920x24' \
  bash experiments/linux-gsk/replay.sh dist/p09-run
python3 - <<'PY'
import json, subprocess
from pathlib import Path
run = Path("dist/p09-run")
w, h = json.loads((run / "ngl/states.json").read_text())[0]["chart"][2:]
with (run / "chart.ppm").open("wb") as out:
    subprocess.run(["dist/chart-oracle", str(w), str(h)], stdout=out, check=True)
PY
python3 experiments/linux-gsk/compare.py dist/p09-run
python3 experiments/linux-gsk/gallery.py dist/p09-run dist/gallery/linux-gsk
```

The harness launches an isolated window for each backend, waits for a drawn publication, checks semantic state after each input, captures the active client window and closes it via the window manager. The scale-2 scenario uses a separate process. The failure scenario requests NGL while disabling GL and Vulkan at startup and checks the actual fallback renderer class. Neither test simulates mid-frame device loss.

The chart-only reference uses Moxi's `SoftwareSceneRenderer`. The full-window reference uses the existing Linux Cairo renderer, which also paints glyphs and controls. The comparison uses all RGB pixels of each aligned window and the chart crop, with an eight-level per-channel threshold on at least 97% of pixels. To catch missing series geometry against a uniform background, the chart's teal pixels must overlap the software oracle with intersection-over-union ≥ 0.65. Full-window captures cover the GTK client area at its native device scale. No hardware timing or latency conclusion follows from running the guest under emulation.

[Offline slideshow](../../artifacts/demo-slideshows/linux-gsk/index.html)
