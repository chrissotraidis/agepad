# Steam account-risk review

Reviewed 1 October 2026. Scope: the v0.1.0 Mac-to-iPad route and the current source.
This is an engineering and policy review, not a legal opinion or approval from
Valve, Microsoft or Feral Interactive.

The subsequent [focused interoperability investigation](STEAM-INTEROPERABILITY-LOOP.md)
traces the actual QR request, distinguishes local integrity checks from remote
authentication, examines legal precedents, and evaluates alternative architectures.

**We cannot promise that using AgePad will never result in account action.** This
project has only just been released, so the absence of incident reports supplies
no meaningful enforcement history from which to estimate a probability. Successful
Steam sign-in and gameplay establish functionality, not account safety.

**Decision:** if the requirement is to avoid modifying proprietary Steam client
or SDK files, the current standalone AgePad route does not meet it. Its header
edits are actual modifications, not merely file copying. On a conservative reading
of the published terms, this route should be treated as outside documented
standard permissions unless an applicable exception is established. This review
does not establish one. That conclusion does not depend on requesting written
guidance from the companies involved.

## What the project actually does

- **Personal copies:** `scripts/agepad-kit.py` imports game and Steam files from
  the player's Mac. Its recipe verifies source hashes and describes the changes.
  Public releases exclude these files; the player's completed IPA contains them.
- **Modified packaging:** `scripts/prepare-de-load-image.py` changes Mach-O
  platform metadata and library paths, and re-signs copies. It checks that original
  code and data sections remain identical. This is narrower than rewriting game
  instructions, but the files and execution environment are still modified.
  The Mac installation's originals are preserved; the staged copies change.
- **Internal Steam interfaces:** `port/steam-engine/SteamEngineHost.c` reads ARM64
  instructions to identify internal `IClientUser` methods, then calls Valve's
  client engine directly. This is not simply an app using documented game SDK
  calls with the ordinary desktop client.
- **Real authentication:** `SteamQRSignIn.m` calls Valve's HTTPS
  `IAuthenticationService` endpoints, requests a Steam-client token audience and
  identifies the device by name. The player approves the QR session in Steam's
  mobile app. The refresh token is stored in the iPad Keychain. The optional
  password flow handles the password in app memory and sends its encrypted form
  to Valve; QR sign-in does not require entering a password into AgePad.
- **Real ownership:** `AgePadSteamRoute.m` waits for Valve's
  `BIsSubscribedApp(813780)` answer. Offline startup uses Steam's cached licenses.
  The reviewed normal path does not manufacture ownership or a successful login.
- **Integrity compatibility:** `port/de/SteamModuleCompat.m` maps the game's
  Steam-module file reads to the untouched original bytes, then redirects loading
  to the adapted module after separate hash checks. The game's check is not
  patched out. Nevertheless, what it reads and what gets loaded differ in
  packaging. This works around a file-acceptance barrier and deserves explicit
  disclosure; it does
  not justify a blanket assertion that no security mechanism is affected.
- **Other routes and diagnostics:** `IPCSystemCompat.c` also retains a paired-Mac
  relay with socket/PID compatibility. That route is not established as approved
  either. The opt-in `AGEPAD_TEST_INPUT` command-file reader automates game input;
  it is disabled on ordinary launches. Keep it out of multiplayer use.

## Measured modifications

The v0.1.0 base's recipe contains 16 header transformations: eight outputs sourced
from the Steam installation and eight sourced from the game. Two game-sourced
outputs are adaptations of its bundled `libsteam_api.dylib`.

| Source | Header-transformed outputs |
| --- | --- |
| Steam installation | `steamclient.dylib`, `libtier0_s.dylib`, `libvstdlib_s.dylib`, `crashhandler.dylib`, `libaudio.dylib`, `IPCHelperDevice.dylib` (from `ipcserver`), `Breakpad.dylib`, `breakpadUtilities.dylib` |
| Game's Steam SDK | `SteamModuleSimulator.dylib`, `Vendor_libsteam_api.dylib.dylib` |

