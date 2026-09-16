#!/usr/bin/env python3
"""Prepare locked Metal sources and build the private iOS candidate. Never installs an app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def run(*args, cwd=ROOT):
    print('+', ' '.join(str(a) for a in args), flush=True)
    subprocess.run([str(a) for a in args], cwd=cwd, check=True)

def output(*args, cwd=ROOT):
    try:
        return subprocess.check_output([str(a) for a in args], cwd=cwd, text=True).strip()
    except subprocess.CalledProcessError as error:
        if error.output:
            print(error.output, file=sys.stderr, end='')
        raise

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def checked_lock():
    main = json.loads((ROOT / 'dependencies.lock.json').read_text())
    entry = main['optional_backends']['metal']
    path = ROOT / entry['path']
    if digest(path) != entry['sha256']:
        raise ValueError('Metal lock hash mismatch')
    lock = json.loads(path.read_text())
    for name, expected in lock['files'].items():
        if digest(ROOT / name) != expected:
            raise ValueError('Metal input hash mismatch: ' + name)
    return lock

def checkout(path, source, patch=None):
    if not (path / '.git').exists():
        if path.exists() and any(path.iterdir()):
            raise ValueError('Refusing nonempty non-git source directory: ' + str(path))
        path.mkdir(parents=True, exist_ok=True)
        run('git', 'init', path)
        run('git', '-C', path, 'remote', 'add', 'origin', source['url'])
    head = subprocess.run(['git', '-C', str(path), 'rev-parse', '--verify', 'HEAD'],
                          capture_output=True, text=True)
    if head.returncode:
        run('git', '-C', path, 'fetch', '--depth', '1', source['url'], source['commit'])
        run('git', '-C', path, 'checkout', '--detach', 'FETCH_HEAD')
    elif head.stdout.strip() != source['commit']:
        raise ValueError('Wrong source revision; refusing reset: ' + str(path))
    if 'origin' not in output('git', '-C', path, 'remote').splitlines():
        run('git', '-C', path, 'remote', 'add', 'origin', source['url'])
    run('git', '-C', path, 'remote', 'set-url', '--push', 'origin', 'DISABLED-PRIVATE-ONLY')
    diff = subprocess.check_output(['git', '-C', str(path), 'diff', '--binary', 'HEAD'])
    if patch:
        expected = patch.read_bytes()
        if not diff:
            run('git', '-C', path, 'apply', '--check', patch)
            run('git', '-C', path, 'apply', patch)
            diff = subprocess.check_output(['git', '-C', str(path), 'diff', '--binary', 'HEAD'])
        if diff != expected:
            raise ValueError('Source differs from locked patch; refusing overwrite: ' + str(path))
    elif diff:
        raise ValueError('Modified dependency: ' + str(path))
    if any(line.startswith('??') for line in output('git', '-C', path, 'status', '--porcelain', '--untracked-files=all').splitlines()):
        raise ValueError('Unexpected untracked source files: ' + str(path))

def verify_game_source():
    main = json.loads((ROOT / 'dependencies.lock.json').read_text())
    source = main['sources']['freeaoe']
    base = ROOT / 'worktrees/freeaoe'
    if output('git', '-C', base, 'rev-parse', 'HEAD') != source['commit']:
        raise ValueError('Wrong game source revision')
    entry = next(item for item in main['patches'] if item['source'] == 'freeaoe')
    patch = ROOT / entry['path']
    if digest(patch) != entry['sha256']:
        raise ValueError('Game patch hash mismatch')
    if subprocess.check_output(['git', '-C', str(base), 'diff', '--binary', 'HEAD']) != patch.read_bytes():
        raise ValueError('Game worktree differs from the locked patch; preserve and review it')
    for submodule in source['submodules']:
        path = base / submodule['path']
        if output('git', '-C', path, 'rev-parse', 'HEAD') != submodule['commit']:
            raise ValueError('Wrong game dependency revision: ' + submodule['path'])
        if output('git', '-C', path, 'status', '--porcelain', '--untracked-files=all'):
            raise ValueError('Modified game dependency: ' + submodule['path'])

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=['simulator', 'device'], nargs='?', default='simulator')
    parser.add_argument('--sources-root', type=Path, default=ROOT / 'generated/metal')
    parser.add_argument('--angle-source', type=Path)
    parser.add_argument('--sfml-source', type=Path)
    parser.add_argument('--gn', default=os.environ.get('AGEPAD_GN', 'gn'))
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--angle-only', action='store_true')
    args = parser.parse_args()
    lock = checked_lock()
    angle = (args.angle_source or args.sources_root / 'angle').resolve()
    sfml = (args.sfml_source or args.sources_root / 'sfml').resolve()
    checkout(angle, lock['angle'], ROOT / lock['angle']['patch'])
    for dep in lock['dependencies']:
        checkout(angle / dep['path'], {'url': dep['url'], 'commit': dep['revision']})
    checkout(sfml, lock['sfml'], ROOT / lock['sfml']['patch'])
    if args.prepare_only:
        print('Locked Metal sources and patches verified.', flush=True)
        return
    if not args.angle_only:
        verify_game_source()
    gn = str(Path(shutil.which(args.gn) or args.gn).resolve())
    if output(gn, '--version') != lock['gn']['version']:
        raise ValueError('Wrong GN version; install the pinned package in port/metal/dependencies.lock.json')
    if sys.version_info < (3, 11):
        raise ValueError('Use Python 3.11 or later for the pinned Chromium build tools')
    installer = angle / lock['clang']['installer']
    # The pinned installer checks its installed stamp for --print-revision.
    # On a fresh checkout there is no stamp until the packages are installed.
    for package in lock['clang']['packages']:
        run(sys.executable, installer, '--package', package)
    if output(sys.executable, installer, '--print-revision') != lock['clang']['package_version']:
        raise ValueError('Installed Clang revision mismatch')
    target = 'ipadsim' if args.target == 'simulator' else 'ipaddevice'
    sdk = 'iphonesimulator' if args.target == 'simulator' else 'iphoneos'
    build = angle / 'out' / target
    build.mkdir(parents=True, exist_ok=True)
    gn_args = (ROOT / 'port/metal/args.gn').read_text()
    if args.target == 'device':
        gn_args = gn_args.replace('target_environment = "simulator"', 'target_environment = "device"')
    (build / 'args.gn').write_text(gn_args)
    shutil.copy2(ROOT / 'port/metal/gclient_args.gni', angle / 'build/config/gclient_args.gni')
    run(gn, 'gen', 'out/' + target, '--script-executable='+sys.executable, cwd=angle)
    run('ninja', '-C', build, '-j4', 'libEGL', 'libGLESv1_CM')
    if args.angle_only:
        return
    run(ROOT / 'scripts/verify-sources.sh')
    run('cmake', '--build', ROOT / 'generated/freeaoe-macos', '--target', 'resgen', '-j4')
    common = ['-G', 'Ninja', '-DCMAKE_SYSTEM_NAME=iOS', '-DCMAKE_OSX_SYSROOT='+sdk,
              '-DCMAKE_OSX_ARCHITECTURES=arm64', '-DCMAKE_OSX_DEPLOYMENT_TARGET='+lock['deployment_target']]
    freetype_build = ROOT / ('generated/freetype-metal-' + target)
    freetype_install = ROOT / ('generated/deps/freetype-metal-' + target)
    run('cmake', '-S', ROOT / 'ref/freetype-2.5.5', '-B', freetype_build, *common,
        '-DCMAKE_BUILD_TYPE=Release', '-DBUILD_SHARED_LIBS=OFF',
        '-DCMAKE_C_FLAGS=-DFT_CONFIG_OPTION_SYSTEM_ZLIB', '-DCMAKE_INSTALL_PREFIX='+str(freetype_install))
    run('cmake', '--build', freetype_build, '-j4')
    run('cmake', '--install', freetype_build)
    sfml_build = ROOT / ('generated/sfml-metal-' + target)
    sfml_install = ROOT / ('generated/deps/metal-' + target)
    run('cmake', '-S', sfml, '-B', sfml_build, *common, '-DCMAKE_BUILD_TYPE=Release',
        '-DBUILD_SHARED_LIBS=OFF', '-DCMAKE_INSTALL_PREFIX='+str(sfml_install),
        '-DSFML_BUILD_AUDIO=OFF', '-DSFML_BUILD_NETWORK=OFF', '-DSFML_BUILD_EXAMPLES=OFF',
        '-DSFML_BUILD_DOC=OFF', '-DAGEPAD_ANGLE_ROOT='+str(angle),
        '-DAGEPAD_ANGLE_FRAMEWORK_DIR='+str(build))
    run('cmake', '--build', sfml_build, '-j4')
    run('cmake', '--install', sfml_build)
    game_build = ROOT / ('generated/freeaoe-metal-' + target)
    run('cmake', '-S', ROOT / 'worktrees/freeaoe', '-B', game_build, *common,
        '-DCMAKE_BUILD_TYPE=RelWithDebInfo', '-DBUILD_TESTS=OFF',
        '-DSFML_DIR='+str(sfml_install / 'lib/cmake/SFML'), '-DSFML_STATIC_LIBRARIES=TRUE',
        '-DFreeType_LIB='+str(freetype_install / 'lib/libfreetype.a'),
        '-DAGEPAD_HOST_RESGEN='+str(ROOT / 'generated/freeaoe-macos/src/tools/resgen/resgen'))
    run('cmake', '--build', game_build, '-j4')
    executable = game_build / 'freeaoe.app/freeaoe'
    print(json.dumps({'target': args.target, 'backend': 'metal', 'executable': str(executable),
                      'sha256': digest(executable), 'frameworks': str(build)}, indent=2))

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
