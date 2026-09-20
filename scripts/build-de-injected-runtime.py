#!/usr/bin/env python3
"""Build the libraries injected into the launch, plus the host Steam path relay.

These seven binaries used to exist only as per-session clang command lines
recorded inside `generated/mac-de-simulator-*`, which is why a fresh clone could
not reproduce them. This script is the tracked recipe: every input is a source
file in `port/de`, every output is rebuilt here, and a manifest records source
and binary identities.

It builds only. It does not install into a Simulator, launch a session, or touch
any candidate's saves, and it refuses to write into `ref/`.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

# name, source, extra clang arguments. All of these are injected into the
# Simulator process with DYLD_INSERT_LIBRARIES, so they build for the Simulator.
LIBRARIES = [
    ('SystemFrameworkCompat', 'port/de/SystemFrameworkCompat.m',
     ['-fobjc-arc', '-framework', 'Foundation']),
    ('SignalTrace', 'port/de/SignalTrace.c', []),
    ('MainThreadGraphicsWait', 'port/de/MainThreadGraphicsWait.cpp',
     ['-lc++', '-framework', 'CoreFoundation']),
    ('ResourceFileTrace', 'port/de/RuntimeFileTrace.m',
     ['-fobjc-arc', '-framework', 'Foundation']),
    ('OriginalInputTrace', 'port/de/OriginalInputTrace.m',
     ['-fobjc-arc', '-framework', 'Foundation', '-framework', 'QuartzCore']),
    ('AudioOutputCompat', 'port/de/AudioOutputCompat.m',
     ['-fobjc-arc', '-framework', 'AudioToolbox', '-framework', 'AVFoundation']),
]

# The relay runs on the host Mac, not in the Simulator. HostSteamPathQuery.h
# defines the Mach bootstrap query as a static function, so the relay is a
# single translation unit with no framework beyond libSystem. (The separate
# HostSteamPathQuery.c is a standalone host probe with its own main.)
HOST_TOOLS = [
    ('HostSteamPathRelay', ['port/de/HostSteamPathRelay.c'], ['-I', 'port/de']),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args):
    subprocess.run([str(a) for a in args], check=True)


def platform_of(binary):
    """Read the LC_BUILD_VERSION platform so a wrong-target build cannot pass."""
    text = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(binary)], text=True)
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('platform'):
            return line.split(None, 1)[1].strip()
    raise SystemExit('No LC_BUILD_VERSION platform in ' + str(binary))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('output', type=Path, help='Fresh output directory')
    parser.add_argument('--optimization', choices=['0', '1', '2', '3'], default='2')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('Use a fresh output directory so a prior build stays reviewable')
    if ROOT / 'ref' == output or ROOT / 'ref' in output.parents:
        parser.error('Do not write builds into reference data')
    for _, source, _ in LIBRARIES + [t for t in HOST_TOOLS]:
        for one in (source if isinstance(source, list) else [source]):
            if not (ROOT / one).is_file():
                parser.error('Missing source: ' + one)
    output.mkdir(parents=True)
    sdk = subprocess.check_output(
        ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    manifest = {'optimization': args.optimization, 'sdk': sdk,
                'libraries': {}, 'host_tools': {}, 'source_sha256': {}}
    for name, source, extra in LIBRARIES:
        destination = output / (name + '.dylib')
        command = ['xcrun', 'clang', '-target', 'arm64-apple-ios17.0-simulator',
                   '-isysroot', sdk, '-O' + args.optimization, '-dynamiclib',
                   str(ROOT / source), '-o', str(destination)] + extra
        run(command)
        run(['codesign', '--force', '--sign', '-', destination])
        observed = platform_of(destination)
        if observed not in ('IOSSIMULATOR', 'IOS_SIMULATOR'):
            raise SystemExit(name + ' built for ' + observed + ', expected the Simulator platform')
        manifest['libraries'][destination.name] = {
            'sha256': digest(destination), 'source': source, 'platform': observed,
            'arguments': command}
    for name, sources, extra in HOST_TOOLS:
        destination = output / name
        command = ['xcrun', 'clang', '-O' + args.optimization]
        command += [str(ROOT / one) for one in sources] + ['-o', str(destination)] + extra
        run(command)
        run(['codesign', '--force', '--sign', '-', destination])
        observed = platform_of(destination)
        if observed != 'MACOS':
            raise SystemExit(name + ' built for ' + observed + ', expected MACOS')
        manifest['host_tools'][destination.name] = {
            'sha256': digest(destination), 'sources': sources,
            'platform': observed, 'arguments': command}
    for name, source, _ in LIBRARIES:
        manifest['source_sha256'][source] = digest(ROOT / source)
    for _, sources, _ in HOST_TOOLS:
        for one in sources:
            manifest['source_sha256'][one] = digest(ROOT / one)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for name in sorted(list(manifest['libraries']) + list(manifest['host_tools'])):
        print('built ' + name)
    print('manifest: ' + str(output / 'manifest.json'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
