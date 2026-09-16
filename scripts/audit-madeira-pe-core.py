#!/usr/bin/env python3
"""Compare rebuilt Windows core DLLs with bundled inputs; never install them.

Export/import structure is build evidence, not execution or ABI conformance.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

r = Path(__file__).resolve().parents[1]
src = r / 'worktrees/madeira'
reader = src / 'toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/llvm-readobj'
out = r / 'generated/madeira-windows-core'
out.mkdir(parents=True, exist_ok=True)
pairs = {
    'xtajit64': (src / 'app/Madeira/arm64ec-windows/xtajit64.dll', r / 'generated/madeira-fex-arm64ec/Bin/libarm64ecfex.dll'),
    'ntdll-arm64ec': (src / 'app/Madeira/arm64ec-windows/ntdll.dll', src / 'wine/build-arm64ec/dlls/ntdll/arm64ec-windows/ntdll.dll'),
    'ntdll-arm64': (src / 'app/Madeira/aarch64-windows/ntdll.dll', src / 'wine/build-macos/dlls/ntdll/aarch64-windows/ntdll.dll'),
}

def inspect(path, label):
    text = subprocess.check_output([str(reader), '--file-headers', '--coff-imports', '--coff-exports', str(path)], text=True)
    (out / f'{label}.txt').write_text(text)
    exports = {}
    for block in re.findall(r'Export \{(.*?)\n\}', text, re.S):
        name = re.search(r'Name: (.*)', block).group(1).strip()
        ordinal = int(re.search(r'Ordinal: (\d+)', block).group(1))
        exports[name or f'<ordinal:{ordinal}>'] = ordinal
    imports = {}
    for block in re.findall(r'Import \{(.*?)\n\}', text, re.S):
        imports[re.search(r'Name: (.+)', block).group(1)] = re.findall(r'Symbol: (.*?) \(', block)
    return {'path': str(path.relative_to(r)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size, 'format': re.search(r'Format: (.+)', text).group(1),
            'exports': exports, 'imports': imports}

report = {'scope': 'Structural DLL comparison only; no runtime or ABI pass', 'pairs': {}}
for name, paths in pairs.items():
    old, new = [inspect(path, f'{name}-{label}') for path, label in zip(paths, ['bundled', 'rebuilt'])]
    old_i = {(dll, fn) for dll, names in old['imports'].items() for fn in names}
    new_i = {(dll, fn) for dll, names in new['imports'].items() for fn in names}
    report['pairs'][name] = {'bundled': old, 'rebuilt': new,
        'missing_exports': sorted(old['exports'].keys() - new['exports'].keys()),
        'added_exports': sorted(new['exports'].keys() - old['exports'].keys()),
        'changed_ordinals': {n: [old['exports'][n], new['exports'][n]] for n in old['exports'].keys() & new['exports'].keys() if old['exports'][n] != new['exports'][n]},
        'removed_imports': sorted(old_i - new_i), 'added_imports': sorted(new_i - old_i)}
files = sorted((src / 'app/Madeira/aarch64-windows').glob('*.dll')) + sorted((src / 'app/Madeira/arm64ec-windows').glob('*.dll'))
text = subprocess.check_output([str(reader), '--coff-imports', *map(str, files)], text=True)
(out / 'bundled-imports.txt').write_text(text)
ordinal_imports, ntdll_imports = [], 0
for block in re.split(r'\nFile: ', text)[1:]:
    path = block.splitlines()[0]
    for imp in re.findall(r'Import \{(.*?)\n\}', block, re.S):
        if re.search(r'Name: (.+)', imp).group(1).lower() != 'ntdll.dll':
            continue
        for name, number in re.findall(r'Symbol: (.*?) \((\d+)\)', imp):
            ntdll_imports += 1
            if not name.strip():
                ordinal_imports.append({'file': path, 'ordinal': int(number)})
report['bundled_import_scan'] = {'files_checked': len(files), 'ntdll_imports': ntdll_imports,
    'ordinal_imports': ordinal_imports,
    'limitation': 'Static imports of bundled DLLs only; runtime ordinal lookups and external executables untested.'}
(out / 'audit.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({n: {'exports': len(v['rebuilt']['exports']), 'missing': v['missing_exports'],
                     'added': v['added_exports'], 'changed_ordinals': len(v['changed_ordinals'])}
                  for n, v in report['pairs'].items()}, indent=2))
