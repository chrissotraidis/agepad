# AgePad PRD: classic AoE II first, native iPad first

**Spec ID:** `agepad-v2-2026-09-06`.

**Revision: v2 — 6 September 2026.** Supersedes the previous AgePad PRD, goal loop, and input recommendations for execution planning. Status: **ready for private, gated implementation; no game build or device result validated by this revision**.
Audience: an autonomous coding agent in Chris's designated workspace on an Apple Silicon Mac.
Working name: **AgePad** (`agepad`), provisional and unofficial.
Companions: [AgePad-GOAL-LOOP.md](AgePad-GOAL-LOOP.md) and [AgePad-INPUTS-AND-VERSIONS.md](AgePad-INPUTS-AND-VERSIONS.md). When installing this set in a repository, copy the three files to `docs/PRD.md`, `docs/GOAL-LOOP.md`, and `docs/INPUTS-AND-VERSIONS.md` respectively, and adjust these sibling links. No older supplementary policy file is authoritative over this revision.

**Decision: GO for a bounded native-gameplay investigation that can grow into a complete classic/HD single-player product. iPad is the first product milestone; iPhone is the next committed Apple target. Android, multiplayer, and DE expansion remain separate follow-on branches, not prerequisites for a successful iPad single-player result. No public release is authorized.**

### What changed in v2

The central uncertainty is **engine completeness**, not an assumed inability to put a native RTS core on Apple mobile hardware. That is an engineering hypothesis, not a completed portability test. Establish real Mac gameplay, reproduce it in iPad Simulator immediately, then prove an original scenario and persistence. Preserve that result while completing the game. Do not spend the entire program comparing unfinished engines or chasing DE matchmaking.

This revision makes a complete, explicitly scoped classic/HD single-player game a legitimate product outcome. It does **not** lower that bar to a tutorial demo. It separates tablet and phone acceptance, makes Android/network/DE branches conditional, adds an early physical-device scout when access exists, and requires a missing-systems audit before expanding to full campaigns. Conversational probability estimates were subjective judgments, not measured forecasts; none are used as success criteria or planning guarantees.

The thirteen-section PRD structure and evidence discipline still follow the supplied SnapPad templates. Their N64 ROM/ELF, overlay, RSP, FlashRAM, controller, and timing assumptions do not transfer. [T1, T2]

## 1. Objective

Build an authentic native **Age of Empires II classic/HD single-player experience**: campaigns, useful AI skirmish, the declared ruleset, reliable saves, and an interface designed for iPad. Adapt the same proven core to iPhone with a separately tested phone interface. Keep portable boundaries so Android and networking can be added without making them immediate completion gates.

**First engine/data hypothesis:** `freeaoe` with a complete, unmodified **Windows Steam Age of Empires II HD/2013** installation, app `221380` (listed as “Retired” in the earlier source audit). Its inspected source contains an HD asset loader. Test the exact supplied installation; a loader and a README are not proof of complete gameplay. If a complete classic Age of Kings + The Conquerors installation is already available, test it as a separate R1 variant instead of waiting for an HD purchase. [S1, S3, S4]

**Preferred future content source:** **Windows Steam Age of Empires II: Definitive Edition**, app `813780`. Identify a supplied DE copy and run one bounded compatibility probe early when feasible. Do not require successful DE conversion, a DE purchase, or a complete DE engine before advancing the classic route. A fully working classic port would already satisfy the first product objective. [S2, S6, S7]

**Original-logic fallback:** a pinned classic Windows executable plus matching data may support static recompilation or selective reconstruction. Investigate this when the existing engine's gaps justify it, not simply because an EXE exists. A Mac ARM64 retail binary is not a ready-made mobile build; authorized DE source access would be a different starting condition. [S8, S10]

Delivery order:

1. **Inventory and pin.** Inspect only supplied inputs. Record edition, build confidence, data schema, language, expansions, modifications, and hashes. Unknown versions remain unknown.
2. **Choose a provisional route quickly from evidence.** Start R1 with the best available HD/classic input. Record DE intake and a bounded probe or a precise deferral. Audit other routes only to resolve a named uncertainty. Do not wait for every candidate to be built.
3. **Demonstrate native macOS BASIC-SLICE.** Map, selection, movement, gathering/dropoff, construction, training/research, combat, input, and required audio work through ordinary commands.
4. **Promote immediately to iPad Simulator.** Rebuild the same core/data/ruleset for the Simulator SDK, reproduce BASIC-SLICE with minimal RTS touch controls, and audit the device-SDK build. Do this before full campaigns or interface polish.
5. **Complete an authentic scenario and persistence.** Finish actual objectives and result/return flow on Mac and Simulator; separately prove a mid-scenario save/relaunch/resume and persistent campaign progress. Scout the same slice on a physical iPad when authorized access is available.
6. **Audit completeness, then finish the declared baseline.** Inventory missing AI, pathfinding, rules, triggers, UI flows, audio and save systems. Implement bounded missing work and test the named campaign/skirmish manifest. A successful tutorial does not prove a nearly complete game.
7. **Complete the iPad product.** Tablet-first touch, optional Pencil/pointer/keyboard, three-dot menu, import, settings, diagnostics, lifecycle, performance, clean reproduction, and exact physical acceptance.
8. **Adapt to iPhone.** Reuse the core; make and test a real phone layout. A good iPad result is not phone usability or performance proof. Continue authorized iPhone engineering after the iPad technical milestone rather than declaring the whole Apple request finished.
9. **Expand deliberately.** Android ARM64, same-project LAN/Internet, modern DE data/mechanics, and retail-client interoperability are separately enabled branches. Preserve the working classic product and test identities.

Three hard requirements:

- **Native execution is real.** Compile the game core ahead of time for the target. Wine/CrossOver, streaming, browser wrapping, guest-CPU interpretation, or dynamic Windows translation cannot satisfy native deliverable gates. A reference run can use another environment, labeled reference-only. Feral's retail Mac app is not AgePad's host proof.
- **Claims are separate.** Asset import, game rules, campaign coverage, saves, platform behavior and N0–N4 multiplayer each get their own status. ARM64 architecture, same-code compilation, or a successful converter does not collapse these distinctions.
- **Product scope cannot shrink silently.** A map viewer, one tutorial, a custom RTS with AoE graphics, or an AoE I experiment is not the complete AoE II baseline. Such results can be useful milestones without being a finished product.

## 2. What “done” means

Separate four outcomes: **basic native portability**, **an end-to-end feasibility slice**, **a complete single-player product**, and **optional expansion compatibility**. A bounded route investigation may also end in a precise blocked/parked report. That does not mean the product is done or native AoE is impossible.

### 2.1 Acceptance definitions

| ID | Requirement | Evidence required |
|---|---|---|
| D1 | Environment and inputs identified | Actual toolchain/authority; pinned sources; safe input inventory and hashes; separate edition/build confidence; missing inputs stated |
| D2 | Provisional route and scope selected | R1 probe evidence; all supplied inputs accounted for; DE probe result or explicit nonblocking deferral; named baseline; active route/data/ruleset; missing-systems ledger |
| D3 | Native macOS BASIC-SLICE | ARM64 architecture, linkage and process audit; ordinary commands demonstrate all basic mechanics with logs and interaction evidence |
| D4 | Early iPad Simulator BASIC-SLICE | Same core/data/ruleset rebuilt for Simulator; minimal touch path; actual economy/combat; successful device-SDK compile/link audit recorded separately |
| D5 | Original scenario and meaningful persistence | Actual objectives and result/return flow; mid-scenario save, exit, load, continued state; completion/progress persistence on Mac and iPad Simulator |
| D6 | Complete named classic/HD baseline | Declared fresh campaign progression; complete useful AI skirmish; required rules, units, technologies, pathfinding, triggers, audio, saves and regression coverage; no baseline subsystem hidden as a stub |
| D7 | iPad product shell and interaction | Every mandatory action usable by touch alone; optional Pencil/pointer/keyboard; three-dot menu, safe import, settings, diagnostics, lifecycle and accessible tablet layout |
| D8 | iPhone adaptation | Same proven core, separately sized phone UI and gesture rules; scenario/persistence on iPhone Simulator; all mandatory actions accessible without an external input device |
| D9 | Enabled extension acceptance | Apply only to explicitly enabled Android, N1–N4 or DE branches; use their own complete proofs. Deferred branches do not block D1–D8/D10 for the Apple baseline |
| D10 | Reproducibility and stability for the named profile | All applicable technical matrix rows on exact candidates; clean-clone scripts, regressions, measured budgets and 60-minute soaks; platform scope explicit |
| D11 | Physical acceptance per claimed mobile platform | Authorized tester uses exact candidate; device/OS/artifact identity, actual input, sustained performance, audio, lifecycle, persistence and observed failures recorded |
| D12 | Authorized publication of a named candidate | Separate source/binary rights decisions, audits, notices, exact-artifact acceptance and Chris's explicit approval; no automatic upload |

### 2.2 Product profiles and completion semantics

The **default intended Apple scope** remains iPad **and** iPhone (`apple-singleplayer`). The first independently meaningful milestone is `ipad-singleplayer`. Scope profiles prevent unfinished extensions from blocking an already valid result; they do not permit omitting iPhone while calling the complete Apple program finished.

| Profile or milestone | Required technical evidence | Physical/public boundary |
|---|---|---|
| `basic-portability` | D1–D4 | Proves only the tested Mac/Simulator slice and device build, not on-device gameplay |
| `scenario-feasibility` | D1–D5 | Proves the named end-to-end slice, not full campaigns/AI or physical performance |
| `ipad-singleplayer` | D1–D7 + D10 for Mac/iPad; D8 and D9 not prerequisites | D11 on iPad + D12 for any public iPad binary |
| `apple-singleplayer` | D1–D8 + D10 for Mac/iPad/iPhone | D11 on iPad and iPhone + D12 for claimed public binaries |
| `android-singleplayer` extension | Shared D1–D6, equivalent Android shell, D9 Android tests + D10 for Android | D11 on Android + D12; not an iPad prerequisite |
| Network or DE extension | Baseline dependency plus D9 for the specifically enabled tier/subset | Exact extension claims require their own applicable technical/physical/rights acceptance |

