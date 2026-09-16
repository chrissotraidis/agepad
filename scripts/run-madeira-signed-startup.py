#!/usr/bin/env python3
"""Install the full runtime in a separate bundle and observe signed ntdll startup.

Requires a rebuilt Madeira app containing the opt-in adapter. This is a bounded
startup observation, not a game/Windows process success verifier.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import struct
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--label', required=True)
parser.add_argument('--probe-bundle', action='store_true', help='Use isolated local.agepad.runtime-probe app/profile on the same designated Simulator, preserving the Steam diagnostic installation')
parser.add_argument('--app-template', type=Path, help='Explicit source app bundle for a native runtime experiment; default is the baseline build')
parser.add_argument('--fex-container', type=Path, help='Explicit root-only FEX container for source-owned diagnostic probes; incompatible with child banks')
parser.add_argument('--signed-child-ntdll', action='store_true', help='Initialize first child with private signed ntdll (other child ownership remains experimental)')
parser.add_argument('--child-banks', type=int, choices=range(1,17), default=1, help='Number of private child banks to stage; never recycled in a run')
parser.add_argument('--retail-processes', action='store_true', help='Preserve original process requests and arguments; bypass inherited helper filters and CEF argument rewriting')
parser.add_argument('--dispatch-pending-work', action='store_true', help='Experimental pending work-list check before dispatcher cache hits')
parser.add_argument('--shared-process-memory', action='store_true', help='Experimental memory transfer between registered signed guests in this host')
parser.add_argument('--present-readback', action='store_true', help='Simulator diagnostic: copy four presented textures to private PPM files; affects timing')
parser.add_argument('--http-trace', action='store_true', help='Diagnostic WinHTTP trace; use only before authentication')
parser.add_argument('--certificate-trace', action='store_true', help='Diagnostic certificate chain/revocation tracing; use before authentication only')
parser.add_argument('--encode-texture-ids', action='store_true', help='Simulator experiment: encode zero texture IDs through Metal argument encoder')
parser.add_argument('--reuse-jit-chunks', action='store_true', help='Simulator experiment: reuse full released JIT chunks of the same size and owner')
parser.add_argument('--startup-trace', action='store_true', help='Diagnostic retail CEF execution register trace; affects timing')
parser.add_argument('--explicit-memory-flush', action='store_true', help='Experimental memory notifications rely on checked delinker flushes')
parser.add_argument('--explicit-compile-flush', action='store_true', help='Experimental normal compilation relies on checked emitted-block flush; requires cache-hit mode')
parser.add_argument('--explicit-invalidation-flush', action='store_true', help='Experimental flush/dirty callbacks rely on checked delinker instruction flushes')
parser.add_argument('--cache-hit-explicit-flush', action='store_true', help='Experimental lookup-only explicit flush with conservative compilation and queued-work scopes')
parser.add_argument('--direct-asm-teb', action='store_true', help='Experimental FEX transition assembly reads using the published per-bank TSD offset')
parser.add_argument('--direct-teb-check', action='store_true', help='Experimental call checker using the published TSD offset instead of fault-emulated x18')
parser.add_argument('--explicit-link-flush', action='store_true', help='Experimental audited linker flush; nested conservative scopes still flush the full region')
parser.add_argument('--services-exe', type=Path, help='Stage source-built x64 services.exe in the diagnostic system directory')
parser.add_argument('--bootstrap-services', action='store_true', help='Opt in to service startup before the initial guest entry; requires services.exe')
parser.add_argument('--bootstrap-rpcss', action='store_true', help='Start and verify real RpcSs before the guest entry; requires service bootstrap and rpcss.exe')
parser.add_argument('--usd-time', action=argparse.BooleanOptionalAction, default=True, help='Publish shared Windows time (default on); --no-usd-time is only for negative controls')
parser.add_argument('--unlocked-jit-flush', action='store_true', help='Experimental full cache flush outside the metadata lock; preserves signal masking and execution protection ordering')
parser.add_argument('--jit-pool-mib', type=int, choices=[64,128,256,512,1024], default=64, help='Bounded native JIT pool size; 1024 is a Simulator diagnostic; released chunks remain quarantined')
parser.add_argument('--guest-arg', action='append', default=[], help='One literal guest argument; current bridge supports at most 16 nonempty tokens without whitespace or quotes')
parser.add_argument('--msctf-dll', type=Path, help='Stage source-built x64 Wine text-services DLL')
parser.add_argument('--crypt32-dll', type=Path, help='Stage source-built x64 Crypt32 diagnostic DLL')
parser.add_argument('--rpcss-exe', type=Path, help='Stage source-built x64 rpcss.exe in the diagnostic system directory')
parser.add_argument('--conhost-exe', type=Path, help='Stage a source-built x64 Wine console host in the active system directory')
parser.add_argument('--child-bank-preflight', action='store_true', help='Check independent signed child ntdll storage before guest startup')
parser.add_argument('--wininet', action='store_true', help='Stage source-built WinINet container')
parser.add_argument('--graphics', action='store_true', help='Stage source-built graphics containers')
parser.add_argument('--exe', type=Path, help='Windows executable to stage and launch')
parser.add_argument('--guest-dir', type=Path, help='Copy a complete guest installation into an isolated per-run Wine directory')
parser.add_argument('--force-late-image-copy', action='store_true', help='Probe only: force image-copy fallback for the two source-owned late-load DLLs')
parser.add_argument('--retire-fex-state', action='store_true', help='Probe-only native FEX-state drain; requires an enabled FEX build')
parser.add_argument('--retire-fex-callbacks', action='store_true', help='Experimental callback retirement at final native process exit; does not enable bank reuse')
parser.add_argument('--abort-fex-cleanup', action='store_true', help='Experimental FEX self cleanup for terminated server waiters')
args = parser.parse_args()
if args.force_late_image_copy and (not args.probe_bundle or not args.retire_fex_callbacks):
    parser.error('--force-late-image-copy requires --probe-bundle and --retire-fex-callbacks')
if args.retire_fex_state and (not args.probe_bundle or not args.retire_fex_callbacks):
    parser.error('--retire-fex-state requires --probe-bundle and --retire-fex-callbacks')
if args.retire_fex_callbacks and not args.abort_fex_cleanup:
    parser.error('--retire-fex-callbacks requires --abort-fex-cleanup')
if args.explicit_compile_flush and not args.cache_hit_explicit_flush:
    parser.error('--explicit-compile-flush requires --cache-hit-explicit-flush')
if len(args.guest_arg)>16 or any(not value or any(c.isspace() or c in '\"\'' for c in value) for value in args.guest_arg) or len(' '.join(args.guest_arg).encode())>1023:
    parser.error('Guest arguments exceed the native bridge token/size limits or require unsupported quoting')
if args.bootstrap_rpcss and (not args.bootstrap_services or not args.rpcss_exe):
    parser.error('--bootstrap-rpcss requires --bootstrap-services and --rpcss-exe')
if args.bootstrap_services and not args.services_exe:
    parser.error('--bootstrap-services requires --services-exe')
if args.guest_dir and not args.exe:
    parser.error('--guest-dir requires --exe')
if args.guest_dir:
    guest_root = args.guest_dir.resolve(strict=True)
    guest_relative = args.exe.resolve(strict=True).relative_to(guest_root)
    if any(p.is_symlink() for p in guest_root.rglob('*')):
        parser.error('Guest intake must contain regular files/directories, not symlinks')
if not args.label.replace('-', '').isalnum():
    raise SystemExit('Use an alphanumeric label with optional hyphens.')
r = Path(__file__).resolve().parents[1]
device = '574671AD-6F61-4558-9528-BF946DDB760A'
bundle = 'local.agepad.runtime-probe' if args.probe_bundle else 'local.agepad.signed-startup'
inv = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','-j']))
assert [d['udid'] for group in inv['devices'].values() for d in group if d['state']=='Booted'] == [device]
if args.fex_container and (args.signed_child_ntdll or args.child_bank_preflight):
    parser.error('--fex-container does not support child banks')
def dependency_path(name):
    return args.fex_container.resolve(strict=True) if name == 'xtajit64' and args.fex_container else r/'generated/madeira-containers'/name
dependencies = ['xtajit64','ucrtbase','kernel32','kernelbase']
if args.graphics: dependencies += ['d3d11','dxgi','winemetal','gdi32','user32','advapi32','win32u','sechost','msvcrt']
if args.wininet: dependencies += ['wininet']
# Refuse stale generated containers before installing anything.
for manifest_path in [r/'generated/madeira-pe-container-ntdll/manifest.json'] + [dependency_path(name)/'manifest.json' for name in dependencies]:
    manifest = json.loads(manifest_path.read_text())
    source = Path(manifest['source'])
    if not source.exists() or hashlib.sha256(source.read_bytes()).hexdigest() != manifest['source_sha256']:
        raise SystemExit(f'Stale container: rebuild {manifest_path.parent} from the current PE DLL.')
    dylib = manifest_path.parent/'AgePadPEProbe.app/Frameworks/PEContainer.dylib'
    if hashlib.sha256(dylib.read_bytes()).hexdigest() != manifest['dylib_sha256']:
        raise SystemExit(f'Container hash mismatch: {dylib}')
if args.child_bank_preflight or args.signed_child_ntdll:
    child_modules = ['ntdll'] + (dependencies if args.signed_child_ntdll else [])
    if len(child_modules) * args.child_banks + len(dependencies) + 1 > 256:
        raise SystemExit('Selected banks exceed the native/PE 256-entry registration table')
    banks = []
    for slot in range(1, args.child_banks + 1):
        bank_path = r/f'generated/madeira-child-banks/child-{slot}/bank.json'
        bank = json.loads(bank_path.read_text())
        assert bank['slot'] == slot
        banks.append((slot, bank_path, bank))
        for name in child_modules:
            item = bank['modules'][name]
            for key, digest in [('source','source_sha256'), ('dylib','dylib_sha256')]:
                if hashlib.sha256(Path(item[key]).read_bytes()).hexdigest() != item[digest]:
                    raise SystemExit('Stale child bank: ' + name)
out = r / 'generated/madeira-signed-startup' / args.label
out.mkdir(parents=True, exist_ok=False)
helper_paths = {}
for name, supplied, suffix in [('conhost', args.conhost_exe, '.exe'), ('services', args.services_exe, '.exe'), ('rpcss', args.rpcss_exe, '.exe'), ('msctf', args.msctf_dll, '.dll'), ('crypt32', args.crypt32_dll, '.dll')]:
    if supplied is None:
        continue
    helper = supplied.resolve(strict=True)
    data = helper.read_bytes()
    if len(data) < 64 or data[:2] != b'MZ':
        raise SystemExit(f'{name} must be a PE x64 {name}{suffix}')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    if helper.name != name+suffix or offset > len(data)-24 or data[offset:offset+4] != b'PE\0\0' or struct.unpack_from('<H', data, offset+4)[0] != 0x8664:
        raise SystemExit(f'{name} must be a PE x64 {name}{suffix}')
    helper_paths[name] = helper
    (out/(name+'-manifest.json')).write_text(json.dumps({'source':str(helper),'sha256':hashlib.sha256(data).hexdigest()},indent=2)+'\n')
app_template = (args.app_template or r/'generated/madeira-baseline/Build/Products/Debug-iphonesimulator/Madeira.app').resolve(strict=True)
if not (app_template/'Info.plist').is_file() or not (app_template/'Madeira').is_file():
    raise SystemExit('App template must contain Info.plist and Madeira executable')
app = r / 'generated/madeira-signed-startup/Madeira.app'
if app_template == app.resolve() or app.resolve() in app_template.parents:
    raise SystemExit('App template must be outside the staging destination')
if app.exists(): shutil.rmtree(app)
shutil.copytree(app_template, app, dirs_exist_ok=True)
for name, helper in helper_paths.items():
    shutil.copy2(helper, app/'arm64ec-windows'/helper.name)
p = app/'Info.plist'
info = plistlib.loads(p.read_bytes()); info['CFBundleIdentifier'] = bundle
p.write_bytes(plistlib.dumps(info))
if args.exe:
    exe = args.exe.resolve(strict=True)
    if exe.suffix.lower() != '.exe' or not all(c.isalnum() or c in '-_.' for c in exe.name):
        raise SystemExit('Diagnostic must have a simple .exe filename')
    if not args.guest_dir:
        shutil.copy2(exe, app/'arm64ec-windows'/exe.name)
    (out/'guest-manifest.json').write_text(json.dumps({'source':str(exe), 'sha256':hashlib.sha256(exe.read_bytes()).hexdigest()},indent=2))
(app/'Frameworks').mkdir(exist_ok=True)
shutil.copy2(r/'generated/madeira-pe-container-ntdll/AgePadPEProbe.app/Frameworks/PEContainer.dylib', app/'Frameworks/PEContainer.dylib')
shutil.copy2(r/'generated/madeira-pe-container-ntdll/manifest.json', out/'container-manifest.json')
for name in dependencies:
    dependency = dependency_path(name)
    dep_manifest = json.loads((dependency/'manifest.json').read_text())
    shutil.copy2(Path(dep_manifest['source']), app/'arm64ec-windows'/(name+'.dll'))
    shutil.copy2(dependency/'AgePadPEProbe.app/Frameworks/PEContainer.dylib', app/'Frameworks'/(name+'.dll.dylib'))
    shutil.copy2(dependency/'manifest.json', out/(name+'-manifest.json'))
if args.child_bank_preflight or args.signed_child_ntdll:
    for slot, bank_path, bank in banks:
        for name in child_modules:
            shutil.copy2(bank['modules'][name]['dylib'], app/'Frameworks'/f'{name}-child-{slot}.dll.dylib')
        shutil.copy2(bank_path, out/f'child-bank-{slot}.json')
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--strict',str(app)],check=True)
subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
container = Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,bundle,'data'],text=True).strip())
# The signed diagnostic uses the Wine 'wine' profile; the app's legacy repair
# only populates users/madeira. Cryptnet checks LocalLow existence before it
# can create its own revocation cache. Preserve all existing profile contents.
profile_low = container/'Documents/wine/drive_c/users/wine/AppData/LocalLow'
profile_low.mkdir(parents=True, exist_ok=True)
if args.guest_dir:
    destination = container/'Documents/wine/drive_c/AgePadGuests'/args.label
    shutil.copytree(guest_root, destination)
    (out/'guest-files.json').write_text(json.dumps({str(p.relative_to(guest_root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in guest_root.rglob('*') if p.is_file()},indent=2)+'\n')
log = container/'Documents/madeira-log.txt'
if log.exists():
    shutil.copy2(log,out/'previous-runtime.log')
    log.unlink()
env = dict(os.environ, SIMCTL_CHILD_AGEPAD_SIGNED_STARTUP='1')
env['SIMCTL_CHILD_AGEPAD_JIT_POOL_MIB'] = str(args.jit_pool_mib)
env['SIMCTL_CHILD_AGEPAD_UNLOCKED_JIT_FLUSH'] = '1' if args.unlocked_jit_flush else '0'
env['SIMCTL_CHILD_MADEIRA_ARGS'] = ' '.join(args.guest_arg)
if args.bootstrap_services:
    env['SIMCTL_CHILD_AGEPAD_BOOTSTRAP_SERVICES'] = '1'
env['SIMCTL_CHILD_AGEPAD_TEST_FORCE_LATE_IMAGE_COPY'] = '1' if args.force_late_image_copy else '0'
env['SIMCTL_CHILD_AGEPAD_RETIRE_FEX_STATE'] = '1' if args.retire_fex_state else '0'
env['SIMCTL_CHILD_AGEPAD_RETIRE_FEX_CALLBACKS'] = '1' if args.retire_fex_callbacks else '0'
env['SIMCTL_CHILD_AGEPAD_ABORT_FEX_CLEANUP'] = '1' if args.abort_fex_cleanup else '0'
env['SIMCTL_CHILD_MADEIRA_USD_TIME'] = '1' if args.usd_time else '0'
if args.bootstrap_rpcss:
    env['SIMCTL_CHILD_AGEPAD_BOOTSTRAP_RPCSS'] = '1'
if args.wininet: env['SIMCTL_CHILD_AGEPAD_SIGNED_WININET'] = '1'
if args.child_bank_preflight: env['SIMCTL_CHILD_AGEPAD_CHILD_BANK_PREFLIGHT'] = '1'
if args.signed_child_ntdll: env['SIMCTL_CHILD_AGEPAD_SIGNED_CHILD_NTDLL'] = '1'
if args.retail_processes: env['SIMCTL_CHILD_AGEPAD_RETAIL_PROCESSES'] = '1'
if args.direct_teb_check: env['SIMCTL_CHILD_AGEPAD_DIRECT_TEB_CHECK'] = '1'
env['SIMCTL_CHILD_AGEPAD_DIRECT_ASM_TEB'] = '1' if args.direct_asm_teb else '0'
env['SIMCTL_CHILD_AGEPAD_PRESENT_READBACK'] = '1' if args.present_readback else '0'
env['SIMCTL_CHILD_AGEPAD_HTTP_TRACE'] = '1' if args.http_trace else '0'
env['SIMCTL_CHILD_AGEPAD_CERTIFICATE_TRACE'] = '1' if args.certificate_trace else '0'
env['SIMCTL_CHILD_AGEPAD_ENCODE_TEXTURE_IDS'] = '1' if args.encode_texture_ids else '0'
env['SIMCTL_CHILD_AGEPAD_REUSE_JIT_CHUNKS'] = '1' if args.reuse_jit_chunks else '0'
env['SIMCTL_CHILD_AGEPAD_STARTUP_TRACE'] = '1' if args.startup_trace else '0'
env['SIMCTL_CHILD_AGEPAD_EXPLICIT_MEMORY_FLUSH'] = '1' if args.explicit_memory_flush else '0'
env['SIMCTL_CHILD_AGEPAD_EXPLICIT_COMPILE_FLUSH'] = '1' if args.explicit_compile_flush else '0'
env['SIMCTL_CHILD_AGEPAD_EXPLICIT_INVALIDATION_FLUSH'] = '1' if args.explicit_invalidation_flush else '0'
env['SIMCTL_CHILD_AGEPAD_CACHE_HIT_EXPLICIT_FLUSH'] = '1' if args.cache_hit_explicit_flush else '0'
env['SIMCTL_CHILD_AGEPAD_SHARED_PROCESS_MEMORY'] = '1' if args.shared_process_memory else '0'
env['SIMCTL_CHILD_AGEPAD_DISPATCH_PENDING_WORK'] = '1' if args.dispatch_pending_work else '0'
if args.explicit_link_flush: env['SIMCTL_CHILD_AGEPAD_EXPLICIT_LINK_FLUSH'] = '1'
if args.exe:
    env['SIMCTL_CHILD_AGEPAD_TEST_EXE'] = ('C:\\AgePadGuests\\' + args.label + '\\' + str(guest_relative).replace('/', '\\')) if args.guest_dir else exe.name
if args.graphics: env['SIMCTL_CHILD_MADEIRA_WIN32U'] = '1'
launch = subprocess.check_output(['xcrun','simctl','launch','--terminate-running-process','--stderr=/tmp/agepad-signed-startup.log',device,bundle],env=env,text=True).strip()
pid = launch.rsplit(':',1)[-1].strip()
deadline = time.monotonic()+15
state = None
while time.monotonic()<deadline:
    time.sleep(0.5)
    state = subprocess.run(['ps','-p',pid,'-o','pid=,stat=,pcpu='],capture_output=True,text=True)
    if state.returncode:
        break
if log.exists():
    shutil.copy2(log,out/'runtime.log')
report = {'fex_container_override':str(args.fex_container.resolve()) if args.fex_container else None,'app_template':str(app_template),'device':device,'container':str(container),'bundle':bundle,'launch':launch,
          'profile_locallow_prepared':profile_low.is_dir(),'http_trace':args.http_trace,'certificate_trace':args.certificate_trace,'encode_texture_ids':args.encode_texture_ids,'present_readback':args.present_readback,'reuse_jit_chunks':args.reuse_jit_chunks,'startup_trace':args.startup_trace,'retail_processes':args.retail_processes,'bootstrap_services':args.bootstrap_services,'bootstrap_rpcss':args.bootstrap_rpcss,'usd_time':args.usd_time,'jit_pool_mib':args.jit_pool_mib,'unlocked_jit_flush':args.unlocked_jit_flush,'guest_args':args.guest_arg,'signed_child_banks':args.child_banks if args.signed_child_ntdll else 0,
          'explicit_link_flush':args.explicit_link_flush,'direct_teb_check':args.direct_teb_check,'direct_asm_teb':args.direct_asm_teb,'cache_hit_explicit_flush':args.cache_hit_explicit_flush,'explicit_invalidation_flush':args.explicit_invalidation_flush,'explicit_compile_flush':args.explicit_compile_flush,'explicit_memory_flush':args.explicit_memory_flush,'shared_process_memory':args.shared_process_memory,'dispatch_pending_work':args.dispatch_pending_work,'abort_fex_cleanup':args.abort_fex_cleanup,'retire_fex_callbacks':args.retire_fex_callbacks,'retire_fex_state':args.retire_fex_state,'force_late_image_copy':args.force_late_image_copy,
          'runtime_executable_sha256':hashlib.sha256((app/info['CFBundleExecutable']).read_bytes()).hexdigest(),
          'process_snapshot':state.stdout.strip(),'process_exists':state.returncode==0,
          'scope':'Startup observation only; inspect runtime log. No automatic pass claim.'}
(out/'run.json').write_text(json.dumps(report,indent=2)+'\n')
subprocess.run(['xcrun','simctl','io',device,'screenshot',str(out/'simulator.png')],check=True)
print(json.dumps(report,indent=2))
