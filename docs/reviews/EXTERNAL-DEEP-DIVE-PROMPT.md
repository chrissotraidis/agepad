# Independent deep dive: AgePad feasibility and runtime failures

You are reviewing an active engineering effort in the `agepad` repository. Inspect the actual repository, private local reference files, build artifacts and logs. Research relevant upstream implementations and current platform constraints using primary sources. Return a rigorous report that another coding agent can ingest to redirect its ongoing goal loop.

Do not merely validate the existing approach. Identify wrong assumptions, wasted work, missing prerequisites, unsafe implementation shortcuts, and better routes to the same user outcome. Distinguish observations, source-derived explanations, hypotheses and untested proposals.

## The actual objective

Run the **actual Age of Empires II: Definitive Edition engine locally on an iPad**, with usable touch controls, good sustained gameplay performance, and multiplayer in the supported retail ecosystem. Ideally users obtain the game through Steam and use their legitimate copy/account.

Hard user constraints:

- No streaming or remote-rendered game.
- No publisher-authorized port as the proposed solution.
- Do not substitute a recreated engine, classic/HD-only gameplay, a mock UI, or a component test for DE success.
- Simulator execution on this Mac is an initial engineering milestone. Physical iPad execution, performance, distribution feasibility and multiplayer are separate requirements.
- Distinguish any Mac-specific multiplayer ecosystem from Windows/console interoperability; verify rather than assume compatibility.

The user supplied Mac DE and an older Windows HD installation. At the last inventory, `ref/AoE2DE/Age Of Empires II.app/Contents/MacOS/Age Of Empires II` and `ref/Age2HD/AoK HD.exe` existed, but **Windows DE's `AoE2DE_s.exe` did not**. The user has been asked to add an installed Windows DE folder under `ref/WindowsDE`. Recheck: inputs may change. Do not assume the Mac app is an official/native build solely from its filename; inspect provenance, executable architecture and dependencies.

## Review workflow and preservation

Read `AGENTS.md` first. Exactly one Simulator may be booted/open: existing AgePad G5 iPad, UDID `574671AD-6F61-4558-9528-BF946DDB760A`. Check the real booted inventory before any Simulator interaction. Never start another device.

This is an independent review. Prefer read-only source/log inspection and isolated tests. Do not replace the installed app, rebuild active packaged binaries, edit the primary agent's source, modify game files/saves, change trust/security settings, enter credentials, or restart a process. Recommend concrete experiments for the primary agent to execute. If a test creates artifacts, use a separate `generated/external-review/` directory. Do not reset/clean the repository: it contains extensive preexisting changes and ignored vendor worktrees.

Never upload game binaries, private logs, account data, QR challenges, or local screenshots to external services. Use public research sources for upstream/platform questions. Never ask the user to put passwords or Steam Guard codes in the report/chat.

## Start with these files

- `docs/WINDOWS-DE-STATUS.md`: latest entries are near the top; some historical entries are appended/out of order. Read the latest evidence first.
- `docs/WINDOWS-DE-GOAL-LOOP.md`: full objective and investigation history.
- `dependencies.lock.json`, `port/windows/patches/{madeira,wine,fex,dxmt}.patch`.
- `scripts/run-madeira-signed-startup.py`, `scripts/observe-madeira-run.py`.
- `scripts/build-windows-https-probe.py`, `port/windows/WindowsHTTPSProbe.c`.
- `scripts/census-vmmap-band.py`.
- `tests/test-root-certificate-enumeration.py`.

Relevant ignored sources:

- `worktrees/madeira/FEX/`
- `worktrees/madeira/wine/`
- `worktrees/madeira/build/ntdll-unix/`
- `worktrees/madeira/build/crypto-unix/crypt32_unixlib_ios.c`
- `worktrees/madeira/research/dxmt/`
- `worktrees/madeira/app/Madeira/`

Use `rg --no-ignore`/`rg --files --no-ignore` for ignored sources/artifacts and `rg -a` for runtime logs containing NULs. Report claims with exact paths and line numbers, build/run identifiers, relevant log excerpts, and public source links where applicable. Historical comments are hypotheses/evidence from previous experiments, not automatically current truth.

