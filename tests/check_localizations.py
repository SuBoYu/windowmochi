"""Check translation coverage and printf argument compatibility without macOS permissions."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
resources = root / 'Sources/WindowMochi/Resources'
tables = {p.stem: json.loads(p.read_text()) for p in resources.glob('*.json')}
assert set(tables) == {'en', 'zh-Hant', 'zh-Hans', 'ja'}
base = tables['en']
used = set()
for source in (root / 'Sources/WindowMochi').glob('*.swift'):
    used.update(re.findall(r'\bL\("([a-z_]+)"', source.read_text()))
assert used <= base.keys(), f'Missing keys: {used - base.keys()}'
for language, table in tables.items():
    assert table.keys() == base.keys(), f'{language}: inconsistent keys'
    for key, value in table.items():
        assert value.strip(), f'{language}.{key}: empty translation'
        assert re.findall(r'%(?:@|d)', value) == re.findall(r'%(?:@|d)', base[key]), f'{language}.{key}: incompatible placeholders'
print(f'PASS: {len(tables)} languages, {len(base)} keys, coverage and format arguments')
