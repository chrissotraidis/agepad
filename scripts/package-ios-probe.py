#!/usr/bin/env python3
"""Package a private minimal iPad probe; contains no game data."""
import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess
import re
p = argparse.ArgumentParser()
p.add_argument('--executable', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--angle-frameworks', type=Path, help='Built ANGLE framework directory for this SDK')
a = p.parse_args()
frameworks = []
if a.angle_frameworks:
    frameworks = [a.angle_frameworks / (name + '.framework') for name in ['libEGL', 'libGLESv1_CM', 'libGLESv2']]
    def platform(path):
        text = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(path)], text=True)
        values = re.findall(r'platform\s+(\S+)', text)
        if len(values) != 1:
            p.error('Expected one SDK platform in ' + str(path))
        return values[0]
    expected = platform(a.executable)
    for framework in frameworks:
        if platform(framework / framework.stem) != expected:
            p.error('ANGLE framework SDK does not match executable: ' + str(framework))
if a.output.exists():
    p.error('Output already exists; preserve prior artifact')
a.output.mkdir(parents=True)
shutil.copy2(a.executable, a.output / 'AgePad')
info = dict(CFBundleExecutable='AgePad', CFBundleIdentifier='local.agepad.ipad-probe',
            CFBundleName='AgePad', CFBundleDisplayName='AgePad Probe',
            CFBundlePackageType='APPL', CFBundleInfoDictionaryVersion='6.0',
            CFBundleVersion='1', CFBundleShortVersionString='0.1',
            MinimumOSVersion='18.0' if frameworks else '15.0', UIDeviceFamily=[2],
            UIRequiredDeviceCapabilities=['arm64'], UIRequiresFullScreen=True,
            UIApplicationSupportsIndirectInputEvents=True,
            UIStatusBarHidden=True, UIViewControllerBasedStatusBarAppearance=True,
            UILaunchScreen={}, UISupportedInterfaceOrientations=[
                'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'])
with (a.output / 'Info.plist').open('wb') as f:
    plistlib.dump(info, f)
if frameworks:
    target = a.output / 'Frameworks'
    target.mkdir()
    for framework in frameworks:
        destination = target / framework.name
        shutil.copytree(framework, destination, symlinks=True)
        # Sign nested frameworks before their container.
        for nested in sorted(destination.rglob('*.framework'), key=lambda path: len(path.parts), reverse=True):
            subprocess.run(['codesign', '--force', '--sign', '-', str(nested)], check=True)
        subprocess.run(['codesign', '--force', '--sign', '-', str(destination)], check=True)
    binary = a.output / 'AgePad'
    commands = subprocess.check_output(['otool', '-l', str(binary)], text=True)
    if 'path @executable_path/Frameworks (' not in commands:
        subprocess.run(['install_name_tool', '-add_rpath', '@executable_path/Frameworks', str(binary)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(a.output)], check=True)
print(a.output)
