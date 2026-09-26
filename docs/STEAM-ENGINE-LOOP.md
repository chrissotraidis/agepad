# Steam engine on iPad: goal loop

**Objective.** Chris's existing Steam copy of AoE II: DE starts and plays on the iPad without his Mac at play time, by running Valve's genuine Steam client engine (the arm64 `steamclient.dylib` from his own Mac Steam install) inside AgePad. No new license. No faked Steam or ownership answers, no ownership bypass, no stub backend. The Mac's Steam sign-in, config and saves are never copied or modified; the engine uses its own Steam folder. Chris signs in himself (QR code with the Steam mobile app preferred, so AgePad never sees a password). Existing routes stay as fallbacks: Mac helper over Wi-Fi/Tailscale and the USB cable.

## Gates

| Gate | Pass | Status |
|---|---|---|
| 0a | Engine loads in a plain Mac process, no Steam app involved | **Passed 26 Sep**: `CreateInterface` returns CLIENTENGINE_INTERFACE_VERSION005, SteamClient021 and SteamClient020 (`port/steam-engine/Stage0Probe.c`) |
| 0a-ii | Engine runs from an isolated Steam folder (nothing written under the real Mac Steam folder) and connects to Steam's servers | Next |
| 0b | Sign-in: QR code approved in the Steam mobile app (password + Steam Guard as fallback); remembered after restart | Open |
| 0c | Unmodified Mac DE reaches its menu against the headless engine, with an isolated home folder | Open |
| 0d | Wi-Fi off: engine offline mode, DE starts and plays a skirmish | Open |
| 1a–1f | Same on the iPad inside AgePad: sign-in screen, menu under 60 s with no Mac, airplane skirmish/save/resume, real online match, 60-min session under the 8 GB limit with in-match frame rate | Open |

**Stop rule.** If 0b cannot sign in without Steam's web window, stop this route, report, and fall back to the Mac helper with read caching and parallel prefetch.

## Evidence so far (26 Sep)

- The Wi-Fi bottleneck is 34,121 sequential Steam round trips at startup (10,262 real calls at ~3 round trips each; 370 achievements and ~1,200 stats read repeatedly; 5,026 distinct calls). Measured with the helper's opt-in capture. An in-device engine makes these local.
- `steamclient.dylib` is native arm64 and contains the client engine; the Steam app (`steam_osx`) is a launcher and the visible UI is a separate web layer (`steamui.dylib`, `steamwebhelper`).
- The library carries ordered method-name tables for its internal interfaces (e.g. IClientUser: LogOn, LogOff, BLoggedOn, … BHasCachedCredentials, DestroyCachedCredentials, SetAccountNameForCachedCredentialLogin, SetLoginInformation, SetLoginToken …), so interfaces can be mapped by name.
- Modern sign-in is inside the engine: Authentication service calls GetPasswordRSAPublicKey, BeginAuthSessionViaCredentials, BeginAuthSessionViaQR, UpdateAuthSessionWithSteamGuardCode, PollAuthSessionStatus, reachable through IClientUnifiedMessages (SendMethod, GetMethodResponseInfo, GetMethodResponseData, ReleaseMethod) — the same path Steam's login window uses.
- It spawns programs in places (fork, posix_spawn, popen); iPadOS forbids this, so those paths must fail safely.
- The Mac's saved sign-in (config/local.vdf, ssfn sentry file) is machine-bound and is never copied.
- The game binary also contains Feral Store, StoreKit/Game Center and Epic backends; they are not used (no new license).