An iPad-only private milestone or explicitly approved iPad-only release may precede the phone branch. Report unfinished iPhone work as such. Do not say “all platforms,” “full DE,” or “online with Steam players” because a narrower profile passed.

For the runner: work through the first iPad technical profile, then the iPhone technical profile within the authorized run. If physical hardware is available earlier, perform the diagnostic scout in Section 8.3. Lack of hardware blocks physical acceptance, not independent authorized code/testing work. A release handoff is never implicit approval to publish.

### 2.3 Baseline content scope

The first product targets the original **Age of Kings + The Conquerors single-player content/ruleset family**, using a verified compatible HD/classic installation. HD is a data-source hypothesis, not a promise of every HD-era rule, expansion, save format or multiplayer feature. The earlier source audit records that HD supplies the original campaigns. [S1]

Before D2, start `docs/CONTENT-SCOPE.md`: actual edition/build, named campaigns/scenarios, civilizations, units/technologies, skirmish settings, AI expectations, ruleset, language and exclusions. Refine identification from supplied data, then freeze the intended baseline before D6 work. Distinguish **HD data with a classic-compatible ruleset** from **HD gameplay equivalence**. Do not imply exact retail behavior where a reimplementation differs.

A single tutorial is an early feasibility target only. Full D6 acceptance requires the declared campaign progression and useful skirmish experience. Reducing that consumer scope requires Chris's explicit decision; changing the engine or silently skipping a difficult campaign cannot make D6 pass.

A future DE-derived classic subset must say which DE build, content and rules it represents. DE conversion, a full DE ruleset, original DE saves, and DE services are different workstreams. Newly installed DLC/mods or changed data create new test identities. Completion of the classic product does not guarantee easy DE compatibility.

### 2.4 Non-goals and deferred work

Not part of the initial single-player acceptance: Android, N1–N4 networking, full DE support, optional HD/DE expansions, every historical patch, Workshop compatibility, proprietary save/replay import, graphical enhancement packs, or arbitrary simulation-speed changes. Preserve these as named branches; do not discard them or claim them tested.

Not authorized by this document: purchases, public pushes/releases, store submission, TestFlight/notarization, paid infrastructure, broad account changes, publisher contact, leaked source, cracks, authentication/DRM bypass, or unlicensed redistribution. Do not build a general Windows emulator or unlimited recompiler before a bounded AoE-specific path. Do not copy N64 controls or game-specific PaperPad patches into an RTS.

## 3. Why this is worth testing — and what remains unproven

### 3.1 Source findings carried forward from the earlier 6 September 2026 audit

| Finding | What it establishes | What it does not establish |
|---|---|---|
| The earlier audit recorded the 2013/HD Steam product under “Retired,” with a purchase option and no further updates. [S1] | A previously identified retail acquisition lead. | Current availability in every region/account, or compatibility of the supplied installation; recheck before purchase. |
| freeaoe documents HD support and basic gameplay; its HD loader indexes the `resources/_common` tree. [S3, S4] | A concrete HD-aware code path is worth reproducing. | Successful current macOS/mobile builds, complete campaigns, or retail multiplayer. |
| freeaoe's build enables fast floating-point math. [S5] | A specific determinism-risk setting must be audited. | That it actually causes a desync, or that removing it alone creates determinism. |
| openage supports a broad original/DE asset-conversion ambition while warning about incomplete gameplay. [S6] | A credible DE conversion and engine audit route. | A finished DE replacement or any particular new patch working. |
| openage's detector can recognize an edition's required files while failing to recognize the exact file hash. [S7] | Edition recognition and exact-version verification must be separated. | A detected edition is a verified supported build. |
| M-HT/SR supports static recompilation of selected legacy games, including Windows titles. [S8] | A precedent for a game-specific AOT approach. | A ready-made AoE recompiler, iOS pipeline, or universal EXE converter. |
| The original AoE/Rise of Rome reconstruction project documents partial gameplay and macOS support. [S9] | An optional first-game investigation has an existing foundation. | Complete AoE I gameplay, or any AoE II compatibility. |
| Feral shipped a native Apple-silicon Mac DE release; the official FAQ documents Mac-only multiplayer. [S10, S11] | Native ARM feasibility and a separate Mac reference implementation. | Public source availability, transferable mobile rights, or Windows/Mac DE cross-play. |

### 3.2 Unproven execution claims and feasibility judgment

**This is a revision of the supplied planning documents and the subsequent discussion, not a new engine build or new external research audit.** No game copy was inspected, extracted, hashed or run during this revision. No macOS, Simulator, device or performance test was executed. The earlier session reported unavailable Drive access; that is historical evidence, not a statement about a future runner's current connections. Recheck actual authorized access when execution starts.

The source findings above remain leads, not passes. The revised engineering judgment is:

| Question | Working judgment | What would materially change it |
|---|---|---|
| Can a correctly functioning native core be adapted to iPad? | Worth pursuing; platform integration appears more bounded than recreating missing game logic. No device guarantee. | Same BASIC-SLICE on Mac/Simulator, device-SDK audit, then physical scout |
| Can a useful classic/HD game be completed through the chosen public engine? | Plausible but materially less certain; missing AI, rules, triggers or saves may dominate the effort. | Authentic scenario + save/reload, followed by the subsystem gap audit and representative harder content |
| Can the same product work well on iPhone? | Shared-core reuse is plausible; phone usability, memory and sustained performance are separately unproven. | Phone-specific commands/UI plus exact physical scenario and stress tests |
| Does classic success make DE straightforward? | No. Tooling and platform work may transfer; engine semantics, schemas and service integration may not. | Explicit DE subset mapping/gameplay and a separate full-engine/fidelity audit |
| Will commercial DE online work? | Unproven, higher-risk, and not a baseline requirement. | Legitimate exact-ecosystem interoperability, including an actual mixed-client match |

Do not convert the earlier conversational success percentages into forecasts, schedules, “expected pass” values or evidence. No calibrated success model exists here. Likewise, completing one tutorial settles only that tutorial-sized feasibility question; it does not establish all campaigns, acceptable physical performance or low remaining effort.

### 3.3 The core decision: porting work versus missing-game work

After the first desktop probe, and again immediately after D5, write a concrete **engine-completeness audit**. For each subsystem, record source location, status (`source-only`, `observed-working`, `partial`, `absent`, `unknown`), observed tests, failure class, smallest next proof, and the bounded work needed. Use at least: asset import; unit commands; economy; buildings/production; combat; pathfinding/formations; AI; technologies/civilization rules; scenario scripting; random maps; campaign progression; saves; audio/rendering; mobile shell; optional networking.

Classify defects as `PLATFORM`, `ENGINE`, `DATA`, `HARNESS`, `INPUT/ACCESS`, or `RIGHTS/RELEASE`. A broken file-picker path is not evidence the simulation needs replacing. A missing AI interpreter is not an iPad packaging defect. A faulty harness is not a reason to rewrite a working engine.

If remaining work is a list of bounded compatibility fixes or missing features with understood semantics, continue the winner. If most essential gameplay systems must be invented or reconstructed, explicitly reclassify the route as **engine development**, compare R1 repair against R4 original-logic reconstruction, and document the scope/budget implication. Do not silently expand into an unlimited rewrite, and do not treat one failed candidate as proof of impossibility.

### 3.4 Build value and product value

**Build value:** portable RTS integration, a verified importer, repeatable gameplay tests, and potentially reusable original-logic tooling. **First product value:** an authentic classic AoE II single-player game that is actually usable on iPad, followed by iPhone. Good tablet fit is a design hypothesis to test, not a measured UX finding. Public reach is not guaranteed.

A complete classic/HD iPad product is success even if DE or multiplayer never becomes viable. It is not success to disguise a partial tutorial as that product. Existing Apple shell experience may reduce integration effort; it does not supply Genie simulation, finish missing game systems, or prove future Android/network/DE compatibility.

## 4. Environment and workspace

Use a new, isolated AgePad integration workspace unless Chris has supplied an existing one. Inspect current work before changing anything. Verify the installed Xcode, command-line tools, macOS SDK, iOS Simulator/device SDKs, CMake, Ninja, Git, Python, and compiler versions; record exact versions rather than assuming “latest.” Install missing dependencies only within the machine authority Chris has granted. Do not silently switch the global Xcode selection or upgrade an existing project toolchain.

When the Android branch is enabled, verify a compatible JDK, Gradle, Android SDK/NDK, CMake integration, and an ARM64 emulator or authorized device. Do not install the Android stack as a prerequisite for the first iPad result. Android C/C++ builds need the NDK ABI, not an Apple ARM64 library reused under another filename. [S14]

```text
agepad/
  docs/
    PRD.md, GOAL-LOOP.md, INPUTS-AND-VERSIONS.md
    STATUS.md, JOURNAL.md, ROUTES.md, CONTENT-SCOPE.md, ENGINE-GAPS.md
    INPUTS.md, PLATFORM-MATRIX.md, ENGINE-MAP.md, DETERMINISM.md
    SAVE-AND-LIFECYCLE.md, NETWORK.md, PERF.md, RIGHTS-STATUS.md
    RELEASE-READINESS.md           source register is included below; SOURCES.md optional
    artifacts/                    local, ignored evidence by date/run ID
  ref/                            ignored; read-only pinned reference sources
    paperpad/, freeaoe/, openage/, sr/, aoe1/
    inputs/originals/              immutable originals, or read-only external refs
  worktrees/                      ignored isolated candidate modifications
  generated/                      ignored conversions, AOT, builds, caches
  private/                        ignored manifests, test saves, local paths
  config/                         non-secret schemas and experiment policies
  port/
    core/, assets/, apple/, android/, renderer/, network/, patches/
  scripts/                        deterministic setup/build/test/audit tools
  tests/                          original synthetic fixtures and harness code
  dependencies.lock.json
```

Hard rules:

