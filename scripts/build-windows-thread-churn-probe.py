#!/usr/bin/env python3
"""Build a source-owned normal-thread churn and FEX-band census probe."""
from pathlib import Path
import subprocess,json,hashlib
root=Path(__file__).resolve().parents[1]
src=root/'port/windows/WindowsThreadChurnProbe.c';exe=root/'generated/agepad-thread-churn-x64.exe'
cc=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(cc),'-O2','-Wall','-Wextra','-Werror','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32','-o',str(exe)]
subprocess.run(cmd,check=True)
exe.with_suffix('.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'requires':'normal FEX with callret failure injection disabled','acceptance':'64 normal worker exits73; census at baseline and every8 exits; parent0 proves execution only, not reclamation or residency'},indent=2)+'\n')
print(exe)
