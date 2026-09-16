#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,hashlib
r=Path(__file__).resolve().parents[1];out=r/'generated/windows-service-probe';out.mkdir(parents=True,exist_ok=True)
src=r/'port/windows/WindowsServiceBootstrapProbe.c';exe=out/'agepad-service-bootstrap-x64.exe'
cc=r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(cc),'-O2','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32','-ladvapi32','-o',str(exe)]
subprocess.run(cmd,check=True)
(out/'manifest.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'scope':'SCM connectivity/RpcSs running status only; no COM activation or Steam acceptance'},indent=2)+'\n');print(exe)
