#!/usr/bin/env python3
"""Build the source-owned Windows HTTPS status/body diagnostic."""
from pathlib import Path
import hashlib,json,subprocess,argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--revocation",action="store_true")
parser.add_argument("--autoproxy",action="store_true")
parser.add_argument("--chain",action="store_true")
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
source=root/'port/windows/WindowsHTTPSProbe.c'
suffix=('-revocation' if args.revocation else '')+('-autoproxy' if args.autoproxy else '')+('-chain' if args.chain else '')
exe=root/f'generated/agepad-https{suffix}-x64.exe'
exe.parent.mkdir(parents=True,exist_ok=True)
compiler=root/'worktrees/madeira/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang'
cmd=[str(compiler),'-O2','-nostdlib','-fno-builtin','-fno-stack-protector','-Wl,--entry,mainCRTStartup','-Wl,--subsystem,console',str(source),'-lkernel32','-lwinhttp','-o',str(exe)]
if args.revocation: cmd.insert(1,"-DAGEPAD_CHECK_REVOCATION=1")
if args.autoproxy: cmd.insert(1,"-DAGEPAD_AUTOPROXY=1")
if args.chain:
    cmd.insert(1,"-DAGEPAD_CHAIN=1")
    cmd.insert(-2,"-lcrypt32")
subprocess.run(cmd,check=True)
exe.with_suffix('.json').write_text(json.dumps({'command':cmd,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest()},indent=2)+'\n')
print(exe)
