#!/usr/bin/env python3
"""Combine completed device DXMT/LLVM archives for the isolated app link."""
import argparse,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--llvm-targets',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();r=Path(__file__).resolve().parents[1];out=a.output.resolve()
if out.exists():p.error('Output exists; preserve previous artifact')
names=json.loads(a.llvm_targets.read_text());assert names and len(names)==len(set(names))
if not all(isinstance(n,str) and n.startswith('LLVM') and n.isalnum() for n in names):p.error('Invalid LLVM target list')
inputs=[r/'worktrees/madeira/build/dxmt-ios/libdxmt_unix-iphoneos.a']+[r/'generated/madeira-llvm-device/lib'/('lib'+name+'.a') for name in names]
missing=[str(x) for x in inputs if not x.is_file()]
if missing:p.error('Missing completed archives: '+', '.join(missing))
out.parent.mkdir(parents=True,exist_ok=True)
with out.with_suffix('.build.log').open('w') as log:
 subprocess.run(['xcrun','libtool','-static','-o',str(out),*[str(x) for x in inputs]],stdout=log,stderr=log,check=True)
manifest={'output':str(out),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'inputs':{str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in inputs},'scope':'Static archive assembly; app link and device Metal acceptance untested'}
out.with_suffix('.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out)
