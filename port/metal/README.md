# Optional Metal backend

Private engineering candidate for the pinned FreeAoE/SFML core. The default build remains EAGL. The Metal candidate uses ANGLE's ES1 frontend plus two small OES separate-blend extensions, and an SFML EGL/CAMetalLayer adapter. The dependency lock includes the generated extension code, so routine builds do not need code-generation tools or the extra Khronos XML checkouts.

The matched Simulator tutorial test in `docs/artifacts/2026-09-06/backend-53/result.json` measured median10.83FPS with EAGL and56.71FPS with Metal. The synthetic comparison passed all24 integer-scale images exactly; fractional differences occurred only at exact nearest-neighbor texel boundaries. This is not complete-game, physical-device or sustained-performance acceptance.

## Build

Prerequisites: the normal locked source setup, native Mac host resgen build, Xcode26.6/SDK26.5, CMake/Ninja, Python3.11+ and GN2552 (`4f6a76b64b82`). GN is available as CIPD package `gn/gn/mac-arm64` at `git_revision:4f6a76b64b8279e98004f541f8e136307efe5e01`; the script checks the installed version. The pinned Chromium Clang/objdump packages are downloaded by the pinned installer. No paid service is needed.

```sh
# Fetch pinned sources and apply locked patches into generated/metal.
python3.11 scripts/build-metal.py --prepare-only

# Build one SDK at a time; the host resource generator is shared.
AGEPAD_GN=/absolute/path/to/gn scripts/build-ios-core.sh simulator metal
AGEPAD_GN=/absolute/path/to/gn scripts/build-ios-core.sh device metal

# Original renderer remains available.
scripts/build-ios-core.sh simulator eagl
```

Set `AGEPAD_PYTHON` to a Python3.11+ executable if needed. The Metal deployment target is currently18.0, inherited from the current ANGLE iOS build configuration; the original EAGL path remains15.0. Older-OS support for Metal is unverified.

`--sources-root PATH` chooses a different source cache. `--angle-source PATH --sfml-source PATH` reuse separately prepared candidates only when their exact revisions and patch contents match. `--gn PATH` is equivalent to AGEPAD_GN. `--angle-only` stops after the framework build. Existing wrong revisions, modified dependencies and unexpected source changes are refused rather than reset. Push is disabled on prepared remotes. The game worktree and nested dependencies must match the normal source lock.

Outputs are `generated/freeaoe-metal-ipadsim/freeaoe.app/freeaoe` and `generated/freeaoe-metal-ipaddevice/freeaoe.app/freeaoe`. Matching ANGLE frameworks are under the selected ANGLE source's `out/ipadsim` or `out/ipaddevice`.

## Package a private probe

```sh
python3 scripts/package-ios-probe.py \
  --executable generated/freeaoe-metal-ipadsim/freeaoe.app/freeaoe \
  --angle-frameworks generated/metal/angle/out/ipadsim \
  --output generated/AgePadMetalCandidate.app
```

The packager checks that all three ANGLE frameworks match the executable's SDK, embeds/signs nested frameworks, and adds the loader path. It refuses existing output paths. It does not include game data, install/launch a Simulator, perform device provisioning, or publish anything. A device build still needs a separately authorized physical signing/testing handoff.

## Remaining work

Full clean-machine/clean-checkout reproduction, physical testing, resize/lifecycle and anti-aliasing settings, broad asset/gameplay parity, longer performance/memory/thermal tests, complete saves/progression and unfinished product/game systems remain open. Backend54 evidence records build/packaging validation; it does not close these gates.

## Renderer regression fixture

`tests/renderer` contains the asset-free Simulator probe used for the cross-backend image comparison. Configure it as a separate iOS CMake project with the selected SFML_DIR and FreeType_LIB, and package its executable with the same SDK's frameworks. It writes48 PNG images to its own app Documents directory and logs `AGEPAD_SFML_RENDER_RESULT=0` on success. Use a separate probe bundle/device from an active user game, and retain each backend's image set before replacing a test app.

```sh
python3 tests/renderer/compare.py --baseline /path/to/eagl-images \
  --candidate /path/to/metal-images --output /path/to/comparison.json
```

The comparison script requires Pillow (test-only). It reports all differences. It separately identifies pixel centers on exact texel boundaries in the fractional fixture; this is diagnostic information, not blanket permission to ignore other image changes.
