#!/usr/bin/env python3
"""Create the designated AgePad Simulator on this machine and print its UDID.

A Simulator device is local to one Mac: `simctl create` picks the UDID, so the
scripts resolve it through AGEPAD_SIMULATOR_UDID instead of a literal. Run this
once on a new machine, then export the line it prints.
"""
import argparse
import json
import subprocess
import sys

import de_device


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', default=de_device.DEFAULT_NAME)
    parser.add_argument('--device-type', default=de_device.DEVICE_TYPE)
    parser.add_argument('--runtime', default=de_device.RUNTIME)
    args = parser.parse_args()
    listed = subprocess.run(['xcrun', 'simctl', 'list', 'devices', '-j'],
                            capture_output=True, text=True)
    try:
        groups = json.loads(listed.stdout).get('devices', {})
    except ValueError:
        print('Could not read the Simulator inventory', file=sys.stderr)
        return 1
    runtimes = {key for key in groups}
    for existing in [d for group in groups.values() for d in group]:
        if existing.get('name') == args.name:
            print('Already exists: ' + existing['udid'])
            print(de_device.export_line(existing['udid']))
            return 0
    if args.runtime not in runtimes:
        print('Runtime not installed: ' + args.runtime, file=sys.stderr)
        print('Installed: ' + ', '.join(sorted(runtimes)), file=sys.stderr)
        return 1
    created = subprocess.run(['xcrun', 'simctl', 'create', args.name, args.device_type,
                              args.runtime], capture_output=True, text=True, check=True)
    udid = created.stdout.strip()
    subprocess.run(['xcrun', 'simctl', 'boot', udid], check=True)
    print('Created and booted: ' + udid)
    print(de_device.export_line(udid))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
