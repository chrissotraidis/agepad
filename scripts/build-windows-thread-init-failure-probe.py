#!/usr/bin/env python3
"""Build the guest probe for AGEPAD_TEST_CALLRET_FAIL_AT=2, not a retail binary."""
from pathlib import Path
import subprocess,json,hashlib
root=Path(__file__).resolve().parents[1]
src=root/'port/windows/WindowsThreadInitFailureProbe.c';exe=root/'generated/agepad-thread-init-failure-x64.exe'
cc=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(cc),'-O2','-Wall','-Wextra','-Werror','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32','-o',str(exe)]
subprocess.run(cmd,check=True)
exe.with_suffix('.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'requires':'diagnostic FEX AGEPAD_TEST_CALLRET_FAIL_AT=2','acceptance':'first thread STATUS_NO_MEMORY without worker entry; next thread73; parent0'},indent=2)+'\n')
print(exe)
