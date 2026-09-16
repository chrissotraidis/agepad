# Original DE on iPad — current evidence

## Iteration404: shared ORDER state produces a real rally command

Fresh `generated/mac-de-simulator-375/touch-order-global-2/` ran under one
continuous `caffeinate -dimsu` assertion on the sole designated Simulator.
Original launcher, menu, setup, loading, live world and Town Center selection
were observed. ORDER visibly changed to CANCEL; the map target produced
AppKit types 3/4 with button 1 (`game.stderr:15397,15406`), placed a blue rally
flag, and returned to selection mode (`15408`). Villager production completed
to population 5/5. Ordinary Town Center selection worked afterward; its final
screenshot is explicitly labeled post-observation, so it is not soak evidence.

The fixture completed 1200.306 seconds with game and Simulator helper alive
and no helper exit during observation. The world was observed from about
19:33 to 19:43 local time on September 11. The host-path relay intentionally
exits after 60 seconds (see `HostSteamPathRelay.c`); earlier claims of relay
liveness throughout long observations must not be inferred from helper state.
The 30-second composition sample recorded 86 displayed and 16 dropped
completions (2.87/s), not physical scanout FPS. This is a performance concern,
not full-playability promotion. Units are not yet visually identified well
enough to prove a villager move.

Evidence includes `menu-raw.png`, `setup-raw.png`, `loading-raw.png`,
`town-center-selected-raw.png`, `order-enabled-raw.png`,
`rally-order-completed-raw.png`, `composition-live.json`, and `result.json`.
Build/signing, startup-parser tests, safety unit test, Python compilation and
git diff checks passed. The safety scan initially found a username path in
`docs/reviews/EXTERNAL-DEEP-DIVE-PROMPT.md`; replacing it with repository-relative
wording made the scan pass.

First-tap activation remains unresolved. A read-only Astra audit found matching
coordinates and successful original dispatch on misses, but no mouseMoved
event before down. Prior nearby second taps confound geometry with previous
hover state. Next: compare exact same-coordinate repeats with cold taps, then
trace downstream cursor/button consumption. Do not add delay or coordinate
jitter. No input source change was made in this iteration.

The follow-up `touch-activation-1` reached the launcher but CUA reported a
locked Mac. `host-assertions-at-lock.txt` confirms caffeinate still asserted
PreventUserIdleDisplaySleep. The parent deliberately terminated this launcher
at 172.998 seconds and allowed helper cleanup; this is an environment-interrupted
run, not a spontaneous game crash. Manual unlock is required for the exact-point
input diagnostic. No further source change is justified from that interruption.

## Iteration403: command state must cross DE hosts; proof run relocked before retest

The first live interaction with `touch-order-zorder-1` exposed the next causal
boundary. Pressing the visible `ORDER` control produced
`DE_TOUCH_COMMAND_MODE mode=order` on a host whose map was not the host that
received the next touch. The map pair then logged ordinary
`DE_SYNTH_MOUSE event_type=1/2 button_number=0` at
`game.stderr:23327-23375`, and the selected Town Center visibly cleared while
the overlay remained `CANCEL`. This is a host-scoping bug, not evidence that
the explicit policy itself is wrong.

`WindowViewCompat.m` now keeps the opt-in command state process-wide across
all `DEGameViewHost` instances and refreshes every overlay button when the
state changes or the target completes. The rebuilt candidate was launched as
`generated/mac-de-simulator-375/touch-order-global-1/`; Steam discovery,
original window creation and the original DE surface all initialized. The Mac
relocked during the splash transition before CUA could repeat the live-world
probe. That run ended early at `171.26` seconds with a `SIGABRT` signal trace
and no command event, so it is not a stability or input pass and needs a fresh
unlocked observation rather than interpretation as a global-state failure.

## Iteration402: ORDER control is visible above the original DE surface
## Iteration402: ORDER control is visible above the original DE surface

The follow-up fixture `generated/mac-de-simulator-375/touch-order-zorder-1/`
rebuilt the opt-in command overlay after the first capture showed it hidden
under the original full-size web view. The bounded z-order fix keeps the
parchment `ORDER` button above later-added original subviews. The preserved
raw Simulator capture is `launcher-zorder-raw.png`; it visibly shows the
control over the original launcher artwork rather than a replacement screen.

The fixture completed its `60.05` second observation with the helper and relay
alive (`result.json`). The host was still locked, so no native press, command
event, live-world move/order, or ordinary-selection regression is claimed.
The next run should use this candidate, enter a live world, press the visible
button, and verify the explicit AppKit event pair before testing gameplay.

## Iteration401: explicit ORDER control is installed, interactive proof awaits an unlocked host

The bounded fixture `generated/mac-de-simulator-375/touch-order-overlay-1/`
was rebuilt from the current `port/de` candidate with
`AGEPAD_TOUCH_COMMAND_OVERLAY=1`. The new control is opt-in and uses the
game's parchment-adjacent brown/gold treatment. The app log records
`DE_TOUCH_COMMAND_OVERLAY installed style=parchment` during host construction,
and the fixture reached the original launcher with the original artwork and
web surface intact. The fixture survived `180.14` seconds with the helper and
relay alive (`touch-order-overlay-1` launch/result output).

The Mac was locked for this run, so CUA could not enter Single Player or press
the control. No `ORDER` mode transition, synthesized right-event pair, unit
move, or order is claimed. The next run must begin with the host unlocked,
capture the live-world control, press `ORDER`, and verify
`DE_TOUCH_COMMAND_EVENT` phases `1/2` as AppKit types `3/4` with
`button_number=1`. It must then repeat one ordinary tap with the mode off and
prove the original selection path is unchanged before any promotion.

## Iteration400: CUA secondary input is flattened before the AppKit bridge

The fresh relay-backed fixture `generated/mac-de-simulator-375/button-mask-1/`
was run with `AGEPAD_BUTTON_MASK_TRACE=1` and the designated Simulator as the
only booted device. It reached the original launcher, Skirmish, a live world,
and a visible Town Center selection. The bounded observation then completed in
`240.18` seconds with helper and relay alive during observation
(`button-mask-1/result.json`); the post-cleanup process is not a stability
claim.

An ordinary Town Center click produced UIKit `mask=0`, `touch_type=0`, and the
synthesized AppKit pair `event_type=1/2`, `button_number=0` at
`game.stderr:12613-12642`. A CUA right-click at the neighboring map point
produced the same UIKit and synthesized values at `game.stderr:12880-12927`
and visibly cleared the Town Center selection. The secondary-button identity
is therefore absent before `WindowViewCompat.m`; changing AppKit button
numbers now would fabricate input semantics. The next bounded probe enables
the Simulator toolbar's Capture Pointer mode and repeats the same fixture. If
that still yields `mask=0`, the input route must be redesigned as an explicit
touch gesture policy rather than a right-click shim.

The follow-up `button-mask-capture-1` fixture repeated the same probe with the
Simulator toolbar's Capture Pointer and Capture Keyboard both enabled. The
live-world probe again produced `mask=0`, `touch_type=0`, and synthesized
`event_type=1/2`, `button_number=0` for both the ordinary click and the CUA
right-click (`game.stderr:20088-20188`). Capture mode also left the measured
setup hit region less reliable. It does not provide a usable secondary-button
route for this candidate. Its bounded observation completed in `180.14`
seconds with helper and relay alive (`button-mask-capture-1/result.json`).

The next DE input work must therefore be an explicit, documented touch-command
policy or a supported native pointer event source. Do not infer a right mouse
event from an undifferentiated UIKit touch, and do not promote either fixture
to a genuine move/order result.

## Iteration399: repaired lifecycle candidate survives a full touch fixture, but unit order is still unproved

After the host became available again, the patched candidate was relaunched in
the fresh relay-backed fixture `generated/mac-de-simulator-375/final-touch-1/`.
The designated Simulator stayed the only booted device. The setup grid again
showed the narrow calibration: ordinary `[430,522]` hovered with the original
tooltip, while `[440,522]` entered the original loading screen. A normal tap
at `[420,325]` selected the Town Center and produced the original selection
outline (`game.stderr:11864-11910`). The raw world capture is
`final-touch-1/live-current-raw.png`; it shows the original terrain, fog and
HUD, not a replacement renderer.

The fixture recorded complete touch down/up and original-window dispatch pairs
for the action-panel and map probes, with status `0` throughout. A CUA
right-click probe also became an ordinary type-1/type-2 pair at root
`(591.5,398.5)` (`game.stderr:19320-19364`) and visibly cleared the selection,
but no unit moved and no attack/order state appeared. The bridge therefore has
not yet proven a genuine unit order, and this is not permission to synthesize a
right-click or duplicate events. Production remains proven by `mapping-3` at
the accepted `[67,570]` point; the final fixture did not produce a stronger
production-state artifact.

The repaired candidate reached `DE_GAME_WINDOW_CREATED` and survived the full
`300.17` second observation with helper and relay alive during observation
(`final-touch-1/result.json`). The host locked again while targeting a villager,
so foreground restoration and a genuine unit order remain open. The next
bounded probe is the opt-in `AGEPAD_BUTTON_MASK_TRACE`: it records UIKit's
primary/secondary button mask and the synthesized AppKit type/number for the
same CUA right-click without changing behavior. Only a recorded secondary mask
can justify changing the synthesized AppKit event to its right-mouse
type/number contract. Treat the post-cleanup game process as unsupported for
soak claims, as in prior runs.

## Iteration398: the mirror-state boundary is removed, but foreground proof needs an unlocked host

The `mapping-3` fixture was a fresh relay-backed run on the sole designated
Simulator. Its setup calibration shifted relative to `mapping-2`: ordinary
`[430,522]` showed the original start tooltip, while neighboring `[440,522]`
entered the original loading screen and then a live world. In that world,
ordinary `[67,570]` entered Create Villager production and the HUD reached
`5/5` after completion. `Escape` opened the original parchment pause menu;
ordinary cancel `[425,430]` only hovered, while neighboring `[430,430]`
returned to the world. These are real touch-slice results, but the launch-to-
launch setup and cancel accepted regions are still narrow enough that F4 is
not promoted to general usability.

The Simulator Home control successfully backgrounded the game. A subsequent
attempt to foreground it through the app icon and `simctl launch` did not
restore the visible game surface. The trace then identified the exact old
boundary during lifecycle work: `_CGDisplayIsInMirrorSet` was routed to the
fail-fast CoreGraphics stub, with the original `InputMappingList` activation
stack at `game.stderr:31020-31031`. The CUA host locked before a second visual
foreground attempt, so this result is recorded as an external verification
limit as well as a real lifecycle failure observation.

The bounded causal fix is now in `port/de/DisplayLifecycleCompat.m` and the
boundary builder: on this single UIKit display, `_CGDisplayIsInMirrorSet`
returns false instead of aborting. The generated candidate was rebuilt and
signed. Fresh `lifecycle-mirror-1` reached `DE_GAME_WINDOW_CREATED` with no
mirror boundary in its log and survived the full `120.14` second observation;
both helper and relay were alive during observation
(`lifecycle-mirror-1/result.json`). This proves the startup side of the fix,
not foreground visual restoration. Re-run the Home/foreground check after the
host is unlocked, then continue F4 with a genuine unit-order target. A focused
Astra-medium audit of headless lifecycle control disconnected before returning
evidence; it is recorded as no finding and does not justify another speculative
delegation.

## Iteration396: ordinary setup tap is proven in the true-landscape fixture

The fresh relay-backed fixture `generated/mac-de-simulator-375/mapping-2/`
was intentionally started from the current installed candidate after the
previous unsaved world. This was a controlled fixture reset, not an app update;
the earlier unsaved scenario was discarded. The designated Simulator remained
the only booted device, and the fixture reached
`DE_GAME_WINDOW_CREATED` with the relay alive.

On the original Skirmish setup screen, ordinary CUA `[420,522]` left the
screen unchanged and showed the original `Click to start the game` tooltip.
The neighboring ordinary CUA `[430,522]` entered the original loading screen
and reached a live world. The trace contains complete UIKit down/up details
and original-window dispatches for the setup interaction; the preceding miss
is recorded around `game.stderr:8577-8658`, and the accepted transition path
continues around `9277-9839` as the game changes screens.

The same ordinary-tap path then selected the Town Center at visible CUA
`[420,325]`, producing the original selection outline and unit panel
(`game.stderr:13409-13458`). An ordinary action-panel tap at `[67,594]`
showed the original Loom tooltip (`13879-13929`). A later ordinary villager
point at `[62,570]` also produced the original Create Villager tooltip
(`14454-14498`). These results establish usable ordinary taps across setup,
world selection and the action panel when the Simulator is kept in its true
landscape presentation.

The fixture survived the full `240.03` second observation with the helper and
relay alive during observation (`mapping-2/result.json`). As in the prior run,
the post-cleanup game process is not treated as a stability test. No source
change was made. F4 is still open only for the remaining move/order,
production acceptance, cancel/menu return and lifecycle-return checks; the
next run must preserve the true-landscape presentation and keep the relay
alive while completing those states.

The matching raw Simulator capture is `mapping-2/live-world-current-raw.png`.
A bounded 30-second composition sample recorded `938` displayed completions,
zero drops and `31.26` callbacks per second in
`mapping-2/composition-live.json`. This remains Simulator composition evidence,
not physical scanout or per-frame latency, so it does not advance F5 by itself.

## Iteration395: the true landscape fixture restores ordinary taps across the core slice

The fresh relay-backed fixture `generated/mac-de-simulator-375/mapping-1/`
was launched while the designated Simulator was in its true landscape
presentation. It reached the original launcher, main menu, Single Player,
Skirmish setup and a live world, then stayed alive with its helper for the full
`300.26` second observation (`mapping-1/result.json`). A prior attempt to
activate Play after the relay had already been cleaned up detached the launcher
and aborted; that is now classified as a stale-lifecycle failure, not a
coordinate or rendering result.

In the fresh fixture, ordinary taps worked for Single Player and Skirmish
(`game.stderr:6246-6310`), town-center selection at root `(574.5,352)`
(`15067-15115`), and a normal camera drag (`11729-11781`). The ordinary Start
Game tap still hovered the visible control at root `(450.5,514.5)`
(`8838-8924`); the calibrated one-point activation path entered the live world
at root `(607,657)` to `(608.5,657)` (`9891-9943`). The repeatable cause is
therefore a narrow original accepted region on the setup control, not blanket
touch delivery failure.

The live action panel gave the same useful boundary. A normal tap at the
visible Create Villager point delivered root `(35.5,731)` and showed only its
tooltip (`26759-26809`). A one-point adjacent drag moved the release to root
`(37,731)` and entered production (`28191-28240`). A normal tap five CUA pixels
left delivered root `(28,731)` and produced the original `You need more houses`
state after the queue completed (`29372-29421`). This is ordinary tap evidence
for the actual accepted action region, but it also confirms that the rendered
button is still too easy to miss at its edge. The raw captures are
`live-world-current-raw.png` and `normal-action-house-limit-raw.png`.

The same fixture produced a 30-second bounded composition sample with `949`
displayed completions, zero drops and `31.63` callbacks per second in
`mapping-1/composition-live.json`. As before, this measures Simulator
composition notifications, not physical scanout or per-frame latency. The
world capture shows the original game's dark unexplored map and fog state; it
does not justify replacing terrain or background rendering with a substitute.

The orientation source already requests landscape through the scene geometry,
legacy device handoff and package manifest. The reliable fixture requirement is
therefore to leave the designated Simulator in its true landscape state before
launch; another orientation or coordinate patch is not justified by this run.
F4 remains open for a normal Start Game tap, full action-panel coverage,
move/order and menu/lifecycle return. F5 physical promotion, F6 physical
device execution and F7 genuine retail multiplayer remain open.

## Iteration394: live-world re-entry and bounded cadence are repeatable, but presentation still splits

The `interaction-release-1` fixture was used to re-enter a fresh live world
after the setup-screen calibration. The calibrated CUA drag produced a real
down/up pair at root `(628.5,657)` and both original-window dispatches returned
status `0` (`game.stderr:81090-81143`). This is a repeatable setup-to-world
transition through the existing bridge, but it is not evidence that ordinary
visible-control clicks are usable: the preceding normal Start Game click still
landed at root `(449,514.5)` and only hovered the control
(`game.stderr:77304-77383`).

Two bounded composition measurements on the sustained fixture observed
`1077` displayed completions in 30 seconds and `2136` in 60 seconds, with zero
dropped completions. The measured callback rates were `35.90` and `35.60` per
second. These artifacts are
`generated/mac-de-simulator-375/interaction-release-1/composition-live-1.json`
and `composition-live-2.json`; their declared scope is Simulator composition
notifications, not physical scanout or per-frame latency. The matching raw
capture is `sustained-world-raw.png`. This is useful bounded cadence evidence,
but F5 remains open until the evidence contract calls for more than Simulator
composition callbacks.

The lifecycle probe backgrounded the app and returned to SpringBoard. A clean
relay-backed launch then restored the same installed DE candidate, and the
Simulator Rotate control was used to make the logical landscape surface
visible again. The clean launch intentionally discarded the unsaved world;
this was a visible-candidate reset, not an app update. The current CUA view is
the original DE launcher with the game surface centered inside black margins,
while `simctl io screenshot` remains a portrait `1640x2360` backing containing
the rotated landscape surface. Keep the raw/CUA split explicit: it is not a
license to add an arbitrary coordinate offset or duplicate touch events.

The next loop remains a measured CUA-to-root mapping experiment on the same
fixture, followed by a normal-tap touch slice. F4 ordinary usability, F5
physical-performance promotion, F6 physical-device execution and F7 genuine
retail multiplayer are still open.

## Iteration393: the apparent hold fix is a coordinate-space split, not a timing fix

The fresh `interaction-release-1` fixture reached the original launcher, main
menu, Single Player, Skirmish setup and a live world on the sole designated
Simulator. On the setup screen, a normal CUA click at the visible Start Game
button produced a complete down/up pair at root `(449,514.5)` and only hovered
the control (`game.stderr:10476-10559`). The nearby CUA drag path produced a
different pair at root `(597.5,657)` and transitioned into the live match
(`game.stderr:11244-11296`). The two actions must not be described as a
short-versus-held comparison: they exercised different coordinate paths.

The same live world makes the remaining action-panel issue concrete. A normal
click at the visible Create Villager icon delivered root `(25,731)` and only
showed its tooltip (`game.stderr:24450-24500`); a one-point drag delivered the
same visible control at `(26.5,731)` and entered production. A subsequent
normal click at `[61,570]` produced the original `You need more houses` state,
showing that the engine and release path are functional but the accepted
logical region is extremely narrow relative to the rendered control. The raw
artifact is `generated/mac-de-simulator-375/interaction-release-1/action-boundary-house-limit-raw.png`.

An ordinary-click calibration grid then mapped CUA x inputs
`[55,57,59,61,63,65,67]` to root x values
`[17,20,23,26.5,29.5,32.5,35.5]` at the same y (`game.stderr:46413-46835`).
The mapping is stable and linear enough to use as a fixture calibration; it is
not evidence that a held gesture is required. The next setup retry should use
this measured mapping to target the rendered button, then compare one adjacent
point and the resulting original state change.

This rules out promoting a release-delay or duplicate-event workaround. It
does not yet prove whether the remaining transform belongs to the CUA harness
or the UIKit/legacy host contract. The next experiment must use a measured
screen-to-root mapping on the same fixture, with one known point and one
neighbor, before any source-level coordinate change. The Astra-medium review
requested for this distinction also disconnected before returning evidence;
that is recorded as no finding.

## Iteration392: UIKit touch-detail trace rules out field differences

The fresh bounded fixture `generated/mac-de-simulator-375/touch-detail-1/`
rebuilt the same original DE candidate with an opt-in, read-only UIKit touch
trace. It reached the original launcher, menus, Skirmish setup, live world and
town-center selection, then remained alive with its helper for the full
`180.09` second observation. The installed AVUI observer still verified both
GOT hooks and the relay reached `DE_GAME_WINDOW_CREATED`.

At the same calibrated root point `(25,731)`, the short production tap and the
held production touch produced identical `DE_TOUCH_DETAIL` fields: phase 0/3,
touch type 0, tap count 1, force 0, major radius 20 on down and 0 on up,
precise coordinates `(25,731)`, and a 100 ms original down/up interval. Both
events reached `CFeralNSWindow` with status 0. The short pair is
`game.stderr:22779-22825`; the held pair is `24132-24177`. Only the held pair
visibly entered the original queue; its screenshot is
`touch-detail-1/villager-created-traced.png`.

This rules out a missing UIKit touch field, coordinate transform, or basic
original dispatch failure as the immediate cause. It does not yet identify the
private engine's acceptance predicate, and the Astra-medium read-only audit
disconnected before returning evidence. The next allowed experiment is a
fresh consumer-boundary trace or one measured original acceptance predicate;
do not add duplicate mouse events, widen rectangles, or change rendering to
compensate. The current fixture is now the trace baseline, and F4/F5 remain
open.

## Iteration391: production, camera drag and reselection work in the live original world

Without rebuilding or reinstalling, the preserved `production-avui-2` world was
used for the next smallest touch slice. A held touch on the visible Create
Villager control at root `(25,731)` entered the original town-center queue;
the Simulator screenshot showed `Creating 2.2%`. After the villager completed,
a normal tap at the same calibrated point produced the original red
`You need to build more houses` response and the HUD advanced from `4/5` to
`5/5`. The matching enqueue/dequeue and original-window dispatch records are
in `game.stderr:34100-34148` and `36819-36867`. The exact raw artifact is
`generated/mac-de-simulator-375/production-avui-2/villager-created-and-house-limit.png`.

