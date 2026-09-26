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
parser.add_argument('--ipc-load-probe', type=Path, help='Output of build-de-device-ipc-probe.py')
parser.add_argument('--original-steam-module', type=Path,
                    help='Owned unmodified Mac libsteam_api.dylib; staged as inert data for exact module validation')
parser.add_argument('--bundle-id', default='local.agepad.device-de-probe')
parser.add_argument('--steam-app-manifest', type=Path,
                    help="Mac Steam's appmanifest_813780.acf (read only): the installed build the imported files match")
parser.add_argument('--increased-memory-limit', action='store_true',
                    help='Request com.apple.developer.kernel.increased-memory-limit; the profile must grant it')
parser.add_argument('--launch-env', type=Path,
                    help='AGEPAD_* KEY=VALUE settings baked in for tap-to-play launches (AgePadLaunch.env)')
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
memory_key = 'com.apple.developer.kernel.increased-memory-limit'
if args.increased_memory_limit and not decoded['Entitlements'].get(memory_key):
    parser.error('Provisioning profile does not grant the increased memory limit')
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
    if destination.name.startswith(('DEBoundary_', 'DEClientBoundary_')) and device_boundary.is_file():
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
if args.ipc_load_probe:
    for image, dependency in (
        (frameworks / 'steamclient.dylib', '/usr/lib/libSystem.B.dylib'),
        # Valve's support library supplies the Steam client's process ID.
        (frameworks / 'libtier0_s.dylib', '/usr/lib/libSystem.B.dylib'),
        (frameworks / 'SteamModuleSimulator.dylib', '/usr/lib/libSystem.B.dylib'),
        (output / 'Vendor_libsteam_api.dylib.dylib', '@loader_path/DEBoundary_libSystem_B.dylib'),
    ):
        temp = image.with_name(image.name + '.device-ipc-temp')
        result = adapter.prepare(image, temp, platform='ios-device', dependency_map={
            dependency: '@loader_path/IPCSystemCompat.dylib' if image.parent == frameworks
                        else '@executable_path/Frameworks/IPCSystemCompat.dylib'},
            preserve_executable=image.name == 'DEOriginalGame')
        if result['instructions_changed'] or not all(item['equal'] for item in result['sections']):
            raise ValueError('Original Steam section changed in IPC probe: ' + str(image))
        temp.replace(image)
        for item in staged:
            if item['path'] == str(image.relative_to(output)):
                item['action'] += '+local-ipc-dependency'
                break
if args.original_steam_module:
    config_path = output / 'SteamModuleCompat.json'
    config = json.loads(config_path.read_text())
    original = args.original_steam_module.resolve(strict=True)
    if hashlib.sha256(original.read_bytes()).hexdigest() != config['original_sha256']:
        parser.error('Owned original Steam module does not match the pinned build')
    shutil.copy2(original, output / 'OriginalSteamModule.data')
info_path = output / 'Info.plist'
if args.steam_app_manifest:
    # The in-app Steam engine's install record for the imported game: same build
    # and depots as the Mac install the files were copied (and verified) from.
    # Personal fields are dropped; "update only when launched through Steam"
    # (AgePad never does) keeps the engine from downloading on its own.
    lines = [line for line in args.steam_app_manifest.read_text().splitlines()
             if not re.search(r'"(LastOwner|LastPlayed|LastUpdated)"', line)]
    text = re.sub(r'("AutoUpdateBehavior"\s+)"\d+"', r'\1"1"', '\n'.join(lines) + '\n')
    if '"buildid"' not in text or '"813780"' not in text:
        parser.error('Not the AoE II: DE app manifest: ' + str(args.steam_app_manifest))
    (output / 'SteamAppManifest_813780.acf').write_text(text)
info = plistlib.loads(info_path.read_bytes())
info.update({'CFBundleIdentifier': args.bundle_id, 'CFBundleDisplayName': 'AgePad DE Probe',
             'CFBundleSupportedPlatforms': ['iPhoneOS'], 'LSRequiresIPhoneOS': True})
# Tap-to-play reaches the Mac helper on the home network; iPadOS asks once.
info['NSLocalNetworkUsageDescription'] = ('AgePad connects to the AgePad helper on your Mac, '
                                          'which lets the game use your Mac\'s Steam sign-in.')
info_path.write_bytes(plistlib.dumps(info))
# The original localized InfoPlist.strings overrides this diagnostic label.
# Keep the probe visibly distinct from a playable AgePad installation.
for localized in output.rglob('InfoPlist.strings'):
    localized.unlink()
# Normal launch shows the setup screen. Steam relay and original startup are
# opt-in diagnostics; imported data lives only in the app's Documents folder.
(output / 'DeviceSetupGate').write_text('hardware diagnostic; setup shown without opt-in relay\n')
if args.launch_env:
    lines = [line for line in args.launch_env.read_text().splitlines() if line.startswith('AGEPAD_') and '=' in line]
    (output / 'AgePadLaunch.env').write_text('\n'.join(lines) + '\n')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
child = output / 'DeviceChildProbe'
subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-isysroot', sdk,
                str(ROOT / 'port/de/DeviceChildProbe.c'), '-o', str(child)], check=True)
ipc_images = []
if args.ipc_load_probe:
    ipc_root = args.ipc_load_probe.resolve(strict=True)
    for name in ('IPCSystemCompat.dylib', 'IPCHelperDevice.dylib'):
        source_image = ipc_root / name
        if platform(source_image) != 'IOS':
            parser.error('IPC load probe is not an IOS image: ' + str(source_image))
        destination = frameworks / name
        shutil.copy2(source_image, destination)
        ipc_images.append(destination)
shutil.copy2(profile, output / 'embedded.mobileprovision')
entitlements = {'application-identifier': team + '.' + args.bundle_id,
                'com.apple.developer.team-identifier': team, 'get-task-allow': True}
if args.increased_memory_limit:
    entitlements[memory_key] = True
entitlements_path = output.parent / 'device-probe-entitlements.plist'
entitlements_path.write_bytes(plistlib.dumps(entitlements))
for item in staged:
    file = output / item['path']
    if file.name == info['CFBundleExecutable']:
        continue
    subprocess.run(['codesign', '--force', '--sign', args.identity, str(file)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['codesign', '--force', '--sign', args.identity, str(child)], check=True)
for image in ipc_images:
    subprocess.run(['codesign', '--force', '--sign', args.identity, str(image)], check=True)
if args.original_steam_module:
    config['device_translated_sha256'] = hashlib.sha256(
        (frameworks / 'SteamModuleSimulator.dylib').read_bytes()).hexdigest()
    config_path.write_text(json.dumps(config, indent=2) + '\n')
subprocess.run(['codesign', '--force', '--sign', args.identity, '--entitlements',
                str(entitlements_path), str(output)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(output)], check=True)
report = {'scope': 'device launch probe; signing alone proves no Steam session, data import or gameplay',
          'bundle_id': args.bundle_id, 'images': staged,
          'main_sha256': hashlib.sha256((output / info['CFBundleExecutable']).read_bytes()).hexdigest(),
          'child_probe_sha256': hashlib.sha256(child.read_bytes()).hexdigest(),
          'ipc_load_probe': [image.name for image in ipc_images]}
(output.parent / 'device-probe-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Signed {len(staged)} IOS images in {output}')