## Current architecture and demonstrated progress

The current Windows route combines FEX x86-64 translation, Wine Windows APIs, signed ARM64EC containers/private DLL banks, and DXMT/Metal rendering inside a UIKit/Madeira app. Multiple guest Windows processes share one native host address space, requiring process-specific state isolation. Sixteen child banks and a 1 GiB JIT pool were used in recent Steam runs. Verify exact options in each `run.json`.

Demonstrated in the designated Simulator:

- Genuine Windows Steam renders its sign-in form.
- A controlled Windows Direct3D test samples and updates a texture correctly through Metal. A Simulator-specific encoded texture binding repaired zero direct texture IDs. This is not comprehensive graphics correctness or gameplay FPS.
- Source-owned Windows HTTPS probes pass HTTP 200 with certificate checking, revocation and automatic proxy discovery. A Crypt32 chain probe passes both default flags and Steam-observed `0x48000001`.
- After a concrete certificate-enumeration repair, genuine Steam retrieves its connection-manager directory, logs `ConnectionCompleted()` for a WebSocket connection and displays a clear QR sign-in challenge. This also occurred with certificate/HTTP tracing disabled.

NOT demonstrated: successful Steam authentication, actual Windows DE startup/gameplay, DE touch controls, sustained gameplay FPS, physical iPad execution, or retail multiplayer. The Simulator overlay's Present/FPS counters are known unreliable for the current rendering path. A live UIKit host is not proof of guest progress. At the last `devicectl` inventory, no physical device was found.

## Recently fixed bug: root certificate enumeration

Steam reported `CERT_TRUST_IS_UNTRUSTED_ROOT` while a standalone probe trusted a chain with the same certificate names. A diagnostic found the failing Steam store contained only five roots, despite another guest logging 120 imported roots. Its ISRG Root X1 SHA1 property was obtained successfully (`cabd2a79a1076a31f21d253635cb039d4329a5e8`). Logs then exposed deletion of that exact certificate.

Native `crypt32_unixlib_ios.c::enum_root_certs` had one global `loaded` flag and destructively consumed/freed a shared list. A later guest saw an empty host list; Wine's root-store reconciliation interpreted that as roots being removed and deleted previously imported roots.

The repair retains the immutable root list and uses mutex-protected enumeration cursors keyed by guest PEB. An extracted-function ASan/UBSan test covers interleaved owners, short-buffer retry, EOF and concurrent guests. Genuine Steam then progressed to directory retrieval/WebSocket/QR. Review the repair independently, including owner identity, PEB reuse, lifecycle, allocation failure, locking, repeated enumeration and whether errors can still be interpreted as empty trusted-root lists. Do not propose disabling certificate validation.

Evidence: `generated/steam-206-*`, runs `windows-steam-rootlookup-206`, `windows-steam-root-enumeration-206`, `windows-steam-root-fixed-quiet-206` under `generated/madeira-signed-startup/`. Source-built x64 Crypt32 is optionally staged with `--crypt32-dll` and a hash manifest.

## Immediate blocker: FEX memory fragmentation and unchecked failure

The quiet fixed run subsequently terminated. The agent withdrew its QR sign-in request; do not use that old QR. Authentication-session polling logged result 2 / transport error 2 before termination, but causality is not established.

Allocation-time evidence from `windows-steam-root-fixed-quiet-206/runtime-followup.log`:

- FEX host range `[0x7c00000000, 0x8000000000)` is 16 GiB.
- Request `0x1002000` bytes; native rounded size `0x1004000`; alignment `0x10000`.
- Wine scanner saw 1,887 views and a reported maximum gap `0x1000000`.
- Stop: `gaps-exhausted(bottom-up)`; **zero host mapping attempts**, errno 0.
- Allocation returns `STATUS_NO_MEMORY`.
- `FEXMem_CallRetStacks` is logged at NULL.
- Built symbol mapping places the first fault at `FEX::Windows::CallRetStack::InitializeThread`, container-relative offset `0x108f2c`.
- Unchecked failure leads to access at `0x1000`, secondary ntdll exceptions and the native fatal redelivery guard terminating the host.

