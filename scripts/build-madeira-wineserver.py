#!/usr/bin/env python3
"""Reconstruct Madeira's Wine server archive from source, without a base .a.

Outputs are diagnostic build artifacts, not evidence of Windows execution.
Run with Python 3.9+. The configured Wine host tree supplies generated headers.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=Path, default=ROOT / 'worktrees/madeira')
p.add_argument('--sdk', choices=['iphonesimulator', 'iphoneos'], default='iphonesimulator')
p.add_argument('--jobs', type=int, default=6)
p.add_argument('--objcopy', type=Path, default=Path('/opt/homebrew/opt/llvm@20/bin/llvm-objcopy'))
a = p.parse_args()
src = a.source.resolve()
wine = src / 'wine'
overlay = src / 'build/wineserver'
out = ROOT / 'generated' / ('madeira-wineserver-' + a.sdk)
out.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', a.sdk, '--show-sdk-path'], text=True).strip()
target = 'arm64-apple-ios17.0' + ('-simulator' if a.sdk == 'iphonesimulator' else '')
flags = ['xcrun', '--sdk', a.sdk, 'clang', '-target', target, '-isysroot', sdk,
         '-O2', '-fPIC', '-fno-strict-aliasing', '-Wno-implicit-function-declaration',
         '-D__WINESRC__', '-DWINE_IOS=1', '-Dmain=wineserver_main',
         '-DBINDIR="/usr/local/bin"', '-DDATADIR="/usr/local/share"']
for folder in [overlay, wine / 'include', wine / 'include/wine',
               wine / 'build-macos/include', wine / 'server', src / 'build/ntdll-unix/shims']:
    flags += ['-I', str(folder)]
for header in [overlay / 'config_ios.h', 'stdarg.h', overlay / 'unicode_fix.h']:
    flags += ['-include', str(header)]
sources = re.findall(r'^\s*([a-z0-9_]+\.c)\s*', (wine / 'server/Makefile.in').read_text(), re.M)
entries = []
for name in sources:
    adapted = overlay / (Path(name).stem + '_ios.c')
    entries.append((Path(name).stem, adapted if adapted.exists() else wine / 'server' / name))
entries += [(name, overlay / (name + '.c')) for name in ['wine_log_ios', 'wineserver_ios_kill']]

def compile_one(entry):
    name, path = entry
    cmd = flags.copy()
    if name != 'wineserver_ios_kill':
        cmd += ['-include', str(overlay / 'wineserver_ios_kill.h')]
    obj = out / (name + '.o')
    obj.unlink(missing_ok=True)
    cmd += ['-c', str(path), '-o', str(obj)]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (out / (name + '.log')).write_text(result.stdout)
    return {'name': name, 'source': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'command': cmd, 'exit_code': result.returncode}

archive = out / 'libwineserver.a'
archive.unlink(missing_ok=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
    results = list(pool.map(compile_one, entries))
failed = [r['name'] for r in results if r['exit_code']]
manifest = {'sdk': a.sdk, 'target': target, 'sources': results, 'failed': failed,
            'archive_created': False, 'runtime_tested': False}
if not failed:
    # Match Madeira's archive-local symbol separation from win32u/ntdll.
    collisions = ['alloc_user_handle', 'free_user_handle', 'get_virtual_screen_rect',
                  'destroy_thread_windows', 'get_window_thread', 'is_desktop_class',
                  'is_message_class', 'is_window_visible', 'mirror_region', 'send_notify_message',
                  'shared_session', 'user_shared_data']
    rename = [str(a.objcopy)]
    for symbol in collisions:
        rename += ['--redefine-sym', '_' + symbol + '=_ws_' + symbol]
    for result in results:
        subprocess.run(rename + [str(out / (result['name'] + '.o'))], check=True)
    manifest['archive_symbol_renames'] = collisions
    subprocess.run(['xcrun', 'libtool', '-static', '-o', str(archive)] +
                   [str(out / (r['name'] + '.o')) for r in results], check=True)
    manifest['archive_created'] = True
    manifest['archive_sha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'compiled': len(results) - len(failed), 'failed': failed, 'output': str(out)}))
sys.exit(bool(failed))
