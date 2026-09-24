#!/usr/bin/env python3
"""Private fail-fast loader experiment, not a functioning compatibility layer.

Use a prior actual Simulator symbol survey. Preserve original executable sections
and vendor code. Reexport available system APIs, stop at missing function/class
usage. Unavailable data exports are NULL diagnostics, not implemented constants.
No gameplay, authentication, or multiplayer success can be inferred here.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import plistlib
import struct
import subprocess

def run(*args):
    subprocess.run([str(x) for x in args],check=True)


def included_sources(source_lines):
    """Compat .m names referenced by the generated source, including transitively."""
    root=Path(__file__).resolve().parent.parent
    names=[]
    pending=[re.search(r'#include "([^"]+\.m)"',line).group(1)
             for line in source_lines if re.search(r'#include "([^"]+\.m)"',line)]
    while pending:
        one=pending.pop()
        if one in names:
            continue
        path=root/'port/de'/one
        if not path.is_file():
            continue
        names.append(one)
        pending.extend(re.findall(r'#include "([^"]+\.m)"',path.read_text()))
    return names


def implemented_symbols(names):
    """Symbols those sources define, by __asm__ name or by plain definition."""
    root=Path(__file__).resolve().parent.parent
    found=set()
    for one in names:
        path=root/'port/de'/one
        if not path.is_file():
            continue
        text=path.read_text()
        found.update(re.findall(r'__asm__\s*\(\s*"(_[A-Za-z0-9_$]+)"\s*\)',text))
        # A compat source may also define an original API under its real C name,
        # for example `void CGWarpMouseCursorPosition(CGPoint point) {`. Those
        # mangle to the imported symbol and must not be stubbed a second time.
        for match in re.finditer(r'^[A-Za-z_][A-Za-z0-9_ \t\*]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*\([^;()]*\)\s*\{',text,re.M):
            found.add('_'+match.group(1))
    return found

p=argparse.ArgumentParser()
p.add_argument('input',type=Path)
p.add_argument('app',type=Path)
p.add_argument('survey',type=Path)
p.add_argument('artifacts',type=Path)
p.add_argument('--application-bootstrap',action='store_true')
p.add_argument('--constants',type=Path)
p.add_argument('--main-executable',action='store_true')
p.add_argument('--loader-trace',action='store_true',help='Diagnostic interposition; caller-relative loader semantics may differ')
p.add_argument('--file-trace',action='store_true',help='Diagnostic real filesystem results for libsteam_api paths')
p.add_argument('--steam-module-compat',action='store_true',help='Opt-in verified Steam module representation; requires staged manifest')
p.add_argument('--keyboard-layout-unavailable',action='store_true',help='Opt-in missing Carbon layout diagnostic; no character translation')
p.add_argument('--default-uikit-cursor',action='store_true',help='Opt-in default UIKit pointer policy; no custom cursor support')
p.add_argument('--cgimage-wrapper',action='store_true',help='Opt-in CGImage-backed image representation')
p.add_argument('--unavailable-gestalt',action='store_true',help='Opt-in undefined Gestalt selectors; no OS version fabrication')
p.add_argument('--uikit-display-mode',action='store_true',help='Opt-in current UIKit display point dimensions; other mode APIs stop')
p.add_argument('--pointer-snapshot',action='store_true',help='Opt-in snapshot of app-owned UIKit touch/hover pointer')
p.add_argument('--metal-device-observer',action='store_true',help='Opt-in real iOS Metal enumeration with polling observer; requires iOS18')
p.add_argument('--menu-model',action='store_true',help='Menu object model only; no UIKit menu presentation')
p.add_argument('--window-view-host',action='store_true',help='UIKit window/view hosting for original engine layers')
p.add_argument('--application-events',action='store_true',help='Original application-created other-event representation')
p.add_argument('--alert-compat',action='store_true',help='Original alert panel objects hosted by UIKit')
p.add_argument('--pasteboard-compat',action='store_true',help='Original pasteboard names and change counts; no prompt bypass')
p.add_argument('--tracking-area-compat',action='store_true',help='Tracking areas hosted by the UIKit view')
p.add_argument('--min-spec-dialog',action='store_true',help='Opt-in minimum-specification dialog representation')
a=p.parse_args()
if a.main_executable and not a.application_bootstrap:
    p.error('--main-executable requires --application-bootstrap')
if a.steam_module_compat and (not a.application_bootstrap or a.loader_trace):
    p.error('--steam-module-compat requires bootstrap and excludes --loader-trace')
root=Path(__file__).resolve().parent.parent
app=a.app.resolve()
art=a.artifacts.resolve()
if 'ref' in app.parts or 'ref' in art.parts:
    raise SystemExit('Never write diagnostic outputs into references')
art.mkdir(parents=True,exist_ok=True)
incomplete=app/'BoundaryBuildIncomplete'
incomplete.write_text('Boundary build has not completed. Do not execute this candidate.\n')
survey=json.loads(a.survey.read_text())['platform_survey']
# CoreVideo itself loads on iOS, but the Mac display-link API is absent. The
# loader probe only checks framework loading, so include these imports in the
# boundary even when the framework reports as loaded.
for item in survey:
    if item['path'].endswith('/CoreVideo.framework/CoreVideo'):
        item['missing_symbols']=sorted(set(item['missing_symbols']) | {
            '_CVDisplayLinkCreateWithActiveCGDisplays', '_CVDisplayLinkRelease',
            '_CVDisplayLinkSetCurrentCGDisplay', '_CVDisplayLinkSetOutputCallback',
            '_CVDisplayLinkStart', '_CVDisplayLinkStop'})
    if item['path'].endswith('/Security.framework/Security'):
        item['missing_symbols']=sorted(set(item['missing_symbols']) | {
            '_SecTrustCopyAnchorCertificates'})
constants=json.loads(a.constants.read_text()) if a.constants else {}
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
spec=importlib.util.spec_from_file_location('adapter',root/'scripts/prepare-de-load-image.py')
adapter=importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
mapping={}
manifest={'claim':'Diagnostic load only. Missing APIs abort. NULL data exports are not implementations.',
          'libraries':[],'images':[]}
for item in survey:
    if item['loaded'] and not item['missing_symbols']:
        continue
    path=item['path']
    name=Path(path).name.replace('.dylib','').replace('.','_')
    install='@loader_path/DEBoundary_'+name+'.dylib'
    mapping[path]=install
    source=['#import <objc/runtime.h>','#include "UnsupportedBoundary.h"']
    aliases=[]
    if a.metal_device_observer and name=='Metal':
        source.append('#include "MetalDevicesCompat.m"')
    if a.unavailable_gestalt and name=='CoreServices':
        source.append('#include "GestaltCompat.m"')
    if a.keyboard_layout_unavailable and name=='Carbon':
        source.append('#include "KeyboardLayoutCompat.m"')
    if a.application_bootstrap and name=='Security':
        source.append('#include "SecurityTrace.m"')
    if a.application_bootstrap and name=='AppKit':
        source.append('#include "AppLifecycleCompat.m"')
        if a.steam_module_compat:
            source.append('#include "SteamModuleCompat.m"')
        source.append('#include "ScreenCompat.m"')
        if a.main_executable:
            # LoaderProbe.m also brings in Metal; the window/view host below
            # needs those declarations, so it is emitted first, as in the
            # working candidate.
            source.append('#define DE_EMBEDDED_DELEGATE 1\n#include "LoaderProbe.m"')
        # Include order matters: WindowViewCompat.m uses helpers defined by the
        # pasteboard compat and pulls in the drawable-presentation compat, so the
        # optional sources are emitted in the alphabetical order the working
        # candidate uses rather than in the order the flags are declared.
        optional = []
        if a.alert_compat:
            optional.append('AlertCompat.m')
        if a.default_uikit_cursor:
            optional.append('DefaultCursorCompat.m')
        if a.application_events:
            optional.append('EventCompat.m')
        if a.cgimage_wrapper:
            optional.append('ImageCompat.m')
        if a.menu_model:
            optional.append('MenuCompat.m')
        if a.pasteboard_compat:
            optional.append('PasteboardCompat.m')
        if a.tracking_area_compat:
            optional.append('TrackingAreaCompat.m')
        if a.window_view_host:
            optional.append('WindowViewCompat.m')
        if a.loader_trace:
            optional.append('RuntimeLoaderTrace.m')
        if a.file_trace:
            optional.append('RuntimeFileTrace.m')
        for one in optional:
            source.append('#include "' + one + '"')
    if a.application_bootstrap and name=='CoreGraphics':
        source.append('#include "DisplayLifecycleCompat.m"')
        source.append('#include "DisplayCallbacksCompat.m"')
        source.append('#include "DisplayGammaCompat.m"')
        if a.pointer_snapshot:
            source.append('#include "PointerEventCompat.m"')
        if a.uikit_display_mode:
            source.append('#include "DisplayModeCompat.m"')
        if a.min_spec_dialog:
            source.append('#include "MinSpecDialogCompat.m"')
    if a.application_bootstrap and name=='CoreVideo':
        source.append('#include "DisplayLinkCompat.m"')
    classes=set()
    actions=[]
    # A stub must never be emitted for a symbol that an included compat source
    # already defines through an __asm__ name: the duplicate mangled name fails
    # the link. This mirrors build-de-simulator-runtime.py's stub stripping.
    implemented=implemented_symbols(included_sources(source))
    for i,symbol in enumerate(item['missing_symbols']):
        if symbol in implemented:
            actions.append({'symbol':symbol,'action':'implemented by an included port/de compat source'})
            continue
        if a.application_bootstrap and a.application_events and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSEvent','_OBJC_METACLASS_$_NSEvent'):
            actions.append({'symbol':symbol,'action':'original-created other-event representation; no synthetic user input'})
            continue
        if a.application_bootstrap and a.window_view_host and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSView','_OBJC_METACLASS_$_NSView','_OBJC_CLASS_$_NSWindow','_OBJC_METACLASS_$_NSWindow'):
            actions.append({'symbol':symbol,'action':'UIKit window/view hosting for original layers; incomplete APIs stop'})
            continue
        if a.application_bootstrap and a.menu_model and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSMenu','_OBJC_METACLASS_$_NSMenu','_OBJC_CLASS_$_NSMenuItem','_OBJC_METACLASS_$_NSMenuItem'):
            actions.append({'symbol':symbol,'action':'retained menu model; presentation and action dispatch unimplemented'})
            continue
        # These classes are implemented by the opt-in compat sources, so the
        # generic diagnostic class must not be emitted for them.
        if a.alert_compat and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSAlert','_OBJC_METACLASS_$_NSAlert'):
            actions.append({'symbol':symbol,'action':'original alert panel objects hosted by UIKit'})
            continue
        if a.pasteboard_compat and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSPasteboard','_OBJC_METACLASS_$_NSPasteboard'):
            actions.append({'symbol':symbol,'action':'original pasteboard names and change counts; no prompt bypass'})
            continue
        if a.tracking_area_compat and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSTrackingArea','_OBJC_METACLASS_$_NSTrackingArea'):
            actions.append({'symbol':symbol,'action':'tracking areas hosted by the UIKit view'})
            continue
        if a.metal_device_observer and name=='Metal' and symbol in ('_MTLCopyAllDevicesWithObserver','_MTLRemoveDeviceObserver'):
            actions.append({'symbol':symbol,'action':'actual MTLCopyAllDevices with polling observer'})
            continue
        if a.application_bootstrap and a.pointer_snapshot and name=='CoreGraphics' and symbol in ('_CGEventCreate','_CGEventGetLocation','_CGEventSourceKeyState'):
            actions.append({'symbol':symbol,'action':'app-owned touch pointer snapshot; explicit initial-center policy'})
            continue
        if a.application_bootstrap and a.uikit_display_mode and name=='CoreGraphics' and symbol in ('_CGDisplayBounds','_CGDisplayCopyDisplayMode','_CGDisplayCopyAllDisplayModes','_CGDisplayModeGetWidth','_CGDisplayModeGetHeight','_CGDisplayModeRelease','_CGDisplayModeGetIOFlags'):
            actions.append({'symbol':symbol,'action':'current UIKit screen geometry; retained mode snapshot'})
            continue
        if a.application_bootstrap and name=='CoreGraphics' and symbol=='_CGDisplayIsInMirrorSet':
            actions.append({'symbol':symbol,'action':'single UIKit display is not mirrored'})
            continue
        if a.unavailable_gestalt and name=='CoreServices' and symbol=='_Gestalt':
            actions.append({'symbol':symbol,'action':'runtime opt-in gestaltUndefSelectorErr; no fabricated data'})
            continue
        if a.application_bootstrap and a.cgimage_wrapper and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSImage','_OBJC_METACLASS_$_NSImage'):
            actions.append({'symbol':symbol,'action':'runtime opt-in retained CGImage representation'})
            continue
        if a.application_bootstrap and a.default_uikit_cursor and name=='AppKit' and symbol in ('_OBJC_CLASS_$_NSCursor','_OBJC_METACLASS_$_NSCursor'):
            actions.append({'symbol':symbol,'action':'runtime opt-in UIKit default cursor only'})
            continue
        if a.keyboard_layout_unavailable and name=='Carbon' and symbol in ('_TISCopyCurrentKeyboardLayoutInputSource','_TISCopyCurrentASCIICapableKeyboardLayoutInputSource','_TISGetInputSourceProperty'):
            actions.append({'symbol':symbol,'action':'runtime opt-in unavailable layout; no character translation'})
            continue
        if a.application_bootstrap and symbol in ('_CGDisplayGammaTableCapacity','_CGGetDisplayTransferByTable','_CGSetDisplayTransferByTable'):
            actions.append({'symbol':symbol,'action':'gamma unavailable: zero capacity, explicit not-implemented errors'})
            continue
        if a.application_bootstrap and symbol in ('_CGDisplayRegisterReconfigurationCallback','_CGDisplayRemoveReconfigurationCallback'):
            actions.append({'symbol':symbol,'action':'UIKit screen callback registry; post-change events only'})
            continue
        if a.application_bootstrap and symbol in ('_NSApp','_NSApplicationMain','_OBJC_CLASS_$_NSApplication','_OBJC_METACLASS_$_NSApplication','_OBJC_CLASS_$_NSWorkspace','_OBJC_CLASS_$_NSScreen','_OBJC_CLASS_$_NSRunningApplication'):
            actions.append({'symbol':symbol,'action':'application bootstrap adapter; incomplete lifecycle stops explicitly'})
            continue
        if symbol=='dyld_stub_binder':
            continue # dyld-internal binder, not an API implementation.
        if symbol.startswith(('_OBJC_CLASS_$_','_OBJC_METACLASS_$_')):
            cls=symbol.split('$_',1)[1]
            classes.add(cls)
            actions.append({'symbol':symbol,'action':'diagnostic class; construction/unknown methods abort'})
        elif (symbol.startswith(('_k','__swift_FORCE_LOAD')) or
              symbol.endswith(('Notification','DocumentType','Template','RunLoopMode')) or
              symbol in ('_NSApp','_NSDocumentTypeDocumentAttribute','_NSApplicationLaunchUserNotificationKey','_NSPasteboardTypeString') or
              symbol.startswith('_NSTouchBarItemIdentifier')):
            if symbol in constants:
                source.append('NSString *const DEData%d __asm__(%s) = @%s;' % (i,json.dumps(symbol),json.dumps(constants[symbol])))
                actions.append({'symbol':symbol,'action':'actual public Mac string constant','value':constants[symbol]})
            else:
                source.append('void *DEData%d __asm__(%s) = 0;' % (i,json.dumps(symbol)))
                actions.append({'symbol':symbol,'action':'NULL diagnostic data; not implemented'})
        else:
            source.append('__attribute__((noreturn)) void DEFunction%d(void) __asm__(%s);' % (i,json.dumps(symbol)))
            source.append('void DEFunction%d(void) { DEUnsupported(%s); }' % (i,json.dumps(symbol)))
            actions.append({'symbol':symbol,'action':'abort with symbol/backtrace'})
    for cls in sorted(classes):
        if cls=='NSColor':
            # UIKit has a private class with this name. Keep the missing imported
            # API diagnostic distinct instead of creating an ambiguous duplicate.
            source.append('#include "ColorCompat.m"' if a.application_bootstrap and a.window_view_host else 'DE_DIAGNOSTIC_CLASS(DEDiagnosticNSColor)')
            for kind in ('CLASS','METACLASS'):
                exported='_OBJC_'+kind+'_$_NSColor'
                actual='_OBJC_'+kind+'_$_DEDiagnosticNSColor'
                aliases.append('-Wl,-alias,'+actual+','+exported)
        else:
            source.append('DE_DIAGNOSTIC_CLASS(%s)' % cls)
    src=art/(name+'.m')
    src.write_text('\n'.join(source)+'\n')
    command=['xcrun','clang','-target','arm64-apple-ios15.0-simulator','-isysroot',sdk,
             '-fobjc-arc','-dynamiclib','-I',str(root/'port/de'),str(src),'-framework','Foundation',
             '-Wl,-install_name,'+install,'-o',str(app/Path(install).name)]
    command.extend(aliases)
    if a.application_bootstrap and name=='AppKit':
        command.extend(['-framework','UIKit'])
        if a.window_view_host:
            # WindowViewCompat.m hosts original layers and observes a GameController
            # keyboard, so both frameworks must be on the link line.
            command.extend(['-framework','QuartzCore','-framework','GameController'])
        if a.main_executable:
            command.extend(['-framework','Metal','-framework','CoreGraphics'])
    if a.application_bootstrap and name=='CoreGraphics':
        command.extend(['-framework','UIKit',str(app/'DEBoundary_AppKit.dylib')])
        if a.pointer_snapshot:
            command.extend(['-framework','GameController'])
    if a.application_bootstrap and name=='CoreVideo':
        command.extend(['-framework','UIKit','-framework','QuartzCore'])
    if item['loaded']:
        if '.framework/' in path:
            framework=re.search(r'/([^/]+)\.framework/',path).group(1)
            command.append('-Wl,-reexport_framework,'+framework)
        else:
            command.append('-Wl,-reexport_library,'+str((Path(sdk)/path.lstrip('/')).with_suffix('.tbd')))
    elif name=='AudioUnit':
        command.append('-Wl,-reexport_framework,AudioToolbox')
    run(*command)
    run('codesign','--force','--sign','-',app/Path(install).name)
    manifest['libraries'].append({'path':path,'replacement':install,'reexports_original':bool(item['loaded']),'symbols':actions})

input_app=a.input.resolve()
vendors=[]
for path in (input_app/'Contents/Frameworks').rglob('*'):
    if path.is_symlink() or not path.is_file(): continue
    magic=path.open('rb').read(4)
    if magic not in (b'\xca\xfe\xba\xbe',b'\xcf\xfa\xed\xfe'): continue
    relative=path.relative_to(input_app/'Contents/Frameworks')
    flat=re.sub(r'(\.framework)/Versions/[^/]+/',r'\1/',str(relative))
    destination='Vendor_'+path.name+'.dylib'
    for prefix in ('@rpath/','@executable_path/../Frameworks/','@loader_path/'):
        mapping[prefix+str(relative)]='@loader_path/'+destination
        mapping[prefix+flat]='@loader_path/'+destination
    vendors.append((path,destination))
for path,destination in vendors:
    thin=art/(destination+'.thin')
    run('xcrun','lipo',path,'-thin','arm64','-output',thin)
    manifest['images'].append(adapter.prepare(thin,app/destination,dependency_map=mapping))
engine=input_app/'Contents/MacOS/Age Of Empires II'
engine_output=app/('DEOriginalGame' if a.main_executable else 'Engine.dylib')
manifest['images'].append(adapter.prepare(engine,engine_output,dependency_map=mapping,preserve_executable=a.main_executable))
raw=engine.read_bytes()
offset=32
for _ in range(struct.unpack_from('<I',raw,16)[0]):
    cmd,size=struct.unpack_from('<II',raw,offset)
    if cmd==0x80000028:
        (app/'EngineEntry.json').write_text(json.dumps({'file_offset':struct.unpack_from('<Q',raw,offset+8)[0]}))
    offset+=size
info=plistlib.loads((input_app/'Contents/Info.plist').read_bytes())
(app/'BoundaryDiagnostic.json').write_text(json.dumps({'enabled':True,'invoke_entry':False,'claim':manifest['claim'],
    'principal_class':info.get('NSPrincipalClass'),'main_nib':info.get('NSMainNibFile'),'engine_is_main_executable':a.main_executable}))
if a.main_executable:
    probe_info=plistlib.loads((app/'Info.plist').read_bytes())
    probe_info['CFBundleExecutable']='DEOriginalGame'
    (app/'Info.plist').write_bytes(plistlib.dumps(probe_info))
(art/'boundary-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
incomplete.unlink()
try:
    run('codesign','--force','--sign','-',app)
except Exception:
    incomplete.write_text('Final candidate signing failed. Do not execute.\n')
    raise
print(app)
