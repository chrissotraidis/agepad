# Release readiness: AgePad 0.1 preview

Updated 27 September 2026. The earlier 12 September assessment (freeaoe/Simulator
era) is in the Git history and `docs/ENGINEERING-HISTORY.md`.

## Verdict

Ready for a public **preview** once the three items under "Needs Chris" are done.
Nothing else blocks it. It is a preview: one iPad model tested, online play and
long sessions not yet verified (the README and release notes say so).

## Checked

| Check | Result |
|---|---|
| Game on a real iPad | Menu, skirmish at ~120 fps, save and load, offline play, Steam QR sign-in (iPad Pro 12.9-inch M2, 8 GB) |
| Base app contents | `AgePad-base.ipa`: 65 files, all AgePad's own; audit finds no game or Steam file; no personal paths, addresses or Steam IDs |
| Release round trip | recipe → base → audit → inject → identical to a direct build (`tests/test_agepad_kit_roundtrip.py`) |
| Game version | Base app, release notes and current Steam game all build 25464371 |
| Repository history (104 commits) | No keys, tokens, Steam IDs, device IDs or home paths; all commits use the GitHub no-reply address; no game or Steam files ever committed |
| Screenshots in `docs/images` | Game UI and AgePad screens only; the Steam QR shown is an expired, approval-only code |
| Licences | The iPad app contains only AgePad code plus MIT bcdec; GPL/LGPL material is confined to patches for earlier routes ([THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)) |
| Tests | `scripts/run-de-tests.sh` (incl. two-finger and Pencil logic in the Simulator) and `scripts/check-repo-safety.py` pass |
| Community | README badges and Discord, issue templates for bugs and questions |

## Needs Chris

1. **Second touch review on the iPad** (first review 27 September; the follow-up
   build changes map drag, zoom speed, Pencil arming and the double-tap).
2. **Publish:** push, make the repository public, tag and release (below).

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
