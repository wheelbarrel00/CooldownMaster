# Cooldown Master

A timeline-style cooldown tracker for World of Warcraft. Built fresh from the
ground up to support **Midnight (retail 12.0+)**, **Classic Era**, and
**Burning Crusade Classic**, with first-class integration for panel addons
like Titan Panel, Bazooka, and ChocolateBar.

> Inspired by CooldownTimeline2 (cliffclive / Vreenak), but a clean-room
> rewrite — no copied code.

## Status

`v0.2.0` — engine cracked. The cooldown engine is live (curve-evaluation
architecture from the BCM/TweaksUI Cooldowns research; sidesteps the Midnight
12.0 secret-value taint entirely), with hardcoded fallback durations for 26
Paladin spells, persistent learning via SavedVariables, and a three-tier
resolution path (direct curve read → cache extrapolation → fresh-cast inference
via `UNIT_SPELLCAST_SUCCEEDED`). Most rendering, bar/ready frames, and tab
content are still stubs to be filled in.

## Getting it running locally

The repo doesn't ship the Ace3 / LibSharedMedia / LibDataBroker libraries
themselves — they're pulled in by the
[BigWigs packager](https://github.com/BigWigsMods/packager) via `.pkgmeta`.

You have two options:

### Option A — Run the packager (recommended)

If you've got the packager installed:

```bash
./release.sh
```

This produces `.release/CooldownMaster/` with all libraries fetched into
`Libs/`. Copy that folder into your `World of Warcraft/_retail_/Interface/AddOns/`.

### Option B — Reuse libraries from CooldownTimeline2

If you have a copy of CDTL2 already, copy its entire `Libs/` folder into this
addon's `Libs/` folder, then add `LibDataBroker-1.1/` and `LibDBIcon-1.0/`
from CurseForge. Same library names, same load order, no version conflicts.

After either option, drop the `CooldownMaster/` folder into your AddOns
directory and `/reload`.

## Slash commands

| Command           | Action                                         |
| ----------------- | ---------------------------------------------- |
| `/cdmaster`            | Open / close the options panel                 |
| `/cdmaster lock`       | Lock all frames                                |
| `/cdmaster unlock`     | Unlock all frames for repositioning            |
| `/cdmaster test`       | Toggle test mode (fake cooldowns for layout)   |
| `/cdmaster reset`      | Reset all settings (requires `/reload`)        |
| `/cdmaster version`    | Print version + flavor                         |

`/cooldownmaster` is also accepted as the long form of the same command.

## Panel addon integration

The addon registers a LibDataBroker-1.1 launcher and a LibDBIcon-1.0 minimap
button. Titan Panel, Bazooka, and ChocolateBar all pick up the launcher
automatically — just enable "Cooldown Master" in your panel addon's plugin
list.

| Click          | Action                |
| -------------- | --------------------- |
| Left           | Open options panel    |
| Right          | Lock / unlock frames  |
| Middle         | Toggle test mode      |

## License

See `LICENSE`.
