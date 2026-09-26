# Physical iPad DE handoff — 25 September 2026

**For the next agent:** the objective is to make the user's owned **Steam Age of Empires II: Definitive Edition** run natively and accept touch commands on their physical iPad. The physical build is **not playable**. It has never shown an original game menu or frame on hardware. Do not substitute classic/HD, an asset viewer, streaming, or a synthetic Steam response. Read [the scope override in the PRD](AgePad-PRD.md) and [the full device route log](DEVICE-ROUTE-20260924.md) before changing the route.

## Current state and verified evidence

- Checkout: `the AgePad checkout`, `main` at `bacfd5a` before this handoff. The stable signed setup probe is `generated/de-device-candidate-20260925d/AgePadDeviceProbe.app` (ignored/private). Normal launch shows a diagnostic setup screen, not Play.
- Physical device: paired iPad Pro 12.9-inch (6th generation). Rediscover its UDID with `xcrun devicectl list devices`; do not hard-code it into tracked files. The stable probe was reinstalled **in place** and launched normally after the last crash experiment.
- The user's Mac Steam DE `AgeOfEmpires2Data` tree is already in this app's iPad `Documents`. A fresh post-restore inventory found **24,886 files, 1,223 directories, 20,372,303,243 bytes, zero path/type/size differences** from the Mac source. Four representative files had matching SHA-256 readbacks earlier. Do not clear the app container, uninstall the app, or retransfer the 19 GB tree without a specific need and backup.
- The original vendor `SteamAPI_Init()` succeeds on iPad through a temporary paired-Mac CoreDevice TCP/path relay. It sees a real Steam pipe, user and logged-on status; no Steam response or ownership result is fabricated. This is an **engineering Mac dependency**, not standalone iPad Steam integration.
- With full data and real Steam initialization, the original game launch callback runs, then the original executable crashes **before a menu** at image offset `0x505fc` (null `x0`). A synchronous read-only fault trace shows all three backend candidates constructed and `IceLinkerDynamic` selected. Its object field `+8` (module handle) is null. The selected virtual method is at image offset `0x33c24` and returns the null pointer that the caller dereferences.
- The game requests `Frameworks/libsteam_api.dylib` beside the app bundle. That sibling path is absent on iPad; a narrow file trace saw `stat` fail with `ENOENT`. The tracked opt-in experiment in `port/de/SteamModuleCompat.m` packages a SHA-256-verified copy of the owned Mac file as inert data and maps **only that exact `stat` query**. On the signed iPad test the query succeeded twice (real file size 412,160 bytes), but the module handle remained null and the same crash followed. The hook did not observe a subsequent `dlopen`. This fixes one observed file query, not the loader.
- The two successful mapped `stat` calls came from inside `IceLinkerDynamic::Load`, returning to original image offset `0x285d8`. Disassembly shows a later hash/guard call at `0x28620`, compare at `0x28634`, a branch away at `0x28638`, and the `dlopen` call at `0x28660`. **Which branch is taken and why has not been measured.** Do not describe the guard as DRM, a path hash, or the definitive cause without tracing it.
- A broad `dlopen`/`dlsym` interposer disturbed startup and crashed earlier. A separate narrow `open`/`stat`/`access`/`fopen` injection also disturbed startup; it was useful only to identify the missing `stat` path. A private replacement libSystem boundary did not receive the game's `dlopen` calls. LLDB with `--start-stopped` attached and resolved a breakpoint at `0x28634`, but stayed in dyld startup for over a minute and could not halt the process. No useful branch register was collected. These are failed diagnostic methods, not game results.

## Source and private artifacts

| Purpose | Location |
|---|---|
| Device route, UX observations and failure history | `docs/DEVICE-ROUTE-20260924.md` |
| Current concise status | `docs/STATUS.md` |
| Opt-in backend pointer/fault trace, pinned to current DE image offsets | `port/de/ContextDispatchTrace.h` (`AGEPAD_DEVICE_LINKER_TRACE`) |
| Exact Steam module metadata/load experiment | `port/de/SteamModuleCompat.m` (`AGEPAD_DEVICE_STEAM_MODULE`) |
| Fresh iPad SDK boundary build | `scripts/build-de-device-runtime.py` |
| In-place signed probe packaging | `scripts/prepare-de-device-probe.py` |
| Paired-Mac Steam relay | `scripts/relay-de-steam-device.py` and `HostSteamPathRelay` in the ignored candidate package |
| Full on-device import inventory verifier | `scripts/verify-de-device-import.c`; a built copy is in `generated/de-device-candidate-20260925d/` |
| Working private build inputs | `generated/de-candidate-20260924-responder/` and `generated/de-device-ipc-20260925d/` |
| Hardware logs from this investigation | ignored `generated/de-device-candidate-20260925h/fatal-linker-launch.log`, `...k/path-trace-launch.log`, `...n/module-fix-launch.log`, `...q/caller-launch.log`, `...r/stack-launch.log` |

The large private diagnostic `.app` copies from `h` through `r` were removed after preserving logs; the stable `d` app remains. Never commit Steam binaries, the 19 GB data tree, device logs, signing material, account details, or `generated/` outputs. The current tracked source contains the opt-in metadata mapping and corrected post-signing translated-module hash. The signed device build's manifest hash matched its actual module locally, but the game did not reach the load hook.

## Next bounded work

