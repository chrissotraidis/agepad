# Mac lock diagnosis — 2026-09-12

The lock was real and caused by the macOS screen-saver idle timer. The saved
current-host `com.apple.screensaver` preference is `idleTime = 1200` (20 minutes).
At 2026-09-11 21:24:56 local, loginwindow logs actualUserIdle=1200.0 and
targetUserIdle=1200.0, then starts ScreenSaverDaemon, logs "about to call
lockScreen", and enqueues lock reason3. The earlier19:47:00 lock followed the
same screen-saver path. Evidence: generated/mac-lock-audit-20260912/lock-causes.log.

This is separate from system sleep: pmset reports SleepDisabled=1, sleep=0,
and several system-sleep assertions. Amphetamine's active assertion prevented
system sleep, not user-idle display sleep. Simulator CUA interaction continued
while loginwindow's idle clock reached its limit, so those actions did not
reliably count as macOS user activity. The CUA lock guardian appeared after the
lock at21:24:57; the observed initiating request was ScreenSaverDaemon.

At02:42:44 the genuine macOS unlock succeeded. CUA access was verified working
again. Started a bounded `caffeinate -diu -t 3600` session (PID53154, revalidate)
and verified UserIsActive, PreventUserIdleDisplaySleep and
PreventUserIdleSystemSleep assertions in pmset. This is a temporary mitigation;
password requirements and persistent screen-saver/lock settings were unchanged.
Verify it remains effective past the20-minute threshold rather than assuming
that an assertion alone proves the recurrence fixed.

Resumed original-DE testing. Old right-dispatch-1 game was still alive after its
one-hour helper cleanup, so that remaining process was not a valid new soak.
Both current autosaves were copied with hashes before the announced fresh
move-before-down-1 candidate. No extra Simulator was booted.

At03:07:12 the temporary assertions had been active20m29s. CUA screenshots and
interaction still worked; a loginwindow search over the preceding25minutes found
no new screen-saver lock request. This is observed prevention during the session,
not a permanent lock-policy change. The game runner now owns the same temporary
assertions for each bounded test, tied to its PID and released in finally. Python
compile passes; subsequent runners use this lifecycle integration. Current run
continues under the separately verified PID53154 assertion until its expiry.

At04:54 the separate bounded assertion was verified active; at04:56 the new
runner owned all three assertions under PID4114, including UserIsActive and
PreventUserIdleDisplaySleep. That runner subsequently ended on a Metal-service
crash; a bounded work-session assertion was restarted across diagnostic restarts.
Keep-awake coverage must span investigation as well as live-game observation.
The crashes are separate from the established screensaver lock cause.

## 2026-09-12 evening recovery

No Simulator was booted at intake. Reused only the designated G5 iPad. The
screensaver idleTime remains 1200; permanent security/lock preferences were not
changed. Recovery runners again own UserIsActive, PreventUserIdleDisplaySleep
and PreventUserIdleSystemSleep assertions. The recent loginwindow query found an
idle-timer check, not a new lockScreen call. This session has not established a
permanent fix or reproduced the reported desktop freeze.

Read the 04:05–04:07 WindowServer CPU report: 56% average CPU over 162 seconds,
with display-compositing stacks. This is a high-CPU report, not proof of a full
machine hang or an AgePad root cause. Decoded the 08:27 shutdown-stall report:
one second of samples after a two-second delay during shutdown. It does not
establish a gameplay freeze. No thermal/performance warning was recorded by
pmset during the recovery checks. A later world sample showed game RSS about
1.4 GiB and WindowServer about 26% CPU; point samples do not rule out spikes.

Reduced avoidable diagnostic load: first recovery startup generated ~35 MB of
stderr; the quiet profile was ~324 KB after about one minute. The runner now
stops its owned renderer when observation expires, on SIGTERM cleanup, or after
helper loss. Previously a game could outlive its helper and assertions. Actual
five-second expiry and explicit interruption both removed owned processes;
PID/executable mismatch protection was tested with an isolated sleep child.

Next freeze report needs a time and symptom distinction (lock screen versus
unresponsive desktop/pointer) before attributing it. Private diagnostics and
screenshots are in `generated/recovery-audit-20260912`.
