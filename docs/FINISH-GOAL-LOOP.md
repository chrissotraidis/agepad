# AgePad finish loop

**Revision:** 2026-09-11

**Latest checkpoint:** [MADEIRA-REORIENTATION.md](MADEIRA-REORIENTATION.md)
supersedes the coordinate-only diagnosis below. Identical taps now establish a
first-hover/second-activation pattern. Fresh GPU metadata fixes reboot startup;
proper original rightMouse handlers visibly place a rally flag. Move-before-down
is compiled as an opt-in experiment, not qualified. Current run is
`generated/mac-de-simulator-375/right-dispatch-1`; computer use awaits Mac unlock.

This is the active execution loop for the current request. It reconciles the
classic R1 work with the newer original-DE investigation without treating a
partial result from either route as completion of the other.

## Active objective

Run the supplied original Age of Empires II Definitive Edition engine locally
through the existing AgePad iPad Simulator first, then prove usable touch and
sustained gameplay performance. Physical-device execution and genuine retail
multiplayer are later gates with separate inputs and evidence.

The classic `R1/freeaoe` candidate remains preserved as a fallback and as a
separate single-player product track. Loading DE artwork into R1, or reaching a
classic tutorial, does not satisfy the active DE objective.

## Reorientation checkpoint

The project is not stuck at engine rendering. The latest clean fixture,
`generated/mac-de-simulator-375/presentation-clean-1`, reached the original
launcher, main menu, Single Player, Skirmish, a live world and a town-center
selection on the one designated Simulator. The probe overlay is hidden and
the host surface is black instead of white. The remaining host-boundary work
is narrower: the raw Simulator backing is still portrait while the logical
surface and CUA presentation are landscape, and a delivered Start Game tap
does not consistently match the rendered control's accepted logical region.

The preserved live fixture has now crossed the next interaction boundary:
production entered the original town-center queue, a normal calibrated tap
returned the original house-limit response after population reached `5/5`, and
a world drag changed the camera before a touch reselected the town center.
The exact evidence is recorded in `docs/DE-STATUS.md` Iteration391 and the
`production-avui-2` screenshots/log ranges. This means the current blocker is
not blanket event delivery or a renderer rewrite; it is reliable calibration
of the visible action panel plus the remaining touch-slice transitions.

The latest `interaction-release-1` fixture sharpens that checkpoint: the
normal CUA click and the drag path at the same visible Start Game control
delivered different root coordinates, so the old “held touch succeeds” label
was misleading. In the live world, a one-point root shift at the rendered
Create Villager control changed tooltip-only behavior into the original
house-limit response. Treat this as a coordinate-space/hit-region question,
not a release-delay result. The next loop must measure the CUA-to-root mapping
and a neighboring point before changing `WindowViewCompat.m`. The measured
action-panel grid is now recorded in Iteration393; use it to target the setup
control instead of reusing screenshot pixels as touch coordinates.

The same fixture now supplies bounded cadence evidence: 30- and 60-second
Simulator composition samples recorded 1077 and 2136 displayed completions,
with zero dropped completions. That evidence is explicitly not physical
scanout or per-frame latency. A lifecycle background/foreground probe also
confirmed that the installed candidate can be cleanly restored, but the clean
restore intentionally discarded the unsaved world and left the logical
landscape surface inside the Simulator's portrait raw backing. Keep this as a
presentation observation and F5 input to the loop, not as a completed
performance or orientation pass.

The fresh `mapping-1` fixture changes the interaction diagnosis: when the
Simulator is left in its true landscape presentation, ordinary taps work for
the main menu, Skirmish, town-center selection and a neighboring action-panel
point. The remaining Start Game and action-panel misses are narrow accepted
regions, not evidence for another release-delay or duplicate-event patch. A
300-second relay-backed run and a fresh 30-second composition sample also
passed; the one abort observed outside that fixture occurred after its relay
had already been cleaned up. The next loop must keep the relay alive while
exercising setup, then target the remaining accepted regions with measured
normal taps before changing source. `mapping-2` completed that experiment:
CUA `[420,522]` left the setup screen in place with the original tooltip,
while ordinary CUA `[430,522]` entered the original loading screen and then a
live world. The same run also accepted ordinary town-center selection and an
action-panel tooltip tap. This promotes the true-landscape presentation to the
current input fixture invariant; it does not yet promote the full touch slice.

