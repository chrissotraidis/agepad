# Active signed-bank lifetime audit — windows-246

Scope: current signed-container runtime, not the inactive `WINE_IOS_JIT_*` image-copy allocator. Bank reuse remains disabled. These source findings identify implementation requirements; they do not certify native quiescence.

## Resources that survive guest exit

| Resource | Current behavior | Requirement before reuse |
|---|---|---|
| Signed DLL handles/data | `agepad_load_signed_ntdll_locked` keeps a static retained array. `dlopen` returning an existing base succeeds only for the same PEB. Relocations, imports, CRT statics and exported dispatcher slots mutate writable data. | Preserve/restore a validated initial data image; revoke old owner and view/dispatcher references before publishing new owner. Clearing bank allocation alone is insufficient. |
| Signed image table | Base is release-published; owner/size/split remain in the shared table. PE ntdll stores a pointer to that table. | Stable entry lifetime and coherent retirement/publication for readers; do not overwrite a live table entry under old readers. |
| Active JIT chunks | `agepad_jit_service` stores owner, release and full-release eligibility. `agepad_jit_reuse_chunk` accepts only exact-size chunks belonging to the same PEB. | Prove old execution/references ended before transfer; preserve full-release versus partial-release distinction. Do not reuse based solely on a release log. |
| Native Mach registry | `ios_thread_registry` keeps port, TEB and trampoline; registration appends or replaces a matching port. No unregister path found. Extra Mach send references are pinned during registration. | Stop acquisition, drain readers, retire coherent port/TEB/trampoline identity, and account for retained send rights before slot reuse. |
| FEX sweep registry | `IosSweepUnregisterThread` clears the thread slot and waits for `IosSweepBusy`; main/worker cleanup calls it before destruction. | Preserve this existing ordering. It covers FEX sweep snapshots, not native Mach registry readers. |
| Native FEX callback registry | Early retirement closes tracked hold/cleanup/pending/alias calls; tombstones remain. | Native registry and all other readers must also drain before bank data reset. Callback retirement alone is insufficient. |

## Evidence and distinctions

- `worktrees/madeira/build/ntdll-unix/agepad_signed_ntdll.h`: retained cache rejects a different owner at the same dyld base, applies data relocations once, registers builtin views, and retains handles. No data reset or bank retirement function exists. A failed load after relocation is another future rollback concern; no repair claimed here.
- `worktrees/madeira/build/ntdll-unix/virtual_ios.c`: active `agepad_jit_chunks` are distinct from legacy `ios_pool_ledger`. Legacy process-exit reclamation does not retire the active chunks. Same-owner reuse helper's sanitizer test, including a negative control that removes owner isolation, passes.
- `scripts/account-active-jit-log.py windows-forced-late-copy-245`: six logged allocations total 50,380,800 bytes; all six have release markers by root termination. Release logs omit the requested release size, so they cannot certify full-release eligibility. The controlled log order associates two allocations with each initialization interval, but the allocation messages themselves do not carry owner identity. Do not generalize that attribution to overlapping Steam processes.
- `signal_arm64_ios.c`: `ios_thread_registry_count/teb/mach`, `ios_lookup_thread`, and registration near `pe_thread` publication retain references outside FEX. Some lookups fall back to slot zero. A capacity overflow or stale port can therefore select the wrong process's TEB; a larger capacity does not solve lifetime.
- `thread_ios.c::ios_mach_port_for_teb` reads TEB and port through separate accessors. Reusing a slot would permit mismatched observations unless readers obtain a coherent snapshot. Signal/exception context prohibits blindly introducing the ordinary callback registry's blocking mutex.
- `FEX/FEXCore/Source/Interface/Core/CPUBackend.cpp::IosSweepUnregisterThread` plus `Module.cpp::DestroyRegisteredThreadState` establish the separate FEX sweep drain. They do not unregister a Mach thread.

## Next implementation boundary

Start with the native Mach registry's coherent identity, reader acquisition and retirement protocol, including terminal native-thread exit. Test an in-flight reader and attempted slot reuse; require that it cannot observe mixed old/new identities or stale TEB/trampoline data. Locate the true last native exit before wiring retirement, and account for held Mach rights. Only after that proof should signed image reset and active JIT owner transfer be enabled together in a bounded two-bank churn test. Do not clear bank owners or reset DLL data merely because wineserver reports a child exit.

