#!/usr/bin/env python3
"""Download the Steam for Mac client files AgePad needs, on any computer.

AgePad adds eight Steam for Mac libraries to the app. Reading them from the
player's installed Steam broke whenever Steam updated. This fetches the exact
packages pinned in config/steam-mac-client.json from Valve's public client
update server, checks every package and file hash, and writes the files under
OUTPUT in the layout agepad-kit.py --steam expects. It needs no Steam login and
no Mac; nothing is uploaded.

Usage: python3 scripts/fetch-steam-mac.py OUTPUT
"""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SERVER = 'https://client-update.steamstatic.com/'


def main(output):
    pins = json.loads((ROOT / 'config' / 'steam-mac-client.json').read_text(encoding='utf-8'))
    output = Path(output)
    wanted = pins['files']
    done = {}
    for name, package in pins['packages'].items():
        names = [path for path, entry in wanted.items() if entry['package'] == name]
        if not names:
            continue
        with urllib.request.urlopen(SERVER + package['file'], timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != package['sha256']:
            raise SystemExit(f'{name}: download does not match its pinned hash')
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for path in names:
                relative = PurePosixPath(path)
                if relative.is_absolute() or '..' in relative.parts:
                    raise SystemExit(f'unsafe path in pins: {path}')
                content = archive.read(path)
                if hashlib.sha256(content).hexdigest() != wanted[path]['sha256']:
                    raise SystemExit(f'{path}: file does not match its pinned hash')
                target = output.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                done[path] = True
    missing = sorted(set(wanted) - set(done))
    if missing:
        raise SystemExit('pinned files not found in their packages: ' + ', '.join(missing))
    print(f'Steam for Mac {pins["client_version"]}: {len(done)} files in {output}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fetch-steam-mac.py OUTPUT')
    main(sys.argv[1])