The next clean `mapping-3` fixture showed that the accepted setup neighborhood
can shift between launches: `[430,522]` hovered, while `[440,522]` entered the
loading screen. It also accepted ordinary production at `[67,570]`, reached
the original `5/5` population state, opened the original pause menu with
Escape, and returned with a neighboring ordinary cancel point `[430,430]`.
The first cancel point hovered, so control calibration remains part of F4.
Backgrounding via the Simulator Home control worked, but foregrounding could
not be visually verified because the host UI locked during the run.

The smallest causal lifecycle change is now implemented in
`port/de/DisplayLifecycleCompat.m`: `_CGDisplayIsInMirrorSet` returns the
faithful single-display result instead of aborting. The fresh
`lifecycle-mirror-1` probe reached `DE_GAME_WINDOW_CREATED` and survived 120
seconds with no mirror boundary. This permits a new foreground verification
once the host is unlocked; it is not yet a completed lifecycle pass.

The input probe is now complete. `button-mask-1` and
`button-mask-capture-1` both recorded UIKit `buttonMask=0`, `touch_type=0`,
and synthesized AppKit `event_type=1/2`, `button_number=0` for ordinary and
CUA secondary clicks. The secondary identity is absent before
`WindowViewCompat.m`; do not patch the AppKit number or event type from this
ambiguous touch. An opt-in explicit DE touch-command policy now exists in
`WindowViewCompat.m` behind `AGEPAD_TOUCH_COMMAND_OVERLAY=1`: normal taps
remain selection taps, while the parchment `ORDER` control arms one next
touch for AppKit right-event types. The first installation fixture completed
without a crash but the host was locked before CUA interaction, so this policy
is not promoted. The follow-up raw capture proved the button is now above the
original web surface after a bounded z-order fix; it still lacks a native
interaction proof. The first live press also proved the overlay and map can
be backed by different DE hosts, so command state is now shared across all
opt-in hosts. The retest relocked before map input and ended with an early
`SIGABRT`, so no global-state promotion is allowed yet. The next F4
experiment must run unlocked, prove the event pair and a visible move/order,
then repeat the ordinary selection path with the mode off.

The finish loop therefore has this order:

1. **External precondition:** require the relay to reach
   `DE_GAME_WINDOW_CREATED`; a `SteamAPI_Init`/`GetSteamPath` failure is an
   external stop, not a renderer or input hypothesis. The latest canonical
   run passed this gate; the temporary relay diagnostic now records failure
   stage when it does not.
2. **Presentation:** capture the raw framebuffer and CUA view for the same
   launcher, setup screen and world. Reject any change that does not improve
   the actual visible surface.
3. **Input contract:** keep the UIKit-space event path fixed and instrument the
   original Start Game predicate across the same four-point horizontal grid.
   Only a measured original hit rectangle or a measured transform may change.
4. **Touch slice:** repeat the accepted setup tap, town-center selection,
   move/order, production, drag/camera, cancel/menu return and lifecycle fixture.
5. **Soak and promotion:** measure real cadence and bounded stability only after
   the interaction fixture passes; then move to physical-device and retail gates
   only when their hardware/service inputs exist.

The active goal loop is now deliberately finite and evidence-gated:

1. **F4 touch completion:** from a fresh relay-backed true-landscape fixture,
   prove ordinary taps for setup, town-center selection, one move/order,
   production, camera drag, cancel/menu return and lifecycle return. Record the
   visible state transition and the root coordinates for each pair.
2. **F5 bounded stability:** after F4 passes, run the same candidate for the
   documented observation window, collect composition counts and raw/CUA
   screenshots, and reject any run with helper/relay death during observation.
3. **F6 device gate:** only when a physical device and signing inputs exist,
   repeat the smallest F4 slice there. Do not infer device behavior from the
   Simulator's portrait raw backing.
4. **F7 retail gate:** only when Steam/service authorization inputs exist,
   qualify a genuine multiplayer match. Do not replace this gate with a
   service stub, streaming path, classic R1, or synthetic performance number.

At each step, stop after the first missing evidence, preserve the fixture, and
make one causal change only if the evidence identifies its owner. If F4 passes
in the current bridge, no source change is required for this loop; the next
work is verification and promotion rather than another speculative input patch.

Every iteration records one hypothesis, one causal change, one fixture, the
visible-state result, and the exact artifact. Two failed rounds without a new
milestone park that hypothesis; three remedies for one cause do not authorize a
fourth guess. The classic R1 track stays separate.

## State at loop creation

- Primary route: original DE on the designated Simulator.
- Simulator: reuse `574671AD-6F61-4558-9528-BF946DDB760`; never boot a second
  device.
- Latest DE evidence: the original engine reaches the full-size menu, opens
  Single Player and Skirmish, loads a real world, and accepts a short tap that
  selects the town center. The input bridge now holds mouse-up for 100 ms by
  default and refreshes the release timestamp when it posts the event. This is
  a Simulator interaction milestone, not yet a full touch-slice or FPS pass.
