#!/usr/bin/env python3
"""Run the existing private DE candidate without rebuilding or replacing saves.

Requires the designated iPad Simulator already booted and host Steam running.
The bounded runner closes the game and releases its helpers when time expires.
"""
import argparse
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'generated/mac-de-simulator-375'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', help='Fresh evidence directory name')
    parser.add_argument('--seconds', type=int, default=3600)
    parser.add_argument('--trace-sld-frames', action='store_true',
                        help='Observe original SLD parse/frame access; create trace-frames.arm in the run directory to start frame logging')
    parser.add_argument('--trace-input-consumer', action='store_true')
    parser.add_argument('--trace-pointer', action='store_true',
                        help='Log UIKit touch details and captured hardware button masks')
    parser.add_argument('--graphics-wait-pump-ms', type=float,
                        help='Run-loop pump interval for main-thread GPU waits (default 1 ms; the earlier build used 5)')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.name):
        parser.error('Use a simple run name containing letters, digits, dash or underscore')
    if not 1 <= args.seconds <= 3600:
        parser.error('Session duration must be 1–3600 seconds')
    # Do not inherit experimental Simulator flags from an earlier investigation.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith('SIMCTL_CHILD_AGEPAD_')
           and k not in ('SIMCTL_CHILD_DYLD_INSERT_LIBRARIES',
                         'AGEPAD_GAME_DYLD_INSERT_LIBRARIES')}
    features = '''SOFTWARE_BC7 SUPERSEDED_FIFO_DROP LAYER_ATTACH_FLUSH
        GRAPHICS_WAIT_FLUSH MAIN_GRAPHICS_WAIT SOFTWARE_BC4 MINSPEC_DIALOG
        WEB_DIRECT_PAINT WEB_SOFTWARE_COMPOSITING WEB_FORCE_TILES
        NO_CARBON_LAYOUT DEFAULT_UIKIT_CURSOR CGIMAGE_WRAPPER CURSOR_IMAGES
        UNAVAILABLE_GESTALT UIKIT_DISPLAY_MODE EVENT_QUEUE POINTER_STATE
        METAL_DEVICES ALPHA_RENDER_TARGET CUBE_ARRAY_STORAGE SOFTWARE_BC_ALL
        EXPERIMENTAL_BC_PROFILE QUIET_RENDER_TRACE INPUT_TIMING
        ORIGINAL_INPUT_TRACE TOUCH_COMMAND_OVERLAY TOUCH_MOVE_BEFORE_DOWN
        EARLY_METAL_ADAPTER BACKING_WORKING_SET'''.split()
    for key in features:
        env['SIMCTL_CHILD_AGEPAD_' + key] = '1'
    if args.graphics_wait_pump_ms is not None:
        env['SIMCTL_CHILD_AGEPAD_GRAPHICS_WAIT_PUMP_MS'] = str(args.graphics_wait_pump_ms)
    if args.trace_pointer:
        env['SIMCTL_CHILD_AGEPAD_BUTTON_MASK_TRACE'] = '1'
        env['SIMCTL_CHILD_AGEPAD_TOUCH_DETAIL_TRACE'] = '1'
    if args.trace_sld_frames:
        env['SIMCTL_CHILD_AGEPAD_SLD_PARSE_TRACE'] = '1'
        env['SIMCTL_CHILD_AGEPAD_SLD_FRAME_TRACE'] = '1'
        env['SIMCTL_CHILD_AGEPAD_SLD_FRAME_TRACE_ARM'] = str(PACKAGE / args.name / 'trace-frames.arm')
    libraries = ['SystemFrameworkCompat', 'SignalTrace', 'MainThreadGraphicsWait',
                 'ResourceFileTrace', 'OriginalInputTrace', 'AudioOutputCompat']
    if args.trace_input_consumer:
        env['SIMCTL_CHILD_AGEPAD_ORIGINAL_CONSUMER_TRACE'] = '1'
        libraries.append('OriginalInputConsumerTrace')
    for name in libraries:
        if not (PACKAGE / (name + '.dylib')).is_file():
            parser.error('Missing private runtime library: ' + name)
    # ResourceFileTrace also supplies compatibility hooks; retain the library
    # while leaving its high-volume diagnostic logging disabled.
    env['SIMCTL_CHILD_DYLD_INSERT_LIBRARIES'] = ':'.join(
        str(PACKAGE / (name + '.dylib')) for name in libraries)
    env['SIMCTL_CHILD_AGEPAD_WEB_SNAPSHOT_DIR'] = str(PACKAGE)
    os.chdir(ROOT)
    # Replace this wrapper so SIGTERM/Ctrl-C reaches the runner's cleanup.
    os.execve(sys.executable, [sys.executable, str(ROOT / 'scripts/run-de-game-relay.py'),
        str(PACKAGE), str(PACKAGE / args.name), '--probe',
        str(ROOT / 'generated/mac-de-simulator-280/simulator-kernel'),
        '--seconds', str(args.seconds)], env)


if __name__ == '__main__':
    main()
