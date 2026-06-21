# Ready Frames — Design & Implementation Spec

_Status: increment 2 (full CDTL2 parity) shipped in v0.10.0. Increment 1 shipped in v0.9.0. Author handoff from CooldownTimeline2 (CDTL2). Drafted 2026-06-21._

## Implementation status

**Increment 2 — full CDTL2 parity (shipped v0.10.0):**
- **Routing resolver** — per-category `readyBox` (in each `filters.<cat>`, default 1) +
  per-spell `spellOverrides[spellID].readyBox` (`nil`=default, `0`=off, `1/2/3`=box).
  `ResolveReadyBox` ([UI/ReadyFrames.lua](../UI/ReadyFrames.lua)) replaces the old
  first-enabled-box loop, so boxes 2 and 3 now receive icons. Filters tab gained a
  per-category "Ready Box" dropdown and a per-spell Ready Box dropdown.
- **Grow directions** — UP/DOWN/LEFT/RIGHT/CENTER_V/CENTER_H, box sized on the
  correct axis (`RelayoutReadyFrame`).
- **Pop-in pulse** — one-shot Scale AnimationGroup (origin CENTER, visual-only so the
  layout anchor is untouched), API-detected (`SetScaleFrom`/`SetFromScale`) + pcall-guarded
  for Classic; replayed every pop.
- **Box-level fade-when-empty** (`BOX_FADE_DUR` 0.3s) + **post-combat linger** (`pTime`,
  default 0 = off; resets on each pop / while in combat). Owned by the box OnUpdate.
- **Highlight** — `highlight.style` Border/Glow/Flash/Border+Flash, per-box
  `highlight.color`, `highlightDuration`, `highlightSound`; a per-spell **important**
  flag selects the highlight hold + sound. GLOW renders as a pulsing additive border
  (we deliberately do **not** use the deprecated `ActionButton_*OverlayGlow` API).
  New **Highlight** sub-tab on the Ready tab.
- **Pinned** — per-spell flag freezes the hold timer; important + pinned are packed into
  one per-spell "Ready Flags" dropdown (bit0 = important, bit1 = pinned). _Limitation:_
  a pinned ready icon clears only on box rebuild (profile switch / box toggle / `/reload`);
  there is no per-icon manual clear yet.
- **Charge-count text** — engine entries now carry `_maxCharges` (`Core/Engine.lua`
  `ScanSpells`); ready icons read `entry._charges`/`entry._maxCharges` (the stub read
  non-existent `entry.charges`/`.maxCharges`, so charge text never showed before).
- **Built-in ready sounds** — `READY_BUILTIN_SOUNDS` exposes a few Blizzard `SOUNDKIT`
  entries (Ready Check / Quest Ding / Raid Warning) at the top of the Ready Sound
  dropdown, so audible defaults need no bundled `.ogg` files. LSM sounds still listed below.

**Still deferred (project-wide media/skinning pass, to keep Lanes consistent):**
- Per-box LSM **textures** (`bgTexture`/`borderTexture` are still dropdown strings;
  boxes use plain `WHITE8x8` like Lanes).
- **Masque** skinning hook for ready icons (Lanes does not skin either).
- Bundling custom CDM `.ogg`/texture asset files.

**Increment 1.1 (2026-06-21, uncommitted):**
- Ready icons no longer show a countdown number (decided: the box is a "it's back" flash, not a timer);
  the internal hold timer still controls how long the icon stays.
- The Ready tab now mirrors the Lanes tab: Box 1/2/3 sub-tabs + a General/Appearance/Icons rail
  (name/enabled/grow/duration/sound; position + bg color + box alpha + border; icon size/alpha/offset/spacing).
- Engine charge-spell fix: a depleted multi-charge spell (e.g. Shimmer) feeds the native widget its
  charge-duration object (chosen via the readable charge count, `maxCharges > 1` and
  `currentCharges < maxCharges`), so the swipe/number render once fully depleted. Single-cooldown
  and 1-charge pseudo-charge spells (Touch of the Magi) are unaffected.
- **Reverted (2026-06-21, user in-game test):** the earlier change that *tracked* charge spells
  while a charge was still regenerating. A partial recharge is not a cooldown, so it must not show
  in a lane or pop a ready frame. Charge spells now track only when **fully depleted** (`isActive`),
  matching the original 0.6.0 behavior. See `audit.md` §3 (resolved by decision).

