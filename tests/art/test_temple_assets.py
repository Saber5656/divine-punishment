"""Temple interchange contract, independent of the Blender runtime."""
import json
from pathlib import Path
import unittest
from test_asset_contract import read_glb

ROOT = Path(__file__).resolve().parents[2]
MODULES = {'wet_paving_2m', 'stone_wall_2m', 'stone_tread_2m',
           'cedar_wall_2m', 'temple_post', 'temple_beam_2m',
           'temple_roof_2m', 'eave_trim_2m', 'bronze_bell', 'grave_stone',
           'temple_lantern', 'temple_brazier', 'temple_retainer',
           'monk_umbrella', 'naginata', 'boundary_rock', 'cell_lattice_2m',
           'waterwheel'}


class TempleAssets(unittest.TestCase):
    def test_original_temple_kit_covers_authored_areas_without_runtime_rigs(self):
        path = ROOT / 'assets/environment/temple_modules.glb'
        self.assertTrue(path.is_file(), 'Temple needs its original Blender module kit')
        if not path.is_file():
            return
        data = read_glb(path)
        nodes = {node.get('name'): node for node in data['nodes']}
        self.assertTrue(MODULES <= nodes.keys(), MODULES - nodes.keys())
        for name in MODULES:
            node = nodes[name]
            self.assertEqual(node.get('translation', [0, 0, 0]), [0, 0, 0])
            self.assertEqual(node.get('scale', [1, 1, 1]), [1, 1, 1])
            for actual, expected in zip(node.get('rotation', [0, 0, 0, 1]), [0, 0, 0, 1]):
                self.assertAlmostEqual(actual, expected, places=5, msg=name)
        self.assertFalse(data.get('skins'))
        self.assertFalse(data.get('animations'))
        self.assertFalse(data.get('cameras'))
        self.assertGreaterEqual(len(data['materials']), 8)
        vertex_count = sum(data['accessors'][primitive['attributes']['POSITION']]['count']
                           for mesh in data['meshes'] for primitive in mesh['primitives'])
        self.assertLess(vertex_count, 75000, 'Modules must remain suitable for repeated instances')
        manifest = json.loads(path.with_suffix('.json').read_text())
        self.assertEqual(set(manifest['modules']), MODULES)
        self.assertEqual(manifest['units'], 'metres')
        self.assertEqual(manifest['license'], 'Project license')
        self.assertFalse(manifest['external_assets'])


if __name__ == '__main__':
    unittest.main()
