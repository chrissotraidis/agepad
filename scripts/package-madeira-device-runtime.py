#!/usr/bin/env python3
"""Stage an unsigned device runtime with verified root PE containers; no install."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--app', type=Path, required=True)
p.add_argument('--containers', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
if a.output.exists():
    p.error('Output exists; preserve previous package')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def device(path):
    output = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(path)], text=True)
    if re.findall(r'platform\s+(\S+)', output) != ['IOS']:
        p.error('Expected iOS device Mach-O: ' + str(path))

device(a.app / 'Madeira')
names = ['ntdll', 'xtajit64', 'ucrtbase', 'kernel32', 'kernelbase',
         'd3d11', 'dxgi', 'winemetal', 'gdi32', 'user32', 'advapi32',
         'win32u', 'sechost', 'msvcrt']
inputs = {}
for name in names:
    folder = a.containers / name
    m = json.loads((folder / 'manifest.json').read_text())
    source = Path(m['source'])
    dylib = folder / 'AgePadPEProbe.app/Frameworks/PEContainer.dylib'
    if (m.get('platform') != 'IOS' or not m.get('immutable_prefix_preserved') or
            sha(source) != m['source_sha256'] or sha(dylib) != m['dylib_sha256']):
        p.error('Stale or incompatible container: ' + name)
    device(dylib)
    inputs[name] = (m, source, dylib)

app = a.output / 'Madeira.app'
shutil.copytree(a.app, app)
frameworks = app / 'Frameworks'
frameworks.mkdir(exist_ok=True)
for name, (m, source, dylib) in inputs.items():
    shutil.copy2(source, app / 'arm64ec-windows' / (name + '.dll'))
    shutil.copy2(dylib, frameworks / ('PEContainer.dylib' if name == 'ntdll' else name + '.dll.dylib'))
info = plistlib.loads((app / 'Info.plist').read_bytes())
info['CFBundleIdentifier'] = 'local.agepad.device-runtime-probe'
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
# Check all Mach-O files staged by the app template too; PE DLLs are data.
for path in app.rglob('*'):
    if path.is_file():
        with path.open('rb') as f:
            magic = f.read(4)
        if magic in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
            device(path)
manifest = {'app': str(app.resolve()), 'native_sha256': sha(app / 'Madeira'),
            'containers': {name: m for name, (m, _, _) in inputs.items()},
            'launch_environment': {'AGEPAD_DEVICE_SIGNED_STARTUP': '1',
                                   'AGEPAD_TEST_EXE': 'cube-x64.exe', 'MADEIRA_USD_TIME': '1'},
            'signed_for_device': False, 'executed': False,
            'scope': 'Root-process device probe package; no child banks, auth, DE or multiplayer proof'}
(a.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(a.output / 'README.md').write_text(
    '# Device runtime probe — not yet executed\n\n'
    'Unsigned app with ad-hoc container signatures. Provision and sign the nested '
    'code and app using the user\'s team before installation. No provisioning is supplied here.\n\n'
    'Launch with the environment in manifest.json. Enable JIT through the existing '
    'StikDebug flow, then use the existing “x64 DX11 cube” action. '
    'The device setup switch configures containers only; it never bypasses debugger '
    'or pool-allocation checks. Capture launch logs, fallback pool selection, '
    'translated execution, actual drawing and memory on the physical device. '
    'A cube is a graphics gate, not DE gameplay or an FPS benchmark.\n')
print(app)
