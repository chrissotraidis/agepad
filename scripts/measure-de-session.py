#!/usr/bin/env python3
"""Measure observed compositions alongside host load and Simulator inventory.

Read-only: does not launch, stop, or interact with a game. These counters are
composition observations, not scanout timing or engine frame acknowledgements.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess

import de_device
import time

DEVICE = de_device.device_udid()


def inventory():
    data = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'], timeout=10))
    return [{'udid': d['udid'], 'name': d['name']}
            for group in data['devices'].values() for d in group]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path, help='Existing relay run directory')
    parser.add_argument('output', type=Path, help='New JSON evidence file')
    parser.add_argument('--seconds', type=int, default=30)
    args = parser.parse_args()
    if not 5 <= args.seconds <= 300:
        parser.error('Use a 5–300 second observation')
    if args.output.exists():
        parser.error('Preserve prior evidence; use a new output path')
    launch = json.loads((args.run / 'launch.json').read_text())
    expected = str(Path(launch['app']) / 'DEOriginalGame')
    samples, inventories = [], []
    devices = inventory()
    inventories.append({'elapsed': 0, 'devices': devices})
    with (args.run / 'game.stderr').open('rb') as stream:
        stream.seek(0, 2)
        start = previous = time.monotonic()
        partial = b''
        for tick in range(args.seconds):
            time.sleep(max(0, start + tick + 1 - time.monotonic()))
            now = time.monotonic()
            chunk = partial + stream.read()
            boundary = chunk.rfind(b'\n') + 1
            complete, partial = chunk[:boundary], chunk[boundary:]
            count = complete.count(b'time=composition-observation')
            elapsed = now - previous
            samples.append({'elapsed': now - start, 'interval': elapsed,
                            'observed_compositions': count,
                            'compositions_per_second': count / elapsed,
                            'host_load_1m_5m_15m': os.getloadavg()})
            previous = now
            if (tick + 1) % 5 == 0 or tick + 1 == args.seconds:
                inventories.append({'elapsed': time.monotonic() - start,
                                    'devices': inventory()})
    process = subprocess.run(['ps', '-p', str(launch['pid']), '-o', 'comm='],
                             capture_output=True, text=True, timeout=10)
    alive = process.returncode == 0 and process.stdout.strip() == expected
    count = sum(s['observed_compositions'] for s in samples)
    rates = [s['compositions_per_second'] for s in samples]
    sole_device = all([d['udid'] for d in i['devices']] == [DEVICE]
                      for i in inventories)
    report = {'run': str(args.run.resolve()), 'pid': launch['pid'],
              'duration': previous - start, 'observed_compositions': count,
              'average_compositions_per_second': count / (previous - start),
              'interval_throughput_min_median_max':
                  [min(rates), statistics.median(rates), max(rates)],
              'same_game_process_alive_at_end': alive,
              'sole_designated_simulator_at_all_checks': sole_device,
              'samples': samples, 'simulator_inventories': inventories,
              'interpretation': 'Throughput, not frame-time percentiles. '
                                'Compare host load and inventory before attributing changes.'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as output:
        json.dump(report, output, indent=2)
    print(json.dumps({k: v for k, v in report.items()
                      if k not in ('samples', 'simulator_inventories')}, indent=2))


if __name__ == '__main__':
    main()