- Supplied input: the Mac DE app is present at `ref/AoE2DE/Age Of Empires II.app`
  and is the current Simulator source. A separate Windows DE executable was
  not found, and `devicectl` reports no connected physical device.
- Unproved: the complete DE touch slice and gameplay command coverage,
  sustained performance on target hardware, Steam authentication, and retail
  multiplayer.
- Parked: further FEX/native teardown and bank-reuse work unless a measured
  current-run failure makes it the smallest causal next step.
- Release state: private-only. No publication, purchase, account change,
  authentication bypass, or rights claim is implied.

### First cycle result

F0 passed read-only: the designated Simulator is the only booted device, and
an owned original DE process remains alive. A real Simulator screenshot shows a
full-size DE world with terrain, minimap, resources, HUD and live units. F2 is
therefore demonstrated for this candidate, with evidence in
`generated/mac-de-simulator-375/checkpoint.md` and the captured process state.

F3 is still open. The short Load tap is delivered through UIKit, queued and
dequeued, sent to the original window, hit-tested, dispatched to the original
handlers, and returns status `0` for both down and up. A held tap reaches the
same path and restores the autosave. The observed difference is temporal: about
`0.08 s` versus `1.0 s`. This makes downstream state sampling or pressed-state
consumption the next hypothesis; it does not justify a duration workaround.

The first cycle made no app update, install, process termination, or source
change. The live scenario remains preserved. The previous Astra-medium audit
worker disconnected without evidence and was closed; no delegation result is
being treated as a finding.

### Latest touch-cycle result

The ABI-correct consumer observer first recorded the event as the original
engine sees it: the real `CFeralNSWindow`, a nonzero window number, matching
down/up types, click count, coordinates and zero modifier/data fields. That
proved delivery but not acceptance. The follow-up clean run is now
`generated/mac-de-simulator-375/touch-default-2`: the default 100 ms release
delay produced fresh release timestamps, opened Single Player, entered
Skirmish, loaded the map, and selected the town center with a visible outline
and unit panel. The game and helper both remained alive for the full 180-second
observation; the run record is `touch-default-2/result.json`. This promotes the
basic menu/selection interaction milestone, while movement, production, drag,
camera, lifecycle return and measured frame pacing remain open.

The next preserved-world observation closed part of that gap without a rebuild:
`production-avui-2` visibly trained a villager, accepted a follow-up action
panel tap, and completed a camera drag/reselection. The action-panel miss is
now treated as a small coordinate-calibration case, not evidence for changing
the original engine or synthesizing commands. A fresh run is only needed for
the bounded neighboring hit grid and the remaining cancel/menu/lifecycle
checks, since reinstalling would discard the current unsaved scenario.

The same live fixture also opened the original parchment Main Menu with
Escape. A normal touch hovered Cancel but did not dismiss it; a held touch at
the same visible button returned to the world. Keep that as an unresolved
coordinate/activation observation until the CUA-to-root mapping is measured;
do not promote it to a release-timing defect or add duplicate events.

The follow-up `touch-detail-1` fixture now rules out the obvious UIKit fields:
short and held production touches at the same root point have the same phase,
touch type, tap count, force/radius, precise coordinate, original event types
and 100 ms down/up interval. Only the held pair visibly queues production.
That, together with Iteration393, makes the next boundary the visible-to-root
coordinate contract. The opt-in consumer observer already proved delivery;
use a mapping probe or a verified acceptance predicate before a behavioral
input patch is justified.

The relay readiness race is fixed in `scripts/run-de-game-relay.py`, and the
legacy compressed-texture backing path now advertises `MTLTextureUsageShaderRead`
in `port/de/MetalDevicesCompat.m`; a clean post-reboot run reached the menu and
survived 180 seconds before this touch fixture. The three Astra-medium audit
attempts in this cycle disconnected before returning evidence; they are not
findings and should not be retried reflexively.

### New F3/F4 boundary: visible control versus accepted logical hit region

The next focused loop is now explicitly:

1. Preserve `touch-default-2` as the last clean baseline and verify the sole
   booted Simulator before any update.
2. Reproduce the Skirmish setup screen with ordinary taps and probe a small
   horizontal grid across the rendered Start Game button.
3. Record both the UIKit/root event coordinate and the visible state change.
4. Fix only the responsible host coordinate contract, then repeat the same
   grid without changing Metal, map data, release timing or the original
   executable.
