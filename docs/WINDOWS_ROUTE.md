# AgePad without a Mac: findings and plan

AgePad's build compiles nothing. `scripts/agepad-kit.py inject` copies the
player's own Mac game files and eight Steam for Mac libraries into the published
base app, rewriting a few library headers. That step is plain Python, so the
only things tying it to a Mac are where those files come from.

## The Steam files (fixed here)

The v0.1.0 recipe pins the Steam files from the player's installed Steam. Steam
updates itself, so on 31 October 2026 six of the eight no longer matched: on a
Mac with Steam installed, `ipcserver`, `crashhandler.dylib`, `libaudio.dylib`,
`libtier0_s.dylib`, `libvstdlib_s.dylib` and `steamclient.dylib` all differed
(only the two Breakpad files matched). `inject` then stops with "a different
version". The game files themselves still matched: all 652 at build 25464371.

Valve's client update server publishes Steam for Mac as content-addressed
packages that any computer can download, and older packages stay available.
`config/steam-mac-client.json` pins client 1792618285's `bins_osx`,
`bins_client_osx` and `breakpad_osx` packages and the eight files, and
`scripts/fetch-steam-mac.py OUTPUT` downloads, checks and extracts them with the
Python standard library. No Steam login is needed.

Checked on a Mac: with these files and the installed game, `inject` produced a
71 MB personal IPA from a copy of the v0.1.0 base app whose recipe was updated
to the new Steam hashes. The header edits applied to the newer binaries, and
every library each one loads is either in its recorded dependency map or a
sibling Steam library in the same folder. The resulting app has not been run
on an iPad, so the newer Steam client is not yet known to work at runtime.

## The game files (next)

On Windows, Valve's SteamCMD can download the Mac edition with the player's
own Steam account: `+@sSteamCmdForcePlatformType macos`, then
`download_depot 813780 <depot> <manifest>` for the exact build AgePad expects.
The player types their own login into SteamCMD; PadMint never sees it. This
step is not implemented or tested yet. `inject` would also need to accept a
build number instead of reading Steam's install record.

## To ship

1. Play a personal build made with client 1792618285's files on an iPad.
2. Publish a base app whose embedded recipe pins those hashes, and run
   `fetch-steam-mac.py` before `inject` in `padmint.json`. This fixes the Mac
   route for players whose Steam has updated.
3. Add the SteamCMD game download and Windows hosts to the recipe.
