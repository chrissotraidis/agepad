#!/usr/bin/env python3
"""Fetch only locked reference sources; refuse to change existing work."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'dependencies.lock.json').read_text())
def run(*args):
    subprocess.run(args, check=True)
for name, source in lock['sources'].items():
    path = root / 'ref' / name
    if path.exists():
        actual = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
        dirty = subprocess.check_output(['git', '-C', str(path), 'status', '--porcelain'], text=True).strip()
        if actual != source['commit'] or dirty:
            raise SystemExit('Existing reference differs: ' + name + '; preserve and inspect it')
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        run('git', 'clone', '--no-checkout', '--filter=blob:none', source['url'], str(path))
        run('git', '-C', str(path), 'checkout', '--detach', source['commit'])
    run('git', '-C', str(path), 'config', 'remote.origin.pushurl', 'DISABLED-PRIVATE-ONLY')
    if source['submodules']:
        run('git', '-C', str(path), 'submodule', 'update', '--init', '--recursive')
        run('git', '-C', str(path), 'submodule', 'foreach', '--recursive', 'git config remote.origin.pushurl DISABLED-PRIVATE-ONLY')
run('python3', str(root / 'scripts/verify-sources.py'))