- Never modify the originals or the user's live Steam installation. Copy a pinned snapshot to the ignored workspace; verify copies and detect partial cloud sync.
- Do not scan unrelated personal storage. Start from supplied roots. Do not ingest entire Drive/account contents to locate one game.
- Reference checkouts are pinned and push-disabled. Changes belong in isolated working trees or reviewed patches, never the reference checkout.
- Keep binaries, original assets, converted assets, generated proprietary AOT, saves, memory dumps, credentials, and private paths out of commits and exported diagnostics.
- Never run `git clean -fdx`, blanket `rm -rf`, destructive resets, or cleanup that erases ignored inputs/evidence. Preserve unknown local edits.
- One active mutable candidate and one ordinary game instance. One Simulator at a time. A deliberate two-peer multiplayer test is the only process-count exception; see the loop.
- No autonomous public push, tag, package upload, game purchase, paid provisioning, publisher contact, or Internet service deployment.

The runner may perform reversible private engineering when Chris launches it in the designated workspace. It must record its actual permissions. This document is not legal permission from a third-party rights holder, and its creation does not mean a bot is currently executing.

## 5. Inputs and repositories

### 5.1 Edition acquisition and initial testing order

| Priority | Supply | Role | Initial route |
|---|---|---|---|
| First gameplay hypothesis | Complete Windows Steam **HD/2013**, app `221380`, preferably an unmodified English baseline | Concrete existing HD-aware loader plus partial engine to test | R1 HD |
| Equally usable to begin inventory; alternate first gameplay input when already owned | Complete original **Age of Kings + The Conquerors** install with matching EXE/data | Classic R1 variant; fidelity fallback if reconstruction is justified | R1 classic, then conditional R4 |
| Second input when available, not required to start | Complete standard Windows Steam **Definitive Edition**, app `813780`, separate from HD | Preferred future modern-data target; bounded intake/schema/conversion probe | DE0/DE1 through R2; later R3 only with evidence |
| Optional existing reference | Mac DE install | Retail reference and separately scoped layout/dependency audit; not AgePad host proof | R6 only with a specific premise |
| Optional different-game experiment | Original AoE + Rise of Rome | Separate AoE I fallback, not the AoE II baseline | R5 |

**A single appropriate existing copy is enough to start.** Do not require Chris to obtain the full comparison set before source/build/input work. With only DE supplied, perform its bounded probe and source/synthetic work, then report the precise missing gameplay input if needed; never pretend DE is a valid R1 HD input. An installer or disc image is enough to investigate identity, not necessarily enough to run the game.

Use the complete installed directory, not a lone EXE. Preserve game data, archives, campaigns/scenarios, audio, localization, relative paths and matching executable when present. Optional private Steam `appmanifest_*.acf` metadata can identify app/build/depot details; hashes are still required. No account credentials or entire Steam configuration directory is needed.

Prefer unmodified English data for the first test only to reduce variables; other language copies may be inventoried and assessed rather than rejected automatically. Record all already-installed DLC/mods. Do not mix files or delete expansions to force a parser version. No optional Enhanced Graphics Pack, new DLC or additional game purchase is required by the initial experiment. “Standard DE install” does not imply the original 2019 schema. [S2]

The earlier source audit recorded the Steam product names and availability. This editing pass does not reverify a storefront or authorize a purchase. Recheck legitimate availability for Chris's account/region before any acquisition recommendation is acted on. [S1, S2]

### 5.2 Safe identification protocol

1. Enumerate only the designated inputs. Record source label, file type, size, and whether a cloud file is fully materialized. Treat archive names such as “Gold,” “HD,” or “Definitive” as hints.
2. Hash originals and record SHA-256. For very large directory inputs, inventory first, then produce a deterministic sorted file-hash manifest for the selected snapshot. Do not hash a still-changing live install and call it stable.
3. Inspect magic bytes/container metadata; list archives before extraction. Enforce expanded-size/file-count limits, available-space checks, no absolute/parent-traversal paths, no escaping symlinks, and deterministic case-collision handling. Mount disc images read-only. Never launch bundled executables just to identify a version.
4. Extract/copy into an ignored staging directory. Find the actual installation root; distinguish an installer, an installation, a backup package, a partial download, and an asset-only export.
5. Combine executable product/version headers and architecture, installation layout, data-format headers, expansion indicators, language assets, Steam metadata where present, and known upstream detector matches. Keep raw data-header evidence private.
6. Record **edition confidence** and **exact revision confidence** separately. An unknown hash may still permit a limited parser probe, but not “known compatible” status. Never overwrite headers or suppress parser errors to force a match.
7. Validate representative terrain, sprites/animation, palettes, audio, UI/text, DAT units/technologies, and one scenario. Log missing fields/IDs and unsupported formats precisely. Run negative tests using original synthetic malformed/truncated inputs.
8. Freeze an `input_set_id`, content-manifest hash, and intended ruleset. Every test/cache/save/network handshake uses that identity. Any executable, DAT, mod, localization, or DLC change invalidates affected compatibility evidence.

For reimplementation routes, a game executable may be useful for identification/reference but is not necessarily a runtime input. For AOT, the **exact executable and matching data** are build inputs: supporting a different EXE revision may require a new generated and signed application. Mobile import must not quietly invoke a JIT or download executable code.

### 5.3 Required input record

Create a machine-readable manifest with at least:

```json
{
  "input_set_id": "assigned-after-inspection",
  "edition": "unknown",
  "edition_confidence": "uninspected",
  "exact_revision": null,
  "exact_revision_confidence": "uninspected",
  "source_platform": "unknown",
  "steam_app_id": null,
  "steam_build_id": null,
  "language": null,
  "expansions": [],
  "mods": [],
  "original_sha256": null,
  "content_manifest_sha256": null,
  "executable_sha256": null,
  "data_schema": null,
  "ruleset_id": null,
  "compatibility": "unverified",
  "inspection_evidence": []
}
```

Local absolute paths live in ignored configuration, not public manifests. Unknown/null values are deliberate; never invent expected hashes from the SnapPad template.

### 5.4 Starting reference pins

| Reference | Starting revision/state | Purpose |
|---|---|---|
| `sandsmark/freeaoe` | `f5e46da59761868aa1814037f712f277c71b5bb3` | Source-inspected candidate for HD/classic gameplay |
| `SFTtech/openage` | `9a5a7ccbfc20c2de658fc746462cd4a69aa758ef` | Version-detection/conversion audit and alternate engine |
| `chrissotraidis/paperpad` | `74b6e45830a06c7f274c5ac1ddd7c625bc13a557` | Template-linked Apple shell and engineering-process reference |
| `M-HT/SR` | Resolve an exact revision before a probe | Legacy Windows static-recompilation precedent, not AoE support |
| `FolkertVanVerseveld/aoe` | Resolve an exact revision before a probe | Optional original-AoE reconstruction |
| SFML, genieutils, SDL, Qt, codecs and other transitive inputs | Resolve from each candidate's actual dependency graph, then pin | No unspecified “latest” dependencies |

These pins establish inspectable starting points, not known-good builds. Record recursive submodules, licenses, patches, compiler/SDK, build options, and hashes in a new AgePad lockfile. Do not confuse a Git blob hash with a repository commit. Update one dependency at a time, only with a stated reason and repeated tests.

### 5.5 Reference code to read first

For freeaoe, read `README.md`, `CMakeLists.txt`, `.gitmodules`, `src/resource/AssetManager_HD.h`, the actual classic asset manager, data/version selection, scenario/trigger implementation, unit actions, AI code, and persistence/network code if present. Locate remaining paths from the pinned tree instead of inventing filenames. Establish whether save/load and networking exist at all.

For openage, read the README, current converter entry points, `openage/convert/service/init/version_detect.py`, edition/expansion configuration, the chosen DE data parser, renderer/GUI requirements, runtime dependencies, and gameplay status. Its converter's output is an openage representation, not automatically a freeaoe-compatible package. [S6, S7]

For PaperPad, read its README, architecture, build/dependency/testing documents, lockfile, release/safety scripts, `apple/app/ios_main.mm`, `apple/app/diagnostics.mm`, `apple/app/rom_setup.mm`, and relevant tests at the pin. Reuse mechanisms only. In particular, do not inherit its N64 runtime, ROM size/hash, SDL version assumptions, controller-only command model, or game-specific shutdown workaround. [S12]

## 6. Phase 0 gate: reproducibility, rights state, and route selection

### 6.1 Initial state

Create the journals, input inventory, route register, source lock, safety ignores, and executable safety checks before generating game data. `RIGHTS-STATUS.md` begins as **private-only; publication not approved; third-party rights under review**. A missing public-release decision does not stop ordinary authorized local engineering. A genuinely unavailable or unauthorized required input does stop that input-dependent route.

The original Drive copies are **uninspected**, not “absent.” The earlier session’s access limitation must not be treated as permanent. Check the runner’s actual authorized tools and supplied paths. With a connected Drive tool, list the specified folder, verify access and inspect only the approved game inputs. Without access, record the limitation once, continue independent source/synthetic-fixture work, and issue a precise input handoff. Do not search unrelated accounts or substitute guessed file contents.

### 6.2 Route portfolio: one winner, bounded alternatives

| Route | Mechanism | First falsifiable experiment | Promote when | Park or re-scope when |
|---|---|---|---|---|
| R1 | freeaoe + exact HD data; classic AoC as a separate variant | Build pinned host code, import matching set and execute BASIC-SLICE | Real economy/combat works and a specific mobile path exists; then test iPad immediately | Important omissions cannot be bounded, or supplied data cannot be supported after diagnosis |
| R2 | openage conversion / alternate native engine | Identify supplied DE schema; inspect/convert representative media and gameplay records | A converter passes its own gate; engine promotion additionally needs real gameplay | Converting data is becoming a substitute for a missing simulation |
| R3 | Explicit DE subset adapter for the proven core | Map one declared DE content subset without silently discarding required semantics | Mappings plus ordinary gameplay pass on the stated ruleset | Renamed formats, dropped triggers or ignored mechanics create false DE support |
| R4 | Classic Windows AOT plus selective reconstruction | Audit exact EXE and execute a bounded translated original-logic path | Correct native behavior and a bounded path toward BASIC-SLICE; no CPU fallback | Unbounded generic translation/API work replaces an AoE-specific experiment |
| R5 | Original AoE/Rise of Rome reconstruction | Build and test its own host gameplay | Useful separately labeled first-game result | Used to mark AoE II goals complete |
| R6 | Authorized DE source port or narrow Mac-binary audit | Verify actual source rights/buildability, or an explicitly scoped dependency/rehosting premise | Authorized reproducible source build or real bounded rehosting result | Only the retail Mac app runs, or the plan assumes relabeling ARM64 makes an iPad app |

