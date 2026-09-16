#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,hashlib,argparse
p=argparse.ArgumentParser();group=p.add_mutually_exclusive_group();group.add_argument('--two',action='store_true');group.add_argument('--crt',action='store_true');group.add_argument('--crt-headless',action='store_true');args=p.parse_args()
r=Path(__file__).resolve().parents[1];out=r/'generated/windows-child-probe';out.mkdir(parents=True,exist_ok=True);src=r/'port/windows/WindowsChildProcessProbe.c';exe=out/'agepad-child-x64.exe';cc=r/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
if args.two:
 out=r/'generated/windows-two-child-probe';out.mkdir(parents=True,exist_ok=True);src=r/'port/windows/WindowsTwoChildProbe.c';exe=out/'agepad-two-child-x64.exe'
if args.crt or args.crt_headless:
 out=r/'generated/windows-crt-child-probe';out.mkdir(parents=True,exist_ok=True);exe=out/'agepad-crt-child-x64.exe'
if args.crt_headless:
 out=r/'generated/windows-crt-headless-child-probe';out.mkdir(parents=True,exist_ok=True);exe=out/'agepad-crt-headless-child-x64.exe'
cmd=[str(cc),'-O2','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(src),'-lkernel32']
if args.crt or args.crt_headless:cmd+=['-DAGEPAD_CHILD_CRT=1','-lucrtbase']
if args.crt_headless:cmd+=['-DAGEPAD_CHILD_HEADLESS=1']
cmd+=['-o',str(exe)];subprocess.run(cmd,check=True)
(out/'manifest.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest()},indent=2)+'\n');print(exe)
