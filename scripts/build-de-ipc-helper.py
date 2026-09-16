#!/usr/bin/env python3
"""Prepare a private original Steam IPC helper for the Simulator experiment.

Does not start services, change the original file, or supply Steam client state.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', type=Path, help='Installed original Mac Steam ipcserver')
p.add_argument('output', type=Path, help='New private output directory')
a = p.parse_args()
source = a.source.resolve(strict=True)
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
repo = Path(__file__).resolve().parents[1]
sdk = Path(subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip())
subprocess.run(['xcrun', 'lipo', str(source), '-thin', 'arm64', '-output', str(out/'ipcserver.arm64')], check=True)
imports = subprocess.check_output(['xcrun', 'nm', '-m', '-u', str(out/'ipcserver.arm64')], text=True)
(out/'imports.txt').write_text(imports)
if '(from CoreServices)' in imports:
    raise SystemExit('This helper imports CoreServices functions; the audited unused-dependency mapping is not applicable.')
shim = out/'IPCSystemCompat.dylib'
subprocess.run(['xcrun', 'clang', '-Wall', '-Wextra', '-target', 'arm64-apple-ios26.0-simulator',
    '-isysroot', str(sdk), '-dynamiclib', str(repo/'port/de/IPCSystemCompat.c'),
    '-Wl,-reexport_library,'+str(sdk/'usr/lib/libSystem.tbd'),
    '-Wl,-install_name,@rpath/IPCSystemCompat.dylib', '-Wl,-compatibility_version,1.0', '-o', str(shim)], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(shim)], check=True)
spec = importlib.util.spec_from_file_location('de_prepare', repo/'scripts/prepare-de-load-image.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
manifest = adapter.prepare(out/'ipcserver.arm64', out/'ipcserver-simulator', preserve_executable=True,
    dependency_map={
        '/System/Library/Frameworks/CoreServices.framework/CoreServices': '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
        '/usr/lib/libSystem.B.dylib': '@loader_path/IPCSystemCompat.dylib'})
if manifest['instructions_changed'] or not all(s['equal'] for s in manifest['sections']):
    raise SystemExit('Original section preservation failed')
(out/'representation.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(out/'ipcserver-simulator')
