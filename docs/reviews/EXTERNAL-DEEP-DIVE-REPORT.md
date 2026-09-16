# External deep dive: AgePad Windows-DE-on-iPad feasibility and runtime failures

Review date: 2026-09-09 (00:20–01:10 CDT). Reviewer: independent agent, read-only. Repository state at review: branch `codex/agepad-native-probe`, `docs/WINDOWS-DE-STATUS.md` at windows-213, live run `windows-steam-guestav-212` (host PID 98839) on the sole booted Simulator `574671AD-6F61-4558-9528-BF946DDB760A`. No Simulator interaction, no builds, no source edits, no game/save/trust changes were made. All review artifacts are under `generated/external-review/` (index in §11).

Labels used throughout: **[O]** observation (quoted from a file, log or primary source), **[S]** source-derived explanation (reasoning from cited code/docs), **[H]** hypothesis (falsifiable, not yet tested), **[P]** proposal (untested design).

---

## 1. Executive assessment

**Confidence: medium-high** on the failure analyses in §3–§5 (every claim is tied to a log line or source line that I or a sub-audit read). **Medium** on the physical-device constraints in §6 (primary Apple/XNU sources plus the upstream project's own device measurements, but no measurement on the user's iPad). **Low** on end-to-end feasibility of the full objective, because the four load-bearing assumptions below have no evidence yet.

1. **The immediate blocker is understood and is not a mystery.** [O/S] The 206 termination is a deterministic chain: FEX-internal reservations fill the 16 GiB host band at ~80 MiB per guest thread (≈140 live threads across 16 pseudo-processes, plus reservations retained by exited pseudo-processes); the call/return stack is merely the first consumer with no fallback, and it fails first because its request (16 MiB + 2 guard pages) can never fit the exactly-16 MiB holes that FEX's own pools recycle; the unchecked NULL then becomes a read at `0x1000` and a redelivery storm. The 8 MiB change lets the request fit 16 MiB holes and defers the failure by roughly one GiB of band; it does not change the per-thread cost (still ~80 MiB, unchanged stride in 209) and the null crash path is untouched. Details §3, §4.

2. **The next wall is already visible and is the same pattern.** [O] Run 209 exhausted all 16 signed child banks in about nine minutes because Steam's CEF helpers churn (206 launched 28 `--type=utility`, 14 `--type=gpu-process`, 7 `--type=renderer` helpers) and banks, PEB-keyed registries, proc-socket tables and fd caches are never recycled. Finite, never-recycled per-process resources are the dominant structural defect of the current architecture, not any single allocation.

3. **The Simulator is not memory-representative of the iPad, and the current Steam configuration has never been checked against device limits.** [O] Run 206 placed CEF's 16 GiB PartitionAlloc pool at `0x58cc00000000` (88 TiB), an address that exists only under the macOS kernel. [O] On the device the upstream project measured exactly one usable ~63 GiB window above the GPU carveout and, for that reason, forces `steamwebhelper` into single-process mode. The primary agent's `--retail-processes` multi-process Steam with 16 banks and a 1 GiB JIT pool is therefore a Simulator-only configuration. Gate W2 (device) was explicitly allowed to precede W1 in the goal loop and has never been attempted; no physical iPad has been connected.

4. **Four assumptions remain unsupported for the actual objective:** (a) that the whole stack (Steam client + DE + FEX metadata) fits the device's resident-memory ceiling (upstream measured a hard 4096 MB jetsam limit on a 6 GB phone; DE's own recommendation is 8 GB; the user's iPad appears to be an 8 GB iPad Air M4); (b) that DE's Windows build runs correctly under FEX's shipped accuracy settings (`X87ReducedPrecision=false` is good for lockstep determinism, but `VectorTSOEnabled=false` is a deliberately accepted memory-ordering gap, and `AoE2DE_s.exe` carries in-house anti-tamper and debugger checks); (c) that a sideloaded, StikDebug-enabled app is an acceptable "deployment" for users, because no App Store, TestFlight or EU-notarized channel permits this stack; (d) that a Windows DE binary will arrive, since the loop has spent ~125 of 213 iterations on Steam client plumbing without the game.

5. **Sequencing recommendation (§8, §9):** stop treating full-Steam stability as the gating milestone. Run the device gate now with the existing small probes, fix the finite-resource lifecycle once (banks, PEB registries, thread teardown, CallRetStack stride and failure propagation), and, when the Windows DE input exists, qualify the DE engine to its Steam-init gate with Steam absent. DE is a far simpler workload than Steam (no CEF, one process); most graphics, page-size, anti-tamper and FPS risk can be retired without a login. Genuine QR login remains required for ownership and is unchanged as an acceptance gate; it is just not the first thing to spend runs on.

The rest of this report gives the evidence, the defects, a patch design for the pending experiment, a prioritized experiment queue with pass/fail criteria, acceptance gates, and a revised loop with stopping rules.

---

## 2. Verified-state table

| Requirement | Actual evidence (path) | Status | Missing proof |
|---|---|---|---|
| Windows x64 code executes under FEX/Wine in the designated Simulator | windows-009/011 CPU + D3D11 draw/readback; windows-190 texture sampling (`docs/WINDOWS-DE-STATUS.md:182-215`) | Demonstrated (bounded) | Not comprehensive graphics correctness; Simulator FPS overlay unreliable |
| Genuine Windows Steam reaches sign-in UI | 206: QR rendered, `ConnectionCompleted` WebSocket (`docs/WINDOWS-DE-STATUS.md:41`); 209/210: three `ConnectionCompleted`, "Try another CM"/"Failure" logon responses (`:53-55`) | Demonstrated (unauthenticated) | Session survives >30 min; no bank exhaustion; no renderer crash |
| Root-certificate store fix | `worktrees/madeira/build/crypto-unix/crypt32_unixlib_ios.c:853-899`; test `tests/test-root-certificate-enumeration.py` passes | Fixed for this app lifetime | PEB reuse, OOM path, empty-load latch (§5) |
| CallRetStack exhaustion | 206 `runtime-followup.log:199172-199190`; 209 no scan failure over ~9 min with 199 stacks | Deferred, not fixed | Failure propagation; per-thread band cost unchanged |
| Child-process capacity | 210: all 16 banks assigned, later GPU child refused (`docs/WINDOWS-DE-STATUS.md:49-59`) | **Failing** | Lifecycle/teardown design; device-scale capacity |
| Steam authentication | none | Not attempted (correctly deferred) | Stable unauthenticated session first |
| Windows DE binary present | `ref/WindowsDE` absent; no `AoE2DE_s.exe` under `ref/` (`generated/external-review/inventory-2026-09-09.md`) | **Missing input** | User must supply installed Windows DE |
| DE launch / menus / skirmish | none | Not started | Input above |
| Physical iPad execution | `xcrun devicectl list devices` → "No devices found" | Not started | Device connected; signing team; StikDebug; entitlements |
| Physical memory budget | Simulator RSS 2.5 GB at 2 min (Steam only, PID 86564); upstream device ceiling 4096 MB on 6 GB phone | **Unknown on device** | `os_proc_available_memory` on the user's iPad with increased-memory-limit |
| Touch controls for DE | none | Not started | DE running |
| Sustained gameplay FPS | none | Not started | DE running on device |
| Retail multiplayer match | none | Not started | Everything above; second retail Windows client |
| Mac DE interoperability | `ref/AoE2DE` is Feral's native arm64 build (codesign: Feral Interactive Ltd, notarized, 1.1.2/478570.102902); official support: Mac plays Mac only (§6.4) | Verified: separate pool | — |

