#!/usr/bin/env python3
"""Build an isolated real-Steam-SDK probe, retaining real ownership checks."""
import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess

p=argparse.ArgumentParser()
p.add_argument('input',type=Path)
p.add_argument('output',type=Path)
p.add_argument('artifacts',type=Path)
a=p.parse_args()
root=Path(__file__).resolve().parent.parent
source,app,art=a.input.resolve(),a.output.resolve(),a.artifacts.resolve()
if 'ref' in app.parts or 'ref' in art.parts or source==app or source in app.parents:
    raise SystemExit('Never write into references')
app.mkdir(parents=True,exist_ok=True);art.mkdir(parents=True,exist_ok=True)
marker=app/'BoundaryBuildIncomplete';marker.write_text('Steam probe build incomplete\n')
original=plistlib.loads((source/'Contents/Info.plist').read_bytes())
appid=str(original['FeralAppID'])
if not appid.isdigit() or int(appid)==0: raise SystemExit('Expected the genuine numeric game App ID')
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
subprocess.run(['xcrun','clang','-fobjc-arc','-target','arm64-apple-ios15.0-simulator','-isysroot',sdk,
    str(root/'port/de/SteamProbe.m'),'-framework','UIKit','-framework','Foundation','-o',str(app/'DESteamProbe')],check=True)
thin=art/'libsteam_api.arm64'
subprocess.run(['xcrun','lipo',str(source/'Contents/Frameworks/libsteam_api.dylib'),'-thin','arm64','-output',str(thin)],check=True)
spec=importlib.util.spec_from_file_location('adapter',root/'scripts/prepare-de-load-image.py')
adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
manifest=adapter.prepare(thin,app/'Frameworks/libsteam_api.dylib')
info={'CFBundleIdentifier':'local.agepad.de-loader-probe','CFBundleExecutable':'DESteamProbe','CFBundleName':'DE Steam Probe',
    'CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'0.1','MinimumOSVersion':'15.0',
    'UIDeviceFamily':[2],'CFBundleSupportedPlatforms':['iPhoneSimulator'],'UILaunchScreen':{},'DEAppID':appid,
    'UISupportedInterfaceOrientations':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
(app/'steam_appid.txt').write_text(appid+'\n') # Official development hint; never substitutes for a licensed client.
manifest['app_id_hint']=appid
(art/'steam-library-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
marker.unlink()
try: subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
except Exception:
    marker.write_text('Steam probe signing failed\n');raise
print(app)
