# AgePad goal-based loop: classic gameplay first, iPad proof first

> Superseded for the current user's DE/native-iPad/multiplayer objective by [DE-GOAL-LOOP.md](DE-GOAL-LOOP.md), 2026-09-07. This classic route remains preserved; its single-player-only completion criteria do not satisfy the active DE goal.

**Spec ID:** `agepad-v2-2026-09-06`.

**Revision: v2 — 6 September 2026.** Supersedes the earlier AgePad loop. Working name: `agepad`. Requirements: [AgePad-PRD.md](AgePad-PRD.md). Inputs: [AgePad-INPUTS-AND-VERSIONS.md](AgePad-INPUTS-AND-VERSIONS.md). For a repository installation, use `docs/PRD.md`, `docs/GOAL-LOOP.md` and `docs/INPUTS-AND-VERSIONS.md`, updating these links accordingly.

**Operating intent:** prove an authentic native classic/HD AoE II single-player core, get it into iPad Simulator early, complete the declared game, and make a good iPad product. Then adapt the same proven core to iPhone. Preserve Android, multiplayer and DE as separate follow-on branches. Do not require them to call a complete iPad single-player result successful.

When Chris launches the agent in the designated workspace, perform reversible private engineering within the actual granted authority. Default intended profile: `apple-singleplayer`; first independent milestone: `ipad-singleplayer`. Work toward technical acceptance, prepare exact physical handoffs, and continue unblocked authorized work. No publication, purchases, paid infrastructure, publisher contact or broad account changes are authorized. These documents are plans, not evidence that an agent or game build has run.

The structure retains the SnapPad loop: lowest unmet dependency, one concrete step, immediate testing, evidence, regression reopening and an unblocking ladder. The main v2 changes are **profile-aware gates**, **an engine-completeness audit**, **nonblocking DE triage**, and **separate tablet, phone and extension acceptance**. Do not import the old bundle's conflicting Android/network-required defaults. The PRD's embedded source register carries the earlier research; this revision does not supply a new external audit or calibrated success probabilities.

## The goal stack

Work the lowest unmet goal **in the active profile's dependency chain**, not the lowest numbered item in an unrelated extension. A goal is met only when its required evidence exists. Regressions reopen the earliest affected dependency; independent unblocking work may continue without marking it met.

| Goal | Required result | PRD mapping |
|---|---|---|
| **G0. Environment, authority and state ready** | Verify workspace, preserve existing work, record tools/permissions, pin read-only references, disable push, create safety checks and private-only rights state. No unnecessary Android setup. | Part of D1 |
| **G1. Inputs identified and frozen** | Safely inspect supplied roots; distinguish edition from exact-build confidence; preserve originals; record hashes, schema, language, expansions and missing data. One suitable input is enough to proceed; missing comparison copies remain missing. | D1 |
| **G2. Provisional route selected** | R1 with the best appropriate HD/classic input is the default. Record probe evidence, all input dispositions, bounded DE result or deferral, baseline scope and the initial ENGINE-GAPS ledger. Do not require every route to build. | D2 |
| **G3. Native macOS candidate builds and boots** | Selected ARM64 core opens a real map/UI with required audio/input. Inspect architecture, linkage and execution mode. Feral's retail app, Wine or a CPU interpreter cannot pass. | Part of D3 |
| **G4. macOS BASIC-SLICE works** | Ordinary commands select/move, gather/drop off, place/build, train/research and fight. Costs, queues, completion and invalid actions are observed. A moving sprite is insufficient. | D3 |
| **G5. Early iPad Simulator BASIC-SLICE works** | Rebuild the same core/data/ruleset for Simulator; repeat mechanics with minimal touch input; complete the device-SDK compile/link audit. Run before full campaigns, final menus or networking. | D4 |
| **G6. Authentic scenario and persistence work** | Fresh original objectives and result/return flow, mid-scenario save/exit/reload/continue, and separate completion/progression persistence on Mac and iPad Simulator. Update ENGINE-GAPS immediately afterward. | D5 |
| **G7. Named classic baseline complete** | Declared campaigns, useful AI skirmish, required units/rules/technologies/triggers/pathfinding, audio and reliable saves pass. Missing game systems need real implementations, not platform excuses or stubs. | D6 |
| **G8. iPad product shell works** | Touch-alone mandatory actions; optional Pencil/pointer/keyboard; three-dot menu, import/settings/diagnostics, lifecycle and tablet layout. No stale orders or inaccessible controls. | D7 |
| **G9. iPhone adaptation works** | Same proven core; phone-specific gestures/panels/targets; authentic scenario and persistence on iPhone Simulator; baseline rows extended to the phone. Not required to mark the separate iPad milestone. | D8 |
| **G10. Named technical profile green** | Exact-artifact applicable matrix, source locks/scripts, clean clone, regressions, measured workloads and 60-minute soaks. Evaluate separately as G10[ipad-singleplayer] and G10[apple-singleplayer]. | D10 |
| **G11. Exact physical iPad accepted** | Authorized tester plays the exact candidate: authentic scenario, harder fixture/skirmish, real touch, audio, persistence, lifecycle and sustained workload. Record hardware, OS and artifact hash. | D11 on iPad |
| **G12. Exact physical iPhone accepted** | Equivalent exact-artifact phone testing, with actual phone usability/memory/sustained behavior. An iPad pass cannot substitute. Required for an iPhone/complete Apple claim, not iPad-only. | D11 on iPhone |
| **G13. Named public candidate authorized** | Appropriate technical profile, exact physical acceptance, separate source/binary rights, notices, audits and Chris's explicit publication approval. This is a handoff, never permission inferred from progress. | D12 |