Physical-device JIT and Windows DE input remain separate open gates. Current active JIT service rejects non-Simulator targets; no device, gameplay, FPS or multiplayer acceptance follows from this audit.

## Snapshot foundation — windows-247

Native entries now have serialized publication and nonblocking atomic sequence-checked snapshots. Handle-to-Mach-thread lookup uses one coherent triple instead of separate accessors; actual concurrent helper test and native build pass. Other readers remain raw. Snapshot acceptance does not pin TEB memory or code after return, so retirement/reuse is still prohibited until reader lifetimes are covered. No app deployment this turn.

## Reader migration — windows-248

Registry consumers now obtain coherent snapshots; remaining raw payload reads are within serialized registration. Actual concurrent helper test and16worker guest shutdown regression pass. Slot0 fallback remains; cached pump/beacon values and direct TEB/CPU-area dereferences outlive snapshot acquisition. The next gate is protecting those references for their full use interval and retiring native entries at terminal thread exit. Coherence does not certify lifetime or permit bank reset.

## Reader reference mechanism — windows-249

Per-entry CLOSED/WRITING/count state supports one-attempt acquisition, release, retirement and publication exclusion. Actual helper tests pass for a held reader blocking replacement, retirement pending until release, and closure retained across publisher completion. Runtime consumers still only use value snapshots; a zero count currently certifies nothing about them. Next wire full-use scopes before calling retirement. No slot reuse enabled.

## Mach request scope — windows-250

Mach requests now hold one exact-port lease until request/reply scope exit and reuse that identity throughout. Missing/busy/closed owners decline instead of slot0 fallback. Actual scope-exit tests and16worker guest regression pass; no forced live Mach-request retirement yet. Other native readers/cachedreferences remain outside lifetime accounting, so no reclamation may rely on the count globally.

## Escaped diagnostic port — windows-251

Handle-to-Mach diagnostic now matches TID and takes an owned send right while the registry entry is leased. Caller releases that right after sampling. Actual helper/mocked-right tests and native build pass; consumer release order is source-checked. No guest qualification this turn. Diagnostic caches and other readers remain outside complete lifetime coverage; teardown cannot yet rely on lease count for reclamation.

## Protected diagnostic scans — windows-252

Pump discovery, orphan/live-stamp scans and lock census now use one captured set of leased native registry entries for the entire diagnostic pass. Partial acquisition failure releases every earlier acquisition and skips the pass. Pump ports/TEBs are local and rediscovered each pass; published beacon values are cleared before attempting capture. A retired/busy entry currently suppresses the whole pass conservatively, rather than producing an incomplete census that could misidentify an absent lock owner.

New actual-helper ASan/UBSan test covers full capture, partial-failure cleanup, retirement pending while held, scope-exit drain and rejection of closed entries. All five native snapshot/lease/request/owned-port/scan tests pass; native Simulator build reports34 succeeded,0 failed. Canonical Madeira patch synchronized and reverse-checked. No app relink/install, Simulator operation or new guest run; the diagnostic path itself has not been guest-qualified. Leases cover registry identity, not arbitrary object/stack pointers followed by diagnostics. Actual teardown still does not consult all reader lifetimes; native unregister, Mach-right cleanup and bank reuse remain disabled/unproved.

Fresh input inventory252: devicectl reports No devices found; recursive ref search finds no AoE2DE_s.exe or AoE2DE.exe. External report hash remains unchanged. Next audit remaining escaped native references and terminal-thread exit, then qualify controlled retirement before attempting bank reuse. Physical-device JIT implementation remains required: the active service rejects non-Simulator targets. DE gameplay, authentication, touch, sustained FPS and retail multiplayer remain unproved.


## Signal diagnostic reference and terminal-exit boundary — windows-253

Previous252 made progress with protected diagnostic scans. Added exact nonblocking ios_thread_lease_for_teb and scoped the POSIX signal RSP diagnostic through its TEB/CPU-area reads. Missing, busy or closed identities skip the diagnostic; no slot0 fallback. Actual-helper test covers exact identity, missing/zero/busy/closed rejection and pending retirement until scope cleanup. All six native lifetime harnesses pass ASan/UBSan; native build reports34 succeeded,0 failed; canonical patch reverse-check passes. No app relink/install or Simulator changes; actual signal delivery/retirement overlap is not guest-qualified. Nonlocal fault unwinding may retain a lease; this conservatively prevents reclamation under the future protocol. A lease alone does not keep independently freed FEX frame contents alive.