1. **Resolve the loader branch.** Inspect the original `IceLinkerDynamic::Load` input (`x1` copied to `x20` at `0x284b8`) and the computed value at `0x28634` on a normal device run, or reproduce the comparison in the working Mac/Simulator path. A minimal in-process, read-only trace at this one function is preferable to global loader interposition. The failed LLDB attach does not prove the branch is unreachable. Do not force the compare or bypass any authentication/ownership check to claim progress.
2. **If the guard passes, verify the real load.** Require a `dlopen` observation, nonzero dynamic module handle, exact original/translated module hashes, and the game's genuine Steam interface consumption. The device module mapping currently covers `stat` only; trace any further exact file APIs before extending it. Keep original executable sections unchanged in a product candidate.
3. **Only then validate gameplay.** Capture a physical original game frame, start a scenario, test tap/drag/pinch/hold and commands, save/relaunch/resume, and measure real device performance. A process alive, Steam initialized, or a setup screenshot is not gameplay acceptance. Continue the setup/import UX audit when a Play gate actually exists.

## Reproducing safely

Check `git status --short`, device pairing, free Mac/iPad space, the owned Steam build and `xcrun simctl list devices booted` first. The repository rule is **never more than one booted Simulator**; other projects had three booted at the last check, so do not boot AgePad G5 or shut down someone else's devices as part of this handoff. A full signed candidate is about 360 MB, and repeated copies filled the Mac disk during this investigation. Keep one fresh output, preserve its log, and remove only known duplicate ignored experiments after checking for unique files.

Use fresh output names. The following is a command template; set the signing profile, identity and device UDID locally from the machine's current state rather than recording them in the repository:

```sh
python3 scripts/build-de-device-runtime.py \
  --package generated/de-candidate-20260924-responder/package \
  generated/de-device-probe-NEXT

python3 scripts/prepare-de-device-probe.py \
  --candidate-root generated/de-candidate-20260924-responder \
  --boundary generated/de-device-probe-NEXT \
  --ipc-load-probe generated/de-device-ipc-20260925d \
  --original-steam-module "$HOME/Library/Application Support/Steam/steamapps/common/AoE2DE/Age Of Empires II.app/Contents/Frameworks/libsteam_api.dylib" \
  --output generated/de-device-candidate-NEXT/AgePadDeviceProbe.app \
  --profile "$AGEPAD_SIGNING_PROFILE" --identity "$AGEPAD_SIGNING_IDENTITY"

codesign --verify --deep --strict generated/de-device-candidate-NEXT/AgePadDeviceProbe.app
xcrun devicectl device install app --device "$AGEPAD_DEVICE_UDID" \
  generated/de-device-candidate-NEXT/AgePadDeviceProbe.app
```

The original launch is opt-in. Check that Mac Steam still listens on loopback port `57343`, and choose free relay ports. Start the host path responder and Python relay in separate terminals **immediately before** launch; the responder has a 60-second deadline. One known-working command shape is:

```sh
generated/de-candidate-20260924-responder/package/HostSteamPathRelay \
  generated/de-device-candidate-NEXT/path.sock 20

python3 scripts/relay-de-steam-device.py --bind :: --allow paired-tunnel \
  --listen-port 61343 --steam-port 57343 \
  --path-listen-port 61344 \
  --path-socket generated/de-device-candidate-NEXT/path.sock --seconds 120

xcrun devicectl device process launch --terminate-existing --console \
  --device "$AGEPAD_DEVICE_UDID" \
  --environment-variables '{"AGEPAD_STEAM_TUNNEL_HOST":"paired-tunnel","AGEPAD_STEAM_LOOPBACK_PORT":"57343","AGEPAD_STEAM_TUNNEL_PORT":"61343","AGEPAD_HOST_PATH_RELAY_TCP_HOST":"paired-tunnel","AGEPAD_HOST_PATH_RELAY_TCP_PORT":"61344","AGEPAD_DEVICE_RUN_ORIGINAL":"1","AGEPAD_DEVICE_LINKER_TRACE":"1","AGEPAD_DEVICE_STEAM_MODULE":"1"}' \
  local.agepad.device-de-probe > generated/de-device-candidate-NEXT/launch.log 2>&1
```

The three commands need overlapping lifetimes; running them sequentially in one shell would wait at the first command. Capture console output under ignored `generated/`. Do not assume the paired tunnel address or Steam process survives a reconnection.

After any crash experiment, reinstall `generated/de-device-candidate-20260925d/AgePadDeviceProbe.app` **in place**, launch `local.agepad.device-de-probe` without diagnostic environment variables, and verify the data remains:

```sh
xcrun devicectl device install app --device "$AGEPAD_DEVICE_UDID" \
  generated/de-device-candidate-20260925d/AgePadDeviceProbe.app
xcrun devicectl device process launch --terminate-existing \
  --device "$AGEPAD_DEVICE_UDID" local.agepad.device-de-probe
generated/de-device-candidate-20260925d/verify-de-device-import \
  "$AGEPAD_DEVICE_UDID" local.agepad.device-de-probe \
  "$HOME/Library/Application Support/Steam/steamapps/common/AoE2DE/AgeOfEmpires2Data"
```

Expected verifier output is the file/directory/byte totals above with `differences=0`. If those counts differ, stop destructive installs and inspect the app container and existing backup before changing data. No public release, push, or playable claim has been authorized or earned.
