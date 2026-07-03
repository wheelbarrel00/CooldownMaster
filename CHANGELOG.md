# Cooldown Master Changelog

## 0.16.4 (2026-07-03) — Now on CurseForge

### Improvements
- Cooldown Master is now available on CurseForge.
- Added a Credits section to the in-game About tab acknowledging CooldownTimeline2 (CDTL2) by cliffclive, whose addon inspired this one.

## 0.16.3 (2026-07-03) — Code cleanup

### Maintenance
- Internal code comment cleanup and tidying. No functional, gameplay, or settings changes.

## 0.16.2 (2026-07-02) — Auto-hide keeps your icons

### Improvements
- **Auto-hide Frames** now hides only each lane's background, border, name, and markers; your tracked cooldown icons stay visible out of combat and return with the chrome when you enter combat. Use a lane's Override Autohide to keep its chrome pinned.
- Added plain-language tooltips to the Auto-hide Frames, Override Autohide, and per-category Enabled / Show by Default options, so their effect is clear at a glance.

### Bug Fixes
- Locked lanes no longer capture mouse clicks over their area — clicks now pass through to the game world beneath them.

## 0.16.1 (2026-07-02) — New icon

### Improvements
- **New icon**: now shown on the minimap button, addon list, and data-broker displays.

## 0.16.0 (2026-06-30) — Smoother motion, Split mode, lane highlights, textures, and labels

