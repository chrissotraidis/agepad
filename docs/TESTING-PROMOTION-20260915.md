# Device testing promotion check

The development source can be synchronized to private main. The app cannot yet
be promoted as an accepted physical-iPad build or standalone Mac installer.

## Executed checks

- Reused the sole designated G5 Simulator after shutting down the competing iPhone.
- Launched the current private runtime with a 30-minute cleanup deadline.
- Rotated the initially portrait Simulator to landscape.
- Loaded the named AGEPADPLAY914 regression save through the original menu.
- Verified visible villagers, animals, the previously completed house and 8/10 population.
- Selected a visible idle villager. Existing food gathering continued.
- Two Order + ground attempts delivered secondary events but did not move the villager.
- Zoom increased the rendered world scale.
- Actual Simulator touch-adapter regression passed ordered delivery and secondary down/drag/up.
- Python unittest discovery passed 14 tests.
- Source safety scan passed before commit. Current preflight/README/status edits
  pass whitespace checking. The initial source snapshot includes existing patch
  context whitespace and a few historical source/document whitespace warnings.

The 30-second measurement recorded 296 compositions (9.87/s), interval throughput
5.00–14.01/s, the same live game process, and only the designated Simulator at every
inventory check. This is not physical FPS or frame-time latency qualification.
Private evidence: `generated/promotion-20260915/`; runtime log:
`generated/mac-de-simulator-375/promotion-20260915/`.

## Installation assessment

`scripts/check-de-install.py` checks the installed Simulator application, required
private runtime files, desktop Steam and sole designated Simulator. It reports
the device/signing inventory separately, and cannot label a physical build ready.
The real positive preflight passed on this Mac. This machine currently reports
no physical device and zero valid signing identities.

README provides an executable local testing sequence and explicitly distinguishes
it from the planned importer and physical IPA flow. The Mac-assisted Steam helper
has no validated physical-device replacement. Signing alone cannot resolve that
dependency. Device packaging, asset import, on-screen text input, multi-touch,
lifecycle and sustained performance remain required work.

## Next acceptance conditions

Trace the failed order at the original gameplay consumer under measured load,
and compare with the successful September 14 scenario before changing timing.
Require repeated accepted movement after a fresh launch, without visiting Options.
Then validate two-finger order/pan and pinch with real touch hardware. A connected,
trusted iPad and development signing identity are needed for the device phase;
the device graphics/runtime and service design must also pass launch qualification.

Main is a development checkpoint, not a release tag or downloadable game package.