**Increment 1 — LIVE (the core loop + a config tab):**
- `UI/ReadyFrames.lua` is loaded (added to all 3 TOCs after `UI/Lanes.lua`), seeded via a
  `readyFrame()` factory in `Core/Defaults.lua` (`DEFAULTS.readyFrames`, box 1 enabled by default),
  and `CDM.readyFrames = {}` is initialized. `MigrateV030` no longer strips `readyFrames`.
- Engine dispatch: `ns.ReadyFrames_OnReadyTransition` fires at the spell prune seam (`ScanSpells`,
  gated on `trackedSpells` to avoid spec-swap false pops) and the item seam (`PollAllItems`).
  It honors `Engine:IsSpellVisible` so filtered-off spells don't leak into the box.
- A new **Ready** options tab (after Lanes): per-box Enabled, Frame Name, Icon Size, Grow Direction,
  Display Duration, Ready Sound, Show countdown text; box selector for boxes 1/2/3.
- Empty boxes hide unless frames are unlocked; build/profile/lock paths refresh ready frames.
- Adversarially reviewed (load-safety, tab UI, runtime behavior); two findings fixed.

**Increment 2 delivered all of the below** — see the increment-2 block at the top of
this file. The original deferred list (now done except the media/skinning items):
- ~~Per-category + per-spell routing~~ — done (`readyBox` + Filters dropdowns).
- Grow directions ~~beyond UP/DOWN~~ done; **per-box backdrop/border textures still deferred**
  (media pass — Lanes uses plain `WHITE8x8` too).
- ~~Pop-in pulse, highlight styles, `highlightDuration`/`highlightSound`, post-combat linger
  (`pTime`), `pinned`~~ — all done.
- Sound media — built-in `SOUNDKIT` ready sounds added; **bundling custom `.ogg` files still deferred**.
- ~~Charge-count text on ready icons~~ — done (engine carries `_maxCharges`).
- **Masque** skinning hook — still deferred (Lanes does not skin either).

## What we are building

A **ready-notification** display. When a tracked spell or item finishes its
cooldown, its icon pops into a dedicated on-screen box, does a quick **flash**,
plays a short **sound**, sits there for a configurable number of seconds, then
fades out. There are **three** independent ready boxes (mirroring the three
lanes), each separately placeable, sizeable, and configurable.

This is the feature Blizzard's built-in Cooldown Manager does *not* cover well
and the one CDTL2 was known for. Cliff (cliffclive / Vreenak), CDTL2's author,
stopped maintaining it when Midnight's new cooldown API landed; CooldownMaster
is the clean-room continuation. CDTL2 is the behavioral reference — but its
trigger mechanism does not survive Midnight (see below), so we re-implement the
trigger on CooldownMaster's existing engine.

## The Midnight constraint (why we cannot just port CDTL2)

CDTL2 fires its ready popup from `Cooldown.lua` by subtracting elapsed time from
a cooldown **number** each frame (`currentCD <= 0`, CDTL2 `IconUpdate`
~`Cooldown.lua:1458`). Under Midnight 12.0+, every cooldown remaining-time
number is a **secret value** in combat — unreadable by any path (see
[docs/EXPERIMENTS.md](EXPERIMENTS.md)). CDTL2's whole trigger is therefore
dead-on-arrival in combat.

**CooldownMaster already solved the underlying problem.** The engine tracks the
cooldown lifecycle off the only combat-readable signal,
`C_Spell.GetSpellCooldown(spellID).isActive` (a boolean). An entry is created on
the active edge and **removed the instant `isActive` flips false** — that
active→inactive edge *is* the "spell is ready" signal. No number needed.

