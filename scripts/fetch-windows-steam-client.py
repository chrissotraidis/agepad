#!/usr/bin/env python3
"""Fetch public Valve Windows client packages to an isolated, versioned directory.
Does not log in, read account data, install services, or change the host Steam app.
"""
from pathlib import Path, PurePosixPath
import re,hashlib,json,subprocess,zipfile
r=Path(__file__).resolve().parents[1];root=r/'generated/windows-steam-intake';root.mkdir(parents=True,exist_ok=True)
base='https://client-update.fastly.steamstatic.com/'
manifest=root/'steam_client_win64'
if not manifest.exists():subprocess.run(['curl','-fsSL','--max-time','45',base+manifest.name,'-o',str(manifest)],check=True)
s=manifest.read_text();version=re.search(r'"version"\s*"(\d+)"',s).group(1)
out=root/version;out.mkdir(exist_ok=True);client=out/'client';client.mkdir(exist_ok=True)
packages=[]
for name,block in re.findall(r'"([^"\n]+)"\s*\{([^{}]*)\}',s):
 d=dict(re.findall(r'"([^"]+)"\s*"([^"]*)"',block))
 if 'file' not in d or name=='steamchina':continue
 filename=d['file'];assert '/' not in filename and '\\' not in filename
 archive=out/filename
 if not archive.exists():
  partial=out/(filename+'.partial')
  subprocess.run(['curl','-fsSL','--retry','2','--max-time','180',base+filename,'-o',str(partial)],check=True)
  partial.rename(archive)
 digest=hashlib.sha256(archive.read_bytes()).hexdigest()
 assert digest==d['sha2'] and archive.stat().st_size==int(d['size']),(name,'package mismatch')
 with zipfile.ZipFile(archive) as z:
  for info in z.infolist():
   path=PurePosixPath(info.filename.replace('\\','/'))
   assert not path.is_absolute() and '..' not in path.parts and ':' not in info.filename,info.filename
   assert (info.external_attr>>16)&0o170000!=0o120000,'symlink'
  z.extractall(client)
 packages.append({'name':name,'url':base+filename,'sha256':digest,'size':archive.stat().st_size})
 print(name,'verified and extracted',flush=True)
(out/'intake.json').write_text(json.dumps({'version':version,'manifest_url':base+manifest.name,'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest(),'packages':packages,'scope':'Public client intake only; no login or execution; package SHA-256 verified against HTTPS manifest, not a separate signature verification'},indent=2)+'\n')
print(client)
