# Libs

This folder is empty in the source repo. Libraries are either:

1. Pulled in by the BigWigs packager via `.pkgmeta` at the repo root, or
2. Copied here manually for local development.

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

## Quick local setup

Download each of the above from CurseForge, or let the packager fetch them by
running a build from `.pkgmeta`.