This narrows the earlier production miss: the event path and original consumer
are functional, but the rendered action-panel hit area is sensitive to a few
root-coordinate points. Do not widen the rectangle or add duplicate commands;
keep the calibrated point and measure the neighboring action-panel grid in a
fresh fixture when the current unsaved world is intentionally restarted.

A world drag from CUA `[450,330]` to `[560,330]` changed the visible camera and
cleared selection; a subsequent normal touch reselected the town center. The
drag/reselection records are `game.stderr:40801-40810` and `42001-42026`, with
the paired screenshot at
`generated/mac-de-simulator-375/production-avui-2/camera-pan-and-reselect.png`.
This is camera and selection evidence through the real UIKit-to-original path,
not a claim that the complete touch slice is finished. Cancel/menu return,
lifecycle return, a bounded action-panel grid and measured cadence remain open.

The bounded action-panel grid then delivered five more complete down/up pairs:
CUA x `[54,57,60,63,66]` mapped to root x approximately
`[15.5,20,25,29.5,34]` at y `731`. The original house-limit state remained
visible in `action-panel-grid-house-limit.png`; the event records are
`game.stderr:50852-51273`. This is calibration evidence, not proof that every
sample was accepted by the game. `Escape` was also delivered through the
existing keyboard route but did not open a visible in-game menu, so cancel/menu
return remains open and is not being promoted from that probe.

The menu boundary was then qualified in the same run. A second `Escape` opened
the original parchment Main Menu; a normal touch at the visible Cancel button
hovered it but left the popup open (`game.stderr:61983-62029`). A held touch at
the same root point `(587,517.5)` dismissed the popup and returned to the live
world (`game.stderr:62604-62652`), with the repeated menu-close attempt also
requiring the held form (`66572-67249`). Paired visual artifacts are
`in-game-menu.png` and `menu-return-final.png`. This is a real menu/cancel
transition, but it also confirms that the current short-touch contract is not
yet usable enough for promotion: the next source experiment must measure and
fix the release/activation threshold at the adapter boundary, without
changing the original engine or fabricating clicks.

## Iteration390: Simulator rotation confirms the outer presentation state

With `startup-after-reboot-1` still alive and no reinstall or source change,
the designated Simulator's own Rotate control was used once. The same live
world immediately filled the visible CUA landscape frame: terrain, HUD,
minimap, town-center panel and selection outline became large and usable
instead of sitting in portrait letterbox bands. This is a reversible
presentation observation, not a new engine candidate or a touch pass.

The paired `simctl io screenshot` remains a `1640x2360` portrait backing; after
rotation it contains the landscape world turned inside that physical buffer.
The app's landscape plist and UIKit geometry requests therefore do not by
themselves change the legacy Simulator device orientation. The manual Rotate
state is a harness prerequisite for the visible CUA candidate, while raw
framebuffer orientation remains open for evidence quality and physical-device
promotion. `simctl` exposes no rotate operation, so do not claim that a
package-key or host-geometry edit solved this state.

The next bounded input experiment can use the now-readable landscape CUA
surface, but it must preserve the orientation state in its fixture and record
both CUA/root coordinates. The original Start Game miss/neighbor hit and the
unreproduced production action remain the lowest unmet interaction evidence.

## Iteration389: Metal launch gate removed; DE world and 180s fixture restored

The previous startup stall was isolated to the diagnostic probe, not the
original engine. `port/de/LoaderProbe.m` now defers its synchronous
`MTLCreateSystemDefaultDevice` and shader-library survey when the original
engine owns the launch path, so UIKit can hand control to the real DE
executable first. The earlier bounded sample, `startup-sample-1`, captured
the main thread blocked inside that probe call through Metal Simulator XPC;
that stack is diagnostic evidence, not a game-rendering failure.

The current relay pair was rebuilt from the matching source/protocol and
passed a standalone request/reply smoke test. After one controlled reboot of
the designated Simulator to restore its Metal service, the bounded fixture
`generated/mac-de-simulator-375/startup-after-reboot-1/` reached Steam
discovery, `DE_METAL_DEVICES actual_count=1`, a real original game window,
the launcher, main menu, Single Player, Skirmish, a live world and a visible
town-center selection. The run remained alive for `180.16` seconds with the
helper alive, repeated displayed drawable composition records, and no
`DE_FIRST_SIGNAL` or unsupported-boundary termination. The reboot reused the
only allowed device; no second Simulator was booted.

The paired CUA screenshots are visual evidence of the original launcher and
menus. `live-world-selected-raw.png` is raw framebuffer evidence of actual
terrain, fog, HUD, minimap and selection state. It also confirms the remaining
presentation defect: the raw backing is portrait (`1640x2360`) around a
landscape logical world (`1180x820`) with black bands. This is still not an
acceptable presentation pass.

The same run gives a narrower input failure. The first visible Start Game
attempt delivered a genuine down/up at root `(608.707,656.073)` but did not
transition; a nearby point `(595.756,656.073)` did transition into the live
match. Town-center selection delivered at `(588.561,339.488)` and visibly
worked. A production tap was delivered at `(125.915,747.451)` but did not
produce a new visible state, so the older `move-command-2` production
artifact remains the only production evidence. The next experiment is a
measured Start Game hit-grid and touch-slice run; no renderer, orientation or
release-timing change is justified by this evidence.

This promotes the repeatable original-launch/world milestone and the basic
menu/selection interaction milestone. F4 full touch coverage and measured
F5 cadence remain open; physical-device and retail-multiplayer gates remain
external and unstarted.

## Iteration388: host-geometry probe parked at the external startup gate

The next bounded source change was diagnostic only. `port/de/WindowViewCompat.m`
now has an opt-in `AGEPAD_HOST_GEOMETRY_TRACE` record at layer attachment,
window ordering and full-screen completion; it reports the UIKit scene
orientation, logical/native/coordinate-space bounds, root/host/layer frames and
layer transform without changing rendering or input. The runner now exposes
that flag and the existing geometry trace only when explicitly requested.

`host-geometry-1` did not reach this presentation gate. It remained on the
white pre-window surface, then stopped after `190.8` seconds at the genuine
Steam dependency failure: `DE_STEAM_DISCOVERY` found the helper, but
`SteamAPI_Init()` still reported `ipcserver GetSteamPath failed`. It emitted no
`DE_GAME_WINDOW_CREATED`, so it is not orientation, rendering, touch or FPS
evidence. Evidence is `generated/mac-de-simulator-375/host-geometry-1/`.

The owned helper's generated `IPCSystemCompat.dylib` was older than its source,
so it was rebuilt in place for one retry. `relay-repair-1` then remained on the
same white pre-window surface without a game-window record and was interrupted
after a bounded observation; its relay/helper transcript is preserved under
`generated/mac-de-simulator-375/relay-repair-1/`. The retry also exposed a
cleanup race when a helper exited between `kill -0` and `ps`. The runner now
treats that exact race as already-cleaned while retaining the wrong-process
refusal. The exact game PID left by the interrupted run was terminated and the
designated Simulator has no owned game/helper/relay process.

The active failure class is therefore `EXTERNAL/STEAM-IPC` with a secondary
`HARNESS/CLEANUP-RACE`. Reopen the host-geometry experiment only after an owned
relay run produces `DE_GAME_WINDOW_CREATED` and a visible main-menu transition.

## Iteration387: bounded AVUI hit-test observer prepared

The latest user-visible failure is still an unplayable control contract: the
original engine can render the launcher, setup screen and world, but a
delivered Start Game point is not consistently accepted. Two new Astra medium
investigations disconnected without evidence; a completed static audit did
establish that `InputHitTestResultCallback` and `NoNested2DFilter` are weak
exports with bound GOT slots in the original and installed engine.

The one bounded source change in this iteration is an opt-in, return-preserving
observer in `port/de/AVUIHitTestTrace.c`, built by
`scripts/build-de-avui-hit-test-trace.py` and enabled only with
`AGEPAD_AVUI_HIT_TRACE=1`. It records installation against the verified
`DEOriginalGame` GOT slots and at most 256 callback results; it does not read
private object layouts or modify input, geometry, rendering, timing or game
state. At preparation time there was no runtime result. The first runtime gate
must reach
`DE_GAME_WINDOW_CREATED`, then show `DE_AVUI_HIT_INSTALL ... input=1 filter=1`,
before any Start Game grid is treated as evidence.

The designated Simulator remains the only booted device. An orphaned native
process from the old `generated/mac-de-simulator-351/native-control` fixture
was found and terminated before the next controlled run; it was not part of the
current Simulator candidate.

The controlled follow-up produced three distinct outcomes. `avui-hit-1` stopped
in the harness because the first symbol spelling was injected into the Steam
helper; `avui-hit-2` reached the game launch but aborted on the same unresolved
symbol. Those were corrected without changing the engine candidate. In
`avui-hit-3`, the observer verified `input=1 filter=1`, reached
`DE_GAME_WINDOW_CREATED`, and showed the original launcher and main menu. The
later interactive attempt ended in `DE_FIRST_SIGNAL sig=6` after 106.7 seconds,
with no `DE_AVUI_HIT_BEGIN` record. `avui-hit-4` and `avui-hit-5` again verified
the GOT hooks but remained on the white pre-window surface for 136.9 and 102.6
seconds before clean owned-app termination. Evidence for all three is under
`generated/mac-de-simulator-375/`.

This parks the rectangle hypothesis. The next loop may reopen the four-point
grid only after one run repeats the main-menu transition and records a second
delivered touch at the intended Single Player/Skirmish control. Until then the
active failure class is `HARNESS/INPUT-LIFECYCLE`, not `GEOMETRY`; no coordinate,
release-delay or renderer change is justified.

## Iteration386: fresh grid attempt parked at an intermittent transition

A fresh canonical run using the same cleaned host and no new source change
accepted the launcher Play tap, showed the Feral splash, and then remained on
a black surface for `318.3` seconds. The process continued to emit drawable
composition records and did not emit `DE_UNSUPPORTED_BOUNDARY` or
`DE_FIRST_SIGNAL`; it never reached the main menu, so no Start Game grid was
collected. The owned app was terminated and the helper/relay cleaned up
normally. Evidence: `generated/mac-de-simulator-375/start-grid-clean-1/`.

This is an intermittent post-Play transition observation, not evidence for a
new coordinate transform or renderer patch. Park it after the new milestone
from Iteration385 and preserve `presentation-clean-1` as the promotion
fixture. Reopen the hit-test grid only after a run reaches the main menu and
Skirmish setup again.

## Iteration385: clean host surface and full DE interaction fixture restored

The canonical runner was rebuilt after the host probe view was changed to a
black root/window background and its diagnostic `UITextView` was hidden in
`port/de/LoaderProbe.m`. The installed candidate was refreshed in place, so
the previous unsaved scenario was discarded. A real CUA/Simulator pass then
showed the original launcher without the exposed white diagnostic surface,
the full main menu, the Single Player dialog, Skirmish setup, the loading
screen, and a live world with terrain, HUD, minimap and fog of war. A tap
selected the town center and produced its original outline and unit panel.

The exact evidence is `generated/mac-de-simulator-375/presentation-clean-1/`.
The raw Simulator capture `raw-world.png` still shows the portrait-backed
framebuffer with the landscape world rotated, so this is not an orientation
pass. The visible CUA surface is landscape with intentional black letterbox
areas; the white probe artifact is gone.

The relay was also revalidated with a temporary diagnostic helper: genuine
host path replies returned with `transport=0`, and the canonical run loaded
Steam successfully before creating the game window. The original process
remained alive for `538.4` seconds; terminating only the owned bundle produced
normal helper/relay cleanup. The first clean-run Start Game tap at root
`(620.5,657.5)` was delivered but did not transition, while the known prior
accepted point near `(602.95,658.23)` did. Keep the hit-test problem open and
do not infer a new transform from this one-point result.

## Iteration384: native hit-test boundary identified statically

A read-only audit of the supplied original arm64 binary identified the next
named input boundary without changing the candidate or launching another
pre-window run. The binary exposes AVUI hit-test/input symbols including
`AVUI::InputHitTestResult::InputHitTestResultCallback`,
`AVUI::TopMostHitResult::NoNested2DFilter`, and `AVUI::MenuBase` mouse-button
handlers. It also contains the `Age2ScreenSinglePlayerCreate` object factory
and the named handlers `SelectScenarioPressed`, `LocationPressed`,
`CheckDefaultsByGameMode`, and `ClosePressed`.

This does not prove the Start Game rectangle or justify a binary patch. When
the Steam relay again reaches `DE_GAME_WINDOW_CREATED`, the next bounded
runtime probe should observe the AVUI hit-test result or the
`Age2ScreenSinglePlayerCreate` callback while preserving return values. The
same Steam IPC failure still precedes that window-creation gate, so no runtime
probe was launched in this iteration. Exact static findings are recorded in
`generated/mac-de-simulator-375/static-hit-test-audit.txt`.

## Iteration383: fresh relays hit the Steam IPC barrier before a game window

Two fresh runs after the presentation audit reached the original launch
callback and verified/loaded the Steam module, but then stopped at the same
external dependency:
SteamAPI_Init() failed; ipcserver GetSteamPath failed, and
SteamAPI_Init(): Could not determine Steam client install directory.
Neither run emitted DE_GAME_WINDOW_CREATED, so they are not rendering,
orientation, touch, or stability evidence. The designated Simulator remained
the only booted device and is now back at the home screen. Evidence:
generated/mac-de-simulator-375/probe-background-1/ and
generated/mac-de-simulator-375/probe-background-2/.

A short-lived probe-surface cleanup was reverted because it could not be
validated before this dependency. The installed/package candidate is restored
to the last demonstrated boundary baseline. Reopen this loop only when the
owned Steam IPC relay produces a real DE_GAME_WINDOW_CREATED line; do not
spend another renderer or coordinate change on a pre-window Steam failure.

## Iteration382: aspect-preserving layer composition did not fix the presentation

The bounded AGEPAD_LAYER_ASPECT_FIT=1 experiment set the hosted Metal layer
to kCAGravityResizeAspect while leaving input and original-engine code
unchanged. It produced the expected DE_LAYER_GRAVITY mode=resizeAspect
traces, but the Simulator still showed the same constrained/rotated legacy
surface and no repeatable improvement to the launcher/background contract.
The run ended after about356seconds with DE_FIRST_SIGNAL sig=6 and recorded
no DE_GAME_TOUCH, so it supplies no touch or soak evidence. The toggle was
removed; the normal contentsGravity=resize path remains the baseline.
Evidence: generated/mac-de-simulator-375/aspect-fit-1/.

## Iteration381: package orientation contract did not change the host surface

The reproducible DE probe builder now declares `UIRequiresFullScreen` and
`UIApplicationSupportsIndirectInputEvents`, matching the existing iPad probe
packaging contract. The installed candidate was updated in place after the
previous unsaved match was intentionally discarded. A fresh run reached the
original launcher, main menu, Single Player dialog, Skirmish setup and the
loading screen, so the metadata change did not regress startup or ordinary
menu dispatch.

It did not rotate the designated Simulator's raw surface: the current runtime
still reports a landscape logical display of `1180x820` over a portrait
`1640x2360` backing, and a fresh raw screenshot shows the original world/HUD
rotated inside that backing. The CUA presentation remains landscape and shows
the original artwork, terrain, minimap and HUD, but this is not a passed
orientation or usability result. Evidence:
`generated/mac-de-simulator-375/orientation-contract-1/` and
`/tmp/orientation-contract-raw.png`.

The next smallest experiment is the host geometry/orientation contract itself;
do not treat these package keys as the renderer fix.

## Iteration380: drawable/pointer-space remap rejected; restored path remains good

An opt-in remap of touch events and `NSEvent.mouseLocation` into the original
Metal drawable's `1920x1280` space was tested against the same main-menu and
Skirmish setup fixture. It changed a visible menu tap into logical coordinates
around `(367,841)` and the original engine ignored the menu activation. The
known-good path delivers the UIKit-space point directly and again reaches the
real menu, setup, live world and town-center selection in
`generated/mac-de-simulator-375/restored-input-1/`. The remap was removed from
the source and is not part of the visible candidate.

This isolates the drawable-size mismatch as a rendering/presentation clue,
not a justified input scaling rule. No coordinate jitter, duplicate event or
forced original command was added. Production, drag/camera, cancel/menu return,
orientation acceptance and sustained cadence remain open.

## Iteration379: setup hit geometry is narrower than the rendered control

The designated Simulator was reused with the rebuilt AppKit/CoreGraphics/Metal
boundaries and the same original DE candidate. The launcher, main menu, Single
Player dialog and Skirmish setup all accepted ordinary taps. On the setup
screen, a tap at the visible Start Game button's apparent center did not start
the match at root input x=607, while taps only a few screen points to the right
at root x=614 and x=620 did start the match. The rendered red button is much
wider than this accepted slice. This is direct evidence of a visual-to-logical
hit-region mismatch, not a release-delay fix. The 250 ms release experiment
also failed at the same miss coordinate, so longer mouse-up timing is not the
current remedy. Evidence: `generated/mac-de-simulator-375/touch-delay-250/`
and `generated/mac-de-simulator-375/orientation-retry-1/game.stderr`.

The successful match then accepted an ordinary town-center tap and showed the
original selection outline and information panel. World rendering is visible
in the CUA landscape presentation, while the raw Simulator framebuffer still
reports a portrait backing (`1640x2360`) beside a landscape logical surface
(`1180x820`); the rotated raw capture shows the HUD upside down. The UIKit
host now re-requests landscape after `viewDidAppear`, but this legacy host still
does not change the physical Simulator orientation. Keep this as an open
presentation/input-boundary defect, not a passed orientation gate.

`geometry-trace-1` and `geometry-trace-2` are harness/process failures: both
terminated before a traced touch, with helper alive and SIGABRT diagnostics.
They are not rendering or input evidence. The current next experiment is one
source-level coordinate-contract fix, followed by the same setup hit grid and
the world selection/production fixture. Do not broaden into renderer changes
until the accepted logical rectangle is aligned with the visible control.

## Iteration378: default release timing reaches a live selected world

A clean run on the designated Simulator, using the rebuilt boundary libraries,
kept the original DE alive for the full 180-second observation and reached the
full-size main menu. With the default 100 ms mouse-up delay, a real Simulator
tap opened **Single Player**, a second tap entered **Skirmish**, and the game
loaded a live Death Match world. A further tap on the town center produced the
normal selection outline and unit information panel. The event log shows every
down/up pair being enqueued, dequeued, hit-tested and dispatched to the
original `CFeralNSWindow`; release events carry refreshed timestamps after the
100 ms delay. Evidence: `generated/mac-de-simulator-375/touch-default-2/`,
especially `game.stderr` and `result.json`.

This closes the immediate “clicks do nothing” failure for menu activation and
world selection on the current Simulator candidate. It does not yet close the
full touch gate: movement, production, drag/camera, cancel/menu return,
lifecycle return and a measured sustained gameplay cadence still need their own
fixtures. The post-cleanup game process is not stability evidence, and the
composition callback count is not an FPS measurement.

## Iterations376–377: original consumer sees a valid event; fresh timing runs did not reach interaction

The ABI-correct read-only consumer observer installed after `CFeralNSWindow`
class registration and preserved both original handlers and return values. A
real Simulator tap reached `mouseClickEvent:fromEvent:` and
`mouseEvent:fromEvent:` for both down and up. The consumer saw
`window=CFeralNSWindow`, `windowNumber=3`, event numbers1/2, types1/2,
flags/subtype/data1/data2 all0, click count1, button0 and the expected
bottom-left point `(232,536)`. The visible launcher did not transition. This
exonerates the missing-window-number hypothesis and proves delivery is not
the same as user-visible acceptance. Evidence:
`generated/mac-de-simulator-375/consumer-trace-run-5/game.stderr:7740-7769`.

The adapter then moved the 100 ms release timing into the clean default path;
the successful Iteration378 fixture above is the first evidence that this
timing change fixes visible acceptance. The earlier timing runs remain startup
or harness failures and are not used as touch evidence. Reliable full-slice
touch, sustained performance, physical-device execution and retail multiplayer
remain open.

## Iteration375: missed short click accepted by original dispatch; restored world ~14.8 completions/sec

Current PID85705/helper85695 restores the full-size saved world. A missed short Load click reaches the original mouse handlers, both dispatch calls return0, and both complete in under0.2ms. A held press succeeds with the same return statuses. This moves the investigation downstream to game input consumption; successful dispatch alone is not successful interaction.

The selector optimization is now loaded. A30second world observation measures443 displayed composition notifications (~14.8/s), below smooth-play target and not physical FPS or a controlled improvement claim. Preserve the live scenario. Evidence: generated/mac-de-simulator-375/checkpoint.md. Reliable touch, sustained performance, standalone Steam, device and online acceptance remain open.

## Iteration374: missed click delivered promptly; quieter build still ~12 callbacks/sec

Current PID58166/helper58154 restores the full-size world with reduced logging. A missed short Load click spent under0.4ms in the event queue and had matching press/release click counts. The remaining input fault lies after this queue; trace the original handler/consumer next.

A30second observation counted362 displayed completions (~12.1/s), so logging removal did not establish a speedup. Profiling identified repeated Foundation string searches in the encoder adapter. A direct selector-name classification change passes the actual Simulator57344pixel adapter test; it is not yet loaded into the game or performance-validated. Preserve the current restored scenario. Evidence: generated/mac-de-simulator-374/checkpoint.md. Goal remains active; touch reliability, good sustainedFPS and online/device acceptance remain open.

## Iteration373: autosave restored and villager trained

