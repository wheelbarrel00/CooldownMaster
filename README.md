# Cooldown Master

A **timeline-style lane** cooldown tracker for World of Warcraft. Designed to
complement Blizzard's built-in Cooldown Manager (which already covers icon,
bar, and ready-notification displays natively) by providing the one display
the built-in does not: a horizontal lane where each tracked spell's icon
travels at a speed proportional to its own cooldown, so abilities visually
fan out by urgency.

Supports **Midnight (retail 12.0+)**, **Classic Era**, and **Burning Crusade
Classic**, with first-class integration for panel addons like Titan Panel,
Bazooka, and ChocolateBar.

> Inspired by CooldownTimeline2 (cliffclive / Vreenak), but a clean-room
> rewrite — no copied code.

## Status

`v0.3.0` — scope refocused. Cooldown Master no longer tries to replicate
Blizzard's built-in icon, bar, or ready-notification displays — those work
fine out of the box. Instead the addon is now squarely focused on the lane
timeline: per-spell time mapping, smooth 60 Hz icon motion, configurable
stacking, timeline markers, and per-lane appearance/icons/stacking/text
controls. Filters, Colors, Profiles, and Import/Export tabs are next on the
roadmap.

The engine itself (curve-evaluation architecture from the BCM/TweaksUI
Cooldowns research; sidesteps the Midnight 12.0 secret-value taint entirely)
is unchanged and continues to drive lane rendering at 10 Hz with persistent
duration learning via SavedVariables.

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
