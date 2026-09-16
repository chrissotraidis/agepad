#!/usr/bin/env python3
"""Compile the native iPad runtime without leaving device libraries in the Simulator app."""
import argparse,hashlib,json,os,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=a.output.resolve()
if out.exists():p.error('Output exists; preserve prior evidence and choose a new path')
m=root/'worktrees/madeira'
headers=m/'toolchains/gnutls-iphoneos/include/gnutls'
if not (headers/'gnutls.h').is_file() or not (headers/'pkcs12.h').is_file():
 p.error('Build GnuTLS for iphoneos first; device headers are missing')
out.mkdir(parents=True)
shared=[m/'app/Madeira/libntdll_unix.a',m/'build/crypto-unix/gnutls_symtab_ios.c']
saved={x:x.read_bytes() if x.exists() else None for x in shared}
report={'scope':'Native iphoneos compile only; no signing, app link, installation, JIT execution or gameplay proof'}
try:
 with (out/'build.log').open('w') as log:
  result=subprocess.run(['bash',str(m/'build/ntdll-unix/build.sh')],cwd=root,
      env={**os.environ,'AGEPAD_SDK':'iphoneos'},stdout=log,stderr=log)
 report['build_exit']=result.returncode
 if result.returncode==0:
  lib=out/'libntdll_unix.a';shutil.copy2(shared[0],lib)
  report['sha256']=hashlib.sha256(lib.read_bytes()).hexdigest()
  obj=m/'build/ntdll-unix/obj-iphoneos/virtual.o'
  platform=subprocess.check_output(['xcrun','vtool','-show-build',str(obj)],text=True)
  (out/'platform.txt').write_text(platform)
  report['device_platform_verified']=bool(re.search(r'^\s*platform\s+IOS\s*$',platform,re.M)) and 'IOSSIMULATOR' not in platform
finally:
 for path,data in saved.items():
  if data is None:path.unlink(missing_ok=True)
  else:path.write_bytes(data)
 report['shared_files_restored']=all((path.read_bytes()==data if data is not None else not path.exists()) for path,data in saved.items())
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
raise SystemExit(0 if report.get('build_exit')==0 and report.get('device_platform_verified') and report['shared_files_restored'] else 1)
