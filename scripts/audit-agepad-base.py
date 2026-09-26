#!/usr/bin/env python3
"""Check that an AgePad base .ipa holds none of the game's or Steam's files.

Compares every file in the .ipa (after removing AgePad's module wrapper) with
every file of the local game and Steam installs: whole-file SHA-256 and, for
arm64 programs, the hash of their code and data sections. Exit 1 on any match.
Usage: scripts/audit-agepad-base.py AgePad-base.ipa
"""
import importlib.util
import sys
import zipfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('kit', Path(__file__).with_name('agepad-kit.py'))
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)
hashes, sections = set(), set()
for path in kit.sources(kit.GAME, kit.STEAM).values():
    data = path.read_bytes()
    hashes.add(kit.sha(data))
    arm = kit.thin(data)
    if arm:
        sections.add(kit.sections_digest(arm))
archive = zipfile.ZipFile(sys.argv[1])
count, hits = 0, []
for item in archive.infolist():
    if item.is_dir():
        continue
    data = archive.read(item)
    count += 1
    if data.startswith(kit.WRAP):
        data = data[len(kit.WRAP):]
    arm = kit.thin(data) if len(data) > 32 else None
    if kit.sha(data) in hashes or (arm and kit.sections_digest(arm) in sections):
        hits.append(item.filename)
print('%d files checked, %d contain game or Steam content%s' % (count, len(hits), ': ' + ', '.join(hits[:10]) if hits else ''))
sys.exit(1 if hits else 0)

