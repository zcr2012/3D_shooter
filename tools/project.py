#!/usr/bin/env python3
"""Cross-platform launcher. Python 3.10+, no third-party Python requirements.

Set GODOT_BIN / BLENDER_BIN to executable paths, or put them on PATH.
This tool never downloads binaries, invokes a shell, or rewrites the v08 baseline.
"""
import argparse
import glob
import os
import re
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


SUITES = ['verify_production_motion.gd', 'verify_gameplay.gd', 'verify_urban.gd',
          'verify_chapter_zh.gd', 'verify_session.gd']


def annotate(level, title, text):
    """GitHub annotations are the only CI channel readable without log/artifact downloads."""
    if not os.environ.get('GITHUB_ACTIONS') or not text:
        return
    for start in range(0, min(len(text), 7500), 2500):
        detail = text[start:start+2500].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::{level} title={title}::' + detail, flush=True)


def execute(args, timeout=240):
    """Run one engine command; return (failed, output). Never raises on engine failure."""
    print('>', subprocess.list2cmdline([str(a) for a in args]), flush=True)
    try:
        result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=timeout)
        output = result.stdout + result.stderr
        failed = result.returncode != 0 or 'SCRIPT ERROR:' in output or '\nERROR:' in output \
            or output.startswith('ERROR:')
    except subprocess.TimeoutExpired as error:
        def text(value):
            return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else (value or '')
        output = text(error.stdout) + text(error.stderr) + f'\nCommand exceeded {timeout} seconds.'
        failed = True
    print(output, flush=True)
    return failed, re.sub(r'\x1b\[[0-9;]*m', '', output)


def diagnostics(output):
    tags = ['ERROR', 'Error', ' at:', 'GDScript', '[FAIL]', 'exceeded', 'watchdog']
    selected = [line.strip() for line in output.splitlines() if any(tag in line for tag in tags)]
    unique = list(dict.fromkeys(selected))
    return '\n'.join(unique) if unique else output[-3000:]


def summary(output):
    passed = len(re.findall(r'^\[PASS\]', output, re.M))
    failed = len(re.findall(r'^\[FAIL\]', output, re.M))
    lines = [line.strip() for line in output.splitlines()
             if re.search(r'\d+ checks?, \d+ failures?|MOTION (PASS|FAIL)', line)]
    counted = f'[PASS]x{passed} [FAIL]x{failed}' if passed or failed else ''
    return ' | '.join(filter(None, [counted] + lines[-2:]))


def run(args):
    failed, output = execute(args)
    if failed:
        annotate('error', 'engine', diagnostics(output))
        raise SystemExit(1)


def godot(*args):
    run([executable('godot'), '--path', PROJECT, *args])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['doctor', 'import', 'run', 'verify', 'model', 'audit', 'render', 'model-urban', 'audit-urban', 'render-urban', 'export-windows'])
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
        # Run every suite even after a failure (except parse errors), so one CI round exposes all regressions.
        engine = executable('godot')
        failures = []
        failed, output = execute([engine, '--path', PROJECT, '--headless', '--editor', '--import'])
        if failed:
            failures.append('import')
            annotate('error', 'import', diagnostics(output))
        parse_error = ''
        for suite in SUITES:
            if parse_error:
                # A GDScript parse error makes later suites hang until their watchdog
                # (4 min each) and report the same cascade; stop and point at the cause.
                print(f'SUITE {suite}: SKIPPED after parse error', flush=True)
                failures.append(suite)
                continue
            failed, output = execute([engine, '--path', PROJECT, '--headless', '--script', 'res://tools/' + suite])
            line = summary(output) or ('no summary line' if failed else 'completed')
            print(f'SUITE {suite}: {"FAIL" if failed else "PASS"} {line}', flush=True)
            if failed:
                failures.append(suite)
                annotate('error', suite, (line + '\n' + diagnostics(output)).strip())
                found = re.search(r'Parse Error: .*|at: GDScript::reload \(res://[^)]+\)', output)
                if 'Parse Error' in output and found:
                    parse_error = found.group(0)
            else:
                annotate('notice', suite, 'PASS ' + line)
        motion = ROOT / 'outputs/production_motion_verification.json'
        if motion.is_file():
            destination = ROOT / 'outputs/v09/motion_verification.json'
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(motion, destination)
        if failures:
            print('FAILED:', ', '.join(failures), flush=True)
            raise SystemExit(1)
        print('All engine suites passed.', flush=True)
    elif options.command in ['model-urban', 'audit-urban', 'render-urban']:
        scripts = {
            'model-urban': ['build_urban_assets.py', 'build_urban_enemy.py',
                            'build_urban_witness.py', 'audit_urban_assets.py'],
            'audit-urban': ['audit_urban_assets.py'],
            'render-urban': ['render_urban_fps.py'],
        }[options.command]
        for script in scripts:
            run([executable('blender'), '-b', '--python-exit-code', '1',
                 '-P', ROOT / 'scripts' / script])
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
