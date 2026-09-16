#!/usr/bin/env python3
"""Build pinned DXMT ARM64EC graphics and Wine dependencies; no Simulator launch.
Apply the local patches and build Windows core first. Meson is isolated/pinned.
"""
from pathlib import Path
import os, subprocess, sys, json, hashlib
r=Path(__file__).resolve().parents[1];m=r/'worktrees/madeira';out=r/'generated/dxmt-windows-build';out.mkdir(parents=True,exist_ok=True)
venv=r/'generated/windows-build-venv';bin=m/'toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin'
if not (venv/'bin/python').exists():subprocess.run([sys.executable,'-m','venv',str(venv)],check=True)
subprocess.run([str(venv/'bin/python'),'-m','pip','install','meson==1.7.2'],check=True,stdout=(out/'meson-install.log').open('w'),stderr=subprocess.STDOUT)
env=dict(os.environ);env['PATH']=os.pathsep.join([str(venv/'bin'),str(r/'generated/madeira-host-bin'),str(bin),'/opt/homebrew/opt/bison/bin',env['PATH']])
def run(command,log):
    with (out/log).open('w') as f:subprocess.run(command,cwd=r,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
wine_names=['gdi32','user32','advapi32','win32u','sechost','msvcrt','dbghelp']
run(['make','-C',str(m/'wine/build-arm64ec'),'-j6','arm64ec_CFLAGS=-g -O2 -DAGEPAD_SIGNED_WINE_TSD=1']+[f'dlls/{n}/arm64ec-windows/{n}.dll' for n in wine_names]+['dlls/dbghelp/arm64ec-windows/libdbghelp.a','libs/winecrt0/arm64ec-windows/libwinecrt0.a'],'wine-build.log')
cross=r/'generated/dxmt-arm64ec-cross.ini'
lines=['[binaries]']+[f"{k} = '{bin}/arm64ec-w64-mingw32-{v}'" for k,v in {'c':'clang','cpp':'clang++','ar':'ar','strip':'strip','windres':'windres'}.items()]
lines += ['[properties]','needs_exe_wrapper = true','[host_machine]',"system = 'windows'","cpu_family = 'aarch64'","cpu = 'aarch64'","endian = 'little'"]
cross.write_text('\n'.join(lines)+'\n')
build=r/'generated/dxmt-windows-arm64ec'
cmd=['meson','setup',str(build),str(m/'research/dxmt'),'--cross-file',str(cross),'-Dbuildtype=release',f'-Dwine_build_path={m}/wine/build-arm64ec',f'-Dwine_tools_path={m}/wine/build-macos','-Dwine_builtin_dll=true','-Dmetal_sdk=iphonesimulator']
if (build/'meson-private/coredata.dat').exists():cmd.append('--reconfigure')
run(cmd,'dxmt-configure.log');run(['meson','compile','-C',str(build),'-j6'],'dxmt-build.log')
sources={n:build/f'src/{n}/{n}.dll' for n in ['d3d11','dxgi','winemetal']}
sources.update({n:m/f'wine/build-arm64ec/dlls/{n}/arm64ec-windows/{n}.dll' for n in wine_names if n!='dbghelp'})
for name,path in sources.items():run([sys.executable,str(r/'scripts/build-madeira-pe-container-probe.py'),'--container-only','--source',str(path),'--output',str(r/'generated/madeira-containers'/name)],f'{name}-container.log')
(out/'manifest.json').write_text(json.dumps({name:{'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for name,path in sources.items()},indent=2)+'\n')
print(out)
