# Rights status

Updated 1 October 2026.

- **AgePad's own code:** MIT ([LICENSE](../LICENSE)), chosen 27 September 2026: the
  shipped app contains no GPL code, so a permissive licence fits.
- **Third-party code and patches:** [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
- **Game and Steam:** never in the repository or the release. Players add their own
  copies with `scripts/agepad-ipad.sh inject`; the resulting `AgePad-mine.ipa` is
  for their own devices only. `scripts/audit-agepad-base.py` checks each release.
- AgePad is an unofficial fan project, not affiliated with Microsoft, Forgotten
  Empires, Feral Interactive, Valve or Apple.
- **Steam account and permission status:** no approval for this integration is
  documented in the reviewed project materials. Account safety is not guaranteed;
  the personal build modifies Steam client and SDK copies for iPadOS, even though
  their code and data sections are preserved. The absence of vendor files from
  the public base does not resolve permission for those modifications;
  the [Steam account-risk review](STEAM-ACCOUNT-RISK.md) explains the evidence and
  unresolved policy questions. Packaging audits establish neither permission nor
  legal clearance.