Exit audit: thread_ios.c::exit_thread exchanges prev_teb, invokes pthread_join without checking its return, then calls virtual_free_teb without native registry retirement/drain. virtual_ios.c::virtual_free_teb releases guest stack, ChpeV2CpuAreaInfo and native stack, then signal_free_thread and TEB freelist insertion. Thus pthread termination alone is not sufficient for external native readers. Two other virtual_free_teb calls are pre-start stack/create failure cleanup and must not be confused with registered-thread reclamation. Process exit and raw pthread_exit paths remain separate.

Next implementation boundary: verify join success, close acquisition for the exact joined identity under publication synchronization, retain memory on pending/unknown readers, and cover TEB/CPU-area destruction before any native slot reuse. Audit FEX CPU-area/frame destruction ordering separately; do not infer its lifetime from a native TEB lease. No native unregister, Mach-right release, bank reset or device execution is enabled. Actual DE/gameplay/FPS/touch/authentication/multiplayer remains unproved; input inventory252 still supplies the last device/WindowsDE evidence.


## Joined-thread reclamation guard — windows-254

Previous253 made progress with signal scope protection and identified the normal exit boundary. exit_thread now checks pthread_join return and retains the preceding TEB on failure. Under existing experimental AGEPAD_RETIRE_FEX_CALLBACKS setting, successful join invokes ios_thread_retire_joined_teb before virtual_free_teb. The helper holds the publication mutex, closes every registry entry matching the TEB (including historical aliases), and permits this cleanup only when a matching identity exists and every matching count reports drained. Missing/pending/unknown state retains the allocation. Pre-start cleanup paths are unchanged. Without the experimental setting only the join-result guard changes; the old unguarded reader-lifetime behavior remains.

Actual-helper pthread test holds a reader while closure is attempted, verifies both aliases close, rejects new acquisition/replacement, preserves an unrelated identity, then verifies drained state after the reader exits. Missing/zero identity rejects. Consumer join/retire/free ordering is source-checked, not executed in this harness. All seven native lifetime tests pass ASan/UBSan; native Simulator build reports34 succeeded,0 failed; canonical patch reverse-check and changed-source whitespace check pass. No app relink/install or Simulator operation. No actual guest retirement or forced join-failure qualification yet.

This is a conservative reclamation guard, not complete recycling. Retained allocations have no retry queue; slots and Mach rights remain reserved. A closed slot conservatively suppresses the current full diagnostic scan. Process-wide exit, FEX frame destruction before native closure and other independent references still need coverage. Next exercise actual normal-worker guest exit under the experimental setting, with explicit evidence that retirement precedes TEB cleanup, then address deferred reclamation and diagnostic handling of closed slots. Do not enable bankreset from this helper result alone. Full DE/device/touch/FPS/authentication/multiplayer goal remains unproved.


## Joined retirement executes in Windows guest — windows-255

Previous254 is progress: conservative joined-thread guard. Added a marker after successful join and registry drain immediately before virtual_free_teb. Native/app builds pass, joined-helper test passes, canonical Madeira patch synchronized/reverse-checked. Checked sole designated Simulator and live SteamPID1661 before foregrounding isolated probe.

Actual windows-joined-retire-255 sixteen-worker fixture passes:15 distinct TEB/TID joined-drained before-free markers within first child before its cleanup barrier; no retained markers. This matches normal exits reclaiming the preceding worker. Extended verifier --joined-retirement checks exact workers-minus-one count, unique identities, placement between child attach and drain, and no retention, alongside child81/82, guestTLS/DLL, early retirement, main/CRT/allocator/final retirement and parent0. Observation confirms guest terminal0; host liveness is not used as success. Evidence: generated/madeira-signed-startup/windows-joined-retire-255/detach-verification.json and generated/steam-255-joined-retirement.json.

This proves ordinary guest exits reach the guard before cleanup, not a reader-held race, join failure, post-free accessibility or resource reuse. Final worker and process-wide exit still need coverage; retained objects have no retry queue and closed entries suppress the full diagnostic scan. Next qualify retention with an intentionally held reader and develop deferred reclamation without reopening identities prematurely. Independently audit FEX frame lifetime; do not infer full safety from TEB drain.

After verified guest terminal result, terminated only probe and restored Steam samePID1661 at2:57:24. Normal FEX root and two-bank packages restored. Preserved Steam unchanged; no extraSimulator or game/account changes. No WindowsDE/device/touch/FPS/authentication/retail multiplayer acceptance follows.

