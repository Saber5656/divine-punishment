import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class CatalogLintTests(unittest.TestCase):
    def test_literal_detector_ignores_comments_but_catches_ui_strings(self):
        path = ROOT / 'tools/text/lint_catalog.py'
        self.assertTrue(path.is_file(), 'Catalog lint must exist')
        if not path.is_file():
            return
        spec = importlib.util.spec_from_file_location('catalog_lint', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(module.hardcoded_lines('label.text = "開始"'))
        self.assertFalse(module.hardcoded_lines('# 日本語の説明\nlabel.text = GameText.get_text(&"start")'))
        self.assertTrue(module.hardcoded_lines('label.text = "開始 # not a comment"'))

    def test_repository_catalog_and_references_are_consistent(self):
        path = ROOT / 'tools/text/lint_catalog.py'
        self.assertTrue(path.is_file(), 'Catalog lint must exist')
        if not path.is_file():
            return
        spec = importlib.util.spec_from_file_location('catalog_lint', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.check(ROOT), [])

    def test_resource_dialogue_keys_are_checked(self):
        import tempfile
        spec = importlib.util.spec_from_file_location('catalog_lint', ROOT / 'tools/text/lint_catalog.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'src').mkdir()
            (root / 'data/text').mkdir(parents=True)
            (root / 'data/text/ja.csv').write_text('key,ja\nknown,既知\n')
            (root / 'data/scene.tres').write_text('text_key = &"missing.line"\nspeaker_key = &"missing.speaker"\n')
            self.assertEqual(len(module.check(root)), 2)
