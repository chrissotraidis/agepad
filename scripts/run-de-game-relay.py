#!/usr/bin/env python3
"""Bounded original-game test using a prepared private Steam relay package.

Reuses only the designated Simulator and DE diagnostic app. Stops the owned game
and temporary relay/helper after observation. It does not replace app data.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import subprocess as sp
import tempfile
import time

import de_device

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('package',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--probe',required=True,type=Path)
p.add_argument('--seconds',type=float,default=15)
p.add_argument('--device',default=de_device.device_udid())
a=p.parse_args()
def interrupted(signum, frame):
    raise KeyboardInterrupt(f'Runner interrupted by signal {signum}')
signal.signal(signal.SIGTERM, interrupted)
if not 1<=a.seconds<=3600: p.error('Observation must be between 1 and 3600 seconds')
package=a.package.resolve();out=a.output.resolve();probe=a.probe.resolve()
device=a.device;bundle='local.agepad.de-loader-probe'
def cmd(*args):return ['xcrun','simctl',*map(str,args)]
def discover():return json.loads(sp.check_output(cmd('spawn',device,probe),text=True))
def alive(pid):return sp.run(['kill','-0',str(pid)],capture_output=True).returncode==0
def owned_stop(pid,executable):
    if pid and alive(pid):
        try:
            observed=sp.check_output(['ps','-p',str(pid),'-o','comm='],text=True).strip()
        except sp.CalledProcessError:
            # The process can exit between kill -0 and ps. Treat that as
            # already cleaned rather than aborting the surrounding finally.
            return
        if observed!=str(executable):
            raise RuntimeError('Refusing to terminate a different process')
        os.kill(pid,signal.SIGTERM)
def wait_relay_ready(path,relay):
    deadline=time.monotonic()+5
    last_error='socket not ready'
    while time.monotonic()<deadline:
        if relay.poll() is not None: raise RuntimeError('Relay exited before readiness')
        try:
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
                client.settimeout(.5);client.connect(path);client.sendall(b'AGEPATH1')
                response=b''
                while len(response)<524:
                    chunk=client.recv(524-len(response))
                    if not chunk:break
                    response+=chunk
            status=int.from_bytes(response[0:4],'little',signed=True) if len(response)>=4 else -1
            pid=int.from_bytes(response[4:8],'little') if len(response)>=8 else 0
            host_path=response[8:520].split(b'\0',1)[0] if len(response)>=520 else b''
            if len(response)==524 and status==0 and pid and host_path:
                return
            last_error=f'invalid readiness response bytes={len(response)} status={status} pid={pid}'
        except (OSError,TimeoutError) as error:
            last_error=str(error)
        time.sleep(.05)
    raise RuntimeError(f'Relay readiness timeout: {last_error}')
boot=json.loads(sp.check_output(cmd('list','devices','booted','-j')))
assert [d['udid'] for ds in boot['devices'].values() for d in ds]==[device]
assert not discover()['routes'][0]['found'], 'An existing Simulator Steam service must be preserved'
meta=json.loads((package/'game-client-appkit.json').read_text())
assert sp.check_output(cmd('get_app_container',device,bundle,'app'),text=True).strip()==meta['app']
assert hashlib.sha256(Path(meta['boundary']).read_bytes()).hexdigest()==meta['sha256']
out.mkdir(parents=True,exist_ok=False)
# The Simulator's backing GPU registry identity changes after host reboot.
# Refresh desktop-only metadata from Metal, preserving the adapter's exact-ID
# match rather than copying a stale survey or weakening that check.
survey=out/'host-device-survey'
sp.run(['xcrun','--sdk','macosx','clang','-fobjc-arc','-framework','Foundation',
        '-framework','Metal',str(Path(__file__).resolve().parents[1]/
        'port/de/HostDeviceMetadataSurvey.m'),'-o',str(survey)],check=True)
survey_data=sp.check_output([str(survey)])
assert json.loads(survey_data), 'No backing Metal devices found'
(out/'host-device-survey.json').write_bytes(survey_data)
helperbin=package/'ipc-helper-relay/ipcserver-simulator'
with tempfile.TemporaryDirectory(prefix='agepad-path-',dir='/tmp') as temp:
    relay_socket=str(Path(temp)/'relay.sock');files=[];helper=None;observer=None;relay=None;awake=None;game=None
    def log(name):
        f=open(out/name,'w');files.append(f);return f
    try:
        # Simulator automation does not reliably reset loginwindow's idle timer.
        # Hold activity only for this bounded test, without changing lock prefs.
        awake=sp.Popen(['/usr/bin/caffeinate','-diu','-t',str(int(a.seconds)+60),
                        '-w',str(os.getpid())])
        relay=sp.Popen([str(package/'HostSteamPathRelay'),relay_socket,'20'],stdout=log('relay.stdout'),stderr=log('relay.stderr'))
        for _ in range(40):
            if Path(relay_socket).exists():break
            if relay.poll() is not None:raise RuntimeError('Relay exited before ready')
            time.sleep(.1)
        else:raise RuntimeError('Relay not ready')
        wait_relay_ready(relay_socket,relay)
        env=os.environ.copy();env.update(SIMCTL_CHILD_AGEPAD_HOST_PATH_RELAY=relay_socket,SIMCTL_CHILD_AGEPAD_IPC_TRACE='1')
        observer=sp.Popen(cmd('spawn',device,helperbin),env=env,stdout=log('helper.stdout'),stderr=log('helper.stderr'))
        for _ in range(40):
            lines=sp.check_output(['ps','-axo','pid=,comm='],text=True).splitlines()
            matches=[int(x.strip().split(None,1)[0]) for x in lines if x.strip().split(None,1)[-1]==str(helperbin)]
            if len(matches)==1:helper=matches[0];break
            if observer.poll() is not None:raise RuntimeError('Helper exited before ready')
            time.sleep(.1)
        assert helper
        for _ in range(30):
            if discover()['routes'][0]['found']:break
            time.sleep(.1)
        else:raise RuntimeError('Simulator service absent')
        env=os.environ.copy();env.update(SIMCTL_CHILD_DYLD_LIBRARY_PATH=str(package/'game-client'),
            SIMCTL_CHILD_AGEPAD_MAC_STEAM_MODULE='1',SIMCTL_CHILD_AGEPAD_MAC_STEAM_DISCOVERY='1')
        env['SIMCTL_CHILD_AGEPAD_HOST_METAL_METADATA']=str(out/'host-device-survey.json')
        env['SIMCTL_CHILD_AGEPAD_CASE_INSENSITIVE_RESOURCE_ROOT']=str(Path(meta['app']).parent/'AgeOfEmpires2Data')
        env.pop('SIMCTL_CHILD_AGEPAD_MAC_STEAM_PAUSE',None)
        game_insert=env.pop('AGEPAD_GAME_DYLD_INSERT_LIBRARIES',None)
        if game_insert:
            base_insert=env.get('SIMCTL_CHILD_DYLD_INSERT_LIBRARIES','')
            env['SIMCTL_CHILD_DYLD_INSERT_LIBRARIES']=':'.join(x for x in (base_insert,game_insert) if x)
        launch=sp.run(cmd('launch','--terminate-running-process','--stdout='+str(out/'game.stdout'),
            '--stderr='+str(out/'game.stderr'),device,bundle),env=env,text=True,capture_output=True,check=True,timeout=20)
        game=int(launch.stdout.strip().split(':')[-1])
        game_executable=Path(meta['app'])/'DEOriginalGame'
        record={'pid':game,'helper_pid':helper,'relay_pid':relay.pid,'app':meta['app'],
                'observation_seconds':a.seconds,'helper_exit_during_observation':None}
        (out/'launch.json').write_text(json.dumps(record,indent=2))
        deadline=time.monotonic()+a.seconds
        started=time.monotonic()
        while alive(game) and time.monotonic()<deadline:
            if record['helper_exit_during_observation'] is None and not alive(helper):
                record['helper_exit_during_observation']=time.monotonic()-started
                (out/'dependency-failure.json').write_text(json.dumps(record,indent=2))
                break
            time.sleep(.25)
        record['alive_after_observation']=alive(game)
        record['helper_alive_after_observation']=alive(helper)
        record['observation_ended_after_seconds']=time.monotonic()-started
        record['end_reason']=('helper-exited' if record['helper_exit_during_observation'] is not None
                              else 'observation-expired' if record['alive_after_observation'] else 'game-exited')
        record['owned_game_will_stop_during_cleanup']=record['alive_after_observation']
        (out/'result.json').write_text(json.dumps(record,indent=2))
        print(json.dumps(record,indent=2))
    finally:
        # Do not leave an unobserved renderer running after its Steam helper and
        # keep-awake coverage disappear. Refuse to stop a reused/different PID.
        if game:
            owned_stop(game,game_executable)
        if awake:
            if awake.poll() is None: awake.terminate()
            awake.wait(timeout=5)
        owned_stop(helper,helperbin)
        if observer:
            try:observer.wait(timeout=8)
            except sp.TimeoutExpired:observer.terminate();observer.wait(timeout=5)
        if relay:
            if relay.poll() is None:relay.terminate()
            relay.wait(timeout=5)
        for f in files:f.close()
        (out/'cleanup.json').write_text(json.dumps({'game_alive':bool(game and alive(game)),
            'helper_alive':bool(helper and alive(helper)),
            'relay_exit':relay.returncode if relay else None,'discovery':discover()},indent=2))