5. Promote to F4 only after a normal tap succeeds across the visible control,
   town-center selection, one production command, one map order, cancel/menu
   return and a lifecycle interruption.

The accepted Start Game region is not yet stable across clean runs: the latest
pass delivered root `(620.5,657.5)` without transition, while the preserved
fixture and this same run accepted nearby root `(602.95,658.23)`. The 250 ms
release test did not make the documented neighboring miss coordinate work.
The next runtime probe is now an opt-in AVUI observer that forwards the original
`InputHitTestResultCallback` and `NoNested2DFilter` callbacks unchanged and
records the slid GOT slots plus bounded return values. It must be installed and
verified before the fixed point grid is interpreted. The raw framebuffer
also remains portrait-backed while the logical screen and CUA presentation are
landscape. These are presentation/input calibration problems, not permission
to add arbitrary coordinate jitter or duplicate commands. The explicit UIKit
landscape retry is retained for physical UIKit but is not counted as a
Simulator orientation pass. The DE probe package also declares iPad full-screen
and indirect-input support, but those keys are package hygiene only; the
remaining orientation defect belongs to the host geometry/compositor contract.

The observer cycle changed the loop's immediate stop condition: a verified AVUI
GOT hook is not evidence that a user touch reached AVUI. The run must also show
`DE_GAME_WINDOW_CREATED`, a visible main-menu transition, a fresh
`DE_TOUCH_HIT`/pointer record for the second tap, and then an AVUI begin/end
pair. If any earlier transition is missing, classify the run as
`HARNESS/INPUT-LIFECYCLE` and preserve it; do not widen the hit rectangle or
change orientation to compensate.

The next host-geometry trace was deliberately parked at that same gate. The
opt-in trace is ready, but the fresh `host-geometry-1` and `relay-repair-1`
runs stopped at the external Steam/relay startup boundary before
`DE_GAME_WINDOW_CREATED`. The matching relay pair has since been rebuilt, the
designated Simulator's Metal service was restored with one controlled reboot,
and `startup-after-reboot-1` passed that gate: it reached the original window,
main menu, Skirmish setup, live world and town-center selection, then survived
the 180-second observation. The raw and CUA captures still show the portrait
backing/landscape logical-surface defect, while the Start Game miss/neighbor
hit keeps the input contract open. The immediate next experiment is therefore
a measured Start Game hit-grid plus the smallest touch slice; do not repeat
relay repair or Metal reset unless the same external failure recurs.

One reversible observation then narrowed the presentation problem further:
rotating the designated Simulator with its own Rotate control made the live
CUA frame fill landscape and restored readable world/HUD scale without a
reinstall or engine change. `simctl` has no rotate operation, and its raw
capture remains a portrait physical backing containing the landscape world
rotated inside it. Treat Simulator orientation as an explicit fixture
precondition and raw capture as a separate evidence limitation; do not claim
that the existing package orientation keys or a host-geometry trace fixed it.

## Gates and promotion

Each gate needs its own dated evidence. A build, a screenshot, or a helper
process is not enough by itself.

| Gate | Required proof | Promotion rule |
| --- | --- | --- |
| F0 state safe | Git state, exact candidate, owned processes, booted-device inventory, input hashes, and current evidence path recorded | Recheck before every Simulator or install action |
| F1 DE input | Exact supplied DE app/data identity, edition/build confidence, and read-only provenance; a Windows executable is a separate optional input | If the selected input is absent, mark that route blocked and continue only independent work |
| F2 original launch | Existing DE engine reaches a repeatable launcher/world on the designated Simulator with original code/data bytes accounted for | Do not infer gameplay from launcher pixels |
| F3 original interaction | Menu activation, selection, movement, production or equivalent ordinary command succeeds through the real engine | Every input result must show enqueue, dispatch, and visible state change |
| F4 touch slice | Short tap, drag/hold, selection, order, camera, cancel/menu and lifecycle return work without desktop-only input | CUA or pointer evidence is diagnostic unless the event path is verified |
| F5 sustained Simulator play | Fixed fixture runs at a measured cadence for a bounded soak with no growing failures, stale input, or teardown corruption | Report actual frame/composition data, not a proxy counter |
| F6 physical device | Exact candidate is signed, installed, launches, accepts touch/audio, sustains the fixture, and survives lifecycle/persistence checks | Requires connected authorized hardware; Simulator cannot substitute |
| F7 retail multiplayer | Legitimate matching ecosystem, authentication, two real peers, state agreement, disconnect handling, and exact artifact identity | Requires actual service/input authority; no fake or guessed compatibility |

