#!/usr/bin/env python3
"""AgePad kit: a publishable base app plus "add your own copy" on the user's side.

  recipe BUILT_APP OUT.json     (maintainers) record, for every file in a built
                                AgePad that comes from the game or Steam, where it
                                comes from and the header-only changes applied.
                                The recipe holds paths, hashes and load-command
                                edits only: never vendor bytes.
  base BUILT_APP RECIPE OUT.ipa (maintainers) the app without any of those files:
                                AgePad's own code and assets only.
  inject BASE.ipa OUT.ipa [--game DIR] [--steam DIR]
                                (players) put your own game program and Steam
                                software into the base app. Pure Python: no Xcode.
                                Sign and install the result with a sideloading
                                tool (see docs/IPA-ROUTE.md).

Vendor Mach-O files are changed only in their header (platform, library paths),
exactly as scripts/prepare-de-load-image.py does; code and data sections are
byte-identical to the user's own files, which the recipe verifies by hash.
"""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import struct
import sys
import tempfile
import zipfile
from pathlib import Path

HOME = Path.home()
GAME = HOME / 'Library/Application Support/Steam/steamapps/common/AoE2DE/Age Of Empires II.app/Contents'
STEAM = HOME / 'Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS'
STEAMAPPS = HOME / 'Library/Application Support/Steam/steamapps'
DYLIB_COMMANDS = (0xc, 0x80000018, 0x8000001f, 0x80000023, 0xd)
WRAP = b'AGEPAD-MODULE-1\n'  # a vendor file stored behind this header (see SteamModuleCompat.m)


def install_record(text):
    """Steam's install record for the game as AgePad ships it (same rule as
    prepare-de-device-probe.py): personal fields dropped, auto-update off."""
    import re
    lines = [l for l in text.splitlines() if not re.search(r'"(LastOwner|LastPlayed|LastUpdated)"', l)]
    return re.sub(r'("AutoUpdateBehavior"\s+)"\d+"', r'\1"1"', '\n'.join(lines) + '\n')


def build_id(text):
    import re
    found = re.search(r'"buildid"\s+"(\d+)"', text)
    return found.group(1) if found else None


def sha(data):
    return hashlib.sha256(data).hexdigest()


def thin(data):
    """The arm64 Mach-O of a (possibly universal) file, or None."""
    magic = struct.unpack_from('>I', data)[0]
    if magic in (0xcafebabe, 0xcafebabf):
        count = struct.unpack_from('>I', data, 4)[0]
        wide = magic == 0xcafebabf
        for i in range(count):
            if wide:
                cpu, _, offset, size = struct.unpack_from('>iiQQ', data, 8 + i * 32)[:4]
            else:
                cpu, _, offset, size = struct.unpack_from('>iiII', data, 8 + i * 20)[:4]
            if cpu == 0x100000c:
                return data[offset:offset + size]
        return None
    if struct.unpack_from('<I', data)[0] == 0xfeedfacf and struct.unpack_from('<I', data, 4)[0] == 0x100000c:
        return data
    return None


def commands(data):
    ncmds = struct.unpack_from('<I', data, 16)[0]
    offset, out = 32, []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, offset)
        out.append((cmd, data[offset:offset + size]))
        offset += size
    return out


def sections_digest(data):
    """Hash of every section's file bytes (the code and data, not the header)."""
    h = hashlib.sha256()
    for cmd, body in commands(data):
        if cmd == 0x19:
            for i in range(struct.unpack_from('<I', body, 64)[0]):
                size, offset = struct.unpack_from('<QI', body, 72 + 80 * i + 40)
                if offset:
                    h.update(data[offset:offset + size])
    return h.hexdigest()


def header_key(data):
    """Load commands without the code-signature parts, which every signing rewrites
    (LC_CODE_SIGNATURE and the size of __LINKEDIT, where the signature lives)."""
    key = []
    for cmd, body in commands(data):
        if cmd == 0x1d:
            continue
        if cmd == 0x19 and body[8:18] == b'__LINKEDIT':
            body = body[:32] + body[40:48]  # keep vmaddr and fileoff; drop vmsize and filesize
        key.append((cmd, body))
    return key


def dylib_names(data):
    names = []
    for cmd, body in commands(data):
        if cmd in DYLIB_COMMANDS:
            nameoff = struct.unpack_from('<I', body, 8)[0]
            names.append(body[nameoff:].split(b'\0')[0].decode())
    return names


