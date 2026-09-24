# Physical iPad execution route check — 24 September 2026

## What changed

The signed `local.agepad.device-de-probe` was updated in place on the connected iPad Pro 12.9-inch (6th generation), iPadOS 26.7. A tiny separately signed `IOS` executable was embedded solely to test the process model. The game binary and Steam installation were not modified; no game data or saves were transferred. The setup page remained visible after the checks.

The original Steam DE game previously crashed at a null read before any menu. Its working Simulator run uses a separate copy of Steam's `ipcserver` helper and a Mac path relay. The hardware checks now show why copying that helper design to the iPad is not a routine packaging step:

| Hardware test | Observed result | Meaning for the current implementation |
|---|---|---|
| `posix_spawn` of a signed helper in this app bundle | `1` (`EPERM`); no child PID | The Simulator's separate helper cannot be launched this way in the current iPad app sandbox. |
| Lookup of `com.valvesoftware.steam.ipctool` from the app | `1100` (`BOOTSTRAP_NOT_PRIVILEGED`) | The app cannot discover that named service in this bootstrap namespace. |
| `bootstrap_check_in` for the same service | `1100` (`BOOTSTRAP_NOT_PRIVILEGED`) | Moving the helper into the app process does not make the same launchd service available. |

The exact console lines are in ignored `generated/de-device-candidate-20260924d/launch.log`; the compiled/signature-verified bundle is beside it. All 27 generated boundary sources still passed device-SDK syntax checks, and all 18 engine boundaries linked for `IOS`. These results rule out the **current separate-process/Mach-service architecture** on this device and provisioning setup. They do not prove that every possible authorized game port is impossible.

[Valve's current platform documentation](https://partner.steamgames.com/doc/store/application/platforms?language=english) lists Windows, macOS and Linux as Steam platforms. Its macOS instructions explicitly say Steam is incompatible with the macOS app sandbox. It does not describe an iOS Steam client integration. This reinforces the measured device result; copying desktop Steam files or providing a path reply is not a supported iPad authentication/session design.

## Native-engine/data alternatives checked

The only matching local Steam installation found in the authorized Mac Steam library is AoE II **Definitive Edition** (app `813780`), with about 19 GB of `AgeOfEmpires2Data`. No HD/2013 app `221380` manifest or local Age2HD install was found there. The old `ref/` and `worktrees/` inputs cited in the PRD are absent from this checkout.

Read-only temporary source copies were examined outside the project checkout:

- `freeaoe` commit `f5e46da59761868aa1814037f712f277c71b5bb3`, the exact R1 revision recorded in the PRD route notes. Its `DataManager.cpp` probes AoK/AoC/HD DAT names and **does not list** DE's `empires2_x2_p1.dat`. Its HD asset manager does not establish DE gameplay compatibility. Earlier repository evidence classifies R1 as engine development, with AI and campaign gaps. The Mac DE installation is not a drop-in input for this route.
- `openage` commit `fc981f208a05fa17f19c0764b3bb961a17734db7` has an AoE II DE conversion path and file layout that matches the Mac data root when pointed at `AgeOfEmpires2Data`. The installed `empires2_x2_p1.dat` SHA3-256 is `580c9d7b47132874e4b4dee589ef8904a28a210e14d1fff3fb6d9d6bb68def67`, whereas this checkout's recorded hash is for a different update. Edition recognition may still work, but exact version support is unproved. [Openage's README](https://github.com/SFTtech/openage/blob/master/README.md) states that gameplay is currently essentially nonfunctional. Its converter is a possible import component, not a playable iPad engine.

## Decision gate

Do not copy the 19 GB tree to the iPad until there is a game core that can use it. The retail Mac DE plus Steam relay has now failed two device architecture checks. For physical gameplay, proceed with a native game core that consumes a matching owned data edition, or obtain an authorized iOS-capable DE integration from the game owner. The PRD's native classic/HD route needs a matching HD/classic installation and substantial engine completion; the currently available DE data alone does not satisfy it. Preserve the working Mac-assisted Simulator candidate as a reference while that route is developed.

This is a route finding, not a claim of physical gameplay. The iPad currently runs the hardware scout and the honest DE setup page. Touch commands inside the actual game remain untested on hardware.
