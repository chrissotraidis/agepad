#!/usr/bin/env python3
"""Check the generated DE boundary sources against the iPad device SDK.

Legacy packages recorded link commands; fresh bootstrap packages contain the
generated sources instead. For a fresh package this checks every source with
the device compiler. It does not link a game, sign, install, or prove hardware
execution. Output goes to a fresh directory.
"""
import argparse
import hashlib
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


def check_fresh_sources(package, output, sdk):
    roots = [package.parent / 'artifacts/candidate.app-art', package / 'game-client']
    sources = [source for root in roots for source in sorted(root.glob('*.m'))]
    if not sources or not (roots[0] / 'AppKit.m').is_file():
        raise SystemExit('Fresh package has no generated engine boundary sources')
    results = {}
    for source in sources:
        command = ['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-isysroot', sdk,
                   '-fobjc-arc', '-fsyntax-only', '-I', str(ROOT / 'port/de'), str(source)]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        key = source.parent.name + '/' + source.name
        (output / (source.parent.name + '-' + source.stem + '.log')).write_text(run.stdout + run.stderr)
        results[key] = {'exit': run.returncode,
                        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                        'errors': [line.strip() for line in run.stderr.splitlines()
                                   if re.search(r':\d+:\d+: error:', line)][:20]}
    report = {'scope': 'device-SDK syntax only; no link, signing, game install, Steam session, or gameplay',
              'sdk': sdk, 'sources': results}
    (output / 'device-compile-result.json').write_text(json.dumps(report, indent=2) + '\n')
    failed = [key for key, value in results.items() if value['exit']]
    print(f'Device SDK source check: {len(sources)} generated sources, {len(failed)} failures')
    for key in failed:
        print(key, results[key]['errors'][:3])
    return bool(failed)


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
    output.mkdir(parents=True)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
    if missing:
        if check_fresh_sources(args.package.resolve(), output, sdk):
            raise SystemExit(1)
        return
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