Earlier snapshots showed similar total mapped/reserved bytes but different largest gaps (about 32 MiB versus 512 MiB). Snapshot gaps alone do not prove mappability. The historical `[span-census] live=` counter was misleading: it counted commit-only allocation calls and release attempts before success. Source labels now say `ALLOC_SUCCESS`, `RELEASE_ATTEMPT`, `call_balance`, with operation type; do not multiply the old counter by span size to infer a leak.

Inspect:

- `FEX/Source/Windows/Common/CallRetStack.h`
- `FEX/FEXCore/include/FEXCore/Debug/InternalThreadState.h`
- `FEX/FEXCore/Source/Interface/Core/JIT/BranchOps.cpp`
- `FEX/FEXCore/Source/Interface/Core/Dispatcher/Dispatcher.cpp`
- `FEX/FEXCore/Source/Interface/Core/Core.cpp`
- `FEX/Source/Windows/ARM64EC/Module.cpp`
- `FEX/External/rpmalloc/rpmalloc/rpmalloc.c`
- Native `virtual_ios.c` allocation, release, scan and reservation logic.

Distinguish live demand, fragmentation, retained/recyclable heaps, leaked reservations, private process-bank overhead, and ownership/protection bugs. Blindly freeing exited threads' heaps is unsafe because allocations can remain referenced across threads. Expanding limits without accounting for placement and physical-device constraints is not a demonstrated solution.

## Latest experiment at handoff: windows-209

The primary agent has just changed FEX's call/return prediction cache from 16 MiB to 8 MiB for `FEX_IOS_HOST`, introduced shared size/shift/offset constants, replaced three CALL/RET JIT guards' hardcoded bounds and the callback guard's hardcoded shift/default, and updated the geometry log.

**The FEX build, signed root container, and all 16 child banks now build successfully. The canonical FEX patch has been synchronized and reverse-apply checked.** Actual Simulator run `windows-callret8-depth-209` passes translated Windows recursion at depth 1,024 followed by 98,304 twice, checking the triangular sum and a volatile tag in every frame; guest exit is 0. The build disables tail-call optimization, and disassembly confirms real recursive calls. Inspect `port/windows/WindowsCallRetProbe.c`, `scripts/build-windows-callret-probe.py`, and the generated run evidence. This is limited recursion coverage, not callback/exception-unwind qualification. There is no explicit reset-event counter, so do not claim a measured number of cache resets.

Genuine Steam run `windows-steam-callret8-209` was launched with HTTP/certificate/startup tracing disabled. Its sustained stability and authentication have NOT been established at this handoff. Read its latest logs and manifest; do not assume a launched host is a healthy guest. The smaller cache may merely postpone exhaustion. Recheck the status document for subsequent experiments before relying on this snapshot.

Audit every consumer, hardcoded value, reset/decommit span, callback/sentinel push, pre/post decrement, predictor fallback, exception unwinding, signal handling and diagnostics that infer geometry. The current source still has unchecked reserve/commit failure handling. Propose proper failure propagation/cleanup as well as a sustainable memory strategy. The deep-recursion test above has passed; genuine Steam stability remains to be qualified. Assess what additional callback, exception, thread-lifecycle and allocation-failure tests are needed, and whether the smaller cache addresses the causal resource problem.

## Follow-up evidence: windows-210

The current209host was independently live at elapsed4:57, with ongoing Steam network activity, no fatal marker, and no captured FEX-band/constrained allocation failure. Three WebSocket connections occurred; the first two ended about61–62seconds later with 'Try another CM' / 'Failure' and remote disconnection. This is not authentication success. Consult the latest private logs for later lifecycle.