def load_adapter():
    import importlib.util
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location('de_adapter', here / 'prepare-de-load-image.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def transform(source_thin, edits):
    """Apply recorded header edits with the project's own adapter, without signing."""
    adapter = load_adapter()
    real = adapter.subprocess.run
    adapter.subprocess.run = lambda *a, **k: None  # signing is the sideloading tool's job
    try:
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp) / 'in', Path(tmp) / 'out'
            src.write_bytes(source_thin)
            data = source_thin
            for step in edits:
                adapter.prepare(src, dst, platform=step['platform'], dependency_map=step['map'],
                                preserve_executable=step['preserve'], audio_umbrella=step.get('audio', False))
                data = dst.read_bytes()
                src.write_bytes(data)
            return data
    finally:
        adapter.subprocess.run = real


def sources(game, steam):
    table = {}
    for root, label in ((game, 'game'), (steam, 'steam')):
        if not root or not root.is_dir():
            continue
        for p in root.rglob('*'):
            if p.is_file() and not p.is_symlink():
                table.setdefault(label + ':' + str(p.relative_to(root)), p)
    return table


def recipe(app, out, game, steam):
    table = sources(game, steam)
    by_hash, by_sections = {}, {}
    for key, p in table.items():
        data = p.read_bytes()
        by_hash.setdefault(sha(data), key)
        arm = thin(data)
        if arm:
            by_sections.setdefault(sections_digest(arm), key)
    entries, ours = [], []
    # Files derived from the player's own game/Steam data rather than copied:
    # Info.plist (the game's, plus AgePad's changes) and Steam's install record.
    game_info = plistlib.loads((game / 'Info.plist').read_bytes())
    app_info = plistlib.loads((app / 'Info.plist').read_bytes())
    entries.append({'path': 'Info.plist', 'source': 'game:Info.plist', 'op': 'plist',
                    'source_sha256': sha((game / 'Info.plist').read_bytes()),
                    'set': {k: v for k, v in app_info.items() if game_info.get(k) != v},
                    'delete': sorted(k for k in game_info if k not in app_info)})
    record = app / 'SteamAppManifest_813780.acf'
    if record.is_file():
        entries.append({'path': record.name, 'source': 'steamapps:appmanifest_813780.acf', 'op': 'appmanifest',
                        'buildid': build_id(record.read_text())})
    derived = {e['path'] for e in entries}
    for p in sorted(app.rglob('*')):
        if not p.is_file() or '_CodeSignature' in p.parts:
            continue
        rel = str(p.relative_to(app))
        if rel in derived:
            continue
        data = p.read_bytes()
        if data.startswith(WRAP):
            key = by_hash.get(sha(data[len(WRAP):]))
            if not key:
                sys.exit('Wrapped file with unknown contents: ' + rel)
            entries.append({'path': rel, 'source': key, 'source_sha256': sha(data[len(WRAP):]), 'op': 'wrap'})
            continue
        key = by_hash.get(sha(data))
        if key:
            entries.append({'path': rel, 'source': key, 'source_sha256': sha(data), 'op': 'copy'})
            continue
        arm = thin(data)
        key = arm and by_sections.get(sections_digest(arm))
        if not key:
            ours.append(rel)
            continue
        source_thin = thin(table[key].read_bytes())
        before, after = dylib_names(source_thin), dylib_names(arm)
        mapping = {a: b for a, b in zip(before, after) if a != b}
        filetype = struct.unpack_from('<I', arm, 12)[0]
        edits = [{'platform': 'ios-device', 'map': mapping, 'preserve': filetype == 2}]
        rebuilt = transform(source_thin, edits)
        same = header_key(rebuilt) == header_key(arm) and sections_digest(rebuilt) == sections_digest(arm)
        entries.append({'path': rel, 'source': key, 'source_sha256': sha(table[key].read_bytes()),
                        'op': 'header', 'edits': edits, 'verified': same})
    report = {'format': 1, 'files': entries, 'own_files': len(ours)}
    out.write_text(json.dumps(report, indent=1) + '\n')
    bad = [e['path'] for e in entries if e['op'] == 'header' and not e['verified']]
    print('vendor files: %d (copies %d, header edits %d), AgePad files: %d, unverified: %s' % (
        len(entries), sum(e['op'] == 'copy' for e in entries), sum(e['op'] == 'header' for e in entries),
        len(ours), bad or 'none'))
    return 1 if bad else 0


