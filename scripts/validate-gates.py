#!/usr/bin/env python3
"""Validate exact-artifact evidence records for a named PRD profile.

This checks record completeness and file identities, not the truth of a
human observation. Every recorded pass still needs review against the PRD.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

BASIC = {1, 2, 4, 5, 8, 9, 10, 11, 12, 13, 36}
BASELINE = {1, 2, 3, 4, 5, *range(8, 26), 31, 32, 36}
PROFILES = {'basic-portability': BASIC, 'scenario-feasibility': BASIC | {14, 15},
            'ipad-singleplayer': BASELINE, 'apple-singleplayer': BASELINE | {26}}

def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def validate(record, profile, root):
    failures = []
    identity = record.get('identity', {})
    for key in ('spec_revision', 'source_lock_sha256', 'patch_sha256', 'input_manifest_sha256', 'ruleset_id', 'artifact_sha256'):
        if not identity.get(key):
            failures.append('Missing identity: ' + key)
    if identity.get('spec_revision') != 'agepad-v2-2026-09-06':
        failures.append('Spec revision mismatch')
    lock = root / 'dependencies.lock.json'
    if not lock.is_file() or sha256(lock) != identity.get('source_lock_sha256'):
        failures.append('Missing or stale source lock identity')
    required = set(PROFILES[profile])
    if record.get('route') == 'R4':
        required.add(7)
    rows = record.get('rows', {})
    for number in sorted(required):
        row = rows.get(str(number), {})
        if row.get('status') != 'pass':
            failures.append('Row {}: {}'.format(number, row.get('status', 'missing')))
            continue
        for field in ('expected', 'observed', 'commands', 'targets'):
            if not row.get(field):
                failures.append('Row {} missing {}'.format(number, field))
        if row.get('identity') != identity:
            failures.append('Row {} identity mismatch'.format(number))
        if not row.get('evidence'):
            failures.append('Row {} missing evidence'.format(number))
        for evidence in row.get('evidence', []):
            path = root / evidence.get('path', '')
            if not path.is_file() or sha256(path) != evidence.get('sha256'):
                failures.append('Row {} missing/changed evidence'.format(number))
    return failures

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', choices=PROFILES, required=True)
    ap.add_argument('--record', type=Path, required=True)
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        errors = validate(json.loads(args.record.read_text()), args.profile, root)
    except (OSError, ValueError, TypeError, KeyError) as error:
        errors = ['Invalid/missing acceptance record: ' + str(error)]
    print(json.dumps({'profile': args.profile, 'status': 'fail' if errors else 'pass', 'errors': errors}, indent=2))
    return 1 if errors else 0

if __name__ == '__main__':
    sys.exit(main())