- Spell ready edge: prune sweep at the end of `Engine:ScanSpells`
  ([Core/Engine.lua:510-516](../Core/Engine.lua#L510-L516)). The full `entry`
  table (spellID, name, icon, dObj, duration, category, laneIndex) is still in
  hand on the loop variable immediately before `self.entries[spellID] = nil`.
- Item/potion ready edge: identical sweep at the end of `Engine:PollAllItems`
  ([Core/Engine.lua:573-577](../Core/Engine.lua#L573-L577)). Item entries carry
  `itemID`, `kind == "item"`, plain `startTime/duration/endTime`, and **no
  dObj** (item cooldowns are plain numbers, not tainted).
- Test entries are pruned separately in `Engine:Tick`
  ([Core/Engine.lua:625-629](../Core/Engine.lua#L625-L629)).

There is **no callback at either edge today** — entries are silently discarded.
The core new wiring is: dispatch a ready event from these two sweeps (capturing
the entry *before* nil-ing), and never from the bulk-clear paths (`Engine:Wipe`,
`Start/StopTestMode`).

## Decided design (2026-06-21)

| Decision | Choice |
| --- | --- |
| **Routing** — which box a spell pops in | **Per-category default + per-spell override** (mirror CDTL2's `defaultReady`). Each Filters category gets a default ready box; any spell can override to a specific box or off. |
| **Flash** — on pop-in | **One-shot pulse**: the icon briefly scales/brightens when it appears, then settles. Plays once per spell. (Highlight styles below are an additional, optional per-box effect for "important" spells.) |
| **Proc resets** | **Fire on both** natural expiry and proc/talent resets. The engine cannot distinguish them in combat (both are just "no longer `isActive`"), and "it's ready again" is the correct message either way. |
| **Initial scope** | **Full CDTL2 parity** in v1: all grow directions, per-box backdrop/border/textures, post-combat linger, normal vs highlight sounds, multi-text overlays — all ported onto the isActive-edge engine. |

## Architecture & data flow

```
Engine:ScanSpells prune  (Core/Engine.lua:514)  ─┐
Engine:PollAllItems prune (Core/Engine.lua:575)  ─┤→ ns.OnCooldownReady(entry)
Engine:Tick test-expiry  (Core/Engine.lua:627)  ─┘        │  (gated: not Wipe / not test-mode-stop)
                                                          ▼
                                       ns.ReadyFrames_OnReadyTransition(entry)
                                                          │
                          resolve target box from routing (category default / per-spell override)
                                                          │
                          acquire pooled icon in box → set texture/charge text
                          → play one-shot pulse + sound → start hold countdown
                                                          │
                          box OnUpdate: count down hold, fade out last 1s,
                          relayout on removal, post-combat linger (pTime), drag-to-move
```

`ns.OnCooldownReady(entry)` is a thin engine-side dispatcher so the engine has
no hard dependency on the UI layer (guard with `if ns.ReadyFrames_OnReadyTransition then`).

## The three boxes (mirror the Lanes architecture)

Ready boxes copy the Lanes module's proven structure verbatim — same
index-keyed create / pool / ApplyConfig / Refresh quartet. Blueprint from
[UI/Lanes.lua](../UI/Lanes.lua):

- **Live cache array**: `CDM.readyFrames = {}` initialized in
  [Core/Init.lua](../Core/Init.lua) alongside `CDM.lanes` / `CDM.cooldowns`
  (~`Init.lua:11`). _The current stub assumes this exists but it is never set —
  must add it._
- **Idempotent builder**: `ns.ReadyFrames_Build(addon)` loops `1..3`, creates
  each enabled box that does not yet exist (cf. `ns.Lanes_Build`,
  [UI/Lanes.lua:49](../UI/Lanes.lua#L49)).
- **One box** = a named `BackdropTemplate` frame on `UIParent` + an inner icon
  container, a center name label (shown at 0.6 alpha only while unlocked), and
  an index-based icon pool. End creation with an `ApplyConfig` call (Lanes does
  this deliberately, [UI/Lanes.lua:149](../UI/Lanes.lua#L149) — config/layout
  lives only in ApplyConfig, never in the per-tick refresh).
- **Movable/lockable**: reuse Lanes' hand-rolled drag triple
  (OnMouseDown/OnUpdate/OnMouseUp, [UI/Lanes.lua:68-115](../UI/Lanes.lua#L68-L115)).
  Mouse is always enabled; the lock is enforced inside OnMouseDown by checking
  `global.unlockFrames`. **Cursor-scale gotcha**: divide `GetCursorPosition()`
  by the frame's `GetEffectiveScale()` before comparing to frame coords (matters
  for scaled/zoomed boxes). Write `anchor/x/y` back to the box's config on
  mouse-up.
- **Icon pool**: index-based `AcquireIcon(box, i, size)` (cf.
  [UI/Lanes.lua:186](../UI/Lanes.lua#L186)) — return `pool[i]` or lazily build
  one; pool only grows, surplus slots are `Hide()`'d and cleared, never
  destroyed. Icons are reparented/recycled, **never** per-spell created (this is
  also how CDTL2 works — `SetParent`, not new frames).
- **ApplyConfig / Refresh pattern**: extract bodies to module-level named
  functions wrapped by `pcall` with 5s-throttled error printing, so the wrappers
  don't allocate a closure at ~30 Hz × 3 boxes (Lanes does this for GC
  discipline; preserve it — see the project memory on memory efficiency).
- **Backdrop reference-compare gotcha**: `BackdropTemplateMixin` skips
  `SetBackdrop` when handed the same table reference. Cache the backdrop table
  and allocate a fresh one only when a structural field (edgeFile/edgeSize/inset)
  changes; steady-state uses `SetBackdropColor`/`SetBackdropBorderColor` only
  (cf. [UI/Lanes.lua:285](../UI/Lanes.lua#L285)).

## Routing model (per-category default + per-spell override)

Mirror CDTL2's `defaultReady`. Box index convention: `1/2/3` = box, `0` = off.

- **Per-category default**: add a `readyBox` field to each
  `filters.<category>` entry in [Core/Defaults.lua](../Core/Defaults.lua)
  (categories: spells, items, buffs, debuffs, potions, offensives, petspells,
  custom). Suggested defaults echoing CDTL2: offensives/essentials → 1,
  utility → 2, defensives/buffs → 2, debuffs → 3, with anything noisy → 0 (off).
- **Per-spell override**: extend `spellOverrides[spellID]` (today `{ visible,
  lane }`) with `readyBox = nil | 0 | 1 | 2 | 3`. `nil` = use the category
  default; `0` = never pop this spell.
- **Resolution order**: per-spell `readyBox` → category `readyBox` → off.
- **Do NOT reuse the old key name `defaultReady`** — `MigrateV030` actively nils
  `f.defaultReady` ([Core/Init.lua:105](../Core/Init.lua#L105)). Use `readyBox`,
  and remove/guard that strip (see Wiring).
- The current stub only ever targets the **first enabled box**
  ([UI/ReadyFrames.lua:215](../UI/ReadyFrames.lua#L215) loop breaks on first
  match) — this must be replaced with the resolver above so boxes 2 and 3 can
  receive icons.

Options-panel work: surface a "Ready Box" dropdown per category and per spell in
the existing Filters tab, plus a dedicated **Ready** options tab (three sub-tabs
ready1/2/3) mirroring CDTL2's `GetReadySet` and the Lanes appearance tabs.

## Flash, sound & per-icon lifecycle

- **Pop-in pulse (the "flash")**: a one-shot `AnimationGroup` on the icon —
  scale up + brighten over ~0.3s, then settle to normal (non-looping,
  `SetToFinalAlpha`). Played once in `OnReadyTransition` when the icon enters.
  This is the baseline flash for every ready icon.
- **Highlight styles (parity, optional, per-box)**: for spells flagged
  "important" (per-spell override flag), additionally support CDTL2's styles —
  `GLOW` (`ActionButton_ShowOverlayGlow`, retail/Midnight only; verify on
  Classic flavors), `BORDER`, `BORDER_FLASH` and `FLASH` (looping BOUNCE alpha
  pulse 0.2↔1 over 0.5s). These run for the hold duration, distinct from the
  one-shot pop-in pulse.
- **Sound**: `PlaySoundFile(LSM:Fetch("sound", name), "SFX")`, skipped when name
  is `"None"`. Per box: `normalSound` for ordinary spells, `highlightSound` for
  "important" spells. The stub already does the LSM fetch + play, pcall-guarded
  ([UI/ReadyFrames.lua:277-285](../UI/ReadyFrames.lua#L277-L285)) but uses the
  `"Master"` channel — switch to `"SFX"` to match CDTL2/expectations.
- **Hold duration**: stamp `icon._readyTime = box.normalDuration` (default 5s);
  for "important" spells use `box.highlightDuration` (default 10s).
  **Fix CDTL2's bug here**: CDTL2 *always* used `nTime` and ignored `hTime`
  (`hTime` was dead code) — we apply the highlight duration as intended.
- **Removal**: when `_readyTime <= 0` (and not `pinned`), hide the icon, flag a
  relayout. The box recounts visible icons and re-stacks per `growDirection`.
  Individual icons do not fade on removal; the **box** fades out (0.3s alpha)
  when it has zero visible icons.
- **Post-combat linger (`pTime`)**: while out of combat and visible, accumulate
  a `combatTimer`; past `pTime` seconds, force the box to fade out. Reset
  `combatTimer` to 0 on every new ready pop; prime it on `PLAYER_REGEN_DISABLED`.
- **Pinned spells**: a `pinned` per-spell flag freezes `_readyTime` so the icon
  stays until manually cleared (CDTL2 parity).

## Settings / defaults schema

Add a local `readyBox(frameName)` factory in [Core/Defaults.lua](../Core/Defaults.lua)
modeled on the existing `lane()` factory, and seed
`DEFAULTS.readyFrames = { [1]=readyBox("Ready 1"), [2]=readyBox("Ready 2"), [3]=readyBox("Ready 3") }`
as a sibling of `lanes`. Color fields must be `{r,g,b,a}` tables (never scalars).

Per-box fields (CDTL2 parity + the stub's existing reads):

```
enabled        = true            -- box 1 on; 2/3 default off or on per taste
frameName      = "Ready 1"
anchor/x/y     = "CENTER"/-300/-75   -- (box2 +300, box3 0/+100 per CDTL2)
alpha          = 1.0             -- whole-box target alpha (Autohide settles here)
growDirection  = "DOWN"          -- UP / DOWN / LEFT / RIGHT / CENTER_V / CENTER_H
padding        = 0               -- inner padding around the icon block
-- appearance
bgTexture      = "CDM Smooth"
bgColor        = { r=0.15, g=0.15, b=0.15, a=0.5 }
borderEnabled  = true
borderTexture  = "CDM Shadow"
borderColor    = { r=0, g=0, b=0, a=0.25 }
borderSize     = 5
borderPadding  = 5
-- icons
iconSize       = 50
iconAlpha      = 1.0
iconOffset     = 0
xPadding/yPadding = 0/0           -- per-icon spacing when count > 1
iconText       = {                -- fixed 3-slot array (slot1 = charges, slot2 = countdown)
  { enabled = true,  text = "[cd.stacks]" },
  { enabled = true,  text = "[cd.time]"   },
  { enabled = false, text = ""            },
}
-- timing / sound / highlight
normalDuration    = 5            -- nTime
highlightDuration = 10           -- hTime (we honor this, unlike CDTL2)
pTime             = 10           -- post-combat linger
normalSound       = "None"       -- LSM sound key; "None" = silent
highlightSound    = "None"
highlight = { style = "BORDER", color = { r=1,g=1,b=1,a=0.25 }, flash = false }
```

## Required wiring changes (the integration checklist)

The popup module [UI/ReadyFrames.lua](../UI/ReadyFrames.lua) already exists and
is ~90% of the per-box machinery, but it is **dormant**: not in any TOC, not
seeded in Defaults, wiped by migration, and never called by the engine. To
bring it online:

1. **Stop the migration wipe** — [Core/Init.lua:99](../Core/Init.lua#L99)
   (`if p.readyFrames ~= nil then p.readyFrames = nil end`) deletes the config
   on every load *and* every profile switch (`MigrateV030` runs from both
   OnInitialize and ApplyProfile). Remove it. Keep the `barFrames` strip (line
   98). Also remove the per-filter `f.defaultReady` strip
   ([Core/Init.lua:105](../Core/Init.lua#L105)) — but use the new `readyBox`
   key so old `defaultReady` data stays stripped.
2. **Seed defaults** — add the `readyFrames` block to `ns.DEFAULTS`
   ([Core/Defaults.lua](../Core/Defaults.lua)). Without it, the stub nil-errors
   indexing `db.profile.readyFrames[i]`.
3. **Init the live cache** — `CDM.readyFrames = {}` in
   [Core/Init.lua](../Core/Init.lua) (~line 11). The stub writes
   `addon.readyFrames[index]` but never initializes the table.
4. **Load the file** — add `UI\ReadyFrames.lua` to all three TOCs after
   `UI\Lanes.lua` ([CooldownMaster.toc:27](../CooldownMaster.toc), and the
   TBC/Vanilla TOCs which are offset by 2 lines). It depends on Theme/Widgets,
   so it must come after `UI\Theme.lua`.
5. **Build at world-enter** — call `ns.ReadyFrames_Build(self)` in
   `CDM:OnEnteringWorld` ([Core/Init.lua:159](../Core/Init.lua#L159)), next to
   `ns.Lanes_Build`.
6. **Profile switch** — in `CDM:ApplyProfile`
   ([Core/Init.lua:127](../Core/Init.lua#L127)), loop `1..3` calling
   `ns.ReadyFrames_RebuildOne` + `ns.ReadyFrames_RefreshUnlockState`, next to
   the lane rebuild.
7. **Engine dispatch** — add `ns.OnCooldownReady(entry)` calls at the two prune
   seams ([Core/Engine.lua:514](../Core/Engine.lua#L514) for spells,
   [Core/Engine.lua:575](../Core/Engine.lua#L575) for items), firing with the
   entry *before* `nil`-ing. Optionally dispatch test-mode pops from
   [Core/Engine.lua:627](../Core/Engine.lua#L627) so users can position boxes.
   Do **not** dispatch from `Engine:Wipe` / `Start/StopTestMode`.
8. **Options** — restore a Ready options tab (three sub-tabs) and add the
   per-category / per-spell "Ready Box" routing dropdowns to the Filters tab.
   Wire option changes to `ns.ReadyFrames_ApplyConfig` / `_RebuildOne` exactly
   as Lanes does ([UI/Options.lua](../UI/Options.lua) change handlers).
9. **Unlock + DataBroker** — call `ns.ReadyFrames_RefreshUnlockState` wherever
   `ns.Lanes_RefreshUnlockState` is called (DataBroker, Options unlock toggle).

## Gap analysis — what the existing stub already does vs. needs

The stub ([UI/ReadyFrames.lua](../UI/ReadyFrames.lua)) **already has**: 3
movable backdrop boxes, an index icon pool, drag-to-move with the cursor-scale
fix, per-frame countdown OnUpdate, fade-out over the last 1s, RelayoutReadyFrame
(UP/DOWN stacking + box resize), ApplyConfig/RebuildOne/RefreshUnlockState,
charge + time text, and LSM sound playback. It is genuinely close.

It **needs** (to reach parity + the decided design):

- Routing resolver to replace the first-enabled-box-only logic
  ([UI/ReadyFrames.lua:215](../UI/ReadyFrames.lua#L215)).
- The one-shot pop-in pulse (no entry flash today — it only fades out).
- Grow directions beyond UP/DOWN (add LEFT/RIGHT/CENTER_V/CENTER_H).
- Per-box textures/border styling via the appearance fields (today bg/border are
  minimal WHITE8x8).
- `highlightDuration`/`highlightSound`/highlight styles + "important" flag.
- Post-combat linger (`pTime`) and the box-level fade-when-empty.
- Sound channel `"SFX"` not `"Master"`
  ([UI/ReadyFrames.lua:283](../UI/ReadyFrames.lua#L283)).
- Charge fields: the stub reads `entry.charges`/`entry.maxCharges`, which engine
  entries don't populate yet (fails safe to no text). Pairs with the charge-spell
  fix in [audit.md](../audit.md) §3.
- Masque skinning hook (OptionalDep) for icons, to match how Lanes ought to skin.

## Known CDTL2 quirks to NOT copy (fix instead)

- `hTime` was dead code in CDTL2 (`SendToReady` always used `nTime`). We honor
  `highlightDuration`.
- CDTL2's `pTime` option was mislabeled "Pinned Hide Time" but is really the
  post-combat linger; unrelated to the per-spell `pinned` flag. Label it clearly.
- CDTL2's border frame had a latent ownership bug (`if not f.bd` but created
  `f.mf.bd`). Decide border-frame ownership explicitly.
- Highlight `GLOW` uses `ActionButton_ShowOverlayGlow`, which may not exist on
  Classic flavors — guard it.

## Open items

- **Media gap**: CooldownMaster does not register any custom LSM media yet —
  "CDM Smooth"/"CDM Shadow" are only dropdown strings, and the LSM hookup itself
  is pending ([UI/Options.lua:365](../UI/Options.lua#L365)). For ready sounds we
  must either bundle `.ogg` files and `LSM:Register("sound", ...)` them (as CDTL2
  did: ready-click/rattle/tinks), or fall back to Blizzard `SOUNDKIT` IDs via
  `PlaySound`. Decide before shipping audible defaults.
- Confirm per-category default `readyBox` values once the Filters categories'
  intended grouping is settled.
- Decide whether test mode should drive ready pops (recommended for box
  placement UX).
