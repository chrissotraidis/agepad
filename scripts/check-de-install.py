#!/usr/bin/env python3
"""Read-only preflight for the private Mac-assisted AgePad Simulator workflow."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEVICE = '574671AD-6F61-4558-9528-BF946DDB760A'


def command(args):
    try:
        run = subprocess.run(args, capture_output=True, text=True, timeout=30)
        return run.returncode, run.stdout.strip() or run.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as error:
        return 1, str(error)


def inspect():
    checks = []
    def add(name, passed, detail):
        checks.append(dict(name=name, passed=bool(passed), detail=detail))

    code, output = command(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'])
    try:
        devices = [d for group in json.loads(output)['devices'].values() for d in group
                   if d['state'] == 'Booted'] if code == 0 else []
    except (ValueError, KeyError, TypeError):
        devices = []
    add('sole_designated_simulator', len(devices) == 1 and devices[0]['udid'] == DEVICE,
        ', '.join(d['name'] for d in devices) or 'No booted Simulator detected')
    package = ROOT / 'generated/mac-de-simulator-375'
    required = ['game-client-appkit.json', 'SystemFrameworkCompat.dylib',
                'SignalTrace.dylib', 'MainThreadGraphicsWait.dylib',
                'ResourceFileTrace.dylib', 'OriginalInputTrace.dylib',
                'AudioOutputCompat.dylib']
    missing = [name for name in required if not (package / name).is_file()]
    add('private_runtime', not missing, 'Missing: ' + ', '.join(missing) if missing else
        'Runtime files present; launcher still verifies installed boundary identity')
    code, output = command(['xcrun', 'simctl', 'get_app_container', DEVICE,
                            'local.agepad.de-loader-probe', 'app'])
    add('installed_simulator_app', code == 0, 'Installed' if code == 0 else output)
    code, output = command(['pgrep', '-x', 'steam_osx'])
    add('desktop_steam', code == 0, 'Running' if code == 0 else 'Start desktop Steam')
    _, physical = command(['xcrun', 'devicectl', 'list', 'devices'])
    _, signing = command(['security', 'find-identity', '-v', '-p', 'codesigning'])
    return dict(simulator_preflight_passed=all(c['passed'] for c in checks),
                checks=checks, physical_device_inventory=physical,
                signing_inventory=signing, physical_release_ready=False,
                physical_blockers=[
                    'Device runtime packaging and launch have not passed acceptance',
                    'Host Steam relay is not a demonstrated physical-iPad service solution',
                    'End-user game-data import and on-screen text entry are unfinished',
                    'Real multi-touch, lifecycle and sustained device performance are untested'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true', help='Print structured local diagnostic output')
    args = parser.parse_args()
    result = inspect()
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for check in result['checks']:
            print(('PASS' if check['passed'] else 'FAIL') + ' ' + check['name'] + ': ' + check['detail'])
        print('\nPhysical iPad: NOT READY')
        print(result['physical_device_inventory'])
        print(result['signing_inventory'])
        for blocker in result['physical_blockers']:
            print('- ' + blocker)
    return 0 if result['simulator_preflight_passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
