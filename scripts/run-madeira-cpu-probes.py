#!/usr/bin/env python3
"""Run bounded native FEX tests in the sole authorized, already booted Simulator."""
from pathlib import Path
import json
import subprocess
import time

r = Path(__file__).resolve().parents[1]
device = '574671AD-6F61-4558-9528-BF946DDB760A'
bundle = 'local.agepad.windows-cpu-probe'
inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j']))
booted = [d for group in inventory['devices'].values() for d in group if d['state'] == 'Booted']
if [d['udid'] for d in booted] != [device]:
    raise SystemExit('Expected only the existing AgePad Simulator booted; no devices changed.')
out = r / 'generated/madeira-cpu-probe/runs'
out.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'simctl', 'install', device, str(r / 'generated/madeira-cpu-probe/AgePadCPUProbe.app')], check=True)
container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, bundle, 'data'], text=True).strip())
result_file = container / 'Documents/result.txt'
summary = []
for name, args, expected in [('arithmetic', [], 42), ('dynamic', ['--dynamic'], 42), ('branch', ['--branch-loop'], 1000000)]:
    result_file.unlink(missing_ok=True)
    log_name = f'agepad-cpu-{name}-qualification.log'
    process = subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process',
        f'--stderr=/tmp/{log_name}', device, bundle, *args], capture_output=True, text=True, check=True)
    deadline = time.monotonic() + 15
    while not result_file.exists() and time.monotonic() < deadline:
        time.sleep(0.1)
    if not result_file.exists():
        raise SystemExit(f'{name}: no fresh result; inspect launched process {process.stdout.strip()}')
    result = result_file.read_text()
    log = Path(booted[0]['dataPath']) / 'tmp' / log_name
    (out / f'{name}.log').write_bytes(log.read_bytes())
    (out / f'{name}.txt').write_text(result)
    passed = result.startswith(f'PASS: x64 result = {expected};')
    summary.append({'case': name, 'args': args, 'expected': expected, 'passed': passed,
                    'launch': process.stdout.strip(), 'result': result})
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    if not passed:
        raise SystemExit(f'{name}: {result}')
subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', str(out / 'simulator.png')], check=True)
print(json.dumps(summary, indent=2))