**Default:** R1 with the best appropriate supplied input. Inventory DE early (DE0); schedule at most one initial DE conversion/schema probe round (DE1) when input and tools are available. A blocker becomes a documented deferral, not a precondition for R1's G3–G6. R2's entire engine does not have to build just to complete a small parser audit. Conversely, source inspection alone does not count as a conversion run.

Classic executable intake does not automatically activate R4. Activate a bounded R4 audit when R1's observed gaps suggest preserving original logic may be a better route, or when no viable R1 data path exists. R3 waits for both meaningful DE evidence and a core worth adapting. R5 and R6 require a concrete separate rationale. Do not build all six routes before choosing one.

D2 is **provisional**, not a global competition that every engine must finish. It records available/unavailable inputs, the first winner, known gaps, the bounded DE outcome or deferral, and why any fallback is or is not active. Reopen it when new evidence changes the premise; do not restart merely because another repository looks interesting.

### 6.3 Bounded experimentation policy

These are engineering resource controls, not promises of completion time:

- A probe round has at most **six evidence-producing steps per route/input pair**. A step is one hypothesis, bounded change, and repeatable test; an endless command is not one step.
- No identical failing command a third time without changed evidence. After two matching failures, use the unblocking ladder.
- After three distinct unsuccessful remedies to one causal blocker, reassess it using the ladder. After two probe rounds without reaching a new rung or materially reducing the blocker, park that pair with a reproducer.
- A new round requires a concrete changed premise: corrected input, new source/dependency evidence, a smaller supported path, or a successful isolating experiment. “Try harder” is not a changed premise.
- Preserve the best verified route. Parked candidates remain available when new evidence arrives, but cannot erase a working baseline or consume unlimited effort.
- Missing inputs or physical hardware are dependencies, not failures. Independent synthetic tests, dependency audits, and documentation may continue without marking the blocked gate complete.

Route states: `uninspected`, `identified`, `import-only`, `host-build`, `host-boot`, `host-slice`, `simulator-slice`, `scenario-complete`, `baseline-complete`, `blocked`, `parked`. Record capability flags and per-platform/extension states separately; no synthetic overall completion percentage. Physical evidence never follows automatically from a route state.

D2 selects a **provisional active route**, based on observed gameplay, attainable inputs, mobile integration and missing-system scope. Preserve the winner. A successful Mac BASIC-SLICE should trigger Simulator work, not another broad repository comparison. DE preference cannot stall classic progress or justify mislabeling incomplete DE.

Record these execution defaults in `STATUS.md` (declarative policy to implement, not an existing runner):

```json
{
  "spec_revision": "agepad-v2-2026-09-06",
  "target_profile": "apple-singleplayer",
  "first_milestone": "ipad-singleplayer",
  "active_route": null,
  "input_set_id": null,
  "ruleset_id": null,
  "enabled_extensions": [],
  "de_intake": "uninspected",
  "de_probe": "unrun-or-deferred-with-reason",
  "physical_ipad": "unrun",
  "physical_iphone": "unrun",
  "publication_authorized": false
}
```

Enabling an optional branch means an explicit recorded work decision within the actual machine authority, not an automatic reaction to its mention in this document. Finish the first iPad profile and the intended iPhone adaptation before spending open-ended effort on extensions. Small non-disruptive input/source audits remain allowed. If required inputs are absent, independently testable setup work may proceed without pretending D1 is fully met.

## 7. Phase 1 gates: engine, assets, execution model, and correctness

### 7.1 Shared core and platform boundaries

Keep the selected engine's simulation separate from platform services. Introduce the smallest adapters necessary; do not require a wholesale engine rewrite before the first build.

```text
Read-only identified game input
          |
  validated edition-specific importer / desktop converter
          |
 versioned content manifest + explicit ruleset
          |
   native simulation core <---- ordered ordinary player commands
          |
  render snapshot / audio events / serialized saves / command stream
          |
  macOS | iOS Simulator | iPad/iPhone device | Android ARM64
```

Recommended interfaces are `AssetProvider`, `CommandQueue`, `SimulationClock`, `RenderSnapshot`, `AudioSink`, `SaveStore`, and `NetworkTransport`. They are design boundaries, not claims these APIs already exist. Expose stable entity IDs, not platform pointers, in commands, persistence, or network messages. Log route/data/ruleset identity at boot.

AOT is an alternative way of producing the core; it does not remove platform-service work. Native code may retain emulated guest memory semantics while being compiled ahead of time. The requirement is no runtime guest-CPU interpretation/translation, not a claim that every internal representation is identical to a modern source port.

### 7.2 Asset and data conversion

Validate media and gameplay separately. A map-render screenshot cannot pass unit/technology parsing. Build a format inventory from actual files: DAT schemas, DRS or directory layouts, sprite/animation formats, palettes, terrain/blending, sound/music codecs, language/UI resources, campaigns/scenarios, and scripts. Decode by the actual edition and version.

Each unsupported field/ID must be `implemented`, `explicitly out-of-scope`, or `blocking`. Preserve source-to-internal mappings and transformation versions. Never silently treat DE records as classic structures, truncate unknown tables, replace critical graphics with placeholders, or discard triggers to load a map. A subset converter must state exactly which content it can represent.

Use desktop preparation when that reduces mobile dependencies, provided importing user-owned data remains repeatable. Desktop conversion is acceptable; requiring an undisclosed proprietary asset download is not. A mobile asset package may contain only the user's local converted data and manifest, not generated executable code. Keep import cancellation, failed imports, low storage, and interrupted copy recovery transactional.

### 7.3 R1: freeaoe first-build discipline

First reproduce the unmodified pinned host build using an actually compatible SFML/API dependency set. The old build warning and generic SFML mobile support are neither proof of failure nor proof of success. Avoid automatically selecting SFML 3 for source written for older APIs; resolve and test the dependency graph. [S3, S13]

Record compiler errors by subsystem. Fix bounded toolchain/platform issues in a small patch series. Identify engine-level omissions separately. Audit unsafe `-ffast-math` and `/fp:fast` assumptions before determinism claims: retain the original flags in the reference record, create an explicit strict-simulation build configuration, and compare behavior rather than silently changing the baseline. [S5]

An HD file lookup is not complete edition support. Verify terrain, expansion overrides, language paths, UI resources, scenarios, and error handling for the exact supplied installation. The inspected loader uses `resources/_common` and numbered assets; preserve identity and avoid accidental cross-edition overrides. [S4]

### 7.4 Renderer and audio routes

**Start with the selected engine's existing host renderer** to establish gameplay. Then test the smallest mobile-compatible path. SFML's documented mobile support is limited; each graphics feature and dependency must survive the actual Simulator and device SDK builds. [S13]

If the existing renderer cannot cross the mobile gate with bounded fixes, choose a clearly recorded alternative: a 2D sprite/terrain renderer behind SDL with a Metal backend on Apple, a direct Metal renderer, or a proven compatible graphics abstraction. For openage, separately audit its OpenGL/Qt assumptions and whether the GUI/render layer can be isolated. Do not claim SDL automatically runs another engine's OpenGL renderer, or that RT64 understands Genie-engine rendering.

Preserve draw ordering, terrain seams/blending, unit orientation/animation, shadows, palette/player colors, selection outlines, fog of war, minimap mapping, text, and hit testing. Compare against reference captures; batch work only after correctness. Audio must cover ambient/world events, UI, unit acknowledgments, combat, music, campaign narration, and interruption behavior. Record codec licenses and file handling.

Metal remains the intended Apple production graphics path, directly or through an explicitly audited compatible abstraction. A working native temporary renderer may satisfy a labeled early slice but cannot silently replace the declared production path. Do not rewrite rendering before a concrete feature/dependency test proves it necessary. Choose and test the Android backend only when that branch is enabled.

### 7.5 R4: classic executable AOT/reconstruction audit

Use a fixed, legitimately supplied Windows executable and matching data. Do not assume HD or DE is easier merely because it is newer. Inventory architecture, PE sections, relocations, entry points, imported DLLs/APIs, calling conventions, callbacks, exception behavior, threads, executable-memory writes, indirect targets, and dynamically loaded code. Classify resources separately from executable bytes.

M-HT/SR is a precedent to inspect, not an AoE toolchain selected by name. Evaluate whether its supported translation path can represent the chosen executable; otherwise document another concrete lifting/reconstruction mechanism before generating large outputs. N64Recomp and console-specific recompiler configurations from other projects are not generic x86 tools. [S8]

The smallest meaningful result is one real original-logic path translated and linked against native replacements, with observable behavior compared against a legitimate reference. Expand toward the same gameplay slice. Audit x87/SSE precision, integer overflow, pointer sizes, host/guest address translation, timing, callback lifetimes, and API behavior as applicable to the observed binary.

Create `docs/EXECUTABLE-MODEL.md`: every needed native replacement, unsupported operation, indirect-target incident, translation warning, and code-generation identity. A failed indirect call is a metadata/translation incident to understand, not a return-zero stub. No hidden Wine dependency, interpreter fallback, unrestricted JIT, or downloaded executable plugin may rescue a supposedly native gate. Script interpreters for ordinary AI/scenario data are not guest-CPU interpreters and are not automatically prohibited; audit their actual behavior and distribution separately.

### 7.6 Simulation, AI, triggers, and deterministic testing

Establish the actual simulation cadence and speed settings from the selected ruleset/reference. Do not import Pokémon Snap's frame assumptions or pick an AoE tick rate from memory. Rendering cadence may differ from simulation cadence; changing renderer performance must not change build times, movement, combat, research, or trigger timing.

Add read-only observability and a command-injection harness that uses the ordinary game command path. Record a fixed scenario/seed plus ordered commands. Assert resource conservation and expected costs; entity ownership/creation/destruction; construction/training/research completion; path reachability; attack/cooldown outcomes; fog visibility; scenario objectives; and victory/defeat transitions.

