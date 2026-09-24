#!/usr/bin/env python3
"""Build an iPad IPC diagnostic from the installed Mac Steam helper.

The package test may run this helper inside the app. It does not provide a
Steam session, account state, ownership result, or gameplay.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True, help='Private ipcserver.arm64 from the Simulator package')
parser.add_argument('--output', type=Path, required=True, help='Fresh ignored output directory')
args = parser.parse_args()
source = args.source.resolve(strict=True)
output = args.output.resolve()
if output.exists():
    parser.error('Output already exists; preserve earlier probe evidence')
output.mkdir(parents=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
shim = output / 'IPCSystemCompat.dylib'
subprocess.run(['xcrun', 'clang', '-Wall', '-Wextra', '-target', 'arm64-apple-ios15.0',
                '-isysroot', sdk, '-dynamiclib', str(ROOT / 'port/de/IPCSystemCompat.c'),
                '-Wl,-reexport_library,' + sdk + '/usr/lib/libSystem.tbd',
                '-Wl,-install_name,@rpath/IPCSystemCompat.dylib', '-o', str(shim)], check=True)
spec = importlib.util.spec_from_file_location('de_adapter', ROOT / 'scripts/prepare-de-load-image.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
helper = output / 'IPCHelperDevice.dylib'
result = adapter.prepare(source, helper, platform='ios-device', dependency_map={
    '/System/Library/Frameworks/CoreServices.framework/CoreServices':
        '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
    '/usr/lib/libSystem.B.dylib': '@loader_path/IPCSystemCompat.dylib'})
if result['instructions_changed'] or not all(item['equal'] for item in result['sections']):
    raise SystemExit('Original helper sections changed')
for image in (shim, helper):
    build = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(image)], text=True)
    if 'platform IOS\n' not in build:
        raise SystemExit('Not a device image: ' + str(image))
(output / 'manifest.json').write_text(json.dumps({
    'scope': 'in-app helper diagnostic; no Steam session, auth or gameplay',
    'helper': result,
}, indent=2) + '\n')
print(helper)