---

## 3. Findings ordered by impact

### F1. Finite, never-recycled per-process resources are the dominant structural defect [O/S]

- [O] Banks: `agepad_signed_ntdll.h:6-26` caps banks at 16 and retains owners for host lifetime; 210 observed the 17th distinct guest refused. Run 206 consumed all 16 `[proc-ident] ... (slot N)` entries in ~5 minutes; 209 in ~9 minutes.
- [O] Registries with monotonically increasing counters and no slot reuse: `build/ntdll-unix/server_ios.c:310-323` (`ios_proc_sockets`, 64 max, freed slots never reused; on overflow the exit path closes the parent's `fd_socket`, the "3-deep-tree bug" described at `:167-176`), `server_ios.c:1571-1600` (`ios_fd_caches`, on overflow falls back to the shared cache that caused the ml570/571 stale-inode bug), `loader_ios.c:345-352` (`ios_proc_idents`, 64), `class_ios.c:108-109,336-356` (64), `virtual_ios.c:2698-2700`.
- [O] Child PEBs are `mmap`ed at `loader_ios.c:3242` and never unmapped; `process_exit_wrapper` (`server_ios.c:2257-2295`) releases only the fd cache and JIT-pool ledger; FEX `ProcessTerm` is empty (`Module.cpp:1158`), so an exited pseudo-process leaves all of its threads' band reservations in place (§4).
- [S] Steam's helper churn is normal CEF behaviour (utility processes are short-lived by design). Any architecture whose per-process resources are consumed monotonically will exhaust in tens of minutes regardless of the other fixes. Raising the caps only moves the wall and increases VA/memory demand (correctly noted at `docs/WINDOWS-DE-STATUS.md:57`).
- Impact: blocks *stable unauthenticated Steam* (the first acceptance gate in §8) independently of the call/return fix.

### F2. The FEX band failure is live demand plus retention, decided by a size-class mismatch [O/S]

Full analysis in §4. Short form: ~80 MiB of band VA per guest thread (rpmalloc 16 MiB spans ×2–3, OpDispatcher 16 MiB, Frontend 8 MiB, CallRetStack 16 MiB + guards, L1 2 MiB), ~140 live threads at failure, plus reservations of exited pseudo-processes; the CallRetStack fails first because 16 MiB + 16 KiB cannot fit an exactly-16 MiB hole.

### F3. The pending 8 MiB experiment is consistent but is a postponement, and the crash path is untouched [O/S]

Details §5.1. Two diagnostic consumers were missed (`Core.cpp:1670`; `build/ntdll-unix/signal_arm64_ios.c:8250-8255` and `:8040`), the Wine files are not in any canonical patch, and the same mismatch reappears one size down (8 MiB + 16 KiB cannot fit an exactly-8 MiB Frontend hole).

### F4. The Simulator configuration is not device-representative for memory [O/S]

- [O] `L206:9124 [bigres-use] POOL 0x58cc00000000 +16384MB` (CEF PartitionAlloc at 88 TiB). [O] iPhoneOS 26.5 SDK `usr/include/mach/arm/vm_param.h:88`: `MACH_VM_MAX_ADDRESS_RAW 0x0000000FC0000000ULL` (63 GiB); GPU carveout `[0x1000000000, 0x7000000000)`. [O] Upstream field measurement (`worktrees/madeira/STEAM_CEF_HANDOFF.md:30-41`): "Usable CPU virtual address space is ~64 GB, not 512 GB"; "the 64GB VA window above the GPU carveout can hold exactly ONE CEF instance's PartitionAlloc pools + one V8 sandbox" (`process_ios.c` forces single-process `steamwebhelper` on device).
- [O] `virtual_ios.c:12255` is the only `TARGET_OS_SIMULATOR` guard in the unix layer; the band layout is emulated, but the kernel-picked addresses (furniture spill, PA pool) are macOS-only.
- [S] Everything measured about memory geometry in the Simulator (16 banks, multi-process CEF, 1 GiB JIT pool, 16 GiB band + 16 GiB PA pool + furniture) must be re-derived on the device. This is the single strongest argument for running W2 now with the small probes, before more Steam runs.

### F5. Physical-memory budget is the likely hard wall on an 8 GB iPad [O/H]

- [O] DE minimum 4 GB / recommended 8 GB RAM, D3D11, 15–30 GB on disk (Steam store page; PCGamingWiki). [O] Steam alone reached 2.5 GB RSS at two minutes in the Simulator (PID 86564). [O] Upstream measured a hard 4096 MB jetsam ceiling on a 6 GB iPhone 13 Pro with `increased-memory-limit`. [SECONDARY] Developer reports: ~12 GB per app on 16 GB iPad Pro, ~6 GB on 8 GB models with the entitlement.
- [O] The user's Simulator is named for an "owned iPad Air11 M4" (`docs/PLATFORM-MATRIX.md:8`), an 8 GB device.
- [H] Steam client (CEF) + DE under FEX (JIT code, metadata, translated-code caches) on an 8 GB iPad will exceed the foreground limit during gameplay. Falsify on device with `os_proc_available_memory()` and a DE launch; if the ceiling is ~6 GB, plan for Steam to be terminated/suspended after launch (which breaks Steamworks) or restrict to 16 GB iPads.

### F6. Device JIT and distribution constraints are firm and unmet [O]

- [O] `com.apple.security.cs.allow-jit` is macOS-only (Apple docs; `EntitlementChecker.swift:47-51` says the same). [O] The only working route on iPadOS 26 is sideload + `get-task-allow` + StikDebug/StikJIT with every executable region prepared over the debug connection before detach (StikJIT `INTEGRATION.md`); StikDebug is not on the App Store. [O] App Review 2.5.2/4.7.2/3.1.1 and EU notarization ("cannot download executable code") each independently exclude this stack. [O] Upstream README: "this app cannot be distributed through the App Store".
- [O] `Madeira.entitlements` lacks `com.apple.developer.kernel.extended-virtual-addressing` (listed as desired in `app/source.json:27`; Apple's capability table shows it available to free accounts). `project.pbxproj` `DEVELOPMENT_TEAM = UT49TA9TA4` is the upstream author's team; the user's own team is required.
- [S] "Deployment to users" therefore means: user-owned developer signing (7-day resign on a free account, yearly on paid, 100 devices ad hoc), StikDebug sideloaded, LocalDevVPN, pairing file. The report cannot make this more favourable; it should be stated to the user as a constraint, not discovered later.

### F7. Multiplayer interoperability: Windows pool yes, Mac pool no, determinism unproven [O/H]

- [O] Feral's Mac DE (the supplied `ref/AoE2DE` app: Mach-O arm64 thin, Feral Developer ID, PlayFabParty/Xal/xsapi frameworks) plays only against Mac players per official support; the Windows build joins the unified Steam/Xbox/PlayStation pool on the same game build. [S] So only the Windows binary can satisfy the retail-multiplayer requirement, which is consistent with the current route.
- [O] DE is deterministic lockstep with RelicLink matchmaking and PlayFab Party transport (RedRocket reversing; Mac bundle frameworks). [H] Under FEX, desync risk comes from x87 precision (`X87ReducedPrecision=false` shipped, good), FTZ/DAZ and vector ordering (`VectorTSOEnabled=false`, `MemcpySetTSOEnabled=false`, `HostFeatures=disableavx` shipped: `FEX/FEXCore/Source/Interface/Config/Config.json.in`), and 16 KiB host pages under Wine's 4K simulation. No test exists yet. The W5 gate needs a replay-comparison test before a live match.
- [O] `AoE2DE_s.exe` has in-house anti-tamper and `IsDebuggerPresent`-style checks; no EAC/BattlEye. [H] Wine's `PEB.BeingDebugged` and StikDebug detach timing may interact; test at DE launch.

### F8. The root-enumeration fix is correct for this app lifetime but has three latent regressions [O]

Details §5.2. The fix depends on PEB addresses never being reused (true today because child PEBs are never unmapped), returns `STATUS_NO_MEMORY` on `calloc` failure which the PE side treats as end-of-list and then deletes every imported root (verified with the extracted function: `generated/external-review/crypt32-review/enum_reuse_oom.out`), and latches `loaded` even if the first load produced zero roots.

### F9. The loop's evidence handling is strong but its budgeting is weak [O]

- [O] 213 iterations in ~21 hours (windows-001 at 2026-09-08 04:45 CDT; windows-213 by 01:00 CDT 09-09); 266 run directories; `generated/` 24 GiB; `docs/WINDOWS-DE-STATUS.md` 398 KB with historical entries out of order. Roughly windows-083 through windows-186 (about 100 iterations) were CEF IPC/JIT-flush/renderer forensics; windows-191 through 206 were Steam transport/certificates; 210–213 are again renderer fault forensics.
- [S] The methodology (falsifiable hypothesis, one bounded change, evidence) is good. What is missing is a per-hypothesis run budget and a rule that forbids diagnostic-only runs when a behaviour-changing fix is already known (e.g., failure propagation at `CallRetStack.h:56`, known since 207, still unimplemented at 213).

### F10. Minor but real [O]

- `Core.cpp:1670` diagnostic string still says `guard_window=[+0x200000,+0x600000)`.
- `Module.cpp:2118-2128`: `ThreadTerm` returns early without `DestroyThread` when the thread is not found in `Threads`; a leak path if registration ever misses.
- `LookupCache.cpp:66,85` checks for `-1` but the allocator returns `nullptr` on failure (`AllocatorHooks.h:116-119,143-146`), so the check cannot fire.
- `AllocatorHooks.h:128-131`: generic FEXMem allocations silently fall through to an unconstrained top-down `VirtualAlloc2` when the band is exhausted; only CallRetStack and rpmalloc refuse. That is why CallRetStack is the first hard failure and why band exhaustion is otherwise invisible.
- The 209 Simulator screenshot capture is upside-down; unrelated to the guest, noted at 206/207.

---

## 4. Question 2: first causal failure in the terminated run and the reservation population

### 4.1 Chronology (`windows-steam-root-fixed-quiet-206/runtime-followup.log`, hereafter L206) [O]

Timestamps stop at `L206:167` (`[00:03:54.561]`); later ordering is by line. External logs place the failure between 00:06:04 and 00:06:44 UTC-5.

1. `L206:299,313`: rpmalloc selects `[va-profile] ml706 SELECTED base=0x7c00000000 end=0x7fffffffff` per pseudo-process; each does a 256 MiB reserve/release probe (`rpmalloc.c:987-994`).
2. Per-thread pattern (`L206:470-495`): 16 MiB rpmalloc span (`FEXMem_ThreadState`), `FEXMem_Lookup_L1` 2 MiB, `FEXMem_BlockLinks`, `FEXMem_CallRetStacks 0x7c03000000..0x7c04002000` (16 MiB + 8 KiB → host 16 MiB + 16 KiB), later `FEXMem_OpDispatcher` 16 MiB and `FEXMem_Frontend` 8 MiB (`L206:926`).
3. CallRetStack bases climb monotonically: ordinal 0 → 0.05 GiB, 50 → 4.45 GiB, 100 → 8.25 GiB, 150 → 12.83 GiB, 186 → 15.94 GiB (`generated/external-review/fex-memory/thread_bank_timeline.py`). Only 17 of 187 placements reuse a lower hole. Median stride between fresh placements: **80 MiB per thread**.
4. Seven pseudo-process exits before the failure (`L206:6918, 6977, 24025, 37544, 37633, 78663, 81164`); 16 bank slots created.
5. `L206:199147`: last 16 MiB span fits at the very top (`0x7fff000000`); `L206:199172`: `[AgePad-fex-scan-failure] ... size=1002000 host_size=1004000 align=10000 top_down=0 tries=0 ... views=1887 maxgap=1000000 stop=gaps-exhausted(bottom-up) ... errno=0 tid=358`; `:199173` `STATUS_NO_MEMORY`; `:199174` `[vname] FEXMem_CallRetStacks 0x0..0x1002000`.
6. `L206:199175-199190`: `SEGV #1: pc=0x3c84f0f2c addr=0x1000 ... x0=0x0 x2=0x1000` at `xtajit64-child-16.dll.dylib` `+0x108f2c` (`CallRetStack::InitializeThread` → `ZeroScrub`), `[cpu-area] no-state-at-exception ... StateFrame(ED0)=0x0`.
7. `L206:199193` second SEGV at `addr=0x0` in ntdll-child-16; `:199295` onward ~250 `SEGV LOOP FATAL`; `:205216` `[AgePad-abort-thread] ... remaining=137` (137 guest threads still alive); `:206790` identical failure for tid 0x360; `:207629` `[redeliv] 256 identical redeliveries`; `:209580` `[redeliv] terminating process rev=ml465`.

Correction to the handoff premise: `align=10000` is 64 KiB. The 16 MiB-aligned variant failed in the *previous* run in the same container (`previous-runtime.log:735268`, `maxgap=a10000`); 206 fails on size, not alignment.

The Steam "auth-session polling result 2 / transport error 2" lines are downstream of the CM disconnects and are not causally connected to the native failure by anything in the log; 210 later observed the same "Try another CM"/"Failure" responses on a healthy host.

### 4.2 Why 1,887 views with `maxgap` exactly 16 MiB [S]

- `map_free_area` (`virtual_ios.c:6730-6810`) walks Wine's view tree bottom-up; `maxgap = view->base - start` (`:6789-6791`); `try_map_free_area` (`:6633-6635`) only calls `mmap` when `start + size <= end`, so if every gap is `< host_size` no host mapping is attempted (`tries=0`).
- The band's unit sizes are all exactly 16 MiB: rpmalloc `SPAN_SIZE` (`rpmalloc.c:218`), OpDispatcher buffers, CallRetStack commit. Every recycled hole is therefore 16 MiB (or 16 MiB + 64 KiB slack). A 16 MiB + 16 KiB request cannot recycle them and is pushed to virgin space at the top, producing the monotonic climb. Freed CallRetStack holes are reused only while intact (`L206:6787→7164`); once nibbled by an 8 MiB Frontend or 16 MiB OpDispatcher buffer (`L206:37182→37258`) they never fit again.
- Kernel corroboration: steam-198 vmmap shows 896 inter-run gaps of which 440 are exactly `0xc000` and 139 exactly `0x4000`, the signature of `0x1004000` views tiled at 64 KiB (`generated/external-review/fex-memory/vmmap_band_runs.py`); band 13.85 GiB mapped, **0.82 GiB resident**. Exhaustion is VA reservation, not physical memory.
- The band holds only FEX-internal allocations. CEF's pool is at `0x58cc00000000`; guest furniture scans use `0x7038000000..0x73ffff0000`. The 256 `gaps-exhausted` lines in 209 are all furniture-window `[va-scan] FAILED ... errno=17 --> relaxing ceiling` records (64-try budget on foreign Mach mappings), not band failures; benign in effect.

### 4.3 Band budget at failure (cumulative `[vname]`, frees not subtracted) [O/S]

| class | count | cumulative | source |
|---|---|---|---|
| FEXMem_CallRetStacks | 187 | 2.92 GiB | `CallRetStack.h:33,56` |
| FEXMem_OpDispatcher (16 MiB) | 168 | 2.63 GiB | `Context.h:405`, `ThreadPoolAllocator.h:388` |
| FEXMem_Frontend (8 MiB) | 166 | 1.30 GiB | `Context.h:406` |
| FEXMem_Lookup_L1 (2 MiB) | 188 | 0.37 GiB | `LookupCache.cpp:62-70,118` |
| CPUBackend/BlockLinks/ThreadState | ~770 | ~0.11 GiB | |
| named total | | 7.32 GiB | |
| unnamed rpmalloc spans (16 MiB, 2–3 per thread at creation, more as heaps grow) | ≈790 | ≥8.7 GiB by subtraction | `rpmalloc.c:218` |

`[span-census]` reached `ALLOC_SUCCESS #2208` vs `RELEASE_ATTEMPT #208`, `call_balance=1999` (`L206:205962`); the counter includes commits and is sampled, so it is not a live count, but the 10:1 ratio and the monotone climb are consistent with a near-solid band.

### 4.4 Retention [O/S]

- Thread teardown does free: `Module.cpp:2080-2166 ThreadTerm` → `CallRetStack::DestroyThread` (`MEM_RELEASE`) → `CTX->DestroyThread` → `rpmalloc_thread_finalize` (`rpmalloc.c:3300-3306`) → `heap_release` (`:2362-2374`), which only queues the heap; spans are not unmapped on thread exit. Pool buffers return to a process-wide pool freed at most one per claim after 5 s idle (`ThreadPoolAllocator.h:204,268-292`).
- Pseudo-process exit frees nothing in the band (§F1). Of the 16 CallRetStack regions belonging to the two exited processes at `L206:78663` and `:81164`, 12 are never referenced again while later threads were placed above 15 GiB (`generated/external-review/fex-memory/refill_check.py`): consistent with never-released reservations. Only 29 `[thr-term] deinit` for 189 created threads.
- Each child bank has its own rpmalloc instance, so a child's queued heaps are reusable only by new threads of the same pseudo-process.

### 4.5 Ranked hypotheses with falsification [H]

1. **Live demand ≈ 80 MiB/thread × ~140 threads + retained reservations fills 16 GiB; CallRetStack is the first consumer with no fallback.** For: stride 80 MiB, `nb_threads=137`, 209 lowered the top-of-band by only ~1 GiB at equal ordinal (15.88 → 14.88 GiB) with the same stride. Against: named bytes total 7.3 GiB; the remainder is inferred. Falsify: E1 (unsampled, result-aware, PEB-tagged span census); if live reservations at failure sum to ≪16 GiB, this is wrong.
2. **Size-class mismatch decides which request fails first.** For: `maxgap` exactly `0x1000000`; 440 × `0xc000` gaps; 209 reused holes 37 times vs 17. Against: does not change total occupancy. Falsify: E3 (reserve exactly 16 MiB including guards); the failure should move to another consumer or later ordinal.
3. **Pseudo-process exit leak.** For: empty `ProcessTerm`, 24 threads / ≥0.94 GiB named in exited processes. Against: 1–2 GiB of 16. Falsify: E4 (per-PEB teardown at `process_exit_wrapper`); the failure ordinal should move by ≈ leaked bytes / 80 MiB.
4. **rpmalloc heap retention per bank.** For: `heap_release` semantics; 16 instances. Against: windows-201's warning that freeing exited-thread spans corrupted live containers. Falsify: log `global_heap_queue` length and mapped spans per instance at failure.
5. **Stale Wine views (bookkeeping).** Against: kernel vmmap agrees the band is solid; freed early holes are reused. Falsify: E2 (kernel walk of the band at scan failure).
6. **Bank overhead / JIT pool.** Excluded: the 256 MiB probe is released; `FEXMemJIT` is at `0x300004000`, outside the band.

---

## 5. Questions 3 and 4: the pending experiment and the root-enumeration fix

### 5.1 The 8 MiB CallRetStack experiment (now deployed as 209/212) [O/S]

State: canonical `port/windows/patches/fex.patch` matches the FEX working tree (`git apply --check -R` passes: `generated/external-review/callret-audit/wt-full.diff`); 16 banks rebuilt; probe `port/windows/WindowsCallRetProbe.c` PASS at depths 1024/98304/98304; genuine Steam ran ~9 minutes with 199 stacks and no scan failure.

Correct and internally consistent:
- `InternalThreadState.h:112-127`: `CALLRET_STACK_SHIFT` 23 (iOS) / 24, `CALLRET_STACK_SIZE = 1 << SHIFT`, `DEFAULT_OFFSET = SIZE/4`, `LIVE_OFFSET = SIZE/8`, `LIVE_SIZE = SIZE/4`, `LIVE_SHIFT = SHIFT-2`, with `static_assert`s.
- Three JIT guards (`BranchOps.cpp:195-201, 255-261, 335-341`) and the callback guard (`Dispatcher.cpp:723-728`) use the constants; geometry log (`CallRetStack.h:111-116`) matches the 209 log (`size=0x800000 guard-window=[base+0x100000, base+0x300000)`, default `+0x200000`).
- Correctness is unaffected by size on iOS: the RET prediction is discarded (`BranchOps.cpp:300 (void)SkipFullLookup;` under `FEX_IOS_HOST`) and every RET goes through the L1 lookup; the cache's only effects are the guarded push/pop stores and reset frequency. Full clears (`Core.cpp:708-716`) still cover the full region.

Defects and misses:
1. **Unchecked failure remains** (`CallRetStack.h:56,68-74,87`; `Module.cpp:1806,2077`; Wine `loader.c:5602` discards `arm64ec_thread_init()` status). The next fragmentation miss crashes identically.
2. **Missed consumers**: `Core.cpp:1670` diagnostic string; `build/ntdll-unix/signal_arm64_ios.c:8250-8255` (`dflt = cr[1] + 0x400000`, "% of 4MB", now off by 131,072 entries) and `:8040` (`base + 0x1000000`, accepts sp up to 8 MiB past the end). Those two Wine files are not in any canonical patch: the build tree is their only source of record.
3. **Same pathology one size down**: 8 MiB + 16 KiB cannot fit an exactly-8 MiB Frontend hole; long sessions with thread churn will reproduce the failure.
4. Stale comments (`BranchOps.cpp:177-189`; `CallRetStack.h:80`); the ml609/ml610 explanation of why the clear must cover the full size was deleted from the header (two-line remnant at `:127-128`).
5. `CallRetStack.h:27-28` still spells the default as `SIZE/4` instead of the named constant.

The depth probe: [S] depth 98304 does cross both reset boundaries (window headroom is 65,536 entries each way), but nothing records a JIT-guard reset; `[callret] ml610` and `[CALLRET_OOB]` count other paths and read 0; the callback-sentinel guard (`>> CALLRET_STACK_SHIFT`) was not exercised (`[cb-entry]`=0). PASS shows the guarded stores stayed inside writable memory, not that the reset boundaries behaved. Sufficient as a smoke test; insufficient as a boundary test.

**Verdict:** useful mitigation, a postponement, not dangerous for correctness. The hazard is the unchecked null.

### 5.2 Recommended patch design (not applied) [P]

A. **Failure propagation** (smallest change, do first):

```cpp
// Source/Windows/Common/CallRetStack.h
[[nodiscard]] NTSTATUS InitializeThread(FEXCore::Core::InternalThreadState* Thread) {
  const size_t AllocSize = TS::CALLRET_STACK_SIZE + 2 * FEX_PAGE_SIZE;
  void* Alloc = ::VirtualAlloc2(nullptr, nullptr, AllocSize, MEM_RESERVE, PAGE_NOACCESS, &AddrParam, 1);
  if (!Alloc) {
    LogMan::Msg::EFmt("[callret] RESERVE FAILED size={:#x} band=[{:#x},{:#x}) gle={:#x}",
                      AllocSize, ios_fex_band_base, ios_fex_band_end, GetLastError());
    Thread->CallRetStackBase = nullptr;
    Thread->CurrentFrame->State.callret_sp = Thread->CurrentFrame->State.callret_sp_base = 0;
    return STATUS_NO_MEMORY;
  }
  VirtualName(...); VirtualTHPControl(...);
  Thread->CallRetStackBase = (char*)Alloc + FEX_PAGE_SIZE;
  if (!::VirtualAlloc(Thread->CallRetStackBase, TS::CALLRET_STACK_SIZE, MEM_COMMIT, PAGE_READWRITE)) {
    LogMan::Msg::EFmt("[callret] COMMIT FAILED base={:#x} gle={:#x}", (uint64_t)Thread->CallRetStackBase, GetLastError());
    ::VirtualFree(Alloc, 0, MEM_RELEASE);
    Thread->CallRetStackBase = nullptr;
    return STATUS_NO_MEMORY;
  }
  /* ZeroScrub, sp/base init, geometry log unchanged */
  return STATUS_SUCCESS;
}
void DestroyThread(TS* Thread)            { if (!Thread->CallRetStackBase) return; /* unchanged */ }
bool HandleAccessViolation(TS* Thread, …) { if (!Thread->CallRetStackBase) return false; /* unchanged */ }
```

```cpp
// Source/Windows/ARM64EC/Module.cpp, ThreadInit()
if (const NTSTATUS St = FEX::Windows::CallRetStack::InitializeThread(Thread); !NT_SUCCESS(St)) {
  delete[] NewSegments;
  CTX->DestroyThread(Thread);
  ::VirtualFree(reinterpret_cast<void*>(EmulatorStack), 0, MEM_RELEASE);
  CPUArea.ThreadState() = nullptr; CPUArea.StateFrame() = nullptr;
  CPUArea.DispatcherLoopTopEnterEC() = 0;   // never let x86 entry BLR into a half-built area
  return St;
}
```
Also check `Module.cpp:1743` (emulator stack) and `:1750` (`CTX->CreateThread` null) the same way, and fix `LookupCache.cpp:66,85` to test `nullptr`.

```c
/* wine dlls/ntdll/loader.c:5602 */
if (!NT_SUCCESS(status = arm64ec_thread_init()))
{
    ERR( "arm64ec thread init failed %lx\n", status );
    if (NtCurrentTeb()->ClientId.UniqueThread == first_thread_id) NtTerminateProcess( 0, status );
    RtlExitUserThread( status );
}
```
Without the Wine change a status from `ThreadInit` changes nothing: the thread proceeds and dies at the first dispatch with `StateFrame(ED0)=0x0`, exactly `L206:199189`. A thread must never run with `callret_sp_base == 0`: the JIT guard computes `(0-0)>>shift == 0`, passes, and stores at `-0x10`.

B. **Geometry** (fixes the mismatch, second): make the reservation stride a power of two *including* guards. Either reserve exactly 16 MiB (or 8 MiB) total and set `SIZE = STRIDE - 2*host_page` with a compare-based guard instead of a shift, or (preferred) carve stacks from a slot arena reserved once at `ProcessInit`: `N × STRIDE` with `STRIDE = SIZE + 2×16 KiB` rounded to 64 KiB, bitmap under `ThreadCreationMutex`, `VirtualDontNeed` on release and `MEM_COMMIT` on reuse. This removes the per-thread scan over 1,887 views, makes the guard pages real (neighbours are other slots' guards), and turns exhaustion into one explicit logged condition. Apply the same stride discipline to OpDispatcher/Frontend pools if E1 shows they dominate.

C. **Lifecycle** (F1): per-PEB teardown at `process_exit_wrapper` for the exiting pseudo-process's FEX threads (call `ThreadTerm`-equivalent under the existing thread list), release its cursor/registry slots (`server_ios.c:2277` is the right place), and only then design bank reuse with a quiescence check (no live callbacks/native threads referencing the bank). Do not recycle banks blindly (agreed with `docs/WINDOWS-DE-STATUS.md:57`).

### 5.3 Tests for the call/return change [P]

Minimum, in order (each is a guest x64 `.exe` in the existing harness):
1. Guard-reset counters: in each guard's cold path add `State.callret_guard_resets[3]`; print in `[thr-term]`. Pass: depth-1024 → 0; depth-98304 → call ≥1 and ret ≥1 per iteration; callback 0.
2. Leak-then-wrap via SEH: `RaiseException` at depth 70,000, catch at depth 0, repeat 4×. Pass: correct sums, ≥1 call-side reset per iteration after the first, 0 `[CALLRET_OOB]`, exit 0.
3. Fault + `NtContinue` at depth 60,000. Pass: exit 0, resets accounted for.
4. Native→guest callbacks (`QueueUserAPC` + `SleepEx(TRUE)`; 100 TLS-callback threads). Pass: exit 0; callback counter 0 or documented.
5. Thread exit while deep (64 threads at depth 70,000 then `ExitThread`). Pass: 64 `[vname] FEXMem_CallRetStacks`, 64 `[thr-term]`, bases repeat, no scan failure.
6. Fragmentation soak: churn 32 threads every 2 s for 120 s while 200 sleepers hold stacks. Pass: 0 scan failures; run once with a deliberately mis-sized request to prove the test can fail.
7. Failure injection (after patch A): force the 5th thread's reserve to fail. Pass: `[callret] RESERVE FAILED`, thread exits `STATUS_NO_MEMORY`, process continues, no `no-state-at-exception`.
8. Only then genuine Steam, judged by: 0 scan failures, 0 `[CALLRET_OOB]`, geometry line `size=0x800000`, and the stability gate in §8.

The planned "deep recursion then Steam" test alone is insufficient: it cannot observe resets, does not exercise exceptions, callbacks, thread exit or fragmentation, and Steam stability is confounded by F1.

### 5.4 Root-enumeration fix review (Question 4) [O]

Code: `crypt32_unixlib_ios.c:853-899` (identical hunk in `port/windows/patches/madeira.patch:2454-2499`). PE consumer: `wine/dlls/crypt32/rootstore.c:651-745`.

- Owner identity: `NtCurrentTeb()->Peb` resolves via `thread_ios.c:1922-1924` (`pthread_getspecific(teb_key)`); every thread of a pseudo-process gets the creator's PEB (`virtual_ios.c:12550-12561`). Unique for the app lifetime only because child PEBs (`loader_ios.c:3242`) are never unmapped. If PEB reuse is ever introduced, a new process with a reused address gets `STATUS_NO_MORE_ENTRIES` on its first call and `rootstore.c:715-745` deletes every imported root (verified: `generated/external-review/crypt32-review/enum_reuse_oom.out`, "guest2 (same peb) first status=0x8000001a, saw 0 roots").
- Allocation failure: `calloc` failure → `STATUS_NO_MEMORY`; the PE loop `while (!CRYPT32_CALL(...))` exits on any non-zero status, `new_count == 0`, deletion pass runs, `root_certs_imported` is set unconditionally (`rootstore.c:799`) so there is no retry, and the deletion is persisted to the registry. Verified with the extracted function.
- First load: guarded by the mutex; but if the bundle is missing/unreadable the empty list is latched (`loaded = TRUE`) for the app lifetime and every process sees EOF immediately.
- Locking: static initializer, single exit, no recursion; mutex held across file I/O and `getenv` (low risk; one thread per process calls it).
- Repeated enumeration: at most once per pseudo-process (`rootstore.c:757-801`, PE static + named semaphore).
- Test: extracts the shipped text (not a re-implementation); covers retention, interleaving, short buffer, EOF, four concurrent owners. Does not cover PEB reuse, OOM, same-owner concurrency, empty-load latch, or PE-side semantics.

Recommendations: (1) release the cursor in `process_exit_wrapper` (or key by `(pid, peb)` as `class_ios.c:1377-1386` does); (2) in `rootstore.c`, skip the deletion pass unless the loop ended with `STATUS_NO_MORE_ENTRIES`, and defensively when the host reported zero certificates but the previous import count was non-zero; (3) do not latch `loaded` when the list is empty; log loudly; (4) add the tests in `generated/external-review/crypt32-review/enum_reuse_oom.py`.

Same-pattern bugs to prioritize (by actual code): the 64-slot registries and bank cap (F1, high); `class_ios.c:82` shared `class_list`/`winproc_array` across guests (documented cyclic-list hang after process exit at `:569-580`; global classes with the same name registered by two guests match each other; medium, relevant to DE + Steam overlay windows); `thread_ios.c:87,1729,1760` global `nb_threads` (a guest whose last thread exits via `ExitThread` never terminates; low); `process_ios.c:81-83,2999,3090` global error mode/DEP flags (low); `sysparams_ios.c:45,7645` first-setter-wins DPI context (low); `audio_null_ios.c:315,527` re-initialising a mutex another guest may hold (low-medium, matters once DE plays audio); gnutls global refcount on attach/detach (low); global `peb` switched to the newest child (`loader_ios.c:3330`; benign today, a trap for new unix-side code).

---

## 6. Question 5: what blocks each milestone (with current platform constraints)

### 6.1 Stable unauthenticated Steam (Simulator)
Blocked by F1 (bank/registry exhaustion within ~10 min), F2/F3 (band exhaustion, unchecked null), and the renderer access violations in `libcef.dll` (211/213: RVAs `0x33e809d`, `0x3344325`, different faults, unexplained; upstream reported the same class at `libcef.dll+0x41258FB`). Also `--type=utility` churn will keep consuming banks even with no crash.

### 6.2 Authenticated Steam
Requires 6.1 for ≥30 minutes, then a fresh QR challenge and the user scanning it with the Steam Mobile app (never paste codes/passwords into chat or the report). Unknowns: CM logon under Wine's networking (`GetAdaptersAddresses failed: 2` ×239 upstream), Steam Guard flow, persistent session across app restarts (profile preservation is already in the runner).

### 6.3 Actual DE launch
Missing input (Windows DE, ~30 GB). Then: `AoE2DE_s.exe` anti-tamper/debugger checks under Wine + FEX (H); Wine 4K-page simulation on 16 KiB hosts (Wine 11.0 notes: "more demanding applications may not work correctly"); DXMT D3D11 coverage (feature level, tessellation not needed, compute?); PlayFab Party/xsapi network init; Steamworks init requiring the client. DE is single-process and CEF-free, so it avoids most of the Steam-specific plumbing.

### 6.4 Physical iPad
Firm constraints [O]: JIT only via sideload + `get-task-allow` + StikDebug/StikJIT with all executable regions prepared before detach; VA is one ~63 GiB window above the GPU carveout; jetsam ceiling measured 4096 MB on a 6 GB phone; `extended-virtual-addressing` and `increased-memory-limit` entitlements (both available to free accounts per Apple's capability table; not yet in the entitlements file for the former); weekly re-sign on a free account; the project's team ID is upstream's. Unknown: the user's exact iPad (model, RAM, iPadOS), whether StikDebug 3.1.10 works on its iPadOS build, and the actual `os_proc_available_memory()`.

Do not transfer Simulator results: address placement (F4), JIT pool mechanics (Simulator uses `MAP_JIT`; device uses debugger-provided RX + `vm_remap` RW alias, no new executable mappings after detach), page-size behaviour (Simulator host page 16 KiB too, which helps), and performance are all different.

### 6.5 Deployment to users
No App Store, TestFlight, enterprise or EU-notarized path permits downloaded executable code plus JIT plus an embedded store client (Guidelines 2.5.2, 4.7.2, 3.1.1; EU notarization text). Valve's SSA §2.G forbids modifying the client or emulating/redirecting its protocols; the Steamworks SDK licence covers only `redistributable_bin`. Feasible model: users sideload the app with their own Apple ID, install StikDebug, and sign into their own Steam account inside the app; the app must not bundle or patch the Steam client (the runner already fetches Valve's public packages at runtime, `scripts/fetch-windows-steam-client.py`). Licence note: Madeira and its Wine fork are GPL-3.0-or-later; distribution obligations apply to AgePad's derived code.

### 6.6 Multiplayer
Windows-build client joins the unified Windows/console pool (same build required); Mac pool is separate and irrelevant to this route. Blockers: deterministic simulation under FEX (F7), NAT/UDP and PlayFab Party under Wine, time-base accuracy (the shared-clock work is relevant here), anti-tamper, and a second untouched retail Windows client for the W5 match.

---

## 7. Question 6: user-provided inputs still needed

Missing files/accounts/hardware (cannot be solved by the agent):
1. **Installed Windows DE folder** under `ref/WindowsDE` (must contain `AoE2DE_s.exe`, `steam_appid`-less retail layout, all data; expect ~30 GB). Provide it from the user's own Steam library on a Windows machine. Without it, gates W3 (entitled installation), W4, W5, W6, W7 cannot start.
2. **Physical iPad connected to this Mac** (USB, trusted, Developer Mode on), with model, RAM and iPadOS version stated. Needed for W2 and for every memory/JIT/FPS claim.
3. **Signing identity**: the user's own Apple Developer team (free or paid) selected in Xcode for the Madeira target; decision whether a paid account is acceptable (yearly profiles, ad hoc devices) versus weekly re-signing.
4. **StikDebug** sideloaded on the iPad (plus pairing file and LocalDevVPN per its README), or an explicit decision to use another JIT enabler.
5. **Steam account with DE ownership**, used only by the user scanning a QR challenge inside the app when the agent asks; Steam Mobile app on the user's phone for Steam Guard. Never share credentials or codes with the agent.
6. **A second, untouched retail Windows DE client** (PC + separate Steam account or a friend) on the same game build, for the W5 match.

Solvable independently (no user input): failure propagation, stride/arena, per-process teardown and slot reuse, root-enumeration hardening, device probe packaging (entitlements, team placeholder), determinism test harness design, DXMT/D3D11 coverage tests against DE's shader set once the input exists.

---

## 8. Acceptance gates (concrete)

| Gate | Pass criteria | Evidence to capture |
|---|---|---|
| G0 Finite-resource lifecycle | Source-owned test creates/exits 200 pseudo-processes and 2,000 threads; `[proc-ident]` slots, fd caches, proc-sockets, banks and band bytes return to baseline ± tolerance; no `no-state-at-exception` | new lifecycle test log; `call_balance` returns near baseline |
| G1 Stable unauthenticated Steam | Sign-in window with fresh QR visible at 5, 15, 30 and 60 min in one host process; 0 `[AgePad-fex-scan-failure]`, 0 bank refusals, 0 `[redeliv]`, ≤1 renderer restart per 30 min; RSS plateau recorded | run dir with 4 timed observations + screenshots (private) |
| G2 Authenticated Steam | User scans QR; `RecvMsgClientLogOnResponse` success; library lists DE as owned; session persists across an app restart without re-login | connection_log excerpts (redacted), screenshot |
| G3 DE launch | `AoE2DE_s.exe` reaches main menu with Steam running; if Steam absent, reaches the Steam-required dialog (engineering sub-gate G3a) | screenshot, DXMT device/feature-level log, anti-tamper outcome |
| G4 Sustained gameplay (Simulator) | 20-minute AI skirmish on a standard map, game speed normal, no desync/crash; median and p95 frame time recorded by an in-app timer (not the overlay) | frame-time CSV, save file |
| G5 Physical iPad | Same probes as W1 (CPU + D3D11 draw) on the device via StikDebug; then G3/G4 on device; `os_proc_available_memory()` and peak footprint logged; thermal state logged | device logs pulled via `devicectl`, `log collect` |
| G6 Touch | Selection, drag-select, context command, camera pan/zoom, hotkey groups through normal input; validated against reference screenshots; user-approved visual style (AGENTS.md) | screenshots |
| G7 Retail multiplayer | Private lobby with an untouched Windows retail client, 20-minute match, no desync, no disconnect; then a 4-player match; replay checksums equal on both ends | both clients' logs, replay files |
| G8 Performance | On device: target 60 FPS, floor 30 FPS at documented resolution/workload; median/p95 frame times and memory over 30 min | frame-time CSV per run |

Distribution gate (separate, user decision): documented sideload + StikDebug procedure tested by a second person on their own device.

---

## 9. Prioritized experiment queue

Each entry: hypothesis; setup; discriminating output; pass/fail; risk; next action either way. Runs against genuine Steam consume tens of minutes each; put source-owned probes first.

**E0. Device gate now (W2), before any further Steam run.**
Hypothesis: the existing CPU/D3D11 probes run on the user's iPad with StikDebug, and the device's VA window, footprint ceiling and JIT-pool grant can be measured. Setup: once the iPad is connected, build the Madeira target with the user's team, add `extended-virtual-addressing` to the entitlements, install StikDebug; run `run-madeira-cpu-probes.py`-equivalent and the D3D11 probe on device. Outputs: `[va-profile]` band selection, `os_proc_available_memory()`, JIT pool size granted, probe PASS/FAIL, frame time of the draw loop. Pass: both probes pass; VA/footprint numbers recorded. Fail: record which prerequisite failed (attach, pool, VA). Risk: none to the Simulator work. Next: pass → derive the device memory architecture (single-process CEF? bank count? pool size) before more Steam; fail → this is the highest-value information available and should be reported to the user immediately.

**E1. Unsampled, result-aware, PEB-tagged band census.**
Hypothesis: live reservations at scan failure sum to ≈16 GiB (H1) rather than ≪16 GiB (H5). Setup: remove the `n<=40 || !(n&15)` sampling at `virtual_ios.c:1334`, log after the release result, include PEB and vname; reproduce with a thread-churn probe (E6 in §5.3). Output: per-class live bytes by PEB at failure. Pass/fail: as stated. Next: H1 → stride/arena + teardown; H5 → view bookkeeping audit.

**E2. Kernel band walk at scan failure.**
Hypothesis: the kernel has no free hole ≥ `host_size` at 64 KiB alignment when Wine reports `gaps-exhausted`. Setup: generalize `ios_furniture_census` (`virtual_ios.c:4587`) to `[0x7c00000000,0x8000000000)`, call it in the failure diagnostic. Output: largest kernel hole. Pass: kernel agrees (no bookkeeping bug). Next: fail → fix view tracking before anything else.

**E3. Failure propagation + stride fix (patch A then B of §5.2), with tests 1–7 of §5.3.**
Hypothesis: with a power-of-two stride the failure ordinal moves materially and, when exhaustion does occur, the thread fails cleanly. Output: fragmentation-soak result; failure-injection result. Pass: 0 scan failures in the soak; injected failure yields `[callret] RESERVE FAILED` and a live process. Next: pass → G0.

**E4. Per-PEB teardown at `process_exit_wrapper` and slot reuse for the 64-entry registries and bank ownership.**
Hypothesis: helper churn no longer consumes banks/slots monotonically. Setup: lifecycle test (G0); add a quiescence check (no live threads/callbacks for the PEB) before releasing a bank; recycle registry slots by `peb==NULL`. Output: bank assignment count over a 30-minute Steam run vs helper launches. Pass: banks ≤ live processes + small margin. Risk: use-after-free if quiescence is wrong; keep the check conservative and log refusals. Next: pass → G1 attempt.

**E5. Root-enumeration hardening** (rec. 1–4 of §5.4) with the two new test cases. Small, low risk, prevents a silent re-regression when E4 introduces PEB reuse. Do before E4 lands.

**E6. DE engine to its Steam gate (needs input #1).**
Hypothesis: `AoE2DE_s.exe` loads, passes anti-tamper, creates a D3D11 device via DXMT and reaches either the main menu or the "Steam must be running" dialog, in a single pseudo-process with 0 banks. Setup: `run-madeira-signed-startup.py --exe ... --guest-dir ref/WindowsDE --graphics` (no Steam). Output: loader log, DXMT feature level, shader compile errors, anti-tamper outcome. Pass: dialog or menu. Next: fail → fix the DE-specific boundary (this is where DXMT/page-size/anti-tamper risk is retired); pass → G3 with Steam once G1/G2 exist.

**E7. Determinism harness (before any live match).**
Hypothesis: FEX reproduces DE's simulation bit-for-bit. Setup: record a DE replay on a real Windows PC; play the same replay under FEX in Simulator and on device; compare per-turn sync checksums from DE's own logs (or the replay's recorded checksums). Pass: identical; fail → investigate x87/SSE/vector-TSO settings (`Config.json.in`) before W5.

**E8. Bounded renderer-fault forensics (currently 211–213).**
Keep, but with a budget: at most three more capture iterations to obtain the native opcode + R12 the primary agent has identified as the discriminator. If after three iterations there is no reproducible mechanism, park it (upstream also has an open libcef fault with a different RVA) and test whether single-process `steamwebhelper` (`--single-process`, as upstream forces on device) changes the fault class; that experiment is also required by F4 anyway.

**E9. Steam single-process mode in the Simulator (device-representative configuration).**
Hypothesis: Steam reaches the QR window with `steamwebhelper` in single-process mode and 1–2 banks, i.e. within the device's VA budget. Output: bank count, band usage, RSS. Pass: QR window reached. This defines the configuration to carry to the device; multi-process results are otherwise not transferable.

---

## 10. Question 7 and the revised goal loop

### 10.1 Stop / continue / reorder
- **Stop** (or budget-limit): open-ended renderer fault forensics without a mechanism (E8 budget); diagnostic-only Steam restarts when a known behaviour-changing fix is pending (failure propagation has been known since 207); adding capacity knobs (banks, pool, band) as experiments; wall-clock "verified waits" as progress; further Mac DE adaptation (D-gates), since the Mac pool is separate and the binary is not the objective.
- **Continue**: source-owned probes with pass/fail; the canonical-patch discipline; root-enumeration hardening; the clock/USD work (needed for lockstep timing).
- **Reorder**: E0 (device) and E9 (device-representative Steam config) before any authenticated attempt; G0 lifecycle before G1; DE-to-Steam-gate (E6) as soon as the input exists, in parallel with Steam stability; determinism harness (E7) before W5.

### 10.2 Revised loop
1. Read state; pick the lowest unmet gate in the order G0 → G1 → (G2 ∥ E6/G3a) → G5 → G3 → G4 → G6 → G7 → G8, unless a device boundary makes G5 more informative (it does, now).
2. Before each run declare: hypothesis, the single discriminating output, and pass/fail text. A run without a declared discriminator is not allowed.
3. One behaviour-changing change per iteration; diagnostic-only iterations are allowed at most twice in a row per hypothesis, then either change behaviour or park the hypothesis with a written reason.
4. Genuine Steam runs only after the relevant source-owned test passes; each Steam run must record bank count, band top offset, RSS and helper launches at fixed times (5/15/30/60 min) so runs are comparable.
5. Stopping rules: (a) three consecutive iterations on the same hypothesis without a new discriminator → park; (b) any run that ends by host termination must produce a failure-propagation or lifecycle fix before the next Steam run, not another capture; (c) if a required user input is missing for more than five iterations, the loop works only on input-independent items in §7 and reports the dependency at the top of the status file; (d) no capacity increase (banks, pool, band) without a device measurement showing headroom; (e) never claim a gate from Simulator evidence for device requirements.
6. Keep the full objective; every entry ends with the unchanged list of unproved requirements (already practised).
7. Housekeeping: add a short machine-readable state ledger (gate → status → evidence path) at the top of `WINDOWS-DE-STATUS.md`, and cap per-run retained artifacts (24 GiB of `generated/` now).

### 10.3 Is stabilizing full Steam first necessary?
Not as the first milestone. Legitimate ownership is preserved by requiring genuine Steam login before any *entitled* DE run (G2 before G3), but the engine boundary (E6) and the device boundary (E0) are independent of login and retire more risk per run. Steam stability remains a gate; it is just not the most informative next experiment.

---

## 11. Review artifacts

- `generated/external-review/inventory-2026-09-09.md`: read-only inventory (Simulator/device, `ref/`, Mac app provenance, entitlements, SDK VA constants, pace).
- `generated/external-review/fex-memory/`: `NOTES.md`, `vname_census.py`, `thread_bank_timeline.py`, `exited_proc_ledger.py`, `refill_check.py`, `stride.py`, `vmmap_band_hist.py`, `vmmap_band_runs.py`, `run209-live-snapshot-002113.log`.
- `generated/external-review/callret-audit/`: `wt-callret.diff`, `wt-full.diff`, `fex-callret-refs.txt`, `fex-literal-grep.txt`.
- `generated/external-review/crypt32-review/`: `enum_reuse_oom.py`, `enum_reuse_oom.c`, `enum_reuse_oom.out`.
- `generated/external-review/research/platform-research.md`: public-source memo (80+ sources with access dates).

---

## 12. Public sources (accessed 2026-09-09; full list with quotes in the research memo)

- Apple, `com.apple.security.cs.allow-jit` (macOS 10.7+ only): https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit
- Apple, Extended Virtual Addressing entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.extended-virtual-addressing
- Apple, Increased Memory Limit entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit
- Apple, Supported capabilities (iOS) by account tier: https://developer.apple.com/help/account/reference/supported-capabilities-ios/
- Apple, Alternative browser engines in the EU (JIT only for browser engines): https://developer.apple.com/support/alternative-browser-engines/
- Apple, App Review Guidelines (2.5.2, 3.1.1, 4.7): https://developer.apple.com/app-store/review/guidelines/
- Apple, EU notarization / alternative distribution: https://developer.apple.com/support/dma-and-apps-in-the-eu/ ; https://developer.apple.com/support/web-distribution-eu
- XNU `osfmk/mach/arm/vm_param.h` (63 GiB iOS limit, GPU carveout): https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/arm/vm_param.h (local copy: iPhoneOS26.5.sdk `usr/include/mach/arm/vm_param.h:84-100`)
- StikDebug / StikJIT (iOS 26 region-preparation protocol): https://github.com/StephenDev0/StikDebug ; https://github.com/StephenDev0/StikJIT/blob/main/INTEGRATION.md
- Madeira and forks: https://github.com/willfaust/Madeira ; https://github.com/willfaust/FEX ; https://github.com/willfaust/wine ; https://github.com/willfaust/dxmt
- FEX release notes (ARM64EC 2501; call-ret stack 2508; rpmalloc/Steam CEF 2603; 2609): https://fex-emu.com/FEX-2501/ ; https://fex-emu.com/FEX-2508/ ; https://fex-emu.com/FEX-2603/ ; https://github.com/FEX-Emu/FEX/releases/tag/FEX-2609
- FEX on macOS not planned: https://github.com/FEX-Emu/FEX/discussions/3267
- Wine 10.0 / 11.0 announcements (ARM64EC, x86-64 emulation interface, 4K-page simulation caveat): https://www.winehq.org/news/2025012101 ; https://www.winehq.org/news/2026011301
- DXMT (macOS 14+ only upstream): https://github.com/3Shain/dxmt
- World's Edge, AoE2 DE on macOS (Feral, Apple-silicon native, 2026-05-28): https://www.ageofempires.com/news/age-of-empires-ii-definitive-edition-available-now-on-mac/
- AoE support, Mac cross-play not supported: https://support.ageofempires.com/hc/en-us/articles/360050470032
- Steam store page (requirements, D3D11): https://store.steampowered.com/app/813780/
- PCGamingWiki AoE2 DE (RelicLink, no third-party anti-cheat, macOS pool): https://www.pcgamingwiki.com/wiki/Age_of_Empires_II:_Definitive_Edition
- AoE2DE_s.exe anti-tamper analysis: https://tarasyk.ca/2020/01/09/aoe2-de-tampering.html ; lockstep reversing: https://redrocket.club/posts/age_of_empires/
- Steam Subscriber Agreement §2.G: https://store.steampowered.com/subscriber_agreement/ ; Steamworks SDK Access Agreement: https://partner.steamgames.com/documentation/sdk_access_agreement/
- UTM 5.0.5 release (DXMT on iOS requires TrollStore/Hypervisor build): https://github.com/utmapp/UTM/releases/tag/v5.0.5
- Crashpad termination code 0xffff7003: https://github.com/chromium/crashpad/blob/main/util/win/termination_codes.h

## 13. Unresolved uncertainties

- The user's exact iPad model/RAM/iPadOS and the actual per-app footprint ceiling and VA window on it (E0 resolves).
- Whether StikDebug 3.1.10 works on that iPadOS build and whether the "GetMoreRam"/extended-VA injection mentioned in the app is needed on M-series iPads.
- Live band reservation by class at failure (E1) versus the cumulative estimate here.
- The mechanism of the `libcef.dll` renderer access violations (211/213) and whether single-process CEF changes their class.
- DE's behaviour under Wine's 4K-page simulation, DXMT feature coverage, and its anti-tamper response to the FEX/Wine environment (E6).
- FEX simulation determinism for DE lockstep (E7).
- Official meaning of the `_s` suffix in `AoE2DE_s.exe` (inferred: the protected retail binary).
- Whether Valve's SSA "emulate or redirect the communication protocols" clause would be read to cover CPU emulation of an unmodified client (my reading: it targets protocol emulation, not CPU emulation; not legal advice).
