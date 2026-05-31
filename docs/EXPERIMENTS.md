# Engine Experiments Log

A record of things we have actually *tried* against the Midnight 12.0 secret-value
API, and what the result *was* — not what we hoped it would be. Add the outcome
here the moment a test is run, so we never re-litigate a settled question.

Format: one entry per experiment. Always fill in **Result** and **Decision**.

---

## Settled conclusions (2026-05-30)

Proven via `/cdmaster curvetest` (probe v1-v3), every value classified with
`issecretvalue()`:

- **In combat, every cooldown NUMBER is secret.** Raw `GetRemainingDuration` /
  `GetTotalDuration`, `dObj:IsZero()`, and the correctly-called
  `dObj:EvaluateRemainingDuration(curve)` (step / linear / identity) ALL return
  secret values. No readable remaining-time number exists in combat, by any path
  tested.
- **The only combat-readable signals are `C_Spell.GetSpellCooldown(id).isActive`
  and `.isOnGCD`** (plain booleans). Out of combat, everything reads normally.
- **A live, number-positioned timeline is therefore impossible in combat.** This
  is a platform constraint every addon hits, not a CDM bug. Display must route
  through privileged setters (`Cooldown:SetCooldownFromDurationObject`); icon
  position must be self-extrapolated from learned durations + readable on/off
  edges.

Direction chosen: **option C, hybrid variant** (native Cooldown widgets + extrapolated position).

### Implementation (hybrid option C) — 2026-05-30
- `Core/Engine.lua`: the secret-number poll (`PollOneSpell`/`PollAllSpells`) is
  replaced by `ScanSpells`, driven off the readable `isActive`/`isOnGCD`. It
  creates an entry on the active edge (startTime = now, duration = learned/
  hardcoded, so position is extrapolated), stores the opaque DurationObject for
  the renderer, removes entries when `isActive` goes false (so procs/resets clear
  the icon at the true end), and still learns true durations out of combat. Curve
  building remains only for the `/cdmaster curvetest` probe. Tick/SPELL_UPDATE_
  COOLDOWN/UNIT_SPELLCAST_SUCCEEDED all call `ScanSpells`; the dead fresh-cast/
  endTime-prune machinery is gone.
- `UI/Lanes.lua`: each lane icon gained a native `Cooldown` widget
  (`CooldownFrameTemplate`). RefreshBody feeds it once per cooldown instance via
  `SetCooldownFromDurationObject` (spells) or `SetCooldown` (items/test) — so the
  swipe + countdown text are EXACT in combat. Position stays extrapolated and
  clamps at the ready end if the extrapolation underran; the native text is the
  source of truth for time remaining.

Known v1 limits (follow-ups): icon POSITION is approximate for haste/talent-
scaled cooldowns (only the text is exact); charge-spell recharge may not show
until a full cooldown; native countdown text is centered (was bottom-aligned);
`FormatTime` + countdown lookup tables are now unused (retained pending a
custom-text decision); `/cdmaster api` counters are stale.

---

## EXP-001 — Does curve-eval de-taint cooldown values in combat?

**Status:** CLOSED — corrected call (probe v3) returns SECRET for step, linear, AND identity in combat. Curves do not de-taint. Genuine dead end.
**Date opened:** 2026-05-30

### Background
The v0.2.0 changelog ("Engine cracked") claimed the engine routed all numeric
math through `DurationObject:EvaluateRemainingDuration(curve, default)` to avoid
secret-value taint. Git proves this was never true: from the initial commit
(`25e4e84`), `PollOneSpell` has read `GetTotalDuration`/`GetRemainingDuration`
**directly**, and `EvaluateRemainingDuration` exists only in comments and one
"does this method exist" diagnostic. The curve pipeline was documented as a
shipped success but never wired into the poll path. Any earlier hand-test of
curves predates the git history and was never written down — hence this log.

### Question
In **combat**, for a spell on cooldown, which data paths return a usable plain
number versus a taint-protected secret value?

