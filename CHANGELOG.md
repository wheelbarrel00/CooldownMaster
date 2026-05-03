# Cooldown Master Changelog

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
