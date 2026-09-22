"""One place that decides which Simulator the AgePad scripts talk to.

The designated device was created on one Mac, so its UDID cannot be reproduced
elsewhere with `simctl create`. Scripts therefore resolve it here instead of
carrying a literal: an explicit argument wins, then AGEPAD_SIMULATOR_UDID, then
the UDID this Mac uses.
"""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_UDID = '574671AD-6F61-4558-9528-BF946DDB760A'
DEFAULT_NAME = 'AgePad G5 iPad'
DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'


def device_udid(explicit=None):
    return explicit or os.environ.get('AGEPAD_SIMULATOR_UDID') or DEFAULT_UDID


def booted():
    """[(udid, name)] for every booted Simulator."""
    out = subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'booted', '-j'],
                         capture_output=True, text=True)
    try:
        groups = json.loads(out.stdout or '{}').get('devices', {})
    except ValueError:
        return []
    return [(d['udid'], d.get('name', '')) for group in groups.values() for d in group
            if d.get('state') == 'Booted']


def require_sole_device(explicit=None):
    """The designated device must be the only booted Simulator.

    Returns (ok, message). Never boots or shuts anything down.
    """
    wanted = device_udid(explicit)
    running = booted()
    if not running:
        return False, 'No booted Simulator; boot ' + wanted
    if len(running) > 1:
        return False, 'More than one booted Simulator: ' + ', '.join(u for u, _ in running)
    if running[0][0] != wanted:
        return False, 'Booted %s but expected %s' % (running[0][0], wanted)
    return True, running[0][1]


def export_line(explicit=None):
    """The shell line a new machine needs after creating its device."""
    return 'export AGEPAD_SIMULATOR_UDID=' + device_udid(explicit)


def package_dir(explicit=None):
    """Which runtime package the scripts work against.

    On this Mac that is the long-standing private package. Elsewhere - a clone
    whose runtime was built by scripts/bootstrap-de-simulator.py - it is the most
    recently built candidate, so the documented flow needs no edits.
    """
    if explicit:
        return Path(explicit).expanduser()
    legacy = ROOT / 'generated/mac-de-simulator-375'
    if legacy.is_dir():
        return legacy
    built = sorted((ROOT / 'generated').glob('de-candidate-*/package'),
                   key=lambda path: path.stat().st_mtime)
    return built[-1] if built else legacy
