# Cooldown Master

[![Support on Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=flat-square&logo=ko-fi)](https://ko-fi.com/wheelbarrel00) [![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal)](https://www.paypal.biz/wheelbarrel00) [![Join our Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/vm8K2WfQUE) [![Version](https://img.shields.io/github/v/release/wheelbarrel00/CooldownMaster?color=6D0501&label=Version&style=flat-square)](https://github.com/wheelbarrel00/CooldownMaster/releases) ![WoW Midnight](https://img.shields.io/badge/WoW-Midnight12.0-8B0000?style=flat-square) ![WoW Classic Era](https://img.shields.io/badge/WoW-ClassicEra1.15-8B0000?style=flat-square) ![WoW TBC](https://img.shields.io/badge/WoW-BurningCrusade2.5-8B0000?style=flat-square) ![WoW MoP](https://img.shields.io/badge/WoW-MoP5.5-8B0000?style=flat-square) ![Interface](https://img.shields.io/badge/Interface-120100-333333?style=flat-square) [![License](https://img.shields.io/github/license/wheelbarrel00/CooldownMaster?style=flat-square&color=333333)](https://github.com/wheelbarrel00/CooldownMaster/blob/main/LICENSE)

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

### Text

- **Icon labels** — a line of tag-built text on each lane or ready-box icon
  (`[cd.name]`, `[cd.type]`, and `[cd.time]` on Classic), anchored above, on, or
  below the icon.
- **Status line** — one line of live text per lane, bar frame, or ready box, built
  from global tags: `[cd.next]`, `[cd.count]`, `[player.class]`, `[player.name]`,
  `[target.name]`, `[target.class]`, plus `[player.hp.pct]` and
  `[player.power.pct]` on Classic.
- **Click-to-insert tag picker**, context-aware — the per-cooldown tags are offered
  on icon labels, the global tags on status lines. Templates with only static tags
  resolve once instead of every frame.

> Retail note: `UnitHealth` and `UnitPower` return secret values under Midnight's
> secret-value model (even out of combat), so health and power tags are offered on
> the Classic flavors only. `[cd.time]` is Classic-only for the same reason — on
> retail the icon's native countdown draws it instead.

### Tracking

- **Custom cooldowns** — define your own tracked cooldown from a fixed duration
  plus a trigger (a spell you cast, or a buff you gain). Runs on a purely local
  timer, so it works for anything the cooldown API doesn't expose. Aura triggers
  have a **Detect** button that captures the next buff you gain, so you never have
  to go hunting for an aura ID.
- **Per-category filters** (spells, utility, buff bars, buffs, potions, trinkets,
  offensives, pet spells, custom) with per-spell overrides for visibility, lane, bar,
  ready box, important, and pinned — plus **Set All** buttons to bulk-apply a
  category's routing to every cooldown in it at once. Every category is tracked by
  default except **offensives**, which is opt-in.
- **Consumables and trinkets** — potions/flasks are auto-discovered from your
  bags and equipped on-use trinkets (slots 13/14) are tracked.
- **Pet spells** — your pet's abilities (Spell Lock, Axe Toss, Gnaw, Freeze and the
  rest) are discovered from the pet spellbook and tracked like any other cooldown.
- **Offensives** — your damage-over-time effects on your current target, timed by
  aura duration instead of by a cooldown, so a dot travels the lane and pops a ready
  box when it falls off and wants recasting. Discovered as you apply them; refreshes
  re-anchor. Tracking follows your target, so swapping targets clears the lane. On
  retail this is **cast-driven** — a target's auras are secret in combat, so identity
  comes from `UNIT_SPELLCAST_SUCCEEDED` rather than from reading the target. A
  per-spell **Remove (X)** button clears a dot that got learned off a shared target
  dummy.
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
  icon labels, status lines, and frame name tags.
- **Masque** — optional icon skinning. CooldownMaster registers three groups you can
  skin or disable independently in Masque's own options: **Lane Icons**, **Ready
  Icons**, and **Bar Icons**. Skinning is opt-in per group, so nothing changes until
  you pick a skin. While a group is skinned, its skin owns the icon border and crop,
  so CooldownMaster's own icon border and zoom step aside for it.
- **Scale** — one slider resizes every lane, bar, and ready box together (0.5x-2x)
  while keeping each frame anchored where it is; a second scales the options window
  itself.
- **Class colors** — a per-class color table, flavor-aware (13 classes on retail, 11
  on MoP, 9 on Era/TBC), feeding the lane fill and bar fill "use class color" toggles.
- **Profiles** — per-spec auto-switch, import/export to a copy-paste string, and
  standard AceDB profile management.
- **What's New popup** — a short digest after an update, with a quiet chat-link
  mode or off entirely.

## Planned

- Classic offensive (dot) tracking — Offensives is retail-only today.

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
every subcommand above (e.g. `/cdmaster lock`). A set of diagnostic subcommands
exists for troubleshooting the engine: `debug`, `api`, `spells`, `haste`,
`tracking`, `anchor`, `seedtest`, `curvetest`, `items`, `buffs`, `petprobe`, and
the offensives probes (`off`, `offprobe`, `offreset`, `auraprobe`, `auraapi`).

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
