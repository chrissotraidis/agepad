# Local work check and Simulator smoke run — 2026-09-19

A read-only pass over the checked-out tree plus one fresh end-to-end launch of
the existing candidate. No runtime library, source or save was changed.

## Tree state before the run

- `scripts/check-de-install.py`: sole designated Simulator, private runtime,
  installed Simulator app and desktop Steam all pass. No physical iPad and no
  signing identity (unchanged).
- `python3 -m unittest discover -s tests -p 'test_*.py'`: 14 tests, OK.
- `python3 scripts/check-repo-safety.py`: pass.
- Housekeeping: three stale root duplicates (`AgePad-GOAL-LOOP.md`,
  `AgePad-INPUTS-AND-VERSIONS.md`, `AgePad-PRD.md`) had already been superseded
  by the `docs/` copies and are removed here. The feasibility report PDF that
  `DE-STATUS.md` cites (`output/pdf/agepad-de-feasibility-research.pdf`) is
  tracked so that reference resolves.
- One orphaned native Mac game process (`ref/AoE2DE`, started ~22 h earlier and
  reparented to launchd) was stopped. No Simulator game, helper or relay process
  remained from the previous session.

## Smoke run

`python3 scripts/recover-de-session.py loose-ends-20260919 --seconds 1800`

Every step below was accepted on the first tap: main menu; PLAY; SINGLE PLAYER;
LOAD GAME; the selected AUTOSAVE. The world then rendered with its HUD (Food
19875 / Wood 19900 / Gold 9940 / Stone 5000, Imperial Age) and the side
shortcuts drove the game: TOWN centred the camera and drew a selection box and
info panel on the town center; IDLE re-centred on another unit. No crash and no
missed dialog or menu tap.

Private evidence, including the landscape captures for each step:
`generated/mac-de-simulator-375/loose-ends-20260919/`.

## Interaction geometry (for future automated passes)

The Simulator window is a CUA target whose supplied click coordinates are scaled
onto the window: `global = window_origin + scale * supplied`, with `scale =
window_size / binding_screenshot_size` (measured 1.3164 for a 1316x1011 pt
window, i.e. a 1000x768 binding view). The raw `simctl` capture is a rotated
portrait frame, so it must be rotated 90 deg counter-clockwise before use.

For that window (`x=3 y=57 w=1316 h=1011`, one device point per screen point)
the device screen sat at window-relative `(68, 123)`, giving
`global_point = (71 + device_px_x/2, 180 + device_px_y/2)` and a click to supply
of `(global_point - window_origin)/1.3164`. The mapping was confirmed by
pixel-comparing the desktop and device captures (correlation 0.903) before any
tap was sent. Recompute it whenever the window is resized.

## Unchanged open items

Xbox Network sign-in, real two-finger pan/pinch on hardware, physical-iPad
packaging and acceptance, and the end-user import/service flow.