def zip_app(app, out):
    out.parent.mkdir(parents=True, exist_ok=True)  # generated/ doesn't exist in a fresh clone
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(app.rglob('*')):
            arc = 'Payload/' + app.name + '/' + str(p.relative_to(app))
            if p.is_symlink():
                info = zipfile.ZipInfo(arc)
                info.external_attr = 0o120777 << 16
                z.writestr(info, os.readlink(p))
            elif p.is_file():
                info = zipfile.ZipInfo.from_file(p, arc)
                info.compress_type = zipfile.ZIP_DEFLATED
                with p.open('rb') as f:
                    z.writestr(info, f.read())


def base(app, recipe_path, out):
    plan = json.loads(recipe_path.read_text())
    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / app.name
        shutil.copytree(app, copy, symlinks=True)
        for name in ('_CodeSignature', 'embedded.mobileprovision'):
            target = copy / name
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()
        for entry in plan['files']:
            (copy / entry['path']).unlink(missing_ok=True)
        # Info.plist is rebuilt from the player's game; ship only what iPadOS
        # needs to identify the unfinished base app.
        own = next(e for e in plan['files'] if e['op'] == 'plist')['set']
        (copy / 'Info.plist').write_bytes(plistlib.dumps({k: own[k] for k in (
            'CFBundleIdentifier', 'CFBundleDisplayName', 'CFBundleName') if k in own}))
        (copy / 'AgePadKit.json').write_text(json.dumps(plan, indent=1) + '\n')
        zip_app(copy, out)
    print('Base app: %s (%.0f MB), %d vendor files left out' % (out, out.stat().st_size / 1e6, len(plan['files'])))


def inject(base_ipa, out, game, steam, steamapps=STEAMAPPS):
    table = sources(game, steam)
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(base_ipa) as z:
            z.extractall(tmp)
        app = next((Path(tmp) / 'Payload').glob('*.app'))
        plan = json.loads((app / 'AgePadKit.json').read_text())
        missing = [e['source'] for e in plan['files'] if e['op'] in ('copy', 'header', 'wrap') and e['source'] not in table]
        if missing:
            sys.exit('Not found in your game/Steam folders: %s. Is Age of Empires II: DE (Mac) installed through Steam?'
                     % ', '.join(sorted(set(missing))[:5]))
        wrong = []
        for entry in plan['files']:
            target = app / entry['path']
            if entry['op'] == 'appmanifest':
                path = steamapps / 'appmanifest_813780.acf'
                text = path.read_text() if path.is_file() else ''
                if build_id(text) != entry['buildid']:
                    wrong.append('Steam install record (game build %s, AgePad expects %s)' % (build_id(text), entry['buildid']))
                    continue
                target.write_text(install_record(text))
                continue
            if entry['op'] == 'plist':
                info = plistlib.loads(table[entry['source']].read_bytes())
                for key in entry['delete']:
                    info.pop(key, None)
                info.update(entry['set'])
                target.write_bytes(plistlib.dumps(info))
                continue
            data = table[entry['source']].read_bytes()
            if sha(data) != entry['source_sha256']:
                wrong.append(entry['source'])
                continue
            if entry['op'] == 'header':
                data = transform(thin(data), entry['edits'])
            if entry['op'] == 'wrap':
                data = WRAP + data
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            if entry['op'] == 'header':
                target.chmod(0o755)
        if wrong:
            sys.exit('These files are a different version than this AgePad was made for: %s. '
                     'Get the AgePad release for your game and Steam versions.' % ', '.join(sorted(set(wrong))[:5]))
        zip_app(app, out)
    print('Your AgePad: %s (%.0f MB). Sign and install it with a sideloading tool; keep it to yourself.'
          % (out, out.stat().st_size / 1e6))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='command', required=True)
    r = sub.add_parser('recipe'); r.add_argument('app', type=Path); r.add_argument('out', type=Path)
    b = sub.add_parser('base'); b.add_argument('app', type=Path); b.add_argument('recipe', type=Path); b.add_argument('out', type=Path)
    i = sub.add_parser('inject'); i.add_argument('base', type=Path); i.add_argument('out', type=Path)
    for s in (r, i):
        s.add_argument('--game', type=Path, default=GAME, help='the Mac game app\'s Contents folder')
        s.add_argument('--steam', type=Path, default=STEAM, help='Steam for Mac\'s Contents/MacOS folder')
    a = p.parse_args()
    if a.command == 'recipe':
        return recipe(a.app, a.out, a.game, a.steam)
    if a.command == 'base':
        return base(a.app, a.recipe, a.out)
    return inject(a.base, a.out, a.game, a.steam)


if __name__ == '__main__':
    sys.exit(main())
