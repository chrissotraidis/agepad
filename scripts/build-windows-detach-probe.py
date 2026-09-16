#!/usr/bin/env python3
"""Build source-owned process probe plus x64 DLL/TLS detach fixture."""
from pathlib import Path
import subprocess,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument("--workers",type=int,choices=range(1,33),default=4);p.add_argument("--late-load",action="store_true");args=p.parse_args()
root=Path(__file__).resolve().parents[1]
out=root/('generated/windows-detach-probe' if args.workers==4 else f'generated/windows-detach-probe-{args.workers}');out=out.with_name(out.name+"-late") if args.late_load else out;out.mkdir(parents=True,exist_ok=True)
cc=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
flags=['-O2','-Wall','-Wextra','-Werror','-nostdlib','-fno-builtin','-fno-stack-protector']
commands=[];hashes={}
for name,source,extra in [('agepad-detach.dll','WindowsDetachProbeDll.c',['-shared','-Wl,--entry,DllMain','-Wl,-u,_tls_used']),('agepad-process-detach-x64.exe','WindowsProcessChurnProbe.c',['-DAGEPAD_DETACH_PROBE=1',f'-DAGEPAD_WORKER_COUNT={args.workers}','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console'])]:
 src=root/'port/windows'/source;target=out/name;cmd=[str(cc),*flags,*extra,str(src),'-lkernel32','-o',str(target)]
 if args.late_load and name.endswith('.exe'):cmd.insert(1,'-DAGEPAD_LATE_ALIAS_PROBE=1')
 subprocess.run(cmd,check=True);commands.append(cmd);hashes[name]={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
if args.late_load:
 src=root/'port/windows/WindowsLateLoadProbeDll.c'
 for name in ['agepad-late-one.dll','agepad-late-two.dll']:
  target=out/name;cmd=[str(cc),*flags,'-shared','-Wl,--entry,DllMain',str(src),'-lkernel32','-o',str(target)]
  subprocess.run(cmd,check=True);commands.append(cmd);hashes[name]={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
(out/'manifest.json').write_text(json.dumps({'late_load':args.late_load,'worker_count':args.workers,'commands':commands,'files':hashes,'acceptance':'two attach checks, two TLS and two DLL detach OK markers after respective worker drain; children81/82 and parent0, no fatal markers'},indent=2)+'\n')
print(out)
