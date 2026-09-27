#!/usr/bin/env python3
"""Reproducible glyph coverage audit. Requires fonttools; not an engine test."""
import hashlib
import json
from pathlib import Path
from fontTools.ttLib import TTFont
ROOT = Path(__file__).resolve().parents[1]
font_path = ROOT / 'godot_project/assets/fonts/NotoSansCJKsc-Regular.otf'
font = TTFont(font_path)
sources = sorted((ROOT / 'godot_project/scripts').rglob('*.gd'))
sources += sorted((ROOT / 'godot_project/data').glob('*.json'))
characters = {c for p in sources for c in p.read_text(encoding='utf-8') if ord(c) > 127 and not c.isspace()}
cmap = font.getBestCmap()
missing = sorted(c for c in characters if ord(c) not in cmap)
report = {'font': str(font_path.relative_to(ROOT)), 'font_sha256': hashlib.sha256(font_path.read_bytes()).hexdigest(),
          'checked_non_ascii_characters': len(characters), 'missing': missing,
          'source_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}
output = ROOT / 'outputs/zh_chapter/font_coverage.json'
output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'{len(characters)} characters checked; {len(missing)} missing')
raise SystemExit(bool(missing))
