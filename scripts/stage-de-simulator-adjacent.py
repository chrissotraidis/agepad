#!/usr/bin/env python3
"""Restore genuine adjacent DE inputs after a Simulator app installation.

Engineering staging only: not a device installer or Steam authentication setup.
simctl install replaces the bundle container, including its adjacent inputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import de_device

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', type=Path)
p.add_argument('manifest', type=Path)
a = p.parse_args()
device = de_device.device_udid()
boot = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
assert [d['udid'] for ds in boot['devices'].values() for d in ds] == [device]
app = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device,
    'local.agepad.de-loader-probe', 'app'], text=True).strip())
source = a.source.resolve()
parent = app.parent
assert source != parent and source not in parent.parents
assert 'CoreSimulator' in parent.parts and device in parent.parts

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

frameworks = source / 'Age Of Empires II.app/Contents/Frameworks'
data = source / 'AgeOfEmpires2Data'
config = json.loads((app / 'SteamModuleCompat.json').read_text())
assert digest(frameworks / 'libsteam_api.dylib') == config['original_sha256']
assert digest(app / 'Frameworks/SteamModuleSimulator.dylib') == config['translated_sha256']
assert data.is_dir()
assert not (parent / 'Frameworks').exists() and not (parent / 'AgeOfEmpires2Data').exists()
a.manifest.parent.mkdir(parents=True, exist_ok=True)
record = {'app': str(app), 'source': str(source), 'complete': False,
          'engineering_adjacent_layout': True, 'resource_name_policy': 'preserve_source',
          'verified': {}}
a.manifest.write_text(json.dumps(record, indent=2) + '\n')
for src, name in [(frameworks, 'Frameworks'), (data, 'AgeOfEmpires2Data')]:
    subprocess.run(['cp', '-cR', str(src), str(parent / name)], check=True)
assert digest(parent / 'Frameworks/libsteam_api.dylib') == config['original_sha256']
for name in ['resources', 'widgetui']:
    original = data / name
    root = parent / 'AgeOfEmpires2Data' / name
    entries = list(original.rglob('*'))
    assert not any(f.is_symlink() for f in entries)
    # exists() cannot detect case-only corruption on a case-insensitive host.
    # Compare directory entry spelling, then file contents, against the source.
    expected_names = {str(f.relative_to(original)) for f in entries}
    actual_names = {str(f.relative_to(root)) for f in root.rglob('*')}
    assert actual_names == expected_names, 'Staging changed resource names'
    hashes = {str(f.relative_to(original)): digest(f) for f in entries if f.is_file()}
    for relative, expected in hashes.items():
        assert digest(root / relative) == expected, relative
    record['verified'][name] = {'verified_files': len(hashes), 'sha256': hashes}
    a.manifest.write_text(json.dumps(record, indent=2) + '\n')
record['complete'] = True
a.manifest.write_text(json.dumps(record, indent=2) + '\n')
print('PASS: genuine adjacent Steam library and data staged; original names and hashes verified')
