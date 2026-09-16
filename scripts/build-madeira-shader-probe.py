#!/usr/bin/env python3
"""Build a Simulator DXMT shader-component diagnostic from pinned Wine fixture."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import subprocess

r = Path(__file__).resolve().parents[1]
source = r / 'worktrees/madeira'
out = r / 'generated/madeira-shader-probe'
app = out / 'AgePadShaderProbe.app'
app.mkdir(parents=True, exist_ok=True)
fixture_source = source / 'wine/dlls/d3d11/tests/d3d11.c'
s = fixture_source.read_text()
start = s.index('static const DWORD default_vs_code[]')
end = s.index('\n    };', start)
words = re.findall(r'0x[0-9a-f]+', s[start:end])
(out / 'fixture.h').write_text('// Wine default_vs_code; LGPL-2.1-or-later. Generated, not game content.\n'
    'static const uint32_t shader_fixture[] = {' + ','.join(words) + '};\n')
exe = app / 'AgePadShaderProbe'
exe.unlink(missing_ok=True)
cmd = ['xcrun', '--sdk', 'iphonesimulator', 'clang++', '-target', 'arm64-apple-ios18.0-simulator',
       '-isysroot', subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip(),
       '-std=c++20', '-fobjc-arc', '-O2', '-I', str(out), '-I', str(source / 'research/dxmt/src/airconv'),
       str(r / 'port/windows/ShaderProbe.mm'), str(source / 'app/Madeira/libdxmt_combined.a'),
       '-framework', 'UIKit', '-framework', 'Metal', '-o', str(exe)]
result = subprocess.run(cmd, capture_output=True, text=True)
(out / 'build.log').write_text(result.stdout + result.stderr)
if result.returncode:
    print(result.stderr[-6000:])
    raise SystemExit(result.returncode)
(app / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleExecutable': exe.name, 'CFBundleIdentifier': 'local.agepad.shader-probe',
    'CFBundleName': 'AgePad Shader Probe', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1',
    'CFBundleShortVersionString': '0.1', 'MinimumOSVersion': '18.0', 'UIDeviceFamily': [2], 'UILaunchScreen': {}}))
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
(out / 'build-manifest.json').write_text(json.dumps({
    'command': cmd, 'sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'fixture_source': str(fixture_source), 'fixture_source_sha256': hashlib.sha256(fixture_source.read_bytes()).hexdigest(),
    'purpose': 'DXMT shader component, not Windows, game execution, or FPS measurement'}, indent=2) + '\n')
print(app)