The corrected adapter is now loaded in PID38229/helper38217. The game restored its autosave, selected the town center, and trained a villager: population4/5→5/5, villager count3→4. Full-size world persisted through the latest31minute process observation. Preserve current live scenario. Evidence: generated/mac-de-simulator-373/checkpoint.md and villager-held.png.

Short clicks remain inconsistent: LoadGame and production needed longer presses. Click-count preservation is not a complete fix. Next reduce quantified diagnostic logging and measure input enqueue/dequeue latency. Gameplay interactions now have concrete evidence; usable touch, sustained goodFPS, physical device and online play remain incomplete.

## Iteration372: intact-code skirmish renders; click-pair correction built

Current PID19873/helper19859 renders a full-size skirmish and selects the town center. Preserve this unsaved scenario. Short clicks are inconsistent; the adapter forwarded clickCount1 on down and0 on up. A correction now preserves the press count through release and compiles, but has not been loaded or validated yet. Villager training remains unconfirmed.

A30second diagnostic sample measured399 real composition callbacks (~13.2/s), below target and not a sustained/device benchmark. The new semaphore observer also disproves treating repeated cd43bc samples as sufficient proof of a deadlock: waits return and stack depth changes. No forced completion. Evidence and next steps: generated/mac-de-simulator-372/checkpoint.md. Full goal remains active; online/device acceptance still absent.

## Iteration371: stalled queue callback identified

The queued callback copies graphics-state records and contains no Metal call or GPU wait. A fresh sample confirms the same unresolved completion semaphore. Next associate the queue with its worker and wake-up signal; the worker identity is not yet verified. Keep live PID4549/helper4536. No further coordinate clicks or gameplay acceptance. Evidence: generated/mac-de-simulator-371/checkpoint.md.

## Iteration370: full-size menu; input dispatch verified, game wait under investigation

Removed two diagnostic observers doing expensive symbol lookups on hot mutex/pool calls. The new intact-code run reaches the full-size menu by roughly3minutes; those symbol-resolution costs disappear from the new sample. This is a concrete startup improvement.

SinglePlayer still doesn't navigate. Logs show down/up events reaching the original window, while WinMain samples remain on a queued-work completion semaphore. Next trace that queue's consumer; stop repeated coordinate clicks. PID4549/helper4536 remain live, no match loaded or FPS/online pass. Evidence: generated/mac-de-simulator-370/checkpoint.md.

## Iteration369: real game passes the invalid-texture blocker

The experimental software BC profile is now exercised by the original game:55compressed uploads, zero invalid-format/unsupported events at the latest observation. Original67.5MB instruction section is byte-identical to supplied input. This replaces the former format instruction patch with implemented GPU decoding at the platform boundary.

Game PID98272 remains live at6:58elapsed, black startup with cursor; helper98262alive. Preserve and observe this same run. No menu/world, sustained sizing/FPS or online acceptance yet. The software profile is explicitly incomplete Metal conformance, with unsupported operations still rejected. Evidence: generated/mac-de-simulator-369/checkpoint.md.

## Iteration368: decoder integrated into 2D texture adapter

An opt-in all-format path now connects compressed allocation, typed storage, upload decoding, logical views and sampled shader bindings. Actual Simulator adapter test passes57344pixels across14formats. Hardware capability reports remain unchanged; no game launch this turn.

Next exercise the original game with a clearly bounded experimental software-device profile and resolve operations it actually reaches. Compressed readback, other texture types and some view/copy operations remain unsupported. This is integrated texture functionality, not complete graphics support or stable gameplay. Evidence: generated/mac-de-simulator-368/checkpoint.md.

## Iteration367: production texture formats and sRGB sampling pass

New logical-format mapping and actual Simulator test cover14BC formats with private RGBA8/R16/RG16/RGBA16 backings and real sRGB sampling views.57344pixels pass within the stated storage/transfer precision tolerance. This replaces reference-only output qualification with intended production formats; native BC1–BC5 interpolation differences remain a separate open issue.

Next connect these tested paths to game texture allocation/upload/views/binding. Current game remains stopped at the intact-code texture-support boundary; no fresh sizing, gameplay/FPS, device or online pass. Evidence: generated/mac-de-simulator-367/checkpoint.md.

## Iteration366: all-format checked GPU upload implemented

BC6 signed/unsigned compute decoding now passes29750pixels on actual Simulator. A unified checked BC1–BC7 upload API passes148750pixels across ten format variants, including invalid-range rejection, pre-enqueued command buffers and rejection after completion. No game instructions, candidate installation or hardware feature flags changed.

Next integrate typed backing textures, sampling views and compressed storage semantics. Current tests use RGBA32float reference output; intended production backing formats and sRGB views still need qualification. Native BC1–BC5 precision differences remain open. Game sizing, sustained gameplay/FPS, device and online gates remain open. Evidence: generated/mac-de-simulator-366/checkpoint.md.

## Iteration365: BC1–BC5 compute path passes actual Simulator tests

New GPU decoder passes104125pixels across BC1/2/3/4U/4S/5U/5S against the CPU reference, including private-buffer ordering, padded stride, cropped edges and preserved borders. Independent native compressed-texture comparison gives exact matches for BC6 and valid BC7, but exposes interpolation differences in BC1–BC5 (largest observed absolute error0.016416). That strict native comparison fails and remains unresolved; CPU-reference agreement is not a hardware-equivalence claim.

Next implement BC6 GPU decoding and checked texture storage/view integration, retaining explicit native-precision qualification. Current game candidate unchanged/stopped; no fresh match, sizing or multiplayer pass. Evidence: generated/mac-de-simulator-365/checkpoint.md.

## Iteration364: compressed-texture implementation groundwork

The intact-code game still stops at an invalid2048×2048 texture after its warning acknowledgment; observed resource reads do not identify a standalone BC4 DDS to convert. Added a bounded all-format CPU decoder/reference and corrected three sanitizer-detected upstream arithmetic/initialization issues. All10000 randomized format/bounds cases pass under host ASan/UBSan and on the actual Simulator. Regenerated BC7 GPU decoder passes33153pixels in Simulator and matches the native GPU for all valid-mode pixels; the previously documented reserved-prefix alpha discrepancy remains.

This is tested graphics groundwork, not an integrated game fix. Next qualify remaining formats and implement compressed upload/storage/view/sampling semantics before advertising a software BC capability. Original game instructions remain restored. Current Simulator game is stopped after natural failure. Stable sizing, FPS, device and online gates remain open. Evidence: generated/mac-de-simulator-364/checkpoint.md.

## Iteration363: actual warning acknowledgment advances intact-code startup

The original hardware-warning preference is now identified and verified: “Min Spec Message Skip” stores the actual failed-check mask. A read-only stack observation measured mask16. After backing up Preferences Data, changed only that existing value0→16, matching the original persistent-continue action. Hardware reports and executable instructions remain unchanged.

The next launch accepts the acknowledgment, advances beyond the missing dialog, and reaches an invalid Metal texture-format request for a2048×2048 texture. It ends naturally at38.24seconds with the genuine Steam helper still alive. This is startup progress, not a sizing or stable-gameplay fix. Trace the actual texture source and implement a qualified graphics conversion without instruction patches. Earlier349 demonstrated world rendering and villager training, but no stable sizing, sustained FPS, physical-device or online-match gate has passed.

## Iteration362: native comparison redirects the warning investigation

The empty resource registry is now directly associated with the Simulator's missing minimum-spec dialog. But the unchanged Mac control has the same empty registry at the same startup lookups and proceeds beyond minimum-spec initialization. This rejects the assumption that the empty registry alone is a Simulator packaging regression. The reader expects Windows PE resources; rebuilding missing resources is not yet justified.

Next investigate the game's actual hardware-warning preference/continuation path and capability differences, preserving original instructions. The existing code stores the actual warning mask when its persistent-continue action is chosen; an external settings route is not verified and no preference was changed. Native PID91879 remains live under read-only observation; Simulator run ended naturally. Stable gameplay, sizing, FPS and online gates remain open. See362/checkpoint.md.

## Iteration361: resource registry observed empty

A read-only observer at the original module-handle lookup reports an empty resource linked list and a null resource vector in eight observations. This narrows the missing warning to resource registration/lookup; associating the exact observation with the minimum-spec call still needs a caller stack. Real Simulator mutex forwarding passes2,000 synchronized increments. The game naturally exits again; no live Simulator game remains. Debugger attachment failed, and a debug-signing experiment was restored to the exact verified prior executable/signature. Next trace the original CHModule/CDozeResourceFile initialization. No dialog, sizing, sustained gameplay or online fix claimed. See361/checkpoint.md.

## Iteration360 result: cube-array startup stall removed; original warning dialog is next

The intact-code game now creates/uploads its two-cube placeholder successfully through the qualified storage adapter. It advances beyond359's renderer semaphore stall to the original minimum-spec check. MainLog records `Min spec not passed` and `Exiting with code 0`; the expected warning/continue dialog does not appear. Subsequent cleanup terminates at61.10seconds with helper alive. No Simulator game remains. Next fix the original dialog/resource boundary, preserving original instructions. This is verified startup progress, not yet a sizing or stable-gameplay result. See360/checkpoint.md.

## Iterations359–360: intact code launches; cube-array storage qualified

The intact-code candidate is installed. Installation replaced its bundle container, exposing adjacent inputs that the old setup had staged manually. Added `scripts/stage-de-simulator-adjacent.py`: copies the owner's genuine Steam module and game data, verifies Steam hashes and verifies unchanged content while normalizing resource paths (13,917 resource files and 6,803 widget files). References remain untouched. This is engineering staging, not a self-contained device installer.

359 now verifies/loads the genuine Steam module and renders the original launcher. After Play, the original cube-array request (1×1, two cubes, RGBA8) is rejected, followed by the same renderer cleanup semaphore wait diagnosed in294. Agent stopped this splash-only run at410seconds to replace the adapter; no natural crash or unsaved match loss.

360 implements cube-array storage as six 2D-array slices per cube, preserving logical metadata and rejecting unimplemented shader sampling. Actual Simulator test verifies12 faces,2 mip levels,240 components and an aliased view; sampling rejection returns78. New original-code game run starts with this adapter. No sizing/gameplay/FPS/online acceptance yet. The native357 comparison reaches the full-size menu after its long startup; no sustained gameplay qualification from that run.

## Iteration358: original code-section hash identified; intact-code candidate staged

A predicate writer hashes a range that static descriptor/linkage analysis resolves exactly to the entire67,501,856-byte original instruction section. The Simulator’s three remaining instruction patches lie in that range. This is a concrete compatibility difference to remove, though sole causality for shrinking/ICX remains unverified.

A separate signed candidate now restores all three instructions and verifies byte-for-byte equality with the original section. It is staged only; installed candidate unchanged. Next replace the removed texture/dialog patch behavior at framework boundaries and qualify the intact-code launch. Native control81577 remains live with black startup at14:26; no native gameplay acceptance. See358/checkpoint.md.

## Iteration357: native and Simulator predicate differ

A native control with the original signature and read-only trace now runs. Its first compositor snapshots have the same scale candidates0/1 and threshold666, but the decoded predicate is false; it is true in both356 Simulator snapshots. An isolated extraction of the original seven decoding instructions confirms these values and the decoder. This is initial runtime evidence, not yet a complete native gameplay comparison or a platform-cause diagnosis. Native startup is still black at the inspected screenshots. No game flags, signatures or viewport values changed.

Three functions using aliases of the predicate state are identified for the next data-flow investigation. Native PID81577 remains under observation;356 Simulator run is stopped. All gameplay/FPS/device/online acceptance gates remain open. See357/checkpoint.md.

## Iteration356 result: comparison input changes at shrinking

Actual scale0→1 coincides with reference0→2939 and changed predicate bits; candidates0/1 and comparison-current666 remain unchanged. Static analysis follows reference writers to CLOCK_UPTIME_RAW; both platform SDKs use the same clock ID. A clock mismatch is not established. The scale callback dispatches a worker thread.356 naturally exits at1071.95seconds with helper alive; no successful match start despite delivered button events. Runtime is now stopped. No sizing, FPS or online acceptance. See356/checkpoint.md and scale-transition-evidence.json for the next causal boundary.

## Iteration356: exact scale-state writer located; next trace qualified

355 reproduced shrinking with scale changing0→1 at the same address while the motion callback output remained0. It then naturally exited with internal ICX failure at1147.91seconds; helper still alive. Load Game did not navigate successfully; no save/load or stable gameplay acceptance.

Static original-code analysis identifies function0xd8a75c, store0xd8abd8, resolving the exact scale pointer through globals0x5995540/0x5995548/0x5995518. It selects candidate values read through two other pointer chains and a predicate involving additional global inputs. This is a statically identified writer, not yet a runtime writer-event capture or a proven underlying platform cause.

Extended bounded read-only tracing observes both scale candidates, comparison current/reference and predicate bits. Ten synthetic pointer chains with signed displacements pass on the actual Simulator, including an inaccessible-pointer result; imported comparison control passes. Original executable instructions, viewport and flags are unchanged.356 starts a new isolated run after355's natural exit; the same designated Simulator is reused. Physical-device, self-contained Steam, sustained FPS and online-match gates remain open.

## Iteration355 finding: suspected callback writes motion, not scale

Actual Simulator snapshots resolve the callback output to the same address as the motion input, while the scaling input has a different address. This rejects that callback as the direct scaling-flag writer and redirects investigation to the scaling writer. All three initially read0; candidate values read0/1. This is real runtime alias evidence, not a sizing fix. The same live Simulator run continues.

## Iteration355: audio stall limits Mac comparison; callback trace returns to Simulator

The locally signed Mac menu subsequently stalls: WinMain waits on the game audio mutex while an audio worker is blocked configuring CoreAudio output; the render worker waits for work. Additional clicks do not diagnose touch coordinates. Agent stopped that control; no natural ICX exit or gameplay qualification.

Extended read-only callback pointer tracing now passes actual Simulator pointer/error and interposition controls. A new isolated Simulator run starts to establish whether the suspected callback output aliases the observed scaling input. No game flags, original instructions, or viewport values are changed. Actual alias result and sizing fix remain pending.

## Iteration352 updated result: locally signed Mac reaches full-size menu

The same clean Mac process reaches the full-size main menu at20:49 elapsed after a long black startup. No ICX termination is logged at that observation. The black screen was transient; signing changes alone have not reproduced the Simulator failure in this control. Match loading and menu input remain unverified for this run, so elapsed process survival is not gameplay stability. Further read-only trace controls now validate all five pointer chains and inaccessible-address handling; actual callback aliasing remains unproved.

## Iteration352: unchanged Mac world/save control passes; packaging comparison starts

Payload comparison now verifies24,921 files: only the executable differs, with identical instructions and four changed bytes outside the signature (signature/link-edit size metadata). Missing or changed assets are excluded for this comparison. A further control preserves the original entitlements while changing the signing identity; prepared and verified, not yet launched. Clean current control remains live under observation.

Clean follow-up: the first locally signed Mac run stays black, with native event/render loops alive. Agent stops it and verifies no other game process before a standalone launch, excluding the earlier overlap. OS dynamic and static signature checks both return success. Native Steam library loads and a service request returns HTTP200, but neither proves gameplay or multiplayer. The second launch is still under observation; no signing-cause or sizing-fix claim.

Unchanged native Mac shows full-size terrain, visible villagers/scout and continuing AI activity beyond22minutes process elapsed. Saved a unique match and verified its private copy/hash. Menus/save paused part of the observation, so this is not uninterrupted gameplay or FPS qualification. Agent then stopped this control; no natural exit.

A separate native Mac clone now has a local ad-hoc signature and local-compatible entitlements, with its entire original instruction section verified unchanged. It uses ordinary Mac Steam and no iPad compatibility libraries. This tests whether packaging changes reproduce the delayed display/exit failure; result pending. Actual iPad sizing, stable gameplay, independent Steam authentication and online match remain unresolved. See352/checkpoint.md.

## Iteration351: unchanged Mac control running; activation callback followed

350 naturally exits with ICX1196.26seconds, helper alive.351 follows constructor callback through stdfunction invocation0xd8d54c to predicate/store function0xd8b3e4; actual target identity still requires proof. Signature verification of source and private APFS clone passes. Launched untouched native clone without compatibility libraries for source-vs-adapter control. Native menu and skirmish setup respond to first clicks; Start Game initiated. This is Mac diagnostic evidence only, no iPad stability or FPS acceptance.351/checkpoint.md records live native PID56434 and window5382.

## Iteration350 observation: scale activation changes from zero to one

Same runtime scale address reads0 during normal compositor output and1 at first small rectangle; motion input remains0 at those captures. Actual skirmish world loads again, miniature by05:32. This verifies an activation-value transition upstream of the resizing calculation; writer/trigger and ICX relationship remain unresolved. Constructor callback0xd8b8a8 identified for next data-flow inspection. Game/helper confirmed live18:37, preserve/re-poll same run. No sizing fix, stable FPS, physical-device or multiplayer acceptance.

## Iteration350: runtime scale/motion input observation prepared

Original constructor builds animation tables; transform reads two runtime-initialized inputs from zero-fill globals. Added bounded, read-only snapshots at349’s verified compositor boundary. Actual Simulator control verifies valid memory read and invalid-address failure; imported comparison/pool control still passes. New private run starting; actual activation values pending. No sizing or stability fix claimed.350/checkpoint.md records source, controls and next discriminator. Full goal active.

## Iteration349 result: first world rendering and completed touch command; shrinking source captured

Actual Simulator skirmish renders terrain, town center, fog, minimap and HUD at full size (349/loading-later.png). Touch selects Town Center (town-center.png); train command produces Villager Created and population4/5→5/5 (train-second.png). Visible unit movement is not verified. Shrinking subsequently reproduces in the skirmish; game later terminates, no save completed. No stable gameplay/FPS/device/multiplayer claim.

Read-only compositor trace now catches supplied small rectangles and upstream parent0xd86720 -> transform0xd8c53c. Static transform cycles a152-entry table and explicitly scales/moves/bounces the output rectangle. The activation inputs use obfuscated global indirections and are unresolved; connection to ICX remains unproven. This identifies the calculated source beyond the Metal consumer, rather than an outer UIKit sizing error. Full goal active.

## Iteration349: alternate compositor trace qualified; live run starting

348 naturally exits after1068.66seconds with ICX and Steam helper alive. Shrinking reproduces but setter memcmp trace misses active path.349 adds read-only imported pool-push trace of original alternate compositor optional rectangle, with caller validation before reading. Actual Simulator control proves both pool and memcmp interception and preserves comparison/input/errno behavior. Per-resource-binding draw log is now explicitly opt-in to remove millions of unconditional diagnostic lines. No viewport override, executable patch, sizing fix or gameplay claim. See349/checkpoint.md for live run state.

## Iteration348: shrinking persists after diagnostic restoration; upstream capture running

347 reproduces miniature viewport with three diagnostic calls restored; agent deliberately stops it after reproduction, so no natural-exit claim.348 enables a read-only imported-library trace at the viewport setter. Real Simulator control verifies interception and unchanged comparison semantics; actual game library mapping verified. Await upstream caller evidence, not another output-scaling workaround. Full gameplay/device/multiplayer goal remains active.

## Iteration347: unnecessary executable diagnostics removed; full-size menu preserved

Audited all six original __text instruction changes; restored three diagnostic-only calls with byte verification, backup and valid signature. Actual original menu still renders (347/engine.png). Delayed failure outcome is pending in live restored-run; no sizing or gameplay fix claimed. Prepared a read-only imported-memcmp trace at the actual viewport setter to capture the upstream caller without further executable edits; Simulator comparison control passes, actual game trace still pending. Full goal active.

## Iteration346: shrinking and ICX exit reproduce with Steam helper alive

The longer controlled run exits after1033.30seconds with its helper still alive and no early helper death. This excludes the old ten-minute cleanup as the cause. Real mission briefing renders, then Skip leads to black/loading decoration; no terrain/units. The original queued viewport copies are faithful; upstream altered rectangle and ICX predicate remain unresolved. No sizing/playability fix claimed. See346/checkpoint.md. Next trace the failure condition and audit existing executable modifications; full goal remains active.

## Iterations343–345: miniature viewport traced to original commands; delayed exit identified

The UIKit/CALayer ancestry stays full size with identity transforms.344 captures actual original Metal viewport requests such as x439/y697/w198/h132 on a1920×1280 drawable;345 captures first offset call stacks through original0xa55954, the threaded command consumer. This is an original submitted viewport, not an outer UIKit resize. No viewport override or sizing fix is claimed.

344 reaches real A8 adapter texture/pipeline creation (including1920×1280 and3840×2560 targets), advancing beyond340's immediate unsupported A8 failure. No terrain/units screenshot or playable scenario is verified. Its eventual exit prints `localhost kernel: internal ICX failure`. Static code schedules exit(1) through original0xf75360 after a randomized780–959 delay;0xf6d650 arms it after predicate0x387668. The predicate is obfuscated and its underlying failed condition remains unknown. A connection to viewport oscillation is a hypothesis, not established.

The600-second test runner removes the temporary Steam helper while leaving the game alive. Late failures therefore have a dependency-lifetime confound.346 extends the supported observation to3600 seconds and records early helper failure explicitly; it does not change game checks. Post-cleanup process survival is explicitly not supported stability evidence.345/checkpoint.md records screenshots, source snapshot and limits. `DE-INSTALL-AND-ONLINE-PLAN.md` distinguishes proposed ownership/import/authentication flow from implemented host-assisted tests. Full gameplay, FPS, device and genuine multiplayer gates remain open.

## Iterations341–342: alpha GPU control passes; live game has unresolved display regression

