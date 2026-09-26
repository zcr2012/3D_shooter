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
        self.assertIn('run/main_scene="res://scenes/mission.tscn"', text)
        self.assertIn('renderer/rendering_method="gl_compatibility"', text)
        self.assertTrue((ROOT / 'godot_project/scenes/main.tscn').is_file())
        self.assertTrue((ROOT / 'outputs/v08/swat_visual_v08.blend').is_file())

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
