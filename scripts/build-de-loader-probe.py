#!/usr/bin/env python3
"""Package original executable/shader loading probe; does not change inputs."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess


def run(*args):
    subprocess.run([str(x) for x in args], check=True)


a = argparse.ArgumentParser()
a.add_argument("input", type=Path)
a.add_argument("output", type=Path)
a.add_argument("--audit-json",type=Path)
a.add_argument("--adapt-engine",action="store_true")
a.add_argument("--manifest",type=Path)
a.add_argument("--shader",type=Path)
args = a.parse_args()
root = Path(__file__).resolve().parent.parent
app = args.output.resolve()
source = args.input.resolve()
if source == app or source in app.parents:
    raise SystemExit("Output must not be inside input")
app.mkdir(parents=True,exist_ok=True)
sdk = subprocess.check_output(["xcrun","--sdk","iphonesimulator","--show-sdk-path"],text=True).strip()
run("xcrun","clang","-target","arm64-apple-ios15.0-simulator","-isysroot",sdk,
    "-fobjc-arc",root/"port/de/LoaderProbe.m","-framework","UIKit","-framework","Foundation",
    "-framework","Metal","-framework","CoreGraphics","-o",app/"DELoaderProbe")
run("cp","-c",source/"Contents/MacOS/Age Of Empires II",app/"OriginalEngine")
run("cp","-c",source/"Contents/Resources/feral.metallib",app/"feral.metallib")
if args.shader:
    run('cp','-c',args.shader.resolve(),app/'feral-retargeted.metallib')
if args.audit_json:
    audit=json.loads(args.audit_json.read_text())
    merged={}
    for binary in audit['binaries']:
        for line in binary['dependencies']['stdout'].splitlines()[1:]:
            path=line.strip().split(' (compatibility')[0]
            if not path.startswith(('/System/','/usr/')):
                continue
            match=re.search(r'/([^/]+)\.framework/',path)
            name=match.group(1) if match else Path(path).name.split('.dylib')[0].split('.')[0]
            path=re.sub(r'(\.framework)/Versions/[^/]+/',r'\1/',path)
            merged.setdefault(path,set()).update(binary['undefined_symbols'].get(name,[]))
    (app/'Imports.json').write_text(json.dumps([{'path':k,'symbols':sorted(v)} for k,v in merged.items()]))
if args.adapt_engine:
    if not args.manifest:
        raise SystemExit('--manifest is required for an adapted engine')
    run('python3',root/'scripts/prepare-de-load-image.py',source/'Contents/MacOS/Age Of Empires II',
        app/'Engine.dylib',args.manifest,'--audio-umbrella')
    run('xcrun','clang','-target','arm64-apple-ios15.0-simulator','-isysroot',sdk,'-dynamiclib',
        '-x','c','/dev/null','-Wl,-reexport_framework,AudioToolbox',
        '-Wl,-install_name,@loader_path/AudioUnitCompat.dylib','-o',app/'AudioUnitCompat.dylib')
    run('codesign','--force','--sign','-',app/'AudioUnitCompat.dylib')
info = {"CFBundleIdentifier":"local.agepad.de-loader-probe","CFBundleExecutable":"DELoaderProbe",
    "CFBundleName":"DE Loader Probe","CFBundlePackageType":"APPL","CFBundleVersion":"1",
    "CFBundleShortVersionString":"0.1","MinimumOSVersion":"15.0","UIDeviceFamily":[2],
    "CFBundleSupportedPlatforms":["iPhoneSimulator"],"UIRequiresFullScreen":True,
    "UIApplicationSupportsIndirectInputEvents":True,"UILaunchScreen":{},
    "UISupportedInterfaceOrientations":["UIInterfaceOrientationLandscapeLeft","UIInterfaceOrientationLandscapeRight"]}
(app/"Info.plist").write_bytes(plistlib.dumps(info))
run("codesign","--force","--sign","-",app)
print(app)
