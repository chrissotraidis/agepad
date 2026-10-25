# Getting AgePad onto an iPad: the IPA route

## The problem

A full IPA can't be published: the working app contains Microsoft's game program and Valve's Steam software, which aren't ours to give away. iPadOS also runs only code that is inside the signed app, so the app can't download the game program later by itself.

**Steam modification and account risk:** assembling a personal IPA changes copies
of Steam client and SDK files, including platform metadata, dependency paths and
signatures. Preserving code/data sections and excluding vendor files from the
public base do not establish permission or account safety. Read the
[account-risk review](STEAM-ACCOUNT-RISK.md) before signing in.

## The route: a public base app plus "add your own copy"

1. **Base app (publishable, about 1 MB).** `scripts/agepad-ipad.sh kit` makes `AgePad-base.ipa`, published as `AgePad-vX.Y.Z-ios-unsigned.ipa` with `AgePad-vX.Y.Z-padmint.json` and `SHA256SUMS` so [PadMint](https://github.com/chrissotraidis/padmint) can use it: AgePad's own code, the icon, and `AgePadKit.json`, a recipe of which game/Steam files go where, with their SHA-256 hashes and the header-only changes (platform, library paths) that make them load on iPadOS. The recipe holds no vendor bytes. `scripts/audit-agepad-base.py` checks the base app against the full game and Steam installs (whole files and code sections): **0 matches**.
2. **Add your own copy (on your Mac, about 6 seconds).** PadMint, or `scripts/agepad-ipad.sh inject AgePad-vX.Y.Z-ios-unsigned.ipa`, reads your Steam install of the Mac game and Steam for Mac, checks every file against the recipe, applies the recorded header changes and writes `generated/AgePad-mine.ipa` (71 MB). Plain Python 3 (macOS offers to install it the first time): no Xcode or Apple account needed for this step. Code and data stay byte-identical to your own files. Mismatched game or Steam versions are refused with a clear message.

3. **Sign and install** with your signing method (see "Memory" below): Sideloadly or AltStore, or, with a paid account and the memory capability, `scripts/sign-agepad-ipa.sh AgePad-mine.ipa <iPad ID> [your app ID]`, which signs with the Mac's own tools and installs.
4. **Copy the game data** (about 20 GB): connect the iPad, open it in Finder → Files, and drag the `AgeOfEmpires2Data` folder (Steam → Age of Empires II: DE → Manage → Browse local files) onto AgePad. Or `scripts/agepad-ipad.sh sync`. AgePad checks the copy is complete (file count and size) before starting the game, and shows progress if it isn't.
5. **Open AgePad and sign in to Steam once** with the QR code.

## Verified on the iPad Pro 12.9-inch (26 September 2026)

- Base app → inject → re-signed the way a sideloading tool does (every program signed again) → installed → signed in to Steam, loaded a save, gave orders, 120 fps.
- The injected app matches the normal build file for file, apart from code signatures.
- The copy check recognises a complete game folder and ignores Steam's small cache files.

## Memory: the one real limit

The game asks for more memory than iPadOS gives an app by default. Apple's *increased memory limit* capability raises the limit from 5.1 GB to 8 GB on the tested iPad.

| Signing | Memory limit | Five-player match |
|---|---|---|
| Paid Apple Developer account (99 USD/yr) with the capability | 8 GB | Plays normally (about 4.6–4.9 GB used) |
| Without the capability (what free Apple IDs are expected to get) | 5.1 GB | Loads and plays at 120 fps, but only about 350 MB spare, shrinking about 11 MB a minute; tested 9 minutes without a close, so longer matches will likely be closed by iPadOS |

Free Apple IDs (AltStore, SideStore, Sideloadly) generally can't get the capability, and their apps need re-signing every 7 days. So the **recommended** way is a paid developer account; a free account is "try it, short matches". Reports from free-account users are welcome.

## Other limits

- A base app matches one game build and one Steam version, so each game patch needs a new base app release.
- Missing-file and version-mismatch errors list up to five distinct files and say
  how many more were omitted. This does not relax the recipe's compatibility checks.
- A Mac with Steam is needed once, to get the Mac game files.

## Installed-input development

The next PadMint recipe declares this as a private build input discovered in the
local installation (`schema_version: 2`, `when: build`, `selection: installed`). It requires PadMint's
installed-input support, built on [PR #177](https://github.com/chrissotraidis/padmint/pull/177).
This is a source-only change for the next release; the public v0.1.0 recipe still
uses the older no-file-chooser declaration. No game or Steam files are uploaded,
and this route is not eligible for a GitHub-hosted build.

For local development with matching copies in other folders, the Python injector
accepts `--game` (the Mac game's `Contents` folder), `--steam` (Mac Steam's
`Contents/MacOS` folder), and `--steamapps` (the folder containing
`appmanifest_813780.acf`). It preserves the base IPA's archive metadata and the
recorded permissions of injected files, independently of the host filesystem.
Synthetic portability tests do not establish a Windows player route: a Windows
Steam installation does not supply the required Mac binaries, and an actual
private-input Windows build has not been validated. These folder options are manual preparation only; there is no current Windows PadMint route. Host support remains Mac-only.

The synthetic Windows injection checks also use Japanese folder names and
explicitly disable Python's UTF-8 mode. The CLI writes UTF-8 so reporting a
successful output path does not turn the build into an encoding failure.
On 26 October 2026, a Windows check using the actual installed Mac files and the
published v0.1.0 base correctly refused six changed Steam binaries while
preserving the previous output. The game files and build number matched that
base. This verifies the version guard; a successful private Windows injection
still requires the exact matching Mac Steam files.

## Ruled out

| Route | Why not |
|---|---|
| App Store / TestFlight | Contains or depends on vendor code |
| Public full IPA | Redistributes Microsoft's and Valve's software |
| Base app that downloads the game program later | iPadOS won't load code that isn't in the signed app |
| Streaming (Steam Link etc.) | Needs a computer switched on; not native |
