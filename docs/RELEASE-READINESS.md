# Release readiness: AgePad 0.1 preview

Updated 30 September 2026. The earlier 12 September assessment (freeaoe/Simulator
era) is in the Git history and `docs/ENGINEERING-HISTORY.md`.

## Verdict

Ready for a public **preview** once the items under "Needs Chris" are done.
Nothing else blocks it. It is a preview: one iPad model tested, online play and
long sessions not yet verified (the README and release notes say so).

## Checked

| Check | Result |
|---|---|
| Game on a real iPad | Menu, skirmish at ~120 fps, save and load, offline play, Steam QR sign-in (iPad Pro 12.9-inch M2, 8 GB) |
| Controls (Chris, hands-on) | Keyboard and trackpad work well, Apple Pencil is decent, going online works; a mouse is untested. Three-finger map drag felt bad and was reworked on 30 September (below) |
| First-time install (30 September) | Fresh clone with no `generated/` → `inject` of the new base app (6 s) → `sign-agepad-ipa.sh` → installed in place on the iPad; game data and Steam sign-in kept. `check` no longer reports the build package as missing for release users |
| Base app contents | `AgePad-base.ipa`: 65 files, all AgePad's own; audit finds no game or Steam file; no personal paths, addresses or Steam IDs |
| Release round trip | recipe → base → audit → inject → identical to a direct build (`tests/test_agepad_kit_roundtrip.py`) |
| Game version | Base app, release notes and current Steam game all build 25464371 |
| Repository history (104 commits) | No keys, tokens, Steam IDs, device IDs or home paths; all commits use the GitHub no-reply address; no game or Steam files ever committed |
| Screenshots in `docs/images` | Game UI and AgePad screens only; the Steam QR shown is an expired, approval-only code |
| Licences | The iPad app contains only AgePad code plus MIT bcdec; GPL/LGPL material is confined to patches for earlier routes ([THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)) |
| Tests | `scripts/run-de-tests.sh` (incl. two-finger and Pencil logic in the Simulator) and `scripts/check-repo-safety.py` pass |
| Community | README badges and Discord, issue templates for bugs and questions |

## Needs Chris

1. **Touch review of the 30 September build** (installed on the iPad): three-finger
   map drag, quick repeated swipes, two-finger drag vs pinch. The build turns off
   iPadOS's three-finger undo/copy gestures in the game, keeps a gesture a drag or a
   zoom once it starts, and no longer drops the button when a swipe follows another.
2. **Rebuild the base app after any further change** (`scripts/agepad-ipad.sh kit`);
   the current one (30 September, SHA-256 `571a93e4…1c2d85`) matches the installed build.
3. **Publish:** push, make the repository public, tag and release (below).

Licence: MIT, chosen 27 September ([LICENSE](../LICENSE)).

## Release steps

After the touch review, with the iPad still connected:

```sh
scripts/agepad-ipad.sh kit                 # makes generated/kit/AgePad-base.ipa; must end "0 contain game or Steam content"
shasum -a 256 generated/kit/AgePad-base.ipa
git push origin main
gh repo edit chrissotraidis/agepad --visibility public --accept-visibility-change-consequences
git tag v0.1 && git push origin v0.1
gh release create v0.1 generated/kit/AgePad-base.ipa --prerelease \
  --title "AgePad 0.1 (preview)" --notes-file docs/RELEASE-NOTES-0.1.md
```

Then: in the README "Downloads" row, replace "(release not yet published)" with a
link to the release; download the asset while signed out and compare its SHA-256.

If Steam or the game updates before the release, rebuild first: `inject` rejects
files that don't match the base app's recorded versions.
