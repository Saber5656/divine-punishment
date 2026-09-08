import json
from pathlib import Path
import struct
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2] / 'assets/audio'

class AudioAssets(unittest.TestCase):
    def test_sources_are_original_and_loops_do_not_click_at_the_boundary(self):
        ledger=json.loads((ROOT/'sources.json').read_text())
        self.assertGreaterEqual(len(ledger['assets']),20)
        for row in ledger['assets']:
            with self.subTest(cue=row['id']), wave.open(str(ROOT/row['file'])) as source:
                pcm=source.readframes(source.getnframes())
                values=struct.unpack('<'+'h'*(len(pcm)//2),pcm)
                self.assertLess(max(abs(v) for v in values),32000)
                if row['loop']:
                    self.assertLess(abs(values[-1]-values[0]),160,'Loop boundary should not produce an audible click')