For the **same engine**, canonicalize a state digest excluding pointers, unordered serialization, wall-clock values, and purely visual effects. Compare repeated runs and active Apple platform builds. Diagnose semantic differences before accepting a regression; bit-identical cross-platform lockstep is mandatory only for a branch that actually claims that model. A documented, bounded non-gameplay numerical difference is not by itself a reason to block offline single-player. Never hide a difference in AI, economy, combat, progression or save state as “just floating point.” For **different engines/original retail references**, compare defined semantic outcomes and documented tolerances; raw state hashes are not comparable unless representations and semantics actually match.

Test AI with economic growth, age advancement, scouting, military production, attack/defense, recovery, and ability to finish a match—not a unit that merely retaliates. Test pathfinding around choke points, moving blockers, buildings, shorelines, groups, and unreachable targets. Maintain explicit feature coverage for formations, garrisoning, transports, conversions, projectiles, technologies, civilization bonuses, and scenario triggers required by the baseline content.

Test automation must not directly grant resources, force objective flags, overwrite unit state, teleport past pathfinding, or invoke a test-only victory setter to claim end-to-end acceptance. Synthetic unit tests may set initial state, but those results stay labeled synthetic.

### 7.7 Saves and persistence

Discover whether the chosen engine implements saves. Scenario/campaign loading is not saved-game support. Missing save serialization is a real engineering gap, not a mobile packaging detail.

Use a versioned save format with edition/input/ruleset/engine compatibility identifiers. Preserve resources, entity IDs and orders, build/research queues, AI state, RNG, timers, triggers, campaign progression, and required world state. Never serialize live host pointers or write into the original game installation. Use atomic replacement, validation, backup/recovery, and distinct save namespaces for every route/test profile.

Test fresh saves, mid-construction, mid-combat, queued research, scenario completion, relaunch, repeated writes, failed/interrupted writes, incompatible input refusal, and migration policy. Original proprietary save import is a separate compatibility feature; it is not required merely to provide reliable AgePad saves. Never promise original-save compatibility without actual tests.

## 8. Phase 2: macOS bring-up and early Simulator promotion

### 8.1 Reproducible script contract

Implement scripts with these responsibilities; they are required outputs, **not files already implemented by this planning package**:

```text
scripts/check-prerequisites.sh       record tool versions and capabilities
scripts/clone-sources.sh             pinned safe clones, recursive dependencies
scripts/verify-sources.sh            refuse wrong/dirty references and stale pins
scripts/apply-patches.sh             exact-revision patches, no silent fuzz
scripts/identify-inputs.py           safe edition/build inventory, no execution
scripts/prepare-assets.py            exact input -> validated local content package
scripts/probe-route.sh               one route/input/hypothesis/test result
scripts/build-host-tools.sh          converter/recompiler tools if needed
scripts/generate-core.sh             only when selected route requires AOT
scripts/build-macos-app.sh           native ARM64 candidate app
scripts/build-ios-simulator.sh       correct SDK, explicit selected device
scripts/build-ios-device.sh          early device-SDK compile and later candidate
scripts/build-android.sh             enabled Android branch only; NDK arm64-v8a
scripts/run-scenario.sh              ordinary commands, fixed fixture, evidence
scripts/validate-gates.py            profile-aware checks; missing evidence fails
scripts/run-two-peer-test.sh         enabled network branch only; isolated peers
scripts/capture-crashes.sh           bounded private diagnostics
scripts/check-repo-safety.sh         reject protected source/generated inputs
scripts/audit-package.sh             per-target content/dependency/secret audit
scripts/package-candidate.sh         private candidate; no automatic publication
```

Implement only the script responsibilities needed by the active branch; unused Android/network/AOT script implementations are not Apple baseline gates. Every implemented entry point accepts explicit route/input/profile/output locations where relevant, returns meaningful nonzero errors, and emits the build/test identity. `validate-gates.py` must select requirements by named profile; a deferred extension is neither a pass nor a failed mandatory Apple row. Cache keys include source and dependency commits, patch contents, toolchain/SDK/target, flags, input manifest, converter/AOT version, and ruleset. Reuse a valid cache; never reuse one simply because a directory exists.

### 8.2 Native macOS ladder

1. Build the selected engine and dependencies for ARM64. Inspect Mach-O architecture, linkage, and process execution mode. Launching Feral's app or an x86 process under translation is not this step.
2. Launch one owned app with a fresh isolated profile; log renderer/audio/input and data identity. Show first-run import or a clearly labeled development data selector.
3. Load one exact map with the correct terrain, units, UI/text, and sound. Confirm camera/minimap coordinate transformations and selection hit testing.
4. Select and move a unit through ordinary pointer/keyboard commands. Test cancellation and unreachable-target behavior.
5. Gather and deliver resources. Demonstrate actual stockpile changes and gatherer task transitions.
6. Place and complete a building; show costs, placement rejection, collision changes, and completion.
7. Train a unit and research a supported technology; show queues, costs, resulting entity/stat changes, and cancellation behavior.
8. Fight an enemy; show attack timing, hit points, death/removal, sound, and remaining state. Test both successful and invalid commands.

Rungs 1–3 are build/boot evidence; rungs 4–8 form **BASIC-SLICE**. Use one or several explicitly named fixtures if a single tutorial does not expose every mechanic. A purpose-built fixture proves mechanics but is not an original campaign completion.

### 8.3 Immediate iPad Simulator gate and early hardware scout

After Mac BASIC-SLICE, freeze core/data/ruleset and build for `iphonesimulator`. Use an available iPad Simulator, not a phone first. Verify lifecycle, private data paths and the smallest working touch-to-RTS command bridge, then repeat BASIC-SLICE. Do not wait for full campaigns, save polish, networking or a final menu design. Do not require all UI customization features to test whether a villager can actually gather and build.

Build the same required dependency graph for `iphoneos` as an early compile/link audit. Match the SDK/ABI, not merely the `arm64` label. A successful unsigned compilation is compile evidence only; signing/installation/runtime remain separate. A device-SDK compile failure is a real portability defect to investigate, not something Simulator success erases. [S15]

Preserve the passing Mac artifact. Classify Simulator failures as dependency/SDK, renderer, paths/lifecycle, input mapping, simulation, data or harness defects. Make the smallest causal change, rerun the same fixture and the Mac regression. Switching engines/editions to hide a platform failure reopens the affected route/input gates.

Capture screenshots and interaction video using available tooling, for example `xcrun simctl io <UDID> screenshot <path>`. Discover devices rather than hardcoding an unavailable model. Screenshots prove frames, not commands. Simulator speed cannot establish physical frame rate, memory capacity, thermal behavior or touch feel. [T1, T2]

**E0: optional early physical-iPad scout.** Once the slice or first scenario works, and an authorized physical iPad/signing path is actually available, run that exact scope on-device before investing heavily in completion. Check launch, the ordinary gameplay slice, actual touch, data paths, audio, background/return, initial memory use and basic rendering. Record the exact build/device and every limit. This is diagnostic risk reduction, not D11 final acceptance. If access is absent, leave E0 `blocked: hardware/signing unavailable`, continue independent authorized work, and prepare a precise test handoff. A failed device scout reopens the relevant implementation goal; final candidates must be retested regardless of an earlier scout pass.

### 8.4 First authentic scenario and persistence

After the early Simulator slice, choose a real tutorial/scenario in the verified input. A **William Wallace** scenario is the initial preference only if it is actually present and the candidate exposes a meaningful objective path. Record its exact identifier/hash, required mechanics, objective sequence and result/return flow. Do not assume one tutorial includes construction, research and combat; BASIC-SLICE may use additional named fixtures to test those mechanics.

For D5, on both Mac and iPad Simulator:

1. Start the authentic scenario from ordinary game UI or a documented development launcher that does not alter scenario logic.
2. Use ordinary commands to make meaningful progress. Record inventory, units/orders, timers, triggers and RNG state where observable.
3. Save **before scenario completion**; exit; relaunch; load; verify meaningful state and continue playing. A reopened save file without continued gameplay is not a pass.
4. Complete every actual objective, observe the real result and return flow without forced flags or a test-only victory path.
5. Persist the completed scenario/campaign progression, relaunch again, and verify that the game exposes the correct completed/unlocked state. Do not require a completed scenario to resume as if it were still in progress.

Missing game save serialization is an engine gap, not solved by copying a scenario file. An authentic scenario completion without persistence may be recorded as a partial milestone, but D5 stays unmet. A test fixture, pre-unlocked save, scripted resource grant or direct objective mutation cannot substitute for fresh ordinary progression.

### 8.5 Completeness review and baseline development

Immediately after D5, update `ENGINE-GAPS.md` and `CONTENT-SCOPE.md`. Test at least one harder content path chosen for a **new mechanic**, not another similar tutorial. Audit useful skirmish AI and save-state coverage before assuming the baseline is mostly complete. Source-inspected functionality remains distinct from observed behavior.

Continue the winning engine when the missing work is bounded and behavior can be specified/tested. Add real implementations, not stubs. Retain fixtures for economy, combat, pathfinding, triggers, technologies, AI and persistence so every missing-feature fix can be evaluated without rerunning all campaigns manually.

If the investigation exposes a mostly absent game, record the change from **port integration** to **engine-completion/reconstruction**. Use the finite unblocking/probe policy to compare the best alternative. A larger product-budget decision may require a handoff; an ordinary compile or pathfinding defect with a concrete next test does not.

D6 still requires the full named classic baseline and useful skirmish. Observe a fresh campaign progression on the host, exercise each campaign and unique required mechanic on the iPad path, and maintain private late-game fixtures for fast regressions. At physical acceptance, include an original scenario, a harder fixture and a representative skirmish; do not claim an entire campaign was played on a phone unless that was actually observed. Any reproducible platform-specific divergence expands the on-target tests until resolved.

## 9. Phase 3: iPad product, iPhone adaptation, and optional extensions

### 9.1 PaperPad machinery, RTS interaction

Port the useful mechanisms: safe import/copy, per-app writable paths, settings persistence, native three-dot menu, diagnostics, lifecycle, input clearing, dependency locks, single-purpose scripts, and source/package audits. Adapt the design to an RTS, not an N64 controller overlay. [S12]

Minimum RTS controls:

