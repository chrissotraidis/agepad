# Physical iPad execution route check — 24 September 2026

## What changed

The signed `local.agepad.device-de-probe` was updated in place on the connected iPad Pro 12.9-inch (6th generation), iPadOS 26.7. A tiny separately signed `IOS` executable first tested the process model. The game binary and Steam installation were not modified. The table below records that initial test; the later Steam and data experiments are described separately.

The original Steam DE game previously crashed at a null read before any menu. Its working Simulator run uses a separate copy of Steam's `ipcserver` helper and a Mac path relay. The hardware checks now show why copying that helper design to the iPad is not a routine packaging step:

| Hardware test | Observed result | Meaning for the current implementation |
|---|---|---|
| `posix_spawn` of a signed helper in this app bundle | `1` (`EPERM`); no child PID | The Simulator's separate helper cannot be launched this way in the current iPad app sandbox. |
| Lookup of `com.valvesoftware.steam.ipctool` from the app | `1100` (`BOOTSTRAP_NOT_PRIVILEGED`) | The app cannot discover that named service in this bootstrap namespace. |
| `bootstrap_check_in` for the same service | `1100` (`BOOTSTRAP_NOT_PRIVILEGED`) | Moving the helper into the app process does not make the same launchd service available. |
| App-local Mach port and send/receive | All calls succeeded; message ID matched | An in-app transport is technically possible without a global launchd service. |
| Original Mac Steam `ipcserver`, adapted and loaded in-app | Loaded and reached app-local service check-in | The original helper can begin running on hardware as a thread; this does not establish a Steam session. |
| Original Steam client `CreateInterface("SteamClient020")` | Nonnull interface, status `0` | The factory loads, but this alone does not create a working pipe. |
| Original `SteamAPI_Init()` with helper running | `false`; `ipcserver init failed`, then Steam not running and install path unknown | DE still cannot authenticate or start on the iPad. The client returned failure before the traced service lookup or Mach request. |

### Same-day follow-up: paired Mac tunnel

The row above describes the first in-app helper test. Later signed, in-place device probes reached farther using a short-lived relay bound to the paired CoreDevice IPv6 tunnel. It forwarded genuine Steam TCP bytes to the Mac's existing loopback listener. A second tunnel forwarded the original SDK's path request to the existing Mac responder. No credentials, ownership result or Steam reply was invented.

The physical iPad then observed a nonzero original `CreateSteamPipe` result, a nonzero global user, a `SteamUser021` interface and `BLoggedOn=1`. The original SDK received a fresh Mac Steam path, checked the Mac process's continued existence through a fresh host query, and loaded the already signed local representation of `steamclient.dylib`. **`SteamAPI_Init()` returned success** in ignored `generated/de-device-candidate-20260924ac/launch.log`. The currently running Mac `steamclient.dylib` hash differs from the private staged client's original hash, so the observed client-protocol compatibility is narrower than an exact-build match. The tunnel address changes across device reconnections; discover it again for each run. The relay closes automatically after its bounded test window.

This clears the Steam initialization diagnostic on hardware, not the game or product gate. A preserved-data backup of the probe's `Documents` and `Library` was made. Original game launch is still opt-in. Do not report physical gameplay until real frames and commands are observed.

### Original game launch on the iPad

The signed probe used the actual Mac Steam DE install and an explicit `AGEPAD_DEVICE_RUN_ORIGINAL` diagnostic switch. The CoreDevice tunnel address changed during app launch, so the first static-address run failed. The relay now accepts only a peer on a current paired tunnel, and the device derives that tunnel's Mac endpoint at connection time. With this change, the iPad's original Steam client reported a pipe, global user and `BLoggedOn=1`; the original vendor `SteamAPI_Init()` returned success. The original DE launch callback ran. This is physical original-code execution, but the app terminated with `SIGSEGV` before a menu.

The crash report for the first successful device launch records a null read at original executable offset `0x505fc`. Disassembly shows a virtual call immediately before that instruction; its return value is null (`x0=0` in the crash report), and the game dereferences it without a guard. A read-only follow-up showed the vendor Steam API's `SteamUtils010` interface is present while the game executable's separate SteamUtils context remains empty. At the last pre-crash observation, its context callback is present, its interface slot is null, and all three original Steam backend slots are null. The trace does not yet prove which missing initialization causes the virtual method to return null. Initializing a second copy of the same Steam API was ruled out by switching the probe to the game's vendor copy; the crash was unchanged. The next test must identify the real object and missing initialization, then prove that the game consumes the genuine interface. Do not fill the slot with a synthetic interface or infer that `SteamAPI_Init()` alone made the game playable.

### Data import and storage

