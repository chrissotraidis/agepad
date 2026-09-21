#!/usr/bin/env python3
"""Inventory a supplied Steam client's dylibs for the client boundary builder.

`build-de-steam-client-boundary.py` needs, for every image it translates, the
dependency list classified as system or vendor plus whether the Simulator SDK
provides each system dependency. That graph used to be a hand-audited private
file; this derives it from the supplied client with `otool -L` and SDK presence
checks, so the chain can be rebuilt from the Steam client you already have.

Read-only: it inspects the supplied bundle and writes one JSON file.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


SEEDS = ['MacOS/steamclient.dylib', 'MacOS/libaudio.dylib', 'MacOS/libvstdlib_s.dylib',
         'MacOS/libtier0_s.dylib', 'MacOS/crashhandler.dylib',
         'Frameworks/Breakpad.framework/Versions/A/Breakpad',
         'Frameworks/Breakpad.framework/Versions/A/Resources/breakpadUtilities.dylib']


def is_macho(path):
    try:
        return path.open('rb').read(4) in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe',
                                           b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xce')
    except OSError:
        return False


def macho_images(root):
    """All Mach-O images under the supplied tree, as paths relative to it."""
    found = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink() or not path.is_file():
            continue
        if is_macho(path):
            found.append(str(path.relative_to(root)))
    return found


def vendor_target(root, image, dependency, index=None):
    """Resolve a vendor dependency to a path relative to the tree, if it is one."""
    if dependency.startswith(('@loader_path/', '@rpath/', '@executable_path/')):
        relative = dependency.split('/', 1)[1]
    else:
        return None
    for base in ((root / image).parent, root, root / 'Frameworks'):
        candidate = (base / relative).resolve()
        if candidate.is_file():
            try:
                return str(candidate.relative_to(root))
            except ValueError:
                return None
    # An @rpath dependency usually points at a framework that lives elsewhere in
    # the bundle, so fall back to matching it by name anywhere in the tree.
    found = (index or {}).get(Path(relative).name)
    if found:
        try:
            return str(found.relative_to(root))
        except ValueError:
            return None
    return None


def dependencies(path):
    out = subprocess.run(['otool', '-L', str(path)], capture_output=True, text=True, check=True)
    result = []
    for line in out.stdout.splitlines()[1:]:
        line = line.strip()
        # otool prints `file (architecture arm64):` headers for fat images; only
        # real dependency paths carry a leading / or @.
        if not line or ' (architecture ' in line or not line.startswith(('/', '@')):
            continue
        result.append(line.split(' (compatibility')[0].strip())
    return result


def sdk_provides(sdk, dependency):
    """True when the Simulator SDK can supply this system dependency."""
    relative = dependency.lstrip('/')
    # search, not match: dependency paths carry leading directories, so the
    # framework name is not at the start of the string.
    framework = re.search(r'([^/]+)\.framework/', relative)
    if framework:
        return (sdk / 'System/Library/Frameworks' / (framework.group(1) + '.framework')).is_dir()
    candidate = Path(relative)
    return (sdk / candidate).is_file() or (sdk / candidate).with_suffix('.tbd').is_file()


def sdk_tbd(sdk, dependency):
    """The SDK's text-based stub for a system dependency, if it has one."""
    relative = dependency.lstrip('/')
    if '.framework/' in relative:
        head = relative.split('.framework/', 1)[0]
        name = Path(head).name
        candidate = sdk / (head + '.framework') / (name + '.tbd')
    else:
        candidate = (sdk / relative).with_suffix('.tbd')
    return candidate if candidate.is_file() else None


def undefined_symbols(path):
    """symbol -> providing library, from `nm -m -u` output."""
    out = subprocess.run(['xcrun', 'nm', '-arch', 'arm64', '-m', '-u', str(path)],
                         capture_output=True, text=True)
    found = {}
    for match in re.finditer(r'external (\S+) \(from ([^)]+)\)', out.stdout):
        found.setdefault(match.group(2), set()).add(match.group(1))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('source', type=Path, help='Steam client folder holding its dylibs/frameworks')
    parser.add_argument('output', type=Path, help='Audit JSON to write')
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    if not source.is_dir():
        parser.error('Not a directory: ' + str(source))
    sdk = Path(subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'],
                                       text=True).strip())
    # The engine loads the Steam client by name and the rest of the chain follows
    # from those seeds, so the audit covers the reachable graph rather than every
    # Mach-O in a bundle that also contains the whole Chromium/CEF tree.
    available = set(macho_images(source))
    index = {path.name: path for path in source.rglob('*') if path.is_file()}
    queue = [seed for seed in SEEDS if seed in available]
    if not queue:
        parser.error('No Steam client images found under ' + str(source))
    audit = {}
    while queue:
        relative = queue.pop()
        if relative in audit:
            continue
        entries = []
        imports = undefined_symbols(source / relative)
        for dependency in dependencies(source / relative):
            target = vendor_target(source, relative, dependency, index)
            if target:
                # Express the dependency relative to this image so the builder can
                # resolve it exactly, without guessing at framework layouts.
                entry = {'path': '@loader_path/' + os.path.relpath(str(source / target),
                                                                 str((source / relative).parent)),
                         'kind': 'vendor'}
                if target not in audit and target not in queue:
                    queue.append(target)
            else:
                key = Path(dependency).name
                tbd = sdk_tbd(sdk, dependency)
                # Presence of the dependency is what decides whether the image is
                # rewritten to a boundary library. A framework that exists on
                # iOS is left alone even when a few of its APIs are missing; the
                # survey adds boundaries for the frameworks whose symbols the
                # Simulator actually lacks.
                entry = {'path': dependency, 'kind': 'system',
                         'simulator_sdk_present': tbd is not None}
            entries.append(entry)
        audit[relative] = {'dependencies': entries}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(audit, indent=2, sort_keys=True) + '\n')
    vendor = sum(1 for record in audit.values()
                 for entry in record['dependencies'] if entry['kind'] == 'vendor')
    absent = sum(1 for record in audit.values() for entry in record['dependencies']
                 if entry['kind'] == 'system' and not entry['simulator_sdk_present'])
    print('images audited: %d' % len(audit))
    print('vendor dependencies: %d' % vendor)
    print('system dependencies missing from the Simulator SDK: %d' % absent)
    print(args.output)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
