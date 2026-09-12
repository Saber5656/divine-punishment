"""Port interchange contract, independent of the Blender authoring runtime."""
import json
from pathlib import Path
import unittest
from test_asset_contract import read_glb

ROOT = Path(__file__).resolve().parents[2]
MODULES = {'quay_planks_2m', 'quay_pile', 'storehouse_panel_2m',
           'port_roof_2m', 'house_shoji_2m', 'house_post', 'port_crate',
           'port_barrel', 'coiled_rope', 'cargo_ship_hull', 'cargo_ship_rig',
           'port_lantern', 'port_worker', 'counting_desk'}


class PortAssets(unittest.TestCase):
    def test_port_kit_is_visual_only_and_includes_all_authored_areas(self):
        path = ROOT / 'assets/environment/port_modules.glb'
        self.assertTrue(path.is_file(), 'The port needs its Blender-authored module kit')
        if not path.is_file():
            return
        data = read_glb(path)
        names = {node.get('name') for node in data['nodes']}
        self.assertTrue(MODULES <= names, MODULES - names)
        for node in data['nodes']:
            if node.get('name') in MODULES:
                self.assertEqual(node.get('translation', [0, 0, 0]), [0, 0, 0])
                self.assertEqual(node.get('scale', [1, 1, 1]), [1, 1, 1])
                for actual, expected in zip(node.get('rotation', [0, 0, 0, 1]), [0, 0, 0, 1]):
                    self.assertAlmostEqual(actual, expected, places=5, msg=node['name'])
        self.assertFalse(data.get('skins'))
        self.assertFalse(data.get('animations'))
        self.assertFalse(data.get('cameras'))
        self.assertGreaterEqual(len(data['meshes']), len(MODULES))
        self.assertGreaterEqual(len(data['materials']), 6)
        manifest = json.loads((ROOT / 'assets/environment/port_modules.json').read_text())
        self.assertEqual(manifest['units'], 'metres')
        self.assertEqual(manifest['license'], 'Project license')
        self.assertEqual(set(manifest['modules']), MODULES)
        self.assertFalse(manifest['external_assets'])


if __name__ == '__main__':
    unittest.main()