The Mac Steam `AgeOfEmpires2Data` tree is about 19 GB and contains 24,886 files. The first recursive device copy exhausted the file service's free space and stopped with a device-write error. Only that incomplete copy was removed; the probe's prior `Documents` and `Library` backup was preserved, and no unrelated device data was cleared. After the iPad had about 40 GB free, a second full private transfer completed. Its initial destination contained an extra `resources/` directory level; this was corrected by on-device renames before verification. `scripts/verify-de-device-import.c` compared every relative path, file type and size against the Mac Steam source: **24,886 files, 1,223 directories, 20,372,303,243 regular-file bytes on each side, zero differences**. Four representative files, including the DAT and a 292 MB Wwise pack, were read back from the iPad and matched the Mac SHA-256 hashes. This is a complete inventory with sampled content hashes, not a full cryptographic audit. The app now shows an inventory-checked state; its marker was read back after an in-place app update.

With the complete data present, the original game still crashes before the menu at the same original executable offset `0x505fc`. Data absence was therefore not the cause of this observed startup crash. Read-only executable analysis identified the fallback object's RTTI name as `IceLinkerStubs`; the crash path calls one of its virtual methods and dereferences the null return. The game also has a constructor for three original Steam backend candidates and a selector that chooses one by state. The device trace shows the candidate slots empty at the crash, but it does not yet establish whether construction was skipped or teardown happened first. The next useful runtime trace is at the game's backend constructor, selector and teardown, in that order. Temporary module-path and launch-notification experiments did not change the crash and were removed from maintained source.

The [first physical setup screenshot](images/device-setup-20260924.png) correctly labels the app as a hardware test, but its Steam line says only “unavailable” and its next step redirects the user to the Mac Simulator. The [25 September installed screen](images/device-setup-20260925.png) shows the DE title, imported-inventory state, available space and the paired-Mac Steam test dependency. It no longer says the already imported files still need importing. The full inventory was rechecked after that in-place update, with zero differences. A release setup flow needs capacity preflight, edition/build detection, explicit import progress and verification, recovery after interruption, Steam connection status, and a Play control only after an actual game launch gate. No touch gameplay was observed on hardware.

The separate-process result is in ignored `generated/de-device-candidate-20260924d/launch.log`; the initial in-app trace is in `generated/de-device-candidate-20260924m/launch.log`. Later relay traces and the full-data launch are also under ignored `generated/`. All 27 generated boundary sources passed device-SDK syntax checks, and all 18 engine boundaries linked for `IOS`. The original Steam helper and client libraries loaded on hardware. The initial no-session result was superseded by a real Mac-assisted session; the separate-process/Mach-service architecture remains denied on this device and provisioning setup.

[Valve's current platform documentation](https://partner.steamgames.com/doc/store/application/platforms?language=english) lists Windows, macOS and Linux as Steam platforms. Its macOS instructions explicitly say Steam is incompatible with the macOS app sandbox. It does not describe an iOS Steam client integration. This reinforces the measured device result; copying desktop Steam files or providing a path reply is not a supported iPad authentication/session design.

## DE engine/data alternatives checked

The installed Steam copy is AoE II **Definitive Edition** (app `813780`), with about 19 GB of `AgeOfEmpires2Data`. Chris explicitly requires this edition on iPad; classic/HD is outside the active product scope, regardless of what an older PRD route proposed. The old `ref/` and `worktrees/` inputs cited in that route are absent from this checkout.

Read-only temporary source copies were examined outside the project checkout:

- `freeaoe` commit `f5e46da59761868aa1814037f712f277c71b5bb3`, the exact R1 revision recorded in the PRD route notes. Its `DataManager.cpp` probes AoK/AoC/HD DAT names and **does not list** DE's `empires2_x2_p1.dat`. Its HD asset manager does not establish DE gameplay compatibility. Earlier repository evidence classifies R1 as engine development, with AI and campaign gaps. It is not a DE gameplay route as-is.
- `openage` commit `fc981f208a05fa17f19c0764b3bb961a17734db7` has an AoE II DE conversion path and file layout that matches the Mac data root when pointed at `AgeOfEmpires2Data`. The installed `empires2_x2_p1.dat` SHA3-256 is `580c9d7b47132874e4b4dee589ef8904a28a210e14d1fff3fb6d9d6bb68def67`, whereas this checkout's recorded hash is for a different update. Edition recognition may still work, but exact version support is unproved. [Openage's README](https://github.com/SFTtech/openage/blob/master/README.md) states that gameplay is currently essentially nonfunctional. Its converter is a possible import component, not a playable iPad engine.

## Decision gate

The active target is **Definitive Edition only**. The genuine Mac-assisted Steam diagnostic now initializes on hardware, so continue with the imported DE data and original engine startup. The paired Mac tunnel is an engineering test dependency; a standalone end-user Steam setup and safe data importer are not complete. Do not replace the target with classic/HD, a different game, or an asset viewer. Preserve the working Mac-assisted Simulator candidate as the reference.

This is a route finding, not a claim of physical gameplay. The iPad currently runs the hardware scout and the honest DE setup page. Touch commands inside the actual game remain untested on hardware.
