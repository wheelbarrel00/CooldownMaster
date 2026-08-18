# Cooldown Master

[![Support on Ko-fi](https://img.shields.io/badge/Support-Ko--fi-FF5E5B?style=flat-square&logo=ko-fi)](https://ko-fi.com/wheelbarrel00) [![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=flat-square&logo=paypal)](https://www.paypal.biz/wheelbarrel00) [![Join our Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/vm8K2WfQUE) [![Version](https://img.shields.io/github/v/release/wheelbarrel00/CooldownMaster?color=6D0501&label=Version&style=flat-square)](https://github.com/wheelbarrel00/CooldownMaster/releases) ![WoW Midnight](https://img.shields.io/badge/WoW-Midnight12.1-8B0000?style=flat-square) ![WoW Classic Era](https://img.shields.io/badge/WoW-ClassicEra1.15-8B0000?style=flat-square) ![WoW TBC](https://img.shields.io/badge/WoW-BurningCrusade2.5-8B0000?style=flat-square) ![WoW MoP](https://img.shields.io/badge/WoW-MoP5.5-8B0000?style=flat-square) ![Interface](https://img.shields.io/badge/Interface-120100-333333?style=flat-square) [![License](https://img.shields.io/github/license/wheelbarrel00/CooldownMaster?style=flat-square&color=333333)](https://github.com/wheelbarrel00/CooldownMaster/blob/main/LICENSE)

A **timeline-style lane** cooldown tracker for World of Warcraft. Its signature
display is a horizontal (or vertical) lane where each tracked spell's icon
travels toward the "ready" end at a speed proportional to its own cooldown, so
your abilities visually fan out by urgency — the one view Blizzard's built-in
Cooldown Manager does not provide.

Around that it gives you **three display surfaces you can mix freely** — the
traveling **lanes**, depleting **bar frames**, and **ready-notification boxes**
that a cooldown pops into the moment it comes up. Every cooldown can be routed to
any combination of the three, per category or per individual spell.

Supports **Midnight (retail 12.1)**, **Classic Era**, **Burning Crusade
Classic**, and **Mists of Pandaria Classic** from one code base, ships in **five
languages**, and registers a LibDataBroker launcher + minimap button so panel
addons like Titan Panel, Bazooka, and ChocolateBar pick it up automatically.

> **Cooldown Master** carries forward the idea behind **CooldownTimeline2
> (CDTL2)** by cliffclive / Vreenak. After Midnight changed how cooldowns work,
> I rebuilt the concept from the ground up for 12.0 with the original author's
> blessing — full credit for the original timeline-cooldown idea goes to him.

## Midnight and the secret-value API

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
"sidesteps the taint." That turned out to be a dead end — step, linear and
identity curves all came back secret.)

### Auras are stricter than cooldowns, and 12.1 tightened them again

A cooldown at least keeps two readable booleans. An aura on your target keeps
almost nothing: in combat its `spellId`, `name`, `icon`, `duration` and
`sourceUnit` are all secret, and every "ask by spell" API
(`GetUnitAuraBySpellID`, `GetAuraDataBySpellName`) returns `nil` outright rather
than a secret — so **you cannot identify a debuff on your target in combat by
any path**. That is why Offensives is cast-driven: the spell ID from
`UNIT_SPELLCAST_SUCCEEDED` stays plain, so identity comes from what you cast
rather than from what you read.

As of **12.1** the `UNIT_AURA` payload itself arrives secret — `isFullUpdate` is
a secret boolean and `addedAuras` a secret table. Two practical notes for anyone
hitting this:

- **A boolean test on a secret *boolean* throws** (`if updateInfo.isFullUpdate
  then` is enough to error), because the single bit is the whole payload. A
  boolean test on a secret *table* or *number* does not throw — truthiness of a
  non-boolean leaks nothing. Check the value type before assuming which you have.
- **`tostring` does not throw on a secret** — it hands back a secret *string*,
  and `string.format` is what dies. Wrapping a read in `tostring` or a `pcall`
  around the producer protects nothing; test the returned value with
  `issecretvalue()`.

Instance-id collections go the same way — `removedAuraInstanceIDs` measures as a
secret table, and `C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL|PLAYER")` is
dropped for the same reason. With no plain reconcile source left, the cast-driven
path stands alone and a wall-clock expiry sweep does the job the reconcile loop
used to.

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
  have a **Detect** button that captures the next buff you gain and fills in its
  ID, name, icon and duration, so you never have to go hunting for an aura ID.
- **Per-category filters** (spells, utility, buff bars, buffs, potions, trinkets,
  offensives, pet spells, custom) with per-spell overrides for visibility, lane, bar,
  ready box, important, and pinned — plus **Set All** buttons to bulk-apply a
  category's routing to every cooldown in it at once. Every category is tracked by
  default except **offensives**, which is opt-in.
- **Consumables and trinkets** — potions, flasks and elixirs are auto-discovered
  from your bags, conjured items (mana gems, healthstones) are recognized by ID on
  every flavor, and equipped on-use trinkets (slots 13/14) are tracked. Classic Era
  reports every consumable under one category with nothing to tell a potion from a
  sandwich, so there it lists them all — food and drink carry no cooldown and never
  draw anything, and can be hidden from the list.
- **Buff tracking on Classic** — a cooldown spell that also grants a self-buff
  (Icy Veins, Arcane Power) can show that buff as its own second icon, via a
  per-spell **Buff** checkbox under Filters > Spells. Opt-in; retail surfaces
  tracked buffs through Blizzard's own category sets instead.
- **Pet spells** — your pet's abilities (Spell Lock, Axe Toss, Gnaw, Freeze and the
  rest) are discovered from the pet spellbook and tracked like any other cooldown.
