#!/usr/bin/env python3
"""Screen bundled PE layouts for signed-container obstacles; not a runtime test."""
from pathlib import Path
import collections
import hashlib
import json
import re
import struct
import subprocess

r = Path(__file__).resolve().parents[1]
root = r / 'worktrees/madeira'
reader = root / 'toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/llvm-readobj'
out = r / 'generated/madeira-container-audit'
out.mkdir(parents=True, exist_ok=True)
files = sorted((root / 'app/Madeira/aarch64-windows').glob('*.dll')) + sorted((root / 'app/Madeira/arm64ec-windows').glob('*.dll'))
rows = []
for path in files:
    data = path.read_bytes()
    pe = struct.unpack_from('<I', data, 60)[0]
    machine, count = struct.unpack_from('<HH', data, pe + 4)
    opt = pe + 24
    section_table = opt + struct.unpack_from('<H', data, pe + 20)[0]
    size = struct.unpack_from('<I', data, opt + 56)[0]
    sections = []
    for i in range(count):
        p = section_table + i * 40
        span, address = struct.unpack_from('<II', data, p + 8)
        flags = struct.unpack_from('<I', data, p + 36)[0]
        sections.append((address, address + span, flags))
    layout = subprocess.check_output([str(reader), '--coff-basereloc', '--coff-load-config', str(path)], text=True)
    ranges = [(int(a, 16), int(b, 16)) for a, b in re.findall(r'(0x[0-9A-F]+) - (0x[0-9A-F]+)  ARM64EC', layout)]
    if machine == 0xaa64:
        ranges = [(a, b) for a, b, flags in sections if flags & 0x20000000]
    issues = []
    split = (max((b for a, b in ranges), default=0) + 16383) & ~16383
    if not ranges:
        issues.append('no identified native code')
    if split >= size:
        issues.append('no separate trailing data region')
    relocations = [(kind, int(address, 16)) for kind, address in re.findall(r'Type: (\w+)\n    Address: (0x[0-9A-F]+)', layout) if kind != 'ABSOLUTE']
    code_relocs = [(kind, address) for kind, address in relocations if address < split]
    if code_relocs:
        issues.append('relocations in immutable prefix')
    if any(kind != 'DIR64' or address + 8 > size for kind, address in relocations):
        issues.append('unsupported or out-of-bounds relocation')
    dynamic = {}
    for field in ['DynamicValueRelocTable', 'DynamicValueRelocTableOffset', 'DynamicValueRelocTableSection']:
        match = re.search(r'  ' + field + r': (0x[0-9A-F]+|\d+)\n', layout)
        if match:
            dynamic[field] = int(match.group(1), 0)
    if any(dynamic.values()):
        issues.append('dynamic relocations need handling')
    if any(a < split and b > a and flags & 0x80000000 for a, b, flags in sections):
        issues.append('writable PE section overlaps immutable prefix')
    rows.append({'file': str(path.relative_to(r)), 'sha256': hashlib.sha256(data).hexdigest(),
                 'machine': hex(machine), 'native_ranges': ranges, 'split': split,
                 'relocations': len(relocations), 'immutable_prefix_relocations': code_relocs,
                 'dynamic_relocations': dynamic, 'issues': issues})
report = {'scope': 'Static layout screen of bundled inputs only. Passing does not qualify source provenance, imports, TLS, code patching, process isolation, runtime loading or game compatibility.',
          'files': rows, 'summary': {'scanned': len(rows), 'no_screened_obstacle': sum(not row['issues'] for row in rows),
          'issue_counts': dict(collections.Counter(issue for row in rows for issue in row['issues']))}}
(out / 'audit.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report['summary'], indent=2))
