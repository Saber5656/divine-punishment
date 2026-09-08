"""Check the Japanese catalog, literal references and Japanese UI text leaks."""
import csv
from pathlib import Path
import re
import sys

JAPANESE = re.compile(r'[\u3040-\u30ff\u3400-\u9fff]')
TOKENS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*')
REFERENCES = re.compile(r'(?:GameText\.(?:get_text|with_bindings)\(\s*&?|(?:title_key|display_name_key)\s*=\s*&?)"([a-z][a-z0-9_.]+)"')


def hardcoded_lines(source):
    return [source.count('\n', 0, match.start()) + 1 for match in TOKENS.finditer(source)
            if not match.group().startswith('#') and JAPANESE.search(match.group())]


def check(root):
    root = Path(root)
    errors = []
    with (root / 'data/text/ja.csv').open(newline='', encoding='utf-8') as handle:
        rows = list(csv.reader(handle))
    # "ja" is the Godot CSV translation importer language identifier.
    if not rows or rows[0] not in [['key', 'ja'], ['key', 'text']]:
        errors.append('catalog: expected key,ja (Godot) or key,text')
    keys = set()
    for number, row in enumerate(rows[1:], 2):
        if len(row) != 2 or not all(row):
            errors.append(f'catalog:{number}: expected a nonempty key and text')
            continue
        if row[0] in keys:
            errors.append(f'catalog:{number}: duplicate key {row[0]}')
        keys.add(row[0])
    for folder in ['src', 'data']:
        for path in sorted((root / folder).rglob('*')):
            if path.suffix not in ['.gd', '.tscn', '.tres']:
                continue
            source = path.read_text(encoding='utf-8')
            rel = path.relative_to(root).as_posix()
            for line in hardcoded_lines(source):
                # Persisted pre-v2 rank values are a compatibility mapping,
                # never displayed. Keep this exception exact and auditable.
                if rel == 'src/autoload/save_manager.gd' and source.splitlines()[line-1].startswith('const LEGACY_RANKS :='):
                    continue
                errors.append(f'{rel}:{line}: hardcoded Japanese text')
            for key in REFERENCES.findall(source):
                if key not in keys:
                    errors.append(f'{rel}: unknown catalog key {key}')
    return errors


if __name__ == '__main__':
    findings = check(Path(__file__).resolve().parents[2])
    for finding in findings:
        print(finding)
    print(f'Catalog lint: {len(findings)} findings')
    sys.exit(bool(findings))
