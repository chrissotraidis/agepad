#!/usr/bin/env python3
from pathlib import Path
import subprocess,hashlib,json
r=Path(__file__).resolve().parents[1];out=r/'generated/windows-unsupported-child-probe';out.mkdir(parents=True,exist_ok=True)
records=[]
for arch,source,name in [('x86_64','WindowsUnsupportedChildProbe.c','agepad-arch-parent-x64.exe'),('i686','WindowsUnsupportedChildTarget.c','agepad-arch-child-x86.exe')]:
 src=r/'port/windows'/source;exe=out/name;cc=r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin'/f'{arch}-w64-mingw32-clang'
 cmd=[str(cc),'-O2','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32','-o',str(exe)]
 subprocess.run(cmd,check=True);records.append({'source':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe':str(exe),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'command':cmd})
(out/'manifest.json').write_text(json.dumps({'builds':records,'scope':'Real i386 child rejected with Windows error193; not32-bit execution support'},indent=2)+'\n')
print(out)
