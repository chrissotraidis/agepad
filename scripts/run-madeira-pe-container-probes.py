#!/usr/bin/env python3
"""Run rebuilt signed PE diagnostics only in the sole designated Simulator."""
from pathlib import Path
import json
import subprocess
import time

r = Path(__file__).resolve().parents[1]
device = '574671AD-6F61-4558-9528-BF946DDB760A'
inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
booted = [d for group in inventory['devices'].values() for d in group if d['state'] == 'Booted']
if [d['udid'] for d in booted] != [device]:
    raise SystemExit('Expected only the designated Simulator booted; no devices changed.')
out = r / 'generated/madeira-pe-container-runs'
out.mkdir(parents=True, exist_ok=True)
summary = []
for kind, suffix, bundle, expected in [
    ('fex', '', 'local.agepad.pe-container-probe', 'PASS: real ARM64EC FEX alias functions'),
    ('ntdll', '-ntdll', 'local.agepad.ntdll-container-probe', 'PASS: actual Windows ntdll RtlInitUnicodeString'),
]:
    build = r / ('generated/madeira-pe-container' + suffix)
    subprocess.run(['xcrun', 'simctl', 'install', device, str(build / 'AgePadPEProbe.app')], check=True)
    container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, bundle, 'data'], text=True).strip())
    result_file = container / 'Documents/result.txt'
    result_file.unlink(missing_ok=True)
    log_name = f'agepad-{kind}-signed-container.log'
    launch = subprocess.check_output(['xcrun', 'simctl', 'launch', '--terminate-running-process',
        f'--stderr=/tmp/{log_name}', device, bundle], text=True).strip()
    deadline = time.monotonic() + 15
    while not result_file.exists() and time.monotonic() < deadline:
        time.sleep(0.1)
    result = result_file.read_text() if result_file.exists() else 'FAIL: no fresh result'
    (out / f'{kind}-result.txt').write_text(result)
    log = Path(booted[0]['dataPath']) / 'tmp' / log_name
    if log.exists():
        (out / f'{kind}-runtime.log').write_bytes(log.read_bytes())
    passed = result.startswith(expected)
    summary.append({'kind': kind, 'launch': launch, 'passed': passed, 'result': result,
                    'build': json.loads((build / 'manifest.json').read_text())})
    (out / 'runs.json').write_text(json.dumps(summary, indent=2) + '\n')
    if not passed:
        raise SystemExit(result)
    time.sleep(0.5)  # Allow the main-thread diagnostic text and launch animation to settle.
    subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', str(out / f'{kind}-simulator.png')], check=True)
print(json.dumps([{'kind': row['kind'], 'passed': row['passed'], 'launch': row['launch']} for row in summary], indent=2))
