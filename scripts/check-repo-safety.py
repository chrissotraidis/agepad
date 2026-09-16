#!/usr/bin/env python3
"""Fail closed on protected paths or suspicious bytes in the Git index."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).split(b'\0')
tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).split(b'\0'))
failures = []
for raw in filter(None, paths):
    path = raw.decode('utf-8', 'surrogateescape')
    p = pathlib.PurePosixPath(path)
    if p.parts[0] in {'ref', 'worktrees', 'generated', 'private'} or path.startswith('docs/artifacts/'):
        failures.append(path + ': protected path')
        continue
    if p.suffix.lower() in {'.exe', '.dll', '.dat', '.drs', '.slp', '.scx', '.scn', '.cpn', '.mgx', '.sav', '.ipa', '.p12', '.mobileprovision'}:
        failures.append(path + ': protected file type')
        continue
    contents = []
    if raw in tracked:
        contents.append(subprocess.check_output(['git', 'show', ':' + path], cwd=root))
    current = root / path
    if current.is_symlink():
        failures.append(path + ': source symlink needs explicit review')
    elif current.is_file():
        if current.stat().st_size > 5 * 1024 * 1024:
            failures.append(path + ': exceeds 5 MiB source review limit')
        else:
            contents.append(current.read_bytes())
    for data in contents:
        if data.startswith((b'MZ', b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf')):
            failures.append(path + ': executable content')
        private_pattern = rb'(?:/' + rb'Users/[^/\s]+/|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,})'
        if re.search(private_pattern, data):
            failures.append(path + ': private path or secret')
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print('Repository index and publishable working-tree safety check passed; this is not publication approval.')
