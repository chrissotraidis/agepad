#!/usr/bin/env python3
"""Run only the diagnostic app on the already-booted designated Simulator."""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess

import de_device

DEVICE=de_device.device_udid()
BUNDLE='local.agepad.de-loader-probe'
p=argparse.ArgumentParser()
p.add_argument('app',type=Path)
p.add_argument('artifacts',type=Path)
p.add_argument('--mode',choices=['load','entry','callback','original','main'],default='load')
p.add_argument('--debug-wait',action='store_true')
a=p.parse_args()
app=a.app.resolve()
art=a.artifacts.resolve()
if 'ref' in art.parts:
    raise SystemExit('Evidence must not be written in references')
if (app/'BoundaryBuildIncomplete').exists():
    raise SystemExit('Refusing an incomplete boundary build')
info=plistlib.loads((app/'Info.plist').read_bytes())
if info.get('CFBundleIdentifier')!=BUNDLE:
    raise SystemExit('This runner may only replace the DE diagnostic probe')
if a.mode=='main':
    config=json.loads((app/'BoundaryDiagnostic.json').read_text())
    if not config.get('engine_is_main_executable') or info['CFBundleExecutable']!='DEOriginalGame':
        raise SystemExit('Main mode requires the original-executable candidate')
inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','--json'],text=True))
booted=[d for devices in inventory['devices'].values() for d in devices if d['state']=='Booted']
if len(booted)!=1 or booted[0]['udid']!=DEVICE:
    raise SystemExit('Expected only the designated Simulator booted; no devices changed')
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
art.mkdir(parents=True,exist_ok=True)
(art/'booted-devices.json').write_text(json.dumps(inventory,indent=2)+'\n')
subprocess.run(['xcrun','simctl','install',DEVICE,str(app)],check=True)
flags={'load':[],'entry':['--invoke-engine-entry'],'callback':['--invoke-original-launch'],'original':['--run-original'],'main':[]}
command=['xcrun','simctl','launch','--terminate-running-process','--stdout='+str(art/'stdout.log'),
         '--stderr='+str(art/'stderr.log')]+(['--wait-for-debugger'] if a.debug_wait else [])+[DEVICE,BUNDLE]+flags[a.mode]
r=subprocess.run(command,check=True,capture_output=True,text=True)
(art/'launch.json').write_text(json.dumps({'candidate':str(app),'mode':a.mode,'command':command,
    'stdout':r.stdout,'stderr':r.stderr,'returncode':r.returncode},indent=2)+'\n')
print(r.stdout.strip())
print('Launch accepted; inspect runtime logs before claiming execution success.')
