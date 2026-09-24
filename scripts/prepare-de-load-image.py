#!/usr/bin/env python3
"""Private Mach-O packaging experiment. Does not change instructions or services.

This only adapts executable metadata and install paths. It does not supply missing
APIs, bypass authentication, or make the image compatible with iPadOS.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess


def align8(n):
    return (n + 7) & ~7


def prepare(source, destination, audio_umbrella=False, platform='ios-simulator', dependency_map=None, preserve_executable=False):
    raw = source.read_bytes()
    image = bytearray(raw)
    magic,cpu,subcpu,filetype,ncmds,sizeofcmds,flags,reserved = struct.unpack_from('<8I', image)
    if magic != 0xfeedfacf or cpu != 0x100000c or filetype not in (2,6):
        raise ValueError('Expected thin arm64 executable or dylib')
    commands, changes, sections = [], [], []
    offset = 32
    first_section = len(image)
    for _ in range(ncmds):
        cmd,size = struct.unpack_from('<II',image,offset)
        if size < 8 or offset+size > 32+sizeofcmds:
            raise ValueError('Malformed load commands')
        data = bytearray(image[offset:offset+size])
        if cmd == 0x19:
            nsects = struct.unpack_from('<I',data,64)[0]
            for i in range(nsects):
                section_offset = struct.unpack_from('<I',data,72+80*i+48)[0]
                if section_offset:
                    first_section = min(first_section,section_offset)
                    section_size=struct.unpack_from('<Q',data,72+80*i+40)[0]
                    section_name=bytes(data[72+80*i:72+80*i+16]).split(b'\0')[0].decode()
                    segment_name=bytes(data[72+80*i+16:72+80*i+32]).split(b'\0')[0].decode()
                    sections.append((segment_name+','+section_name,section_offset,section_size))
        if cmd == 0x80000028 and not preserve_executable:
            changes.append({'remove_load_command':hex(cmd)})
            offset += size
            continue
        if cmd == 0x32 and platform in ('ios-simulator', 'ios-device'):
            target_platform = 7 if platform == 'ios-simulator' else 2
            struct.pack_into('<III',data,8,target_platform,15<<16,(26<<16)|(5<<8))
            changes.append({'platform':'iOS-simulator' if target_platform == 7 else 'iOS-device',
                            'minos':'15.0'})
        if cmd in (0xc,0x80000018,0x8000001f,0x80000023,0xd):
            nameoff = struct.unpack_from('<I',data,8)[0]
            old = data[nameoff:].split(b'\0')[0].decode()
            new = re.sub(r'(\.framework)/Versions/[^/]+/',r'\1/',old) if platform in ('ios-simulator', 'ios-device') else old
            new = (dependency_map or {}).get(old,(dependency_map or {}).get(new,new))
            if audio_umbrella and new == '/System/Library/Frameworks/AudioUnit.framework/AudioUnit':
                new = '@loader_path/AudioUnitCompat.dylib'
            if new != old:
                replacement = new.encode()+b'\0'
                data = data[:nameoff]+replacement
                data += b'\0'*(align8(len(data))-len(data))
                struct.pack_into('<I',data,4,len(data))
                changes.append({'old':old,'new':new})
        commands.append(data)
        offset += size
    if filetype == 2 and not preserve_executable:
        name = b'@rpath/Engine.dylib\0'
        size = align8(24+len(name))
        commands.append(struct.pack('<6I',0xd,size,24,0,0x10000,0x10000)+name+b'\0'*(size-24-len(name)))
    blob = b''.join(commands)
    if 32+len(blob)>first_section:
        raise ValueError('Load commands exceed existing header padding')
    image[32:32+sizeofcmds] = b'\0'*sizeofcmds
    image[32:32+len(blob)] = blob
    target_type=filetype if preserve_executable else 6
    target_flags=flags if preserve_executable else flags & ~0x200000
    struct.pack_into('<8I',image,0,magic,cpu,subcpu,target_type,len(commands),len(blob),target_flags,reserved)
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(image)
    destination.chmod(0o755)
    subprocess.run(['codesign','--force','--sign','-',str(destination)],check=True)
    signed=destination.read_bytes()
    section_checks=[]
    for name,start,length in sections:
        before,after=raw[start:start+length],signed[start:start+length]
        if len(before)!=length or before!=after:
            raise ValueError('Original section changed or invalid: '+name)
        section_checks.append({'name':name,'bytes':length,'sha256':hashlib.sha256(before).hexdigest(),'equal':True})
    return {'source':str(source),'source_sha256':hashlib.sha256(raw).hexdigest(),
        'output':str(destination),'output_sha256':hashlib.sha256(signed).hexdigest(),
        'changes':changes,'instructions_changed':False,'sections':section_checks}


if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('source',type=Path)
    p.add_argument('output',type=Path)
    p.add_argument('manifest',type=Path)
    p.add_argument('--audio-umbrella',action='store_true')
    p.add_argument('--platform',choices=['macos','ios-simulator','ios-device'],default='ios-simulator')
    a=p.parse_args()
    source,output=a.source.resolve(),a.output.resolve()
    if source==output or 'ref' in output.parts:
        raise SystemExit('Never modify source/reference images')
    result=prepare(source,output,a.audio_umbrella,a.platform)
    a.manifest.parent.mkdir(parents=True,exist_ok=True)
    a.manifest.write_text(json.dumps(result,indent=2)+'\n')
    print('Prepared metadata-only %s load image:' % a.platform,output)
