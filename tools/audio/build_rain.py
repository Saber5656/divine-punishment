"""Original deterministic rain noise; no external samples. Run from any directory."""
from array import array
import math
from pathlib import Path
import random
import wave

RATE = 22050
rng = random.Random(55)
# Periodic amplitude avoids a seam; zero end samples keep playback click-free.
samples = []
low = 0.0
for i in range(RATE * 12):
    noise = rng.uniform(-1, 1)
    low = low * .78 + noise * .22
    edge = min(1.0, i / 220, (RATE * 12 - 1 - i) / 220)
    samples.append(round((noise * .11 + low * .32) * edge * 32767))
path = Path(__file__).resolve().parents[2] / 'assets/audio/rain.wav'
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(array('h', samples).tobytes())
