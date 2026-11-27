#!/usr/bin/env python3
"""Re-pin a base app's Steam for Mac files to the ones fetch-steam-mac.py downloads.

Usage: python3 scripts/repin-steam.py BASE.ipa STEAM_DIR OUT.ipa

The base app's AgePadKit.json records, for each Steam library it adds, the
SHA-256 of the source file and the header edits applied to it. Earlier releases
pinned the files of the maintainer's installed Steam, which Valve updates. This
points those entries at the files from Valve's pinned client packages
(config/steam-mac-client.json), checks that every library-name edit still
applies, and writes a new base app. Every other entry in the IPA is copied
unchanged. Game entries are not touched.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('agepad_kit', ROOT / 'scripts' / 'agepad-kit.py')
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)


def main(base, steam, out):
    with zipfile.ZipFile(base) as archive:
        name = next(n for n in archive.namelist() if n.count('/') == 2 and n.endswith('.app/AgePadKit.json'))
        plan = json.loads(archive.read(name))
        changed = []
        for entry in plan['files']:
            if not entry['source'].startswith('steam:'):
                continue
            path = steam / entry['source'][len('steam:'):]
            if not path.is_file():
                sys.exit(f'{entry["source"]}: not in {steam}; run scripts/fetch-steam-mac.py first')
            data = path.read_bytes()
            if entry['op'] == 'header':
                arm = kit.thin(data)
                if not arm:
                    sys.exit(f'{entry["source"]}: no arm64 slice')
                names = set(kit.dylib_names(arm))
                for edit in entry['edits']:
                    missing = sorted(set(edit['map']) - names)
                    if missing:
                        sys.exit(f'{entry["source"]}: no longer loads {", ".join(missing)}; rebuild the recipe')
                kit.transform(arm, entry['edits'])  # raises if the header edits cannot apply
            digest = hashlib.sha256(data).hexdigest()
            if digest != entry.get('source_sha256'):
                entry['source_sha256'] = digest
                changed.append(entry['path'])
        updated = (json.dumps(plan, indent=1) + '\n').encode()
        out.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as target:
            for item in archive.infolist():
                entry = copy.copy(item)
                if item.filename == name:
                    target.writestr(entry, updated)
                elif item.is_dir():
                    target.writestr(entry, b'')
                else:
                    with archive.open(item) as source, target.open(entry, 'w') as sink:
                        shutil.copyfileobj(source, sink, 1 << 20)
    print(f'Re-pinned {len(changed)} Steam files: {", ".join(changed) or "none"}. Base app: {out}')


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit('usage: repin-steam.py BASE.ipa STEAM_DIR OUT.ipa')
    main(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
