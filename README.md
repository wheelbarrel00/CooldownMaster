# Cooldown Master

[![Support on Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=flat-square&logo=ko-fi)](https://ko-fi.com/wheelbarrel00) [![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal)](https://www.paypal.biz/wheelbarrel00) [![Join our Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/vm8K2WfQUE) [![Version](https://img.shields.io/github/v/release/wheelbarrel00/CooldownMaster?color=6D0501&label=Version&style=flat-square)](https://github.com/wheelbarrel00/CooldownMaster/releases) ![WoW Midnight](https://img.shields.io/badge/WoW-Midnight12.0-8B0000?style=flat-square) ![WoW Classic Era](https://img.shields.io/badge/WoW-ClassicEra1.15-8B0000?style=flat-square) ![WoW TBC](https://img.shields.io/badge/WoW-BurningCrusade2.5-8B0000?style=flat-square) ![WoW MoP](https://img.shields.io/badge/WoW-MoP5.5-8B0000?style=flat-square) ![Interface](https://img.shields.io/badge/Interface-120007-333333?style=flat-square) [![License](https://img.shields.io/github/license/wheelbarrel00/CooldownMaster?style=flat-square&color=333333)](https://github.com/wheelbarrel00/CooldownMaster/blob/main/LICENSE)

A **timeline-style lane** cooldown tracker for World of Warcraft. Its signature
display is a horizontal (or vertical) lane where each tracked spell's icon
travels toward the "ready" end at a speed proportional to its own cooldown, so
your abilities visually fan out by urgency — the one view Blizzard's built-in
Cooldown Manager does not provide.

Around that it gives you **three display surfaces you can mix freely** — the
traveling **lanes**, depleting **bar frames**, and **ready-notification boxes**
that a cooldown pops into the moment it comes up. Every cooldown can be routed to
any combination of the three, per category or per individual spell.

Supports **Midnight (retail 12.0+)**, **Classic Era**, **Burning Crusade
Classic**, and **Mists of Pandaria Classic**, and registers a LibDataBroker
launcher + minimap button so panel addons like Titan Panel, Bazooka, and
ChocolateBar pick it up automatically.

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

### Displays

- **Timeline lanes** (up to 3), horizontal or vertical, with linear,
  shared-timeline, logarithmic, or split spacing; smooth 60 Hz icon motion.
- **Bar frames** (up to 3) — horizontal status bars that deplete as the cooldown
  runs, with an optional icon, spell name, and live countdown. A conventional
  cooldown-bar list, sitting alongside the lanes rather than replacing them.
- **Ready-notification boxes** (up to 3) with per-spell "important" highlight,
  pinning, sounds, a post-combat linger, and a per-box icon cap.
- **Icon stacking** — grouped rows, spread-apart, offset fan, or emergent overlap
  — so clustered cooldowns stay readable.
- **Secondary tracking** (Classic) — per-lane GCD and swing-timer indicators, as a
  lane fill plus a sliding bar.

### Tracking

- **Custom cooldowns** — define your own tracked cooldown from a fixed duration
  plus a trigger (a spell you cast, or a buff you gain). Runs on a purely local
  timer, so it works for anything the cooldown API doesn't expose. Aura triggers
  have a **Detect** button that captures the next buff you gain, so you never have
  to go hunting for an aura ID.
- **Per-category filters** (spells, utility, buffs, debuffs, potions, trinkets,
  custom) with per-spell overrides for visibility, lane, bar, ready box, important,
  and pinned — plus **Set All** buttons to bulk-apply a category's routing to every
  cooldown in it at once.
- **Consumables and trinkets** — potions/flasks are auto-discovered from your
  bags and equipped on-use trinkets (slots 13/14) are tracked.
- **Shared-cooldown dedupe** — abilities tracked under multiple spell IDs
  collapse to a single lane icon and a single ready pop.

### Appearance and setup

- **Test Mode** — preview your layout with sample cooldowns: pick the type, the
  count (1-20), the duration range they span, and whether they loop. Settings apply
  live, and the samples route through your real Filters config, so what you see is
  what you'll get in combat.
- **Full media control** — every bar, background, border, and font is fed by
  LibSharedMedia, so your own SharedMedia packs work throughout. Ships with a few
  original CDM textures (Gradient, Glass, Soft Edge).
- **Appearance** — per-lane icon borders, icon zoom, unusable-icon tint/desaturate,
  cooldown-swipe tint, and configurable fonts/colors for countdowns, lane markers,
  and frame name tags.
- **Profiles** — per-spec auto-switch, import/export to a copy-paste string, and
  standard AceDB profile management.
- **What's New popup** — a short digest after an update, with a quiet chat-link
  mode or off entirely.

## Planned

- **Offensives** and **Pet Spells** filter categories. Both appear greyed out in the
  Filters list today. They need real data-model work rather than a UI toggle — on
  retail they have to be mapped onto the `C_CooldownViewer` category sets (or the
  combat log, for offensives), and on Classic pet spells need their own spellbook
  scan. They're next up after 1.0.
- **Masque** support for icon skinning.
- A richer text/tag system for lane and bar labels, scoped to the tags that stay
  readable in combat (see the secret-value section above — `[cd.time]` and
  `[cd.stacks]` can't be templated on retail).

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

| Command        | Action                                                 |
| -------------- | ------------------------------------------------------ |
| `/cm`          | Open / close the options panel                         |
| `/cm lock`     | Lock all frames                                        |
| `/cm unlock`   | Unlock all frames for repositioning                    |
| `/cm test`     | Toggle test mode (configure it in Global > Test Mode)  |
| `/cm whatsnew` | Show the What's New popup                              |
| `/cm reset`    | Reset all settings (requires `/reload`)                |
| `/cm version`  | Print version + flavor                                 |

`/cdmaster` and `/cooldownmaster` are the long forms of `/cm` — each works with
every subcommand above (e.g. `/cdmaster lock`). A handful of diagnostic
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
