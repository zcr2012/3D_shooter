"""Portable integrity checks; engine behavior is checked by verify_chapter_zh.gd."""
import hashlib,json,re,wave,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ChineseChapterChecks(unittest.TestCase):
    def test_font_license_and_bytes(self):
        base=ROOT/'godot_project/assets/fonts'
        data=json.loads((base/'provenance.json').read_text())
        self.assertIn('Open Font License', (base/'OFL.txt').read_text())
        for entry in data['files']:
            self.assertEqual(entry['sha256'],hashlib.sha256((ROOT/entry['file']).read_bytes()).hexdigest())

    def test_voice_dialogue_matches_generated_assets(self):
        lines=json.loads((ROOT/'godot_project/data/zh_dialogue.json').read_text())
        manifest=json.loads((ROOT/'godot_project/assets/audio/zh/manifest.json').read_text())
        self.assertEqual({c['id'] for c in manifest['clips']},set(lines))
        self.assertEqual(len(lines),8)
        for clip in manifest['clips']:
            self.assertEqual(clip['text'],lines[clip['id']]['text'])
            self.assertEqual(clip['speaker'],lines[clip['id']]['speaker'])
            self.assertGreater(clip['seconds'],5)
            self.assertEqual(clip['sha256'],hashlib.sha256((ROOT/clip['file']).read_bytes()).hexdigest())

    def test_effects_are_real_pcm_files(self):
        base=ROOT/'godot_project/assets/audio/sfx'
        manifest=json.loads((base/'manifest.json').read_text())
        self.assertEqual(len(manifest['files']),7)
        for file,digest in manifest['files'].items():
            self.assertEqual(digest,hashlib.sha256((ROOT/file).read_bytes()).hexdigest())
            with wave.open(str(ROOT/file)) as audio:
                self.assertEqual(audio.getnchannels(),1)
                self.assertEqual(audio.getsampwidth(),2)
                self.assertEqual(audio.getframerate(),22050)
                self.assertGreater(audio.getnframes(),1000)

    def test_hud_literals_are_chinese_or_keys(self):
        allowed={'WASD','Ctrl','Shift','Tab','Esc'}
        for rel in ['game/hud.gd','urban/urban_hud.gd']:
            source=(ROOT/'godot_project/scripts'/rel).read_text()
            for text in re.findall(r'_(?:text|center)\("([^"\n]+)"',source):
                for word in re.findall(r'[A-Za-z]{3,}',text):
                    self.assertIn(word,allowed, f'{rel}: untranslated {text}')
        operation=(ROOT/'godot_project/scripts/urban/operation.gd').read_text()
        for old in ['CONTROL:', 'WITNESS:', 'SECURE MERCER', 'CONTACTS']:
            self.assertNotIn(old,operation)

    def test_font_is_explicit_for_hud_and_world_signs(self):
        for rel in ['game/hud.gd','game/enemy.gd','game/mission.gd','urban/city_map.gd']:
            self.assertIn('res://assets/fonts/NotoSansCJKsc-Regular.otf',(ROOT/'godot_project/scripts'/rel).read_text())

if __name__=='__main__':unittest.main()