A separate hard limit was reached: all16 signed child banks were assigned to distinct owners, then another distinct child failed initialization before a bank-assignment message. `build/ntdll-unix/agepad_signed_ntdll.h::agepad_child_bank` has capacity16 and never recycles owners; `loader_ios.c::ios_load_child_ec_ntdll` returns failure on bank0 at precisely that point. Review process lifetime and child churn as well as address-space fragmentation. One stuck self-modifying-code fault and subsequent renderer/GPU launches are recorded, but their causal connection is unproved. Do not recommend blindly recycling banks while callbacks/native threads can outlive the guest, or treat increasing the cap as a sustainable solution. Determine what lifecycle evidence and teardown design would make reuse safe, or propose a better isolation architecture.

Latest211follow-up: eight retained bank owners have explicit process-exit records, so16banks do not imply16live guests. The first renderer terminates after an access violation at `libcef.dll` RVA`0x33e809d`, actual instruction `movl -0x1(%r8), %r9d`, preceded by a32bit load from R9+15 and addition of R14. Replacement renderer consumes bank16; the later GPU child is refused. See latest status and private211lifecycle/disassembly artifacts. Root cause of the bad data load and semantic meaning of exit`0xffff7003` remain unverified. Investigate original guest registers/data and translation correctness instead of masking the fault.

Latest217state supersedes the above pending-runtime snapshot: native214fix recognizes LDAPR B/H/W/X as reads rather than stores (exact encoding mask; actual-helper4096encoding regression plus controls, ASan/UBSan). Native/appbuild and canonical patch checks pass; deployed215candidate has reached multiple CM connections and clear QR without captured renderer AV/private-child refusal through8:55. Auth polling still has Result2/TransportError2. User has been asked to try LIVE QR sign-in; preserve this current session, do not restart. No authentication or DE success yet. Refer to status entries212–217 for exact capture limitations, alternate renderer faultRVA0x3344325, and missing native opcode in prior crash. Corrected metadata has not been shown causal for the original invalid pointer.

## Questions your report must answer

1. Is the architecture a credible route to actual DE on physical iPad with retail multiplayer? Which critical assumptions remain unsupported? Is stabilizing full Steam first necessary, or is a different sequence more informative while preserving legitimate ownership/authentication?
2. What is the first causal failure in the latest terminated run? What explains the reservation population and fragmentation? Give ranked, falsifiable hypotheses and evidence against alternatives.
3. Is the 8 MiB experiment correct and useful, merely postponing failure, or dangerous? Identify concrete defects and the smallest meaningful tests. Recommend a better design if warranted.
4. Is the root-enumeration fix robust beyond this one startup? What process-isolation bugs with the same pattern should be prioritized, based on actual code?
5. What blocks authenticated Steam, DE launch, physical-device execution, deployment to users, and multiplayer separately? Research current iPadOS JIT/AOT/signing/graphics constraints and upstream alternatives. Do not transfer macOS or Simulator results to iPad without evidence.
6. What exact user-provided inputs are still needed? Separate missing files/accounts/hardware from problems we can solve independently.
7. Are we spending effort on the right problems? Recommend which investigations to stop, continue or reorder. Do not give an unsupported percentage-complete estimate or promise success.

## Deliverable

Write a report to `docs/reviews/EXTERNAL-DEEP-DIVE-REPORT.md` if you have workspace access; otherwise return the complete Markdown report for the primary agent to save there. Put any scripts/logs you create under `generated/external-review/` and link them.

Include:

- An executive assessment with an explicit confidence level and its basis.
- A verified-state table: requirement, actual evidence, status, missing proof.
- Findings ordered by impact, with exact source/log citations and causal reasoning.
- A critique of the latest experiment and recommended patch design (do not silently apply it).
- A prioritized experiment queue. For each experiment: hypothesis, setup/commands, expected discriminating outputs, pass/fail criteria, risks and next action for either result.
- Concrete acceptance gates through: stable unauthenticated Steam; authenticated Steam; actual DE launch; sustained gameplay; physical iPad; touch; real multiplayer match without desync.
- A proposed revision of the goal loop, with stopping rules that prevent repeated low-value diagnostic iterations while retaining the full user objective.
- Public sources with links/access dates, plus unresolved uncertainties.

Your report will be ingested by the primary agent, checked against the current repository, saved, and used to revise its goal-based loop. Make it specific enough to drive the next code change or experiment—not another generic feasibility essay.