### Dependency and promotion rules

- **Portability milestone:** G0–G5. This proves the tested Mac/Simulator slice and device build, not physical gameplay.
- **Scenario-feasibility milestone:** G0–G6. This proves one authentic scenario/persistence path, not a complete game or low remaining effort.
- **First iPad technical profile:** G0–G8 → G10[ipad-singleplayer]. G9, Android and networking are not prerequisites.
- **Intended complete Apple technical profile:** G0–G9 → G10[apple-singleplayer]. After the iPad milestone, continue G9 within the authorized run rather than announcing the full Apple scope complete.
- **Public iPad binary:** the iPad technical profile → G11 → G13[ipad]. Phone/extension delays do not block this narrower release if Chris explicitly approves it.
- **Public iPad+iPhone binaries:** the Apple technical profile → G11 + G12 → G13[apple]. Exact physical evidence must match the final artifacts.

The numeric list is not an instruction to wait for phone work before evaluating the iPad profile. Likewise, missing hardware is not an instruction to stop independent iPhone engineering. Report the precise achieved profile and the remaining work.

**E0 early physical-iPad scout:** after G5 or G6, when authorized hardware and signing are available, test that exact limited slice on-device before heavy completion work. Record touch, rendering/audio, private paths, background/return and initial memory behavior. E0 is diagnostic, not G11. If access is unavailable, mark E0 blocked and continue independent work. A real device failure reopens the affected implementation goal; an E0 pass never replaces final retesting.

`RIGHTS-STATUS.md = private-only` blocks publication, not otherwise authorized lawful local engineering. Unavailable lawful inputs, service access, signing or hardware remain separate real dependencies. The project owner's direction is not blanket permission from a rights holder.

## Optional branch goals

Keep these visible as `deferred` unless explicitly enabled within the actual work authority. Do not mark deferred work as pass, turn it into an Apple baseline failure, or quietly discard it.

| Branch | Ordered proof | Dependency and claim boundary |
|---|---|---|
| **Android A0 → A1 → A2** | A0: NDK arm64-v8a build and native-library audit. A1: equivalent shell, BASIC-SLICE, scenario, persistence and baseline regressions on an identified ARM64 target. A2: exact physical quality/rights acceptance. | Reuse the demonstrated core after iPad stabilization; emulator is not hardware. D9 + applicable D10–D12. |
| **N1 same-project LAN** | Compatible identity negotiation, ordinary command flow, actual LAN match, state agreement, mismatch/desync/disconnect handling. | Isolated peers; includes networking-specific precision/protocol tests. Not HD/DE retail compatibility. |
| **N2 same-project Internet** | Separate-network real match, join/security, latency/loss and NAT/relay/disconnect behavior. | Requires a suitable N1/protocol foundation and actual service authority; no autonomous paid deployment. |
| **N3 retail classic/HD interoperability** | Exact target build/protocol, legitimate access and actual mixed-client match with compatible simulation. | Separate feasibility and scope decision; N1/N2 do not satisfy it. |
| **N4 commercial DE ecosystem** | Exact platform/service/version, legitimate authentication, compatible engine/protocol and a real mixed-client session. | High uncertainty; DE assets or DE3 are not N4. No bypass or fake identity. |
| **DE0 → DE1 → DE2 → DE3** | DE0: identify/triage supplied DE. DE1: bounded representative conversion. DE2: validated declared subset through the proven core. DE3: separately scoped complete modern-content/engine target. | DE0 disposition belongs in G2; DE1 may be deferred after a bounded blocker. No DE stage is an implicit prerequisite for the classic product. |