- Tap/click selection; multi-select/box selection with a clear gesture mode; deselect; contextual move/gather/attack commands; distinguish selection from issuing orders.
- Camera pan and pinch zoom without accidental commands; accessible minimap navigation; correct world-to-screen coordinates at every scale and safe area.
- Building placement preview, validity feedback, confirm/cancel, production/research queues, idle-villager access, unit groups, and accessible mandatory hotkey equivalents.
- Separate touch, Pencil, mouse/trackpad, keyboard, and optional controller mappings. Pointer/keyboard support is not proof that touch is usable. Pencil is additive, not required.
- Pause/menu, command cancellation, modal input suppression, and release of held selections/gestures on interruption. Never send a stale order after resuming.

Prototype and test tablet controls first. For the phone branch, use separately sized panels and targets, not a scaled-down desktop HUD. User-facing menu, panels, tooltips, text entry, and path controls must remain accessible without developer keyboard shortcuts. Optional controller support must not hide the only usable RTS controls merely because a controller connects.

**Tablet acceptance first:** prove touch-alone selection, orders, panning/zooming, building placement and queues in real economy/combat before polishing gestures. Pencil hover/precision and external pointers are enhancements; do not rely on them to make the base game playable.

**Phone adaptation next:** test selection versus panning, smaller-screen target disambiguation, pinch zoom, edge/drag camera behavior, bottom/contextual command panels, resource visibility, queues and confirmation/cancellation. A radial menu is a candidate, not a mandatory invented replacement for the existing UI. Choose mappings through actual testing and keep the interpretation visible. Completing a scenario by keyboard does not validate a touch-only phone interface. iPad layout changes must not silently alter saved phone preferences and vice versa.

### 9.2 Three-dot menu and data management

Provide game-neutral parity with the useful reference mechanisms:

- Game Data: import/verify/reimport/remove, detected edition/build, supported status, missing-component report, conversion progress and cancellation.
- Saves: current compatibility profile, safe save/load/export/backup actions, new game, and clear refusal of incompatible saves. Import/removal must never delete source files.
- Display: renderer identity, scale/zoom/UI size, supported filtering, and default-off experimental graphics with clear restart requirements.
- Input: touch/Pencil/pointer settings, selection/pan behavior, accessibility, keyboard mappings, safe reset, and separate phone/tablet preferences.
- Audio and simulation speed: only actual supported choices. Speed changes alter the intended simulation setting, not a hidden performance workaround.
- Diagnostics, report a problem, build/source/data identifiers, About, unofficial-project wording, and third-party notices.

A development bypass around the importer is acceptable for early engine diagnosis, but does not satisfy the real import/menu row. Converted data is private. The app must remain useful offline for the supported single-player path after valid import, without assuming Steam exists on the mobile device.

### 9.3 Lifecycle and graphics ownership

Use each OS's writable application container. Keep immutable data separate from mutable saves/config/cache. Test permissions, protected files, interrupted import, low storage, memory pressure, background/foreground, audio route changes, renderer/surface recreation, orientation/size changes, and clean shutdown.

Single-player may pause and write a consistent checkpoint on backgrounding. A multiplayer peer must **not silently pause the shared simulation**: use the defined pause/disconnect/reconnect protocol, preserving session integrity. Partial reconnect support must be labeled honestly.

For graphics changes, test ownership and lifetime of native surfaces/resources. Do not port PaperPad's forced-process-exit or N64-thread cleanup strategy without a reproduced equivalent need; it is not a general iOS lifecycle recipe. [S12]

### 9.4 Android ARM64

This is a preserved follow-on branch, not a prerequisite for iPad or iPhone single-player. When explicitly enabled after the core and iPad path stabilize, build native C/C++ using the NDK for `arm64-v8a`; package it with an Android-specific shell and native libraries. Validate file import through Android's document-access model, lifecycle, input, audio, rendering, and save paths. Never rename or reuse an Apple `.a`/framework as an Android library. [S14]

An ARM64 emulator is a useful development target. Record its ABI and graphics backend; a different-architecture emulator with native-bridge translation is not proof of the intended ARM64 path. Physical Android testing is mandatory before claiming a supported Android release. Lack of attached hardware is a handoff, not an assertion that Android cannot work.

### 9.5 Timing and performance

Measure the selected original/reference simulation setting, then preserve gameplay speed independently of renderer cadence. Target responsive rendering, but do not assert 30/60 fps, memory capacity, battery life, or device tiers without a recorded measurement.

Before candidate profiling, define workloads and acceptance budgets in `PERF.md`: viewport/resolution, unit counts, map size, AI/player count, simulation speed, event density, memory cap, frame-time percentiles, audio underruns, and allowed baseline deviations. Label budgets as **targets**, measurements as **observed**. Do not lower a budget after a failing run without recording a deliberate product decision.

Profile idle town, busy economy, crowded pathfinding/choke points, large combat, effects/projectiles, campaign triggers, save/load, and menu/background transitions. Run 60-minute soaks with repeated transitions and sample memory over time. Simulator performance is diagnostic only; sustained hardware heat, memory pressure, audio behavior, and input feel require device measurements.

### 9.6 Multiplayer tiers and release promises

| Tier | Meaning | Required proof / boundary |
|---|---|---|
| N0 | Offline single-player | Complete baseline scenario/skirmish and reliable saves |
| N1 | Same-project LAN | Two matching AgePad peers; ordered commands, state agreement, complete match, mismatch/desync handling |
| N2 | Same-project Internet | Controlled separate-network match, session discovery/join/security, NAT/relay strategy, latency/loss recovery and disconnect behavior |
| N3 | Classic/HD retail-client interoperability | Exact target version and protocol, documented legal access, compatible simulation and data, actual mixed-client match |
| N4 | Commercial DE-client/service interoperability | Exact ecosystem/platform identified, legitimate authentication/service access, protocol and deterministic compatibility, actual mixed-client session; separate approval and feasibility decision |

The classic single-player baseline requires **N0 only**. N1 is a valuable next feature, not a gate that can prevent a complete offline iPad product. N2 is a separate Internet extension; paid/hosted infrastructure needs separate authority. N3/N4 remain independent conditional investigations and are not implied by N1/N2 or asset import. The earlier audit recorded Mac-only multiplayer in the official Mac DE FAQ; recheck the target ecosystem before a future interoperability decision rather than assuming that historical statement is current. [S11]

During route selection, record the product constraint that no N3/N4 promise exists. A short source-level feasibility note is enough while the branch is deferred; do not require a full protocol or authentication investigation before native single-player. If Chris later makes retail cross-play a hard product requirement, reopen scope explicitly before investing in a route known not to provide it. Do not contact public matchmaking services with an experimental implementation as a substitute for a controlled test. Never fake Steam identity, bypass authentication, disable a service's integrity checks, or claim success from opening a lobby alone.

For N1, negotiate engine build/protocol, ruleset, required content hashes, map/seed, and supported commands. Reject incompatible peers clearly. Use canonical ordering and deterministic simulation or a deliberately designed authoritative-state protocol; if the latter is selected, document the authority/security and snapshot model instead of claiming lockstep equivalence.

Test a complete two-player match with ongoing economy and combat, delays, dropped/reordered transport packets where relevant, peer disconnect, refusal of malformed commands, pause policy, and desync diagnostics. Two peers need isolated save/config/log paths and ports. A two-process localhost test is necessary but not sufficient for LAN or Internet claims. A simple “socket connected” screenshot does not pass multiplayer.

### 9.7 DE extension: reuse what is proven, re-prove what changes

The desired long-term accessibility of DE remains a reason to investigate it, not a reason to abandon a working classic engine. Keep DE work in an isolated branch with new input/ruleset/cache/save identities.

| Stage | Result sought | Boundary |
|---|---|---|
| DE0 | Safe identification and source/schema triage of a supplied DE copy | Intake only; no gameplay claim |
| DE1 | Representative data/media conversion for the exact DE build | openage converter output is not automatically input for freeaoe |
| DE2 | A declared DE-derived subset working through the demonstrated core | Name supported campaigns/mechanics/rules; re-run BASIC-SLICE, scenario, persistence and device checks |
| DE3 | A separately scoped full modern-engine/content target | Requires its complete feature/content audit; not implied by DE2 or classic success |

Two possible follow-ons: **adapt supported DE content to a proven core**, or **use the accumulated tooling to investigate a more direct reconstruction/recompilation/authorized-source route**. The first may change game semantics; the second may replace much of the core. Compare real gaps rather than treating either as a guaranteed upgrade.

Likely reusable assets of the engineering project are the Apple shell, command/test harness, validated platform adapters, diagnostics and import workflow. Exact decoders, simulation rules, saves, AI, multiplayer protocol and authentication may require substantial new work. Do not describe a generic importer or native graphics layer as a finished DE simulation. N4 remains separate even after DE3.

## 10. Phase 4: profile-aware test matrix

For every row record target/hardware or Simulator/emulator, OS/SDK, profile, route, input/ruleset hashes, source/dependency/patch revisions, flags, exact artifact, commands, expected/observed result and evidence. A profile-aware validator must refuse missing evidence, stale artifacts or a secretly reduced scope.

**B** = baseline for Mac/iPad single-player; **P** = additional iPhone requirement; **E** = enabled-extension requirement; **C** = conditional execution-route requirement; **S** = early scout, diagnostic rather than release proof; **H** = physical/public gate. A deferred E row cannot be reported as supported, but cannot fail an otherwise valid B profile either.

