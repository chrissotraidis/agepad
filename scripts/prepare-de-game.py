#!/usr/bin/env python3
"""Add your owned Age of Empires II: DE (Mac edition) to the AgePad Simulator app.

One command for the Mac test flow: find the Steam installation, verify it is the
build this runtime was adapted for, stage the game data next to the installed
app (preserving original filenames), run the launch preflight and optionally
start a session. It never modifies the Steam installation.

This prepares the private Simulator candidate. It is not a physical-iPad
installer and it does not create a standalone Steam session.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

import de_device

ROOT = Path(__file__).resolve().parents[1]
DEVICE = de_device.device_udid()
BUNDLE = 'local.agepad.de-loader-probe'
STEAM_DEFAULT = Path.home() / 'Library/Application Support/Steam/steamapps/common/AoE2DE'
SUPPORTED = {
    'bundle_version': '488492.107976',
    'executable_sha256': 'b40e57e9d77877a59c76f73b515635dfc2d9d39db7d1026d185b06da9f6dfa2b',
    'steam_api_sha256': '7d4991c162d283fef829c287217767326649f02fdcb57e4366e441255ea87d91',
    'data_dirs': ['resources', 'widgetui', 'wwise', 'modes'],
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def step(name, ok, detail):
    sys.stdout.flush()
    print(('PASS ' if ok else 'FAIL ') + name + ': ' + detail)
    sys.stdout.flush()
    return ok


def verify_source(source):
    app = source / 'Age Of Empires II.app'
    data = source / 'AgeOfEmpires2Data'
    if not app.is_dir() or not data.is_dir():
        return step('source_layout', False, 'Expected "Age Of Empires II.app" and AgeOfEmpires2Data in ' + str(source))
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    version = info.get('CFBundleVersion')
    ok = step('game_version', version == SUPPORTED['bundle_version'],
              'Found ' + str(version) + ', supported ' + SUPPORTED['bundle_version'])
    exe = digest(app / 'Contents/MacOS/Age Of Empires II')
    ok &= step('executable_identity', exe == SUPPORTED['executable_sha256'],
               'Executable hash ' + exe[:16] + ('' if exe == SUPPORTED['executable_sha256'] else ' does not match the adapted build'))
    api = digest(app / 'Contents/Frameworks/libsteam_api.dylib')
    ok &= step('steam_library_identity', api == SUPPORTED['steam_api_sha256'], 'libsteam_api ' + api[:16])
    missing = [d for d in SUPPORTED['data_dirs'] if not (data / d).is_dir()]
    ok &= step('game_data_present', not missing, 'Missing: ' + ', '.join(missing) if missing else 'resources, widgetui, wwise, modes present')
    return ok


def simulator_state():
    out = subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'], capture_output=True, text=True)
    booted = [d for g in json.loads(out.stdout or '{"devices":{}}')['devices'].values() for d in g if d['state'] == 'Booted']
    return [d['udid'] for d in booted]


def app_container():
    out = subprocess.run(['xcrun', 'simctl', 'get_app_container', DEVICE, BUNDLE, 'app'], capture_output=True, text=True)
    return Path(out.stdout.strip()) if out.returncode == 0 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--source', type=Path, default=STEAM_DEFAULT, help='Steam AoE2DE folder (default: the Steam library)')
    parser.add_argument('--launch', metavar='RUN_NAME', help='After preparation, start a session with this fresh run name')
    parser.add_argument('--seconds', type=int, default=3600)
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    print('Source:', source)
    if not verify_source(source):
        return 1

    booted = simulator_state()
    if booted != [DEVICE]:
        if not booted:
            print('Booting the designated AgePad G5 iPad Simulator')
            subprocess.run(['xcrun', 'simctl', 'boot', DEVICE], check=True)
            subprocess.run(['open', '-a', 'Simulator'], check=False)
        else:
            return not step('sole_designated_simulator', False, 'Shut down other Simulators first: ' + ', '.join(booted))
    step('sole_designated_simulator', True, 'AgePad G5 iPad')

    app = app_container()
    if not app:
        return not step('installed_app', False, 'The AgePad runtime app is not installed on this Simulator; the private candidate must be installed first')
    step('installed_app', True, str(app))

    package = de_device.package_dir()
    build_record = package.parent / 'bootstrap.json'
    if build_record.is_file():
        built_version = json.loads(build_record.read_text()).get('stages', {}).get('steam', {}).get('bundle_version')
        if built_version and built_version != SUPPORTED['bundle_version']:
            return not step('runtime_game_version', False,
                            'Steam updated since this AgePad runtime was built (' + built_version +
                            ' → ' + SUPPORTED['bundle_version'] + '). Rebuild into a fresh directory first')
        installed_record = package.parent / 'package.json'
        if installed_record.is_file():
            recorded_app = json.loads(installed_record.read_text()).get('installed_app')
            if recorded_app and Path(recorded_app) != app:
                return not step('installed_app_identity', False,
                                'The installed app differs from the selected runtime package. Reinstall that candidate before importing data')

    parent = app.parent
    staged = parent / 'AgeOfEmpires2Data'
    if staged.is_dir() and (parent / 'Frameworks').is_dir():
        sample = staged / 'resources/_common/drs/graphics/u_vil_male_villager_idleA_x1.sld'
        step('game_data_staged', sample.is_file(), 'Already staged; original-case sample ' + ('present' if sample.is_file() else 'MISSING'))
    else:
        print('Staging game data next to the app (about 19 GB, copy-on-write where possible)', flush=True)
        manifest = ROOT / 'generated/prepare-de-game/staging-manifest.json'
        run = subprocess.run([sys.executable, str(ROOT / 'scripts/stage-de-simulator-adjacent.py'), str(source), str(manifest)])
        if not step('game_data_staged', run.returncode == 0, 'Staging ' + ('verified' if run.returncode == 0 else 'failed; see output above')):
            return 1

    pre = subprocess.run([sys.executable, str(ROOT / 'scripts/check-de-install.py'), '--json'],
                         capture_output=True, text=True)
    if not pre.stdout:
        print(pre.stderr or 'Preflight produced no result')
        return 1
    report = json.loads(pre.stdout)
    for check in report['checks']:
        print(('PASS ' if check['passed'] else 'FAIL ') + check['name'] + ': ' + check['detail'])
    if pre.returncode != 0:
        print('Preflight failed; fix the items above before launching')
        return 1
    print('Physical iPad install remains unavailable: this is a Mac-assisted Simulator package.')
    if args.launch:
        os.execv(sys.executable, [sys.executable, str(ROOT / 'scripts/recover-de-session.py'), args.launch, '--seconds', str(args.seconds)])
    print('Ready. Launch with: python3 scripts/recover-de-session.py <run-name> --seconds 1800')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