### Method
`/cdmaster curvetest` (`Engine:RunCurveProbe`). For up to 5 tracked spells
currently on cooldown, it classifies each path with `issecretvalue()` — the
canonical detector (Skiron uses it at `Modules/resourcebar.lua:354`) — so each
path reports a definitive `SECRET` / `<number>` / `nil` / `ERR`.

Paths tested, on both `GetSpellCooldownDuration(id)` (A) and
`GetSpellCooldownDuration(id, true)` (B):
- raw `GetRemainingDuration` / `GetTotalDuration` / `IsZero`
- `EvaluateRemainingDuration(stepCurve, -1)` — Step, 2 outputs {0,1}
- `EvaluateRemainingDuration(linearCurve, -1)` — Linear, 0..600 -> 0..1
- `EvaluateRemainingDuration(identityCurve, -1)` — Linear, 0..600 -> 0..600
  (if this de-taints, the result *is* remaining seconds outright)

The three curves of increasing output precision map the exact boundary between
"quantization Blizzard allows to de-taint" and "precision it blocks."

### Hypotheses (recorded before the run)
- Step curve: likely de-taints (leaks 1 bit, same as `isActive`).
- Linear / identity curves: uncertain, leaning "stays secret" — a precise
  position would defeat the secret system.
- Raw read: possibly usable more often than the current `type()` guess assumes
  (Skiron reads raw durations directly for its cast bar, `Modules/castbar.lua`),
  so taint may be contextual rather than absolute.

### How to run
1. `/reload` after the build loads.
2. Out of combat: cast a few tracked spells to put them on cooldown, then
   `/cdmaster curvetest` — confirms the baseline (everything should read fine).
3. In combat (target dummy): repeat casts, `/cdmaster curvetest` again.
4. Paste the chat output here, or read it back from `db.profile._curveProbe`.

### Result
**Out-of-combat baseline — 2026-05-30 (probe v1):** raw reads return plain
numbers; curve eval throws.

| Spell | raw rem | raw total | isZero | step | linear | identity |
|-------|---------|-----------|--------|------|--------|----------|
| Touch of the Magi (321507) | 2.498 | 45.000 | false | ERR | ERR | ERR |
| Arcane Surge (365350)      | 63.345 | 90.000 | false | ERR | ERR | ERR |
| Arcane Orb (153626)        | 0.711 | 20.000 | false | ERR | ERR | ERR |

`(id)` and `(id, true)` returned identical raw values — the second arg makes no
difference to raw reads.

**Findings:**
1. `dObj:EvaluateRemainingDuration(curve, default)` ERRORS, it does not return
   SECRET. The method exists (the probe distinguishes a missing method), so the
   call itself throws — even out of combat. The curve strategy is broken at the
   API level, independent of taint. Matches the dev's memory that the old curve
   test "didn't work." The signature in the v0.2.0 header comment was never real.
2. The reference addon (SkironCooldownManager) builds curve objects
   (desaturation / alpha / UnitCount) but NEVER evaluates a curve against a
   duration anywhere — they are dead code. Its only live curve evaluation is
   `C_CurveUtil.EvaluateColorValueFromBoolean(dObj:IsZero(), 0, 1)`, a boolean
   helper, not a duration sampler. No known-good precedent for curve-to-number.
3. Raw `GetRemainingDuration` / `GetTotalDuration` are plain and correct OUT of
   combat.

### Decision (CORRECTED 2026-05-30, probe v2 error text)
**NOT abandoned — I was calling it wrong.** Probe v2 captured the real error:
`bad argument #3 to '?' (Usage: self:EvaluateRemainingDuration(curve [, modifier]))`.
I had passed a `-1` "default" as argument #3; the real signature is
`EvaluateRemainingDuration(curve [, modifier])` with the modifier OPTIONAL. The
method exists and accepts a curve — the throw was purely my bad third arg.