Native A8 vs real Simulator RGBA8 alpha-only sampling matches512/512 components for4 modes. Actual adapter allocation/render-pass/pipeline/binding path also matches. Live341 reaches Campaigns but later shows a small moving mission-screen image before any A8 adapter call; cause unproven. Escape stops at missing syslog Darwin spelling.342 real logging bridge passes variadic/errno control; next expose original diagnostic and restore full-size display. No scenario render/FPS acceptance.341/checkpoint.md records failed live test separately from successful GPU controls.

## Iteration340: Campaign black screen fixed; original campaign-selection map renders

After staged widgetui case normalization, actual Single Player→Campaigns renders the original African Campaigns map (340/campaign.png inspected). Trace confirms campaignicons.dds and campaignselectatlas.dds now open successfully, where339 failed. This is a verified visible transition fix. Saladin mission selection and An Arabian Knight briefing render; selecting Skip reaches terminal Metal validation: A8Unorm target is neither blendable nor color renderable in Simulator. No terrain/units yet.340/checkpoint.md records exact error and next alpha-rendering qualification. No gameplay/FPS/device/multiplayer acceptance.

## Iterations339–340: Campaign atlas path casing fails; staged correction verified

Armed339 trace captures Campaigns attempting lowercase UHD atlas paths, returning ENOENT. A real Simulator control confirms lowercase uhd fails while existing uppercase UHD succeeds; host filesystem lookup accepts both.340 normalizes1246 staged widgetui name components after collision preflight and verifies all6803 file SHA256/inode/size/mtime unchanged. Four previously failing Simulator paths now stat successfully. Actual engine rerun pending; this proves a resource defect and repair, not yet a black-screen fix. Reference inputs untouched. Full gameplay/device/multiplayer goal active.

## Iteration338: startup exhausts file trace; corrected diagnostic prepared

Campaigns still becomes black/cursor. The100000-record cap was exhausted before the click, invalidating any inference from absent transition records.339 marker-armed tracing and explicit overflow reporting pass a real Simulator file-semantics control. Next arm at menu and repeat.338/checkpoint.md preserves the failed diagnostic and current evidence. No gameplay/device/multiplayer acceptance.

## Iterations335–337: Escape delivered; both Campaigns and Skirmish reach black screen

Real hardware Escape now reaches original key handlers and text-command interpretation without unsupported calls. Single Player remains touch-navigable; after Escape the main menu is visible and reopening the dialog is verified. Campaigns selection reproduces Skirmish's black screen, and Escape does not visibly leave that state.334 black-state logs show continued successful GPU/composition with no texture bindings in latest frames. The shared transition failure remains undiagnosed; no map/gameplay/FPS acceptance.337/checkpoint.md records live75295, input limits and source snapshot.

## Iterations333–334: original Single Player dialog opens by touch

333 proves the original visible window cached active/main flags were false.334 implements actual key/main transitions and notifications; original flags become true and a real Simulator tap opens Single Player (334/single.png inspected). This is first verified menu navigation. Skirmish selection then reaches a black screen with cursor; game remains live with no unsupported boundary, but no setup screen or match yet. Live thread sample shows a timed wait in the ongoing game loop, not the old startup destruction hang; cause is unproven.334/checkpoint.md records live70494, source snapshot, coordinates and next diagnosis. Gameplay/FPS/device/authentication/multiplayer gates remain open.

## Iterations328–332: full touch event dispatch reached; menu activation still unproven

Actual UIKit press/release pairs now pass the original event queue, application/window dispatch, hit testing and responder chain into CFeralNSWindow.mouseDown/mouseUp without stopping. Added real screen/window coordinate conversion and window update notifications.8 Simulator hit-test controls and24 coordinate controls pass.332/single-player.png still shows the main menu with hover tooltip after a tap; Single Player has NOT opened. Next inspect original focus/internal-event state. The current adapter never sends key/main-window transition notifications, and its isKeyWindow reports all visible hosted windows as key—a concrete incomplete lifecycle model, not yet proven as the cause of ignored clicks.332/checkpoint.md records live process66350 and evidence. Full gameplay, FPS, device and multiplayer goal remains open.

## Iteration323: BC7 mip-chain failure cleared; menu alive, touch presses still missing

Actual2048×2048 BC7 textures with12 mip levels now allocate/upload. Native and Simulator GPU-blit controls verify mip contents; directSimulator CPU readback has a separate discrepancy. Menu stays rendered (323/single.png). Pointer hover highlights Single Player and shows tooltip, but clicking does not activate it: our UIKit pointer adapter tracks coordinates only; original-game touch-to-mouse-button events are still absent. Legacy launcher has a separate WebEvent bridge. Next implement real pressed/released/dragged event delivery, then load a match. Do not describe attempted clicks as successful navigation.323/checkpoint.md records live process/runner. Gameplay, FPS, device and multiplayer remain open.

## Iterations321–323: BC7 decoder verified; original main menu reached

Original internal102 is BC7_RGBAUnorm(Metal152). The new GPU decoder passes33153 CPU-reference pixels across8 valid modes and reserved cases; all29465 valid-mode pixels match independent native BC7 hardware. Reserved cases differ in native hardware alpha, documented in321/checkpoint.md. Actual game322 allocates and GPU-decodes a1024×1024 BC7 texture and visibly renders the original main menu (322/current.png inspected). A later background texture allocation reaches another guarded compressed descriptor; the attempted Single Player tap did not prove navigation. No scenario yet.

323 enables mip-level uploads using actual backing views, with341pixels/all5levels verified through GPU-blit readback. Simulator directCPU getBytes disagrees for32 mip pixels, while native directread and Simulator GPUreadback match expected values. Keep that distinction.323 adds exact descriptor logs for the next engine allocation. No gameplay FPS, device, touch match or multiplayer proof; full goal active.

## Iteration320: original intro visibly rendered; next 1024×1024 format failure

The original intro is visible in generated/mac-de-simulator-320/arrays-scene.png (inspected). Startup teardown, Caps Lock and resource-array boundaries have been passed. Real Simulator mixed-resource GPU control verifies38181 pixels plus33153 existing BC4 decode pixels. The process later exits on Metal validation: original internal format102 maps to0 under actual Simulator capability0; requested texture is1024×1024/private/2D/single-mip. Next classify and faithfully implement that format. No game menu/match/FPS/device/multiplayer acceptance. PID54425 is dead and owned runner cleanup complete; Simulator home screen is the current UI. Full details320/checkpoint.md.

## Iteration318: first presentation deadlock cleared; Caps Lock query reached

Actual original engine passes the startup graphics-destructor wait with the gated dropped-frame handling. It then stops at explicit CGEventSourceKeyState mac_key57. SDK headers identify Carbon kVK_CapsLock=0x39 and GameController GCKeyCodeCapsLock.319 maps the query to the actual coalesced keyboard button, without fabricating pressed state. This advances startup beyond the previous hang. Still no menu/gameplay frame, FPS, physical device or multiplayer proof. See318/checkpoint.md for exact evidence and remaining drop-route limits.

## Iterations314–318: native dropped-frame contract established; first callback retired as dropped

314 proves the first Simulator drawable wrapper and its pending handler storage were being released before GPU completion. NativePresentationControl.m separately submits60 real Metal frames on macOS and receives60 callbacks,11 with zero presentedTime (dropped frames).315 retains pending drawable wrappers; actual first didComposite/didFinish remain false.316 rules out size/future-clock mismatch.317 flushes initial attachment/show transactions, still insufficient.

318 adds opt-in superseded-immediate-FIFO retirement: an older submitted drawable on the same layer, with positive no-later presentation-call time and no actual composition, is reported dropped only once a later immediate/FIFO drawable actually composes. Time stays zero. First original callback now fires as dropped and the next as actual composition. This is an inferred drop from ordered actual presentation, not a direct Simulator dropped notification. No GPU completion or timeout is counted as display. Observe original-engine continuation before claiming startup solved; renderer/gameplay/FPS/device/multiplayer acceptance remains open.

## Iteration313: serial presentation also fails at first drawable

The first actual drawable submission never yields an observed composition even when all later presentations are queued. GPU work completes and window ancestry is intact. Serialization therefore does not solve the stall; keep the FIFO opt-in and disable it for ordinary next experiments. Registration is now located statically at original0xa6c024, with counter increment0xa6c030 and original scheduling0xa7e550. Next qualify the first drawable's actual state and presentation lifecycle independently of our interception. Run313/checkpoint.md records live process and reproduction. The window-lifetime fix311 remains useful, but the game still has no menu/gameplay/FPS acceptance. Goal remains active.

## Iterations311–312: transition presentations restored; early frame still unacknowledged

Run311 preserves existing windows when another is made key/front. Three transition submissions now retain their complete UIWindowLayer ancestry and compose successfully. The renderer destructor still waits: 11 registered presentation handlers versus10 delivered callbacks, with an early frame outstanding. Thus the detached-window bug was real but did not explain the entire wait. Run312 observes setDidFinish:YES before actual composition of other frames; using it as a dropped/displayed callback would be incorrect. Run313 tests actual presentation serialization per layer, releasing the next submission only on actual composition. This is a throughput-limiting diagnostic, not FPS or scene acceptance. No game frames or multiplayer proven.

## Iterations308–310: startup drawable submitted after adapter detaches its window

The main-thread graphics destructor wait is at original offset0xa6689c, waiting for device+0x5eb8. Original presentation callback0xa6c694 decrements and notifies. A scoped wait interposer keeps the actual predicate/mutex semantics while servicing the real UI run loop. Its Simulator control passes; game run308 still stalls. Adding real CATransaction.flush in309 also does not resolve it. These are failed unblocking experiments, not gameplay progress.

Run310 traces actual drawable submission and full layer ancestry. Opening the game window calls our makeKeyAndOrderFront, which removes the old startup host immediately. The engine continues submitting to that old CAMetalLayer; those submissions have only three detached ancestors instead of the earlier UIWindowLayer chain. Only later does the engine orderOut the startup window and wait on its pending presentation. Run311 tests preserving other windows when ordering a new one front. See generated/mac-de-simulator-308,309,310/checkpoint.md. No rendered game scene or FPS yet. The active goal remains unchanged.

## Iterations306–307: first fault identified; staged resource case fixes font and campaign startup

Previous turn was progress.306 introduces an isolated signal recorder (SignalTrace.c/dylib), logging original signal ucontext before chaining the original handler. It catches SIGSEGV at address0x68, original instruction0x102eb5e08 with x19=0. Caller0x10372b38c requests basic_bold_16 after creating/loading combined and retrieving a font object. Static disassembly confirms the earlier font-load failure produces index-1 and then a null object. This is the actual fault, not the secondary crash reporter strlen. Recorder constructor's image-header0 base is NOT a reliable game base under Simulator injection; use sample/dladdr for game slide. The recorder logs bounded async-signal-safe buffers, remains diagnostic, and chains existing dispositions. No exception recovery or fake completion.

307 adds a recorded diagnostic BL at0x102eb12dc to the reserved bridge, which invokes original font file reader0x102cb562c unchanged and records requested path/result. It proves combined.box loads successfully through the virtual Q:\Feral\Program Files\WinDeveloper\resources\_common\fonts path with338684 bytes. The font loader then formats atlas paths with lowercase .dds, whereas the supplied files have uppercase .DDS. The actual physical macOS filesystem can open either spelling; the game's virtual resource lookup still depends on its imported names.

Renamed12 combined/combined_sansserif atlas files to lowercase suffix in the private staged copy only, with SHA256 before/after equality. Original retry passed the combined font, loaded combined_sansserif.box too, and advanced to an actual fatal dialog for CampaignData.pbin. That file also existed with mixed case. Then preflighted all remaining mixed-case staged resource components for collisions and normalized4000 names bottom-up, using temporary rename and verifying identical inode,size,mtime per entry. Manifests font-atlas-case-normalization.json/resources-case-normalization.json contain every change. Reference installation was never renamed/rewritten. Staged resource names are now lowercase; this must be part of reproducible staging or a future correct case-insensitive importer. Avoid introducing fake files or modifying content.

The normalized-resources-run passes both font reads and the campaign-file error. It also restores the original minimum-spec warning text (1GB dedicated VRAM); actual failedmask16 is unchanged and actual Continue was tapped. No first signal or unsupported boundary observed as of checkpoint. The screen is still black with the original cursor, not a menu/gameplay success. Current sample: WinMain at0x38ac1b4→0xbfe720→event/poll path0x22f740..794 (different from the previous font crash); current staging counters have advanced beyond1.3GB cumulative offsets. Do not interpret cumulative staging offsets as RSS. Live PID41579; helper41568,relay41562; runner session55046 observes600s and cleans owned services but leaves live game at deadline. Preserve live process until checked; timeout alone is not terminal. Next inspect next-wait.txt (original0x1038ac130 and0x100bfe6b0) and main-thread path/required event; do not assume CPU activity is loading. Existing normalized-sample.txt and normalized-scene.png preserve evidence.

Installed executable has six recorded instruction patches295–307. Current signed SHA5da36099440aced5bbd5d8164009e3b520edf5b1f6e86a6c91b624ef0c782b1b; font-call-patch.json and backup preserve307 change. Sole Simulator574671AD-6F61-4558-9528-BF946DDB760A; visible window5339, PID58388, bounds175,30,703,1018. Warning has longer actual message after normalization: Continue global526,591. Play global704,715. No scenario opened/lost. Full gameplay/FPS/touch/device/multiplayer goal remains active.

## Iterations 301–305: original BC4 uploads drain; original cursor visible; next fault in game startup

Previous goal turn was progress. This turn fixes the actual upload path, not the staging wait itself. Run301 command-buffer instrumentation records real commits and real completion handlers: a buffer after BC4 allocations failed with Metal status5/error code1, and the next committed buffer never completed. This accounts for the downstream ring wait. It also left the Simulator Metal service unusable: first302 launch crashed in newCommandQueueWithDescriptor via MTLSimulator_encountered_XPC_error, with the original crash reporter then failing in strlen. Rebooted only the designated Simulator; no other device booted.

Added descriptor-based blit encoder wrapping. Retry302 then explicitly identified the original call copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:options:. Added actual handling for options0; unsupported option flags still fail. Original303/304/305 now encode real2048×2048 BC4 uploads with4096-byte compressed row stride. Separate303 real Simulator test exercises descriptor factory, options0, private source buffer, compute decode, and continued blit readback in one command buffer;33153 pixels pass, including bounds/edge/border checks and untracked rejection. Original305 reports successful GPU completion after BC4 encoding. Hardware BC capability remains false; no dummy textures or synthetic completion used. Remaining compressed paths, array bindings, nonzero mip/slices/options remain incomplete.

Original303 advanced to custom NSCursor.set. DefaultCursorCompat.m now presents the original NSImage CGImage bitmap in a noninteractive UIKit UIImageView following the app-owned logical pointer, retaining original dimensions/hotspot. Original304/305 logs32×32 and hotspot0,0. Actual305 screenshot after-timing.png shows that original cursor on a black scene. Mouse movement/hide/stacks/full gameplay touch still unqualified. The implementation currently leaves UIKit's platform pointer available as well; physical mouse presentation needs later qualification. Original304 next requested NSEvent.doubleClickInterval. Added explicit app gesture timing0.3s (configurable0.1–1.0); it is not represented as a UIKit/macOS preference. Original305 consumed it and advanced further.

No gameplay/menu/FPS/device/multiplayer success. Run305 remains black beyond the original cursor. Live sample shows WinMain in a signal/crash handler chain0x774124→0x777dbc→0x7789a8→0x775588→0x77720c→_platform_strlen, above original0x2eb5e08 (caller0x372b390). High CPU was crash handling, not loading. Static current-fault-site.txt shows0x2eb5e08 loads state after a call to0x2e712ec; the sample alone does not give original fault registers/address. Next disable only the original diagnostic crash-handler installation in an isolated diagnostic build so the OS captures the first fault, or install an async-signal-safe recorder of original ucontext. Do not fix secondary strlen blindly or fake success past the original failure.

No new executable instruction patches301–305; the five recorded295–300 changes remain, current executable SHAfd08de44f907eaf49fa7eb656ab912c5d2ff9e40f2533236d795e99afe97ebc0. Refs unchanged. Reproduction305/rebuild-and-run.py uses private overrides; current source snapshot saved305. Only Simulator574671AD-6F61-4558-9528-BF946DDB760A; after reboot visible window ID5339, Simulator PID58388, same bounds175,30,703,1018. No scenario was opened or lost. Faulting305 game deliberately stopped after capture; inspect runner cleanup before restart. Full goal active.

## Iterations 299–300: BC4 backing allocations pass; next wait isolated to upload staging

The original engine now allocates eight real 2048×2048 R8 backing textures for its logical BC4 UNORM resources. BC4TextureCompat.m wraps supported shader bindings and buffer-to-texture uploads, using the GPU decoder inside the same command buffer. The original hardware capability stays false. No original BC4 upload has reached the wrapper yet; no menu/gameplay pixels, FPS, touch gameplay, device or multiplayer acceptance is claimed. Actual screenshots remain black after startup. Ordinary non-BC4 operations forward to Metal; unsupported compressed views/CPU writes/readbacks and resource arrays explicitly fail. This is an experimental partial adapter, not complete BC support.

A separate real Simulator control now exercises the wrapped blit encoder itself: private-buffer upload, BC4 decode, and continued GPU readback through the same proxy/command buffer. 33153 pixels match the independent formula within one R8 unit; borders are preserved. Short source buffers and hazard-untracked resources are rejected. The hazard guard is in source and the passing test, but was added after the live game build; rebuild required for that guard in the game candidate. See generated/mac-de-simulator-300/test-proxy.py and proxy-test.log.

Run299 was sampled alive at a stable staging semaphore wait, then deliberately terminated for tracing (no scenario open). Its helper/relay cleanup completed. Debugger attachment failed with lost connection. Run300 adds one recorded BL diagnostic patch at0x100aa2860; it logs staging arguments/counters then calls original0x100a7f920 unchanged. Only that instruction differs in __text from299; backup/hash/signature and verification saved in300. Installed executable now contains five recorded instruction patches across295–300; reference files are unchanged.

Trace300 proves capacity33554432 bytes. Eight BC4 allocations request2097152-byte staging regions, followed by16777216-byte ordinary uploads. Final pending request: bytes16777216, alignment4, cursor285212672, available251658240, requested251658240, pending33554432. Prior requests returned actual nonnull allocations; this one does not return. A second live sample confirms WinMain at original0xa7fba8 -> semaphore wait through the trace. Metal workers are idle; original BC4 upload log count remains zero. This narrows the next issue to submission/reclamation of pending uploads; it does not prove which callback or scheduler dependency is missing.

Next inspect original flush0xa7dbe0, submission0xa7de88, callbacks0xa7e580/0xa7eac4 and their queue owner. Static disassembly saved in299/staging-path.txt and300/flush-callback-path.txt. Trace real command-buffer submission/completion and the original callback producer before changing ring capacity or wake behavior. Never synthesize completion or bypass the wait over live storage. The complete original-game goal remains active.

Current live game PID32238; runner session6623 observes600 seconds and cleans its owned helper32228 and relay32222 afterwards, leaving a live game at deadline. Check process and cleanup files before any restart. Only designated Simulator574671AD-6F61-4558-9528-BF946DDB760A is booted. Reproduction uses300/rebuild-and-run.py and requires its private overrides/environment, not icon launch alone.

## Iteration 298: real Metal BC4 upload/decode operation passes Simulator pixels

Previous turn classified as progress. This turn implements a GPU-side BC4 UNORM decoder in port/de/BC4MetalDecode.m/h. It accepts a real Metal source buffer and writable R8 2D texture, validates source/destination bounds and device ownership, and encodes a compute pass without committing or waiting. The caller must finish the current encoder first. This is important for original uploads from GPU/private buffers: CPU .contents decoding cannot safely read those or preserve ordering. The decoder processes one compressed block per compute thread, crops edge blocks, respects byte pitch and source offset, and writes only the specified destination region. Source offsets currently require four-byte alignment. It supports level0 2D R8 targets only; no BC1/2/3/5/6/7, signed, sRGB, array, or mip-view integration is claimed. R8 output has up to one integer unit of quantization tolerance against the independent interpolation formula; this is not bit-exact float sampling equivalence.

