# Getting AgePad onto an iPad: the IPA route

## The problem

A normal IPA can't be published: the working app contains Microsoft's game program and Valve's Steam software, which aren't ours to give away. iPadOS also runs only code that is inside the signed app, so an app can't download the game program later on its own.

## The route: a public base app plus "add your own copy"

1. **Base app (publishable, about 1 MB).** `scripts/agepad-ipad.sh kit` makes `AgePad-base.ipa`. It holds only AgePad's own code, the icon, and `AgePadKit.json`: a recipe of which game/Steam files go where, with their SHA-256 hashes and the header-only changes (platform, library paths) that make them load on iPadOS. The recipe contains no vendor bytes. An audit of the base app against the full game and Steam installs finds **0 matching files and 0 matching code sections**.
2. **Add your own copy (on the player's Mac, about 6 seconds).** `scripts/agepad-ipad.sh inject AgePad-base.ipa` reads the player's own Steam install of the Mac game and Steam for Mac, checks every file's hash against the recipe, applies the recorded header changes, and writes `AgePad-mine.ipa` (71 MB). It's plain Python, with no Xcode and no Apple account needed for this step. Code and data sections stay byte-identical to the player's own files.
3. **Sign and install.** With any sideloading method: Xcode or `devicectl`, **Sideloadly** or **AltStore/SideStore** (free Apple ID), or a paid developer account. `scripts/sign-agepad-ipa.sh` does it with the Mac's own tools for testing.
4. **Copy the game data** (about 20 GB) into AgePad's storage: `scripts/agepad-ipad.sh sync` over USB-C. (Sideloading tools don't do this part.)
5. **Open AgePad and sign in to Steam once** with the QR code.

What's shared is only AgePad's own work. Each player's app is assembled from files they already own, on their machine, and is only for their devices.

## Verified (26 September 2026)

- The injected app matches the normal Xcode-route build file for file (identical, or differing only in code signatures), across 724 files.
- Re-signing: the in-app Steam module check now also accepts a digest of the module's sections, which a sideloading tool's re-signing doesn't change. The on-device function and the kit produce the same digest for the injected module.
- Still to verify on hardware: installing a re-signed `AgePad-mine.ipa` and playing a match (the iPad was in use by other work).

## Limits

- **Memory.** The game needs Apple's increased memory limit (8 GB instead of about 5 GB on the tested iPad). That is an entitlement in the provisioning profile. With a paid developer account it works (tested). Whether free Apple IDs used by AltStore or Sideloadly can get it is **untested**. If not, the game would be limited to about 5 GB, which is right at what a skirmish uses (up to 4.9 GB measured in a five-player match), so larger or longer matches would likely be closed by iPadOS. A test build without the capability can settle this.
- **Free Apple IDs** need re-signing every 7 days. AltStore/SideStore can refresh automatically; the game data isn't affected.
- **Versions.** A base app matches one game build and one Steam version. `inject` refuses mismatched files with a clear message, so each game patch needs a new base app release.
- A Mac with Steam is still needed once, to get the Mac game files. (Steam's Windows or Linux clients don't install the Mac version by default.)

## Ruled out

| Route | Why not |
|---|---|
| App Store / TestFlight | Contains or depends on vendor code; not allowed |
| Public full IPA | Redistributes Microsoft's and Valve's binaries |
| Base app that downloads the game program later | iPadOS won't load code that isn't in the signed app |
| Streaming (Steam Link etc.) | Needs a computer switched on; not native |

