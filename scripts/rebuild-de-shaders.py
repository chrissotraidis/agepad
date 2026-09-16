#!/usr/bin/env python3
"""Rebuild supplied Metal IR for a named iOS target into private output.

Uses Apple's tools. The original is read-only; extracted IR is proprietary input
material and must remain in ignored generated/artifact directories.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


p=argparse.ArgumentParser()
p.add_argument('source',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--sdk',choices=['iphonesimulator','iphoneos'],default='iphonesimulator')
a=p.parse_args()
source,output=a.source.resolve(),a.output.resolve()
if 'ref' in output.parts or not any(x in output.parts for x in ('generated','private','artifacts')):
    raise SystemExit('Binary-derived shader IR must use private ignored output')
output.mkdir(parents=True,exist_ok=True)
dump=subprocess.run(['xcrun','metal-objdump','--disassemble','--metallib',str(source)],capture_output=True,text=True,check=True).stdout
(output/'original.ll').write_text(dump)
parts=re.split(r'^0x[0-9a-f]+ -- [^\n]+:\n',dump,flags=re.M)[1:]
if not parts:
    raise SystemExit('No Metal IR modules extracted')
target='air64-apple-ios16.0.0'+('-simulator' if a.sdk=='iphonesimulator' else '')
records=[]
air=[]
for i,part in enumerate(parts):
    name=re.search(r'^source_filename = "([^"]+)"',part,re.M).group(1)
    # Output names are generated indexes, not paths taken from the binary.
    ll=output/('module-%02d.ll'%i)
    compiled=ll.with_suffix('.air')
    ll.write_text(part)
    cmd=['xcrun','--sdk',a.sdk,'metal','-c','-x','ir','-target',target,str(ll),'-o',str(compiled)]
    result=subprocess.run(cmd,capture_output=True,text=True)
    records.append({'function':name,'command':cmd,'returncode':result.returncode,'stderr':result.stderr})
    (output/'compile-log.json').write_text(json.dumps(records,indent=2)+'\n')
    if result.returncode:
        raise SystemExit(result.stderr)
    air.append(str(compiled))
destination=output/'feral.metallib'
subprocess.run(['xcrun','--sdk',a.sdk,'metallib',*air,'-o',str(destination)],check=True)
manifest={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'output':str(destination),'output_sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),
    'sdk':a.sdk,'target':target,'module_count':len(parts),'transformation':'Recompile unedited extracted IR for target using Apple metal/metallib',
    'validation':'Compilation only; runtime equivalence and full-game graphics unproven'}
(output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
