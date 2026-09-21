#!/usr/bin/env python3
"""Private load diagnostic: preserve vendor sections, abort on missing API use.

Requires the audited native client dependency graph and measured public constants.
Never substitutes Steam, ownership, registration or authentication results.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import subprocess as sp

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', type=Path)
p.add_argument('audit', type=Path)
p.add_argument('constants', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--survey', type=Path, help='Actual Simulator LibrarySymbolSurvey result')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
source = a.source.resolve(strict=True)
out = a.output.resolve()
# Path.is_relative_to/removeprefix need Python 3.9; this repository runs on the
# system python3, so use the equivalent 3.8-compatible forms.
if 'ref' in out.parts or source == out or source in out.parents:
    raise SystemExit('Output must be outside source and references')
out.mkdir(parents=True, exist_ok=False)
audit = json.loads(a.audit.read_text())
constants = json.loads(a.constants.read_text())
sdk = sp.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
missing = {}
unmeasured = []

def simulator_classes():
    """Objective-C classes the Simulator SDK already declares.

    Emitting a diagnostic class with a name UIKit/Foundation already defines is
    a duplicate interface, while a class iOS lacks (IOBluetoothDevice) still
    needs the diagnostic. One header scan settles it.
    """
    found = set()
    for root in (Path(sdk) / 'System/Library/Frameworks', Path(sdk) / 'usr/include'):
        if not root.is_dir():
            continue
        out = sp.run(['grep', '-rhoE', '@interface[[:space:]]+[A-Za-z0-9_]+', str(root)],
                     capture_output=True, text=True)
        for line in out.stdout.splitlines():
            found.add(line.split()[-1])
    return found
survey = {Path(x['path']).name:x for x in json.loads(a.survey.read_text())} if a.survey else {}
imports = {}
def flattened(name):
    base=Path(name).name
    return base if base.endswith('.dylib') else base+'.dylib'
names = {name: flattened(name) for name in audit}
if len(set(names.values())) != len(names):
    raise SystemExit('Flattened vendor names collide')
for name, record in audit.items():
    imports[name] = sp.check_output(['xcrun', 'nm', '-arch', 'arm64', '-m', '-u', str(source/name)], text=True)
    for dep in record['dependencies']:
        if dep['kind']=='system' and not dep['simulator_sdk_present']:
            key = Path(dep['path']).name
            missing.setdefault(key, set()).update(re.findall(r'external (\S+) \(from '+re.escape(key)+r'\)', imports[name]))
for key,item in survey.items():
    symbols=set(item['missing_symbols'])-{'dyld_stub_binder'}
    if symbols:
        missing.setdefault(key,set()).update(symbols)
manifest = {'claim':'Diagnostic missing API calls abort; loading is not Steam initialization.', 'boundaries':{}, 'images':{}}
known_classes = simulator_classes()
for library, symbols in missing.items():
    code = ['#include "UnsupportedBoundary.h"', '#import <objc/runtime.h>']
    for i, symbol in enumerate(sorted(symbols)):
        if symbol.startswith('_OBJC_METACLASS_$_'):
            # DE_DIAGNOSTIC_CLASS emits a class and its metaclass together, and a
            # class the Simulator already has needs neither. Never emit this.
            unmeasured.append(symbol)
            continue
        if symbol.startswith('_OBJC_CLASS_$_'):
            name = symbol.split('$_')[1]
            if name in known_classes:
                # The Simulator already declares this class; a diagnostic would be
                # a duplicate interface definition.
                unmeasured.append(symbol)
            else:
                code.append('DE_DIAGNOSTIC_CLASS(' + name + ')')
        elif symbol in constants:
            code.append('NSString *const Data%d __asm__(%s) = @%s;' % (i,json.dumps(symbol),json.dumps(constants[symbol])))
        elif symbol.startswith('_k') or symbol.startswith('_NS'):
            # A data symbol that is not a readable string constant (an allocator
            # reference, for example) cannot be represented as a measured string.
            # Export it as NULL and record it rather than failing the whole build.
            code.append('void *Data%d __asm__(%s) = 0;' % (i,json.dumps(symbol)))
            unmeasured.append(symbol)
        else:
            code.append('__attribute__((noreturn)) void Function%d(void) __asm__(%s);' % (i,json.dumps(symbol)))
            code.append('void Function%d(void) { DEUnsupported(%s); }' % (i,json.dumps(symbol)))
    src=out/(library+'.m'); src.write_text('\n'.join(code)+'\n')
    dst=out/('DEClientBoundary_'+library+'.dylib')
    command=['xcrun','clang','-target','arm64-apple-ios26.0-simulator','-isysroot',sdk,'-fobjc-arc','-dynamiclib',
        '-I',str(root/'port/de'),str(src),'-framework','Foundation','-Wl,-install_name,@loader_path/'+dst.name,
        '-Wl,-compatibility_version,1000.0','-o',str(dst)]
    if survey.get(library,{}).get('loaded'):
        path=survey[library]['path']
        if '.framework/' in path:
            command.append('-Wl,-reexport_framework,'+library)
        else:
            command.append('-Wl,-reexport_library,'+str((Path(sdk)/path.lstrip('/')).with_suffix('.tbd')))
    sp.run(command,check=True)
    sp.run(['codesign','--force','--sign','-',str(dst)],check=True)
    manifest['boundaries'][library]={'symbols':sorted(symbols),'data':'measured public constants only','functions':'abort','classes':'diagnostic only'}
spec=importlib.util.spec_from_file_location('prepare',root/'scripts/prepare-de-load-image.py')
adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
for name,record in audit.items():
    mapping={}
    for dep in record['dependencies']:
        if dep['kind']=='system' and Path(dep['path']).name in missing:
            mapping[dep['path']]='@loader_path/DEClientBoundary_'+Path(dep['path']).name+'.dylib'
        if dep['kind']=='vendor':
            relative=dep['path'][len('@loader_path/'):] if dep['path'].startswith('@loader_path/') else dep['path']
            child=((source/name).parent/relative).resolve()
            mapping[dep['path']]='@loader_path/'+names[str(child.relative_to(source))]
    thin=out/('original-'+names[name]);sp.run(['xcrun','lipo',str(source/name),'-thin','arm64','-output',str(thin)],check=True)
    manifest['images'][name]=adapter.prepare(thin,out/names[name],dependency_map=mapping)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if unmeasured:
    manifest['unmeasured_data']=sorted(set(unmeasured))
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('WARNING %d data symbol(s) exported as NULL diagnostics: %s'
          % (len(set(unmeasured)),', '.join(sorted(set(unmeasured)))))
print(out/'steamclient.dylib')
