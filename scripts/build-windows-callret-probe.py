#!/usr/bin/env python3
"""Build a deep-call Windows x64 correctness test with a 32MiB guest stack."""
from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1]
source=root/'port/windows/WindowsCallRetProbe.c'
exe=root/'generated/agepad-callret-x64.exe'
compiler=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(compiler),'-O2','-fno-optimize-sibling-calls','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console','-Wl,--stack,33554432',str(source),'-lkernel32','-o',str(exe)]
subprocess.run(cmd,check=True)
exe.with_suffix('.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'depths':[1024,98304,98304]},indent=2)+'\n')
print(exe)
