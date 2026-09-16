#!/usr/bin/env python3
"""Build a source-owned Windows x64 text-services COM diagnostic."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
out = root / 'generated/windows-text-services-probe'
out.mkdir(parents=True, exist_ok=True)
source = root / 'port/windows/WindowsTextServicesProbe.c'
exe = out / 'agepad-text-services-x64.exe'
compiler = root / 'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
command = [str(compiler), '-O2', '-nostdlib', '-fno-builtin', '-fno-stack-protector',
           '-Wl,--entry,mainCRTStartup', '-Wl,--subsystem,console', str(source),
           '-lole32', '-luuid', '-lkernel32', '-o', str(exe)]
subprocess.run(command, check=True)
(out / 'manifest.json').write_text(json.dumps({
    'command': command,
    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'exe_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'scope': 'Real text-services InputProcessorProfiles COM creation and current-language method; no Steam or game acceptance'
}, indent=2) + '\n')
print(exe)
