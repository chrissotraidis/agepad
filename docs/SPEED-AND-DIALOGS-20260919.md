# September 19: simulation speed and dialog taps

## Reference point

DE's Normal game speed runs the in-game clock at 1.7x real time (Slow 1.0x,
Fast 2.0x). "Same as Steam" means 1.7x on Normal, not 1.0x.

## Finding: the main-thread wait pump was stealing time

`MainThreadGraphicsWait.cpp` interposes the original engine's GPU wait so UIKit
can deliver composition callbacks. It ran the run loop for up to 5 ms per wait.
At 30 frames/s that is up to 150 ms of every second the simulation thread
cannot use. Reduced to 1 ms (env `AGEPAD_GRAPHICS_WAIT_PUMP_MS`,
`--graphics-wait-pump-ms` on the recovery script).

A/B on the same Simulator, fresh skirmish left untouched, timed from the first
visible world frame (luminance-detected) to the MENU tap, timer read from the
statistics screen:

| Pump | Real s | Game clock | Ratio | Host load |
| --- | --- | --- | --- | --- |
| 5 ms (old) | 123.0 | 3:01 (181 s) | 1.47x | 19 |
| 1 ms (new) | 120.8 | 3:16 (196 s) | 1.62x | 6-14 |
| 5 ms, Sept 18 | 79 | 1:53 | 1.43x | 17 |
| 5 ms, Sept 18 | 261 | 5:12 | 1.20x | 35 |

1.62x is 95% of Normal. The residual tracks host load; on this Mac the load
has not been below ~6 during any run. Frame throughput under the same
conditions has not been re-measured after the change.

## Finding: dialog buttons also missed at low frame rate

Modal confirmation dialogs ("Are you sure you want to quit/restart?") drop
composition to ~5/s. The primary-button release then waited two frames, holding
Yes for 600-1000 ms, and the button only hovered (observed twice in a row on
Sept 19; also the Sept 15 Start Game misses). `DE_PRIMARY_MAX_HOLD` (250 ms) now
caps the primary hold the same way the secondary was capped on Sept 18. After
the change every dialog Yes/No, Play Again, Restart and Start Game tap in this
session was accepted first time (12+ taps).

## Also this pass

- Loom researched (villager HP 25 -> 40), Feudal Age button shows the correct
  "two Dark Age buildings" precondition, Town Bell rings and un-rings, build
  menu pages through Market/Dock/University with correct tooltips. All via
  first-tap actions.
- Session timeout cleanup at 3600 s ran cleanly overnight (no crash report).
- Xbox sign-in remains inert; not pursued further this pass.