Actual designated iPad Simulator test compiles the kernel using the real Metal compiler and executes a single command buffer containing: CPU/shared buffer to private-buffer GPU blit; BC4 compute decode; texture-to-buffer GPU readback. After actual completion,33153 decoded pixels match an independently calculated BC4 interpolation formula within one R8 unit, all surrounding pixels remain unchanged, and direct texture readback matches the subsequent GPU buffer readback. This covers257×129 partial edge blocks, padded528-byte block-row stride,256-byte source offset, destination origin5,7, both endpoint interpolation modes, and short-buffer rejection. Native CPU decoder tests from297 are separate evidence. The latest source uses64-bit shader byte-offset arithmetic and safe Metal math mode. Reproducible build/run and log: generated/mac-de-simulator-298/test-metal.py and metal-test.log. No fake GPU capability or allocation is involved. [Apple compute encoder API](https://developer.apple.com/documentation/metal/mtlcomputecommandencoder) documents the encoding mechanism.

**Still not integrated into the original engine.** No original game launch was performed this turn; the installed candidate is unchanged from297. The game still fails its BC4 format mapping. No gameplay/FPS/touch/multiplayer/device acceptance claim. This operation is necessary groundwork for handling the observed compressed upload, not a replacement success criterion. Only the existing designated Simulator was booted and used; no scenario was running or lost.

Saved original disassembly of0x100aa611c in texture-upload-path.txt. It constructs per-mip copy descriptors and calls0x100aa23a8/0x100aa4304 to obtain source objects, then0x100a6c2ac or0x100aa50dc depending on path. These are static leads, not a proven dynamic BC4 upload route. Next locate the observed engine's buffer-to-texture copy and encoder lifetime, then wire the decoder with real backing textures and exact source metadata. A blit encoder must end before opening the compute encoder; preserve command-buffer ordering and recreate/rebind a subsequent blit encoder instead of launching an unordered second command buffer. Preserve logical compressed format/row pitches upstream while shader bindings receive actual uncompressed backing. Block any unimplemented compressed operation explicitly. Extend other BC formats only with actual decoding and format semantics. Then rerun original startup and require real menu/gameplay pixels. The full goal remains active.

## Iteration 297: invalid format traced to real lack of BC texture support

Previous turn was progress; this turn further identifies the actual cause. Original descriptor construction at0x100a9eba4 reads its Metal format from texture+0x298. A bounded AArch64 store scan finds the relevant assignment at0x100aa5e0c: it stores the result of original mapping0x100a9a780, called with internal format at+0x90 and capability bit4 of device+0x170. That mapper reads a constant table at0x104651660, then returns zero for internal formats83–103 when the capability is false. Its helper0x100b07618 classifies that exact range.

Added read-only runtime diagnostics. MetalFormatTrace.m captures the original caller's x19 through a two-instruction ABI trampoline before forwarding setPixelFormat unchanged; it accesses the texture layout only for verified original return offset0xa9ec7c. This finds internal0/mapped0 at allocation. One additional recorded instruction change routes the mapping call through the existing reserved-import bridge, which calls the original mapper unchanged and logs actual input/output. Actual mapping-run shows internal84/capability0/result0 repeatedly, then internal93/capability0/result0 for the2048×2048 failure. The constant table maps84 to Metal130(BC1_RGBA) and93 to140(BC4_RUnorm). The caller clears the internal format after a failed mapping. This explains why the later Metal descriptor contains zero.

BCSurvey.m runs on the sole designated iPad Simulator and returns `Apple iOS simulator GPU supportsBC=0`. This is an actual runtime limitation, not a capability value to replace with true. No BC capability was overridden, no invalid format was substituted, and original rendering still stops. [Apple supportsBCTextureCompression](https://developer.apple.com/documentation/metal/mtldevice/supportsbctexturecompression) and the installed Metal SDK establish API and format names.

Read-only DDS audit found1475 assets:698 uncompressed,419DXT5,257DXT1,99DX10-format98(BC7),2DXT3. No standalone BC4 DDS exists, including no2048×2048 candidate. Thus an offline conversion of a known BC4 DDS does not address the observed allocation; runtime generation or another resource type is still an inference, not identified provenance. Current texture can be a dynamically allocated atlas; identify its upload path before assuming it has initialized compressed content.

Pinned unmodified bcdec.h from upstream commit80859ed3b7afb1c527a2a99d70c61457bea72d0c under port/de/third_party/bcdec with provenance, SHA256 and retained MIT license. Added BC4Decode.c/h, a bounded BC4 UNORM-to-R8 decoder supporting padded strides, unaligned compressed input, edge blocks and rejection before output writes. Native AddressSanitizer/UndefinedBehaviorSanitizer tests and the same test in the designated Simulator pass524288 endpoint/index combinations plus bounds/stride/crop checks. R8 quantizes interpolated BC4 values; this is not a bit-exact floating-point GPU sampler reference. Decoder is NOT linked into the engine adapter yet, and no original texture upload is decoded yet. This is implementation groundwork for the observed failure, not gameplay proof. [Microsoft block compression formats](https://learn.microsoft.com/en-us/windows/win32/direct3d11/texture-block-compression-in-direct3d-11) explains the BC family; [upstream decoder](https://github.com/iOrange/bcdec/tree/80859ed3b7afb1c527a2a99d70c61457bea72d0c) supplies the implementation.

Next implementation needs: trace the original BC4 allocation/update/copy paths; provide real uncompressed backing plus decoding on compressed uploads (including buffer-to-texture blits, partial regions, row pitches and mip/slice dimensions); ensure shader bindings use that actual backing with correct channel and normalization behavior. Add BC1/2/3/5/7 as demanded by supplied textures using the pinned decoder; signed and sRGB semantics must remain correct. Do not advertise generic BC support before those operations are implemented. A higher-precision BC4 target should be considered if R8 quantization is visually or numerically unacceptable. Compare decoded sampling with a native BC-capable GPU, then require original menu/gameplay screenshots and performance evidence. Physical-device support may differ, but Simulator-first remains the user's explicit order.

Current installed executable has four documented instruction changes in total (295cube skip,296two minspec bridges,297mapping trace). format-call-patch.json preserves a complete before-image and signed hashes. Its current signed SHA256 is93b4c3bc9e2e801c99dd1c10bcd107a5e86313c3b6642d4bcd3eb95efa7adbd5. text-patch-verification.json proves only the recorded instruction changed in __text this turn. Source snapshots, two actual runs, disassembly, scanner/audit scripts and result.json are preserved under generated/mac-de-simulator-297. First build succeeded but launch failed due missing copied package metadata; corrected before either engine run. Both actual game runs are terminal; helpers and relays are cleaned and process absence checked. Ref inputs remain untouched. No gameplay, sustained FPS, touch gameplay, physical-device or supported retail multiplayer gate is complete. Full goal remains active.


## Iteration 296: hardware warning, managed textures and full-screen startup advanced; invalid texture format is next

The original engine now advances past the minimum-spec exit after a real **Continue Anyway** tap, allocates the previously rejected managed textures using shared storage, completes its full-screen callbacks, and resets the original game view's cursor regions. The latest repeatable failure is a **2048×2048 private, shader-readable 2D texture whose original descriptor has pixel format 0 (invalid)**. This is not yet gameplay rendering. No arbitrary replacement format, fake successful allocation, benchmark override or authentication bypass was introduced.

`generated/mac-de-simulator-296` preserves the builds, run logs, screenshots, exact patches, source snapshots and result.json. The original supplied refs remain unchanged. The installed diagnostic executable now has three recorded instruction changes: iteration 295's cube-placeholder branch and two iteration 296 call-site bridges. The latter route the original minimum test and warning call through a reserved import; original test code executes unchanged and returns failed mask 16. The diagnostic UIKit warning waits for an actual button action and returns 0x9002 only for Continue Anyway. Original message text was empty, so the warning uses a generic hardware-warning message. The exact failing criterion represented by bit 16 remains unmapped. The warning bridge is version-specific, not a general implementation of the original Win32 dialog or the reserved CoreGraphics import. Backup, signed hashes and instruction records are in minspec-call-patch.json; text-patch-verification.json confirms all seven changed __text bytes are within the two recorded four-byte calls.

The next observed Metal failure was managed storage mode 1, unavailable on this UIKit runtime. MetalDevicesCompat copies that descriptor and changes only storageMode to shared. Actual engine runs allocate 256×16 and 1024×64 format-80 textures, then advance. Further resource synchronization semantics remain to be qualified if encountered. Apple documents [managed storage](https://developer.apple.com/documentation/metal/mtlstoragemode/managed) as unavailable on iOS and recommends shared storage on Apple silicon. Allocation still uses the real device and returns its actual result.

One run instead crashed Apple's SimMetalHost at newCommandQueueWithDescriptor; the retry hung in initial MTLCreateSystemDefaultDevice XPC. Captured both crash evidence and retry-sample.txt, terminated only the diagnostic game, allowed runner cleanup, then rebooted the same sole designated Simulator. Startup recovered. No scenario was running or lost. Current window is portrait, CGWindow 5335, owner PID 58388, bounds x175/y30/703×1018. Shadow-free screenshot coordinates are reliable; actual Play is global704,715, paste decline526,578 and warning Continue526,576. Recheck geometry before future interaction.

WindowViewCompat now fills the actual UIKit root content area for the game's full-screen transition, retains/restores the windowed frame, updates the full-screen style bit and sends transition notifications/delegate callbacks around actual layout. Actual completion logs1180×820. Exit/re-entry and resize behavior are not yet qualified. AppLifecycleCompat accepts the observed presentation request10 (hide desktop Dock/menu, absent in this host); it does not pretend to disable app switching or force quit. Desktop standardWindowButton returns nil because the UIKit content host has no AppKit title bar. Cursor invalidation calls original resetCursorRects; CFeralNSView completes this three times. No cursor regions have yet been registered, and custom cursor appearance remains unimplemented.

The latest invalid-format-run PID25316 repeats the pixel-format failure after all those steps. Its logged descriptor is 2D,2048×2048,one mip/sample/slice,private storage,ShaderRead|PixelFormatView usage. Crash and allocation stack lead to original0x100aa41ec (newTextureWithDescriptor), caller0x100aa60ec. invalid-format-disassembly.txt and format-origin-disassembly.txt preserve these paths. The descriptor is already invalid on entry to the adapter. Next trace its construction and original internal format mapping, identify the requested asset/format, and implement an actual compatible format/upload path or verified existing engine fallback. Do not merely set format80/70 or advertise unsupported compression.

An attempted MainLog copy selected an older log. latest-MainLog.txt and the copied19:32/19:37/19:41 logs are **not evidence of the current runs**. The previously known container log directory currently exposes only those three older sessions; the fresh log destination or buffering behavior needs resolving. Current diagnosis is supported by actual runtime warning results, Metal validation, original call stacks and screenshots, not those stale logs.

All iteration296 terminal runs have per-run cleanup records; latest helper/relay are stopped and bootstrap discovery is clear. Runner observation now uses600seconds so services remain available during manual startup. No live game scenario remains. The full goal stays active: actual local DE gameplay, usable touch, sustained performance and supported retail multiplayer, Simulator first. Launcher/startup artwork and completion callbacks are not acceptance of these gates.

## Iteration295: cube-array setup corrected; original minimum-spec check is the current exit

Previous turn was progress. Verified PID13746 live, then deliberately replaced it to trace the failed allocation; no scenario existed. Read-only DXBC RDEF audit of all87 supplied game shader files finds76 texture bindings, all dimension4 (2D), plus110 constant-buffer/sampler entries with dimension0. No cube/cube-array bindings in these files. This does not audit embedded engine shaders. Reproducible audit-shader-resources.py and shader-resource-audit.json saved.

Allocation backtrace and original disassembly establish the1x1 two-cube placeholder is inside a capability-conditional initialization block: at original0x100d9cce0, TBZ w8,bit6 skips to0x100d9cdb0. It takes the unsupported-on-Simulator allocation when the bit is set. Applied a **four-byte compatibility patch to the installed Simulator diagnostic executable**, replacing instruction0x36300688 with0x14000034 to take that existing skip path. This changes original engine text; do not continue describing the diagnostic executable as text-unmodified. Original refs remain unchanged. A complete prepatch executable backup, original/patched hashes, exact branch target, script and signed-app verification are saved in cube-capability-patch.json and DEOriginalGame.before-cube-capability. text-patch-verification.json verifies every changed __text byte lies within that one instruction. The patch is specific to this tested Simulator lacking cube arrays, not a general physical-device patch or GPU capability override. Subsequent runs make no rejected cube-array allocation. Broader shader/rendering compatibility remains unproven.

Initial postpatch runs exit with libc++abi terminating. Exception tracing initially recursed via dlsym(RTLD_NEXT); exception-run is a diagnostic failure, not engine evidence. Corrected direct-original forwarding and verified a known std::runtime_error is still caught normally. Added terminate tracing, with independent control proving the registered terminate handler still runs (exit42). The original terminate caller is0x2d03d20 during exit cleanup; the original exit path calls exit at0x309b70, from0xf37684. Later std::system_error mutex failures are cleanup symptoms. The Security exceptions seen earlier in the log are handled during launcher startup and are not the startup exit diagnosis.

**Decisive evidence is the original game's VFS MainLog:** after Initializing Steam System it logs Min spec not passed, tears down managers, and logs Exiting with code0. The latest copied log is generated/mac-de-simulator-295/2026.09.09-1946.47-MainLog.txt (SteamID lines filtered). It reports zero dedicated/shared graphics memory and0.221GB currently available system memory despite24GB total; do not assume which individual criterion caused the minimum-spec failure without tracing it. Hardware/memory inputs must be checked against actual APIs, not fabricated to pass.

Ruled out one harness confound: most earlier runs stopped helper/relay before Play. live-steam-run's40second attempt also expired before Play and is NOT a live-service test. Extended run-de-game-relay.py's bounded observation maximum to600seconds (default15 unchanged); current package requests180. persistent-steam-run verifies game/helper/relay PIDs alive immediately before AND after actual Play, and still reaches the same minimum-spec exit. All7 helper/relay pairs are now cleaned; no game PID remains. The script still cleans services at its deadline, so future sustained game tests need an appropriate explicit service lifetime and must not claim authentication remains available after cleanup.

The original executable contains AO_MinSpecMessageSkip, Min Spec Message Skip, IDS_POPUP_MIN_SPEC_* strings for DirectX, CPU, system RAM and video RAM, and an existing HARDWARE_CONTINUE_ANYWAY action. These are leads, not a verified setting/control path. Next trace CheckMinSpec/DetectMinimumSpec and its actual inputs, then use a real existing continuation flow if appropriate for diagnostic rendering. Do not force a successful benchmark or overwrite capability responses. MainLog is now a required first inspection after each original startup attempt; stderr cleanup messages alone were misleading.

Installed candidate remains the original supplied Mac engine plus documented compatibility adapters and this Simulator-only instruction patch. Original launcher and startup-image rendering are established in earlier screenshots. No gameplay frame/FPS, physical-device acceptance, touch gameplay or retail multiplayer proof yet. Full goal remains active. Evidence/package: generated/mac-de-simulator-295/result.json, allocation/texture-origin/termination disassembly, minspec-strings.json, source-snapshot, original log copies, controls and all per-run logs.

Source for resource dimension names: [Microsoft D3D_SRV_DIMENSION](https://learn.microsoft.com/en-us/windows/win32/api/d3dcommon/ne-d3dcommon-d3d_srv_dimension). Shader bindings and original branch behavior above are local binary evidence.


## Iteration294: original Metal drawable composited; startup image visible; cube-array texture blocks further startup

Previous goal turn classified as progress. Checked actual sole booted Simulator and terminal prior PID. Added NSView tracking-area ownership/removal/enumeration and an actual UIKit hover recognizer for the observed entered/exited active-always options129. Original320x240 game view attaches tracking successfully. Hover delivery and full gameplay input are not qualified.

The original engine now attaches a real CAMetalLayer and obtains real CAMetalDrawable instances. tracking-run PID12862 stops at addPresentedHandler:, absent in the Simulator Metal SDK and runtime. An independent actual Simulator drawable survey records the class's available methods and ABI. Added a compatibility handler registry triggered only by real setDidComposite:YES. Original drawable-run PID13216 registers two callbacks and one actual composition signal delivers a callback. Its later failure is Metal validation: Texture Cube Array is not supported on this device. No submission, command-buffer completion, or timer is falsely reported as composition. presentedTime fallback is the time the composition signal is observed, not actual scanout timing; do not use this for gameplay FPS acceptance. Dropped-drawable completion semantics and drawable reuse still need qualification; the bridge is an incomplete Simulator compatibility implementation.

Descriptor diagnostics identify the rejected allocation as cube-array,1x1,count2,format70,usage1. Guarding a known unsupported allocation returns nil rather than hitting the Metal validation abort; all supported allocations retain the actual API and Objective-C new-method ownership. This is a diagnostic failure result, not emulated cube-array support. An initial texture-limit-run stayed at the launcher and was deliberately replaced before Play to correct return ownership. texture-ownership-run PID13746 passes the earlier stops, displays the original startup image on the actual Simulator screen, and remains alive. Actual-screen evidence: generated/mac-de-simulator-294/texture-after-play.png. This is a startup image, not gameplay or skirmish acceptance.

Live sample shows WinMain waiting at original0xa7d8ec on a renderer semaphore. Static disassembly of its callers includes object deletion/renderer cleanup after the unsupported allocation. Therefore nil has not proven the resource optional or successful startup; the small allocation may be a placeholder but this remains an inference. Do not report the splash or low CPU usage as normal game execution. Original renderer's cube-array requirement needs a real compatibility path or a verified existing capability fallback. If it is a generic unused placeholder, establish that from the original initialization and shader/resource use before changing it. If used, texture storage and shader sampling semantics must both be implemented; substituting an incompatible texture type or falsely advertising GPU support is not a fix.

Current live PID13746 is deliberately preserved for inspection, with visible startup image. The runner's observation period ended while the launcher was alive, then actual Play drove the subsequent behavior. Four helper/relay pairs were cleaned; only13746 remains. Installed app, original refs and staged game bytes were preserved. Changes are private overrides in generated/mac-de-simulator-294, with reproducible rebuild-and-run.py, runtime drawable survey, per-run logs/cleanup, live sample, renderer-wait-disassembly.txt, result.json and source-snapshot/hashes. No scenario was reached or lost.

Next: trace the exact cube-array allocation role and the renderer cleanup wait, including whether an uncomposited drawable has a dropped-frame completion path. Preserve the live candidate until inspection is complete. Full objective remains actual local iPad engine, touch gameplay, sustained measured FPS and genuine supported multiplayer, with Simulator first. None of gameplay/FPS/physical-device/multiplayer gates is complete.

Sources: [Apple MTLDrawable and presentation callbacks](https://developer.apple.com/documentation/metal/mtldrawable), [Apple GPU feature table](https://developer.apple.com/metal/capabilities/). Simulator SDK MTLDrawable.h and actual drawable-survey.txt independently establish the missing presentation API on this runtime.


## Iteration293: original Play reaches Metal initialization; game-view tracking is next

The actual original launcher still renders and accepts Simulator touch. Fifteen startup runs isolated and advanced several independent failures. The latest PID12236 passes original Metal compiler-scheduling setup, then stops explicitly at **-[NSView addTrackingArea:]**. It has exited; all fifteen runs' temporary Steam helpers and host relays are confirmed cleaned. No game scenario was reached or lost. No original gameplay frame, measured gameplay FPS, physical-device execution or multiplayer acceptance yet. Full goal remains active.

Implemented real UIAlertController presentation for the original NSAlert message and buttons. The visible original fatal dialog identified a missing EntitlementData.pbin file. Read-only tracing proved the game's VFS maps the correct staged directory but lowercases the filename; a separate Simulator stat probe succeeds with the original spelling and fails with lowercase. Renamed only the staged clone's directory entry to entitlementdata.pbin, preserving all18360 bytes and SHA25694f94af221bdfaba991b7b0feb8ce6394e7e069a802db77aa30b6727f02d7757. Supplied refs are untouched. The next real run opens the file and advances. The tree audit found no casefold collisions, but other mixed-case paths remain a possible future issue. case-run's first rename attempt aborted its assertion and did not apply a fix; lowercase-run is the successful test. Actual alert pixels are verified; button response dispatch is implemented but was not separately exercised before the diagnostic restart.

Added refresh interval queries using actual UIScreen.maximumFramesPerSecond and a fixed-cadence compatibility display contract; this is not measured gameplay FPS or a claim about the panel's variable-refresh range. The later white screen was a null indirect call on original WinMain, not evidence of a GPU failure. First-signal capture gives PC0 and LR pointing to a cached function lookup; original disassembly and string data identify CFBundleGetFunctionPointerForName for free in macOS System.framework. A narrowly scoped interposer resolves that exact otherwise-missing lookup to real libSystem free. Independent Simulator control fails resolution without the bridge and verifies pointer identity plus malloc/free4096 bytes with it. Original startup then advances. The optional signal diagnostic has an old-action replacement caveat and is not inserted in the final candidate.

Added retained app-owned event-source objects, zero synthetic-input suppression (UIKit's unsuppressed input delivery), and logical pointer repositioning. Source type0 and suppression0 are actually observed; subsequent pointer snapshots reflect the updated position. This does not move the host cursor or implement a macOS system-wide event stream. Private-source event snapshots, nonzero suppression, and synthetic event posting remain unsupported. Gameplay touch/drag/keyboard completeness is not proven.

Original game reaches MTLSimDevice.setShouldMaximizeConcurrentCompilation:, a macOS-only optimization absent on the Simulator device. The compatibility fallback keeps platform-default compiler scheduling and reports extra-thread mode disabled; no shader result or GPU capability is fabricated. First compiler-scheduling-run accidentally reused the old separate Metal dylib and failed unchanged. Rebuilt the correct library: metal-default-run logs requested_maximum=1, effective=platform-default, then reaches NSView.addTrackingArea. Runner now rebuilds/signs AppKit, CoreGraphics and Metal together. Shader compilation, CAMetalLayer attachment and first drawable presentation are still unproven.

Evidence/reproduction: generated/mac-de-simulator-293/result.json, rebuild-and-run.py, source-snapshot/, source-hashes.json, alert.png, case-probe.txt, entitlement-case-rename.json, system-control-before.json, system-control-after.json, null-resolver-disassembly.txt, metal-default-run/game.stderr and cleanup.json. Per-run alive_after_observation=true refers to the initial launcher; subsequent actual Play can and did terminate these processes. Preserve original refs, installed app UUID/adjacent staged data, and classic candidates. The runner still uses genuine host-assisted Steam, which does not qualify standalone-device authentication or Windows cross-play.

Next: implement actual UIKit hover tracking for the observed game-view tracking-area options, then follow original layer creation, shader compilation and presentation. Check actual options and do not merely return success for unimplemented input. The active target remains a real game frame, then playable skirmish and measured FPS, followed by physical iPad and supported retail multiplayer.

Sources: [Apple event-source state domains](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid), [Apple Metal compiler scheduling property](https://developer.apple.com/documentation/metal/mtldevice/shouldmaximizeconcurrentcompilation).


## Iteration292: original launcher visibly renders and responds to Simulator touch

**New actual-screen evidence:** generated/mac-de-simulator-292/direct-screen.png shows the original Age of Empires II DE launcher artwork, text, buttons and usage-statistics dialog in the designated iPad Simulator. after-continue.png shows the unobstructed original launcher. This is not a recreated UI, streamed frame or game-skirmish frame. UIKit drawRect calls the same-process original WebView's displayRectIgnoringOpacity:inContext:. Web preferences disable accelerated compositing for this launcher, WAK tiling is disabled, and a weak-capturing timer requests launcher repaint at10Hz while attached. This is a temporary launcher refresh policy, not measured game FPS or the final performance target. Game Metal rendering remains separate and unproven.

The failure was isolated by read-only DOM/view/layer diagnostics: readyState complete,930x640 host/WebView/all descendants, and17/18 inspected images loaded. Four WAK tiles had contents but their image was black. Force-paint/layout and CATransaction flush did not fix presentation. Direct WebView rendering produced artwork; disabling launcher accelerated compositing restored text and dialogs. The exact tiled painting failure is still unclassified; direct drawing is the proven alternative. Diagnostic snapshot files are offscreen evidence only; direct-screen.png is the actual-screen acceptance evidence. One initial hierarchy diagnostic incorrectly queried isHidden, which WAKView lacks, and crashed; it was guarded before rerun. No fabricated selector success.

Added actual single-touch -> WebEvent mouse-down/move/up routing through WAKWindow.sendEventSynchronously, with outside-point release on cancellation. Runtime WebEvent initializer encodings were checked. Native macOS HID events sent to the observed Simulator window produce genuine UITouch callbacks in the app. Logs show four down/up pairs activating **Do Not Send**, mouse notice **OK**, function-key notice **Continue**, and **Play**. Screenshots independently verify each dialog transition. This proves a launcher touch path; drag, multitouch, gameplay controls, hover and physical-device touch are not qualified. No optional usage reporting was enabled. The first process-targeted mouse injection had no effect; HID posting was the effective path.

After Play, PID6922 exits at the intentionally unsupported -[NSAlert init]. **Next: implement the actual alert object/presentation and inspect its message before interpreting or responding to it.** Do not assume it is a GPU, OS-version or authentication error from the allocation boundary alone. No original gameplay frame, skirmish, gameplay FPS or multiplayer proof yet. The renderer/launcher milestone advances the full goal; it does not complete it.

Package/evidence: generated/mac-de-simulator-292/result.json, rebuild-and-run.py, touch-run/game.stderr, screenshots, DOM summaries, runtime surveys and source downloads. Eight bounded startup runs, all helper/relay cleanup verified;6922 was alive after15seconds but later exited after the explicit Play action. No currently live game remains. The installed diagnostic app itself was not replaced; these are private DYLD library overrides in the test runner. Preserve refs and classic candidates. Scope remains supplied Mac engine and host-assisted Steam in Simulator, not standalone-device Steam or Windows cross-play.


## Iteration291: original launcher remains alive; visible surface is blank

Built a UIKit CALayer host for the actual Simulator WebKitLegacy WAKWindow/WAKView. Runtime inspection confirmed CFeralNSWebView -> WebView -> WAKView, and checked WAKWindow method encodings. Original WebView and its JavaScript/Objective-C bridge are preserved; no substituted launcher HTML. Upstream WAKWindow supports initWithLayer:, content-view attachment, visibility and tile layout. WebThreadLock is released automatically at the main runloop boundary. The reverse WebView-to-host reference is weak, while UIKit owns the host, which owns WAKWindow and its content view. Standalone Simulator control verifies host/window/web-view cleanup and host reuse. This does not verify pixels or input delivery.

Added real screen wrapping for NSWindow.screen, undecorated frame geometry, fixed-host inLiveResize=false, retained subview replacement, original WebView frame forwarding, tracking-area metadata, and a UIKit hover observer for the observed active-always entered/exited options129. Actual hover delivery is not yet tested. Added read-side UIPasteboard wrapping. Original setTouchBar:nil now clears the absent Touch Bar; non-nil values still stop explicitly.

PID4674 first reaches DE_GAME_WINDOW_VISIBLE (930x640), then stops at generalPasteboard. PID4835 executes original launcher JavaScript through WebCore ObjcInstance::invokeObjcMethod into DEOriginalGame, then stops at setTouchBar:. PID4996 survives the15-second observation and remains running after28seconds. Actual screenshots show a black rectangle with a white surrounding area, no artwork or text. **This is a visible launcher surface, not a rendered game frame.** No gameplay FPS, touch playability, physical-iPad execution or multiplayer acceptance.

The live sample shows the original application's nested event loop servicing WebCore image-load events and JavaScript. Sample physical footprint123.4MiB (peak143.3MiB); this is launcher-only memory, not game memory. LLDB attach to4996 failed with lost connection; no successful live object inspection. Next discriminator: instrument read-only DOM/resource state and actual host/WebView geometry/tiling. Do not infer the blank surface is a GPU limitation without these checks. Preserve the current live candidate until evidence is captured; any next binary update restarts this launcher only, with no game scenario reached.

Private reproducible package/evidence: generated/mac-de-simulator-291/, including rebuild-and-run.py, result.json, live-launcher.png, live-sample.txt, host-control.json, WebView/WAK surveys and upstream sources. All temporary relay/helper cleanup verified; the game process is deliberately left alive. Steam evidence remains host-assisted. Installed diagnostic app UUID and original files were preserved; private library overrides are selected by the test runner, not by tapping the app icon alone.

Source: [WebKit WAKWindow](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/ios/wak/WAKWindow.h), [WebThread locking contract](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/ios/wak/WebCoreThread.h).


## Window/view bridge implemented; legacy launcher WebView blocks presentation290

The user explicitly pushed for rendering-first execution while preserving the full goal. Implemented NSMenu/NSMenuItem retained object models (items, tags, indices, submenu ownership), original-created NSEvent other-event storage/queueing, device-RGB color objects with the existing noncolliding NSColor alias, and UIKit-hosted NSWindow/NSView models. The view host retains the original CALayer/CAMetalLayer as a real sublayer, tracks bounds and scale, and preserves object identity. Window activation targets the existing diagnostic UIWindow, preserves requested window dimensions, and supports responder/visibility/geometry state. These are initial partial implementations: desktop decoration, dragging, full notifications and broader view APIs are not complete.

Original engine passed menu construction and queried Mac key55 twice. GameController reports no connected hardware keyboard, so key state is false; present keyboards map the observed modifier and basic-key subset, with unknown keys still stopping. PID1230 reaches NSWindow initWithContentRect:styleMask:backing:defer:. PID1447 creates a930x640-point window, then reaches first-responder setup. Subsequent runs progress through window state, original application-defined event creation (type15/subtype12345), background color and responder-chain setup. No makeKeyAndOrderFront or original Metal layer attachment has occurred in the game yet.

The apparent game window is actually Feral's web-based launcher. PID2166 throws for -[CFeralNSWebView setWantsLayer:]. A read-only native preference inspection confirms Setup/GameOptionsDialogShouldShow. Backed up the Simulator diagnostic profile and set only that preference to0. PID2469 reaches the same exception; the preference remains0, so this did not provide a launcher bypass. Do not repeat it unchanged or claim its reason is established. Native profile and supplied refs remain untouched. The original string reference inspected at0x100f1e4a4 writes a true variant; its trigger has not been fully classified.

An initial attempt to adapt an assumed UIKit web view was wrong. Runtime class inspection in PID2795 conclusively shows CFeralNSWebView's parent is legacy WebView and it is NOT a UIView subclass. The adapter therefore correctly refrains from adding a UIKit-layer method. The initial dlsym-based installer was not sufficient evidence of installation; changed to an optional weak-linked installer and captured the actual class chain. Current boundary remains that legacy-WebView mismatch. This is not an original GPU shader failure. The original window/view bridge must ultimately host a supported web implementation if this launcher path remains required, or use an actually verified original skip-launcher route. Do not change authentication outcomes or previous-run success records to force startup.

Actual Simulator component control passes NSView hierarchy/removal, retention/identity and40x30 geometry of a real CAMetalLayer, menu ownership/removal, device-RGB components, and original-created event field preservation through the queue. The standalone control initially lacked objc/runtime.h; fixed the source include and reran successfully. These tests do not render a frame. Actual screenshot after-window-tests.png was captured and inspected: SpringBoard after process exit. No launcher/game appearance is available for classic/HD visual comparison; visual acceptance remains open.

Evidence generated/mac-de-simulator-290/result.json, exact-PID runs/cleanup, window-model-control.json, launcher-toggle.json and private preference backup, original preference caller, actual class diagnostic and screenshot. All temporary helpers/relays cleaned up. One designated Simulator; original installed bundle/data snapshot retained and private DYLD boundary overrides used. No app replacement or unsaved gameplay loss. Source MenuCompat.m, WindowViewCompat.m, ColorCompat.m, EventCompat.m, their model control, PointerEventCompat.m, AppLifecycleCompat.m and builder flags. Immediate priority remains first original game frame, then original skirmish FPS; standalone device, touch and supported multiplayer remain unproved.

## Real GPU enumeration and desktop metadata pass; menu construction next289

Previous288 made progress through the original event wait. Read original pointer caller at0x100467d94: CGEventCreate(NULL), CGEventGetLocation, CFRelease. Added an explicit app-owned pointer initialized at the actual UIKit window center (590,410 in this landscape run), with touch/hover observers and retained coordinate snapshots. PID98599 passes the snapshot and reaches NSCursor currentCursor; the adapter can only activate the default cursor, so that accessor returns its default singleton. PID98691 then reaches MTLCopyAllDevicesWithObserver. Pointer snapshot controls verify independent values and retain/release. Actual touch/hover delivery has NOT been exercised: installing observers is not proof of touch input. Click/command translation, cursor rendering and gesture interactions remain open.

The current SDK provides actual MTLCopyAllDevices on iOS18+. Added genuine device enumeration and a registry retaining observer tokens; one-second polling emits additions/removals only when actual device registry IDs change. Advance removal-request notification is unavailable. Main-thread creation/removal is required; removal cancels the timer and releases the registry retain. Simulator control matches real enumeration (one device) and verifies observer teardown. Hotplug behavior has not been exercised.

PID98886 reaches the actual MTLSimDevice, then throws for missing macOS-only location. Added only absent runtime methods; existing device APIs are never replaced. location uses native MTLDeviceLocationUnspecified (NSUIntegerMax). PID99071 then reaches locationNumber. Offline caller0x100b11c70 shows these values going into the Metal hardware-information table. locationNumber uses an explicit adapter unknown sentinel (NSUIntegerMax, NOT an Apple-defined location-number constant or fabricated port). PID99461 reaches maxTransferRate. Apple documents [location metadata](https://developer.apple.com/documentation/metal/mtldevice/locationnumber) as not applicable on Apple Silicon.

The unified-memory branch deliberately stopped in PID99592: the Simulator wrapper reports hasUnifiedMemory=false. A native/Simulator survey finds the same registryID4294968172: native Apple M2 reports unified=true and transfer_rate=0, while Simulator reports Apple iOS simulator GPU and unified=false. Added an opt-in desktop transfer-rate lookup from that actual native survey, requiring an exact registry-ID match. This supplies backing-GPU metadata only; no Simulator feature flag, memory model, resource creation or shader result is overridden. Use SIMCTL_CHILD_AGEPAD_HOST_METAL_METADATA pointing at the recorded native survey JSON. It is host-specific Simulator evidence, not a physical-iPad implementation. Native built-in maxTransferRate=0 follows installed MTLDevice.h.

PID99761 passes repeated metadata collection and reaches activateIgnoringOtherApps:. This now succeeds only when UIKit actually reports the app active. PID99861 advances to mainMenu; no desktop menu bar has been installed, so that query returns nil. PID99950 now reaches -[NSMenu initWithTitle:]. This is the next concrete boundary. No original game frame, menu rendering, gameplay FPS or touch-command proof. Main-menu absence is not evidence of the game's in-game menu.

Evidence generated/mac-de-simulator-289/result.json; exact-PID run/cleanup records; pointer and Metal controls; native/Simulator device surveys; original pointer and GPU-table caller disassembly. One control initially failed compilation due to an incorrectly typed Objective-C protocol dispatch; corrected to class_getMethodImplementation and the control passes. All temporary service cleanup verified. Same sole designated Simulator and installed app/data preserved, private boundary overrides only. Source TouchPointerCompat.m, PointerEventCompat.m, MetalDevicesCompat.m/controls, DefaultCursorCompat.m, AppLifecycleCompat.m and builder flags --pointer-snapshot/--metal-device-observer. Next handle the real menu model sufficiently to reach game window/renderer creation; do not interpret more startup boundaries as proof of final feasibility. The user was explicitly told the answer remains unproven, not yes. Full device, standalone authentication, supported multiplayer and performance requirements remain active.

## Event-loop polling advances original startup288

Previous287 made progress through display mode enumeration. Added empty NSScreen auxiliary top-left/right rectangles: no additional UIKit drawing regions are advertised. The native NSScreen.h contract permits empty rectangles when no additional unobscured regions exist; this does not implement full safe-area handling. PID94500 advances to NSApplication isRunning. That query now reflects actual entry into UIApplicationMain with an atomic loop state, reset if it returns. PID95220 advances to nextEventMatchingMask:untilDate:inMode:dequeue:.

Diagnostic PID95305 captures the actual call: all event types, about143ms deadline, default run-loop mode, dequeue enabled. Added an opt-in queue (AGEPAD_EVENT_QUEUE) supporting mask filtering, peek/dequeue, posting and deadline waits while servicing actual Foundation/UIKit run-loop sources. Unsupported modes, implicit deadlines and non-main-thread reads remain explicit stops. A10ms maximum wait slice bounds cross-thread post latency; a source-free loop sleeps instead of spinning. This is queue infrastructure, not UIKit-to-NSEvent translation. No touch, mouse or keyboard event is synthesized to claim input success. Apple's [event polling contract](https://developer.apple.com/documentation/appkit/nsapplication/nextevent(matching:until:inmode:dequeue:)) returns nil when no matching event arrives by the deadline.

Actual Simulator control passes mask filtering, non-destructive peek, dequeue, timer-produced event delivery (~34ms) and empty-queue timeout (~40ms). Original PID97810 progresses through event polling to CGDisplayBounds. Added actual UIScreen bounds for its stable adapter display ID, CGRectZero for an invalid display. PID97943 now stops at CGEventCreate. No game frame or gameplay FPS has been captured; the input boundary is now the next concrete dependency.

Evidence generated/mac-de-simulator-288/result.json and five exact-PID run directories; event-control.json. All helper and relay cleanup verified. Same sole designated Simulator, existing installed diagnostic app and cloned data preserved. Private boundary overrides only. Source ScreenCompat.m, AppLifecycleCompat.m, EventQueueCompat.m/control and DisplayModeCompat.m. Next inspect actual CGEventCreate source and consumer, then implement input state from UIKit without inventing user actions. Steam transport remains host-assisted; physical iPad, supported multiplayer, touch-alone play and performance gates remain open.

## Startup reaches real UIKit display geometry287

Previous286 was progress: actual engine image/cursor construction reached a keyboard property query. The original game queried ID and language properties of a NULL input source. Added NULL-source property absence; a native Carbon control verifies NULL for the ID query. Non-NULL sources still stop explicitly. Original PID1409 advances to Gestalt. An opt-in undefined-selector result (-5551, from the installed CarbonCore header) for the actual sys1 query advances PID6094 to CGDisplayCopyDisplayMode; no macOS version value was invented. This is an unavailable-system-information diagnostic, not a complete implementation.

Added current UIKit screen mode snapshots with retained ownership, point dimensions and release. The installed native CGDirectDisplay.h specifies points for CGDisplayModeGetWidth/Height, distinct from backing pixels. Original PID9268 reads display1 at1180x820 points, while UIScreenMode reports1640x2360 backing pixels in native orientation, then stops at CGDisplayModeGetIOFlags. Separate actual Simulator control verifies dimensions against its UIKit screen, invalid/NULL handling and survival across retain/release. Its standalone portrait orientation is820x1180 points; the game is landscape. No IOKit flags, refresh rate, mode enumeration or physical display measurements are invented.

The original caller at0x100498ac8 extracts bits1 (safe),6 (interlaced) and11 (stretched), then reads and releases the mode dimensions. Added explicit current-UIKit-surface flags valid|safe (3): a presentation policy, not a physical IOKit query. PID90838 advances to mode enumeration. The adapter advertises only its existing supported UIKit mode and retains it in a CFArray; no hardware mode switching is advertised. PID92274 passes these calls and reaches -[NSScreen auxiliaryTopLeftArea]. The extended Simulator control passes CF ownership and enumeration checks. Rendering must still verify the surface contract. Apple describes [UIScreenMode](https://developer.apple.com/documentation/uikit/uiscreenmode?language=objc) as backing-buffer dimensions and pixel aspect; [IOKit flags](https://developer.apple.com/documentation/iokit/iodisplaymodeinformation/1505482-flags) describe physical mode attributes, so these policies must remain distinct.

Evidence generated/mac-de-simulator-287/result.json and property-run/, gestalt-run/, display-run/, native-null-source.json, display-control.json. All temporary helper/relay cleanup verified. The existing installed diagnostic app and cloned game data remain unchanged; only private DYLD-selected boundary libraries changed. Same sole designated Simulator. Source KeyboardLayoutCompat.m, GestaltCompat.m, DisplayModeCompat.m and its control; opt-in builder/runtime flags retained. Next implement the actual screen safe-area/auxiliary-area contract. The installed NSScreen.h specifies empty auxiliary rectangles when no additional unobscured top areas exist. No original game frame, menu, gameplay FPS, touch, standalone device or multiplayer proof yet. Steam initialization continues to rely on genuine host-assisted Simulator transport and does not establish independent iPad authentication.

## Real image/cursor metadata construction advances startup286

Previous285 was progress: startup reached NSImage construction. Added a retained CGImage-backed NSImage representation with logical size separate from pixel dimensions, NSZeroSize using source pixels, size mutation, copying, and an existing-CGImage accessor. The accessor retains/autoreleases the image so it survives wrapper destruction until the current pool drains. These semantics follow the installed native AppKit NSImage.h contract. File loading, unsupported drawing APIs and other image operations still stop; this is not a complete NSImage implementation.

Native and actual Simulator controls agree on automatic/explicit logical sizes, copy size, and exact two-pixel data after the original image and wrapper are released. Original-gamePID94435 creates a genuine3x3 CGImage-backed object, then stops at NSCursor initWithImage:hotSpot:. Implemented retained cursor image and hotspot storage, guarded by AGEPAD_CURSOR_IMAGES. Native/Simulator controls also agree on retained cursor image dimensions and fractional hotspot values. Custom cursor set/activation still explicitly stops because UIKit custom rendering is not implemented; there is no silent substitution of a default cursor for a custom one.

Original-gamePID97076 now constructs the3x3 image and cursor with hotspot1,1, then stops at TISGetInputSourceProperty. This is image/cursor object construction evidence, not a rendered cursor or game frame. Visual comparison against classic/HD references remains pending until there is rendered game UI; no custom control appearance was claimed. Both original-engine runs use the existing installed app/data snapshot, preserved reference inputs and designated Simulator. Temporary helper/relay cleanup and service disappearance verified.

Evidence generated/mac-de-simulator-286/result.json, image-run/ and cursor-storage-run/, host/simulator image and cursor controls. Source ImageCompat.m, ImageCompatControl.m, DefaultCursorCompat.m and builder flag --cgimage-wrapper. Runtime AGEPAD_CGIMAGE_WRAPPER and AGEPAD_CURSOR_IMAGES opt in; prior keyboard/default-cursor flags remain required. Next inspect the actual source/property arguments and caller behavior at TISGetInputSourceProperty before choosing input-source semantics. Keyboard translation, cursor activation, menus, gameplay/FPS, touch, standalone iPad and multiplayer remain unproved.

## Keyboard unavailable fallback and default cursor factory advance startup285

Previous284 was progress: real SDK initialization and game-data discovery advanced. Inspected the original keyboard caller at0x10045e6e8: it handles an absent layout/property/data pointer by returning no translated character. Apple's installed TextInputSources.h describes Carbon layout objects but does not provide an iPad API. Added compile/runtime-opt-in unavailable-layout diagnostics for the two layout-copy calls. They returnNULL because no Carbon layout is supplied; this is explicitly not a keyboard translation implementation. Original enginePID93026 takes the fallback and advances to +[NSCursor arrowCursor].

Added an opt-in default NSCursor object policy that leaves UIKit's existing default pointer behavior unchanged. Custom images, hiding and cursor stacks remain unsupported. Built it into an isolated replacement AppKit boundary selected by DYLD_LIBRARY_PATH; installed app, data snapshot and private references remain unchanged. The first scratch build omitted the existing NSColor export aliases and failed at dyldPID93491; rebuilt with the original aliases restored. ActualPID93714 executes the keyboard fallback and default-cursor factory, then stops at -[NSImage initWithCGImage:size:]. No duplicate-class warning was observed. No claim of visual cursor fidelity or completed input support follows from this startup test.

Evidence generated/mac-de-simulator-285/result.json, original caller disassembly, all three exactPID logs/cleanup records and explicit build command. Actual Simulator screenshot after-startup-test.png was captured and inspected: SpringBoard after diagnostic exit, no game frame. Consequently visual acceptance against classic/HD references is still pending; no custom controls or game appearance were demonstrated. All temporary helpers exited and their service disappearance was verified.

Source changes: port/de/KeyboardLayoutCompat.m and DefaultCursorCompat.m; builder flags --keyboard-layout-unavailable and --default-uikit-cursor. Runtime flags AGEPAD_NO_CARBON_LAYOUT and AGEPAD_DEFAULT_UIKIT_CURSOR are required; defaults still stop at unsupported behavior. To reproduce current candidate, pass those as SIMCTL_CHILD_ environment values to scripts/run-de-game-relay.py using the285 package and the recorded discovery probe. Next inspect actual NSImage/cursor construction and implement a real image representation with correct CGImage retention and size semantics. Keyboard translation, text entry, custom pointer behavior, menus, gameplay/FPS and multiplayer remain unproved.

## Real SDK initializes; original game advances through data discovery284

Previous283 was progress: actual Simulator client pipe/user/login status worked against the host session. The supplied SDK's public SteamAPI_GetSteamInstallPath returns a literal dot and is not a useful discovery source. A native executable's interpose table did not capture SDK messages; a separately inserted observer dylib did. Observed real path request/reply shapes, then implemented a read-only host query. Its entire520byte payload exactly matches the real SDK's captured response, including the actual PID/path. No path or process identity is fabricated.

Added an ephemeral same-user Unix-socket relay restricted to this one read-only query. Every request gets a fresh response from the real host Steam IPC service. The Simulator's original IPC helper adapter forwards that response payload while preserving the actual reply header; transport failure leaves its natural response unchanged. Socket resides in a private temporary directory, mode0600; peers must share the UID, I/O and host queries have timeouts, and relay lifetime/request counts are bounded. This is explicit host-assisted Simulator transport, not a standalone iPad solution or Steam-session implementation.

The supplied, section-preserved SDK returns initialized=true inside the Simulator control. Two live relay queries succeed. DYLD_LIBRARY_PATH selects the prepared client representations while real initialization/authentication calls run unchanged. The original game requires a client AppKit boundary that reexports its already-loaded AppKit adapters to avoid duplicate classes; three measured public string constants remain real values. The client diagnostic's other unsupported desktop API functions still stop if used.

Original-gamePID88352 then passes its former GetSteamPath failure and reaches NSOpenPanel. Staged an independent APFS clone of ref/AoE2DE/AgeOfEmpires2Data beside the current diagnostic app:24,211 files,19,861,966,103bytes, matching source path/size inventory. No reference symlink or reference-file modification. Original-gamePID89989 now passes the file-dialog stage and stops at TISCopyCurrentKeyboardLayoutInputSource. This controlled change supports missing adjacent data as the cause of the prior file-picker request. No menu or game frame has yet been observed.

Evidence generated/mac-de-simulator-284/result.json; native query comparison; sdk-relay-run/ initialized result and relay logs; original-game-relay/ first boundary; game-data-control/ new boundary; data-stage and AppKit linkage manifests. Temporary helper/relay terminated after each test and service absence verified. Same installed app/UUID and designated Simulator reused; no app update or host Steam modification. Reproduction runner scripts/run-de-game-relay.py PACKAGE NEW_OUTPUT --probe PATH_TO_SIMULATOR_DISCOVERY_PROBE expects the prepared private package and installed app metadata, and observes a bounded run.

Next inspect the game's actual keyboard-layout calls and implement an honest UIKit/input compatibility behavior or supported unavailable result. Do not return to Steam-discovery experiments unless a new failure warrants it. Original gameplay, FPS, touch, physical-device execution and multiplayer remain unproved; host-assisted Simulator SDK initialization does not establish any of them.

## Real Simulator client connects to host Steam and reports logged-on283

Previous282 was progress: vendor library loading and real SteamClient020 factory succeeded. Extended the isolated client harness with the actual interface's CreateSteamPipe, ConnectToGlobalUser, GetISteamUser("SteamUser021"), BLoggedOn, ReleaseUser and BReleaseSteamPipe calls. Method ordering follows Valve's [SteamClient020 header](https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/public/steam/isteamclient.h); login-state semantics follow its [ISteamUser header](https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/public/steam/isteamuser.h). SteamUser021 matches the supplied game SDK's version string. Results are not overridden, and no account identifiers or tokens are printed.

NativePID83380 creates a real pipe and global-user connection, releasing it successfully. SimulatorPID83479 does the same with the original IPC helper present. No unsupported-boundary marker fires and the helper receives no path request during that direct connection test. The temporary helper was stopped and its service disappearance verified.

Stronger control without any Simulator Steam IPC service: nativePID83585 and SimulatorPID83591 both obtain the real SteamUser021 interface, report BLoggedOn1 and release their own user/pipe successfully. Actual discovery immediately beforehand returns1102 in Simulator. Thus client-library connection can reach the existing host Steam session independently of the SDK's failed Mach path-discovery step. This does not prove the underlying transport mechanism, game ownership, ticket authentication, original-game SteamAPI_Init, or multiplayer. It is host-assisted Simulator evidence; it does not solve a standalone physical iPad's Steam-client requirement.

Evidence generated/mac-de-simulator-283/result.json, native and Simulator session logs, no-helper discovery, helper lifecycle/cleanup and actual PIDs. No installed game replacement, host client modification, reference modification or account switching. All controls exited and released their own connections. Next investigate a narrow transport of genuine host Steam discovery replies to the Simulator SDK, preserving real authentication and client results; map verified client library loading to the prepared representation. Porting the full Steam UI is no longer the immediate Simulator prerequisite. Original engine still stops at GetSteamPath until that integration is tested; no game menu/FPS/touch/multiplayer proof.

## Real client library loads and SteamClient020 factory executes282

Previous281 was progress: actual GetSteamPath replies confirmed missing client registration. Prepared private Simulator representations of all seven real client-chain images, with every original file-backed section verified equal. Direct loadPID82180 fails at absent DiskArbitration. Initial explicit missing-framework diagnostics move the loader to absent AEBuildAppleEvent in the existing Simulator CoreServices framework.

Performed a current Simulator export survey for the client-chain imports. It identifies38 missing exports after excluding the dyld-internal binder:13 across absent desktop frameworks,7 in CoreServices and18 in CoreGraphics. The earlier SDK-file audit therefore understated API gaps in frameworks that exist. Read three actual public Mac string constants through HostConstants; no NULL data substitutes used. Added a dedicated diagnostic builder: missing functions exit78 on use, missing classes are diagnostic classes, and present APIs are reexported from their actual framework. Empty imported-framework facades are only load diagnostics, not compatibility implementations.

With those boundaries, original steamclient.dylib and its dependent constructors load successfully in actual SimulatorPID83001. A subsequent separate controlPID83074 calls the library's real CreateInterface("SteamClient020", &status); it returns a nonnull interface and status0, with no unsupported-boundary marker. Factory ABI follows Valve's [published interface convention](https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/public/tier1/interface.h); the interface string also exists in the supplied game SDK. This proves load and factory execution only. It does not create a Steam pipe, register a running client, authenticate, initialize the game's SDK, or reach game startup.

Evidence generated/mac-de-simulator-282/result.json, exactPID loader/factory logs, symbol request/survey, measured public constants and section manifests. Source tools: scripts/build-de-steam-client-boundary.py, port/de/LibrarySymbolSurvey.m, port/de/SteamClientLoadProbe.c. The sole designated Simulator was reused; no installed app replacement, host Steam modification or service registration. All diagnostic processes exited. Next follow real connection/pipe initialization in a bounded control and keep the original engine's genuine GetSteamPath barrier explicit. Game menus/FPS/touch/multiplayer remain unproved.

## Genuine IPC replies confirm absent client registration281

Previous280 was progress: the original game reached the real Simulator IPC service. Fresh native SDK control still initializes successfully and loads the installed original steamclient.dylib, libtier0_s.dylib and libvstdlib_s.dylib. Logs retain only selected library paths and SDK status, not account data.

Offline helper dispatch inspection identifies separate path registration and retrieval operations. Added opt-in message tracing (environment name AGEPAD_IPC_TRACE) to IPCSystemCompat.c around real mach_msg, preserving arguments, results and errno. It logs only the two operation numbers, message sizes and whether reply PID/path fields are nonempty. Original helper code/data remain unchanged. There is no synthetic registration or replacement protocol response.

Executed helperPID79726 and original-gamePID79742 in the sole designated Simulator. Three GetSteamPath requests (opcode14,32bytes) receive actual544byte replies with pid_present0 and path_present0. No registration operation13 was observed. Game again reports GetSteamPath failure and aborts. Therefore the current failure is an empty registered-client response, not missing service discovery or absent message transport. The bounded runner terminated its exact temporary helper in finally; process gone and service absent verified. No second Simulator, account changes, reference changes, or game app replacement.

Audited the seven real vendor libraries in the native client dependency chain. The52MB universal steamclient.dylib links desktop-only AppKit, Carbon, DiskArbitration, OpenGL, IOBluetooth and ApplicationServices libraries absent from the Simulator SDK. Its supporting libraries also involve Cocoa and Carbon. SDK path presence alone does not establish compatible exports/behavior for the other frameworks. Excluded dylib install IDs from dependency traversal. This is an import/dependency audit, not evidence those libraries execute in Simulator.

Evidence generated/mac-de-simulator-281/result.json; traced-game/ actual request/reply logs, launch and cleanup records and exactPID crash; native-sdk-client-load.log; client-dependency-audit.json; private dispatch notes. Next qualify the real client component dependencies and legitimate registration route. Empty client state must not be replaced with a pretend PID/path or forced SDK result. Menus, gameplay, FPS, touch and multiplayer remain unproved.

## Real Steam IPC helper runs in Simulator; next failure is GetSteamPath280

The previous turn was progress: it ruled out ordinary host task-port inspection. This turn tested current, per-user, root and kernel bootstrap discovery in tiny native controls and the designated Simulator. All four host routes find Steam; all four Simulator routes return1102. Host lookup of the named CoreSimulator service succeeds, but bootstrap queries through that port return112. A native host probe launched via simctl returns5. These direct namespace shortcuts are not fixes as tested. Apple’s historical [libbootstrap implementation](https://raw.githubusercontent.com/apple-oss-distributions/launchd/main/liblaunch/libbootstrap.c) informed the read-only API probes; current runtime results are authoritative.

Moved to the actual installed Steam ipcserver helper. Its ARM64 imports are entirely libSystem/libc++; CoreServices has no imported functions. Created a private Simulator representation with every file-backed original section preserved. The unused CoreServices dependency maps to CoreFoundation; the libSystem dependency maps to a reexport adapter that forwards the missing syslog$DARWIN_EXTSN spelling to real vsyslog, preserving errno. An earlier libSystem duplicate dependency was rejected by dyld; without the logging adapter the helper null-called at the syslog stub (actualPID74833, original return offset7004). No IPC or Steam API success is substituted.

With the logging adapter, original helperPID75300 runs and exposes the real Steam service inside Simulator. The initial simctl observer timed out after15s; ps confirmed the child was still live, and that exact process was reused without restart. Original-gamePID75459 then records service_found1 and verified real SDK loaded1. Its genuine initialization error changes from ipcserver init failed to ipcserver GetSteamPath failed, followed by SIGABRT. This proves the namespace discovery/service stage advanced; the helper alone does not supply a registered running Steam client. No menu/gameplay, FPS, touch, authentication or multiplayer is proved.

The temporary helper was terminated in finally after the game test. Verified process gone, Simulator service absent again, host Steam service still present. No launchd job was installed, no host Steam files/account state changed, and the installed DE diagnostic was reused. Evidence: generated/mac-de-simulator-280/result.json, game-with-ipc/ exactPID logs/crash, discovery controls, helper crash and section-preservation manifests. Reproduction builder: scripts/build-de-ipc-helper.py ORIGINAL_IPCSERVER NEW_PRIVATE_DIRECTORY; it only prepares files and never starts a service.

Next follow genuine client registration/GetSteamPath and subsequent SDK client-library loading. Determine whether the real client component can initialize in Simulator, or whether an explicit Simulator-only transport can carry real host responses. Do not populate a pretend running-client registry or force successful Steam initialization. A host-assisted diagnostic remains distinct from the final locally running iPad requirement.

## Simulator Steam namespace capability test279

Rebuilt and installed only the DE diagnostic in the sole designated Simulator. Original engine PID68400 reached the verified SDK loader. Before the real load, an opt-in diagnostic paused its own process and performed read-only service discovery. Host lookup finds the genuine Steam service; the Simulator and its reachable parent return 1102. This confirms the earlier isolated namespace observation within the current original-engine process.

A native host helper attempted task_for_pid on that exact paused diagnostic PID and received KERN_FAILURE (5), so it could not inspect the process bootstrap port. The runner resumed the diagnostic in a finally block. Real SDK load then succeeded, genuine Steam initialization failed with IPC/client-discovery errors, and the game aborted. No service registration, Steam account state, original reference files, or other installed app was changed. This rejects the ordinary host task-port inspection route as tested; it does not establish that all IPC approaches are impossible.

Evidence: generated/mac-de-simulator-279/result.json and run/ (actual PID, pause state, helper result, resumed logs and crash). Gameplay, FPS, touch and multiplayer remain unproved. The next discriminator is whether an explicit Simulator-only transport or co-located real client can provide genuine discovery/IPC, with no fabricated SDK results. Host assistance would remain a Simulator diagnostic dependency, not physical-iPad acceptance.

Apple documents Simulator as having a separate launchd and Mach bootstrap namespace: [Getting the Most Out of Simulator, WWDC 2019](https://devstreaming-cdn.apple.com/videos/wwdc/2019/418o9bbtoe880sauh/418/418_getting_the_most_out_of_simulator.pdf). Local simctl help confirms spawn --standalone uses a NULL bootstrap port; that option cannot supply host Steam services and is not a promising fix.

## Original engine reaches genuine Steam initialization278

Previous277 isolated original-file acceptance from dyld platform rejection. Added compile/runtime-opt-in SteamModuleCompat.m for one exact absolute SDK path. It validates SHA256 of the untouched original sidecar and its generated Simulator representation before calling real dlopen on that representation. Representation generated afresh from the supplied ARM64 slice; every file-backed section matches. File reads/validation continue to see the original file. No Steam API methods, ownership checks or initialization results are fabricated. Broader caller-relative loader semantics and device packaging are still unqualified; this stays experimental.

Same-app controlled runs: disabledPID67008 reproduces original null fault314152. EnabledPID67063 logs verified=1 loaded=1, reaches actual SteamAPI_Init, reports IPC/client discovery failure, then SIGABRT. This advances the original engine past the longstanding null-handle failure but does not reach gameplay. Real macOS SDK control against the running host Steam client succeeds (initialized=true), shutting down only the probe's SDK connection. Host Steam process is present; Simulator cannot discover it through its current route.

Next investigate current Simulator discovery/bootstrap namespace and legitimate client IPC, preserving real SDK results. Physical hardware remains deferred by user; no streaming or device success inferred. Evidence generated/mac-de-simulator-278/result.json, both exactPID crash reports, representation.json and host-steam-control. Corrected277's overly broad platform-error flag so OriginalEngine's separate diagnostic mismatch is not attributed to SDK loads. Gameplay, FPS, touch and multiplayer remain unproved.


## Original SDK reaches dyld; retargeted SDK rejected before load277

Previous276 resolved missing-file placement but handle remained null. File tracing now covers actual fopen$DARWIN_EXTSN and fread for the Steam stream, clearing tracking at fclose. ActualPID60657 opens and reads all196912 bytes of the retargeted/thinned SDK with ferror0. Stale errno2 after successful fread is not a read failure.

Controlled same-installation tests use dyld's own DYLD_PRINT_APIS rather than loader interposition. RetargetedSDK PID61026 reads successfully, never attempts Steam dlopen, and crashes314152. Replaced only the diagnostic UUID sidecar with an untouched copy of the supplied original SDK (reference unchanged). PID61110 reads all412160 bytes, calls dlopen on that SDK, and dyld explicitly rejects its macOS platform. Handle remains null; original crash314152 follows. Current installed sidecar is this original-library control.

This establishes distinct pre-load file-acceptance and platform-loader barriers. It does not yet identify whether thinning, metadata/signature changes or another transformation caused the pre-load rejection. No authentication result is inferred. Next evaluate an exact-module compatibility loader based on the verified original SDK and unchanged code/data sections; keep real original-file validation and genuine SDK execution, do not fabricate acceptance/Steam success. Evidence generated/mac-de-simulator-277/result.json, all exactPID crashes, dyld logs and hashed sidecar manifests. No gameplay/FPS/multiplayer proof.


## Actual library path found; placement alone insufficient276

Previous275 located conditional Ice loading. Decoded original path constant libsteam_api.dylib and followed file-read helpers. Added compile-opt-in --file-trace (stat/access/plain fopen) preserving real file queries/results/errno. SimulatorPID58706 records stat ENOENT at the sibling Frameworks/libsteam_api.dylib beside DEProbe.app within its installation UUID, not inside the app. This explains why inside-app placement did not satisfy this particular query.

Thinned supplied real Steam library to ARM64 and retargeted metadata with all file-backed original sections verified unchanged. Staged it only at that exact diagnostic-owned sibling path; no original ref/Steam client files changed. Relaunched same installed candidate without reinstalling/changing its UUID. PID60161 stat succeeds twice, but handle remains zero and original null crash314152 persists. Path correction is not a complete fix. This is Simulator-only sidecar placement, not a device packaging solution.

Offline platform file-open helper0x259484 uses fopen$DARWIN_EXTSN at0x2594f8; the plain fopen diagnostic does not intercept that variant. Next trace this actual file-open/read result before inferring library validation failure. Evidence generated/mac-de-simulator-276/result.json, both exactPID crashes, library-name-constant.json, steam-library.json and run-path-fixed/launch.json identifying sidecar. No gameplay/FPS/multiplayer proof.


## Linker initialization and Security caller map275

Previous274 confirmed null library handle in traced/control runs. Located original IceLinkerDynamic constructors by decoding references to its original vtable; both initialize object+8 to zero. Located9 direct dlopen call sites; the relevant Ice routine0x2445c stores dlopen's return in object+8 at0x2460c, but condition0x245ec can skip the call. Its path-building/status helpers are the next discriminator.

Added opt-in AGEPAD_MAC_SECURITY_CALLERS stack-address logging after actual SecCodeCopySelf returns. Actual SimulatorPID53193 records12 calls from original0x55a274. Disassembly0x55a198 shows a self-validation helper: failing SecCodeCopySelf skips code-object conversion, leaves validation false. This is real platform failure, not yet proof that it prevents the Ice library open. Return values/output objects remain untouched. Original null crash314152 and empty handle persist. No loader interposition in this run.

Evidence generated/mac-de-simulator-275/result.json, constructor.txt, security-path.txt, library-open.txt and exactPID crash. Next trace required library path/status before its conditional dlopen. Do not merge the Security and library-load hypotheses without a demonstrated dependency. Original-game input untouched; designated Simulator only. Gameplay, FPS and multiplayer remain unproved.


## Missing dynamic-library handle verified274

Previous273 was progress: fatal snapshot identified actual override dispatch. Full original0x302d4 disassembly shows lookup obtains a dynamic-library handle from object+8, resolves an export with dlsym, and only calls it when both export and handle are nonnull. Decoded original vtable/typeinfo identifies IceLinkerDynamic. Runtime fatal snapshot now includes object+8.

Added diagnostic loader interposition, then identified its caller-relative lookup limitation: wrappers can change RTLD_NEXT and relative-path semantics. Restricted it to explicit build flag --loader-trace (off by default) and ran a control without any __interpose section. TracedPID50016 and controlPID50315 both have library_handle=0, target0x302d4 and original null fault314152. Thus the missing handle is not an artifact of loader interposition. The traced run shows no Steam dlopen before the fault, but exact original library-selection intent remains to be established.

Evidence generated/mac-de-simulator-274/result.json, lookup-full.txt and both exactPID crash reports. Control is current diagnostic app. Next identify IceLinkerDynamic initialization, required library path and API outcomes; do not fake a nonnull handle or validation/authentication success. Original-game resources/instructions unchanged; only designated Simulator used. No gameplay/FPS/multiplayer proof.


## Fault-time dispatch identified273

Previous272 produced an earlier read-only dispatch snapshot. Actual hardware-breakpoint retry273 reached neither lookup breakpoint and exited45, matching earlier software-breakpoint behavior; debugger attachment is not proof of the ordinary failure's cause. Do not spend more identical debugger-startup retries.

Added opt-in AGEPAD_MAC_FATAL_CONTEXT_TRACE to ContextDispatchTrace.h. It snapshots known audited image slots using read-only VM reads and fixed-buffer writes, then restores previous signal disposition and returns to the unchanged faulting instruction. It uses no fabricated SDK/validation results. This is a diagnostic, not a compatibility fix. Candidate rebuilt and copied to generated/mac-de-simulator-273/DEProbe.app; previous272 app path was used as build scratch, so older272 logs remain historical evidence rather than identifying that mutable app path.

Actual PID49376 fatal snapshot shows override present, fallback also present, nonnull symbol argument, target originaloffset0x302d4. After restoring signal handling, exactPID crash report still shows null fault at314152. Earlier272 snapshot had no override and target0x44040. This proves dispatch state changes during startup; it does not yet explain the null result. Captured original0x302d4 disassembly begins a substantially different lookup implementation. Next follow this implementation and its initialization dependencies, preserving actual validation/authentication semantics. Evidence generated/mac-de-simulator-273/result.json, debugger.log, run-fatal/crash.ips and actual-lookup-disassembly.txt. No gameplay/FPS/multiplayer proof.


## Simulator dispatch investigation272

Previous271 was progress: native/AppKit comparison and actual original-engine notification experiment ruled out notifications as a sufficient fix. Current offline disassembly shows crash314152 dereferences x0 immediately after a virtual lookup at slot0x1a8. The fallback constructor sets a table whose slot points to0x44040; that implementation returns argument+16, not an unconditional null. No original instructions changed.

Added opt-in read-only ContextDispatchTrace.h at the NSRunningApplication query. Initial compile failed because mach_vm.h is unsupported in the Simulator SDK; using supported vm_read_overwrite resolved it. Fresh candidate272 builds, stages653 resources and runs in the sole designated Simulator. PID48113 snapshot: all reads succeed, override absent, fallback present, symbol argument nonnull, target originaloffset0x44040. Later crash remains null read314152. This earlier snapshot cannot establish which dispatch target/input was used at the exact failing call. Do not claim SteamAPI_Init caused the crash based on this result.

Evidence: generated/mac-de-simulator-272/result.json, disassemblies, run/stderr.log and exactPID crash. Next capture dispatch and argument at the failing original call or the intervening initialization transition. Diagnostic stays opt-in; no SDK results fabricated and no authentication bypass. No gameplay/FPS/device/multiplayer proof.


## Active Simulator goal iteration271

User explicitly requested the supplied-Mac Simulator goal loop. DE-GOAL-LOOP.md is authoritative for current priorities; Windows and device-first work are parked. The goal API refused a replacement because the earlier blocked goal is unfinished; no false completion was issued.

Measured native AppKit with HostLaunchLifecycleProbe.m. finishLaunching alone did not deliver did-finish even with NSRunLoop pumping; actual NSApplication.run delivered will/did delegate callbacks and matching notifications. Added opt-in AGEPAD_MAC_LAUNCH_NOTIFICATIONS to the UIKit adapter. First actual Simulator run hit the adapter's diagnostic resolver while checking the optional will-finish method. Corrected that optional lookup using declared method lists, avoiding resolver side effects.

Rebuilt/reran original engine in the sole designated Simulator. PID29482 logged both launch notifications and the original did-finish callback return, then crashed at original offset314152 with null read, same as270. Notifications alone are not a sufficient fix. Opt-in remains off by default. Evidence: generated/mac-de-simulator-271/result.json, host-lifecycle-app-run.log and run-fixed/crash.ips. No game frame/FPS/multiplayer pass. Next inspect original Steam-context setup and why the weak callback/context storage is null at this point, with actual SDK results preserved. Physical hardware is not a prerequisite.


**User correction, 9 September (mac-de-simulator-270): Simulator first using the supplied Mac DE build.** The AoE2DE input is present; it is macOS ARM64 version1.1.2. The Windows runtime requires a separate Windows input, but that absence does not block further supplied-Mac Simulator investigation. Physical-device work is deferred by the user.

Fresh candidate270 was built from the supplied original executable, with653 verified resource copies, and run in the sole designated Simulator. Original65 classes register and original launch callback returns, then PID9532 crashes with a null read at original image offset314152, matching the historical failure. No gameplay/menu/FPS success. Current evidence: generated/mac-de-simulator-270/result.json and run/crash.ips. Next investigate launch lifecycle/Steam startup ordering without inventing SDK/authentication success. This is a Mac compatibility route; Windows runtime packaging remains separate.


**Active Windows implementation checkpoint:** [WINDOWS-DE-STATUS.md](WINDOWS-DE-STATUS.md). CPU x64 arithmetic and DXMT shader drawing now pass separate Simulator component tests; full native runtime builds and its diagnostic shell opens. Windows DE and multiplayer do not run yet. Historical Mac evidence follows.

Active objective: [DE-GOAL-LOOP.md](DE-GOAL-LOOP.md). This replaces the classic-first priority for the current task. The original-engine iPad/multiplayer goal remains incomplete. The earlier blocked checkpoint is revised by the 8 September research below: new local experiments are available, although no runtime gate advanced.

## Research revision — 8 September 2026

Follow-up constraint: local execution only, without a publisher-backed port. New Windows-route research found UTM 5.0.5 iOS DirectX 11 support and Madeira's single-process iOS Wine/FEX/DXMT implementation. The proposed qualification sequence prioritizes real Steam login and an actual Windows DE multiplayer match: [DE-LOCAL-WINDOWS-NEXT.md](DE-LOCAL-WINDOWS-NEXT.md). These upstream capabilities have not been reproduced here; no runtime gate advanced. The previous July-blog-only characterization of UTM's iOS graphics work was stale.

The earlier blocked checkpoint is historical, not proof that engine source is mandatory. Deep research identifies new executable experiments. The runtime goal is still incomplete; no new game launch or multiplayer pass occurred in this research.

- Apple's documented `SecCodeCopySelf` behavior does not require signed code. Published Security `Code.cpp`, pinned at `db15acbe6a7f257a859ad9a3bb86097bfe0679d9`, places `autoLocateGuest` implementation under `TARGET_OS_OSX` and falls through to `errSecCSNoSuchCode` otherwise. This strongly explains the observed -67065 as platform behavior; the exact Simulator binary has not been matched to that source. A certificate is **not** the prerequisite for further Simulator investigation. Actual later validation requirements remain real and separate.
- `AppLifecycleCompat.m` directly invokes the launch delegate but omits AppKit's normal launch notification broadcasts. The original dyld trace has no Steam-library load before the crash. Compare real native initialization with the adapter before attributing the current original-engine crash solely to the isolated SDK failure. A lifecycle defect is a hypothesis, not a proven fix.
- New read-only official PlayFab audit: version1.10.25 XCFramework device and Simulator ARM64 slices each export all157 `_Party*` C functions imported by the engine. The supplied Mac library contains version string1.10.22. Name coverage is verified; ABI layouts, callback lifetimes, version behavior and retail authorization remain untested. Evidence: `docs/artifacts/2026-09-08/deep-research/party-export-audit.json`.
- A narrow real-result Mac Steam helper is a diagnostic option; it would remain Mac-dependent. The genuine announced Mac App Store edition is a separate potential input; no current build/listing was verified, and Calico's general Mac FAQ excludes Steam cross-store play. Do not assume an alternate build preserves the Steam peer cohort.

Priority: differential startup → faithful identity semantics → mobile Party ABI qualification → narrowly scoped service isolation if original startup actually reaches it. Add early device loading/shader tests when hardware/signing are available; retain the Simulator gameplay milestone and all final acceptance gates. Full report: `output/pdf/agepad-de-feasibility-research.pdf`.

Sources: [Apple identity API](https://developer.apple.com/documentation/security/seccodecopyself%28_%3A_%3A%29), [Apple Security source](https://github.com/apple-oss-distributions/Security/blob/db15acbe6a7f257a859ad9a3bb86097bfe0679d9/OSX/libsecurity_codesigning/lib/Code.cpp), [AppKit lifecycle](https://developer.apple.com/documentation/appkit/nsapplication?language=objc), [PlayFab releases](https://github.com/PlayFab/PlayFabParty/releases), [Feral Calico](https://www.feralinteractive.com/en/accounts/faqs/).

## Input

Supplied Mac build: version 1.1.2, bundle build 478570.102902, ARM64, macOS minimum 13.4, SDK 26.1. Signature verification passes. Full input inventory: 24,936 file/symlink records, 20,011,062,362 regular-file bytes, seven Mach-O images, one standalone Metal library. The matching installed Steam executable has the same SHA-256 as the supplied executable. Exact hashes and complete dependencies remain in ignored `docs/artifacts/2026-09-07/de-001/audit.json`.

## Gates

- D0 input/environment: initial audit passed; only designated Simulator `574671AD-6F61-4558-9528-BF946DDB760A` is booted. Original classic app remains installed, process 30496 was preserved through the initial probes.
- D1 retail reference: actual main menu observed in fullscreen and normal windowed mode. Earlier black-window startup was resolved after disabling the Feral launcher's “Pause game on suspend” for automated observation. The fullscreen window rejects coordinate input through CUA (`noWindowsAvailable`). The supported “Run in a window” setting fixes window targeting, but CUA clicks/short drags move the visible pointer without activating the game's Single Player button. Native AppKit menus do work, including clean Quit and its confirmation. A user input request asks for a small AI skirmish to be started manually while independent adapter work continues. No AI match/FPS baseline yet.
- D2 original engine in Simulator: **bounded execution proof achieved; game startup incomplete**. Both library rehosting and the stronger arrangement using the original binary as the actual app executable now execute original ARM64 startup code in Simulator. All 65 original classes register; the original application constructs, its launch callback returns, and its delayed startup routine runs. The original executable's instruction/data sections remain unchanged. Missing APIs are still diagnostic traps; these results do not prove a functional compatibility layer or game launch. Direct unadapted load still rejects the macOS platform.
- D3–D7 actual Simulator game, FPS/touch, device, multiplayer and complete iPad usability: **open**. A loader probe is not the game, and no gameplay FPS has been measured.

## Experiments completed

| Evidence directory | Result |
|---|---|
| de-001 | Read-only complete bundle/data audit, valid signature, native startup sample; original executable rejected by Simulator as incompatible platform. Original `feral.metallib` loads and exposes 18 functions, which alone does not prove executable GPU pipelines. |
| de-002 | Isolated Mach-O metadata adaptation reaches missing AudioUnit framework. Initial signature-command removal left an awkward linkedit layout; corrected in subsequent packaging. |
| de-003 | Direct AudioUnit→AudioToolbox path alias is rejected as a duplicate linked library. Preserving dependency ordinal through a separately built reexport image is required. |
| de-004 | AudioUnit reexport resolves that loader boundary; Carbon is next. Direct Simulator framework/import survey starts. |
| de-005 | Combined engine/vendor survey: 63 system-library paths, 158 unresolved imported symbols. This excludes dynamic Objective-C selector compatibility and is not an estimate of total implementation effort. The original Mac library fails actual compute-pipeline creation: “library was not compiled for the simulator.” All 46 binary sections unchanged. |
| de-006 | Apple's metal-objdump extracts 18 IR modules. Recompiling unedited IR for iOS 15 fails AIR-version compatibility; targeting iOS 16 preserves AIR 2.5 and links successfully. Simulator and device libraries built. Simulator successfully compiles the original fill pipeline and executes the original copy kernel at 1/63/64/65/4096 bytes; exact output and 16-byte guards pass in all cases. Full engine/rendering remains unproven. |
| de-007 | The metadata-packaged executable loads as a library against real macOS APIs; 65 classes register. Runtime inventory identifies original application, window, input view and Metal view. No game main call in this host test. |
| de-008 | Fail-fast Simulator adapters reexport available system APIs and stop at missing function/class usage. The engine and vendor libraries load; all 65 game classes register in Simulator. Unimplemented data exports remain diagnostic NULLs in this initial candidate. |
| de-009 | Original entry point (file offset 77120) executes inside the Simulator; the first missing startup call is `NSApplicationMain`, with an original-engine backtrace. The diagnostic exits deliberately. |
| de-010 | A UIKit application-state adapter constructs the original `CFeralNSApplication`. A separate native NSNib test confirms the supplied launch nib wires the application as its own delegate and contains desktop menus. Nib loading uses the current data initializer after the deprecated URL initializer throws. Public string-constant inspection exposed an overbroad suffix classification of `SecTransformSetAttribute`; fixed to a function trap. No invocation of that API occurred in the Simulator tests. |
| de-011–013 | Original launch callback advances through optional Dock chrome and workspace notification registration. UIKit state/notification adapters implemented; 31 public Mac string constants read and reproduced accurately. Callback returns, but calling it without the original entry preamble does not start the game. |
| de-014–018 | Original entry hands off to UIKit. Delayed original startup reaches screen enumeration, display reconfiguration, gamma capability and running-app queries. Screen wrappers use actual UIScreen objects; real post-change notification callbacks are registered; unsupported gamma tables report zero capacity/not-implemented errors. Running-app query identified as the current probe bundle, not Steam. NSColor diagnostic symbol aliases avoid a collision with UIKit's private class. An early assembly alias failed to link; the successful candidate uses linker aliases. Incomplete-build markers and a checked Simulator runner prevent stale/failed candidates from being mistaken for completed builds. |
| de-019–020 | Current-app query uses the real PID/bundle. Original engine now faults on a null return at image offset 314152. A dyld API trace records no Steam-library load attempt. No game frame is produced. |
| de-021 | Original binary becomes the actual Simulator executable, retaining LC_MAIN/MH_EXECUTE with adapted platform/dependencies. This stronger arrangement also reaches the same null-pointer crash, ruling out library rehosting as the sole cause. |
| de-022 | 653 supplied configuration/resource files (32,741,272 bytes) copied and byte-verified at the iOS NSBundle resource root. Genuine Feral metadata copied, probe identity retained, and the verified rebuilt helper shader installed under the original resource name. Large adjacent game-data directory is not yet staged. Same crash remains. |
| de-023 | Debugger attaches to the Simulator executable, but the process exits with status 45 before the intended breakpoint. Cause not established; no guard was patched. Offline Mach-O fixup decoding identifies the queried weak symbol as `SteamUtils()`'s callback/context storage, narrowing the failed lookup to Steam integration. |
| de-024 | Original retargeted Steam library placed at `Frameworks/libsteam_api.dylib`, with all 12 file-backed library sections verified unchanged. Placement alone does not resolve the original-engine crash. |
| de-025 | Isolated real Steam SDK test in Simulator: library load succeeds; actual `SteamAPI_Init()` returns false. SDK logs IPC initialization failure, no running Steam instance and no client install directory. Genuine game App ID 813780 supplied using Valve's documented development hint. No authentication result is fabricated. Actual diagnostic screenshot captured. |
| de-026 | macOS control with the same supplied SDK and genuine App ID: actual initialization succeeds against the installed Steam client. Only this test's SDK connection is shut down. This isolates a Simulator discovery/IPC boundary rather than a general failure of the host Steam setup. |
| de-027 | Reusable isolated-SDK builder compiles and signs a fresh candidate from the supplied inputs. Runtime result remains the already observed de-025 test; this build alone is not another runtime pass. |
| de-028 | Read-only Mach bootstrap discovery: host finds the real `com.valvesoftware.steam.ipctool` service; Simulator and its reachable parent return 1102 (unknown service). No bootstrap namespace or service registration changes made. Real Steam initialization remains false. |
| de-029 | Read-only audit of the installed ARM64 Steam client confirms additional macOS framework and sibling-library dependencies. Finding the service alone would not establish a working iPad Steam client. No client binaries retargeted in this experiment. |
| de-030 | Original executable with result-preserving Security API tracing reaches the same crash. Twelve actual `SecCodeCopySelf` calls return -67065 (no guest with requested attributes). This is not proof of an invalid signature or the sole crash cause. |
| de-031 | Native macOS Security APIs successfully locate and validate the live Simulator diagnostic process: dynamic and static checks return zero. No validation result changed. |
| de-032 | Inside Simulator, real self lookup returns -67065, static object creation succeeds, static validation returns -66996 (valid signature, signer not trusted), and actual task creation and read-only code-status query succeed. Steam initialization remains false. Dynamic process validation and static file validation are not interchangeable. |
| de-033 | Read-only signing-identity inventory finds zero valid code-signing identities. A genuine development-signed test needs an identity/build not currently available. It would test a hypothesis, not resolve Steam discovery or establish native iPad compatibility. |

Current reproducible probe source: `port/de/LoaderProbe.m`. Builder: `scripts/build-de-loader-probe.py`. Metadata adapter: `scripts/prepare-de-load-image.py`. Shader rebuilder: `scripts/rebuild-de-shaders.py`. Input auditor: `scripts/audit-de-bundle.py`. The probe uses bundle identifier `local.agepad.de-loader-probe`; it does not replace `local.agepad.ipad-probe`.

Last verified processes: visible Simulator Steam/code-identity diagnostic candidate032 PID55611; original classic AgePad PID30496 still present; Mac retail reference PID44101 still present, copied app in `generated/de-native-reference` with adjacent supplied data linked read-only by convention. Its last observed UI was the main menu; no new Mac UI observation at this checkpoint. No original game binaries were modified. Avoid changing that data link during a running reference. The earlier manual skirmish-start request remains unanswered. Feral observation settings were Run in a window enabled, Pause game on suspend disabled, and automatic crash/statistics uploads disabled. These are per-game reference settings, not iPad product behavior. Only the designated Simulator remains booted.

Validation at this checkpoint: all eight DE Python scripts compile; source diff whitespace check passes. The boundary builder verifies 187 original file-backed sections across seven images after metadata adaptation/signing. The separately packaged Steam library verifies 12 sections. All five original copy-kernel GPU cases also pass in the actual-original-executable candidate021. Original-executable and isolated SDK probes are distinct from gameplay. Candidate025's screenshot was inspected: it shows the SDK diagnostic failure, not the game.

## Current causal boundary

The strongest current game candidate is `generated/DELoaderProbe030.app` (candidate024 plus result-preserving Security tracing): actual original executable, initial UIKit adapters, supplied configuration resources and a retargeted Steam library. It still crashes at the same null Steam-context lookup before a game frame. The real SDK loads but cannot initialize inside Simulator, while the macOS control succeeds. The real Steam Mach service is discoverable on the host but not from the Simulator bootstrap namespace or its reachable parent. Original startup also encounters failed Mac-style code-identity lookup inside Simulator. These are separate observed boundaries; neither is established as the sole cause, and resolving either alone would not prove game launch.

Valve documents that Steam API initialization must succeed before interface access and requires a running licensed Steam client. Its `steam_appid.txt` development hint identifies the real game; it does not replace the client or ownership check. [Steamworks API overview](https://partner.steamgames.com/doc/sdk/api)

Simulator access to a host Steam client, if made to work through legitimate interfaces, would still not prove a standalone physical-iPad solution. Do not silently replace the native-iPad objective with a Mac-dependent product, streaming, or successful service stubs.

The installed iOS Simulator SDK does not expose `SecCode.h` or `SecStaticCode.h` among its public Security headers, although this diagnostic can dynamically resolve implementations. Availability of those implementation symbols is not a supported device-port contract. Do not substitute host-only validation success or a file-only validation for the original live-process check.

A request for engine-source/developer-build access and a request for a genuine development-signing identity are pending. Source access is not assumed. No identity, trust configuration, signed Feral feature configuration, ownership check, or service return has been changed. The source-backed port remains the credible route to replacing desktop platform integration while retaining the actual game engine; this retail-binary experiment has not established that route without developer cooperation.

## Next causal work

1. Finish the now-working windowed Mac reference: ordinary AI skirmish, actual input and rendering observations, save, and a measured baseline. Keep suspend behavior/window changes explicit; no unsaved game existed during startup retries.
2. Investigate the real Steam client-discovery/IPC boundary and Feral's original SDK startup order, using the successful native control and failed Simulator result. Prefer supported configuration and actual service results. Do not patch authentication/ownership checks or fabricate SDK interfaces. Change hypothesis based on evidence rather than continuing speculative UI adapters behind this failure.
3. Integrate the rebuilt shaders at the original engine's real graphics boundary. Kernel equivalence does not certify every shader or runtime-compiled game shader.
4. Move to original-engine Simulator game execution, then touch/FPS and physical-device work. Maintain separate Mac-only and Windows/console multiplayer claims.

Reproduction recipes: [DE-REPRODUCE.md](DE-REPRODUCE.md). The goal remains incomplete; D3–D7 remain open.

## Research checked

- [Apple: Metal tools and IR/library compilation](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Dev-Technique/Dev-Technique.html)
- [Apple: Metal in Simulator](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator)
- [Official DE Mac multiplayer scope](https://support.ageofempires.com/hc/en-us/articles/360050470032-Age-of-Empires-II-Definitive-Edition-coming-to-Mac)
- [maciOS](https://github.com/stossy11/maciOS), inspected at c4178a5e408357ecdd8e2ef4e16f4a67b5dc0fc2 in ignored `worktrees/macios-audit`: incomplete AppKit implementation, with 19 directly imported game AppKit classes lacking implementations in the inspected source. Modal behavior includes immediate success returns, so it cannot be used as evidence of compatible game behavior. No source from it has been incorporated into AgePad.
- [Virtual Mac on iPad](https://github.com/nfzerox/VirtualMacOniPad): restricted old-OS/device virtualization route; not selected for the current Simulator/current-iPad goal.

## Blocked audit — continuation after de-033

Previous turn classification: progress (new platform evidence and its recorded interpretation), without resolving the desktop-service boundary. That same boundary persisted through three consecutive goal turns: real Steam SDK host/Simulator comparison, Mach discovery and Security diagnostics, and this revalidation. The signing-identity inventory is still empty; the original Mac reference and Simulator diagnostic processes remain alive. This is not a wait for an active build or background job.

The Mac reference was re-observed using CUA: actual main menu remains visible. Click plus Return, then raising the window and double-clicking Single Player, did not navigate into a match. No baseline match, new game frame in Simulator, or gameplay FPS measurement resulted. No Simulator candidate was replaced and no unsaved scenario was restarted in this continuation.

Blocked rather than complete: the supplied retail build still fails before a Simulator game frame, real Steam initialization is false, and Mac code-identity calls fail. No faithful working implementation route past these observed boundaries has been established with available inputs. A source/developer build allowing supported replacement of desktop integration would enable a materially different route. A genuine development-signing identity would enable only a narrower diagnostic; it is not a promised solution to Steam or device execution. Manual native-match input would unblock the independent reference measurement, not the iPad goal. Pending user input has not been treated as approval or as a completed experiment.

Resume when one of these inputs or an evidenced platform route becomes available. Preserve the complete D0–D7 objective; do not substitute streaming, the classic engine, synthetic FPS, or service-success stubs.
