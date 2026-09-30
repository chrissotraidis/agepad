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
| Controls (Chris, hands-on) | Keyboard and trackpad work well, Apple Pencil is decent, going online works; a mouse is untested. Three-finger map drag felt bad and was rebuilt on 30 September (next row) |
| Map drag on the iPad (30 September) | DE's click-drag scrolling is a joystick (dead zone ≈68 points, speed rising with the offset, vertical counted 1.78×), so the finger as pointer moved the map the wrong way, ignored small drags and ran away on big ones. AgePad now steers the pointer from a measured model; test drags of 30–360 points moved the map within 3% of the finger movement in all directions, with no stray orders. Not yet checked at other zoom levels or with real fingers |
| First-time install (30 September) | Fresh clone with no `generated/` → `inject` of the new base app (6 s) → `sign-agepad-ipa.sh` → installed in place on the iPad; game data and Steam sign-in kept. `check` no longer reports the build package as missing for release users |
| Base app contents | `AgePad-base.ipa`: 65 files, all AgePad's own; audit finds no game or Steam file; no personal paths, addresses or Steam IDs |
| Release round trip | recipe → base → audit → inject → identical to a direct build (`tests/test_agepad_kit_roundtrip.py`) |
| Game version | Base app, release notes and current Steam game all build 25464371 |
| Repository history (104 commits) | No keys, tokens, Steam IDs, device IDs or home paths; all commits use the GitHub no-reply address; no game or Steam files ever committed |
| Screenshots in `docs/images` | Game UI and AgePad screens only; the Steam QR shown is an expired, approval-only code |
| Licences | The iPad app contains only AgePad code plus MIT bcdec; GPL/LGPL material is confined to patches for earlier routes ([THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)) |
| Tests | `scripts/run-de-tests.sh` (incl. two-finger and Pencil logic in the Simulator) and `scripts/check-repo-safety.py` pass |
| Community | README badges and Discord, issue templates for bugs and questions |

## Published

0.1.0 was published on 30 September 2026, after Chris's hands-on touch review
(three-finger drag fine, then 20% faster; pinch zoom made faster). The release app
(SHA-256 `a03b8f13…80b502`) matches the build on the tested iPad. Still open:
dragging at other zoom levels with real fingers, a mouse, full online matches,
sessions over an hour and other iPads.

Licence: MIT, chosen 27 September ([LICENSE](../LICENSE)).

## Release steps

After the touch review, with the iPad still connected:

```sh
scripts/agepad-ipad.sh kit      # generated/kit/AgePad-base.ipa; must end "0 contain game or Steam content"
V=$(python3 -c "import json;print(json.load(open('version.json'))['version'])")   # 0.1.0
R=generated/release-v$V; mkdir -p $R
cp generated/kit/AgePad-base.ipa $R/AgePad-v$V-ios-unsigned.ipa   # the names PadMint downloads
cp padmint.json $R/AgePad-v$V-padmint.json
(cd $R && shasum -a 256 AgePad-v$V-* > SHA256SUMS)
python3 -m padmint audit $R                # from a PadMint checkout; must PASS (it cannot see game code; the kit audit above can)
git push origin main
git tag v$V && git push origin v$V
gh release create v$V $R/* --latest \
  --title "AgePad $V" --notes-file docs/RELEASE-NOTES-0.1.md
```

Not a GitHub pre-release: PadMint and the README's download link follow
`/releases/latest`, which skips pre-releases. The notes say it is a developer preview.

Then download the three assets while signed out and compare them with
`SHA256SUMS`, and run `padmint make agepad ios` once from a PadMint release that
lists AgePad (catalog entry `catalog/agepad.json`).

If Steam or the game updates before the release, rebuild first: `inject` rejects
files that don't match the base app's recorded versions.
