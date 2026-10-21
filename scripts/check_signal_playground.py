"""Check actual Metal pixels and exported audio, including the batch-offset regression."""

from array import array
from math import cos, pi, sin, sqrt
from pathlib import Path
import sys
import wave


root = Path(__file__).resolve().parents[1] / "artifacts" / "signal-playground"
header = b"P6\n1080 760\n255\n"
pixels = (root / "01-sine.ppm").read_bytes()
assert pixels.startswith(header), "Unexpected native frame dimensions/format"
pixels = pixels[len(header):]
assert len(pixels) == 1080 * 760 * 3
for x, y, expected in [
    (8, 8, (9, 14, 23)),
    (40, 250, (14, 23, 36)),
    (100, 120, (36, 74, 99)),
    (90, 610, (255, 168, 74)),
]:
    offset = (y * 1080 + x) * 3
    actual = pixels[offset:offset + 3]
    assert all(abs(a - b) <= 2 for a, b in zip(actual, expected)), (x, y, tuple(actual), expected)

spectra = {}
for name in ("01-sine", "02-drag", "03-triangle", "04-pulse"):
    with wave.open(str(root / f"{name}.wav"), "rb") as audio:
        assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getnframes()) == (1, 2, 44100, 88200)
        samples = array("h", audio.readframes(audio.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    assert 100 < max(abs(sample) for sample in samples) <= 4916
    assert abs(sum(samples) / len(samples) / 32768) < 0.001
    middle = samples[22050:66150]
    amplitudes = []
    for harmonic in (1, 2, 3):
        rate = 2 * pi * 220 * harmonic / 44100
        real = sum(sample * cos(rate * i) for i, sample in enumerate(middle))
        imaginary = sum(sample * sin(rate * i) for i, sample in enumerate(middle))
        amplitudes.append(2 * sqrt(real * real + imaginary * imaginary) / len(middle) / 32768)
    spectra[name] = amplitudes

assert spectra["01-sine"][0] > 0.11 and spectra["01-sine"][1] < 0.001
assert spectra["02-drag"][1] > 0.01
assert spectra["03-triangle"][1] < 0.001 and spectra["03-triangle"][2] > 0.005
assert spectra["04-pulse"][1] > 0.03
print("Native pixels preserve earlier batches; WAV files are bounded, centered, and contain the expected 220 Hz harmonics.")
for name, amplitudes in spectra.items():
    print(name, "harmonic amplitudes:", ", ".join(f"{value:.4f}" for value in amplitudes))
