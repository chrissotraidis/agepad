#!/usr/bin/env python3
"""Prepare independently named signed DLL copies for child-process integration.
This does not install or prove process isolation. Loader/allocator work is separate.
"""
from pathlib import Path
import argparse,json,hashlib,subprocess,sys
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--slot',type=int,required=True);args=p.parse_args()
if not 1<=args.slot<=16:p.error('Experimental bank slots are 1..16')
r=Path(__file__).resolve().parents[1];out=r/'generated/madeira-child-banks'/f'child-{args.slot}';out.mkdir(parents=True,exist_ok=True)
names=['ntdll','xtajit64','ucrtbase','kernel32','kernelbase','d3d11','dxgi','winemetal','gdi32','user32','advapi32','win32u','sechost','msvcrt','wininet']
result={}
for name in names:
 manifest=r/'generated/madeira-pe-container-ntdll/manifest.json' if name=='ntdll' else r/'generated/madeira-containers'/name/'manifest.json'
 original=json.loads(manifest.read_text());source=Path(original['source']);digest=hashlib.sha256(source.read_bytes()).hexdigest()
 if digest!=original['source_sha256']:raise SystemExit(f'Stale root source for {name}')
 target=out/f'{name}-child-{args.slot}'
 with (out/(name+'-build.log')).open('w') as log:
  subprocess.run([sys.executable,str(r/'scripts/build-madeira-pe-container-probe.py'),'--container-only','--source',str(source),'--output',str(target)],stdout=log,stderr=subprocess.STDOUT,check=True)
 child=json.loads((target/'manifest.json').read_text());assert child['source_sha256']==digest
 dylib=target/'AgePadPEProbe.app/Frameworks/PEContainer.dylib'
 load=subprocess.check_output(['otool','-D',str(dylib)],text=True)
 expected=f'@rpath/{name}-child-{args.slot}.dll.dylib';assert expected in load
 subprocess.run(['codesign','--verify','--strict',str(dylib)],check=True)
 result[name]={'source':str(source),'source_sha256':digest,'dylib':str(dylib),'dylib_sha256':hashlib.sha256(dylib.read_bytes()).hexdigest(),'install_name':expected}
 print(name,'prepared',flush=True)
(out/'bank.json').write_text(json.dumps({'slot':args.slot,'scope':'Signed artifacts only, not installed or isolation-tested','modules':result},indent=2)+'\n')
print(out/'bank.json')
