#!/usr/bin/env python3
"""Cross-platform launcher. Python 3.10+, no third-party Python requirements.

Set GODOT_BIN / BLENDER_BIN to executable paths, or put them on PATH.
This tool never downloads binaries, invokes a shell, or rewrites the v08 baseline.
"""
import argparse
import glob
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / 'godot_project'


def executable(name):
    explicit = os.environ.get(name.upper() + '_BIN')
    if explicit:
        path = Path(explicit).expanduser()
        if not path.is_file():
            raise SystemExit(f'{name.upper()}_BIN is not a file: {path}')
        return str(path.resolve())
    for alias in ([name, 'godot4'] if name == 'godot' else [name]):
        found = shutil.which(alias)
        if found:
            return found
    if sys.platform == 'win32':
        program_files = os.environ.get('ProgramFiles', 'C:/Program Files')
        local = os.environ.get('LOCALAPPDATA', '')
        patterns = ([f'{program_files}/Blender Foundation/Blender */blender.exe']
                    if name == 'blender' else [
                        f'{program_files}/Godot*/Godot*.exe',
                        f'{local}/Microsoft/WinGet/Packages/GodotEngine.Godot*/Godot*_win64.exe',
                    ])
        candidates = sorted({p for pattern in patterns for p in glob.glob(pattern)}, reverse=True)
        if candidates:
            return candidates[0]
    raise SystemExit(f'{name} not found. Install it or set {name.upper()}_BIN. See docs/PLAY.md.')


def run(args):
    print('>', subprocess.list2cmdline([str(a) for a in args]), flush=True)
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)


def godot(*args):
    run([executable('godot'), '--path', PROJECT, *args])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['doctor', 'import', 'run', 'verify', 'model', 'audit', 'render', 'export-windows'])
    options = parser.parse_args(argv)
    if options.command == 'doctor':
        for engine in ['godot', 'blender']:
            run([executable(engine), '--version'])
        print('Project:', PROJECT)
    elif options.command == 'import':
        godot('--headless', '--editor', '--import')
    elif options.command == 'run':
        godot()
    elif options.command == 'verify':
        godot('--headless', '--editor', '--import')
        for suite in ['verify_production_motion.gd', 'verify_gameplay.gd']:
            godot('--headless', '--script', 'res://tools/' + suite)
        destination = ROOT / 'outputs/v09/motion_verification.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'outputs/production_motion_verification.json', destination)
    elif options.command in ['model', 'audit', 'render']:
        script, source = {
            'model': ('polish_v09.py', 'v08/swat_visual_v08.blend'),
            'audit': ('audit_v09.py', 'v09/swat_visual_v09.blend'),
            'render': ('render_v09.py', 'v09/swat_visual_v09.blend'),
        }[options.command]
        # Explicit export location wins over an unrelated inherited environment.
        env = dict(os.environ, SWAT_EXPORT_DIR=str(PROJECT / 'assets'))
        args = [executable('blender'), '-b', str(ROOT / 'outputs' / source),
                '--python-exit-code', '1', '-P', str(ROOT / 'scripts' / script)]
        print('>', subprocess.list2cmdline(args), flush=True)
        subprocess.run(args, cwd=ROOT, env=env, check=True)
    elif options.command == 'export-windows':
        output = ROOT / 'build' / 'windows'
        output.mkdir(parents=True, exist_ok=True)
        godot('--headless', '--editor', '--import')
        godot('--headless', '--export-release', 'Windows Desktop', output / 'SectorNine.exe')
        print('Exported:', output / 'SectorNine.exe')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
