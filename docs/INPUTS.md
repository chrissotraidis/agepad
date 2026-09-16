# Input intake

Input `hd-774da3b16ce26b67`: supplied Windows installed-folder layout, 11,777 files, 4,795,221,634 bytes. Manifest SHA-256 `774da3b16ce26b67d9561a1705d11f3760b586e96f5d57684362774fdbb8b933`. Original and separate APFS-cloned snapshot hashes match; originals not modified. Private file manifests, paths and headers are in ignored storage.

Edition confidence: high for HD/2013, supported by `AoK HD.exe`, `221380_install.vdf`, resources/_common layout, HD localization and DAT files with decompressed `VER 5.7` headers. EXE header is PE x86 (machine 0x14c), with file/product version resource 5.8.0.0. Exact retail/Steam build remains unverified; no supplied appmanifest establishes a Steam build. Executable not run. No other edition supplied in the authorized root.

Languages present: br, de, en, es, fr, it, jp, ko, nl, ru, zh. English selected for the first probe. Both x1/x2 DAT files and all assets retained. Installed expansion entitlement, mods and provenance beyond user supply remain unknown; installed filenames do not establish rights or exact compatibility.

Observed campaign files include kings cam1–cam4/cam8.cpn and conquerors xcam1–xcam4.cpx. Native probe decoded DAT, palette, original HD home UI and cam8.cpn entry 0; PNG terrain/fog/HUD/scenario text rendered. Terrain blend correctness, complete unit/media coverage and audible audio remain unverified. A full file tree and manifest do not prove the installation is complete relative to a retail depot.

Route: R1 freeaoe; ruleset target aok-aoc-classic-candidate-v1. Initial authentic scenario candidate: cam8.cpn entry 0, to be identified by parser. Known loader path mismatch must be handled in the adapter, without relocating/mixing originals. No additional input is required for the current host probe.
