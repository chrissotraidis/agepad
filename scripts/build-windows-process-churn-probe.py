#!/usr/bin/env python3
"""Build a source-owned process-exit comparison and FEX-band census probe."""
from pathlib import Path
import subprocess,json,hashlib,argparse
p=argparse.ArgumentParser();p.add_argument("--workers",type=int,choices=range(1,33),default=4);args=p.parse_args()
root=Path(__file__).resolve().parents[1]
src=root/'port/windows/WindowsProcessChurnProbe.c';exe=root/(f'generated/agepad-process-churn-{args.workers}-x64.exe' if args.workers!=4 else 'generated/agepad-process-churn-x64.exe')
cc=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(cc),f'-DAGEPAD_WORKER_COUNT={args.workers}','-O2','-Wall','-Wextra','-Werror','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32','-o',str(exe)]
subprocess.run(cmd,check=True)
exe.with_suffix('.json').write_text(json.dumps({'worker_count':args.workers,'command':cmd,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'requires':'normal FEX with callret failure injection disabled','acceptance':'joined-worker child81 then live-worker child82; parent0; census measurements do not prove reclamation'},indent=2)+'\n')
print(exe)
