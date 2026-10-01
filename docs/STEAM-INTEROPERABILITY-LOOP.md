# Steam interoperability: focused investigation

Reviewed 1 October 2026 against source commit `395fed1`. This supplements the
[account-risk review](STEAM-ACCOUNT-RISK.md), rather than establishing legal
clearance or a safe account configuration.

**Goal:** identify a credible standalone iPad route that preserves genuine
authentication and ownership, with an established basis for the necessary use
of Steam and game software. Test specific obstacles before deciding whether
this port can meet that goal.

**Current result:** today's native route requires adapted Steam files and uses
internal client interfaces. No compliant standalone replacement has been
demonstrated. That is a reason to withhold compliance claims; it is not proof
that every possible interoperability architecture is unlawful or impossible.
The prominent README caution has been published. The following rounds explain
what was learned and what remains unresolved.

## Round 1: what actually changes at sign-in?

The reviewed route is:

1. AgePad constructs a QR authentication request to Valve over HTTPS.
2. The player approves that session in Steam's mobile app. AgePad polls Valve
   for the resulting Steam-client refresh token and stores it in the Keychain.
3. AgePad passes the token to the embedded client engine's real `SetLoginToken`
   and `LogOn` methods, discovered through internal interface inspection.
4. The engine connects to Steam. AgePad waits for its genuine ownership result
   for app `813780`; offline startup depends on cached licenses.

Source: [SteamQRSignIn.m](../port/steam-engine/SteamQRSignIn.m),
[SteamEngineHost.c](../port/steam-engine/SteamEngineHost.c), and
[AgePadSteamRoute.m](../port/steam-engine/AgePadSteamRoute.m).
The transport code does not edit Valve's authentication replies. Reading the
JWT subject locally is payload decoding, not cryptographic signature validation;
it extracts an account ID and does not manufacture a server-accepted token.
Authentic HTTPS responses and subsequent server acceptance are different checks.

### Actual request probe, with no network sign-in

Compiled the current `SteamQRSignIn.m` on macOS and intercepted its request using
`NSURLProtocol`. The interceptor captured the body and deliberately returned a
transport error before sending anything. Decoded the emitted protobuf bytes;
no password, account, token or fabricated successful response was used.

| Emitted item | Observed value |
| --- | --- |
| Endpoint | `IAuthenticationService/BeginAuthSessionViaQR/v1/` at `api.steampowered.com` |
| Method and encoding | POST; form-encoded, base64 protobuf |
| `device_friendly_name` | `AgePad (iPad)` |
| `platform_type` | `1`, meaning Steam-client token audience, not an OS number |
| `website_id` | `Client` |
| Nested device details | Friendly name and platform type only, fields 1 and 2 |
| OS, machine ID, executable hash, Apple signature in this body | None emitted |

Local evidence is retained in ignored
`generated/steam-interoperability-review-20261001/`: `qr-request-probe.m`,
`qr-request.json`, and `qr-request-decoded.json`.
This measures this component's actual request construction. It does not measure
iPad-specific default HTTP headers, TLS characteristics, or the engine's later
Steam connection. The component's source is unchanged by the probe.

**Result:** Valve can identify the integration from the explicit device name
without first detecting a modified binary. If the session is approved, Valve
can associate it with the account. This is no evidence of an existing ban rule
for that name, and concealing the name would not resolve permission questions.

## Round 2: what could Steam or another player see?

| Observer / signal | Evidence and limit |
| --- | --- |
| Valve: device name and approved account | Directly supported by the emitted QR request and the authentication flow. |
| Valve: connection IP and session activity | The server receives connections. Valve's privacy policy describes IP logging and application/device data. |
| Valve: OS, client package version, machine identity | Steam's tracked client-logon schema has these fields. Their exact values from AgePad's embedded engine have not been captured. |
| Valve: game, build and compatibility-tool information | The tracked games-played schema supports these fields. Schema availability is not proof of AgePad's exact transmitted values. |
| Valve: adapted library bytes or hashes | No automatic whole-file hash upload was established by this review. The QR body has none. That does not exclude other client messages, local inspection or crash/violation telemetry. |
| Publisher/game backend | Steamworks can expose identity and ownership to a game backend. The game's own telemetry could also identify its environment; its exact backend payloads remain unaudited. |
| Other players | Public persona and game/profile information depend on Steam settings and game features. No evidence here gives ordinary players access to the local library files or QR request. |