Audit the existence of these product gaps early without implementing every branch. If Chris makes retail cross-play or a full DE ruleset mandatory later, record a changed product requirement and reopen route selection where necessary. Do not silently revise the promise while retaining the old plan.

## The loop

Repeat until the current authorized profile's technical goal is met, then continue the next intended unblocked Apple goal or prepare the required physical/rights handoff:

1. **Pick.** Select the lowest unmet dependency and smallest experiment. Write a falsifiable hypothesis plus the pass/fail observation before changing code.
2. **Check state.** Read current revision/profile, status, last journal entry, route/input/ruleset, ENGINE-GAPS, git state, pins, caches, test save, owned processes and booted Simulators. Preserve valid work.
3. **Execute one bounded step.** One causal change, target and fixture. Retain the known-good build and save. Do not rebuild every candidate or install unrelated stacks by default.
4. **Test immediately.** Use ordinary commands and read-only observation. Compilation is not gameplay; conversion is not an engine; an objective event is not a result flow; a save file is not resumed state; a socket is not a match.
5. **Capture evidence.** Private dated logs, commands, exit status, video/state observations, hashes and expected versus observed result. Distinguish supported, disproved and inconclusive hypotheses. Timeout or absent evidence is not pass.
6. **Classify and update.** Use `PLATFORM`, `ENGINE`, `DATA`, `HARNESS`, `INPUT/ACCESS`, or `RIGHTS/RELEASE`. Update status, scope, gap ledger and matrix. Reopen affected gates after changes; do not transfer claims across inputs or artifacts.
7. **Promote or unblock.** G4 should lead directly to G5. G6 should lead to a completeness decision, not an automatic claim of near-completion. On failure, use the ladder rather than an unchanged third attempt.

A valid test can discover that a system is absent. That is useful evidence, not success on that system. A plan to implement it is not execution evidence either.

## Route and edition discipline — hard rules

- **Track engine and input independently.** R1 + HD build A differs from R1 + DE build B. Use exact input/ruleset/source/target identities for caches, saves and tests.
- **Start with the available appropriate copy.** Prefer HD/freeaoe when HD is present. Test a supplied classic AoK/AoC variant instead of waiting for another purchase. Only-DE input calls for a bounded DE probe, not pretending it is HD.
- **DE cannot become a hidden dependency.** Inventory it when supplied. Run at most one initial bounded DE probe round when feasible; otherwise record exactly what prevented it and what would reopen it. Continue the classic winner.
- **Do not mix files to suppress errors.** An intentional adapter needs source-to-internal mappings, an explicit ruleset and a new test identity. Unknown hashes remain unknown even when edition detection succeeds.
- **Do not rewrite the platform prematurely.** Reproduce the existing host dependency graph first. A concrete unsupported shader/API/SDK path can justify an adapter; a generic preference for Metal cannot justify throwing away working gameplay.
- **Do not recompile an EXE just because one is present.** Activate R4 after observed R1 limitations or a missing viable data path justify the original-logic investigation. Audit one bounded path before generating an entire general-purpose system.
- **Preserve the winner.** One mutable route at a time; isolated working trees/builds/evidence. R2/R3/DE work must not overwrite the passing classic core or its data.
- **Label partial and alternate results.** Tutorial-only, synthetic scenarios, HD data/classic rules, DE subsets, custom RTS experiments and AoE I stay accurately named.
- **Reopen parked routes on changed evidence.** Corrected input, a dependency fix, new source or a successful isolating test can justify another round. An unchanged prompt cannot.

### Bounded probe policy

A round permits **six evidence-producing steps per route/input pair**. Three distinct unsuccessful remedies to one causal blocker trigger reassessment. Two rounds without a new milestone or material reduction of the blocker trigger parking with a reproducer. These are resource controls, not deadlines or forecasts.

