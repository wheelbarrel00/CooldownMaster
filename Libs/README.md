# Libs

Every library below is committed to this repo, so a fresh clone runs in-game
without any fetch step. At release time the BigWigs packager replaces them with
fresh upstream copies via the `externals` block in `.pkgmeta` at the repo root —
these committed copies serve local development only.

Don't hand-edit anything in here. A packaged build overwrites it.

## Required libraries (load order matches `embeds.xml`)

- `LibStub/`
- `CallbackHandler-1.0/`
- `AceAddon-3.0/`
- `AceEvent-3.0/`
- `AceConsole-3.0/`
- `AceDB-3.0/`
- `AceSerializer-3.0/`
- `LibSharedMedia-3.0/`
- `LibDeflate/` (single `.lua` file)
- `LibDataBroker-1.1/`
- `LibDBIcon-1.0/`

The options panel is hand-rolled, so AceGUI, AceConfig and AceDBOptions are
deliberately not embedded.

## Updating one

Download the new version from CurseForge (or GitHub, for LibDeflate), replace
the folder, and commit it. `embeds.xml` needs a change only if a library's file
list or load order changes.
