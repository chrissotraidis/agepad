#!/usr/bin/env python3
"""Build a CPU-only Simulator probe against source-built FEX static archives."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess

r = Path(__file__).resolve().parents[1]
f = r / 'worktrees/madeira/FEX'
b = r / 'generated/madeira-fex-sim'
a = r / 'generated/madeira-cpu-probe/AgePadCPUProbe.app'
a.mkdir(parents=True, exist_ok=True)
exe = a / 'AgePadCPUProbe'
exe.unlink(missing_ok=True)
cmd = ['xcrun', '--sdk', 'iphonesimulator', 'clang++', '-target', 'arm64-apple-ios17.0-simulator',
       '-isysroot', subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip(),
       '-std=c++20', '-fobjc-arc', '-O2']
for p in [f/'FEXCore/include', f/'FEXHeaderUtils', f/'CodeEmitter', f/'External/fmt/include',
          f/'External/range-v3/include', f/'External/unordered_dense/include', b, b/'include', b/'FEXCore/Source', f]:
    cmd += ['-I', str(p)]
cmd += [str(r/'port/windows/FEXProbe.mm')]
for p in ['FEXCore/Source/libFEXCore.a', 'FEXCore/Source/libFEXCore_Base.a', 'FEXCore/Source/libJemallocLibs.a',
          'External/fmt/libfmt.a', 'External/cephes/libcephes_128bit.a', 'External/xxhash/cmake_unofficial/libxxhash.a',
          'External/SoftFloat-3e/libsoftfloat_3e.a']:
    cmd += [str(b/p)]
cmd += ['-framework', 'UIKit', '-framework', 'Foundation', '-o', str(exe)]
x = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(a.parent/'build.log').write_text(x.stdout)
if x.returncode:
    print(x.stdout[-8000:])
    raise SystemExit(x.returncode)
plist = {'CFBundleExecutable': exe.name, 'CFBundleIdentifier': 'local.agepad.windows-cpu-probe',
         'CFBundleName': 'AgePad CPU Probe', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1',
         'CFBundleShortVersionString': '0.1', 'MinimumOSVersion': '17.0', 'UIDeviceFamily': [2], 'UILaunchScreen': {}}
(a/'Info.plist').write_bytes(plistlib.dumps(plist))
subprocess.run(['codesign', '--force', '--sign', '-', str(a)], check=True)
(a.parent/'build-manifest.json').write_text(json.dumps({'command': cmd, 'sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                                                     'purpose': 'CPU probe, not Windows or game execution'}, indent=2)+'\n')
print(a)
