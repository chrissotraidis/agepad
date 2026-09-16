#!/usr/bin/env python3
"""Build an isolated, matched Simulator boundary and resource-I/O candidate.

Uses the existing private package's recorded link commands. Does not install,
launch, restart a scenario, alter saves, or package a distributable game.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='Fresh isolated build directory')
    parser.add_argument('--package', type=Path, default=ROOT / 'generated/mac-de-simulator-375')
    parser.add_argument('--optimization', choices=['0', '1', '2', '3'], default='2')
    args = parser.parse_args()
    output = args.output.resolve()
    package = args.package.resolve()
    if output.exists():
        parser.error('Use a fresh output directory so a prior candidate remains reviewable')
    if ROOT / 'ref' == output or ROOT / 'ref' in output.parents:
        parser.error('Do not write candidates into reference data')
    output.mkdir(parents=True)
    builds = [('appkit', 'AppKit'), ('display', 'CoreGraphics'), ('metal', 'Metal')]
    manifest = {'optimization': args.optimization, 'package': str(package), 'libraries': {}, 'source_sha256': {}}
    for command_name, library in builds:
        command = json.loads((package / (command_name + '-build-command.json')).read_text())
        command = [arg for arg in command if not re.fullmatch(r'-O(?:[0-3szg]|fast)', arg)]
        command += ['-O' + args.optimization]
        destination = output / ('DEBoundary_' + library + '.dylib')
        command[command.index('-o') + 1] = str(destination)
        # CoreGraphics imports the new pointer-ownership API from this same build.
        if library == 'CoreGraphics':
            dependency = str(package / 'game-client/DEBoundary_AppKit.dylib')
            if dependency not in command:
                raise RuntimeError('Recorded CoreGraphics command lacks its expected AppKit dependency')
            command[command.index(dependency)] = str(output / 'DEBoundary_AppKit.dylib')
        (output / (command_name + '-command.json')).write_text(json.dumps(command, indent=2))
        with (output / (command_name + '-build.log')).open('w') as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=log, check=True)
        subprocess.run(['codesign', '--force', '--sign', '-', str(destination)], check=True)
        manifest['libraries'][destination.name] = hashlib.sha256(destination.read_bytes()).hexdigest()
    # Resource I/O is an injected companion, not a framework reexport. It must
    # travel with the candidate now that staging preserves original filenames.
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    destination = output / 'ResourceFileTrace.dylib'
    command = ['xcrun', 'clang', '-target', 'arm64-apple-ios17.0-simulator',
               '-isysroot', sdk, '-O' + args.optimization, '-fobjc-arc', '-dynamiclib',
               str(ROOT / 'port/de/RuntimeFileTrace.m'), '-framework', 'Foundation',
               '-o', str(destination)]
    (output / 'resource-command.json').write_text(json.dumps(command, indent=2))
    with (output / 'resource-build.log').open('w') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=log, check=True)
    subprocess.run(['codesign', '--force', '--sign', '-', str(destination)], check=True)
    manifest['libraries'][destination.name] = hashlib.sha256(destination.read_bytes()).hexdigest()
    for source in (ROOT / 'port/de').iterdir():
        if source.is_file() and source.suffix in {'.m', '.h', '.c', '.cpp', '.inc'}:
            manifest['source_sha256'][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2))
    print('Built matched Simulator runtime:', output)


if __name__ == '__main__':
    main()