| # | Class | Test | Target | Pass condition |
|---|---|---|---|---|
| 1 | B | Authority, workspace, rights and safety | repo | Actual access recorded; originals protected; private-only state and executable safety checks exist |
| 2 | B | Edition and exact-build identification | inputs | Separate confidence, hashes, schema and missing-component report; no filename-only acceptance |
| 3 | B | Invalid/partial/mixed input rejection | host + iPad importer | Synthetic corruption, missing/changed/mixed data safely refused without mutating originals |
| 4 | B | Pinned native host build | macOS ARM64 | Reproducible candidate; architecture, dependency and execution-mode audits exclude CPU fallback |
| 5 | B | Provisional route decision | repo | R1 evidence and all supplied-input dispositions; DE probe or precise deferral; no mandatory tour of every engine |
| 6 | E-DE | DE conversion | host tools | Exact DE build, representative media/game records, explicit unknown fields; conversion not mislabeled gameplay |
| 7 | C-AOT | Executable model and translation | selected AOT route | Exact EXE; real original path executed; covered exercised imports/indirect code; no guest-CPU fallback |
| 8 | B | Map/render/audio startup | Mac + iPad Sim | Correct data, required UI/audio and input, logs and capture agree |
| 9 | B | Selection, camera and orders | Mac + iPad Sim | Ordinary commands and coordinates; valid selection; stale/invalid commands rejected |
| 10 | B | Economy | Mac + iPad Sim | Gathering/carry/dropoff, stockpile/costs and command transitions observed |
| 11 | B | Build/train/research | Mac + iPad Sim | Placement/collision, queues, cost/completion/cancellation and resulting state correct |
| 12 | B | Combat | Mac + iPad Sim | Target/range/cadence/damage/death and required projectiles; ordinary commands |
| 13 | B | Early Simulator and device-SDK builds | iPad Sim + iphoneos build | Same BASIC-SLICE; correct SDKs; successful device dependency/compile/link audit, not a device-runtime claim |
| 14 | B | Authentic scenario | Mac + iPad Sim | Fresh ordinary progression, all true objectives, result/return; no forced flags |
| 15 | B | Save/relaunch/continue | Mac + iPad Sim | Meaningful mid-scenario state resumes; completion/progression persists separately |
| 16 | B | Save interruption/recovery | claimed baseline targets | Failed/interrupted/incompatible write preserves last good state and gives usable recovery |
| 17 | B | Useful AI skirmish | Mac + iPad Sim | Economic/military development and complete match, not only retaliation |
| 18 | B | Pathfinding/groups/navigation | core + host/iPad regressions | Chokes, moving blockers, groups and required shore/transport/unreachable paths |
| 19 | B | Rules, technologies and triggers | core + host/iPad regressions | Full required manifest; no silently ignored game behavior |
| 20 | B | Named baseline campaigns | host full progression + iPad coverage | Declared campaigns complete fresh on host; every campaign/unique mechanic exercised on iPad path; testing extent explicit |
| 21 | B | Same-core repeatability and semantics | Mac + iPad; add iPhone for Apple profile | Fixed-command regressions; canonical-state differences explained; gameplay/save divergences resolved; networking precision claims separate |
| 22 | B | Production graphics and audio | Mac + iPad builds | Declared Metal path; terrain/layers/fog/UI and required sound categories; no silent diagnostic renderer |
| 23 | B | iPad RTS controls and menu | iPad Sim + physical row 33 | Touch alone exposes every mandatory action; optional Pencil/pointer; modal input clearing |
| 24 | B | Import/data/settings | Mac/iPad; repeat on each added platform | Transactional private copy; identity, cancellation, replacement and settings; originals never deleted |
| 25 | B | Lifecycle/input/audio/surface | iPad; repeat for added platform | Background/modal/resize/input transitions recover without stale orders or corrupted saves |
| 26 | P | iPhone gameplay and product UI | iPhone Sim + physical row 33 | Same scenario/save path; phone layout/targets/gestures; rows 3, 8–16 and 20–25 extended to phone as applicable |
| 27 | E-Android | Native Android single-player | Android ARM64 test target | ABI/dependencies, equivalent shell, BASIC-SLICE/scenario/save and baseline regressions; emulator/hardware labeled |
| 28 | E-N1 | Same-project LAN | isolated peers on actual LAN | Matching identity, full match, state agreement, mismatches/desync/disconnect handled |
| 29 | E-N2 | Controlled Internet | separate networks | Real session/match, join/security and defined latency/loss/reconnect behavior; no unauthorized service deployment |
| 30 | E-N3/N4 | Retail/DE interoperability | named mixed clients | Exact version/ecosystem, legitimate access, actual match and simulation agreement |
| 31 | B | Profiles and 60-minute soak | Mac + iPad; extend to phone/other claimed platforms | Predeclared workloads/budgets, stable memory/timing/audio, repeated saves/transitions; device and Sim observations separate |
| 32 | B | Diagnostics and clean clone | fresh workspace + selected packages | Scripts/regressions reproduce with declared private input; exports omit assets/code/saves/secrets/private paths |
| 33 | H | Exact physical acceptance | each claimed mobile device | Hands-on scenario, harder fixture/skirmish, touch/lifecycle/saves and sustained workload; exact artifact/device/OS recorded |
| 34 | H | Rights and publication | source + named packages | Separate rights decisions, notices, audits and Chris's explicit approval |
| 35 | S | E0 early physical-iPad scout | authorized physical iPad | Tested slice, initial memory/audio/input/lifecycle with exact build; diagnostic only; blocked if unavailable |
| 36 | B | Missing-systems audit | repo + observed gameplay | ENGINE-GAPS ledger distinguishes platform/data/harness/game omissions; updated after D5; major scope changes not hidden |

### 10.1 Required row sets

- **BASIC-SLICE portability:** rows 1, 2, 4, 5, 8–13 and preliminary row 36; row 7 also applies if using AOT. This is D1–D4 evidence, not the complete game.
- **Scenario feasibility:** portability rows plus 14–15 and the updated row 36. Row 35 is strongly useful when hardware is available, but is not inferred from Simulator or required when access is absent.
- **iPad single-player technical profile:** every B row, plus C-AOT if selected. P and E rows are not prerequisites. Early probes may remain partial, but all B requirements must be complete.
- **Apple single-player technical profile:** iPad profile plus row 26 and the applicable baseline rows repeated for iPhone; cross-platform semantic/clean-build/performance tests include phone. A single phone boot is not this profile.
- **Android extension:** row 27 plus all corresponding baseline shell/gameplay/persistence/quality tests on Android; physical and publication gates apply to an Android claim.
- **Network/DE extensions:** the exact enabled E rows plus all impacted baseline regressions; DE2/DE3 also require the declared content/ruleset manifest, not row 6 alone.
- **Public binaries:** the selected complete technical profile plus rows 33–34 for each claimed platform/feature. An early scout is not final physical acceptance.

Use `unrun`, `pass`, `fail`, `blocked`, `deferred`, and `not-applicable` with reasons. `deferred` is allowed for optional branches or a nonblocking scout, not missing mandatory baseline behavior. N/A is not a pass. Do not share an overall “green” without the exact profile name.

### 10.2 Cross-platform and physical evidence

Simulator proves only that environment. A device-SDK link proves no runtime behavior. Shared source does not transfer recorded success automatically to a new OS, build, input set or renderer. Re-run relevant exact-artifact regressions after changes.

A device handoff must name the build hash, supported input manifest, actions, expected outcomes, record/capture instructions and known issues. Include actual touch play, an authentic scenario, a more demanding fixture/skirmish, persistence, lifecycle and the sustained workload. Final performance claims come only from recorded hardware measurements. Do not stitch screenshots from different candidates into one acceptance claim.

## 11. Evidence, journal, and reporting

Maintain these records; evidence-containing files remain private/ignored unless explicitly cleared:

| Document | Responsibility |
|---|---|
| `JOURNAL.md` | Append-only date/run/goal/hypothesis/action/test/result/interpretation/next-step history |
| `STATUS.md` | Spec revision; target/first-milestone profiles; dependency-aware lowest unmet goal; route/input/ruleset; last good artifact; matrix, physical and extension states; actual authorized scope |
| `INPUTS.md` + private manifest | Source provenance, exact identity/confidence, original/copy hashes, formats, incomplete assets, and compatibility |
| `ROUTES.md` | Probe budgets, milestones, evidence, costs/gaps, provisional choice, parking/reopening reasons |
| `CONTENT-SCOPE.md` | Named baseline campaigns, ruleset and mechanics; explicit DE subset/unsupported content and approved changes |
| `ENGINE-MAP.md` / `EXECUTABLE-MODEL.md` | Actual source subsystem map; AOT imports/callbacks/code coverage and patches only when relevant |
| `ENGINE-GAPS.md` | Source-only versus tested/partial/absent/unknown systems; PLATFORM/ENGINE/DATA/HARNESS/INPUT/RIGHTS cause; minimum remedy; post-scenario completeness decision |
| `DETERMINISM.md` | Seed/command traces, canonical serialization, flags/math/threading analysis, first divergent tick and reproducer |
| `SAVE-AND-LIFECYCLE.md` | Serialization identities, interruption/recovery, per-target paths and lifecycle evidence |
| `PLATFORM-MATRIX.md` | SDK/ABI/build/runtime/renderer/input status for each target |
| `NETWORK.md` | Separate N0–N4 statuses, protocol/content identity, actual peers, tests, security, service access and costs |
| `PERF.md` | Reference cadence, predeclared workloads/budgets, actual timings/memory/audio/thermal observations |
| `RIGHTS-STATUS.md` / `RELEASE-READINESS.md` | Authority, license/provenance review, exact source/binary decisions and candidate approval |
| `artifacts/<date>/<run-id>/` | Ignored logs, captures, profiles, hashes, test results and bounded crash reports |

Every experiment record must answer:

```text
Spec revision, target profile, goal and route/input pair:
Hypothesis (what uncertainty this will resolve):
Prerequisites and exact build identity:
Smallest change and command:
Expected pass/fail observation:
Actual observation and exit status:
Evidence paths and hashes:
Interpretation (supported / disproved / inconclusive):
Regression impact and state changes:
Next action or precise handoff:
```

Use acceptance states `unrun`, `pass`, `fail`, `blocked`, `deferred`, and `not-applicable`, with the profile and reasons. `deferred` never excuses a missing mandatory baseline row. Source-read intent may be marked `source-observed`, never `pass`. A partial run is not a successful run. Report separately: native slice, complete scenario, complete baseline, iPad physical, iPhone physical, and each enabled extension. Do not replace this with an unsupported success probability. Test helpers must propagate failures; missing evidence must fail a gate validator rather than becoming an empty green report.

A source read proves implementation intent; a compiler proves compilation; a PID proves process creation; a screenshot proves one image; Simulator proves that environment; and only exact-artifact testing supports that artifact. These evidence distinctions are inherited from the supplied templates. [T1, T2]

## 12. Public release, legal, provenance, and wording

This is an engineering release gate, not legal advice. Private technical direction from Chris is not blanket permission from Microsoft or an upstream author. Review the actual source, dependencies, game license, distribution topology, and jurisdiction where relevant. Do not use leaked source or unlicensed redistributed game files.

