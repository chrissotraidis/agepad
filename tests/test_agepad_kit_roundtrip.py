#!/usr/bin/env python3
"""Release round trip on this Mac: recipe -> base app -> audit -> inject, then
check the injected app matches the latest build file for file (apart from code
signatures). Needs a build (scripts/agepad-ipad.sh build) and the game and Steam
installed; otherwise it says what's missing and skips."""
import importlib.util
import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('kit', root / 'scripts/agepad-kit.py')
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)
builds = sorted(root.glob('generated/ipad-build-2*/AgePadDeviceProbe.app'), key=lambda p: p.stat().st_mtime)
if not builds or not kit.GAME.is_dir() or not kit.STEAM.is_dir():
    print('SKIP: needs a build in generated/ and the game and Steam installed on this Mac')
    sys.exit(0)
app = builds[-1]
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    run = lambda *a: subprocess.run([sys.executable, *map(str, a)], check=True, capture_output=True, text=True).stdout
    run(root / 'scripts/agepad-kit.py', 'recipe', app, tmp / 'recipe.json')
    run(root / 'scripts/agepad-kit.py', 'base', app, tmp / 'recipe.json', tmp / 'base.ipa')
    run(root / 'scripts/audit-agepad-base.py', tmp / 'base.ipa')  # exits 1 on any game/Steam content
    run(root / 'scripts/agepad-kit.py', 'inject', tmp / 'base.ipa', tmp / 'mine.ipa')
    z = zipfile.ZipFile(tmp / 'mine.ipa')
    injected = {i.filename.split('.app/', 1)[1]: i for i in z.infolist() if not i.is_dir() and '.app/' in i.filename}
    built = {str(p.relative_to(app)) for p in app.rglob('*')
             if p.is_file() and '_CodeSignature' not in p.parts and p.name != 'embedded.mobileprovision'}
    assert built - set(injected) == set(), sorted(built - set(injected))[:10]
    assert set(injected) - built == {'AgePadKit.json'}, sorted(set(injected) - built)[:10]
    different = []
    for rel in sorted(built):
        a, b = (app / rel).read_bytes(), z.read(injected[rel])
        if a == b:
            continue
        ta, tb = kit.thin(a), kit.thin(b)
        if ta and tb and kit.header_key(ta) == kit.header_key(tb) and kit.sections_digest(ta) == kit.sections_digest(tb):
            continue
        if rel == 'Info.plist' and plistlib.loads(a) == plistlib.loads(b):
            continue
        different.append(rel)
    assert not different, different
    print('PASS: base app has no game/Steam content; injected app matches the build (%d files)' % len(built))

