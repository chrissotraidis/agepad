#!/usr/bin/env python3
"""Build the source-owned Windows x64 CPU/Win32 integration diagnostic."""
from pathlib import Path
import subprocess, hashlib, json
r = Path(__file__).resolve().parents[1]
out = r/'generated/windows-cpu-integration'
out.mkdir(parents=True, exist_ok=True)
x = 0x123456789abcdef0
for i in range(1000000):
    x = ((x*6364136223846793005+1442695040888963407) if i&1 else (x^(x>>13))+i) & ((1<<64)-1)
source = r/'port/windows/WindowsCPUIntegrationProbe.c'
exe = out/'agepad-cpu-integration-x64.exe'
compiler = r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd = [str(compiler), '-O2', '-nostdlib', '-fno-stack-protector', '-Wl,--entry,mainCRTStartup', '-Wl,--subsystem,console', f'-DEXPECTED_CHECKSUM=0x{x:016x}ULL', str(source), '-lkernel32', '-o', str(exe)]
subprocess.run(cmd, check=True)
manifest = {'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(), 'expected_checksum':f'{x:016x}', 'iterations':1000000, 'command':cmd}
(out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps(manifest, indent=2))
