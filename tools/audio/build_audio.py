"""Reproducible original synthesis. No recordings or external samples are used."""
from array import array
import json
import math
from pathlib import Path
import random
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / 'assets/audio'
TAU = math.tau
ledger = []


def save(name, samples, loop=False):
    if loop:
        # Match the endpoints with a short crossfade into the opening material.
        n = min(RATE // 4, len(samples) // 8)
        opening = samples[:n]
        for i in range(n):
            t = i / (n - 1)
            samples[-n + i] = samples[-n + i] * (1 - t) + opening[0] * t
    peak = max(abs(x) for x in samples)
    assert peak < .98, (name, peak)
    pcm = array('h', (round(max(-1, min(1, x)) * 32767) for x in samples))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as target:
        target.setnchannels(1); target.setsampwidth(2); target.setframerate(RATE)
        target.writeframes(pcm.tobytes())
    ledger.append({'id': name, 'file': name + '.wav', 'seconds': len(samples) / RATE,
                   'peak': peak, 'loop': loop, 'source': 'Original project synthesis'})


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(46)
    ambient = []; low = 0.0
    for i in range(20 * RATE):
        t = i / RATE
        low = low * .985 + rng.uniform(-1, 1) * .015
        insects = max(0, math.sin(TAU * .6 * t)) ** 12 * math.sin(TAU * 3300 * t) * .012
        ambient.append(low * .32 + insects + math.sin(TAU * 48 * t) * .006)
    save('night', ambient, True)
    unease = [0.0] * (16 * RATE)
    for start, freq, duration in [(0,293.665,2.0),(3,349.228,2),(6,391.995,2.8),
                                   (10,440,1.3),(12,391.995,1.5),(14,293.665,1.4)]:
        for i in range(int(duration * RATE)):
            t = i / RATE
            envelope = min(1, t / .18) * min(1, (duration-t)/.45)
            phase = TAU * freq * t + .045 * math.sin(TAU * 5.1 * t)
            tone = math.sin(phase) + .18 * math.sin(phase*2) + .06 * math.sin(phase*3)
            unease[int(start*RATE)+i] += .075 * envelope * (tone + rng.uniform(-.08,.08))
    save('unease', unease, True)
    combat = [0.0] * (16 * RATE)
    for beat in range(24):
        start = int(beat * 2/3 * RATE)
        for i in range(min(int(.6 * RATE), len(combat)-start)):
            t = i / RATE
            body = math.sin(TAU * (64*t + 24*(1-math.exp(-t*20))/20))
            rim = math.sin(TAU * 173 * t) * math.exp(-t*20)
            hit = .24 * (body*.8 + rim*.2) * math.exp(-t*8)
            hit += rng.uniform(-1,1) * .03 * math.exp(-t*60)
            combat[start+i] += hit * (1 if beat % 4 == 0 else .55)
    save('combat', combat, True)
    materials = {'world': (90,.08), 'wood': (145,.035), 'creaky_wood': (180,.04),
                 'tatami': (75,.035), 'gravel': (110,.15), 'soil': (80,.065),
                 'shallow_water': (240,.12)}
    for name,(freq,noise) in materials.items():
        samples=[]; low=0.0
        for i in range(int(.42*RATE)):
            t=i/RATE
            low=.72*low+.28*rng.uniform(-1,1)
            value=.17*math.sin(TAU*freq*t)*math.exp(-t*35)+noise*low*math.exp(-t*13)
            if name=='creaky_wood': value+=.05*math.sin(TAU*(430*t-110*t*t))*math.exp(-t*7)
            if name=='shallow_water': value+=.055*math.sin(TAU*(800*t+600*t*t))*math.exp(-t*18)
            samples.append(value*min(1,t/.003))
        save('footstep_'+name,samples)
    for name,freq,length,noise in [('tool_stone',900,.25,.11),('tool_dart',1200,.18,.12),
            ('tool_smoke',130,.65,.22),('tool_rope',250,.3,.1),('tool_naruko',740,.45,.03),
            ('door',180,.65,.065),('landing',75,.35,.1),('combat_hit',310,.3,.13),
            ('assassination',92,.5,.05),('detection',620,.55,.01),('result',880,.8,.005),
            ('water',360,.5,.12),('bell',780,1.2,.005)]:
        samples=[];low=0.0
        for i in range(int(length*RATE)):
            t=i/RATE;low=.6*low+.4*rng.uniform(-1,1)
            envelope=math.exp(-t*6/length)*min(1,t/.004)
            samples.append((.15*math.sin(TAU*(freq*t+freq*.14*t*t))+noise*low)*envelope)
        save(name,samples)
    (OUT/'sources.json').write_text(json.dumps({'license':'Project license','generator':'tools/audio/build_audio.py',
        'description':'Original synthesized wind, insect texture, flute-like tones, drum-like percussion and foley. No external recordings or sampled instruments.',
        'sample_rate':RATE,'assets':ledger},indent=2)+'\n')
    print('Generated',len(ledger),'original WAV assets; peaks below clipping.')


if __name__=='__main__': main()