Reconstructing the SDK transformations from matching original inputs changed
69 bytes and 286 bytes respectively before signing. All changes were within
Mach-O load commands, and file-backed code/data sections compared equal.
Separately, the signed 30 September device build's `steamclient.dylib`,
`libtier0_s.dylib` and `libvstdlib_s.dylib` compared equal to their preserved
original snapshots by code/data sections, but had different whole-file hashes
and changed platform metadata from macOS to iOS. These are static checks, not a
new device run or proof of how Valve detects the resulting app.

Six current Steam-install inputs no longer matched the pinned release recipe, so
they were not used as exact release reconstructions. The recipe inventory, SDK
reconstruction and preserved-client comparisons are distinct evidence.
Dependency redirection also changes which implementations the original
instructions call. Identical instructions therefore do not imply identical
execution, an untouched signature or an unmodified file.

Historical controlled tests in [DE-STATUS.md](DE-STATUS.md) isolated two barriers:
the game rejected an adapted SDK before loading, while an untouched SDK passed
file acceptance but was rejected by dyld for its macOS platform. The compatibility
route preserves original file reads and loads the adapted copy. This establishes
an integrity-related workaround; it does not establish that the particular
file check is DRM or anti-cheat, or that no protection is affected.

## What the published policies establish

The [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/)
checked for this review is dated 10 September 2026. Section 1.B explicitly includes
the Steam client in its scope. Section 2.G restricts
modification and reverse engineering, subject to permission and applicable-law
exceptions; it also addresses network protocol emulation or redirection. Section
4.B restricts unauthorized process tampering. Section 4.C addresses automation.
Section 9.C permits account or subscription restrictions for agreement breaches.

**Assessment:** the documented changes engage these restrictions on their face;
an applicable permission or legal exception has not been established. Owning the
game, keeping copies private and preserving instructions do not supply one.

