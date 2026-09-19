# AgePad recovery and architecture decision plan

Decision date: September 16, 2026. This is a proposed execution plan with measurable
acceptance gates, not evidence that the repairs have been completed.

## Decision

Keep the original ARM64 Mac engine as a bounded candidate. Stop installer polish
until it passes reliable input and an early device/service feasibility gate.
Treat Madeira as an existing alternative to qualify, not a presumed rescue.
Do not restart its infrastructure work without an actual Windows DE executable
or a physical-device experiment that can advance the game objective.

Use two work queues, executed sequentially when they share the Mac/Simulator:
input/performance diagnosis and device/service feasibility. Neither must wait for
the other to be fully polished. Only the designated G5 Simulator may be booted.

## What further investigation established

1. Madeira upstream main is still `97e2ce26e6dc9e4a38976f3b5deb9272d64558eb`,
   dated August 29. This matches our existing Windows-route pin. Its Steam handoff
   was last changed in commit `2498bdf5915ce99f1a8ece2e916b715991c31fb9`, August 25,
   for project renaming; the document describes August 5 investigations. It reports
   unresolved Steam rendering, crashes and login failures. These are historical
   reports, not a fresh reproduction, but no newer main revision supplies a fix.
   [Upstream](https://github.com/willfaust/Madeira)
   [Steam handoff](https://github.com/willfaust/Madeira/blob/main/STEAM_CEF_HANDOFF.md)
2. Generals defers button commitment while identifying gestures, moves the pointer
   early to establish hover, suppresses duplicate touch-mouse events, and integrates
   input at the engine's SDL mouse path. It can modify/recompile the engine.
   Its implementation is a behavioral reference, not a drop-in AoE adapter.
   [Input source](https://github.com/ammaarreshi/Generals-Mac-iOS-iPad/blob/main/GeneralsMD/Code/GameEngineDevice/Source/SDL3GameEngine.cpp)
3. Our `WindowViewCompat.m` immediately emits a primary press on first contact.
   `NativeTouchGestures.m` relies on recognizer cancellation when a multi-touch
   gesture wins. `touchesCancelled:` currently emits a drag/release at an offscreen
   point. That can deliver gameplay input before gesture identity is settled.
   This is a testable interference risk, not the proven cause of the two failed
   one-finger ORDER attempts.
4. Gesture-generated events and direct-touch events use different constructors.
   `nativeMouse:` does not explicitly populate all fields populated by
   `sendGameMouse:` (including windowNumber and pressure). Determine which fields
   the original consumer needs before changing them.
5. `OrderedMouseDelivery.h` holds release until two observed compositions or a
   timeout; `PresentationProgress.h` explicitly disclaims game acknowledgement.
   Correct adapter ordering alone cannot qualify command consumption.
6. The current service launcher uses a host Unix-domain socket and a Simulator
   helper. This arrangement does not cross onto a physical iPad automatically.
   The staged sibling data/framework layout also is not a persistent device import
   design. These are architecture gates, not missing installer screens.
7. Fresh inventory still reports no physical iPad and zero valid signing identities.
   Existing Windows-route notes record a device-built probe and missing Windows DE
   input; verify artifact provenance before reuse rather than rebuilding blindly.

## Sequence and gates

### 0. Freeze a repeatable experiment — first session

Record the current source revision, runtime-library hashes, game version, save
hash, resolution, original input settings and test machine. Preserve the named
AGEPADPLAY914 save and create working copies. Stop only owned game/helper processes.
Do not reinstall over an unsaved scenario without explaining the restart.

Create one acceptance ledger with pass/fail/inconclusive and links to evidence.
Retire stale top-level claims; keep historical findings dated. No test that only
checks an adapter may count as accepted gameplay.

Deliverable: reproducible launch + preserved fixture + empty acceptance matrix.

### 1. Establish the native control and trace a failed command

Run the unmodified Mac game with the same save, resolution and relevant settings;
keep the Simulator game stopped. Test real mouse selection and ten movement
orders. Automated native menu clicks previously failed: if they still fail, use
one short human-assisted baseline rather than writing another synthetic-click
workaround. Record native frame timing and accepted commands.

Then run the iPad candidate with the same workload. Capture a bounded trace for:
touch receipt → event creation → queue consumption → original Feral consumer →
first visible selection/movement. Reuse `OriginalInputConsumerTrace.m` where its
exact ABI guard passes. It observes only the first consumer, not final game orders.
Use screen video for visible outcomes where internal state is unavailable.

Test three hypotheses individually, restoring the baseline after each:

- **Event/state mismatch:** compare required button, window, location, timestamp,
  click count and polled pointer state with an accepted native click. Check that
  the ordered queue and global button state expose the same transition.
- **Hover/consumption timing:** separate motion from press at an observed consumer
  boundary. Compare current delivery with a bounded diagnostic variant; do not
  permanently replace the two-composition guess with another arbitrary delay.
- **Gesture or camera interference:** repeat with gesture recognizers isolated,
  then with explicit known click-drag settings. Use A/B/A runs; an Options visit
  followed by success is insufficient because that already confounded earlier tests.

Pass: three fresh launches, each with 20/20 accepted movement orders, no Options
visit or retry, no stuck button after cancellation. Target p95 touch-to-visible
response under 150 ms; record failures even if the unit eventually moves.

Budget: three distinct hypothesis experiments. If none discriminates the cause,
stop speculative changes and review the original-consumer evidence. Do not spend
another unbounded run varying delay constants.

### 2. Repair gesture ownership as one coherent subsystem

Once basic mouse semantics are established, implement explicit pending-tap,
selection-drag, order, pan and pinch states. A second finger must not first send
an unintended select/order. Preserve the first contact as the selection anchor;
cancel/release every owned button and key on interruption. Use one event factory
for direct touch, shortcuts and gestures after required field semantics are known.
Keep controls styled consistently with the original game.

Verify pan against the actual loaded hotkey binding; the current slash assumption
must not silently break for another profile. Keep click-drag configuration explicit.

Pass: 20 trials each of selection, box selection, order, two-finger pan and pinch;
10 interrupted gestures; zero unintended commands or stuck inputs. Repeat with
different first-finger/second-finger timing. Require real multi-touch hardware for
acceptance; single-pointer CUA automation cannot establish this gate.

Files: `WindowViewCompat.m`, `NativeTouchGestures.m`, `OrderedMouseDelivery.h`,
`PointerEventCompat.m`, and meaningful actual-adapter/gesture tests.

### 3. Identify the performance bottleneck before optimizing

Capture a 60-second Instruments Game Performance/Metal System Trace for the native
control and adapted game, on the same Mac, sequentially. Use Time Profiler and
explicit bounded timing if a trace facility cannot attach. Record the limitation.
Apple recommends this combined view to relate CPU work, waits and GPU execution.
Distinguish simulation ticks, GPU completion and displayed frames.
Do not label our composition counter as any of those other clocks.
[Apple profiling guidance](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)

Classify the dominant cost: CPU encoding/forwarding, GPU execution, drawable or
semaphore waits, resource uploads, logging/I/O, or memory pressure. Check the
existing wait/flush/FIFO compatibility features one at a time in isolated builds.
Remove a workaround only after tracing why it was necessary and verifying correctness.

Pass: three measured five-minute Simulator runs with accepted commands, no recurring
one-second stalls, and a documented frame-time distribution. Final device target:
30 FPS minimum in the reference scenario, p95 displayed-frame interval under
50 ms, and no unexplained stall over 250 ms. These are proposed project targets,
not promises or measurements. Repeat on a populated battle before release.

Budget: optimize the two largest measured costs, then rerun. If the profile remains
unexplained, request a focused architecture review with traces rather than claiming
another minor forwarding change fixes overall speed.

### 4. Run the device/service feasibility gate early

Start preparation during steps 1–3; do not postpone until gestures look polished.
Obtain target iPad model/OS, connection/trust and development signing. Check actual
GPU capabilities; Simulator has materially different limits and uses the Mac GPU.
[Apple Simulator guidance](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator)

Build a separate iphoneos candidate and audit every executable/library dependency.
Use supported device drawable callbacks; confine Simulator composition interception
to its tested environment. First run a small device graphics/lifecycle probe, then
launch the actual game and record the first authentic failure. Ad-hoc signing,
successful linking and a loading screen do not pass.

Audit Steam dependencies end to end: discovery, helper startup, shared memory,
sockets, callbacks and identity. Decide whether they can operate locally on iPad.
If a Mac companion is proposed, specify exactly which services cross the network,
authentication/pairing and disconnect behavior. A Unix socket path forwarded over
TCP is not a demonstrated substitute for shared memory or process identity.
Do not fabricate Steam success or treat an account name as authenticated play.

Pass: icon launch → actual owned game → load/start scenario on physical iPad, with
a declared working service topology. For standalone acceptance, repeat with the
Mac disconnected. If a companion is essential, identify that as a product choice
requiring the user's agreement, not a silent change to standalone play.

Stop/pivot trigger: a required desktop process/service dependency has no demonstrated
device-compatible implementation. Do not keep polishing the installer behind it.

### 5. Qualify the existing Windows alternative only if needed

Acquire the user's owned Windows DE installation. Reuse the existing pinned
Madeira build and verified device probe after checking hashes. First repeat its
small translated-execution/graphics test, then try the real game and genuine Steam
flow. Do not restart hundreds of infrastructure experiments without game input.

Pass: authenticated game startup, the same 20-order scenario, physical-device
execution and measured performance. Include signing/JIT startup friction and
session stability in the comparison. A login window or a fast unrelated game
does not qualify this route. Upstream README explicitly calls Madeira research.
[Madeira status](https://github.com/willfaust/Madeira)

Switch only when this candidate passes a gate the Mac route cannot, or its measured
remaining work is clearly smaller. If both fail device/service feasibility, report
that local DE is not yet viable with the tested inputs. Keep classic-engine and
streaming alternatives explicit scope choices; neither silently satisfies DE.

### 6. Build the install flow after architecture passes

Turn staging into a clean-checkout preparation tool: detect owned edition/version,
validate hashes and disk space, preserve source casing, prepare signed code separately
from imported assets, and store data/saves in persistent app storage. Test interrupted
import, missing files, insufficient space, repeat import and app update/save preservation.

Pass: a second clean installation follows README without unpublished flags or edits;
icon launches work; existing saves survive upgrade. Then execute a 30-minute device
session, ten background/foreground cycles, sound/interruption checks and all gestures.
Only then merge a release candidate and mark device testing ready. Earlier main merges
remain development snapshots. Multiplayer requires a separate completed retail match.

## Immediate next actions and dependencies

1. Save the baseline hashes and prepare bounded native/Simulator consumer capture.
2. Run the failed-command A/B/A investigation; use its result to choose the first fix.
3. Prepare the device dependency/service audit while hardware/signing is unavailable.
4. Collect iPad model/OS and connection; Windows DE files are needed only to execute
   the alternative route. Do useful local work while these inputs are pending.

Every experiment ends with a concrete pass, failure or unresolved discriminator.
Changes that fail the comparison are reverted in the candidate, with evidence retained.
No elapsed-time estimate is a guarantee: the budgets above limit speculation, not the
amount of proof required to call the app usable.
