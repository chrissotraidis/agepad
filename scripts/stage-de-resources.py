#!/usr/bin/env python3
"""Stage supplied game configuration/resources at the iOS NSBundle resource root.

Keep probe identity/signing fields. Copy genuine Feral configuration keys, never
alter distribution/authentication values. This does not stage the large game-data
directory or certify licensing, rendering, or multiplayer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess

p=argparse.ArgumentParser()
p.add_argument('source',type=Path)
p.add_argument('app',type=Path)
p.add_argument('manifest',type=Path)
p.add_argument('--shader',type=Path,required=True)
a=p.parse_args()
source,app=a.source.resolve(),a.app.resolve()
if 'ref' in app.parts or source==app or source in app.parents:
    raise SystemExit('Never modify references')
info=plistlib.loads((app/'Info.plist').read_bytes())
if info.get('CFBundleIdentifier')!='local.agepad.de-loader-probe':
    raise SystemExit('Resources may only be staged into the diagnostic probe')
original_info=plistlib.loads((source/'Contents/Info.plist').read_bytes())
marker=app/'BoundaryBuildIncomplete'
marker.write_text('Resource staging incomplete; do not execute.\n')
resources=source/'Contents/Resources'
subprocess.run(['cp','-cR',str(resources)+'/.',str(app)],check=True)
keys=[k for k in original_info if k.startswith('Feral') or k in ('DevGameName','CFBundleShortVersionString')]
for key in keys: info[key]=original_info[key]
info['DEOriginalBundleVersion']=original_info['CFBundleVersion']
(app/'Info.plist').write_bytes(plistlib.dumps(info))
checks=[]
for path in resources.rglob('*'):
    if not path.is_file() or path.is_symlink(): continue
    relative=path.relative_to(resources)
    before,after=path.read_bytes(),(app/relative).read_bytes()
    if before!=after: raise SystemExit('Resource copy mismatch: '+str(relative))
    checks.append({'path':str(relative),'bytes':len(before),'sha256':hashlib.sha256(before).hexdigest()})
subprocess.run(['cp','-c',str(a.shader.resolve()),str(app/'feral.metallib')],check=True)
result={'resources':checks,'genuine_configuration_keys':keys,
    'bundle_identity_preserved':info['CFBundleIdentifier'],'original_bundle_version':original_info['CFBundleVersion'],
    'shader_override':{'path':'feral.metallib','source':str(a.shader),'sha256':hashlib.sha256((app/'feral.metallib').read_bytes()).hexdigest()},
    'game_data_staged':False}
a.manifest.parent.mkdir(parents=True,exist_ok=True)
a.manifest.write_text(json.dumps(result,indent=2)+'\n')
marker.unlink()
try:
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
except Exception:
    marker.write_text('Resource candidate signing failed; do not execute.\n')
    raise
print('Verified',len(checks),'copied resources; original helper shader replaced with verified Simulator rebuild.')
