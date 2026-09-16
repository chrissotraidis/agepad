# Signed Windows child processes — implementation boundary

Measured on 8 September 2026 in windows-015/016. Full objective remains Windows DE with real Steam multiplayer on physical iPad. This is a prerequisite, not alternate acceptance.

## Evidence

The real Steam updater completed a 247352 KB download and installation, then failed in its child restart. A fresh launch of that preserved installation passes verification and loads steamui.dll, then requests steamsysinfo.exe and steamwebhelper.exe. The same child ntdll failure recurs. No login screen or working CEF process is established.

The old `ios_jit_copy_module_for_child` searches an executable-copy mapping table. Signed Mach-O PE containers are deliberately outside that mapping mechanism, so it cannot find the parent ntdll. The caller falls back to shared ntdll data and then faults. Do not make the table pretend a signed image has a writable executable alias, or accept shared loader state as isolation.

## Concrete route to test

1. Prebuild independently named signed containers from identical PE source for each supported child slot. Distinct LC_ID_DYLIB values make the intended image identities explicit. Current `scripts/build-madeira-child-bank.py --slot 1` prepares 15 modules, validates signatures and pins source/dylib hashes. It does not load them or prove separate data at runtime.
2. Initial ntdll storage check passes in windows-017 (distinct mappings, prefix byte identity, child-slot mutation does not alter root; parent CPU/Win32 regression passes). Extend this to actual child initialization and other loaded modules. Measure that root and child images load at distinct addresses, have immutable native instruction bytes and independent writable dispatcher/TSD/data slots. Before child execution, prove a write in the child data leaves the parent unchanged. Retain this as a meaningful isolation regression.
3. Assign a stable bank to each child PEB under synchronization. Never reassign a bank whose code or process data remains live. Do not remove ownership checks to reuse the root image. More than one child is required: Steam invokes a system-info child and a CEF helper. A fixed small bank is an explicit prototype limit, not the final process architecture.
4. Initialize fresh child ntdll using the existing per-PEB `ios_ntdll_funcs` registry and CHPE export redirection. Publish the signed-image relocation table and actual TSD offset in that child. Route its other Wine/FEX imports to its own bank. Increase the native table and PE reader capacity together with bounds checks; current hardcoded 16-entry tables are insufficient for multiple banks.
5. Replace single-owner MAP_JIT admission with owner-tagged allocations in the one host pool, validating ownership on query/release. Each child needs its own FEX globals/context. Retain per-thread write/execute scopes, instruction-cache flushing and allocation bounds. Never grant a child ownership of all parent chunks. Prove parent compilation/execution survives child work and exit. This still does not solve physical-device JIT.
6. Audit native globals used during child startup (`peb`, argv, main image identity, dispatcher addresses), and lifecycle/wineserver cleanup. Current comments that the parent is blocked do not prove other parent threads are stopped. No global mutation may silently redirect a live sibling.
7. Test one source-owned parent creating two children with independent data/Win32 operations and real completion status, then the actual updated Steam installation. Real login and DE multiplayer stay separate acceptance gates.

## Preserved installed input

`generated/windows-steam-intake/installed-1788652215` is a 6577-file snapshot of Steam's completed update, including installed-package metadata. `installed-snapshot.json` pins every file hash. This predates any user login. Use it for subsequent client tests rather than redownloading the already completed update. Future authenticated prefixes must be handled as live account state, not blindly copied through this intake workflow.

## Current limits

Checkpoint windows-019 proves one child runs through private signed ntdll/core DLLs and FEX, exits 73, and leaves the parent test variable unchanged; parent exits 0. This is bounded one-child evidence. Synchronized multiple-bank assignment, concurrent process safety, complete lifecycle handling and CEF remain unproven. Root Simulator CPU/D3D11/presentation tests and the real updater result remain valid within their prior scope. Retain allocator diagnostics and raw-x18 exception overhead as unresolved concerns.


Checkpoint windows-020: bank assignment and registration are synchronized; native/PE tables are 64 entries; two-child event rendezvous and parent-state test passes. Actual CEF helper enters private initialization. Shared native globals, lifecycle, extra helper capacity and full Steam operation remain open. See latest status for live PID.