The `C_CurveUtil` evaluator family is known to de-taint: Skiron passes a secret
`dObj:IsZero()` into `EvaluateColorValueFromBoolean` and gets a plain 0/1
(customicons.lua:356). So a correctly-formed `dObj:EvaluateRemainingDuration(curve)`
may return a plain number in combat. Probe v3 drops the bad arg and re-tests,
distinguishing the step curve (low cardinality) from continuous curves
(linear/identity) since the evaluator may de-taint one but not the other.

**Resolution (probe v3, in combat 2026-05-30 21:53):** the corrected call
`dObj:EvaluateRemainingDuration(curve)` returns **SECRET** for ALL THREE curves
(step, linear, identity), on both `(id)` and `(id, true)`. The C_CurveUtil
evaluator does NOT de-taint into a readable Lua value — its result is itself a
secret, consumable only by privileged setters. (Re-explains Skiron:
`EvaluateColorValueFromBoolean(...)` is piped straight into `SetDesaturation`,
never read.) Even the 2-output step curve stays secret. CLOSED: curves are a
genuine dead end; no readable cooldown number exists in combat.

---

## EXP-002 — Do raw cooldown reads survive combat?

**Status:** CLOSED — in combat NO number is readable by any path (DurationObject, curves, AND legacy GetSpellCooldown start/dur all secret). Only isActive/isOnGCD readable. Direction: hybrid option C.
**Date opened:** 2026-05-30

### Question
Out of combat, `dObj:GetRemainingDuration()` / `GetTotalDuration()` return plain
numbers (EXP-001 baseline). Do they stay plain IN combat, or become secret
values (`issecretvalue() == true`)?

### Why it matters
- **Plain in combat** -> simplest possible fix: read raw, use `issecretvalue()`
  to guard the rare secret case. No curves, no native-widget rework; the
  engine's elaborate fallback machinery (hardcoded durations, cache
  extrapolation, fresh-cast inference) becomes largely unnecessary.
- **Secret in combat** -> option C: per-icon native `Cooldown` widgets fed via
  `Cooldown:SetCooldownFromDurationObject(dObj)` (Skiron, customicons.lua:346-367)
  plus `isActive`/`isOnGCD` booleans for show/hide. Loses smooth timeline
  positioning (no number to position with) — a design decision if we land here.

### Method
`/cdmaster curvetest` while `InCombatLockdown()` is true, with tracked spells on
cooldown. Easiest: macro `/cdmaster curvetest`, engage a target dummy, cast 2-3
cooldowns, click the macro while still in combat. Read the `raw : rem=` field —
a number means plain, `SECRET` means taint-blocked.

### Hypothesis (recorded before the run)
Leaning "raw goes secret in combat": CDM's whole fallback apparatus assumes it,
and Skiron never reads raw cooldown durations (only its cast bar reads raw, a
different context). But neither was verified with `issecretvalue()` — measure,
don't assume.

### Result
**In-combat run -- 2026-05-30 (21:44):** every DurationObject value is secret;
the C_Spell boolean is not.

With Touch of the Magi, Arcane Surge, Mirror Image, Counterspell on cooldown in
combat:
- `GetRemainingDuration` = SECRET
- `GetTotalDuration` = SECRET
- `dObj:IsZero()` = SECRET   (was a plain `false` out of combat)

But the probe's spell-selection loop, which gates on
`C_Spell.GetSpellCooldown(id).isActive and not .isOnGCD`, correctly found those
four on-CD spells WHILE IN COMBAT. So `isActive`/`isOnGCD` are READABLE
(non-secret) in combat -- a different API surface from the DurationObject, and
the seam to build on.

### Decision
RAW reads are secret in combat -- settled, will not revisit. The DurationObject's
own contents (including `IsZero`) are all secret in combat; only the
`C_Spell.GetSpellCooldown` booleans survive. The remaining hope for a live
*number* is the corrected curve eval (EXP-001 probe v3). Hold the
timeline-vs-option-C direction decision until that result is in.
