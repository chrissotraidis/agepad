#!/usr/bin/env python3
"""Count real drawable completion records over a bounded live observation.

This measures Simulator composition notifications, not display scanout. Log
arrival timing is not suitable for per-frame latency or percentile estimates.
"""
import argparse
import json
import time
from pathlib import Path


def measure(log: Path, seconds: float) -> dict:
    displayed = dropped = 0
    pending = ""
    with log.open(errors="replace") as stream:
        stream.seek(0, 2)
        started = time.monotonic()
        while time.monotonic() - started < seconds:
            pending += stream.read()
            lines = pending.split("\n")
            pending = lines.pop()
            for line in lines:
                if line.startswith("DE_DRAWABLE_TERMINAL "):
                    displayed += " displayed=1 " in line
                    dropped += " displayed=0 " in line
            time.sleep(min(0.1, max(0, seconds - (time.monotonic() - started))))
        elapsed = time.monotonic() - started
    return {
        "seconds": elapsed,
        "displayed_completions": displayed,
        "dropped_completions": dropped,
        "displayed_completions_per_second": displayed / elapsed,
        "scope": "Simulator composition notifications; not physical scanout or per-frame latency",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not 0 < args.seconds <= 60:
        parser.error("seconds must be in (0, 60]")
    result = measure(args.log, args.seconds)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
