#!/usr/bin/env python3
"""Give the installed Simulator app the game's own icon and display name.

Uses the icon PNGs already staged from the Mac bundle (GameIcons/). Writes
loose iPad icon files plus the CFBundleIcons~ipad plist entries, then re-signs
ad hoc. Simulator only; device bundles need an asset catalog and real signing.
"""
import plistlib
import subprocess
import argparse
import re

import de_device
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, help='Candidate app bundle to prepare before installation')
args = parser.parse_args()
DEVICE = de_device.device_udid()
BUNDLE = 'local.agepad.de-loader-probe'
app = args.app or Path(subprocess.check_output(
    ['xcrun', 'simctl', 'get_app_container', DEVICE, BUNDLE, 'app'], text=True).strip())
source = app / 'GameIcons/icon_512x512.png'
assert source.is_file(), 'staged GameIcons missing'
sizes = {'AppIcon76x76~ipad.png': 76, 'AppIcon76x76@2x~ipad.png': 152, 'AppIcon83.5x83.5@2x~ipad.png': 167,
         'AppIcon60x60@2x.png': 120, 'AppIcon40x40@2x~ipad.png': 80, 'AppIcon29x29@2x~ipad.png': 58}
for name, px in sizes.items():
    subprocess.run(['sips', '-s', 'format', 'png', '-z', str(px), str(px), str(source), '--out', str(app / name)],
                   check=True, capture_output=True)
info = plistlib.loads((app / 'Info.plist').read_bytes())
files = ['AppIcon29x29', 'AppIcon40x40', 'AppIcon60x60', 'AppIcon76x76', 'AppIcon83.5x83.5']
icons = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': files, 'UIPrerenderedIcon': False}}
info['CFBundleIcons'] = icons
info['CFBundleIcons~ipad'] = icons
info['CFBundleDisplayName'] = 'AgePad'
info['CFBundleName'] = 'AgePad'
info['CFBundleVersion'] = str(int(info.get('CFBundleVersion', '1')) + 1)
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
for localized in app.glob('*.lproj/InfoPlist.strings'):
    raw = localized.read_bytes()
    if not raw.startswith((b'\xfe\xff', b'\xff\xfe')):
        continue
    value = raw.decode('utf-16')
    value, count = re.subn(r'("CFBundleDisplayName"\s*=\s*")[^"]*(";)',
                           r'\g<1>AgePad\2', value, count=1)
    if count:
        encoding = 'utf-16-be' if raw.startswith(b'\xfe\xff') else 'utf-16-le'
        localized.write_bytes(raw[:2] + value.encode(encoding))
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
print('Icon and name applied; relaunch or reboot the Simulator for SpringBoard to refresh')
