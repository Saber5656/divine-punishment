"""Original stylized alarm vocal synthesis; no recordings or voice cloning."""
from array import array
import math
from pathlib import Path
import random
import wave
RATE = 22050
rng = random.Random(56)
phase = 0.0
samples = []
for i in range(int(RATE * .8)):
    t = i / RATE
    frequency = 400 + 240 * math.sin(math.pi * t / .8) + 15 * math.sin(2 * math.pi * 7 * t)
    phase += 2 * math.pi * frequency / RATE
    envelope = min(1, t / .06) * max(0, 1 - t / .8) ** .6
    tone = math.sin(phase) + .35 * math.sin(phase * 2) + .18 * math.sin(phase * 3)
    samples.append(round((tone * .22 + rng.uniform(-1, 1) * .02) * envelope * 32767))
path = Path(__file__).resolve().parents[2] / 'assets/audio/civilian_scream.wav'
with wave.open(str(path), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(array('h', samples).tobytes())