A step must be a bounded hypothesis/change/test, not an endless command. A budget counts initial alternative-route probes and their retries; it is not permission to stop a functioning implementation after six useful feature fixes. Baseline implementation continues while steps produce evidence and remain within the authorized product scope. Major new engine-development scope requires the documented completeness decision.

## Completeness checkpoint — mandatory after G6

Update `ENGINE-GAPS.md` using actual code and tests. Cover commands, economy, construction/production, combat, pathfinding/formations, AI, technologies/civilization rules, scenario scripting, random maps, campaign progression, saves, rendering/audio, shell and optional networking. Each row needs source location, observed status, defect class and the smallest next validation.

Ask the concrete engineering question: **Are we adapting a mostly functioning game, filling a bounded set of gaps, or reconstructing most of the game?**

If the answer is bounded missing features, keep implementing and regression-testing the winner. If most baseline systems are absent, compare a tightly scoped R4 alternative or document the larger engineering decision. Do not hide absent AI or save serialization under “mobile polish.” Do not declare impossible because one public engine is incomplete. Do not certify a full game because one scenario finished.

## Process hygiene — hard rules

- **One Simulator:** inspect `xcrun simctl list devices booted`. Stop owned test Simulators before the next one. Preserve unrelated sessions on shared machines; do not terminate another person's work.
- **One ordinary game instance:** track owned PID/bundle/profile; terminate before relaunch and verify exit. Preserve unrelated retail reference games and other development work.
- **Explicit network exception:** when enabled, the declared two-peer harness may run exactly its isolated peers, profiles, ports, logs and artifacts. Prefer a host plus one Simulator or separate devices. Stop peers after the test.
- **One variable:** keep input, seed, route, flags and command trace fixed while testing one cause. Gameplay changes hidden as performance optimization are regressions.
- **Preserve crash evidence:** inspect orphan processes, locks, partial imports/saves and captures before controlled cleanup. Prefer a clean graceful stop; forced termination must be identified as a test condition or recovery action.
- **Immutable originals and references:** work from ignored snapshots and isolated source changes. No destructive reset, blanket deletion or `git clean -fdx`; preserve unknown edits.
- **No leaks:** original/converted assets, EXEs, proprietary AOT, saves, memory dumps, credentials and private paths stay out of commits and exports. Review diagnostics before any sharing.
- **Pin before patching:** exact recursive revisions and patch identities. No silent SFML/Qt/SDL major upgrade or dependency architecture substitution.
- **No silent stubs:** do not replace economy, AI, pathfinding, objectives, required audio, save state or authentication with no-ops to advance a screen. Optional absent services/devices return truthful unavailable results.
- **No native fiction:** unresolved executable paths must be mapped/reconstructed or remain blocked. Ordinary AI/scenario script interpretation is distinct from interpreting guest-CPU instructions.
- **No publication by momentum:** a green technical profile, early hardware scout or clean package scan is not G13. Public rights and exact-artifact approval remain separate.

## Unblocking ladder

Use the following in order as applicable; journal the rung and result.

1. **Read the causal failure.** Capture complete compiler/import/runtime/crash context, not just the last line. For a desync or replay defect, find the first divergent command/tick/state.
2. **Verify state and identity.** Source/input/ruleset, SDK/ABI, dependencies, flags, cache provenance, profile/save and last good command. Rule out mixed data and wrong targets first.
3. **Check the relevant reference mechanism.** Inspect the selected engine's actual build guidance and applicable PaperPad shell/scripts/testing patterns. Do not transplant N64 patches.
4. **Inspect the responsible code/data path.** Loader, parser, ordinary command, simulation, trigger, AI, save or renderer. For AOT, map addresses to the exact executable/import/indirect manifest.
5. **Separate missing logic from a broken integration.** Inspect dependency APIs and source, headers/schema and ENGINE-GAPS. Verify whether the required function exists instead of repeatedly changing build flags around an absent subsystem.
6. **Research one named question.** Use primary documentation/source/issues/history. Return with a bounded test, not a new pile of unrelated repositories. Reverify mutable facts only when they matter to the next decision.
7. **Reduce the case.** One asset record/tile, move, gather/dropoff, queue, trigger, save/reload, callback, strict-math comparison or identical Mac/Simulator fixture.
8. **Fix narrowly and regress.** Implement or patch the real behavior at the smallest useful boundary. Do not remove validation, force objective success or silently alter rules to pass.
9. **Park or pivot on evidence.** When the probe policy is exhausted, preserve the known-good build and reproducer. Reopen G2 only when justified. Continue another unblocked supported task without certifying the blocked goal.
10. **Hand off real dependencies or decisions.** Missing legitimate complete input, source/service authority, no bounded AOT route after actual audit, major engine-completion scope, physical interaction/signing or publication approval. State the exact missing thing and next test afterward.

