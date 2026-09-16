#!/usr/bin/env python3
"""Verify reference pins, recursive submodules, cleanliness and disabled push."""
import json
import hashlib
import tarfile
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'dependencies.lock.json').read_text())
failures = []
def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], text=True).strip()
for name, entry in lock.get('optional_backends', {}).items():
    try:
        path = root / entry['path']
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('lock hash mismatch')
        backend = json.loads(path.read_text())
        for relative, expected in backend['files'].items():
            if hashlib.sha256((root / relative).read_bytes()).hexdigest() != expected:
                raise ValueError('input hash mismatch: ' + relative)
    except (OSError, ValueError, KeyError) as error:
        failures.append(name + ': invalid optional backend lock: ' + str(error))
for name, source in lock['sources'].items():
    base = root / 'ref' / name
    for rel, expected in [('', source['commit'])] + [(s['path'], s['commit']) for s in source['submodules']]:
        path = base / rel
        try:
            if git(path, 'rev-parse', 'HEAD') != expected:
                failures.append(name + '/' + rel + ': wrong pin')
            if git(path, 'status', '--porcelain', '--untracked-files=all'):
                failures.append(name + '/' + rel + ': dirty reference')
            if git(path, 'remote', 'get-url', '--push', 'origin') != 'DISABLED-PRIVATE-ONLY':
                failures.append(name + '/' + rel + ': push enabled')
        except subprocess.CalledProcessError:
            failures.append(name + '/' + rel + ': unavailable reference')
for source in lock.get('source_archives', []):
    archive = root / source['archive_path']
    reference = root / source['reference_path']
    try:
        if hashlib.sha256(archive.read_bytes()).hexdigest() != source['sha256']:
            failures.append(source['name'] + ': archive hash mismatch')
            continue
        expected_files = set()
        with tarfile.open(archive) as contents:
            for member in contents.getmembers():
                parts = Path(member.name).parts
                if not parts or parts[0] != reference.name or '..' in parts or member.name.startswith('/'):
                    raise ValueError('unexpected archive path')
                if member.isdir():
                    continue
                if not member.isfile():
                    raise ValueError('unsupported archive member')
                relative = Path(*parts[1:])
                expected_files.add(relative)
                target = reference / relative
                if target.is_symlink() or target.read_bytes() != contents.extractfile(member).read():
                    failures.append(source['name'] + ': modified reference ' + str(relative))
        actual_files = {p.relative_to(reference) for p in reference.rglob('*') if not p.is_dir()}
        if actual_files != expected_files:
            failures.append(source['name'] + ': unexpected reference files')
    except (OSError, ValueError, tarfile.TarError) as error:
        failures.append(source['name'] + ': unavailable/invalid archive reference: ' + str(error))
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print('All locked references and recursive dependencies verified clean and push-disabled.')
