"""Validate delivered asset interchange contracts without requiring Blender."""
import json
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    size, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20:20 + size])


class AssetContract(unittest.TestCase):
    def test_three_clothed_rigged_roles(self):
        for role in ('shinobi', 'ashigaru', 'magistrate'):
            with self.subTest(role=role):
                data = read_glb(ROOT / 'assets/characters' / f'{role}.glb')
                bones = {data['nodes'][i]['name'] for skin in data['skins'] for i in skin['joints']}
                self.assertTrue({'pelvis', 'Head', 'hand_l', 'hand_r', 'foot_l', 'foot_r'} <= bones)
                self.assertGreater(len(data['meshes']), 3)
                self.assertTrue(any('garment' in n.get('name', '').lower() for n in data['nodes']))
                self.assertFalse(data.get('cameras'))
                self.assertFalse(any(i.get('uri', '').startswith('/') for i in data.get('images', [])))

    def test_in_place_animation_library(self):
        data = read_glb(ROOT / 'assets/animations/quaternius_standard.glb')
        names = {a['name'] for a in data['animations']}
        self.assertEqual(len(names), 43)
        self.assertTrue({'Idle_Loop', 'Walk_Loop', 'Crouch_Fwd_Loop', 'Sword_Attack', 'Death01'} <= names)

    def test_residence_modules(self):
        data = read_glb(ROOT / 'assets/environment/residence_modules.glb')
        names = {n.get('name') for n in data['nodes']}
        required = {'floor_2m', 'post_2p8m', 'beam_2m', 'shoji_2m', 'plaster_2m',
                    'engawa_2m', 'roof_2m', 'ridge_2m', 'gate_4m', 'fence_2m', 'lantern', 'stone_step'}
        self.assertTrue(required <= names, required - names)
        self.assertFalse(data.get('skins'))
        self.assertFalse(data.get('animations'))
        self.assertGreaterEqual(len(data['meshes']), len(required))

    def test_provenance_is_bundled(self):
        for path in ('assets/characters/QUATERNIUS-LICENSE.txt',
                     'assets/animations/QUATERNIUS-LICENSE.txt', 'assets/production-assets.json'):
            self.assertTrue((ROOT / path).is_file(), path)
        manifest = json.loads((ROOT / 'assets/production-assets.json').read_text())
        self.assertEqual(len(manifest['upstream']), 2)
        for source in manifest['upstream']:
            self.assertEqual(source['license'], 'CC0-1.0')
            self.assertEqual(len(source['archive_sha256']), 64)


if __name__ == '__main__':
    unittest.main()