Routine crashes, compiler failures, graphics/input issues and save defects with a concrete isolating experiment are not reasons to abandon the task. Conversely, “the hardware should be capable” is not evidence that an incomplete engine can be finished within an unstated budget.

## Testing rhythm

- **Per change:** smallest affected test plus known-good smoke. Changes to shared code may reopen both Mac and mobile evidence.
- **Per input/importer:** valid snapshot plus synthetic corrupt/missing/mixed inputs; source immutability and mapping checks.
- **Per simulation/math/thread change:** fixed seeds and ordinary-command traces; compare canonical/semantic outcomes. Cross-platform lockstep is a separate network requirement; real single-player behavior differences still need diagnosis.
- **Per save:** disposable backed-up profile; save meaningful mid-game state, exit/load/continue, verify completion progression, interrupt/corrupt/mismatch safely.
- **Per platform/renderer:** BASIC-SLICE, world/screen coordinates, touch versus camera intent, modal input, audio and resource recovery. A clear-color surface does not pass.
- **Per enabled network change:** isolated peers, identity/mismatch checks, ordinary full match and first-divergence evidence.
- **Per goal/profile claim:** run the exact required matrix rows. Deferred extension rows are not baseline gates and cannot be advertised as passed.
- **Per session/candidate:** relevant regressions and highest-good gameplay; complete profile matrix for candidates. Physical acceptance stays physical and artifact-specific.

Synthetic tests may construct their initial fixture. Authentic scenario acceptance must then use ordinary commands, not direct stockpile grants, unit teleports or setters for objective/victory flags. Read-only observation is encouraged. Harness defects must be fixed rather than used to reinterpret an unobserved result as pass.

## Using the reference machinery — not just its appearance

Reuse the design of locks, safe clones, dirty-check refusal, script wrappers, crash capture, private paths, transactional import, menu/input clearing, lifecycle, diagnostics and source/package audits. Use an RTS command model, not an N64 controller snapshot. Engine logic, graphics and scripts still need their own adapter and license audit.

Wire breadcrumbs early: revision/profile, engine/input/ruleset, parser/converter, scene/map, simulation tick and command sequence, gesture ownership, renderer, save begin/commit/failure and lifecycle. Add network events only when that branch exists. Export no game bytes, proprietary full state, account tokens or unreviewed private paths.

Keep risky rendering/precision/compatibility/performance/network experiments default-off and identified. A diagnostic renderer may support an early test, not silently become the accepted production path. A reusable shell or importer does not prove that a later DE core or service protocol will be easy.

## Session start checklist

1. Read all three v2 documents, status, last journal entry and the relevant gap/scope records. Resolve conflicting old-bundle policies in favor of this revision; retain old records as history.
2. Inspect git state and actual authority; preserve unknown work. Record `target_profile`, `first_milestone`, enabled extensions and exact current goal.
3. Inspect owned processes/Simulators, source pins, input snapshots, ruleset and cache identity. Stop stale owned runs without disrupting others.
4. Identify and back up the disposable save/profile. Record available physical hardware without assuming it is connected or authorized.
5. Check probe budget and evidence for any proposed route reopening.
6. State one hypothesis, expected observation and smallest next step; enter the loop.

## Session end checklist

1. Stop owned games/peers and the owned Simulator; verify no accidental test process remains.
2. Run relevant regressions and highest-good gameplay smoke, or record precisely why it could not run.
3. Record spec/profile/goal, route/input/ruleset, source/artifact/save identities, test evidence, observed result and defect class.
4. Update status, gap/scope ledger and per-platform/extension matrix. Keep unrun, blocked and deferred distinct from pass.
5. Run safety checks before any local commit; no public push or release.
6. Leave one next action for the lowest unmet dependency, or an exact physical/input/rights handoff. Report an iPad milestone accurately without calling unfinished iPhone or optional work complete.