The [Steamworks SDK Access Agreement](https://partner.steamgames.com/documentation/sdk_access_agreement/)
is not a general Steam-client modification license. Section 1.1 permits specified
SDK source use and object-code redistribution of `redistributable_bin` with a
licensee's software. Section 2.4 restricts SDK reverse engineering, replacements
and direct service communication outside its APIs. This is a separate developer
agreement; owning the game does not establish that a player or AgePad has the
relevant developer grant, and that grant would not automatically cover the
proprietary client engine.

There are real exceptions, which prevent a categorical claim that every Steam
modification is unlawful. Steam contains separately licensed open-source
components; for example, the upstream [Breakpad license](https://github.com/google/breakpad/blob/main/LICENSE)
permits modifications subject to its conditions. That does not establish the
license of every bundled binary or permission for Valve's client engine.
[U.S. copyright law, section 1201(f)](https://www.copyright.gov/title17/92chap12.html),
also contains a conditional interoperability exception for independently created
programs. Necessity, lawful access, purpose, infringement and other-law conditions
matter. This review has not established that AgePad's entire route qualifies;
that statute is not a promise of continued Steam access.

[Valve's documented third-party web sign-in](https://partner.steamgames.com/doc/features/auth)
uses OpenID to obtain a SteamID. AgePad instead obtains a client login token for
its embedded engine. An accessible authentication endpoint and the player's QR
approval are not evidence that Valve approves this particular integration.

## What comparable projects do and do not show

| Primary source | Relevance and limit |
| --- | --- |
| [GameNative's implementation disclosure](https://github.com/utkarshdalal/GameNative/blob/master/THIRD_PARTY_NOTICES#steam-client-bootstrap-shim-source-withheld) | Its Android integration describes loading a real Steam client library, supplying a refresh token and calling undocumented internal interfaces identified through static analysis. This is a closer comparison than cosmetic skins, but its binary adaptations have not been matched to AgePad's. No substantiated Steam-account ban solely for ordinary use was found in the public search. |
| [Valve's Proton source](https://github.com/ValveSoftware/Proton/blob/proton_11.0/lsteamclient/unixlib.cpp) | Its Steam wrapper loads the host's platform-native Steam client library. A Valve-maintained compatibility tool is not evidence of permission for AgePad's privately retargeted iOS client. |
| [Millennium FAQ](https://docs.steambrew.app/users/getting-started/faq) | This Steam modification project claims the client is exempt from the agreement's modification restrictions. That premise conflicts with the current agreement's explicit client inclusion. Its maintainer reassurance cannot establish AgePad's permission or enforcement safety. |
| [ArchiSteamFarm FAQ](https://github.com/JustArchiNET/ArchiSteamFarm/wiki/FAQ) | The maintainer acknowledges contractual uncertainty and reports suspensions involving extensive account networks, trading or traffic. Those reports are not proof that ordinary compatibility play or metadata edits trigger bans. Its independent client also differs materially from AgePad. |
| [AppImage packaging notes](https://github.com/AppImage/AppImageKit/wiki/Bundling-Steam) | An April 2017 experiment uses `patchelf` on Steam's dependency search path, but explicitly says it was not working. This demonstrates an attempted packaging technique, not approved use or a measured history of safe use. |

The current [official Linux launcher package](https://repo.steampowered.com/steam/)
was also inspected without installation. Its documentation includes
the Subscriber Agreement and separately licenses particular build utilities and
device rules. It supplied no general client-binary editing grant. The older
AppImage reference to a limited redistribution license is not evidence of a
current grant for the Mac-to-iPad route.

## Actual suspension reports and what they establish

The [ArchiSteamFarm incident list](https://github.com/JustArchiNET/ArchiSteamFarm/wiki/FAQ#did-anybody-get-banned-for-it)
documents restrictions involving a 1,000+ bot trading network, 170+ accounts
during the 2017 Winter Sale, 120+ accounts reportedly flooding Steam through an
outdated-client bug, and a 128-account farming operation reported in June 2021.
The page includes messages attributed to Steam Support. This review confirms
that the maintainer published those reports, but cannot independently
authenticate the messages or establish the complete cause of each restriction.
They do not establish that an unofficial client alone causes bans during normal
compatibility play.

For Millennium, the [August 2026 "Ban appeal"](https://github.com/SteamClientHomebrew/Millennium/discussions/870)
concerns its Discord server, not a Steam account. No substantiated Steam-account
ban solely for normal Millennium use was found in this public search. The same
search finding applies to ordinary GameNative use; neither result establishes
an absence of private incidents, official permission or a measured ban rate.

There are confirmed enforcement examples with different mechanisms. Valve's
[19 October 2023 CS2 release notes](https://store.steampowered.com/news/posts/?appids=730&enddate=1697825171&feed=steam_community_announcements)
confirm VAC bans affecting users of incompatible AMD graphics drivers and
announce reversals. Bungie's [Destiny restriction policy](https://help.bungie.net/hc/en-us/articles/360049517431-Destiny-Account-Restrictions-and-Banning-Policies)
explicitly says circumventing SteamOS/Proton incompatibility results in a game
ban. Those show possible anti-cheat or publisher enforcement, not an established
Steam-wide account-ban trigger for AgePad's library adaptations.

**No percentage is supported.** These examples do not provide a representative
population, observation period, complete reporting or verified causes suitable
for estimating AgePad's risk. Public projects and user anecdotes establish
related integrations, not an account-safety guarantee. No substantiated matching
ban precedent was found; private support and Discord reports were not reviewed.
The research does not establish that Steam-wide bans are routine for ordinary
compatibility play, and cannot establish that AgePad is compliant or ban-safe.

## Different meanings of "banned"

| Outcome | Evidence and limits |
| --- | --- |
| Client stops connecting | The code handles protocol rejection and lost sign-in. Valve can change the service or client requirements. A connection failure alone is not proof of a ban. |
| VAC ban | [Valve's VAC FAQ](https://help.steampowered.com/en/faqs/view/571A-97DA-70E9-FF74) describes cheat detection on VAC-secured servers. AoE II DE's [store page](https://store.steampowered.com/app/813780/) and [category API](https://store.steampowered.com/api/appdetails?appids=813780&filters=categories) did not advertise VAC support when checked. This review found no established AgePad-specific VAC trigger. Store metadata is not a complete anti-cheat audit or a safety guarantee. |
| Publisher multiplayer/game restriction | [AoE II DE's ban policy](https://support.ageofempires.com/hc/en-us/articles/360047397872-Age-of-Empires-II-Definitive-Edition-ban) permits temporary and permanent restrictions. The [Code of Conduct](https://www.ageofempires.com/code-of-conduct/) addresses game tampering; [Xbox Community Standards](https://www.xbox.com/en-US/legal/community-standards) address unfair modifications and unauthorized use. How these apply to AgePad has not been confirmed by the publisher. |
| Steam account/subscription restriction | Separate from VAC and a publisher ban. The contractual permission concern above remains even without a competitive cheat. Likelihood cannot be quantified from this review. |

[Steamworks game-ban guidance](https://partner.steamgames.com/doc/features/anticheat)
also distinguishes publisher-issued Steam game bans from general account action.
It says game bans should address unfair multiplayer advantage. That is not an
AgePad exemption and does not establish which enforcement systems this game uses.

## Offline play and practical choices

Single-player offline play avoids participation in multiplayer matches during
that session. It does not remove the earlier online sign-in, the modified
software or permission uncertainty. This is not a verified "ban-safe mode."
The source attempts offline startup after some connection/protocol failures, but
rejects several credential refusals and requires cached ownership. Continued
access after account action or future service changes cannot be promised.

| Choice | Does it remove the current Steam modifications? |
| --- | --- |
| Current standalone AgePad | No. Platform/dependency/signature changes are built into the route. |
| AgePad offline mode | No. It retains adapted files and depends on an earlier genuine login and cached licenses. |
| Existing paired-Mac relay | No. `port/de/IPCSystemCompat.c` still routes SDK loading to the app's adapted local `steamclient.dylib`, with PID/socket compatibility. It is not a clean remote-only Steam boundary. |
| Replace client code with [SteamKit](https://github.com/SteamRE/SteamKit) or another independent implementation | Could remove selected Valve binary edits, but adds a different unofficial protocol/SDK integration. No permission or safety improvement is established; this is substantial new engineering. |
| Supported Mac game and Valve's [Steam Link for iPad](https://help.steampowered.com/en/faqs/view/4C03-C8BA-3EA1-B26A) | Removes AgePad's adapted client/SDK from the execution arrangement. It requires the computer to run the game and changes the standalone product into streaming. |

There is no verified configuration switch that makes today's standalone AgePad
meet a no-Steam-modification requirement. A different architecture would need
fresh technical and permission assessment. More gameplay tests cannot resolve
that requirement. If this uncertainty is unacceptable, use the supported Mac
game, optionally through official Steam Link, rather than treating the existing
relay or offline mode as a fix. Full online matches in AgePad remain an open
functional gate and cannot be advertised as verified or safe.

## Review coverage

Reviewed the runtime files above, prior project engineering records, the public
README, rights/setup/release documentation, GitHub issues/PRs returned by the API,
and the official sources linked here. Searches for AgePad with Steam/ban terms
produced no verified incident. Private community reports were not reviewed.
Removing a project later cannot guarantee reversal of an account restriction or
other consequence. This review does not establish jurisdiction-specific legality
or an exhaustive inventory of applicable game and platform license terms.

Before this review, public documentation explained personal-copy packaging and
lack of affiliation but did not explicitly disclose account risk. The README
warning and documentation changes accompanying this review add that disclosure.
The source release-notes file is separate from GitHub's existing release body;
changing the file does not update that hosted release body.

The local 65-file base IPA matched the hosted v0.1.0 asset's published SHA-256,
`a03b8f133a6cf4c26f1d23354ca7aa380d51b6ad73d4b588a227f54ef080b502`.
Its recipe recorded 16 header adaptations and an original-module wrapper; the
base did not contain the vendor module filenames checked. The earlier release
audit reported zero vendor-content matches. This review did not repeat that full
content scan, a history audit, device testing or an enforcement experiment.
