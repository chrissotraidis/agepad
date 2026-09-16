#!/usr/bin/env python3
"""Inventory a supplied local directory without executing its contents.

Reject links, special files, case collisions, excessive size/count and drift.
Optionally make a separate APFS clone snapshot and verify every file hash.
Output contains private paths and must remain in ignored private storage.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import zlib


def digest(path):
    before = path.stat()
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    after = path.stat()
    if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
        raise ValueError('Input changed while hashing: ' + str(path))
    return h.hexdigest()


def inventory(root):
    rows, names, total = [], set(), 0
    for parent, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            p = Path(parent) / name
            relative = p.relative_to(root).as_posix()
            key = relative.casefold()
            if key in names:
                raise ValueError('Case collision: ' + relative)
            names.add(key)
            st = p.lstat()
            if stat.S_ISLNK(st.st_mode) or not (stat.S_ISREG(st.st_mode) or stat.S_ISDIR(st.st_mode)):
                raise ValueError('Link/special file rejected: ' + relative)
            if stat.S_ISREG(st.st_mode):
                total += st.st_size
                rows.append({'path': relative, 'size': st.st_size})
                if len(rows) > 250000 or total > 40 * 1024**3:
                    raise ValueError('Input exceeds file-count/size budget')
    for row in sorted(rows, key=lambda r: r['path']):
        row['sha256'] = digest(root / row['path'])
    return sorted(rows, key=lambda r: r['path'])


def inspect(root, rows):
    paths = {r['path'] for r in rows}
    hd = '221380_install.vdf' in paths and 'AoK HD.exe' in paths and 'resources/_common/dat/empires2_x1_p1.dat' in paths
    headers = {}
    for path in sorted(paths):
        if path.startswith('resources/_common/dat/empires2'):
            with (root / path).open('rb') as f:
                data = f.read(4096)
            try:
                headers[path] = zlib.decompressobj(-15).decompress(data, 32).hex()
            except zlib.error:
                headers[path] = 'unrecognized compression: ' + data[:16].hex()
    return {'edition': 'AoE II HD/2013' if hd else 'unknown',
            'edition_confidence': 'high-layout-and-install-marker' if hd else 'unknown',
            'exact_revision': None, 'exact_revision_confidence': 'unknown',
            'steam_app_id': 221380 if hd else None, 'steam_build_id': None,
            'source_platform': 'Windows' if hd else 'unknown',
            'languages': sorted(p.name for p in (root / 'resources').iterdir() if p.is_dir() and not p.name.startswith('_')) if (root / 'resources').is_dir() else [],
            'data_headers': headers, 'compatibility': 'unverified',
            'campaign_files': sorted(p for p in paths if p.endswith(('.cpn', '.cpx'))),
            'expansions': 'unverified; inventory retained', 'mods': 'unknown',
            'ruleset_id': 'aok-aoc-classic-candidate-v1'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source', type=Path)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--snapshot', type=Path)
    args = ap.parse_args()
    if args.source.is_symlink():
        raise ValueError('Source root must not be a symlink')
    source = args.source.resolve(strict=True)
    if not source.is_dir():
        raise ValueError('Only installed directories are accepted; archives need separate safe intake')
    if args.output.exists():
        raise ValueError('Refusing to overwrite an existing manifest')
    rows = inventory(source)
    content_hash = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    record = inspect(source, rows)
    record.update({'input_set_id': 'hd-' + content_hash[:16], 'source': str(source),
                   'files': rows, 'file_count': len(rows), 'size_bytes': sum(r['size'] for r in rows),
                   'content_manifest_sha256': content_hash, 'snapshot_verified': False})
    if args.snapshot:
        snapshot = args.snapshot.absolute()
        if snapshot.exists() or source == snapshot or source in snapshot.parents:
            raise ValueError('Snapshot must be new and outside the source')
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        if shutil.disk_usage(snapshot.parent).free < record['size_bytes'] + 2 * 1024**3:
            raise ValueError('Insufficient storage for full-copy fallback plus 2 GiB reserve')
        # macOS cp -c clones data blocks, never hardlinks files to originals.
        subprocess.run(['/bin/cp', '-cR', str(source), str(snapshot)], check=True)
        if inventory(snapshot) != rows or inventory(source) != rows:
            raise ValueError('Snapshot/source hash mismatch; preserve failed snapshot for investigation')
        for parent, dirs, files in os.walk(snapshot):
            for name in files:
                p = Path(parent) / name
                p.chmod(p.stat().st_mode & ~0o222)
        record.update({'snapshot': str(snapshot), 'snapshot_verified': True})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as f:
        json.dump(record, f, sort_keys=True, indent=2)
        f.write('\n')
    print(json.dumps({k: record[k] for k in ['input_set_id', 'edition', 'exact_revision', 'file_count', 'size_bytes', 'content_manifest_sha256', 'snapshot_verified']}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