F2–F5 are the current critical path. F6 and F7 stay pending until their
external dependencies exist. A missing dependency blocks only the affected
gate; it does not justify pretending that gate passed or endlessly modifying an
unrelated subsystem.

## The repeatable loop

1. **Read state.** Check this file, `docs/DE-STATUS.md`,
   `docs/WINDOWS-DE-GATES.json`, the latest run record, `git status`, owned
   processes, and `xcrun simctl list devices booted`. Confirm that at most the
   designated Simulator is booted and that the visible app is the demonstrated
   candidate. Record any unsaved scenario before an update.
2. **Pick one lowest unmet gate.** Write a falsifiable hypothesis, the exact
   fixture, the expected observation, and the failure class: `PLATFORM`,
   `ENGINE`, `DATA`, `INPUT`, `HARNESS`, or `EXTERNAL`.
3. **Freeze the case.** Preserve the last good app, save, input manifest,
   executable bytes, source patch and process identifiers. Use one input,
   one SDK/profile, one seed and one command trace.
4. **Make one causal change.** Keep the change at the responsible boundary:
   event enqueue/dispatch, UIKit host lifecycle, Metal resource translation,
   simulation state, or a named service dependency. Do not combine a renderer
   rewrite with input or teardown changes.
5. **Build and run immediately.** Use the existing scripts and isolated output
   paths. Before any install/update, state that an unsaved scenario will be
   restarted. Reuse the designated Simulator and terminate only owned game and
   helper processes after preserving evidence.
6. **Observe ordinary behavior.** Capture command output, exit status, current
   screenshot, input trace, relevant logs, cadence sample, and hashes. A
   timeout, quiet log, or successful allocation is inconclusive unless the
   expected user-visible state is observed.
7. **Classify and journal.** Record expected versus observed, the exact
   artifact, what the test proves, what it does not prove, and the smallest
   next experiment. Update the relevant gate ledger; do not widen claims.
8. **Promote, park, or escalate.** Promote only with the gate's evidence. Park
   after two rounds without a new milestone or after three distinct remedies
   for one cause. On an external blocker, stop spending the critical path on
   speculation and leave a precise reopen condition.

## Current first cycle

The next run starts with a read-only F0/F1 audit:

1. Verify booted-device inventory and owned process state.
2. Verify whether the supplied DE executable/data has appeared under the
   authorized roots; if still absent, preserve the blocked audit.
3. Re-run the shortest world fixture with the default release delay and record
   one ordinary command beyond selection, preferably a move or production
   action, with enqueue/dispatch and visible state evidence.
4. Add only the smallest missing touch behavior: drag/hold, camera, cancel or
   lifecycle return. Keep the 100 ms release timing fixed while measuring it.
5. Once the touch slice is repeatable, run a separately instrumented cadence
   sample and bounded soak. Do not promote composition counts to FPS.
6. If a step fails, do not restart the entire engine reflexively. Reduce the
   case at the first missing transition and record the result before choosing
   the next boundary.

The classic R1 loop may run in a separate isolated output only when it produces
evidence for the preserved iPad single-player track. It must not overwrite the
DE candidate, input identities, saves, or Simulator installation.

## Unblocking ladder

Use these in order and stop once the causal boundary is known:

1. Reproduce with complete logs and exact artifact hashes.
2. Verify route, input, SDK, process, profile, save and cache identity.
3. Inspect the responsible code/data path and compare a known-good checkpoint.
4. Reduce to one event, resource, frame, state transition or service request.
5. Test the smallest real fix and rerun the same fixture.
6. If the same cause survives three distinct fixes, park it with a reproducer
   and move to the next independent gate.
7. If an input, device, signing identity or service is missing, mark the gate
   externally blocked and do not fabricate a substitute.

## Delegation rule

No subagent is needed for ordinary state checks, narrow edits, builds, or
Simulator verification. Spawn an **Astra medium** subagent only when a bounded
task is genuinely complex or the same causal blocker has resisted the ladder.
The delegated task must have a disjoint write set or be read-only, name its
exact evidence deliverable, and preserve the designated Simulator constraint.
The parent agent owns review, integration, promotion and the final claim.

## Definition of finish

The current request is complete only when the precise claimed profile is
green:

- **DE Simulator milestone:** F0–F5 pass with original DE content and a
  repeatable touch/gameplay fixture.
- **DE physical milestone:** F0–F6 pass on the exact signed artifact and
  authorized device.
- **DE multiplayer milestone:** F0–F7 pass with legitimate peers and recorded
  service/version scope.

If F1 or F6/F7 remains unavailable, report the exact milestone reached and the
external dependency. Never call a narrower milestone “the finished project.”
