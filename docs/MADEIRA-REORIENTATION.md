# Reorientation: actual DE in the iPad Simulator

2026-09-11 (America/Chicago).

## Research and route decision

[Madeira](https://github.com/willfaust/Madeira) documents Wine ARM64EC,
FEX x86-64 translation and DXMT in a single iOS process. Its current README
reports Thumper and ULTRAKILL playable, with less reliable Marvel Cosmic
Invasion gameplay. It does not list Cyberpunk as playable. The user-supplied
developer correction attributes that video to a separate native Mac-game route.
The project's [architecture analysis](https://github.com/willfaust/Madeira/blob/main/ARCHITECTURE_ANALYSIS.md)
describes the additional CPU, Windows API and graphics translation layers;
its projections are not proof that AoE or a full Steam client works.

For our supplied ARM64 Mac DE executable, the existing original-engine
AppKit/UIKit and Metal adaptation removes the need for x86 and DirectX
translation. It already reaches original gameplay. Continue this route for the
requested Simulator milestone. Preserve Windows/Madeira work, but do not spend
the Simulator critical path on CEF, child-bank allocation or FEX teardown.

The earlier freeaoe route requires completing substantial original simulation
behavior. Reaching its tutorial is not evidence that a complete AoE port exists.
The Windows route has separate Steam/browser/platform problems. Combining their
partial milestones has obscured the remaining work rather than finished a game.

## New reproducibility evidence

Only the designated iPad may run. At initial inventory none was booted. Opening
Simulator automatically restored its last-used iPhone; it was immediately shut
down before the designated iPad was booted. Inventory then confirmed only
574671AD-6F61-4558-9528-BF946DDB760A.

`generated/mac-de-simulator-375/reorientation-1` stopped at absent host Steam.
Starting the existing genuine host client restored discovery.
`reorientation-2` reached Steam initialization but aborted at GPU metadata:
the saved registry ID was 4294968172, while this boot's actual GPU is
4294968173. The exact-ID guard was correct; stale fixture metadata was wrong.

`run-de-game-relay.py` now builds/runs `HostDeviceMetadataSurvey.m` at each
launch, saves its result in the run directory, and passes that fresh path to
the adapter. No GPU feature or identity check was relaxed. `reorientation-3`
passed the matching guard, launcher, cinematic, menu, Single Player, Skirmish
and actual world. A normal tap selected the town center; production visibly
queued and completed (population 4/5 to 5/5). Four original AI opponents
continued scoring/exploring. This is genuine engine execution, with host Steam
services still required; it is not standalone physical-iPad acceptance.

## Touch boundary being corrected

The explicit Order control armed and reset, and emitted event types 3/4 with
button number 1. However, NSWindow sent them through mouseDown:/mouseUp:.
The supplied executable contains rightMouseDown:/rightMouseUp:/rightMouseDragged:
selectors. The dispatcher now selects those methods for secondary events,
preserving normal hit testing and responder-chain forwarding. Runtime logs now
include the selected method. `right-dispatch-1` now demonstrates actual visible
command acceptance: selecting the town center, tapping Order and ground at CUA
(523,404) places the original blue rally flag. Logs name CFeralNSWindow and
rightMouseDown:/rightMouseUp:. The subsequent villager completed production
(original notification and population 5/5). Selection of that unit at the flag
did not succeed, so movement is not yet accepted.

The same run disproves a coordinate-only explanation for menu misses. Identical
CUA (330,430) Skirmish taps map to root (443,514.5); identical (450,522) Start
Game taps map to (628.5,657). In each case the first tap hovered and the second
transitioned. Production (60,570) and Save Game (425,344) repeated the pattern.
Do not resume arbitrary neighboring-point calibration as if it established cause.

An opt-in `AGEPAD_TOUCH_MOVE_BEFORE_DOWN` experiment now queues a mouseMoved:
event at the actual touch point before the button event. NSWindow routes type5
through normal hit testing without changing its captured button-down target.
The isolated candidate `input-move-candidate.dylib` compiles, but is NOT installed
or runtime-qualified. Existing `right-dispatch-1` continues without this option.
No claim that the new sequence fixes the repeat-tap defect is justified yet.

At 21:25 local, computer use reported the Mac locked and automatic unlock failed.
An unlock request is pending. The exact current game PID10269 and helper10259
were revalidated live, and only the designated iPad is booted. Preserve the run
while waiting. Runner session97201 owns the one-hour observation/cleanup; after
that window, its helper is removed and the remaining game is not a valid soak.
After unlock, inspect the Save dialog first, preserve a save if possible, then
announce any restart before running the isolated input sequence experiment.

The post-lock raw Simulator screenshot confirms that the repeated Save Game tap
did open the original Save dialog. No new named save was submitted. The adjacent
30-second composition sample counted 1031 displayed completions and zero dropped
completions (34.37/s); this is menu composition, not gameplay FPS or device
performance. Evidence: `right-dispatch-1/checkpoint-locked.png` and
`right-dispatch-1/composition-30.json`. Python compile and AppKit candidate build
pass. Goal remains active; this is the first Mac-lock blocker turn in this run.

Remaining visible defects: narrow/inconsistent button acceptance, very dark
terrain, and unverified reliable unit movement/building/save/lifecycle behavior.
Do not call world rendering alone completion. Keep one live candidate and
finish a repeatable gameplay slice before expanding scope again.

## Locked-host continuation 2

Previous turn classified as progress (GPU survey repair, qualified right-button
rally command, identical-point input evidence). Computer use was retried and again
reported the Mac locked with automatic unlock unavailable. Exact PIDs10269/10259
remain live and only the designated iPad is booted. This is the second consecutive
turn encountering the same external blocker; goal remains active.

Independent audit of 24 paired left-button queue timing records found maximum
post-to-dequeue latency1.432ms. This does not support a long queue backlog as the
cause of the first-hover/second-activation pattern. Evidence is
`right-dispatch-1/input-queue-audit.json`; it does not prove downstream consumption.
Extended optional queue timing to event types1–7 so the next move/right-event run
can be evaluated rather than silently excluded. The opt-in move event now carries
zero click count and pressure, consistent with its non-button state. Isolated
`input-move-candidate.dylib` rebuild passes; no installation or restart occurred.
Next dependent action remains ordinary Save-dialog interaction after unlock,
then the measured move-before-down experiment on a fresh announced candidate.

## Locked-host continuation 3 — blocked

Previous turn classified as progress: input queue latency evidence narrowed the
hypothesis, and move/right timing coverage plus the isolated build were completed.
Current revalidation confirms game10269 and helper10259 live at approximately
19m45s, with only the designated iPad booted. CUA again reports the Mac locked and
automatic unlock unavailable. This is the third consecutive goal turn with the
same external blocker. The pending experiment is already compiled; further
speculative edits would outrun the required live input/rendering evidence.

Goal marked blocked, not complete. Unlock the Mac and resume to inspect/preserve
the Save dialog, then validate move-before-down and continue terrain, actual unit
commands, save/load and lifecycle work. Revalidate the runner/helper before use:
the one-hour runner eventually removes its helper. No process restart, install,
Simulator change or new acceptance claim was made during this audit.

## Resumed after lock diagnosis — 2026-09-12

See MAC-LOCK-DIAGNOSIS.md: authoritative loginwindow evidence identifies the
20-minute screen-saver idle timer, not an intentional lock command. Temporary
activity/display assertions remained effective beyond20minutes; permanent lock
settings unchanged. This removes the observed external blocker for resumed work.

move-before-down-1 reached the main menu, then original CFeralNSWindow forwarded
an unconsumed mouseMoved: to super, which our NSWindow adapter lacked. Added the
Apple-documented next-responder forwarding behavior. No fabricated game response.
The repaired move-before-down-2 PID55567/helper55557 (revalidate) then passed first
ordinary taps for Single Player(190,280), Skirmish(330,430), Start Game(450,522),
town center(420,330) and production(60,570). Population reached5/5. Order then
map(510,418) placed the original blue rally flag through rightMouseDown:/Up:.
This strengthens input-sequence evidence, but is one run, not complete input
acceptance. The experiment remains opt-in AGEPAD_TOUCH_MOVE_BEFORE_DOWN=1.

A30-second world composition sample measured485 displayed completions and1drop
(16.17/s). It is neither physical FPS nor a performance pass. Terrain remains
very dark, ordinary unit selection/movement is not proven, and Escape did not
open the menu on the last observed attempt. Current image is
move-before-down-2/world-checkpoint.png. The runner observation lasts3600s;
keep its helper lifetime in scope. Both prior autosaves are preserved under
right-dispatch-1/preserved-autosaves. Do not claim the full game objective complete.

## Text-input diagnostic — 2026-09-12 03:33

The runner now owns temporary caffeinate activity/display/system assertions and
cleans them up on exit. Prior standalone assertion was stopped after verification.
`idle-villager-1` aborted during startup without a causal error. One unchanged
retry (`idle-villager-2`) reached menus and loaded the real autosave using a short
Load tap. The first Load Game dialog tap still only hovered; the identical second
tap opened it, so move-before-down is not a universal first-tap fix.

Keyboard routing previously ignored everything except Escape. Period HID55 to
Carbon47 now reaches the original engine. Its first test identified a precise
adapter abort: `NSView interpretKeyEvents:` explicitly accepted Escape only.
The callback now returns printable text through the original responder's
`insertText:replacementRange:` when implemented, with NSNotFound/zero replacement
range; legacy responders use `insertText:`. Escape retains cancelOperation:.
Apple's text-input documentation supports this contract, and a native AppKit
oracle (`generated/mac-de-keyboard-oracle/result.txt`) confirms both period with
range9223372036854775807,0 and Escape→cancelOperation:.

`idle-villager-3` was superseded before keyboard testing after inspecting the
original executable's modern text-input selector. Current `idle-villager-4`
contains the completed callback, game69591/helper69581 at launch (revalidate).
Actual unit selection is still pending. Save files are preserved. Rendering
remains corrupted; neither a loaded world nor this diagnostic passes F3–F5.

### Runtime result and next graphics fixture

`idle-villager-4` successfully loaded the autosave, accepted period down/up,
called the original text-input client and selected a Villager (portrait,25/25HP,
selection ring, camera center). Order then ground CUA227,380 emitted original
rightMouseDown:/rightMouseUp:, showed the destination marker, and moved the
selection ring/health bar from425,362 to227,380. The sprite remained invisible.
This is original selection and movement evidence; keyboard selection is not a
passed touch selection gate. A direct tap and box drag at the known destination
still failed. Evidence: `idle-villager-4/movement-checkpoint.png`, game.stderr.

The next boundary is actual draw/resource inspection, not another hit-point
search. Added opt-in `MetalCaptureCompat.m`: with MTL_CAPTURE_ENABLED=1 and an
AGEPAD_GPU_CAPTURE_OUTPUT path, creating <path>.arm starts a half-second capture
of the actual Metal device. No game rendering semantics are modified. Native
macOS26.6.2 lacks the newer gpucapture/gpudebug CLI, so use MTLCaptureManager and
Xcode. Apple documents GPU capture support for Simulator.

The initial capture runner correctly refused to replace a live Steam helper.
The game was explicitly terminated after announcing that unsaved movement resets;
its existing runner completed cleanup (717.2s, helper alive throughout). Retrying
world-capture-1 after cleanup starts the capture-enabled candidate. Revalidate
its launch.json; no capture result is accepted until the file is produced.

Capture mode first exposed a concrete method-introspection failure at the
software-BC profile hook: Metal's capture device forwards the capability query.
The adapter now preserves its forwarding IMP when no concrete Method exists.
`world-capture-2` passes startup and still reports actual hardware BC=0,
software_2d=1. The GPU capture timer reports ready, awaiting the world-state arm
file. This changes introspection compatibility, not the underlying capability.

Capture succeeded in `world-capture-2`: `world-draws.gputrace` is a4.8GB private
trace; log records STARTED then STOPPED. Keyboard selection again displayed an
invisible villager's ring/health/portrait. Current game75479/helper75466 were
alive after20minutes; only AgePad G5 booted and host remained unlocked.
Xcode first-run optional downloads were deselected, existing components used.
CUA text/Return malfunction in its file dialog was resolved by js_reset and
reconnecting; the trace is now opened. Replay target was explicitly changed from
default iPad Air to AgePad G5 before Replay. Xcode is preparing the frame. Do not
boot another Simulator or recapture merely to bypass this analysis step.

### Replay inspection checkpoint — 2026-09-12 04:25

Xcode replay succeeds on AgePad G5 and reproduces corruption. Trace metadata
reports1captured frame; Xcode summary:19command buffers,32render encoders,
2blit encoders,1087draw calls. The2327API insights examined are redundant
bindings, not a causal rendering error. Pipeline grouping is available. Native
GPU profiling/memory metrics are unavailable in Simulator; no performance claim.

Inspected pipeline0x111053c00 texture8(0x37a177480) is a valid wave normal map,
not a unit atlas. Pipeline0x10e38e940 texture8(0x174995680,4096x3144RGBA8) is a HUD
atlas with original controls/icons, not unit pixels. Pipeline0x111005f40
texture8(0x37a118300,1024RGBA8 with mips) is a cyan terrain/water-like texture;
smaller mip previews appear black, but neither ownership nor invalid mip data
has been established. Do not patch mips from this preview alone. Remaining
pipeline/source inspection is needed to identify the missing unit draw.

A native Mac comparison was attempted by opening the supplied unmodified app.
It reached the same original main menu/version, but CUA clicks, one held drag
and Return did not open Single Player. Therefore it is NOT a native-world
baseline and cannot establish whether supplied assets are sound. Closed it via
native menu Quit/OK; PID89498 verified gone. Simulator game75479/helper75466 were
still present at40minutes; only AgePad G5 booted. Xcode GPU replay may suspend
normal foreground gameplay; keep diagnostic replay distinct from live acceptance.

Next: continue the existing capture's draw/resource inspection without another
startup loop. Xcode current trace `world-draws.gputrace`, grouped by pipeline;
last inspected0x111005f40 texture8 Quick Look. CUA session was reset; only xcode
and nativeGame bindings remain, nativeGame is now exited. Reconnect Simulator
only after checking boot inventory. Runner90405 expires after3600seconds and
then cleans helper; captured trace remains available independent of that timer.


### 2026-09-12 05:04 — asset and resource-lifetime investigation

Xcode replay of world-draws.gputrace identified SpritesSLD_Default_PS,
SpriteShadows_Default_PS, CombineTerrainSpriteSMP_PS and the terrain/water
passes. Exported world-atlas-capture.png contains valid static scenery/building
pixels; it does NOT establish that villager frames reached the atlas. Four
installed male/female idle A/C x1 SLD files hash-match the original source.

world-assets-1 startup tracing hit the 100,000-record cap before a useful world
load. world-assets-2 omitted startup tracing but also crashed, so tracing alone
is not an established cause. Host SimMetalHost crash at04:57:31 was in
AGX compute setTextures; subsequent app abort is MTLSim XPC failure, followed
by a secondary fault in the game's signal handler. Later host crashes included
newObjectCommand/newCommandQueue failures.

Runtime mip-lifetime-1 confirms command.retainedReferences=0 on real uploads.
BC4TextureCompat previously created transient per-mip views without retaining
those adapter-owned objects through command completion. Added a completion
handler retaining each temporary view for unretained command buffers. This
fixes a concrete ownership gap per Metal's retainedReferences contract, but
mip-lifetime-1 still crashed in the already-failing Simulator service and does
not establish a startup or visual fix. Restarted ONLY existing G5 Simulator,
then launched mip-lifetime-2 for a fresh-service validation. Resource trace is
currently disarmed; arm generated/mac-de-simulator-375/trace-armed only when
ready to load a scenario. No changes to compressed pixels/shader semantics.


At05:10 mip-lifetime-2 loaded the autosave with textured terrain and normal-looking
fog, a clear improvement over world-capture-2. Candidate change is the mip-view
lifetime fix plus a clean restart of the same Simulator, so do not ascribe all
improvement to the code change without an isolated comparison. Screenshot:
generated/mac-de-simulator-375/mip-lifetime-2/terrain-checkpoint.png. Touch selected
the town center and queued a villager; original UI correctly reports population
cap5/5 and need for houses. Unit visibility remains unresolved. The period key
produced no DE_HARDWARE_KEY_ENQUEUED despite CONNECTED log. Capture Keyboard toggle,
CUA reconnection and Raise did not restore that route; toggle is back off. Do not
repeat those actions blindly. A keyboard callback diagnostic before the key-window
guard can distinguish no HID delivery from a dropped window route on next build.

Scenario-only file trace remains below cap (~15,395 records), with484 SLD opens.
Villager death frames opened successfully; no idle/move paths recorded during
this interval. This does NOT prove those assets failed, as startup ran disarmed.
Next asset test should filter to villager paths and arm before startup to avoid
the broad trace cap. world-sample.txt preserves the running process stacks.
Live game7317/helper7294/runner session50598 at last check. Keepawake work session
74393 (PID4960) plus bounded runner assertion; revalidate rather than assume.


### 2026-09-12 05:50 — focused asset tracing and engine diagnostics

Added AGEPAD_RESOURCE_FILE_TRACE_MATCH to RuntimeFileTrace and rebuilt the
ResourceFileTrace.dylib. Added opt-in AGEPAD_KEY_DELIVERY_TRACE before the HID
filter/window guard. villager-assets-1 confirms idle/walk villager file stat
success at startup, with only death animation SLD opens recorded across startup
and world load. No file-query cap reached. Keyboard period DID arrive/enqueue in
this fresh run and selected a villager (portrait25/25, ring, health bar); body
remained invisible. Terrain/fog improvement reproduced without restarting the
Simulator. Both candidates were explicitly terminated for next diagnostics.

Enabled original engine launch options through Feral MacDoze Config
ExtraCommandLine: LOGSPRITEMEMORY SHOWDEBUGSPRITES CONSTANTLOGGING, enabled=1.
Original preferences backed up in villager-assets-1/preferences-before-sprite-diagnostics.xml.
Engine confirms Active Launch Options and Constant Logging ON, creates
VFS/User/Games/Age of Empires 2 DE/logs/YYYY.MM.DD-HHMM.SS/MainLog.txt (filename
has a trailing space). sprite-diagnostics-1/MainLog.txt preserves the first log.
No sprite-detail messages or debug placeholders appeared yet. May require
ObjectRendering logging category; do not claim the absence proves successful load.

Engine adapter report has Dedicated VRAM=0, Shared RAM=0; selects standard assets
for low video memory. DeviceMemoryProbe.m compiled separately for macOS and the
existing Simulator proves same registry4294968173 reports recommended working
set19069665280 on host vs0 on Simulator; unified1 vs0; maxBuffer14302248960 host
vs268435456 Simulator. Host memory_pressure shows69% free, so no evidence of
actual host memory exhaustion. Probe commands/results can be repeated directly.

Added recommended_working_set to fresh HostDeviceMetadataSurvey and an OPT-IN
AGEPAD_BACKING_WORKING_SET Metal getter fallback. Only replaces zero when the
survey registry matches the actual device; leaves existing nonzero, resource
limits and feature flags unchanged. backing-budget-1 logs successful fallback
calls, but original engine adapter report STILL shows VRAM/sharedRAM0. Thus no
unit-streaming fix established. Candidate currently loading saved world; do not
make the opt-in default without validation. Runner session88755 (revalidate).
Current Feral extra diagnostic launch options still enabled; restore just those
fields from backup when diagnostics complete. Do not overwrite newer saves or
unrelated preference updates. Standalone keepawake4960 expires around05:57;
runner has its own assertion for the bounded run.


At05:55 backing-budget-1 loaded the same world, selected the villager by period
with raw HID55 and enqueue logs. Portrait/health/ring visible, body still absent.
Budget correction DID NOT restore units. Keep experimental flag opt-in, do not
claim it as the cause/fix or change hasUnifiedMemory/maxBufferLength to match host.
MainLog-checkpoint.txt and screenshot preserve results. Live game25995/helper25984,
runner88755 at last check. Original diagnostic options remain active. Next useful
paths: enable ObjectRendering log category (currently only default categories),
inspect engine sprite loader/atlas lifecycle, or trace POSIX aio_read/aio_error
with FD path to cover asynchronous reads. nm confirms original imports aio APIs,
open/fopen/pread/read/mmap but no openat. Missing sprite opens in current trace
alone is not yet proof no reads happened through another path. No further changes
to upload/render semantics were made in this turn. Previous turn classification:
progress (reproduced visual improvement, resource-lifetime fix and live evidence).
This turn: progress (focused diagnostics, original logger activation, tested and
rejected budget-only fix as sufficient). Not blocked; requested game remains
incomplete.


### 2026-09-12 06:14 — initial adapter-budget scan corrected

sprite-aio-1 enables LOGSYSTEMS=ObjectRendering VERBOSELOGGING. Engine explicitly
confirms category and verbose logging; MainLog now emits SLD_ASSET records.
Villager death frames decode, no idle/walk records or sprite errors observed.
New AIO hooks preserve aio_read/error/return and log FD paths; Simulator integration
probe submitted/read11 bytes correctly with hooks active. No villager AIO records
appeared in the game run. Resource filter is now case-insensitive. Source changes
in RuntimeFileTrace.m; rebuilt injected ResourceFileTrace.dylib.

Native Mac log already exists at ~/Library/Application Support/Feral Interactive/
Age Of Empires II/VFS/User/Games/Age of Empires 2 DE/logs/2026.09.12-0416.37/
MainLog.txt (trailing space). It reports Dedicated VRAM18186MB, unlike Simulator0.
The prior working-set hook was installed at device-observer registration, AFTER
the original engine's first machine survey. Added opt-in constructor installation
of ONLY the working-set getter before that survey. early-budget-1 confirms original
MainLog now reports Dedicated VRAM18186MB (matches native), not just the wrapper's
own diagnostic. Startup succeeds; world-load/units validation pending. Keep the
flag opt-in until evaluated. No change to reported maxBufferLength or unified-memory
feature. Live runner89347 (revalidate), screenshot currently Single Player dialog
opening. MainLog-startup.txt preserved; full original log dir0612.28. Diagnostic
launch options remain active; previous preference backup still valid for restoring
only the ExtraCommandLine fields.


At06:26 early-budget-1 world loaded, selected villager via period. Body remains
invisible despite corrected original adapter VRAM18186MB and no low-video-memory
startup warning. So early budget fixes real metadata but is not sufficient for
unit rendering. Through actual Simulator clicks: civilian-build menu59,570,
house59,570, placement362,400. Original unit became Builder, moved to foundation,
finished visible house; cap5->10 and previously queued villager produced, pop6/10.
Screenshot house-production-checkpoint.png preserves real construction/production.
Do not claim complete playability while units remain invisible. MainLog-checkpoint
preserves ObjectRendering diagnostics; still only death-frame villager/builder
SLD records observed, no errors/late-load messages. Current live candidate
is early-budget-1, runner89347, query launch.json for current PIDs.

Next unresolved technical lead: adapter intercepts only MTLDevice texture
allocation. Feral binary includes UseBufferBackedDynamicTextures, DisableHeapTextures,
and EnableTexturePaging. Animated atlas pages may use buffer/heap allocation paths,
but this is NOT verified. A bounded read-only route trace across MTLBuffer/MTLHeap
newTexture methods and device allocator could prove or reject that without changing
rendering options. Do not blindly flip those Feral options. MetalFormatTrace currently
only diagnoses pixelFormat0 at one original offset, not these allocation routes.
Native Mac main log already gives a baseline; no need to relaunch it just for VRAM.


### 2026-09-12 06:57: fresh-world and allocation-route checkpoint

Current candidate early-adapter-1, game51356/helper51344, runner45247.
Only G5 booted. Runner caffeinate51336 active with display/activity assertions.
MetalTextureRouteTrace.m hooks concrete MTLSimBuffer and MTLSimHeap texture
allocation methods, preserves descriptors/results, caps4096 records.
texture-routes-1 world load had1954 device calls, zero buffer/heap calls;
early-adapter-1 after a second world load has2775 device calls and zero buffer/heap.
This does not support the proposed allocation bypass in the observed loads.
Opt-in AGEPAD_EARLY_METAL_ADAPTER=1 installs existing adapter before the engine
machine scan; log confirms installed=1. It did not restore unit bodies.

Through actual Simulator UI, quit saved scenario (house saves already preserved),
then start new Random Map, Black Forest, Tiny2players, Standard AI/resources,
Persians, DarkAge. World loads, textured terrain/TC/fog render. Period selects
starting villager with portrait25/25, ring and health bar, body still absent.
Evidence early-adapter-1/fresh-world-villager.png. Thus failure also affects a
fresh world, not only the old five-player Deathmatch autosave.

Native unmodified Mac game54200 remains at main menu. CUA clicks highlight but
do not activate Single Player; no native-world baseline yet. Native saves backed
up in native-reference-2. Async question asks whether a physical click opens
Single Player; no answer yet. Continue independent Simulator diagnosis.

Fresh-world.sample.txt is a3second process sample after fresh world selection.
AsyncSystemThreads0..3 are sleeping in normal condition-variable waits;
Phoenix workers also mostly wait and WinMain/Metal command encoding continue.
No observed file-read stall; the sample alone cannot distinguish empty queue
from a missed load request. Villager source SLD files are nonempty (idle~0.8-1.1MB,
walk~0.5MB), not empty placeholders. MainLog-fresh-world.txt preserved.
Next discriminating work: establish native-world baseline if physical click
answer arrives, otherwise identify animated-sprite request path before GPU
allocation; do not repeat already-negative early-budget/heap/old-save hypotheses.


### 2026-09-12 07:14: native touch and real-time-speed iteration

User explicitly adds native one-finger left click, two-finger right click,
two-finger map pan, pinch zoom, side macros, normal speed, and clear IPA/Steam/
data setup documentation. Scope remains original game working, not HUD-only.

Created root README.md explaining actual versus intended IPA setup. Simulator
packaging is not physical IPA; desktop Steam on source Mac plus private game
preparation, device signing/import, and required Steam services remain distinct.
Importer/self-contained device Steam/physical execution are unimplemented or
unproven. Updated DE-INSTALL-AND-ONLINE-PLAN.md stale iteration349 claim.

WindowViewCompat moves ORDER to right-side red/gold Georgia strip, clear of
bottom HUD/minimap; added IDLE/TOWN/MENU via shared original keyboard queue.
NativeTouchGestures.m implements recognizers, right tap pair, slash-key original
click-drag, pinch->wheel; EventCompat/NSWindow now support wheel properties and
scrollWheel dispatch. Native multi-touch behavior NOT yet verified; tools lack
an exposed multi-finger action. Added F11 keyboard route and stopped unconditional
CGEventSourceKeyState logs unless key delivery trace requested.

Actual touch-strip-2 Simulator taps: first-attempt SinglePlayer/Load/LoadGame,
IDLE selects portrait25/25/ring, TOWN selects/centers TC. Body still invisible.
MENU Escape only deselects, so source correction uses actual hotkeys.json F10.
Added ZOOM+/− buttons to exercise same wheel path as pinch. HD screenshot reference
from Standardof.net viewed and saved as hd-control-reference.png.

Native reference game54200 quit gracefully via CmdQ/OK; verified PID absent.
Pending earlier physical-click question no longer applies. Beforeclosing/reference
withdiagnostics, early-adapter1 measured702completions/30s=23.4/s. Afterclosing
referenceandwithoutkeytrace, touch-strip2 measured912/30s=30.4/s,0drops.
speed-start.png shows00:11:03 and speed-end.png00:11:54, bothNormal1.7Standard.
Thus simulation advances51secondsin30wallseconds, expected1.7×. This does not
prove60FPS/physicalscanout/generalnormalplay; missingbodiesremain.

Stopped touch-strip2 aftertests (helperaliveuntilcleanup). touch-strip3 now
build/launch running session listed in current turn; querylaunch.json/PIDs.
Next: verify F10MENU and ZOOM through actual Simulator, then gesture arbitration
and natural map movement, with invisible-unit root cause still critical.

At07:19 touch-strip3 live game69780/helper69770, runner session51746.
ActualUI verifies TOWN thenMENU(F10) opens original MainMenu on firsttap withTC
selected. CancelthenZOOM+ increases worldscale, ZOOM− decreases it; HUDfixed,
no unsupportedselector/abort observed. IDLEselects25/25villager, ORDERthen493405
starts moving ring from425362towarddestination and resetsORDermode.
Screenshot side-controls-world.png. This validates the wheel/command paths used
by gestures, not the actual multiple-finger recognizers. Physical native reference
question is obsolete because the reference app was closed for isolated timing.


### 2026-09-12 07:42: parser evidence and pointer-consumption correction

Compared original versus installed __TEXT,__text: both67501856bytes, ZERO changed
4-byte instructions. Existing binary patches cannot explain missing unit bodies.
SLD_ASSET stringxref102d5598c belongs to function102d554ec..102d559cc.
Chainedfixup vtable slotfile/VMoffset4d34be8 points there; RTTI identifiesSLDFile,
baseDEShapeFile. Parser takesobject(x0),path(x1), returns0/1; vectorbytes atobject+10.
Added opt-in SLDParseTrace.h viaRuntimeFileTrace.m: matchgameimagebyname, guard
vtablepointerandfirstopcode, replaceonlydatavtableslot, calloriginalunchanged,
logbounded4096results. vm_protect restoresread-only, no executablecodepatch.
Initialsprite-parser1 skippedguard because imageindex0 is injectedlibrary, not
mainengine (vmmapconfirmed). Correctedname lookup. lldbattach69780 failedlost
connection; process remainedalive. No debugsessionleft.

sprite-parser2 verifiedinstalled=1 restore_status=0. Originalworldloaded;
400SLDparses, allresult1. Onlytwo villagerrecords, male/femaledeathA. Noidle/walk
parses. Fullrecords preserved sprite-parser-2/parser-records.txt. This directs
nextgraphicswork upstream into live-unit assetrequests, not speculativeBC/shader
changes. Doesnotprove noothercodepath, but parserhasnodirectBLcallers andvirtual
slotinstrumentation plusfiletraceagree.

Actualonefingerdrag366277->541441 failedselection in touch-strip3. UIKit
deliveredbegin/end withouttouchesMoved. Addedfinaltype6beforeup; sprite-parser2
verifiedtype6sentbutselectionstillfailed. Logprovedpointerobserverhadalready
updatedendpoint769.5,531.5 BEFOREoriginalmouseDown consumedstart498.5,277.5;
originalmouseDown queriesNSEvent.mouseLocation, soanchorwaswrong.
NSWindow.sendEvent now synchronizesapp-ownedlogicalpointer to each eventlocation
before invoking originalhandler, in correctscreen coordinates. Nohostcursorwarp.
Currentpointer-consumption1 buildrunning session37017; launchedoriginalgamefrom
launcher07:42, world/dragvalidation pending. SLDtraceactive. RevalidatelivePIDs.

At07:47 pointer-consumption1 worldloaded; testeddrag366277->541441, then
IDLEtoestablishknownvillager425362, Escapeanddrag373315->474399. Bothfailed
selection. Logs now prove originalmouseDown polls the START pointer and drag/up
poll END pointer; orderingcorrectionworkedbutisnotasufficientdragfix. Do not
claimdragselectionworking. OriginalCFeralNSWindow mouseDragged handler is found
and invoked; furtheroriginalWindows-eventtranslation/gesturetimingneedsanalysis.
NativeTouchGestures delaysbeginuntiltwo-fingerrecognizersfail; maystillpostpone
livedragfeedback. Preserveuser'srequestednaturaltouchscope.

Shape-load-xrefs.json nowlocates original DEShapeFile::Load errorstring at
102d1581c and existing-objectpreload string at103758424. shape-load.asm is a
partialstaticdisassembly. This isnextupstreamlive-spriteloadlead. No speculativeload
behaviorchanged. Root README/controls/setuprequirements remain current.

### 2026-09-12 07:55 — immediate primary touch and RAM gate trace

Candidate `immediate-touch-1` changes only the two-finger tap recognizer
`delaysTouchesBegan` to NO; previously it withheld the entire primary touch
stream while waiting for recognition to fail. Preserved six save files in
`pointer-consumption-1/preserved-saves` before the announced restart.
Original single-player and load menus still open on first taps.

Static trace locates CheckAvailableMemory at original function102d6a138.
It reads available physical RAM from the original Windows-style memory
structure (+0x10), shifts by30 and selects lower quality when <=2GiB.
The wrapper100b9bfd4 calls100c0efc8, whose available physical memory comes
from host_statistics64 free_count multiplied by page size. This is separate
from the corrected Metal recommended working set. No memory values were
changed; the absence of a diagnostic line is not evidence the branch is
never taken. Disassembly is private in375/memory-survey.asm.

07:57 UI result: autosave loaded, IDLE selected villager25/25 at425,362.
Escape then drag373,315→474,399 left the HUD empty. The original window
receives type6, but no selection. Disabling delayed touch delivery did not
resolve it. Evidence immediate-touch-1/drag-unselected.png and game.stderr.
Next input diagnostic should extend OriginalInputTrace.m to mouseDragged
and inspect dispatchEvent translation, rather than repeat pointer positions.
Live runner68528, game90333/helper90323; only G5 device booted.
