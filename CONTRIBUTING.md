# Contributing to AgePad

Thanks for helping make Age of Empires II better on the iPad.

## Before opening an issue

- Search existing issues and the [FAQ](README.md#frequently-asked-questions) first.
- Include the AgePad version or commit, iPad model and memory, iPadOS version, how
  the app is signed (paid or free Apple account), and exact steps.
- For crashes and freezes, run `scripts/agepad-ipad.sh logs` and paste the relevant
  lines. Read them first and remove your Steam account name or ID.
- Never attach or link to game files, saves, `AgePad-mine.ipa`, Steam files or
  sign-in details.

## Making a change

1. Run `python3 scripts/check-repo-safety.py`.
2. Make the change in `port/`, `scripts/` or `docs/`. Everything under
   `generated/` is built from your own game and Steam install and stays private.
3. Run `scripts/run-de-tests.sh`. With the AgePad iPad Simulator booted it also runs
   the touch and Pencil tests; with the game and a build on your Mac it runs the
   release round trip.
4. Test on an iPad when the change touches input, rendering, Steam or memory:
   `scripts/agepad-ipad.sh build` installs in place and keeps game files and saves.
5. Update the docs when behaviour or a known limit changes.

Pull requests should stay focused and say what a player will notice, what was
tested, and on which iPad.

## Game-data boundary

The game program, game data, Steam client libraries, saves, signing material and
any `.ipa` other than the audited base app must never enter Git history.
`scripts/check-repo-safety.py` and `scripts/audit-agepad-base.py` enforce this.

## Licensing

AgePad's own code is [MIT](LICENSE). Third-party code keeps its own licence
([THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)). By contributing you agree your
change is released under the same terms.