- **Offensives** — the harmful effects you put on your current target: damage-over-time
  effects, and debuffs like stuns. Timed by aura duration instead of by a cooldown, so
  each one travels the lane and pops a ready box when it drops. Discovered as you apply
  them; refreshes re-anchor. Tracking follows your target, so swapping targets clears the lane. On
  retail this is **cast-driven** — a target's auras are secret in combat, so identity
  comes from `UNIT_SPELLCAST_SUCCEEDED` rather than from reading the target. A dot is
  only ever learned once its source can be positively confirmed as you, so a
  groupmate's dots on a shared target stay off your lanes. As of 12.1 the added-aura
  stream itself arrives secret, so an effect Cooldown Master has not already learned
  cannot be picked up during a fight, and `/cm offlearn` says so and stands down
  rather than pretending. Anything already learned keeps tracking normally. A
  per-spell **Remove (X)** button drops one you no longer want tracked.
  - On the Classic flavors an effect that puts nothing readable on your target — a
    Paladin's Consecration is the clearest case — has its length **learned by
    observation**, from when the combat log reports it ending, and the estimate only ever
    revises upward. So on a fresh install its ready box fires early for the first several
    casts and settles once the effect has run its full course uninterrupted. Measured on
    TBC: 3s, then 5s, then 8s and stable. That is the learning working, not a fault.
- **Shared-cooldown dedupe** — abilities tracked under multiple spell IDs
  collapse to a single lane icon and a single ready pop.

### Appearance and setup

- **Test Mode** — preview your layout with sample cooldowns: pick the type, the
  count (1-20), the duration range they span, and whether they loop. Settings apply
  live, and the samples route through your real Filters config, so what you see is
  what you'll get in combat.
- **Full media control** — every bar, background, border, and font is fed by
  LibSharedMedia, so your own SharedMedia packs work throughout. Ships with a few
  original CDM textures (Gradient, Glass, Soft Edge). Font dropdowns draw each name
  in the font it names, and preview your current pick on the closed dropdown.
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

## Localization

Ships in **English, French, Russian, Korean, and Simplified Chinese** since
v1.10.0, plus a partial **Traditional Chinese**. Translations are bundled in
`Locales/`, selected from `GetLocale()`, and fall back to English per-phrase, so
a partial language renders as itself where it has a translation and as English
where it does not. Simplified Chinese is complete; French, Russian, Korean and
Traditional Chinese are partial and growing.

**`Locales/*.lua` are generated — never hand-edit one.** They are built from the
[EverythingLocales](https://github.com/wheelbarrel00/EverythingLocales) shared
store, which CooldownMaster joined as a third addon alongside Everything Quests
and EQ Objective Tracker. That store keys a translation on its **English phrase**
rather than on any addon, so a phrase CDM shares with the other two arrived
already translated — 45 of them did, in four languages, on day one. Editing a
generated file here is overwritten on the next build, and that repo's drift check
exists to catch exactly that.

`Locales/enUS.lua` is the manifest and creates `ns.L`. It must load after
`embeds.xml` and before `Core\Constants.lua` in all four `.toc` files. `ns.L`
carries an `__index` that returns the key, so a missing phrase degrades to English
rather than erroring.

Run `python docs/_verify_locale.py` (exit 0) alongside `luacheck .` after any
user-facing string change — it checks code keys against the manifest and every
translation for orphans and `string.format` mismatches, without needing the store
repo checked out.

> ⛔ **Displayed does not mean translatable.** A string that is also persisted to
> SavedVariables or used as a lookup key must stay bare English. AceDB `rawset`s
> scalar defaults straight into the saved profile, so a translated default is
> written to disk and outlives a client language change. Dropdowns take
> `{ value = <bare>, text = L["..."] }`, and anything Blizzard already localizes
> should use the Blizzard global instead.

## Planned

- **More languages, and fuller coverage** in the ones already shipped —
  contributions welcome, and no tooling or GitHub account is needed to help.
- **More tracking indicator types** (Classic) — the per-lane secondary tracking
  covers the GCD and your main-hand swing timer today; further indicator types are
  on the list.
- **Conditional autohide** — hide frames on resource level or stealth state,
  alongside the existing out-of-combat and group/instance visibility rules.

## Getting it running locally

Clone it straight into your AddOns folder and `/reload` — every embedded library
is committed to the repo, so a fresh clone runs as-is:

```bash
git clone https://github.com/wheelbarrel00/CooldownMaster.git
```

Drop the `CooldownMaster/` folder into
`World of Warcraft/_retail_/Interface/AddOns/` (or the `_classic_era_`,
`_anniversary_`, or `_classic_` equivalent — the same folder serves every
flavor, and the right `.toc` loads itself).

At release time the [BigWigs packager](https://github.com/BigWigsMods/packager)
re-fetches each library fresh from its upstream via the `externals` block in
`.pkgmeta`, so the committed copies are a convenience for local development, not
the source of truth for what ships.

The options panel is hand-built rather than driven by an AceConfig options
table, so AceGUI, AceConfig and AceDBOptions are deliberately **not** embedded —
don't add them.

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
`tracking`, `cdv`, `seedtest`, `curvetest`, `items`, `bagscan`, `itemcd <id>`,
`buffs`, `petprobe`, `tagprobe`, `masque`, and the offensives probes (`off`,
`offprobe`, `offlearn`, `offreset`, `auraprobe`, `auraapi`).

`anchor` reports the cast-to-re-anchor pipeline, and `anchor arm [seconds] [spell]`
traces one spell's live cooldown state — the quickest way to show what the engine is
actually seeing when reporting a timing bug. `off arm [seconds]` does the same for the
offensives binder, showing why each dot was learned or refused.

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
