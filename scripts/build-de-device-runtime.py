#!/usr/bin/env python3
"""Check the generated DE boundary sources against the iPad device SDK.

Legacy packages recorded link commands; fresh bootstrap packages contain the
generated sources instead. For a fresh package this checks every source and
links the generated boundary libraries with the device SDK. It does not link
a game, sign, install, or prove hardware execution. Output goes to a fresh directory.
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


def link_fresh_boundaries(package, output, sdk):
    art = package.parent / 'artifacts/candidate.app-art'
    manifest = json.loads((art / 'boundary-manifest.json').read_text())
    results = {}
    for item in manifest['libraries']:
        name = Path(item['replacement']).name
        source = art / (name.removeprefix('DEBoundary_').removesuffix('.dylib') + '.m')
        if not source.is_file():
            raise SystemExit('Missing generated boundary source: ' + str(source))
        destination = output / name
        command = ['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-isysroot', sdk,
                   '-fobjc-arc', '-dynamiclib', '-I', str(ROOT / 'port/de'), str(source),
                   '-framework', 'Foundation', '-Wl,-install_name,' + item['replacement'],
                   '-o', str(destination)]
        if name == 'DEBoundary_AppKit.dylib':
            command += ['-framework', 'UIKit', '-framework', 'QuartzCore', '-framework',
                        'GameController', '-framework', 'Metal', '-framework', 'CoreGraphics',
                        '-framework', 'AudioToolbox', '-framework', 'AVFoundation']
            command.append(str(ROOT / 'port/de/DeviceAudioOutput.m'))
            command += [str(ROOT / 'port/de/DeviceLocaleCompat.mm'), '-lc++']
            command.append(str(ROOT / 'port/de/DeviceCalendarCompat.m'))
            command += [str(ROOT / 'port/de/DeviceAudioHALTrace.m'), '-framework', 'CoreAudio']
            # In-iPad Steam route: Valve's engine host, QR sign-in, saved sign-in.
            command += ['-I', str(ROOT / 'port/steam-engine'),
                        str(ROOT / 'port/steam-engine/SteamEngineHost.c'),
                        str(ROOT / 'port/steam-engine/SteamQRSignIn.m'),
                        str(ROOT / 'port/steam-engine/AgePadSteamRoute.m'),
                        '-framework', 'CoreImage', '-framework', 'ImageIO', '-framework', 'Security']
            # The generated NSColor diagnostic class has a different ObjC name
            # because UIKit already owns NSColor internally on some runtimes.
            # Preserve the two aliases emitted by build-de-boundary-probe.py.
            for kind in ('CLASS', 'METACLASS'):
                command.append('-Wl,-alias,_OBJC_' + kind + '_$_DEDiagnosticNSColor,_OBJC_' + kind + '_$_NSColor')
        if name == 'DEBoundary_CoreGraphics.dylib':
            command += ['-framework', 'UIKit', '-framework', 'GameController',
                        str(output / 'DEBoundary_AppKit.dylib')]
        if name == 'DEBoundary_CoreVideo.dylib':
            command += ['-framework', 'UIKit', '-framework', 'QuartzCore']
        if name == 'DEBoundary_Metal.dylib':
            command += ['-framework', 'Metal', '-framework', 'UIKit']
        if item['reexports_original']:
            original = item['path']
            framework = re.search(r'/([^/]+)\.framework/', original)
            if framework:
                command.append('-Wl,-reexport_framework,' + framework.group(1))
            else:
                command.append('-Wl,-reexport_library,' + str(Path(sdk) / original.lstrip('/')).removesuffix('.dylib') + '.tbd')
        if name == 'DEBoundary_AudioUnit.dylib':
            command.append('-Wl,-reexport_framework,AudioToolbox')
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        (output / (name + '.log')).write_text(run.stdout + run.stderr)
        platform = None
        if run.returncode == 0:
            build = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(destination)], text=True)
            match = re.search(r'platform\s+(\w+)', build)
            platform = match.group(1) if match else None
        results[name] = {'exit': run.returncode, 'platform': platform,
                         'sha256': hashlib.sha256(destination.read_bytes()).hexdigest() if destination.is_file() else None,
                         'errors': [line.strip() for line in run.stderr.splitlines()
                                    if re.search(r':\d+:\d+: error:|^ld: error:|^Undefined symbols', line)][:20]}
    report = {'scope': 'device SDK boundary links only; no game binary, signing, Steam session, or gameplay',
              'sdk': sdk, 'libraries': results}
    (output / 'device-link-result.json').write_text(json.dumps(report, indent=2) + '\n')
    failed = [key for key, value in results.items() if value['exit'] or value['platform'] != 'IOS']
    print(f'Device SDK boundary link: {len(results)} libraries, {len(failed)} failures')
    for key in failed:
        print(key, results[key]['errors'][:3])
    return bool(failed)


# Steam client boundaries (used by Valve's engine inside AgePad) where the iPad
# gives a real answer: this device's state, or "this macOS service does not
# exist here" where Valve's caller handles that. Each source says which. All
# other symbols keep their generated fail-fast stubs.
CLIENT_REPLACEMENTS = {'DiskArbitration': 'DiskArbitrationUnavailable.m',
                       'CoreGraphics': 'CoreGraphicsClient.m',
                       'ApplicationServices': 'ApplicationServicesClient.m'}


def link_client_replacements(package, output, sdk):
    game_client = package / 'game-client'
    for library, name in CLIENT_REPLACEMENTS.items():
        source = ROOT / 'port/steam-engine' / name
        defined = {'_' + symbol for symbol in re.findall(
            r'^[A-Za-z][\w \t*]*?\b(\w+)\s*\([^;()]*\)\s*\{', source.read_text(), re.M)}
        stub = re.compile(r'__attribute__\(\(noreturn\)\) void (Function\d+)\(void\) __asm__\("(_\w+)"\);\n'
                          r'void \1\(void\) \{ DEUnsupported\("\2"\); \}\n')
        stubs = stub.sub(lambda m: '' if m.group(2) in defined else m.group(0),
                         (game_client / (library + '.m')).read_text())
        generated = output / ('client-' + library + '.m')
        generated.write_text(stubs)
        name = 'DEClientBoundary_' + library + '.dylib'
        command = ['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-isysroot', sdk, '-fobjc-arc',
                   '-dynamiclib', '-I', str(ROOT / 'port/de'), '-I', str(ROOT / 'port/steam-engine'),
                   str(generated), str(source), '-framework', 'Foundation', '-framework', 'UIKit',
                   '-Wl,-install_name,@loader_path/' + name, '-Wl,-compatibility_version,1000.0',
                   '-o', str(output / name)]
        loads = subprocess.check_output(['otool', '-l', str(game_client / name)], text=True)
        for path in re.findall(r'cmd LC_REEXPORT_DYLIB\n\s+cmdsize \d+\n\s+name (\S+)', loads):
            command.append('-Wl,-reexport_framework,' + Path(path).name)
        subprocess.run(command, check=True)
    print(f'Device Steam client replacements: {len(CLIENT_REPLACEMENTS)}')


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
        if link_fresh_boundaries(args.package.resolve(), output, sdk):
            raise SystemExit(1)
        link_client_replacements(args.package.resolve(), output, sdk)
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
