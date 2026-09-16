#!/usr/bin/env python3
"""Create an isolated Xcode project with explicit device-library references; no signing/install."""
import argparse,json,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--native-lib',type=Path,required=True)
p.add_argument('--win32u-lib',type=Path,required=True)
p.add_argument('--dxmt-lib',type=Path,required=True)
a=p.parse_args();r=Path(__file__).resolve().parents[1];m=r/'worktrees/madeira';out=a.output.resolve()
if out.exists():p.error('Output already exists; choose a new evidence directory')
fex=r/'generated/madeira-fex-device'
paths=['FEXCore/Source/libFEXCore.a','FEXCore/Source/libFEXCore_Base.a','FEXCore/Source/libJemallocLibs.a','External/fmt/libfmt.a','External/cephes/libcephes_128bit.a','External/xxhash/cmake_unofficial/libxxhash.a','External/SoftFloat-3e/libsoftfloat_3e.a']
libs={Path(x).name:fex/x for x in paths}
libs.update({name:m/'toolchains/gnutls-iphoneos/lib'/name for name in ['libgnutls.a','libhogweed.a','libnettle.a','libgmp.a']})
libs.update({'libntdll_unix.a':a.native_lib.resolve(),'libwin32u_unix.a':a.win32u_lib.resolve(),'libdxmt_combined.a':a.dxmt_lib.resolve(),'libwineserver.a':r/'generated/madeira-wineserver-iphoneos/libwineserver.a'})
s=(m/'app/Madeira.xcodeproj/project.pbxproj').read_text();lines=[];seen=set()
for line in s.splitlines():
 if 'isa = PBXFileReference;' in line and 'lastKnownFileType = archive.ar;' in line:
  match=re.search(r'path = ("[^"]+"|[^;]+);',line);assert match
  name=Path(match[1].strip('"')).name;assert name in libs,name
  line=line[:match.start(1)]+json.dumps(str(libs[name]))+line[match.end(1):]
  line=line.replace('sourceTree = "<group>"','sourceTree = "<absolute>"');seen.add(name)
 lines.append(line)
assert seen==set(libs),(seen,set(libs))
s='\n'.join(lines)+'\n'
s=s.replace('$(SRCROOT)/../FEX/build-ios',str(fex)).replace('$(SRCROOT)/../FEX',str(m/'FEX'))
# Xcode emits -l flags even for absolute archive file references. Replace the
# search paths too, otherwise the shared source directory supplies Simulator libs.
device_dirs=list(dict.fromkeys(str(path.parent) for path in libs.values()))
search_paths='LIBRARY_SEARCH_PATHS = (\n'+''.join('\t\t\t\t\t'+json.dumps(path)+',\n' for path in device_dirs)+'\t\t\t\t);'
s,count=re.subn(r'LIBRARY_SEARCH_PATHS = \(.*?\);',lambda _:search_paths,s,flags=re.S)
assert count==2,count
out.mkdir(parents=True);project=out/'Madeira.xcodeproj';project.mkdir()
(project/'project.pbxproj').write_text(s)
(out/'Madeira').symlink_to(m/'app/Madeira',target_is_directory=True)
subprocess.run(['plutil','-lint',str(project/'project.pbxproj')],check=True)
(out/'libraries.json').write_text(json.dumps({name:{'path':str(path),'exists':path.is_file()} for name,path in libs.items()},indent=2)+'\n')
print(project)
