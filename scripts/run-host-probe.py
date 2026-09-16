#!/usr/bin/env python3
"""Run one identified native Mac probe and retain its true exit status."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('--bundle', type=Path, required=True)
ap.add_argument('--manifest', type=Path, required=True)
ap.add_argument('--profile', type=Path, required=True)
ap.add_argument('--evidence', type=Path, required=True)
ap.add_argument('--ui-resolution', choices=['800x600', '1024x768', '1280x1024'], default='800x600')
ap.add_argument("--audio-diagnostics", action="store_true")
ap.add_argument("--touch-controls", action="store_true")
ap.add_argument("--game-sample", choices=["basic", "all"])
args = ap.parse_args()
exe = args.bundle.resolve() / 'Contents/MacOS/AgePadProbe'
manifest = json.loads(args.manifest.read_text())
if not manifest.get('snapshot_verified'):
    raise SystemExit('Input snapshot has not been verified')
snapshot = Path(manifest['snapshot'])
if not snapshot.is_dir() or not exe.is_file():
    raise SystemExit('Required snapshot or executable is missing')
running = subprocess.run(['pgrep', '-fl', str(root / 'generated') + '/.*Contents/MacOS'], capture_output=True, text=True)
if running.returncode == 0:
    raise SystemExit('An existing generated app must be inspected/stopped first: ' + running.stdout)
if running.returncode != 1:
    raise SystemExit('Could not verify process state')
args.profile.mkdir(parents=True, exist_ok=True)
args.evidence.mkdir(parents=True, exist_ok=True)
record_path = args.evidence / 'process.json'
if record_path.exists():
    raise SystemExit('Evidence directory already contains a run; preserve it and use a new directory')
command = [str(exe), '--game-path=' + str(snapshot), '--language=en', '--debug', '--ui-resolution=' + args.ui_resolution]
if args.game_sample:
    command.append('--game-sample=' + args.game_sample)
if args.touch_controls:
    command.append('--touch-controls')
if args.audio_diagnostics:
    command.append('--audio-diagnostics')
record = {'spec_revision': 'agepad-v2-2026-09-06', 'route': 'R1', 'target': 'macos-arm64',
          'input_set_id': manifest['input_set_id'], 'input_manifest_sha256': manifest['content_manifest_sha256'],
          'ruleset_id': manifest['ruleset_id'], 'artifact_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
          'source_lock_sha256': hashlib.sha256((root / 'dependencies.lock.json').read_bytes()).hexdigest(),
          'candidate_diff_sha256': hashlib.sha256(subprocess.check_output(['git', '-C', str(root / 'worktrees/freeaoe'), 'diff', '--binary'])).hexdigest(),
          'command': command, 'started_at': time.time(), 'exit_code': None}
with (args.evidence / 'runtime.log').open('xb') as output:
    process = subprocess.Popen(command, cwd=args.profile.resolve(), stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    record['pid'] = process.pid
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    print('Owned native probe PID', process.pid, flush=True)
    record['exit_code'] = process.wait()
record['finished_at'] = time.time()
record_path.write_text(json.dumps(record, indent=2) + '\n')
print('Native probe exited', record['exit_code'], flush=True)
sys.exit(record['exit_code'] if record['exit_code'] >= 0 else 128 - record['exit_code'])
