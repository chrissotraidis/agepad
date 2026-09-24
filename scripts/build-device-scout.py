#!/usr/bin/env python3
"""Build a signed native iPad hardware scout. It contains no game or Steam data."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--profile', type=Path, required=True, help='iOS development provisioning profile that covers the bundle ID and device')
parser.add_argument('--identity', required=True, help='Apple Development signing certificate hash')
parser.add_argument('--bundle-id', default='local.agepad.device-scout')
args = parser.parse_args()
app = args.output.resolve()
if app.exists():
    parser.error('Output already exists; choose a fresh directory')
profile = args.profile.resolve(strict=True)
decoded = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(profile)]))
team = decoded['TeamIdentifier'][0]
covered = decoded['Entitlements']['application-identifier']
if not (covered == team + '.*' or covered == team + '.' + args.bundle_id):
    parser.error('Provisioning profile does not cover ' + args.bundle_id)
app.mkdir(parents=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios17.0', '-isysroot', sdk,
                '-fobjc-arc', '-O2', str(ROOT / 'port/apple/DeviceScout.m'),
                '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'CoreGraphics',
                '-o', str(app / 'AgePadScout')], check=True)
info = {'CFBundleExecutable': 'AgePadScout', 'CFBundleIdentifier': args.bundle_id,
        'CFBundleName': 'AgePad Hardware Scout', 'CFBundleDisplayName': 'AgePad Scout',
        'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '0.1',
        'MinimumOSVersion': '17.0', 'UIDeviceFamily': [2], 'UIRequiresFullScreen': True,
        'UILaunchScreen': {}, 'UIStatusBarHidden': True,
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight']}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
shutil.copy2(profile, app / 'embedded.mobileprovision')
entitlements = {'application-identifier': team + '.' + args.bundle_id,
                'com.apple.developer.team-identifier': team,
                'get-task-allow': True}
entitlements_path = app.parent / 'scout-entitlements.plist'
entitlements_path.write_bytes(plistlib.dumps(entitlements))
subprocess.run(['codesign', '--force', '--sign', args.identity, '--entitlements', str(entitlements_path), str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
result = {'bundle_id': args.bundle_id, 'team': team, 'executable_sha256': hashlib.sha256((app / 'AgePadScout').read_bytes()).hexdigest(),
          'claim': 'Native display/touch/signing scout only; no game, data import, or Steam runtime'}
(app.parent / 'scout-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
print(app)
