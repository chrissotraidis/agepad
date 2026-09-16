#!/usr/bin/env python3
"""Account explicit active-service allocation/release markers; never infer native quiescence."""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser();p.add_argument('label');args=p.parse_args()
if not re.fullmatch(r'[A-Za-z0-9-]+',args.label):p.error('invalid label')
root=Path(__file__).resolve().parents[1];folder=root/'generated/madeira-signed-startup'/args.label
lines=(folder/'runtime-followup.log').read_text(errors='replace').splitlines()
allocations={};events=[]
for n,line in enumerate(lines,1):
 m=re.search(r'\[AgePad-JIT\] allocate base=(0x[0-9a-f]+) size=(\d+)',line)
 if m:
  base=int(m[1],16);assert base not in allocations,'Duplicate allocation marker or unhandled address reuse'
  allocations[base]={'base':m[1],'size':int(m[2]),'allocation_line':n,'released':False};continue
 m=re.search(r'\[AgePad-JIT\] reuse base=(0x[0-9a-f]+) size=(\d+)',line)
 if m:
  a=allocations[int(m[1],16)];assert a['released'] and a['size']==int(m[2]);a['released']=False
  events.append({'kind':'reuse','base':m[1],'line':n});continue
 m=re.search(r'\[AgePad-JIT\] quarantined allocation=(0x[0-9a-f]+)',line)
 if m:
  a=allocations[int(m[1],16)];assert not a['released'];a['released']=True
  events.append({'kind':'release_marker','base':m[1],'line':n})
assert allocations and any('Wine exited with code 0' in line for line in lines)
report={'run':args.label,'allocations':list(allocations.values()),'events':events,'allocated_extent_bytes':sum(a['size'] for a in allocations.values()),'bytes_with_release_marker_at_end':sum(a['size'] for a in allocations.values() if a['released']),'scope':'Captured active AgePad-JIT log only; release markers do not report release length, native quiescence, physical memory, or cross-owner reuse eligibility'}
(folder/'active-jit-accounting.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['allocations','events']}))
