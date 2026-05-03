# Libs

This folder is intentionally empty in the source repo. Libraries are either:

1. Pulled in by the BigWigs packager via `.pkgmeta` at the repo root, or
2. Copied here manually for local development.

## Required libraries (load order matches `embeds.xml`)

- `LibStub/`
- `CallbackHandler-1.0/`
- `AceAddon-3.0/`
- `AceEvent-3.0/`
- `AceConsole-3.0/`
- `AceDB-3.0/`
- `AceDBOptions-3.0/`
- `AceGUI-3.0/`
- `AceConfig-3.0/` (with sub-libs `AceConfigCmd-3.0`, `AceConfigDialog-3.0`, `AceConfigRegistry-3.0`)
- `AceSerializer-3.0/`
- `LibSharedMedia-3.0/`
- `AceGUI-3.0-SharedMediaWidgets/`
- `LibDeflate/` (single `.lua` file)
- `LibDataBroker-1.1/`
- `LibDBIcon-1.0/`

## Quick local setup

If you already have CooldownTimeline2 installed, the easiest path is to copy
its entire `Libs/` folder over here, then download just `LibDataBroker-1.1/`
and `LibDBIcon-1.0/` from CurseForge.
