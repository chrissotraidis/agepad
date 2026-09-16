#!/usr/bin/env python3
"""Snapshot one recorded Simulator run without launching or replacing a process."""
from pathlib import Path
import argparse,json,subprocess,shutil,datetime,re
p=argparse.ArgumentParser(description=__doc__);p.add_argument('label');p.add_argument('--helper-logs',action='store_true',help='Snapshot the three known logs of this test-installed Steam client');args=p.parse_args()
if not args.label.replace('-','').isalnum():p.error('Invalid run label')
r=Path(__file__).resolve().parents[1];out=r/'generated/madeira-signed-startup'/args.label;run=json.loads((out/'run.json').read_text())
pid=run['launch'].rsplit(':',1)[1].strip();state=subprocess.run(['ps','-p',pid,'-o','pid=,stat=,etime=,command='],capture_output=True,text=True)
container=Path(run['container']);log=container/'Documents/madeira-log.txt';text=''
if log.exists():shutil.copy2(log,out/'runtime-followup.log');text=log.read_text(errors='replace')
# Only the known test-installed client's bootstrap log; never traverse account files.
bootstrap=container/'Documents/wine/drive_c/AgePadGuests'/args.label/'logs/bootstrap_log.txt'
if bootstrap.exists():shutil.copy2(bootstrap,out/'steam-bootstrap.log')
helper_logs={}
if args.helper_logs:
 for name in ['webhelper.txt','steamui_html.txt','cef_log.txt']:
  source=bootstrap.parent/name
  if source.is_file():
   shutil.copy2(source,out/name)
   helper_logs[name]={'bytes':source.stat().st_size,'tail':source.read_text(errors='replace').splitlines()[-4:]}
summary={'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':pid,'process_exists':state.returncode==0,'process_snapshot':state.stdout.strip(),'runtime_bytes':log.stat().st_size if log.exists() else None,'unpublished_compile_markers':text.count('UNPUB-COMPILE'),'guest_clean_exit': 'Wine exited with code 0' in text,'bootstrap_tail':bootstrap.read_text(errors='replace').splitlines()[-8:] if bootstrap.exists() else [],'scope':'Observation only. A live shell or exit marker alone is not Steam/game acceptance.'}
# The UIKit host can remain alive after the initial guest returns. Match the
# host bridge's explicit result, not an arbitrary child exit_process message.
initial_exits = re.findall(r'\[WineProc\] Wine exited with code (-?\d+) \(caught by longjmp\)', text)
summary['initial_guest'] = {
 'terminal_observed': bool(initial_exits),
 'exit_codes': sorted({int(code) for code in initial_exits}),
 'scope': 'Initial guest bridge exit only; a live host is not a live guest, and absent markers do not prove guest progress.'
}
summary['host_failure'] = {
 'redelivery_termination_recorded': '[redeliv] terminating process rev=ml465' in text,
 'process_missing': state.returncode != 0,
 'scope': 'Host fatal guard and current process inventory; independent of initial guest exit markers. Missing process alone does not identify cause.'
}
summary['helper_logs']=helper_logs
# Counters are sparsely logged: maximum observed counter is a lower bound,
# not the number of log lines and not an exact final total or execution rate.
x18_records=re.findall(r'\[x18-emul3\] #(\d+) pc=(0x[0-9a-f]+) insn=([0-9a-f]+) teb\+(0x[0-9a-f]+)',text)
summary['thread_state_faults']={
 'logged_counter_lower_bound':max((int(row[0]) for row in x18_records),default=None),
 'logged_records':len(x18_records),
 'recent_samples':[{'counter':int(count),'pc':pc,'instruction':insn,'teb_offset':offset} for count,pc,insn,offset in x18_records[-4:]],
 'scope':'Sparse x18-emulation counters only; missing records can undercount. Not all exceptions, an exact final total, or FPS.'}
summary['direct_assembly_teb_offsets']=sorted(set(re.findall(r'\[AgePad-asm-teb\] offset=(0x[0-9a-f]+)',text)))
# These are logged address reservations, not physical memory or FPS estimates.
pool_matches=re.findall(r'\[AgePad-JIT\] MAP_JIT pool=(0x[0-9a-f]+) size=(\d+)',text)
if pool_matches:
 base,capacity=pool_matches[-1];base=int(base,16);capacity=int(capacity)
 chunks={(int(address,16),int(size)) for address,size in re.findall(r'\[AgePad-JIT\] allocate base=(0x[0-9a-f]+) size=(\d+)',text)}
 valid=sorted((address,size) for address,size in chunks if base<=address and address+size<=base+capacity)
 high=max((address+size-base for address,size in valid),default=0)
 quarantined=set()
 reuse_events=[]
 for event in re.finditer(r'\[AgePad-JIT\] (?:quarantined allocation=(0x[0-9a-f]+)|reuse base=(0x[0-9a-f]+) size=(\d+))',text):
  released,reused,reused_size=event.groups()
  if released: quarantined.add(int(released,16))
  else:
   quarantined.discard(int(reused,16))
   reuse_events.append((int(reused,16),int(reused_size)))
 known_addresses={address for address,size in valid}
 summary['jit_pool']={'capacity_bytes':capacity,'logged_unique_chunks':len(valid),
  'allocated_extent_bytes':high,'remaining_extent_bytes':capacity-high,
  'out_of_range_records':len(chunks)-len(valid),
  'logged_reuse_events':len(reuse_events),
  'logged_reused_bytes_cumulative':sum(size for address,size in reuse_events),
  'logged_quarantined_chunks':sum(address in quarantined for address,size in valid),
  'logged_quarantined_bytes':sum(size for address,size in valid if address in quarantined),
  'logged_not_quarantined_bytes':sum(size for address,size in valid if address not in quarantined),
  'unmatched_quarantine_records':len(quarantined-known_addresses),
  'quarantine_scope':'Release/reuse markers applied in log order; not proof of safe reuse, liveness, or resident memory. Missing logs can undercount.',
  'exhaustion_reported':'EXEC ALLOC FAILED' in text,
  'scope':'Logged monotonic pool extent; not resident memory. Missing logs can undercount.'}
summary['private_banks_seen']=sorted({int(slot) for slot in re.findall(r'\[AgePad-child-bank\] peb=0x[0-9a-f]+ slot=(\d+)',text)})
summary['startup_failures']={
 'private_child_initialization_refusals':text.count('[AgePad-child] private signed ntdll initialization failed; refusing shared fallback'),
 'steam_main_loop_stall_reported':'CSteamEngine::BMainLoop appears to have stalled' in text,
 'scope':'Observed diagnostic messages; a child initialization refusal alone does not identify its cause or establish root process termination.'}
summary['stuck_fault_contexts']=re.findall(r'^.*\[AgePad-stuck-context\].*$',text,re.M)[-4:]
(out/'observation.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
