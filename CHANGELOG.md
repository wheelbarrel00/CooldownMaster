# Cooldown Master Changelog

## 0.4.0 — Filters

The Filters tab is now functional. Users can decide which discovered spells, items, buffs, and debuffs render in lanes, and override per-spell lane routing on a case-by-case basis.

### New Features
- `Filters > Defaults` sub-tab: per-category Enabled toggle, Show by Default flag (controls whether brand-new discovered spells start visible), Ignore Threshold slider, and Default Lane dropdown.
- `Filters > Spells / Items / Buffs / Debuffs` sub-tabs: scrollable list of every spell the engine has discovered for that category, each row with an icon, spell name, visibility checkbox, and per-spell lane dropdown ("Default" or Lane 1/2/3).
- Three-layer visibility model in the engine: category-enabled → per-spell override → category `showByDefault` fallback.
- Per-spell lane override stored in `spellOverrides[spellID].lane`; falls back to `filters[category].defaultLane`, then the engine's hardcoded category default.

### Bug Fixes
- Multi-lane rendering: the entries loop now correctly gates each entry by its resolved `laneIndex`, so spells only appear in the lane they're routed to. Previously every spell rendered in every enabled lane (latent bug — only invisible because most users ran a single lane).

### Migration
- `MigrateV030` extended to fold the legacy `perSpellRouting[spellID] = laneIndex` map into `spellOverrides[spellID].lane`, then strip the obsolete `perSpellRouting` key. Idempotent.

### Not yet implemented
- Filters sub-tabs for Offensives, Pet Spells, and Custom render a "Coming in v0.5" placeholder. Custom in particular requires an "add spell ID by hand" input flow, which is a feature unto itself.

## 0.3.0 — Scope refocus: lanes only

Realized that Blizzard's built-in Cooldown Manager already covers the icon,
status bar, and "ready" notification use cases natively. What it does not
provide is a timeline-style **lane** display. Cooldown Master is now refocused
on that one job — and on doing it well.

### Removed
- Bar Frames feature and all related UI (`UI/BarFrames.lua` deleted, Bars tab
  removed from the options panel).
- Ready Frames feature and all related UI (`UI/ReadyFrames.lua` deleted, Ready
  tab removed from the options panel).
- Engine hook that fired ready transitions (no longer needed).
- `defaultBar` and `defaultReady` filter-routing fields (lanes only now).
- Sound enumeration helper from the options panel (was only used by Ready).

### Migration
- `OnInitialize` runs a one-time SavedVariables cleanup that strips the
  orphaned `barFrames` / `readyFrames` blocks and the obsolete
  `defaultBar` / `defaultReady` keys from each filter category. Idempotent —
  safe to run repeatedly. Nothing for users to do; just `/reload` after
  upgrading.

### Kept and unchanged
- Lanes tab (General, Appearance, Icons, Stacking, Text sub-tabs).
- Global, Filters, Colors, Profiles, Import/Export, Changelog tabs.
- Curve-evaluation cooldown engine and persistent learning.
- LibDataBroker launcher, minimap button, slash commands.

## 0.2.0 — Engine cracked

Cooldown engine is live. Cracked the Midnight 12.0 secret-value problem by
routing all numeric math through Blizzard's privileged
`DurationObject:EvaluateRemainingDuration()` method (curve-evaluation
architecture, originally explored in the BetterCooldownManager and TweaksUI
Cooldowns research). The addon now produces real countdown values for tracked
spells without ever touching tainted secret values directly.

### New Features
- `Core/Engine.lua`: full curve-evaluation pipeline. Builds a Linear progress
  curve and a Step ready curve once at login, then per tick calls
  `dObj:EvaluateRemainingDuration(curve, default)` for every tracked spell.
- Hardcoded fallback duration table for 23 Paladin spells (Retribution focus)
  plus universal items like Hearthstone — used only when no learned duration
  exists.
- Persistent learning via SavedVariables: each spell only needs to be observed
  once (ever) for its true talent-adjusted duration to be remembered across
  `/reload` and login.
- Three-tier resolution hierarchy:
    1. Direct read via `EvaluateRemainingDuration` (most accurate, talent-aware).
    2. Cache extrapolation from a stored `cdStart`/`cdDuration` pair (used in
       combat when the curve method is unavailable).
    3. Fresh-cast inference via `UNIT_SPELLCAST_SUCCEEDED` (last resort, learns
       new spells the moment the player casts them).
- Diagnostic counters (`_curveEvalSuccess`, `_curveEvalFail`, `_fallbackUsed`)
  for verifying which strategy is firing in live play.

### Not yet implemented (next milestones)
- Stacking renderer in `UI/Lanes.lua` (defaults, options form, and hover-raise
  scripts are in place — only the `GROUPED` placement algorithm is missing).
- Bar frame status bar pool with transition animation.
- Ready frame fade animation and sound playback.
- Tab content: Lanes, Ready, Bars, Filters, Colors, Profiles, Import/Export, Changelog.
- Per-spell overrides, custom spell entry, import/export via LibDeflate.
- Fallback duration tables for the remaining 12 classes.

## 0.1.0 — Scaffolding

First playable build. Loads cleanly on Mainline (Midnight 12.0+), Classic Era,
and TBC Classic. The structural skeleton is in place; engine and tab content
are filled in incrementally from here.

### Implemented
- Project layout: `Core/`, `UI/`, `Libs/` with `.pkgmeta` and three TOC files.
- Ace3-based addon object, account-wide `AceDB` profile.
- Slash commands: `/cdmaster`, `/cdmaster lock`, `/cdmaster unlock`, `/cdmaster test`, `/cdmaster reset`, `/cdmaster version`.
- LibDataBroker launcher with left/right/middle click actions, plus minimap
  button via LibDBIcon (visible in Titan Panel, Bazooka, ChocolateBar).
- Themed options panel (red `#6D0501` tabs, yellow `#EBB706` text), with
  horizontal tab bar across the top.
- Global tab populated as a working example (Always / In Group / In Instance,
  Unlock Frames, Auto-hide, Tooltips, Shared CDs, Tint Unusable, Test button).
- Lane / Bar Frame / Ready Frame stub frames spawn on PLAYER_ENTERING_WORLD.
- Flavor-aware compatibility layer (`Core/Compat.lua`) gating Cooldown Manager
  hooks behind `HAS_BLIZZ_CDM`.

### Not yet implemented (next milestones)
- Cooldown engine: subscribing to Blizzard's Cooldown Manager on retail and
  legacy spell-cooldown polling on Classic / TBC.
- Lane icon rendering and timeline layout (the actual moving icons).
- Bar frame status bar pool with transition animation.
- Ready frame fade animation and sound playback.
- Tab content: Lanes, Ready, Bars, Filters, Colors, Profiles, Import/Export, Changelog.
- Per-spell overrides, custom spell entry, import/export via LibDeflate.