### 12.1 Separate source, assets, generated code and binary rights

An open-source engine license covers what its authors license, not Microsoft's game content or trademarks. Translated/reconstructed proprietary game logic may create different redistribution questions from original integration code. Supplying one's own data and omitting original assets do not automatically settle binary rights.

Audit exact dependency licenses, GPL obligations and compatibility, copied snippets, modified upstream files, generated output, codecs, fonts, and notices. Do not assume a public GitHub repository has a license or that GPL makes every Apple distribution topology either automatically allowed or automatically impossible. Resolve the proposed topology explicitly. Apple's review guidelines add code and intellectual-property requirements for any eventual App Store route. Store submission is not part of this baseline. [S16]

`RIGHTS-STATUS.md` must select a permitted topology before publication: appropriately licensed integration source plus user-supplied data; separately approved source and generated-binary distribution; maintainer-authorized integration; or private-only. Rights questions do not justify fabricating technical impossibility, and technical success does not authorize distribution.

### 12.2 Package boundary

Public source/package checks must reject proprietary game assets/executables, converted user data, generated proprietary AOT source, private saves/replays/fixtures, memory dumps, absolute private paths, signing secrets, credentials, account identifiers, and accidental `ref/`, `generated/`, or `private/` contents. A source archive and each `.app`, `.ipa`, or Android package need their own audit.

A native binary that embeds translated game logic requires a separate explicit binary-rights decision even when it contains no artwork. An integration-only public repository does not establish a right to publish that binary. No automatic release/tag/push/upload is allowed.

### 12.3 Honest product wording

Before gameplay proof: **“Researching native mobile routes for Age of Empires II; current work is an evidence-gated feasibility program.”**

After an authorized reimplementation release, use the substance: **“AgePad is an unofficial native client using [named engine] with explicitly supported user-supplied [edition/build] data. Supported content, save formats, and multiplayer modes are listed separately. It is not affiliated with or endorsed by Microsoft, World's Edge, or Feral Interactive.”**

For AOT, describe ahead-of-time recompilation and the actual toolchain instead of saying recovered original source. Do not claim “full Definitive Edition,” “plays online with Steam players,” “emulator-free,” “first-ever,” or a supported device tier without the corresponding evidence and permission.

### 12.4 Public candidate gate

Require the exact technical profile from Section 2.2/10.1, D11 on each claimed physical platform, separate source/binary rights review, completed notices, clean audits, no severity-1 gameplay/save/crash/privacy issue, clear supported-edition documentation, and Chris's explicit approval. For an iPad-only single-player binary, unfinished iPhone/Android/DE/network branches do not substitute for or block its own requirements; describe the release as iPad-only. The complete Apple scope remains unfinished until iPhone is accepted. Each N1–N4 or DE claim needs its own successful branch evidence. Source and binary publication may have different outcomes.

## 13. Risk register

| Risk | Current standing | Response |
|---|---|---|
| Unknown stored editions | No game copies inspected; earlier session reported unavailable Drive | Recheck actual access; safe supplied-root inventory; never infer an edition |
| Current HD data incompatible despite historic support | Unproven | Test current supplied install first; inspect actual schema/terrain/overrides; no forced downgrade |
| DE aspiration displaces working classic progress | Converter/gameplay distinction and scope risk | Nonblocking bounded DE intake/probe; classic product is independently valid |
| freeaoe is old and incomplete | README/source expose missing systems and old build assumptions | Reproduce with pinned compatible dependencies; separate porting defects from engine-development scope |
| Unknown-version detector optimism | Source can identify edition without recognizing exact hash | Separate edition confidence, build verification and tested compatibility |
| Fast floating-point math and nondeterminism | Risky flags observed in freeaoe build | Strict-simulation experiment, canonical replay tests, first-divergence diagnosis |
| SFML/OpenGL/Qt mobile gap | Platform-specific suitability unproven | Early Simulator and device-SDK checks; narrow renderer/platform adapter instead of blind dependency upgrades |
| AOT platform/API/indirect-code scope | No AoE-specific route validated | Exact EXE audit, bounded executed path, explicit code coverage and no CPU fallback |
| Save support mistaken for scenario loading | Unverified per candidate | Dedicated serializer/state/relaunch gate; incompatible-save refusal |
| DE data mistaken for DE multiplayer | Not supported by evidence | N0–N4 status separation; controlled interoperability only with legitimate access |
| Runtime data or patch drift | Expected for different installs/builds | Snapshot, hashes, ruleset namespaces, cache invalidation and explicit supported revision list |
| Too many routes consume all effort | Program risk | Six-step probe rounds, bounded retries, evidence-based parking, one mutable candidate |
| Engine switch invalidates prior proof | Program risk | Key every claim to route/input/ruleset/artifact; reopen affected goals |
| Simulator success hides device failure | Inherent test-scope gap | Early iphoneos audit; E0 scout when available; exact final physical acceptance |
| Original content reduced to demo | Product risk | Named baseline manifest; complete progression/skirmish; explicit approval for scope changes |
| Missing game systems masquerade as platform fixes | Principal completeness risk | ENGINE-GAPS audit before and after scenario; real implementation or evidence-backed pivot |
| Android/networking block an otherwise complete iPad game | Avoidable scheduling risk | Profile-aware gates; extensions deferred explicitly, never presented as tested |
| Shared iPad core mistaken for phone readiness | Separate UX/performance risk | Phone-specific layout, ordinary touch commands, memory/thermal tests and exact physical acceptance |
| Unsupported probability becomes a completion promise | Communication/agent-planning risk | No numerical success forecast; promote only from observed milestone evidence |
| Source/binary licensing or asset leak | Separate unresolved release risk | Private-only by default, executable safety checks, independent source/package rights decisions |

## Sources and drafting basis

The source register and pinned observations are carried forward from the earlier AgePad documents, whose audit was dated 6 September 2026. **This v2 pass read and revised those documents using the subsequent conversation; it did not perform a new external audit, inspect a game installation or run a build.** Recheck mutable storefront, support, license and platform details before relying on them in execution. Pinned code observations remain distinct from runtime proof. New profiles, budgets, priorities, interfaces, test cases and qualitative judgments are engineering policy, not source claims.

Drafting basis also includes the prior `AgePad-PRD.md`, `AgePad-GOAL-LOOP.md`, `AgePad-INPUTS-AND-VERSIONS.md`, and Chris's request to incorporate the follow-up assessment. This v2 three-file set is self-contained for planning. Generate runtime state/locks/scripts during implementation; do not carry conflicting all-platform/network-required defaults from the old bundle's config or status file.

- **T1:** Chris's attached `GOAL-LOOP(20260906-011202).md`, “SnapPad goal-based loop,” dated 26 Aug 2026. Lowest-unmet-goal rule, process hygiene, unblocking ladder, evidence and session procedures.
- **T2:** Chris's attached `PRD(20260906-011203).md`, “SnapPad PRD: Pokémon Snap, native on Apple platforms,” dated 26 Aug 2026. Thirteen-section structure, acceptance matrix, physical-device and rights gates. Early Simulator ordering and AoE-specific route selection are new adaptations.
- **S1:** [Steam: Age of Empires II (Retired), app 221380](https://store.steampowered.com/app/221380/Age_of_Empires_II_Retired/) — earlier listing/acquisition observation and original campaign description; recheck availability.
- **S2:** [Steam: Age of Empires II: Definitive Edition, app 813780](https://store.steampowered.com/app/813780/Age_of_Empires_II_Definitive_Edition/) — earlier product/content and Windows/macOS observation; recheck relevant current details.
- **S3:** [freeaoe README at inspected revision](https://github.com/sandsmark/freeaoe/blob/f5e46da59761868aa1814037f712f277c71b5bb3/README.md) — historical feature claims and unfinished work.
- **S4:** [freeaoe HD asset loader](https://github.com/sandsmark/freeaoe/blob/f5e46da59761868aa1814037f712f277c71b5bb3/src/resource/AssetManager_HD.h) — concrete HD layout handling.
- **S5:** [freeaoe CMake configuration](https://github.com/sandsmark/freeaoe/blob/f5e46da59761868aa1814037f712f277c71b5bb3/CMakeLists.txt) — compiler/dependency choices and fast-math flags.
- **S6:** [openage README](https://github.com/SFTtech/openage/blob/9a5a7ccbfc20c2de658fc746462cd4a69aa758ef/README.md) — engine/conversion scope and readiness warning.
- **S7:** [openage version detector](https://github.com/SFTtech/openage/blob/9a5a7ccbfc20c2de658fc746462cd4a69aa758ef/openage/convert/service/init/version_detect.py) — edition detection versus exact-hash identification.
- **S8:** [M-HT/SR](https://github.com/M-HT/SR) and [SRW](https://github.com/M-HT/SR/blob/master/SRW/README.md) — selected-game static-recompilation precedent; not AoE support.
- **S9:** [FolkertVanVerseveld/aoe](https://github.com/FolkertVanVerseveld/aoe) — partial original-AoE/Rise of Rome reconstruction.
- **S10:** [World's Edge: Mac DE release](https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-available-now-on-mac/) — official 28 May 2026 native Mac launch.
- **S11:** [Official Mac DE FAQ](https://support.ageofempires.com/hc/en-us/articles/360050470032-Age-of-Empires-II-Definitive-Edition-coming-to-Mac) — same Steam ownership and Mac-only multiplayer statement; recheck before future interoperability decisions.
- **S12:** [PaperPad architecture at the template pin](https://github.com/chrissotraidis/paperpad/blob/74b6e45830a06c7f274c5ac1ddd7c625bc13a557/docs/ARCHITECTURE.md) — Apple integration/process reference, not an AoE engine.
- **S13:** [SFML official site](https://www.sfml-dev.org/) — mobile support is qualified; audit the selected release and actual API usage.
- **S14:** [Android NDK ABI guide](https://developer.android.com/ndk/guides/abis) — ARM64, ELF and platform-specific build requirements.
- **S15:** [SDL iOS platform/build notes](https://wiki.libsdl.org/SDL3/README-ios) — distinct Apple platform targets. Simulator evidence rules also follow T1/T2; no obsolete Simulator API list is adopted.
- **S16:** [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — eventual store code/IP constraints, not a legal clearance or an initial submission requirement.
