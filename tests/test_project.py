"""Fast portable integrity checks; actual gameplay is tested in Godot."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import unittest
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('project_tools', ROOT / 'tools/project.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


def glb(path):
    with path.open('rb') as file:
        magic, version, length = struct.unpack('<III', file.read(12))
        assert magic == 0x46546C67 and version == 2 and length == path.stat().st_size
        size, kind = struct.unpack('<II', file.read(8))
        assert kind == 0x4E4F534A
        return json.loads(file.read(size))


class ProjectChecks(unittest.TestCase):
    def test_python_syntax(self):
        for path in list((ROOT / 'scripts').glob('*.py')) + list((ROOT / 'tools').glob('*.py')):
            with self.subTest(path=path.name):
                ast.parse(path.read_text(encoding='utf-8'), filename=str(path))

    def test_character_contract(self):
        data = glb(ROOT / 'godot_project/assets/swat_operator.glb')
        self.assertEqual(len(data['skins']), 1)
        self.assertEqual(len(data['skins'][0]['joints']), 22)
        self.assertEqual({a['name'] for a in data['animations']}, {
            'IdleArmed', 'WalkArmed', 'RunArmed', 'AimArmed', 'FireArmed', 'ReloadArmed', 'HitReact'})
        self.assertEqual(len(data['meshes']), 3)
        for image in data['images']:
            self.assertIn('bufferView', image, 'Textures must be embedded for portable export')
        self.assertEqual([m['name'] for m in data['materials']], ['SWAT_v08_Atlas'])

    def test_mesh_audit(self):
        data = json.loads((ROOT / 'outputs/v09/visual_audit.json').read_text())
        self.assertEqual(data['exported_glb_sha256'], hashlib.sha256((ROOT / 'godot_project/assets/swat_operator.glb').read_bytes()).hexdigest())
        self.assertEqual(data['source_blend_sha256'], hashlib.sha256((ROOT / 'outputs/v09/swat_visual_v09.blend').read_bytes()).hexdigest())
        self.assertEqual(data['weightless'], 0)
        self.assertLessEqual(data['max_influences'], 4)
        self.assertLess(data['weight_sum_error'], 1e-5)
        self.assertLess(data['total_triangles'], 32000)
        for asset in data['assets'].values():
            self.assertEqual(asset['degenerate_faces'], 0)
        for action in data['actions'].values():
            self.assertEqual(action['non_finite_vertices'], 0)
            self.assertGreater(action['lowest_sole_m'], -0.003)

    def test_main_scene_and_baseline(self):
        text = (ROOT / 'godot_project/project.godot').read_text()
        self.assertIn('run/main_scene="res://scenes/urban_operation.tscn"', text)
        self.assertIn('renderer/rendering_method="gl_compatibility"', text)
        self.assertTrue((ROOT / 'godot_project/scenes/main.tscn').is_file())
        self.assertTrue((ROOT / 'outputs/v08/swat_visual_v08.blend').is_file())


    def test_no_inferred_type_from_untyped_member(self):
        # Godot 4.6 rejects `var x := member...` when `member` has no static type
        # (the session_store.gd:118 CI blocker). Follows `extends "res://..."` chains.
        import re
        root = ROOT / 'godot_project'

        def untyped(path):
            text = path.read_text(encoding='utf-8')
            names = set(re.findall(r'^var (\w+)\s*(?:=(?!=).*)?$', text, re.M))
            parent = re.search(r'^extends "res://(.+?)"', text, re.M)
            return names | (untyped(root / parent.group(1)) if parent else set())

        offenders = []
        for path in root.rglob('*.gd'):
            names = untyped(path)
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                match = re.match(r'\s*var \w+\s*:=\s*(\w+)\s*([.\[]|$)', line)
                if match and match.group(1) in names:
                    offenders.append(f'{path.relative_to(ROOT)}:{number}')
        self.assertEqual(offenders, [])

    def test_urban_asset_integrity(self):
        fps = glb(ROOT / 'godot_project/assets/urban/fps_kit.glb')
        names = {n.get('name') for n in fps['nodes']}
        self.assertTrue({'LeftArm', 'RightArm', 'Magazine', 'Weapon'} <= names)
        self.assertLessEqual(sum(len(m['primitives']) for m in fps['meshes']), 20)
        for image in fps['images']:
            self.assertIn('bufferView', image)
        enemy = glb(ROOT / 'godot_project/assets/urban/contractor.glb')
        self.assertIn('FallArmed', {a['name'] for a in enemy['animations']})
        self.assertEqual(len(enemy['skins'][0]['joints']), 22)
        witness = glb(ROOT / 'godot_project/assets/urban/witness.glb')
        self.assertEqual({a['name'] for a in witness['animations']}, {'Captive', 'Idle', 'Jog', 'Plead'})
        self.assertEqual(len(witness['skins']), 1)
        self.assertEqual(len(witness['skins'][0]['joints']), 17)
        self.assertLessEqual(sum(len(m['primitives']) for m in witness['meshes']), 13)
        materials = {m['name'] for m in witness['materials']}
        self.assertTrue({'Dock uniform', 'Denim', 'Hi-vis vest', 'Skin'} <= materials)

    def test_new_animation_audit(self):
        audit = json.loads((ROOT / 'outputs/urban/asset_audit.json').read_text())
        for name in ['FallArmed', 'StrafeArmed']:
            self.assertEqual(audit[name]['non_finite_vertices'], 0)
            self.assertGreater(audit[name]['lowest_vertex_m'], -.003)
        for file, expected in audit['files'].items():
            self.assertEqual(expected, hashlib.sha256((ROOT / file).read_bytes()).hexdigest())
        self.assertLess(audit['assets']['fps_kit']['triangles'], 6000)
        self.assertLess(audit['assets']['contractor']['triangles'], 32000)
        self.assertLess(audit['assets']['witness']['triangles'], 7000)
        self.assertEqual(audit['assets']['witness']['bones'], 17)
        for name, clip in audit['witness_clips'].items():
            self.assertEqual(clip['non_finite_vertices'], 0, name)
            self.assertGreater(clip['lowest_vertex_m'], -.035, name)

    def test_downloaded_texture_provenance(self):
        manifest = json.loads((ROOT / 'third_party/polyhaven/manifest.json').read_text())
        self.assertEqual(manifest['license'], 'CC0-1.0')
        for item in manifest['files']:
            self.assertEqual(item['sha256'], hashlib.sha256((ROOT / item['file']).read_bytes()).hexdigest())
            self.assertIn('godotengine/godot-demo-projects/blob/', item['mirror_url'])

    def test_texture_imports_unified_vram(self):
        # docs/TEXTURE_IMPORT.md：gl_compatibility 桌面纹理统一 VRAM 压缩（S3TC），
        # 与编辑器 update_imports() 自动改写的终态一致，防止打开编辑器反复产生改动。
        # icon.svg 是 2D/UI 贴图、wav 的 compress/mode 语义不同，均不在本约束内。
        import re
        problems = []
        for path in (ROOT / 'godot_project').rglob('*.png.import'):
            rel = path.relative_to(ROOT)
            text = path.read_text(encoding='utf-8')
            for snippet in ['compress/mode=2', '\npath.s3tc="res://.godot/imported/',
                            '"imported_formats": ["s3tc_bptc"]', '"vram_texture": true']:
                if snippet not in text:
                    problems.append(f'{rel}: 缺少 {snippet.strip()[:36]}')
            if '\npath="res://.godot/imported/' in text:
                problems.append(f'{rel}: 仍存在未压缩的 path= 条目')
            if not re.search(r'(?m)^mipmaps/generate=true$', text):
                problems.append(f'{rel}: 3D 贴图必须生成 mipmaps')
            if not re.search(r'(?m)^detect_3d/compress_to=0$', text):
                problems.append(f'{rel}: detect_3d/compress_to 必须为 0（一次性关闭自动改写）')
        self.assertEqual(problems, [])

    def test_invalid_engine_path_fails_early(self):
        with patch.dict('os.environ', {'GODOT_BIN': str(ROOT / 'missing executable.exe')}):
            with self.assertRaises(SystemExit):
                launcher.executable('godot')

    def test_explicit_engine_path_with_spaces(self):
        with tempfile.TemporaryDirectory(prefix='Engine path with spaces ') as folder:
            path = Path(folder) / 'Godot test.exe'
            path.touch()
            with patch.dict('os.environ', {'GODOT_BIN': str(path)}):
                self.assertEqual(launcher.executable('godot'), str(path.resolve()))


if __name__ == '__main__':
    unittest.main()
