#!/usr/bin/env python3
"""Create a private Mac probe bundle using the pinned local dependency build."""
from pathlib import Path
import argparse
import os
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=root / 'generated/AgePadProbe.app')
parser.add_argument('--executable', type=Path, default=root / 'generated/freeaoe-macos/freeaoe')
args = parser.parse_args()
app = args.output.resolve()
if app.exists():
    raise SystemExit('Refusing to replace existing probe bundle; choose a new artifact directory')
macos = app / 'Contents/MacOS'
frameworks = app / 'Contents/Frameworks'
macos.mkdir(parents=True)
frameworks.mkdir()
exe = macos / 'AgePadProbe'
shutil.copy2(args.executable.resolve(), exe)
for source in (root / 'generated/deps/macos/lib').glob('libsfml-*.dylib'):
    target = frameworks / source.name
    if source.is_symlink():
        target.symlink_to(os.readlink(source))
    else:
        shutil.copy2(source, target)
shutil.copytree(root / 'generated/deps/macos/lib/freetype.framework', frameworks / 'freetype.framework', symlinks=True)
subprocess.run(['install_name_tool', '-delete_rpath', str(root / 'generated/deps/macos/lib'), '-add_rpath', '@executable_path/../Frameworks', str(exe)], check=True)
with (app / 'Contents/Info.plist').open('wb') as f:
    plistlib.dump({'CFBundleIdentifier': 'local.agepad.native-probe', 'CFBundleName': 'AgePadProbe', 'CFBundleExecutable': 'AgePadProbe', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '0.0.1', 'NSHighResolutionCapable': True}, f)
subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
print(app)
