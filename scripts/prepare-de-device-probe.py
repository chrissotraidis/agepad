#!/usr/bin/env python3
"""Sign an isolated iPad DE launch probe from a private Simulator candidate.

This does not stage game data, provide Steam services, install, or prove play.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--candidate-root', type=Path, required=True)
parser.add_argument('--boundary', type=Path, required=True, help='Output of build-de-device-runtime.py')
parser.add_argument('--output', type=Path, required=True, help='Fresh .app path')
parser.add_argument('--profile', type=Path, required=True)
parser.add_argument('--identity', required=True)
parser.add_argument('--bundle-id', default='local.agepad.device-de-probe')
args = parser.parse_args()
root = args.candidate_root.resolve(strict=True)
boundary = args.boundary.resolve(strict=True)
output = args.output.resolve()
if output.exists():
    parser.error('Output already exists; preserve the previous candidate')
link = json.loads((boundary / 'device-link-result.json').read_text())
if not link['libraries'] or any(item['exit'] or item['platform'] != 'IOS'
                                for item in link['libraries'].values()):
    parser.error('Device boundary link report is incomplete or failed')
profile = args.profile.resolve(strict=True)
decoded = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(profile)]))
team = decoded['TeamIdentifier'][0]
covered = decoded['Entitlements']['application-identifier']
if covered not in (team + '.*', team + '.' + args.bundle_id):
    parser.error('Provisioning profile does not cover the probe bundle ID')
spec = importlib.util.spec_from_file_location('de_adapter', ROOT / 'scripts/prepare-de-load-image.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
app_source = root / 'candidate.app'
client_source = root / 'package/game-client'
if not (app_source / 'DEOriginalGame').is_file() or not client_source.is_dir():
    parser.error('Candidate root has no complete Simulator game/client package')
shutil.copytree(app_source, output)
frameworks = output / 'Frameworks'
frameworks.mkdir(exist_ok=True)
staged = []

def platform(path):
    result = subprocess.run(['xcrun', 'vtool', '-show-build', str(path)],
                            capture_output=True, text=True)
    match = re.search(r'^\s*platform\s+(\w+)$', result.stdout, re.M) if result.returncode == 0 else None
    return match.group(1) if match else None

def stage(source, destination):
    device_boundary = boundary / destination.name
    if destination.name.startswith('DEBoundary_') and device_boundary.is_file():
        shutil.copy2(device_boundary, destination)
        action = 'device-boundary-link'
    else:
        original_platform = platform(source)
        if original_platform not in ('IOSSIMULATOR', 'MACOS'):
            raise ValueError(f'Unexpected source platform {original_platform}: {source}')
        temp = destination.with_name(destination.name + '.device-temp')
        result = adapter.prepare(source, temp, platform='ios-device',
                                 preserve_executable=destination.name in ('DEOriginalGame', 'DELoaderProbe', 'OriginalEngine'))
        temp.replace(destination)
        action = 'retargeted-' + original_platform
        if not all(section['equal'] for section in result['sections']):
            raise ValueError('Original executable section changed: ' + str(source))
    if platform(destination) != 'IOS':
        raise ValueError('Wrong output platform: ' + str(destination))
    staged.append({'path': str(destination.relative_to(output)), 'action': action})

for file in sorted(output.rglob('*')):
    if file.is_file() and not file.is_symlink() and platform(file):
        source = app_source / file.relative_to(output)
        stage(source, file)
for file in sorted(client_source.glob('*.dylib')):
    if file.name.startswith('original-'):
        continue
    stage(file, frameworks / file.name)
info_path = output / 'Info.plist'
info = plistlib.loads(info_path.read_bytes())
info.update({'CFBundleIdentifier': args.bundle_id, 'CFBundleDisplayName': 'AgePad DE Probe',
             'CFBundleSupportedPlatforms': ['iPhoneOS'], 'LSRequiresIPhoneOS': True})
info_path.write_bytes(plistlib.dumps(info))
# The original localized InfoPlist.strings overrides this diagnostic label.
# Keep the probe visibly distinct from a playable AgePad installation.
for localized in output.rglob('InfoPlist.strings'):
    localized.unlink()
# This package has no on-device Steam connection or imported game data. The
# device boundary shows a setup screen before invoking original startup.
(output / 'DeviceSetupGate').write_text('hardware diagnostic; Steam connection unavailable\n')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
child = output / 'DeviceChildProbe'
subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-isysroot', sdk,
                str(ROOT / 'port/de/DeviceChildProbe.c'), '-o', str(child)], check=True)
shutil.copy2(profile, output / 'embedded.mobileprovision')
entitlements = {'application-identifier': team + '.' + args.bundle_id,
                'com.apple.developer.team-identifier': team, 'get-task-allow': True}
entitlements_path = output.parent / 'device-probe-entitlements.plist'
entitlements_path.write_bytes(plistlib.dumps(entitlements))
for item in staged:
    file = output / item['path']
    if file.name == info['CFBundleExecutable']:
        continue
    subprocess.run(['codesign', '--force', '--sign', args.identity, str(file)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['codesign', '--force', '--sign', args.identity, str(child)], check=True)
subprocess.run(['codesign', '--force', '--sign', args.identity, '--entitlements',
                str(entitlements_path), str(output)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(output)], check=True)
report = {'scope': 'device launch probe only; no game data, Steam session or gameplay proof',
          'bundle_id': args.bundle_id, 'images': staged,
          'main_sha256': hashlib.sha256((output / info['CFBundleExecutable']).read_bytes()).hexdigest(),
          'child_probe_sha256': hashlib.sha256(child.read_bytes()).hexdigest()}
(output.parent / 'device-probe-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Signed {len(staged)} IOS images in {output}')
