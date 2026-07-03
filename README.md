# Cooldown Master

A **timeline-style lane** cooldown tracker for World of Warcraft. Its signature
display is a horizontal (or vertical) lane where each tracked spell's icon
travels toward the "ready" end at a speed proportional to its own cooldown, so
your abilities visually fan out by urgency — the one view Blizzard's built-in
Cooldown Manager does not provide. On top of the lane it adds its own
ready-notification popups, per-category filtering, icon stacking, and per-spec
profiles.

Supports **Midnight (retail 12.0+)**, **Classic Era**, and **Burning Crusade
Classic**, and registers a LibDataBroker launcher + minimap button so panel
addons like Titan Panel, Bazooka, and ChocolateBar pick it up automatically.

> **Cooldown Master** carries forward the idea behind **CooldownTimeline2
> (CDTL2)** by cliffclive / Vreenak. After Midnight changed how cooldowns work,
> I rebuilt the concept from the ground up for 12.0 with the original author's
> blessing — full credit for the original timeline-cooldown idea goes to him.

## Midnight 12.0 and the secret-value API

The interesting part for other addon authors. Under Midnight, every cooldown
*number* is a **secret value** in combat: `C_Spell.GetSpellCooldown`'s
start/duration, the `DurationObject`'s `GetRemainingDuration`/`GetTotalDuration`,
and even curve evaluation all return taint-protected secrets that error the
moment you read or compare them in Lua (`issecretvalue()` is the detector). The
only combat-readable signals are `C_Spell.GetSpellCooldown(id).isActive` /
`.isOnGCD` (plain booleans) and `maxCharges`.

Cooldown Master works around this with a hybrid approach:

- **Exact swipe + countdown text** come from feeding the opaque `DurationObject`
  straight into a native `Cooldown` widget via
  `Cooldown:SetCooldownFromDurationObject` — Blizzard's widget consumes the
  secret internally, so the timer is exact even though the addon can never read
  the number.
- **Icon position** on the lane is self-extrapolated from each spell's true
  duration, learned out of combat (where numbers read normally) and persisted
  across sessions via SavedVariables, plus an in-combat wall-clock observation
  layer for anything not yet learned.
- **Spell discovery** uses the `C_CooldownViewer` category sets, and on/off is
  driven entirely off the readable `isActive`/`isOnGCD` booleans.

(Earlier versions of this README described a curve-evaluation engine that
"sidesteps the taint." That turned out to be a dead end — curve results stay
secret too; see `docs/EXPERIMENTS.md`.)

## Features

- **Timeline lanes** (up to 3), horizontal or vertical, with linear,
  shared-timeline, or logarithmic spacing; smooth 60 Hz icon motion.
- **Ready-notification popups** (up to 3 boxes) with per-spell "important"
  highlight, pinning, sounds, and a post-combat linger.
- **Icon stacking** — grouped rows or spread-apart — so clustered cooldowns stay
  readable.
- **Per-category filters** (spells, utility, buffs, debuffs, potions, trinkets)
  and per-spell overrides for visibility, lane, ready box, important, and pinned.
- **Consumables and trinkets** — potions/flasks are auto-discovered from your
  bags and equipped on-use trinkets (slots 13/14) are tracked.
- **Shared-cooldown dedupe** — abilities tracked under multiple spell IDs
  collapse to a single lane icon and a single ready pop.
- **Appearance** — icon zoom, unusable-icon tint/desaturate, configurable
  countdown font, and a cooldown-swipe tint control.
- **Profiles** — per-spec auto-switch, import/export to a copy-paste string, and
  standard AceDB profile management.

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

| Command            | Action                                       |
| ------------------ | -------------------------------------------- |
| `/cdmaster`        | Open / close the options panel               |
| `/cdmaster lock`   | Lock all frames                              |
| `/cdmaster unlock` | Unlock all frames for repositioning          |
| `/cdmaster test`   | Toggle test mode (fake cooldowns for layout) |
| `/cdmaster reset`  | Reset all settings (requires `/reload`)      |
| `/cdmaster version`| Print version + flavor                       |

`/cooldownmaster` is also accepted as the long form. A handful of diagnostic
subcommands (`debug`, `api`, `spells`, `seedtest`, `curvetest`) exist for
troubleshooting the cooldown engine.

## Panel addon integration

The addon registers a LibDataBroker-1.1 launcher and a LibDBIcon-1.0 minimap
button. Titan Panel, Bazooka, and ChocolateBar all pick up the launcher
automatically — just enable "Cooldown Master" in your panel addon's plugin
list.

| Click  | Action               |
| ------ | -------------------- |
| Left   | Open options panel   |
| Right  | Lock / unlock frames |
| Middle | Toggle test mode     |

## License

See `LICENSE`.