A pass focused on matching the look and feel of CooldownTimeline2 (with the author's blessing): smoother icon motion, a new Split lane mode, lane highlights, texture options, and editable lane labels.

### New Features
- **Split lane mode** (Lanes > General > Mode): a timeline mode where you set the time curve yourself. Place up to three control points — "a cooldown with this many seconds left sits at this percent along the lane" — to spread imminent cooldowns near the ready edge and compress far ones at the back.
- **Lane icon highlights** (Lanes > Icons > Highlight): spells flagged Important can now stand out on the lane with a Border, Glow, Flash, or Border + Flash style in a color you pick — the same styles the ready frames use. Off by default per lane.
- **Background and border textures** (Lanes > Appearance): the lane background and border are now selectable from any LibSharedMedia texture you have installed, instead of the single built-in fill.
- **Editable lane labels** (Lanes > Text): each of the five lane labels now has its own text and position, so you can rename and reposition the markers (Ready / 25% / 50% / 75% / 100% are just the defaults).

### Improvements
- **Smoother lane motion.** Icons now glide along the lane at sub-pixel precision every frame instead of stepping a whole pixel at a time, so slow-moving cooldowns travel smoothly. Most noticeable on long cooldowns and in Logarithmic mode.
- **Ready-pop fade-in.** Icons popping into a ready frame now fade in softly alongside the existing pop animation, instead of appearing instantly.
- Logarithmic mode does a little less work per frame (no behavior change).

## 0.15.0 (2026-06-24) — Shared-cooldown ready-pop dedupe

### Improvements
- **Detect Shared Spell Cooldowns** now also de-duplicates ready-frame pops. An ability tracked under two spell IDs that share a cooldown (a base spell and its override, or the same ability in two Cooldown Viewer categories) now pops a single ready icon instead of one per ID, mirroring how the lanes already collapse it. Off by default, gated on the same Global option.
- Minor internal code cleanup (comment tidy-up; no behavior change).

## 0.14.1 (2026-06-22) — Charge-spell display hotfix

### Bug Fixes
- Fixed multi-charge spells (such as Roll) not appearing on the lane when fully out of charges. A check added in 0.14.0 was hiding them in every case; depleted charge spells now correctly show their recharge again, while still not flickering on individual charge uses.

## 0.14.0 (2026-06-22) — Icon zoom, unusable tint, and cooldown-tracking fixes

New display options for lane and ready icons, plus fixes for cooldown position and charge-spell tracking.

### New Features
- **Icon Zoom** (Global tab): a slider to zoom lane and ready-frame icons in. 1 = the default look; higher crops the icon border further.
- **Unusable icon tint** (Global tab): tint and/or desaturate icons for spells you currently can't cast (not enough resources, wrong form, and so on), in a color you choose — "Tint Unusable Icons", "Desaturate Unusable Icons", and "Unusable Tint Color".
- **Spread stacking** (Lanes > Stacking): a new stacking style that pushes overlapping icons apart along the lane instead of stacking them into rows, so clustered cooldowns stay readable in sequence.
- **Detect Shared Spell Cooldowns** (Global tab): collapse spells that share a cooldown into a single lane icon instead of showing duplicates.

### Bug Fixes
- Fixed certain cooldowns (such as Rising Sun Kick and Strike of the Windlord) tracking at the wrong spot on the lane. The addon now uses the exact learned cooldown length, re-anchors the timer to each cast, and re-learns lengths that changed in a patch. The countdown number was always correct.
- Fixed multi-charge spells (such as Roll) briefly flashing onto the lane and popping a ready frame on each charge use. They now appear only once you're fully out of charges.

## 0.13.1 (2026-06-22) — Countdown font options and a cooldown-position fix

Customizable countdown text on lane icons, plus a fix for some cooldowns showing at the wrong spot on the lane.

### New Features
- **Countdown font** (Lanes > Icons > Timer Font): set the font face, size, outline, and color of the timer text on each lane's icons. Size 0 = auto, scaling with the icon size.

### Bug Fixes
- Fixed certain cooldowns (such as Supernova and Arcane Orb) sliding to the "ready" end of the lane and staying there while still on cooldown. The addon now learns each cooldown's true length from how long it actually runs, so the icon tracks the right position. The countdown number and swipe were always correct.

## 0.13.0 (2026-06-21) — Logarithmic lane mode and icon stacking

Two new lane display options: a logarithmic timeline mode and grouped icon stacking.

### New Features
- **Logarithmic lane mode.** A new per-lane Mode (Lanes > General) that lays cooldowns out on a logarithmic seconds axis: the last several seconds of any cooldown spread across most of the lane while long cooldowns compress toward the far end, so abilities about to come up are easy to read. Shares the lane's Max Time setting.
- **Grouped icon stacking.** Turn on Stacking (Lanes > Stacking) and lane icons that would overlap are packed into rows instead of sitting on top of each other, within the Height you set and laid out in your chosen Grow Direction. The Raise On Mouseover option brings a stacked icon to the front when you hover it.

## 0.12.0 (2026-06-21) — Profiles, consumables, and visibility fixes

New profile tools, potion and trinket tracking, a cooldown-tint control, and two visibility fixes.

### New Features
- **Per-spec profile auto-switch.** On the Profiles tab, map each specialization to a profile and the addon switches to it when you change spec (and on login).
- **Profile import/export.** Export the current profile to a copy-paste string and import one back, from the Profiles tab.
- **Potion auto-discovery and trinket tracking.** Potions and flasks in your bags are found automatically, and equipped on-use trinkets (slots 13 and 14) are tracked under a new Trinkets filter category.
- **Cooldown Tint slider** (Lanes > Appearance > Icons) to lighten the cooldown darkening so you can see the spell art, or set it to 0 to turn it off.

### Bug Fixes
- Locking the frames no longer hides lanes; it now only disables dragging. Lane visibility follows your Always / In Group / In Instance and Auto-hide settings.
- Using a single potion no longer pops several ready frames at once. Combat potions share one cooldown, so they now show and notify as a single icon.

## 0.11.0 (2026-06-21) — Minimap toggle and icon tooltips

Two new options: a checkbox to show or hide the minimap button, and tooltips when you hover a lane icon.

### New Features
- **Show Minimap Button** checkbox on the Global tab to hide or show the minimap icon.
- **Icon tooltips.** Hovering a lane icon now shows the spell or item tooltip. Turn it on with the "Enable tooltips" option on the Global tab (off by default). While frames are unlocked the icons stay click-through, so you can still drag lanes freely.

## 0.10.2 (2026-06-21) — Stability and performance

A maintenance release: fixes a ready-frame bug on loading screens, cuts memory use when switching profiles, smooths the lane display, and shows release dates in the in-game changelog.

### Bug Fixes
- Fixed every tracked spell flooding the ready frames at once after a loading screen or zone change. The cooldown state the game reports during a loading screen is briefly unreliable; the addon now waits for it to settle instead of treating every cooldown as ready.

### Improvements
- Switching, copying, or resetting profiles no longer leaks frames. Lane and ready boxes are now reused instead of destroyed and recreated, and the About tab is no longer rebuilt each time.
- Lane icons reposition only when they actually move, instead of on every frame, and now keep a stable order so they no longer reshuffle as cooldowns come and go.
- The in-game changelog (About tab) now shows the release date for each version.

## 0.10.1 (2026-06-21) — Combat crash fix

Fixes a Lua error that could spam in combat for multi-charge spells, and adds feedback to the profile creation flow.

### Bug Fixes
- Fixed a repeating "secret number value" Lua error that fired in combat for multi-charge spells (such as Shimmer). The addon no longer reads the protected in-combat charge count; multi-charge spells are detected from their maximum charges instead, so their recharge still shows once the spell is fully on cooldown.
- Creating a profile now gives feedback: it warns on an empty, duplicate, or current name, and clears the box with a confirmation on success.
- Hardened active-profile switching so the dropdown can't tear itself down mid-click.

### Maintenance
- Removed charge-count text code paths that can't work under Midnight's in-combat value protection.

## 0.10.0 (2026-06-21) — Ready Frames parity

Ready Frames gains the full feature set it was known for: spells route to any of the three boxes, important cooldowns can be highlighted, and boxes lay out and animate the way you'd expect.

### New Features
- **Per-box ready routing.** Each Filters category now has a Ready Box setting, and any spell can override it, so ready notifications can be split across boxes 1, 2, and 3 (or turned off per spell) instead of all landing in one box.
- **Highlight for important cooldowns.** Flag a spell as Important (Filters tab) to make its ready popup stand out with a Border, Glow, or Flash style in a color you pick, using its own hold duration and sound. Each box configures these on a new Highlight section.
- **Pinned spells.** Flag a spell as Pinned to keep its ready icon up until the box is rebuilt, instead of fading on the normal timer.
- **More grow directions.** Ready boxes can grow Down, Up, Left, Right, or centered vertically/horizontally.
- **Pop-in flash.** Ready icons now bounce in when they appear.
- **Post-Combat Hide.** An optional per-box timer that clears the box a set number of seconds after combat ends (0 = off).
- **Built-in ready sounds.** The Ready Sound list now includes a few built-in chimes, so you can hear a ready alert without installing extra sound media. Any LibSharedMedia sounds you have are still listed.

### Bug Fixes
- The minimap button's hide state and position now follow profile switches instead of staying stuck on the profile you logged in with.
- Cooldowns first seen during combat no longer keep an approximate resting position after their real length is learned; the icon re-centers once the true cooldown is known. The countdown number was always exact.
- Charge-based spells (Shimmer, Fire Blast) once again appear only when the spell is fully on cooldown, not while a charge is still available. A partial recharge isn't a cooldown, so it no longer shows in a lane or pops a ready frame.

### Improvements
- Ready boxes fade out smoothly when they empty instead of snapping off.

## 0.9.0 (2026-06-21) — Ready Frames

The timeline-style **Ready Frames** display is back, the lane visibility and auto-hide settings now work, lanes gain a Timeline mode, and charge-based spells display correctly.

### New Features
- **Ready Frames.** When a tracked spell or item comes off cooldown, its icon pops into a dedicated on-screen box, holds for a configurable time, then fades. Three independent, movable boxes, each configured on a new **Ready** tab with General / Appearance / Icons sections (size, position, grow direction, hold duration, sound, background, border, alpha). Built on the same combat-safe engine that drives the lanes.
- **Lane visibility** — Always / In Group / In Instance now control when each lane shows, re-evaluated on combat, group, and zone changes.
- **Auto-hide out of combat**, with a per-lane Override Autohide toggle.
- **Lane Timeline mode** — a new per-lane mode that positions every icon by real seconds-until-ready on a shared Max Time axis, so abilities can be compared directly. The default per-spell mode is unchanged.

### Bug Fixes
- Multi-charge spells such as Shimmer and Fire Blast now show their recharge swipe and countdown instead of a blank icon, and appear while a charge is regenerating rather than only once fully depleted.

### Maintenance
- Removed dead code: the unused Bar Frames file, undefined frame-discovery calls and their slash subcommands, and stale diagnostic counters.

## 0.8.1 (2026-06-21) — Some code clean up

Some code clean up.

## 0.8.0 (2026-06-18) — Midnight 12.0.7 compatibility

A maintenance release that brings the retail build current with the latest Midnight patch and tidies packaging metadata on the Classic builds. No gameplay or tracking behavior changes.

### Improvements
- Retail interface compatibility updated to WoW 12.0.7, so the addon loads without the out-of-date warning on the current Midnight patch.

### Maintenance
- Corrected the Author field on the Burning Crusade Classic and Vanilla Classic builds to match the retail build.

## 0.7.0 (2026-06-10) — All-class coverage and a reliability pass

Cooldown position baselines now cover every class and spec instead of just Paladin and Mage, so icons land in sensible places on first sight regardless of what you play. This release also fixes a cluster of Filters and spec-swap bugs, makes test mode actually work, and includes a substantial allocation-reduction pass on the live engine.

### New Features
- Baseline cooldown coverage for all classes and specs. The addon already discovered every class's spells dynamically, but the first-impression icon position relied on a hardcoded duration table that only covered Paladin and Mage; every other class fell back to a flat default until each spell was seen once. Positions are now seeded from the game's own base-cooldown data for whatever you're playing, so icons start in the right place on any class. The countdown number on each icon was already exact in all cases; this improves only the icon's resting position along the lane.

### Bug Fixes
- Filters: spells that Blizzard lists in more than one Cooldown Viewer category (for example an Essential cooldown that is also a tracked buff) no longer get reassigned to the wrong sub-tab. Each spell now keeps its primary category, so it appears in the expected Filters list and routes to the lane you'd expect.
- Filters: the per-category spell lists were a one-time snapshot taken the first time you opened a sub-tab. Opening Filters before spell discovery finished left "No spells discovered yet" stuck for the session, and the lists didn't refresh after a spec change. They now rebuild whenever the spell registry does.
- Test mode now works from all three entry points (the `/cdmaster test` command, the Global tab button, and a minimap middle-click). Previously these printed "Test mode on" but nothing happened, because the toggle never reached the engine.
- Learned cooldown durations now persist between sessions as intended. The save step was never being called, so the addon re-learned every spell from scratch on each login instead of remembering them permanently.
- Changing specialization no longer leaves cooldown positions wrong until a `/reload`. The addon was clearing its learned durations on spec change without reloading the saved and baseline values, so every cooldown briefly extrapolated from a flat default.
- A party member changing spec no longer wipes your own learned durations. The specialization event is now filtered to the player.

### Improvements
- Engine allocation pass. The cooldown scan no longer runs on every frame tick; cooldown changes are caught by game events (cast, cooldown-change, and bag-cooldown for potions) with a low-frequency safety sweep behind them. A cast that fires two events now collapses into a single scan instead of two. Together this removes the bulk of the addon's steady-state memory churn during sustained combat.
- Lane configuration (size, position, colors, markers) is no longer re-applied on every render frame. It is now applied once when a lane is built and again only when you actually change a setting, removing redundant layout work at roughly 30 updates per second across three lanes.
- Dragging the Width, Height, X, Y, or Anchor sliders in a lane's Appearance settings no longer leaks a frame per slider step. These now update the existing lane in place instead of destroying and recreating it.

### Developer notes
- Added `/cdmaster seedtest`, a diagnostic that reports how many of the current spec's tracked spells have a learned, hardcoded, or game-seeded baseline, with sample values to sanity-check against tooltips.
- Duration precedence is now explicit: learned (talent-adjusted, observed out of combat) takes priority over hardcoded fallbacks and game-seeded baselines, which take priority over a flat default. Hardcoded and seeded baselines no longer suppress learning the real value.

## 0.6.0 (2026-05-30) — Combat-accurate cooldowns

A ground-up engine rewrite so cooldowns display correctly in combat under Midnight's "secret value" API restrictions. Previously, in-combat timers were extrapolated guesses that were often wrong; now each lane icon shows the real cooldown swipe and countdown, tracks the true cooldown state, and reads as a continuous clock.

### New Features
- Combat-accurate cooldown display. Under Midnight, addons can no longer read remaining cooldown time in combat — it is a protected value. Each lane icon now renders Blizzard's native cooldown swipe and countdown, fed the cooldown object directly, so the swipe and number stay exact in combat without the addon ever reading the number.
- Real-time lifecycle driven by the live cooldown state: icons appear and clear exactly when the real cooldown starts and ends, including early clears when a proc or talent resets a cooldown.
- Continuous M:SS countdown text (4:59, 4:58, ...), with whole seconds under a minute, instead of the default that collapses to bare minutes like "4m". Applies to spells and potions.

### Improvements
- Engine performance: replaced the per-tick numeric cooldown poll with an event-driven model keyed on cooldown-state changes (`SPELL_UPDATE_COOLDOWN` / `UNIT_SPELLCAST_SUCCEEDED`), and removed the unused curve-evaluation code from the live path.
- Removed developer chat output that printed on every login and reload ("Engine started", "Tracking N spells", "Curves built"). Engine state is still available on demand via `/cdmaster api`.

### Known limitations
- Icon position along the lane is approximate for haste- or talent-scaled cooldowns: the exact remaining time is unreadable in combat, so position is estimated from the base duration. The countdown number on the icon is always exact.
- Charge-based spells may not show their recharge until fully on cooldown.

### Developer notes
- Added `docs/EXPERIMENTS.md` recording the Midnight secret-value investigation (no readable cooldown number exists in combat; only `isActive`/`isOnGCD` are usable) and the `/cdmaster curvetest` diagnostic that established it.

## 0.5.0 (2026-05-23) — Potions, Mage support, and a performance pass

Adds item-cooldown tracking (potions), extends fallback duration coverage to Mage, and includes a broad allocation-reduction pass across the engine and the lane renderer. Also fixes a load-blocking syntax error and a backdrop live-update bug.

### New Features
- Potions category: the engine now polls a hardcoded list of potion item cooldowns directly via `C_Container.GetItemCooldown`. Items don't come from Blizzard's Cooldown Viewer (which only enumerates spells), so they're tracked in a parallel registry. A new `Filters > Potions` sub-tab lists tracked items with the same icon / visibility checkbox / per-item lane dropdown as spells. Item names and icons resolve asynchronously via `GET_ITEM_INFO_RECEIVED` and update their Filters row in place.
- Mage fallback durations: baseline cooldowns for all three Mage specs (Arcane, Fire, Frost) plus shared utility and defensives, so Mage cooldowns display correctly in combat before each spell has been observed once out of combat. The addon already discovered Mage spells dynamically from the Cooldown Viewer; this fills the in-combat seed gap that previously only covered Paladin.
- The `Filters > Items` sub-tab is relabeled `Utility` to reflect its real contents — Blizzard's Utility-tagged spells (Hammer of Justice, Lay on Hands, etc.), not inventory items. The internal saved-variable key stays `items` for compatibility; actual consumables now live under Potions.

### Bug Fixes
- Fixed a stray token at the end of `Core/Init.lua` that produced a Lua compile error (`'=' expected near '<eof>'`) and prevented the addon from loading at all.
- Backdrop changes (border size, border color, padding) now take effect immediately instead of requiring a `/reload`. Blizzard's `BackdropTemplateMixin` reference-compares the backdrop table and skipped re-applying when the same reference came back; lane code now swaps in a fresh table only when border settings actually change.

### Improvements
- Engine performance: hoisted per-tick `pcall` closures to module-level functions, switched the hot pollers (`PollOneSpell` / `PollOneItem`) to multi-value returns instead of allocating a result table per call, and reused scratch tables (`_seenSpells` / `_seenItems`) across ticks. `SPELL_UPDATE_COOLDOWN` is now debounced so cooldown-change bursts collapse into a single deferred poll.
- Lane renderer performance: pre-built integer/decimal time-string lookup tables to eliminate roughly 450 `string.format` allocations/sec from the per-icon `OnUpdate` and per-tick refresh; extracted the `ApplyConfig` and `Refresh` bodies to module-level functions so their `pcall` wrappers no longer allocate a closure at ~30 Hz across three lanes; the backdrop table is cached for the steady-state case.

## 0.4.0 (2026-05-03) — Filters

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

## 0.3.0 (Undated) — Scope refocus: lanes only

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

## 0.2.0 (2026-05-03) — Engine cracked

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

## 0.1.0 (Undated) — Scaffolding

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
