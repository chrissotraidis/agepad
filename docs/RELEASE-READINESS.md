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

1. **Touch review on the iPad**, with a fresh build (it also carries the 27 September
   two-finger fix): `scripts/agepad-ipad.sh build`. Checks: two-finger taps,
   three-finger scroll, Pencil tap accuracy, Pencil double-tap/squeeze, a mouse wheel.
2. **Licence.** `LICENSE.draft` is MIT, which fits: the shipped app has no GPL code.
   GPL-3.0 (like KartPad) also works. Either way, update the README's last paragraph.
3. **Publish:** push, make the repository public, tag and release (below).

## Release steps

After the touch review, with the iPad still connected:

```sh
scripts/agepad-ipad.sh kit                 # makes generated/kit/AgePad-base.ipa; must end "0 contain game or Steam content"
shasum -a 256 generated/kit/AgePad-base.ipa
mv LICENSE.draft LICENSE                   # or your chosen licence; edit README "Credits and license"
git add LICENSE README.md && git commit -m "License"
git push origin main
gh repo edit chrissotraidis/agepad --visibility public --accept-visibility-change-consequences
V=$(python3 -c "import json;print(json.load(open('version.json'))['version'])")   # 0.1.0
R=generated/release-v$V; mkdir -p $R
cp generated/kit/AgePad-base.ipa $R/AgePad-v$V-ios-unsigned.ipa   # the names PadMint downloads
cp padmint.json $R/AgePad-v$V-padmint.json
(cd $R && shasum -a 256 AgePad-v$V-* > SHA256SUMS)
python3 -m padmint audit $R                # from a PadMint checkout; must PASS (it cannot see game code; the kit audit above can)
git tag v$V && git push origin v$V
gh release create v$V $R/* --prerelease \
  --title "AgePad $V (preview)" --notes-file docs/RELEASE-NOTES-0.1.md
```

Then download the three assets while signed out and compare them with
`SHA256SUMS`, and run `padmint make agepad ios` once from a PadMint release that
lists AgePad (catalog entry `catalog/agepad.json`).

If Steam or the game updates before the release, rebuild first: `inject` rejects
files that don't match the base app's recorded versions.
