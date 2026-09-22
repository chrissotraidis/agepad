#!/usr/bin/env python3
"""Build a complete AgePad Simulator candidate from your own Steam install.

This is the step-by-step bootstrap: it never needs a private runtime package,
because it rebuilds one. Every input is either a tracked source file in `port/`
or your owned Mac edition of AoE II DE.

Stages, in order:
  steam        verify the Steam installation and the adapted build identity
  audit        inventory the original app's imports (feeds the survey probe)
  shader       retarget the supplied Metal IR for the Simulator
  loader-probe build the probe that surveys what the engine imports
  survey       install, run and harvest that probe's platform survey
  boundary-1   generate the boundary libraries (pass 1: no constants yet)
  constants    read the real public Mac string constants from that manifest
  boundary-2   regenerate the boundary libraries with those constants
  resources    stage the original app's resources with the retargeted shader
  steam-module translate the supplied Steam module into the app bundle
  client-chain build the Steam client chain the engine loads by name
  runtime      build the launch-injected libraries and the host relay
  probe        build the Simulator-side bootstrap probe
  ipc-helper   build the Steam IPC helper from your Steam client
  install      install the candidate on the designated Simulator
  manifest     record the app container, boundary identity and package layout

Nothing here signs for distribution, publishes anything, or stages game data;
`scripts/prepare-de-game.py` stages the ~19 GB data tree after `install`.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time

import de_device

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DEVICE = de_device.device_udid()
BUNDLE = 'local.agepad.de-loader-probe'
# The survey probe installs under its own identity so that bootstrapping never
# replaces the container of an already installed candidate (simctl install
# replaces the whole bundle container, including manually staged siblings).
SURVEY_BUNDLE = 'local.agepad.de-survey-probe'
STEAM_DEFAULT = Path.home() / 'Library/Application Support/Steam/steamapps/common/AoE2DE'
STEAM_IPCSERVER = Path.home() / ('Library/Application Support/Steam/Steam.AppBundle/Steam/'
                                 'Contents/MacOS/ipcserver')
STEAM_CLIENT_DEFAULT = Path.home() / 'Library/Application Support/Steam/Steam.AppBundle/Steam/Contents'

# The configuration the working candidate was built with. Each flag maps to a
# `build-de-boundary-probe.py` option; keeping them here documents the candidate.
BOUNDARY_FLAGS = [
    '--application-bootstrap', '--main-executable', '--steam-module-compat',
    '--menu-model', '--window-view-host', '--application-events',
    '--alert-compat', '--pasteboard-compat', '--tracking-area-compat',
    '--cgimage-wrapper', '--default-uikit-cursor', '--pointer-snapshot',
    '--uikit-display-mode', '--min-spec-dialog', '--metal-device-observer',
    '--unavailable-gestalt', '--keyboard-layout-unavailable',
]

# Host frameworks whose public string constants the compat libraries re-export.
CONSTANT_FRAMEWORKS = ['AppKit', 'Foundation', 'CoreFoundation', 'CoreServices', 'ApplicationServices',
                       'Carbon', 'QuartzCore', 'Metal', 'MetalFX', 'AudioToolbox',
                       'AVFoundation', 'Security', 'ScriptingBridge', 'IOBluetooth',
                       'DiskArbitration', 'OpenGL', 'CoreGraphics']


def framework_paths():
    """Canonical host framework paths the reader is allowed to search.

    Every candidate symbol is offered to each framework; the reader keeps only
    symbols that resolve into a data segment, so a mis-classified function name
    cannot be dereferenced as an object.
    """
    return ['/System/Library/Frameworks/%s.framework/%s' % (name, name)
            for name in CONSTANT_FRAMEWORKS]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(args, log=None, check=True):
    text = ' '.join(str(a) for a in args)
    print('  $ ' + text)
    sys.stdout.flush()
    if log is None:
        return subprocess.run([str(a) for a in args], check=check)
    with open(log, 'a') as handle:
        handle.write('$ ' + text + '\n')
        handle.flush()
        return subprocess.run([str(a) for a in args], stdout=handle,
                              stderr=subprocess.STDOUT, check=check)


def load_module(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def app_container(device, bundle):
    out = subprocess.run(['xcrun', 'simctl', 'get_app_container', device, bundle, 'app'],
                         capture_output=True, text=True)
    return Path(out.stdout.strip()) if out.returncode == 0 else None


def data_container(device, bundle):
    out = subprocess.run(['xcrun', 'simctl', 'get_app_container', device, bundle, 'data'],
                         capture_output=True, text=True)
    return Path(out.stdout.strip()) if out.returncode == 0 else None


def set_bundle_id(app, identifier):
    info_path = app / 'Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info['CFBundleIdentifier'] = identifier
    info_path.write_bytes(plistlib.dumps(info))


def fresh_app(destination, source, identifier):
    """A private copy of the probe bundle carrying the candidate identity."""
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination, symlinks=True)
    set_bundle_id(destination, identifier)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('output', type=Path, help='Fresh build directory')
    parser.add_argument('--game', type=Path, default=STEAM_DEFAULT,
                        help='Steam AoE2DE folder (default: the Steam library)')
    parser.add_argument('--steam-client', type=Path, default=STEAM_CLIENT_DEFAULT,
                        help='Steam client Contents folder (default: the Steam app bundle)')
    parser.add_argument('--device', default=os.environ.get('AGEPAD_SIMULATOR_UDID', DEFAULT_DEVICE))
    parser.add_argument('--survey', type=Path,
                        help='Reuse an existing survey JSON instead of running the loader probe')
    parser.add_argument('--only', action='append', default=[],
                        help='Run only these stages (repeatable); later stages still need their inputs')
    parser.add_argument('--skip', action='append', default=[], help='Skip these stages (repeatable)')
    args = parser.parse_args()
    output = args.output.resolve()
    game = args.game.expanduser().resolve()
    if 'ref' in output.parts or game == output or game in output.parents:
        parser.error('Build output must be outside reference data')
    if output.exists() and not args.only:
        parser.error('Use a fresh output directory so a prior candidate stays reviewable')
    output.mkdir(parents=True, exist_ok=True)
    log = output / 'bootstrap.log'
    device = args.device
    stages = ['steam', 'audit', 'shader', 'loader-probe', 'survey', 'boundary-1',
              'constants', 'boundary-2', 'resources', 'steam-module', 'client-chain',
              'runtime', 'probe', 'ipc-helper', 'install', 'manifest']
    plan = [s for s in stages if (not args.only or s in args.only) and s not in args.skip]
    print('Build directory: ' + str(output))
    print('Stages: ' + ', '.join(plan))
    app = output / 'candidate.app'
    art = output / 'artifacts'
    art.mkdir(exist_ok=True)
    package = output / 'package'
    package.mkdir(exist_ok=True)
    survey = args.survey.resolve() if args.survey else art / 'platform-survey.json'
    shader = art / 'shader/feral.metallib'
    record = {'game': str(game), 'device': device, 'stages': {}, 'boundary_flags': BOUNDARY_FLAGS}

    def done(stage, **extra):
        record.setdefault('stages', {})[stage] = dict(
            extra, finished=time.strftime('%Y-%m-%dT%H:%M:%S'))
        (output / 'bootstrap.json').write_text(json.dumps(record, indent=2) + '\n')

    if 'steam' in plan:
        print('== steam: verify the Steam installation')
        prepare = load_module('prepare_de_game', 'scripts/prepare-de-game.py')
        if not prepare.verify_source(game):
            return 1
        done('steam', bundle_version=prepare.SUPPORTED['bundle_version'])

    if 'shader' in plan:
        print('== shader: retarget the supplied Metal IR')
        source = game / 'Age Of Empires II.app/Contents/Resources/feral.metallib'
        if not source.is_file():
            print('FAIL shader: missing ' + str(source))
            return 1
        run([sys.executable, ROOT / 'scripts/rebuild-de-shaders.py', source, shader.parent,
             '--sdk', 'iphonesimulator'], log=log)
        produced = sorted(shader.parent.glob('*.metallib'))
        if not produced:
            print('FAIL shader: rebuild produced no metallib')
            return 1
        shader = produced[0]
        done('shader', path=str(shader), sha256=digest(shader))

    audit = art / 'audit/audit.json'
    if 'audit' in plan:
        print('== audit: inventory the original app imports')
        # The auditor takes the folder that holds exactly one .app.
        run([sys.executable, ROOT / 'scripts/audit-de-bundle.py',
             game, art / 'audit'], log=log)
        if not audit.is_file():
            print('FAIL audit: ' + str(audit) + ' was not written')
            return 1
        summary = json.loads(audit.read_text())
        print('   binaries audited: %d' % len(summary.get('binaries', [])))
        done('audit', path=str(audit), sha256=digest(audit),
             binaries=len(summary.get('binaries', [])))

    if 'loader-probe' in plan:
        print('== loader-probe: build the survey probe')
        probe_app = output / 'probe.app'
        run([sys.executable, ROOT / 'scripts/build-de-loader-probe.py',
             game / 'Age Of Empires II.app', probe_app,
             '--adapt-engine', '--shader', shader, '--audit-json', audit,
             '--manifest', art / 'loader-probe-manifest.json'], log=log)
        set_bundle_id(probe_app, SURVEY_BUNDLE)
        done('loader-probe', app=str(probe_app))

    if 'survey' in plan:
        print('== survey: run the probe and harvest its platform survey')
        probe_app = output / 'probe.app'
        if not probe_app.is_dir():
            print('FAIL survey: ' + str(probe_app) + ' is missing; run the loader-probe stage')
            return 1
        run(['xcrun', 'simctl', 'install', device, probe_app], log=log)
        run(['xcrun', 'simctl', 'launch', '--terminate-running-process', device,
             SURVEY_BUNDLE], log=log)
        result = None
        seen = False
        deadline = time.time() + 120
        while time.time() < deadline:
            container = data_container(device, SURVEY_BUNDLE)
            candidate = container / 'Documents/before-engine-load.json' if container else None
            if candidate and candidate.is_file():
                seen = True
                try:
                    loaded = json.loads(candidate.read_text())
                except ValueError:
                    loaded = None
                if loaded and loaded.get('platform_survey'):
                    result = loaded
                    break
            time.sleep(2)
        if not result:
            print('FAIL survey: the probe wrote no platform survey (%s); the probe needs '
                  'Imports.json, which the audit stage supplies - see %s'
                  % ('result file present but empty' if seen else 'no result file', log))
            return 1
        survey.write_text(json.dumps(result, indent=2) + '\n')
        (art / 'platform-survey-array.json').write_text(
            json.dumps(result['platform_survey'], indent=1) + '\n')
        run(['xcrun', 'simctl', 'terminate', device, SURVEY_BUNDLE], log=log, check=False)
        loaded = sum(1 for item in result['platform_survey'] if item.get('loaded'))
        print('   survey entries: %d (%d already loaded on iOS)' % (len(result['platform_survey']), loaded))
        done('survey', path=str(survey), sha256=digest(survey),
             entries=len(result['platform_survey']))

    def boundary(target, constants):
        command = [sys.executable, ROOT / 'scripts/build-de-boundary-probe.py',
                   game / 'Age Of Empires II.app', target, survey,
                   art / (target.name + '-art')] + BOUNDARY_FLAGS
        if constants:
            command += ['--constants', constants]
        run(command, log=log)

    if 'boundary-1' in plan:
        print('== boundary-1: generate the boundary libraries')
        probe_app = output / 'probe.app'
        if not probe_app.is_dir():
            print('FAIL boundary-1: ' + str(probe_app) + ' is missing; run the loader-probe stage')
            return 1
        pass1 = fresh_app(output / 'candidate-pass1.app', probe_app, BUNDLE)
        boundary(pass1, None)
        done('boundary-1', app=str(pass1))

    if 'constants' in plan:
        print('== constants: read the public Mac string constants')
        manifest = art / 'candidate-pass1.app-art/boundary-manifest.json'
        if not manifest.is_file():
            print('FAIL constants: ' + str(manifest) + ' is missing; run boundary-1 first')
            return 1
        manifest_data = json.loads(manifest.read_text())
        wanted = set()
        for library in manifest_data.get('libraries', []):
            for entry in library.get('symbols', []):
                if str(entry.get('action', '')).startswith('NULL diagnostic data'):
                    wanted.add(entry['symbol'])
        # The Steam client chain imports AppKit/URL key constants too, and it is
        # built from symbols the boundary manifest does not list, so add the data
        # symbols those images leave undefined.
        contents = args.steam_client.expanduser().resolve()
        if contents.is_dir():
            for relative in ('MacOS/steamclient.dylib', 'MacOS/libaudio.dylib',
                             'MacOS/libtier0_s.dylib', 'MacOS/libvstdlib_s.dylib',
                             'MacOS/crashhandler.dylib'):
                image = contents / relative
                if not image.is_file():
                    continue
                out = subprocess.run(['nm', '-u', str(image)], capture_output=True, text=True)
                for line in out.stdout.splitlines():
                    symbol = line.strip()
                    if symbol.startswith(('_NS', '_k')):
                        wanted.add(symbol)
        # Read one symbol per run: a data symbol whose first word is not an object
        # can still fault the reader, and that must cost one constant, not the batch.
        library_paths = framework_paths()
        tool = art / 'HostConstants'
        run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation',
             ROOT / 'port/de/HostConstants.m', '-o', tool], log=log)
        single = art / 'constants-single.json'
        constants = {}
        skipped = []
        for symbol in sorted(wanted):
            single.write_text(json.dumps({'libraries': [
                {'path': path, 'symbols': [{'symbol': symbol,
                                            'action': 'NULL diagnostic data'}]}
                for path in library_paths]}) + '\n')
            # A faulting read can leave partial, non-UTF8 bytes on stdout, so
            # capture bytes and decode leniently rather than with text=True.
            produced = subprocess.run([tool, single], capture_output=True)
            if produced.returncode != 0:
                skipped.append(symbol)
                continue
            try:
                constants.update(json.loads(produced.stdout.decode('utf-8', 'replace') or '{}'))
            except ValueError:
                skipped.append(symbol)
        constants_path = art / 'public-constants.json'
        constants_path.write_text(json.dumps(constants, indent=2, sort_keys=True) + '\n')
        print('   public constants read: %d (skipped %d unsafe)' % (len(constants), len(skipped)))
        if not constants:
            print('FAIL constants: no constants were read; the boundary build would emit NULL data')
            return 1
        done('constants', path=str(constants_path), count=len(constants),
             sha256=digest(constants_path))

    if 'boundary-2' in plan:
        print('== boundary-2: regenerate with the measured constants')
        constants_path = art / 'public-constants.json'
        if not constants_path.is_file():
            print('FAIL boundary-2: ' + str(constants_path) + ' is missing; run the constants stage')
            return 1
        probe_app = output / 'probe.app'
        if not probe_app.is_dir():
            print('FAIL boundary-2: ' + str(probe_app) + ' is missing; run the loader-probe stage')
            return 1
        fresh_app(app, probe_app, BUNDLE)
        boundary(app, constants_path)
        done('boundary-2', app=str(app), sha256=digest(app / 'DEBoundary_AppKit.dylib'))

    if 'resources' in plan:
        print('== resources: stage resources and the retargeted shader')
        if not app.is_dir():
            print('FAIL resources: ' + str(app) + ' is missing')
            return 1
        run([sys.executable, ROOT / 'scripts/stage-de-resources.py',
             game / 'Age Of Empires II.app', app, art / 'resources.json',
             '--shader', shader], log=log)
        done('resources', manifest=str(art / 'resources.json'))

    if 'steam-module' in plan:
        print('== steam-module: translate the supplied Steam module into the app')
        original = game / 'Age Of Empires II.app/Contents/Frameworks/libsteam_api.dylib'
        if not original.is_file():
            print('FAIL steam-module: missing ' + str(original))
            return 1
        translated = app / 'Frameworks/SteamModuleSimulator.dylib'
        translated.parent.mkdir(parents=True, exist_ok=True)
        adapter = load_module('prepare_de_load_image', 'scripts/prepare-de-load-image.py')
        thin = art / 'libsteam_api.arm64.dylib'
        run(['xcrun', 'lipo', original, '-thin', 'arm64', '-output', thin], log=log)
        adapter.prepare(thin, translated, platform='ios-simulator')
        run(['codesign', '--force', '--sign', '-', translated], log=log)
        (app / 'SteamModuleCompat.json').write_text(json.dumps({
            'claim': 'Exact-module representation: file reads and validation still see '
                     'the untouched supplied module.',
            'original_sha256': digest(original),
            'translated_sha256': digest(translated)}, indent=2) + '\n')
        done('steam-module', translated=str(translated),
             original_sha256=digest(original), translated_sha256=digest(translated))

    if 'client-chain' in plan:
        print('== client-chain: build the Steam client chain the engine loads by name')
        contents = args.steam_client.expanduser().resolve()
        if not (contents / 'MacOS/steamclient.dylib').is_file():
            print('FAIL client-chain: ' + str(contents) + ' has no MacOS/steamclient.dylib')
            return 1
        audit_path = art / 'steam-client-audit.json'
        run([sys.executable, ROOT / 'scripts/audit-de-steam-client.py', contents, audit_path], log=log)
        # The client boundary set must be decided by what the Simulator actually
        # lacks for these images, not by the engine's own survey. LibrarySymbolSurvey
        # is the tracked tool for that: it runs inside the Simulator and reports the
        # missing symbols per dependency.
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'],
                                      text=True).strip()
        survey_tool = art / 'LibrarySymbolSurvey'
        run(['xcrun', 'clang', '-target', 'arm64-apple-ios17.0-simulator', '-isysroot', sdk,
             '-fobjc-arc', '-framework', 'Foundation',
             ROOT / 'port/de/LibrarySymbolSurvey.m', '-o', survey_tool], log=log)
        run(['codesign', '--force', '--sign', '-', survey_tool], log=log)
        audit_data = json.loads(audit_path.read_text())
        wanted = {}
        for relative, record in audit_data.items():
            symbols_by_dep = {}
            found = subprocess.run(['xcrun', 'nm', '-arch', 'arm64', '-m', '-u',
                                    str(contents / relative)], capture_output=True, text=True)
            for match in re.finditer(r'external (\S+) \(from ([^)]+)\)', found.stdout):
                symbols_by_dep.setdefault(match.group(2), set()).add(match.group(1))
            for entry in record['dependencies']:
                if entry['kind'] != 'system':
                    continue
                key = Path(entry['path']).name
                symbols = sorted(symbols_by_dep.get(key, set()) - {'dyld_stub_binder'})
                if symbols:
                    wanted.setdefault(entry['path'], set()).update(symbols)
        # Load commands carry macOS framework paths (`…framework/Versions/A/…`),
        # which do not resolve inside the Simulator: every symbol then looks
        # missing and frameworks that exist on iOS get bogus boundary libraries.
        # Survey the iOS form; the builder matches results by name.
        survey_input = art / 'steam-client-survey-input.json'
        survey_input.write_text(json.dumps([
            {'path': re.sub(r'(\.framework)/Versions/[^/]+/', r'\1/', path),
             'symbols': sorted(symbols)} for path, symbols in sorted(wanted.items())], indent=1) + '\n')
        measured = subprocess.run(['xcrun', 'simctl', 'spawn', device, str(survey_tool),
                                   str(survey_input)], capture_output=True, text=True, check=True)
        client_survey = art / 'steam-client-survey.json'
        client_survey.write_text(measured.stdout)
        survey_missing = sum(len(entry['missing_symbols'])
                             for entry in json.loads(measured.stdout))
        print('   client dependencies surveyed: %d, missing symbols: %d'
              % (len(wanted), survey_missing))
        destination = package / 'game-client'
        if destination.exists():
            shutil.rmtree(destination)
        run([sys.executable, ROOT / 'scripts/build-de-steam-client-boundary.py', contents,
             audit_path, art / 'public-constants.json', destination,
             '--survey', client_survey], log=log)
        if not (destination / 'steamclient.dylib').is_file():
            print('FAIL client-chain: no steamclient.dylib was produced; see ' + str(log))
            return 1
        # Keep the app's own boundary libraries beside the client chain, as the
        # working package does, so a bare-name lookup finds the same images.
        for library in sorted(app.glob('DEBoundary_*.dylib')):
            shutil.copy2(library, destination / library.name)
        done('client-chain', path=str(destination),
             files=sorted(p.name for p in destination.iterdir()))

    if 'runtime' in plan:
        print('== runtime: build the launch-injected libraries and the relay')
        run([sys.executable, ROOT / 'scripts/build-de-injected-runtime.py', art / 'runtime'], log=log)
        for item in sorted((art / 'runtime').iterdir()):
            if item.is_file() and item.suffix in ('.dylib', '') and item.name != 'manifest.json':
                shutil.copy2(item, package / item.name)
        done('runtime', files=sorted(p.name for p in package.iterdir()))

    if 'probe' in plan:
        print('== probe: build the Simulator-side bootstrap probe')
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'],
                                      text=True).strip()
        kernel = package / 'simulator-kernel'
        # The runner spawns this probe with no arguments and reads its JSON route
        # survey, so it is the read-only routes probe, not the pid-taking one.
        run(['xcrun', 'clang', '-target', 'arm64-apple-ios17.0-simulator', '-isysroot', sdk,
             ROOT / 'port/de/BootstrapRoutesProbe.c', '-o', kernel], log=log)
        run(['codesign', '--force', '--sign', '-', kernel], log=log)
        done('probe', path=str(kernel))

    if 'ipc-helper' in plan:
        print('== ipc-helper: build the Steam IPC helper from your Steam client')
        if not STEAM_IPCSERVER.is_file():
            print('FAIL ipc-helper: missing ' + str(STEAM_IPCSERVER))
            return 1
        run([sys.executable, ROOT / 'scripts/build-de-ipc-helper.py', STEAM_IPCSERVER,
             package / 'ipc-helper-relay'], log=log)
        done('ipc-helper', path=str(package / 'ipc-helper-relay'))

    if 'install' in plan:
        print('== install: install the candidate on the designated Simulator')
        if not app.is_dir():
            print('FAIL install: ' + str(app) + ' is missing')
            return 1
        run(['xcrun', 'simctl', 'install', device, app], log=log)
        container = app_container(device, BUNDLE)
        done('install', app=str(container) if container else None)

    if 'manifest' in plan:
        print('== manifest: record the package layout')
        container = app_container(device, BUNDLE)
        if not container:
            print('FAIL manifest: the candidate is not installed')
            return 1
        boundary_path = container / 'DEBoundary_AppKit.dylib'
        if not boundary_path.is_file():
            print('FAIL manifest: installed candidate has no DEBoundary_AppKit.dylib')
            return 1
        (package / 'game-client').mkdir(exist_ok=True)
        # The Steam client chain is not rebuilt yet: the engine dlopens bare names
        # (steamclient.dylib and friends) through DYLD_LIBRARY_PATH=game-client, and
        # without them the launch reaches the menu model and exits. Record the
        # state instead of implying a launchable package.
        client_chain = sorted(p.name for p in (package / 'game-client').glob('*.dylib'))
        if not (package / 'game-client/steamclient.dylib').is_file():
            print('WARNING game-client/ has no steamclient.dylib: the Steam client chain is '
                  'not rebuilt yet, so the launch will exit before presenting. See '
                  'docs/DE-BOOTSTRAP-20260919.md.')
        (package / 'game-client-appkit.json').write_text(json.dumps({
            'app': str(container), 'boundary': str(boundary_path),
            'sha256': digest(boundary_path),
            'purpose': 'Reexport already loaded game AppKit adapter classes; retain '
                       'measured public constants and avoid duplicate diagnostic classes.'},
            indent=2) + '\n')
        (output / 'package.json').write_text(json.dumps({
            'package': str(package), 'candidate_app': str(app),
            'installed_app': str(container), 'survey': str(survey),
            'constants': str(art / 'public-constants.json'),
            'client_chain_present': (package / 'game-client/steamclient.dylib').is_file(),
            'client_chain_files': client_chain}, indent=2) + '\n')
        done('manifest', package=str(package), installed_app=str(container))

    print('\nBootstrap complete: ' + str(output))
    print('Launch with:')
    print('  python3 scripts/recover-de-session.py <run-name> --package %s --probe %s'
          % (package, package / 'simulator-kernel'))
    print('Game data still has to be staged next to the installed app:')
    print('  python3 scripts/prepare-de-game.py')
    return 0


if __name__ == '__main__':
    sys.exit(main())
