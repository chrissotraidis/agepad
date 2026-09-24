#!/usr/bin/env python3
"""Compile the Simulator boundary libraries for iphoneos to expose device gaps.

Reuses the package's recorded link commands with the device SDK/target. This is
a compile/link feasibility probe: it does not sign for a device, install, or
prove the runtime behaves on hardware. Output goes to a fresh directory.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from importlib import import_module
_sim = import_module('build-de-simulator-runtime')
import de_device


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--package', type=Path, default=de_device.package_dir())
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('Use a fresh output directory')
    missing = [name + '-build-command.json' for name in ('appkit', 'display', 'metal')
               if not (args.package / (name + '-build-command.json')).is_file()]
    if missing:
        parser.error('This package cannot be used for the device compile probe: missing ' +
                     ', '.join(missing) + '. The fresh Simulator bootstrap must first record '
                     'its boundary build commands for the device SDK; no device app or IPA was produced.')
    output.mkdir(parents=True)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
    results = {}
    for name, library in [('appkit', 'AppKit'), ('display', 'CoreGraphics'), ('metal', 'Metal')]:
        command = json.loads((args.package / (name + '-build-command.json')).read_text())
        command = [re.sub(r'-simulator$', '', a) if a.startswith('arm64-apple-ios') else a for a in command]
        command[command.index('-isysroot') + 1] = sdk
        command[command.index('-o') + 1] = str(output / ('DEBoundary_' + library + '.dylib'))
        command = [a.replace(str(args.package / 'game-client'), str(output)) for a in command]
        source = next(Path(a) for a in command if a.endswith('.m'))
        stripped = output / source.name
        _sim.strip_implemented_stubs(source, stripped, _sim.implemented_symbols())
        command[command.index(str(source))] = str(stripped)
        command[command.index('-I'):command.index('-I')] = ['-I', str(source.parent)]
        log = output / (name + '-device-build.log')
        with log.open('w') as handle:
            run = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=handle)
        text = log.read_text()
        results[library] = {'exit': run.returncode,
                            'errors': [l.strip() for l in text.splitlines() if ' error: ' in l][:40]}
    (output / 'device-compile-result.json').write_text(json.dumps(results, indent=2))
    for library, r in results.items():
        print(library, 'exit', r['exit'], len(r['errors']), 'errors')
        for e in r['errors'][:12]:
            print('  ', e)


if __name__ == '__main__':
    main()