Protocol evidence: the independently maintained SteamTracking copies of
[authentication messages](https://github.com/SteamTracking/Protobufs/blob/master/steam/steammessages_auth.steamclient.proto),
[client logon](https://github.com/SteamTracking/Protobufs/blob/master/steam/steammessages_clientserver_login.proto),
and [games played](https://github.com/SteamTracking/Protobufs/blob/master/steam/steammessages_clientserver.proto).
These are useful implementation evidence, not an official API permission grant.

The preserved original client imports `sysctl`, `uname`, `NSProcessInfo` and
IORegistry functions. This gives it ways to inspect the environment; it does
not establish which results it sends. No `sysctl`/`uname` replacement was found
in the reviewed Steam engine adapters or `IPCSystemCompat.c`. The OS value may
also come from compiled platform assumptions. Neither "Valve sees a normal
Mac" nor "Valve definitely receives an iPad OS number" is established.

Three existing local connection logs contain successful logon results. Their
text does not expose the OS, machine-ID or binary-signature fields above. This
is not a packet capture and cannot establish their absence on the wire. Private
account identifiers and tokens have not been added to public documentation.

Valve's [privacy policy](https://store.steampowered.com/privacy_agreement/),
sections 3.4–3.6, describes device, OS, identifier, crash and IP data; section
3.8 describes violation-detection data whose details may be withheld. Section
5.4 distinguishes public profile information from game-developer access.
Those categories support possible visibility, not a finding that AgePad is
currently being detected or sanctioned.

**Result:** the integration is observable. The exact later telemetry and any
enforcement rule remain unknown. Not finding a hash in one request cannot
justify an account-safety promise.

## Round 3: what does successful verification mean?

| Check | What passing establishes | What it does not establish |
| --- | --- | --- |
| Import recipe's source hashes | Inputs match the pinned recipe. | Permission to adapt or run them. |
| Apple's app/library signing | The resulting package can satisfy the applicable local signing checks. | Valve/Feral approval or preservation of their original signatures. |
| Game's original-module file acceptance | Its read path sees accepted original SDK bytes. | That the bytes subsequently loaded are an untouched file. |
| AgePad's SDK hash gate | Original whole-file hash and adapted whole-file hash, or the device section-hash fallback, match its configuration. | Remote Steam attestation; the section fallback does not attest every load-command/signature byte. |
| Valve token / engine logon | The server accepts account authentication at that time. | Approval of this architecture or immunity from later restrictions. |
| Subscription check | The engine reports a genuine license, or a cached license offline. | Permission for the adapted platform integration. |
| Steamworks session tickets | A backend can verify identity and ownership through the documented ticket flow. | General attestation of the caller's executable or an iPad port permission. |

Sources: [SteamModuleCompat.m](../port/de/SteamModuleCompat.m), the sign-in and
engine sources above, and Valve's
[authentication guidance](https://partner.steamgames.com/doc/features/auth).
This review has not traced the game's complete session-ticket/backend flow.

The crucial local distinction is already experimentally established in
[DE-STATUS.md](DE-STATUS.md), experiments 277 and 278: the adapted SDK was
rejected before loading, while the original SDK passed file acceptance but
dyld rejected its macOS platform. AgePad consequently maps the read to original
bytes and loads the adapted copy. This is an integrity-related workaround;
the experiments alone do not identify the check as DRM or anti-cheat.

**Result:** login, ownership, local file acceptance and permission are separate.
More successful logins or gameplay sessions cannot establish the missing grant
or legal exception.

## Round 4: actual interoperability precedents

These decisions address particular laws, contracts and facts, rather than a
universal right to modify software or a prediction about Steam bans.

| Primary legal source | What it establishes and how AgePad differs |
| --- | --- |
| [Sony v. Connectix, 203 F.3d 596 (9th Cir. 2000), Copyright Office summary](https://www.copyright.gov/fair-use/summaries/sony-connectix-9thcir2000.pdf) | Necessary intermediate BIOS copying to develop an independent PlayStation emulator was fair use. The final emulator contained no infringing material. This supports some cross-platform interoperability without the original vendor's consent. It does not decide ongoing adaptation of proprietary Steam/game files or Steam service-contract access. |
| [Davidson & Associates v. Jung, 422 F.3d 630 (8th Cir. 2005), court opinion](https://ecf.ca8.uscourts.gov/opndir/05/09/043654P.pdf) | The bnetd project lost on contractual reverse-engineering restrictions and anti-circumvention claims. Its server admitted games without verifying valid, unique keys. AgePad's genuine license checks distinguish that feature, but do not dispose of the separate contract question. |
| [SAS Institute v. World Programming, C-406/10 (2012), official CJEU summary](https://curia.europa.eu/jcms/upload/docs/application/pdf/2012-05/cp120053en.pdf) | Functionality, language and data formats were not protected program expression, and lawful users had protected observation/study rights. The independent implementation did not copy source/object code. This is relevant to independently written adapters under EU law, rather than blanket authorization to adapt proprietary binaries everywhere. |

[U.S. section 1201(f)](https://www.copyright.gov/title17/92chap12.html) contains
conditional interoperability provisions. It does not automatically establish
that this complete port qualifies or that Steam must keep supplying service.
The current [Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/)
restricts relevant modifications and reverse engineering subject to exceptions.
Its application and any mandatory statutory exception require a separate,
jurisdiction-specific analysis of the actual architecture.

**Correction to an overbroad conclusion:** "all Steam modifications are
necessarily unlawful" is not established. "This integration is compliant
because it preserves instructions and checks ownership" is also not established.
There is a serious unresolved permission problem, rather than a demonstrated
AgePad ban precedent or a judicial decision about AgePad.

The game's [published Steam EULA link](https://store.steampowered.com/eula/813780_eula_0)
currently presents its Code of Conduct and incorporates Xbox Community
Standards. It supplies no porting or executable-adaptation grant. This review
has not established the complete governing license set for the supplied Mac
game; solving Steam integration alone would not close that separate question.

## Round 5: can the architecture remove the disputed changes?

Valve's [SDK overview](https://partner.steamgames.com/doc/sdk/api) documents
Windows, macOS and Linux library integration; no ordinary iPadOS SDK route was
found. Apple's [code-signing rules](https://support.apple.com/guide/security/app-code-signing-process-sec7c917bf14/web)
and the observed macOS platform rejection are practical obstacles to loading
the untouched Mac libraries inside a conventional iPad app.

| Candidate | Assessment against the goal |
| --- | --- |
| Keep today's native adapter, offline mode or existing Mac relay | Retains adapted Steam files. None meets a strict no-modification requirement. |
| Replace sign-in with documented OpenID | Supplies a SteamID for a website; does not replace client logon, game SDK IPC or session tickets. Not a drop-in repair. |
| Independently implement client/SDK interfaces | Could remove proprietary client-file adaptations, but does not by itself satisfy the game's original-module acceptance barrier. Protocol/service and game permissions would still need a basis. No working complete route demonstrated. |
| Build a genuine remote SDK bridge to an unchanged desktop client | Substantial new engineering. Different from today's relay; potential protocol-redirection and game-module concerns remain. No established compliant standalone solution. |
| Run unchanged Steam/game inside an independently implemented guest environment | Conceptually removes the need to retarget their files for the host loader. It changes the architecture to emulation, with unresolved licensing, graphics, memory and performance requirements. Not a proven playable iPad alternative. |
| Officially supported game build and Steam Link | A documented streaming arrangement, requiring a computer. Does not meet the standalone port goal. |

The guest-environment candidate should not be dismissed with an outdated claim
that Windows guest graphics are inherently impossible. UTM's July 2026
[Triton announcement](https://blog.getutm.app/2026/introducing-triton-directx-11-driver-for-qemu/)
demonstrates DirectX 11 in a Windows guest on macOS and describes an eventual
iOS port. That is progress on a related architecture, not an iPad result.
[UTM SE](https://docs.getutm.app/installation/ios/) uses slower interpretation
without JIT. Neither source establishes acceptable AoE II DE iPad performance.

**Decision gates for a further engineering pass:**

1. Fix the product constraints: native retail-Mac execution versus an independent
   guest environment; both must retain genuine ownership. Under the native
   retail-Mac design, the measured loader/file-acceptance conflict remains.
2. Identify an actual rights basis for every necessary proprietary adaptation
   and service interaction, including the game, or eliminate that adaptation.
   An independent legal analysis can assess exceptions without requesting
   written guidance from Valve/Feral/Microsoft. This report does not supply it.
3. For an independent interface candidate, demonstrate satisfying the original
   game/SDK boundary without an adapted Valve library, original-read/adapted-load
   substitution, forged ownership, or suppressed genuine verification results.
4. For a guest candidate, demonstrate unchanged files and playable performance
   on the target iPad before treating it as a replacement. No device experiment
   was performed in this research pass.
5. Measure later client/backend messages if exact visibility matters, with
   account data kept private. Such measurement could narrow telemetry claims;
   it cannot establish permission or future enforcement safety.

Abandoning today's architecture would be justified if the hard requirement is
no proprietary Steam-file adaptation and no alternative boundary can meet the
product constraints. Abandoning every possible standalone port is not justified
by the evidence so far. There is no demonstrated compliant native configuration
to ship today, and an empty incident history supplies no assurance.

## Scope and validation

Read current source, earlier project conversations and engineering records,
official policy/documentation, protocol definitions and the legal sources above.
Performed the offline request-construction probe and read existing connection
logs. No new login, packet capture, multiplayer run, device installation,
credential change or runtime modification was performed. Repository safety and
documentation checks verify publication hygiene, not rights or account safety.
