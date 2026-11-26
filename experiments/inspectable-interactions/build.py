"""Build a self-contained synthetic waveform using this checkout's public Moxi API."""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "python"))
from moxi import PlotSpec, plot

spec = PlotSpec()
spec.add_line("Synthetic signal", color=(0.04, 0.45, 0.42, 1))
x = list(range(101))
y = [math.sin(i * 0.18) * (0.4 + i / 160) + 0.25 * math.cos(i * 0.48) for i in x]
svg = plot({"x": x, "y": y}, spec, width=780, height=240).to_svg().decode()
output = Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
(output / "index.html").write_text((HERE / "index.in.html").read_text().replace("<!-- FIGURE -->", svg))
for name in ("interaction.mjs", "app.mjs"):
    (output / name).write_bytes((HERE / name).read_bytes())
