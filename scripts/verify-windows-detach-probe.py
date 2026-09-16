#!/usr/bin/env python3
"""Verify captured source-owned detach probe markers, not retail shutdown correctness."""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser();p.add_argument('label');p.add_argument('--joined-retirement',action='store_true');p.add_argument('--late-load',action='store_true');p.add_argument('--early-retirement',action='store_true');p.add_argument('--callback-retirement',action='store_true');p.add_argument('--allocator-finalize',action='store_true');p.add_argument('--workers',type=int,choices=range(1,33));args=p.parse_args()
if not args.label.replace('-','').isalnum():p.error('Invalid run label')
root=Path(__file__).resolve().parents[1]
source=root/'generated/madeira-signed-startup'/args.label/'runtime-followup.log'
lines=source.read_text(errors='replace').splitlines()
positions=lambda marker:[i+1 for i,line in enumerate(lines) if marker in line]
attach=positions('AGEPAD_DETACH: ATTACH_CONFIRMED');tls=positions('AGEPAD_DETACH: TLS_DETACH_OK');dll=positions('AGEPAD_DETACH: DLL_DETACH_OK');drain=positions('[cleanup-barrier] DRAINED');exits=positions('AGEPAD_PROCESS_CHURN: PARENT_OBSERVED_EXIT')
assert len(attach)==len(tls)==len(dll)==len(exits)==2
assert len(drain)==3
for i in range(2):assert attach[i]<drain[i]<tls[i]<dll[i]<exits[i]
for marker in ['TLS_DETACH_FAIL','DLL_DETACH_FAIL','SEGV LOOP FATAL','[cleanup-barrier] FAILED','AGEPAD_PROCESS_CHURN: FAIL']:
 assert not positions(marker),marker
assert positions('Wine exited with code 0') and positions('AGEPAD_PROCESS_CHURN: PASS')
report={'run':args.label,'attach_lines':attach,'drain_lines':drain,'tls_detach_lines':tls,'dll_detach_lines':dll,'parent_observed_exit_lines':exits,'status':'pass','scope':'This source-owned fixture executes TLS then DLL detach after worker drain; no general last-callback or main-state-disposal claim'}
if args.workers is not None:
 configs=[int(v) for v in re.findall(r'AGEPAD_PROCESS_CHURN: CONFIG workers=(\d+)', '\n'.join(lines))]
 assert configs==[args.workers]*3,configs
 report['worker_count']=args.workers
if args.joined_retirement:
 assert args.workers is not None and args.early_retirement
 joined=positions('[thread-reclaim] joined-drained')
 assert len(joined)==args.workers-1,joined
 assert not positions('[thread-reclaim] retained')
 for line in joined:
  assert attach[0]<line<drain[0]
  assert 'before-free' in lines[line-1]
 identities=[re.search(r'teb=(0x[0-9a-f]+) tid=([0-9a-f]+)',lines[i-1]).groups() for i in joined]
 assert len(set(identities))==len(identities)
 report['joined_retirement']={'count':len(joined),'scope':'Successful join and closed/drained registry immediately before TEB free; no held-reader, post-free or reuse claim'}
if args.allocator_finalize:
 main_begin=positions('[main-detach] BEGIN')
 main_end=positions('[main-detach] END')
 alloc_begin=positions('[allocator-detach] BEGIN after CRT')
 alloc_end=positions('[allocator-detach] END after CRT')
 assert len(main_begin)==len(main_end)==len(alloc_begin)==len(alloc_end)==3
 for i in range(3):
  assert drain[i]<main_begin[i]<main_end[i]<alloc_begin[i]<alloc_end[i]
  assert re.search(r'status=(?:0x0|0)(?:\s|$)',lines[main_end[i]-1])
  if i<2:assert dll[i]<main_begin[i] and alloc_end[i]<exits[i]
 assert not positions('[main-detach] REFUSED')
 report['allocator_finalize']='three ordered completions after main cleanup and CRT wrapper; fixture only'
if args.callback_retirement:
 retired=positions('[callback-retire] DRAINED')
 assert len(retired)==3 and not positions('[callback-retire] QUARANTINED')
 assert args.allocator_finalize,'Retirement fixture requires allocator-finalize verification'
 for i in range(3):
  assert alloc_end[i]<retired[i]
  if i<2:assert retired[i]<exits[i]
 report['callback_retirement']='three successful retirements after allocator cleanup; fixture only'
if args.early_retirement:
 assert args.callback_retirement and args.allocator_finalize
 early=positions('[callback-retire-early] DRAINED')
 assert len(early)==3
 assert not positions('[callback-retire-early] QUARANTINED')
 assert not positions('[callback-retire-early] ABI-ERROR')
 for i in range(3):
  assert drain[i]<early[i]<main_begin[i]
  if i<2:assert dll[i]<early[i]
 report['early_retirement']='three retirements after guest detach callbacks and before main-state destruction; fixture only'
if args.late_load:
 assert args.early_retirement
 starts=positions('AGEPAD_LATE_LOAD: BEGIN')
 ends=positions('AGEPAD_LATE_LOAD: EXECUTED')
 assert len(starts)==len(ends)==2
 owners=re.findall(r'registered version=5 owner=(0x[0-9a-f]+)', '\n'.join(lines))
 assert len(owners)==3 and len(set(owners))==3
 parent=owners[0]
 deliveries=[]
 for i in range(2):
  assert exits[i]<starts[i]<ends[i]<early[2]
  match=re.search(r'EXECUTED mode=(\d+) module=(\d+)',lines[ends[i]-1]);assert match
  assert int(match[1])==i+1
  pe=int(match[2])
  found=[]
  for j in range(starts[i],ends[i]-1):
   m=re.search(r'\[alias-delivery\] owner=(0x[0-9a-f]+) pe=(0x[0-9a-f]+).*delivered=(\d+)',lines[j])
   if m and int(m[2],16)==pe:
    assert m[1]==parent and m[3]=='1'
    found.append(j+1)
  assert found, 'Late DLL execution did not establish the intended alias-delivery path'
  deliveries.extend(found)
 report['late_load']={'status':'two new DLLs execute after child exits with parent-owned alias delivery','delivery_lines':deliveries}
output=source.parent/'detach-verification.json';output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
