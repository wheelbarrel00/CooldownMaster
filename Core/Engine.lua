--[[
	Cooldown Master - Engine.lua

	Curve-evaluation architecture (cracked from BetterCooldownManager and
	TweaksUI Cooldowns research). Avoids Midnight 12.0 secret-value taint
	entirely by routing all numeric math through Blizzard's privileged
	DurationObject:EvaluateRemainingDuration() method.

	How it works:
	1. Build progress and ready curves once at login (Linear 0..1).
	2. Every tick, for each tracked spell:
	     dObj = C_Spell.GetSpellCooldownDuration(spellID)
	     ready    = dObj:EvaluateRemainingDuration(readyCurve, 1)
	     progress = dObj:EvaluateRemainingDuration(progressCurve, 0)
	   These return plain non-secret numbers because the secret arithmetic
	   happens INSIDE Blizzard's privileged curve evaluator.
	3. Lazy-learn each spell's total duration the first time we see it
	   active out of combat, so the renderer can show a countdown text
	   even when the API only exposes "progress 0..1".
	4. Strategy B fallback: cache cdStart/cdDuration when learned and
	   extrapolate in-combat using only numbers we wrote ourselves.

	Test mode unchanged.
--]]

local ADDON_NAME, ns = ...

ns.Engine = {}
local Engine = ns.Engine

-- Module state
Engine.trackedSpells   = {}   -- [spellID] = { name, icon, category, hasCharges, cooldownID }
Engine.trackedItems    = {}   -- [itemID]  = { name, icon, category, kind = "item" }
Engine.cdIDToSpellID   = {}   -- [cooldownID] = spellID  (reverse lookup)
Engine.knownDurations  = {}   -- [spellID] = duration in seconds (LEARNED out of combat / persisted; talent-adjusted, best quality)
Engine.baselineDurations = {} -- [spellID] = duration in seconds (hardcoded fallback or GetSpellBaseCooldown seed; base values, used only when nothing learned)
Engine.cdTimingCache   = {}   -- [spellID] = { cdStart, cdDuration } (extrapolation cache)
Engine.entries         = {}   -- [spellID|itemID] = { spellID, name, icon, startTime, duration, endTime, ... }
Engine.cooldownViewerFound = false
Engine.testActive      = false
Engine.testSpellIDs    = { 184575, 853, 633, 642 }

-- Hardcoded list of potion item IDs we poll every tick. Items don't come
-- from C_CooldownViewer (which only enumerates spells), so we maintain our
-- own list and read cooldowns directly via C_Container.GetItemCooldown.
-- Add new IDs here as Blizzard ships new potions.
local POTION_ITEMS = {
	241308, 241304, 241309, 241323, 258318,
}

Engine.readyCurve      = nil
Engine.progressCurve   = nil
local MAX_DURATION = 600

-- ============================================================================
-- Hardcoded fallback durations
-- ============================================================================
-- These are baseline (no haste, no talent reduction) cooldowns for common
-- spells. Used ONLY when we haven't learned a real duration yet via direct
-- read. Once a real read succeeds, the learned value overrides this table
-- because it accounts for talent modifications and is more accurate.
--
-- Coverage spans Paladin (Retribution) and Mage (all three specs) retail
-- spells, plus universal items/utilities. Easy to extend later.
local FALLBACK_DURATIONS = {
	-- ===== Paladin (Retribution focus) =====
	[375576] = 60,   -- Divine Toll
	[343527] = 60,   -- Execution Sentence
	[853]    = 45,   -- Hammer of Justice
	[96231]  = 15,   -- Rebuke
	[115750] = 90,   -- Blinding Light
	[633]    = 600,  -- Lay on Hands (10min, talent reduces)
	[391054] = 600,  -- Intercession
	[642]    = 300,  -- Divine Shield
	[1022]   = 300,  -- Blessing of Protection
	[1044]   = 25,   -- Blessing of Freedom
	[190784] = 45,   -- Divine Steed
	[403876] = 60,   -- Divine Protection
	[255937] = 30,   -- Wake of Ashes
	[31884]  = 120,  -- Avenging Wrath / Crusade
	[31935]  = 15,   -- Avenger's Shield
	[26573]  = 9,    -- Consecration
	[184662] = 120,  -- Shield of the Righteous (charge-based)
	[407480] = 6,    -- Templar Strike
	[407627] = 6,    -- Templar Slash
	[20271]  = 12,   -- Judgment (charge-based)
	[184575] = 10,   -- Blade of Justice (charge-based)
	[24275]  = 7.5,  -- Hammer of Wrath
	[410126] = 60,   -- Searing Glare

	-- ===== Mage (shared utility / defensives) =====
	[122]    = 30,   -- Frost Nova (charge-based with talent)
	[1953]   = 15,   -- Blink
	[212653] = 25,   -- Shimmer (charge-based; replaces Blink)
	[2139]   = 24,   -- Counterspell
	[45438]  = 240,  -- Ice Block
	[55342]  = 120,  -- Mirror Image
	[66]     = 300,  -- Invisibility
	[110959] = 90,   -- Greater Invisibility
	[80353]  = 300,  -- Time Warp
	[120]    = 12,   -- Cone of Cold
	[342245] = 60,   -- Alter Time
	[389713] = 25,   -- Displacement
	[235450] = 25,   -- Prismatic Barrier (Arcane)
	[11426]  = 25,   -- Ice Barrier (Frost)
	[235313] = 25,   -- Blazing Barrier (Fire)

	-- ===== Mage (Arcane) =====
	[365350] = 90,   -- Arcane Surge
	[321507] = 45,   -- Touch of the Magi
	[12051]  = 90,   -- Evocation
	[205025] = 60,   -- Presence of Mind
	[157980] = 25,   -- Supernova
	[153626] = 60,   -- Arcane Orb (talent)

	-- ===== Mage (Fire) =====
	[190319] = 120,  -- Combustion
	[257541] = 25,   -- Phoenix Flames (charge-based)
	[108853] = 12,   -- Fire Blast (charge-based)
	[31661]  = 20,   -- Dragon's Breath
	[153561] = 45,   -- Meteor
	[157981] = 25,   -- Blast Wave

	-- ===== Mage (Frost) =====
	[84714]  = 60,   -- Frozen Orb
	[12472]  = 180,  -- Icy Veins
	[235219] = 270,  -- Cold Snap (resets Frost cooldowns)
	[205021] = 75,   -- Ray of Frost
	[153595] = 30,   -- Comet Storm
	[157997] = 25,   -- Ice Nova
	[33395]  = 25,   -- Freeze (water elemental / pet)

	-- ===== Universal / item-like =====
	[6948]   = 600,  -- Hearthstone
}

-- Diagnostic counters
Engine._tickCount        = 0
Engine._curvesBuilt      = false
Engine._curveEvalSuccess = 0
Engine._curveEvalFail    = 0
Engine._fallbackUsed     = 0


-- ============================================================================
-- Helpers
-- ============================================================================

local function GetSpellNameIcon(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		if info then return info.name, info.iconID end
	end
	return "?", 134400
end


-- Item info is async on first cache miss. Caller should fall back to a
-- placeholder until GET_ITEM_INFO_RECEIVED fires for this ID.
local function GetItemNameIcon(itemID)
	if not (C_Item and C_Item.GetItemInfo) then return nil, nil end
	local name = C_Item.GetItemInfo(itemID)
	local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or nil
	return name, icon
end


-- (The old secret-number poll's module-level pcall helpers lived here --
-- ReadDObjDurations / PassesValidThresholds / EndTimeAbsDiff / IsEntryExpired.
-- The isActive lifecycle model reads no numbers in combat, so none are needed.)


-- C_Timer.After callback for the deferred scan. Hoisted to module scope so
-- event handlers pass a function reference rather than allocate a fresh
-- closure on every fire — SPELL_UPDATE_COOLDOWN can fire 20-50 times/sec
-- during heavy combat.
local function DeferredCooldownPoll()
	Engine._spellUpdatePending = nil
	if not Engine.testActive then
		Engine:ScanSpells()
	end
end


-- Shared debounce for both spell-cooldown event paths. A successful cast
-- fires UNIT_SPELLCAST_SUCCEEDED and SPELL_UPDATE_COOLDOWN within a few
-- frames of each other; one flag + one 100ms window collapses the pair (and
-- any proc burst) into a single ScanSpells. Worst-case event-driven scan
-- rate is therefore 10/sec — the same ceiling the old every-tick scan had —
-- but the typical rate is one scan per cast or proc burst. Each ScanSpells
-- pass allocates one GetSpellCooldown info table per tracked spell, so scan
-- count is the addon's dominant GC knob.
local SCAN_DEBOUNCE = 0.1
local function ScheduleDeferredScan()
	if Engine._spellUpdatePending then return end
	Engine._spellUpdatePending = true
	C_Timer.After(SCAN_DEBOUNCE, DeferredCooldownPoll)
end


function Engine:CountEntries()
	local n = 0
	for _ in pairs(self.entries) do n = n + 1 end
	return n
end


function Engine:CountTracked()
	local n = 0
	for _ in pairs(self.trackedSpells) do n = n + 1 end
	return n
end


function Engine:Wipe()
	wipe(self.entries)
end


function Engine:GetActiveEntries()
	return self.entries
end


-- ============================================================================
-- Persistent learning
-- ============================================================================
-- Known durations are saved to AceDB so they survive /reload and login.
-- This is what makes the addon usable in actual gameplay: each spell only
-- needs to be observed ONCE (ever) for it to display correctly forever.

function Engine:LoadPersistedDurations()
	local addon = ns.CDM
	if not (addon and addon.db) then return end
	addon.db.profile.knownDurations = addon.db.profile.knownDurations or {}

	-- Bootstrap: copy persisted durations into the runtime table.
	for spellID, duration in pairs(addon.db.profile.knownDurations) do
		if type(spellID) == "number" and type(duration) == "number"
			and duration > 1.5 then
			self.knownDurations[spellID] = duration
		end
	end

	-- Hardcoded fallbacks go in the BASELINE table, not knownDurations.
	-- They used to be layered into knownDurations directly, which made
	-- LearnDuration's "already known" guard treat them as learned -- so the
	-- real talent-adjusted duration was never learned for any spell with a
	-- fallback, contradicting the table's own documentation. Baselines now
	-- only fill the gap until a real observation lands.
	for spellID, duration in pairs(FALLBACK_DURATIONS) do
		if not self.baselineDurations[spellID] then
			self.baselineDurations[spellID] = duration
		end
	end
end


function Engine:SavePersistedDuration(spellID, duration)
	local addon = ns.CDM
	if not (addon and addon.db) then return end
	addon.db.profile.knownDurations = addon.db.profile.knownDurations or {}
	addon.db.profile.knownDurations[spellID] = duration
end


-- ============================================================================
-- Curve construction (BCM's trick)
-- ============================================================================

local function BuildReadyCurve()
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum
		and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
		return nil
	end
	local c = C_CurveUtil.CreateCurve()
	if not c then return nil end
	c:SetType(Enum.LuaCurveType.Step)
	c:AddPoint(0,     1)   -- remaining=0  → 1 (ready)
	c:AddPoint(0.001, 0)   -- remaining>0  → 0 (on cooldown)
	return c
end


local function BuildProgressCurve()
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum
		and Enum.LuaCurveType and Enum.LuaCurveType.Linear) then
		return nil
	end
	local c = C_CurveUtil.CreateCurve()
	if not c then return nil end
	c:SetType(Enum.LuaCurveType.Linear)
	c:AddPoint(0,            0)
	c:AddPoint(MAX_DURATION, 1)
	return c
end


function Engine:EnsureCurves()
	if self._curvesBuilt then return true end
	self.readyCurve    = BuildReadyCurve()
	self.progressCurve = BuildProgressCurve()
	if self.readyCurve and self.progressCurve then
		self._curvesBuilt = true
		return true
	end
	return false
end


-- ============================================================================
-- Baseline duration seeding (all classes, no hardcoded tables)
-- ============================================================================
-- GetSpellBaseCooldown(spellID) returns the spell's BASE cooldown in
-- milliseconds (no haste/talent adjustments). If it's readable on Midnight,
-- it lets us seed a sane icon-position baseline for every tracked spell of
-- every class at registry-build time -- replacing per-class hardcoded tables.
-- Verify in-game with /cdmaster seedtest. Precedence at lookup time:
-- learned/persisted > hardcoded fallback > this seed > 30s default.

-- pcall body: read + validate to plain seconds. Runs entirely inside pcall
-- so a comparison against a secret value (if the detector were ever
-- unavailable) fails closed instead of erroring up the stack.
local function ReadBaseCooldownSeconds(spellID)
	local cdMS = GetSpellBaseCooldown(spellID)
	if cdMS == nil then return nil end
	local issecret = _G.issecretvalue
	if issecret and issecret(cdMS) then return nil end
	if type(cdMS) ~= "number" then return nil end
	-- Skip GCD-length and zero results (charge spells commonly report 0
	-- here; their recharge is learned from observation instead).
	if cdMS <= 1500 then return nil end
	return cdMS / 1000
end


function Engine:SeedBaselineDurations()
	if type(GetSpellBaseCooldown) ~= "function" then
		self._seedAPIPresent = false
		return
	end
	self._seedAPIPresent = true

	for spellID in pairs(self.trackedSpells) do
		-- Learned values are better (talent-adjusted observation), and an
		-- existing baseline (hand-verified hardcoded entry or earlier seed)
		-- is not worth overwriting. Only fill genuine gaps.
		if not self.knownDurations[spellID]
			and not self.baselineDurations[spellID] then
			local ok, secs = pcall(ReadBaseCooldownSeconds, spellID)
			if ok and secs then
				self.baselineDurations[spellID] = secs
			end
		end
	end
end


-- ============================================================================
-- Build the spell registry from Cooldown Viewer
-- ============================================================================

function Engine:BuildTrackedSpells()
	wipe(self.trackedSpells)
	wipe(self.cdIDToSpellID)

	if not (C_CooldownViewer
		and C_CooldownViewer.GetCooldownViewerCategorySet
		and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
		return
	end

	for category = 0, 3 do
		local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category)
		if ok and ids then
			for _, cooldownID in ipairs(ids) do
				local infoOk, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
				if infoOk and info and info.isKnown then
					local effectiveID = info.spellID
					if info.overrideSpellID
						and info.overrideSpellID ~= 0
						and info.overrideSpellID ~= info.spellID then
						effectiveID = info.overrideSpellID
					end

					-- The same spell can appear in more than one Cooldown
					-- Viewer category (e.g. an Essential cooldown that is
					-- also a Tracked Buff). The loop scans categories in
					-- ascending order, so keep the FIRST entry: the lowest
					-- category (Essential/Utility) becomes the spell's
					-- primary category for filter lists and lane routing.
					-- Later duplicates still record their cooldownID mapping.
					if effectiveID and not self.trackedSpells[effectiveID] then
						local name, icon = GetSpellNameIcon(effectiveID)
						self.trackedSpells[effectiveID] = {
							name       = name,
							icon       = icon,
							category   = info.category,
							hasCharges = info.charges,
							cooldownID = cooldownID,
						}
					end
					self.cdIDToSpellID[cooldownID] = effectiveID
				end
			end
		end
	end

	-- Fill duration baselines for every spell the registry just discovered --
	-- this is what makes icon positions sane on classes that have no
	-- hardcoded fallback table (everything except Paladin/Mage).
	self:SeedBaselineDurations()
end


-- ============================================================================
-- Build the item registry (potions today; extensible to other consumables)
-- ============================================================================
-- Items don't come from C_CooldownViewer, so we maintain our own list of
-- itemIDs and resolve name/icon lazily. C_Item.GetItemInfo is async — if
-- the client hasn't cached the item yet, name/icon come back nil and the
-- GET_ITEM_INFO_RECEIVED listener fills them in later.

function Engine:BuildTrackedItems()
	wipe(self.trackedItems)

	if not (C_Container and C_Container.GetItemCooldown) then
		return
	end

	for _, itemID in ipairs(POTION_ITEMS) do
		if C_Item and C_Item.RequestLoadItemDataByID then
			C_Item.RequestLoadItemDataByID(itemID)
		end
		local name, icon = GetItemNameIcon(itemID)
		self.trackedItems[itemID] = {
			name     = name or ("Item " .. itemID),
			icon     = icon or 134400,
			category = ns.CONST.POTION_CATEGORY,
			kind     = "item",
		}
	end
end


-- ============================================================================
-- Lane routing
-- ============================================================================

function Engine:DefaultLaneForCategory(category)
	if category == 0 then return 1
	elseif category == 1 then return 2
	elseif category == 2 then return 3
	elseif category == 3 then return 3
	end
	return 1
end


-- Resolve the string filter key for a numeric Blizzard category. Returns nil
-- for categories outside the mapping (e.g. test entries with category=0 or
-- categories Blizzard adds in the future).
function Engine:GetCategoryFilterKey(category)
	return ns.CONST.CATEGORY_TO_FILTER_KEY[category]
end


-- Decide whether a spell should be visible right now based on the user's
-- filter settings. Three-layer check:
--   1. Category-level enabled flag (Filters > Defaults sub-tab toggles a
--      whole category on/off).
--   2. Per-spell override (Filters > Spells/Items/Buffs/Debuffs sub-tabs;
--      stored in db.profile.spellOverrides[spellID].visible).
--   3. Falls back to the category's showByDefault when no per-spell override
--      exists (so a brand-new discovered spell inherits a sensible default).
-- Categories without a filter mapping always pass through visible (rather
-- than being silently hidden).
function Engine:IsSpellVisible(spellID, category)
	local addon = ns.CDM
	if not (addon and addon.db) then return true end

	local profile = addon.db.profile
	local key = self:GetCategoryFilterKey(category)
	if not key then return true end

	local fcfg = profile.filters and profile.filters[key]
	if not fcfg then return true end
	if fcfg.enabled == false then return false end

	local override = profile.spellOverrides and profile.spellOverrides[spellID]
	if override and override.visible ~= nil then
		return override.visible == true
	end

	return fcfg.showByDefault ~= false
end


function Engine:ResolveLaneIndex(spellID, category)
	local addon = ns.CDM
	if addon and addon.db then
		local profile = addon.db.profile

		-- Per-spell override wins.
		local override = profile.spellOverrides and profile.spellOverrides[spellID]
		if override and override.lane then
			return override.lane
		end

		-- Else the category's defaultLane (set in Filters > Defaults sub-tab).
		local key = self:GetCategoryFilterKey(category)
		local fcfg = key and profile.filters and profile.filters[key]
		if fcfg and fcfg.defaultLane then
			return fcfg.defaultLane
		end
	end
	return self:DefaultLaneForCategory(category)
end


-- ============================================================================
-- Poll loop
-- ============================================================================

-- pcall bodies for LearnDuration, hoisted to module scope. The inline
-- closures they replace allocated two functions per call -- and LearnDuration
-- runs on every scan for each active spell that hasn't learned yet, so a
-- spell whose duration object never yields a total (some charge spells)
-- churned closures indefinitely while out of combat.
local function ReadTotalDuration(dObj)
	if dObj.GetTotalDuration then
		return dObj:GetTotalDuration()
	end
	return nil
end

local function ReadRemainingDuration(dObj)
	if dObj.GetRemainingDuration then
		return dObj:GetRemainingDuration()
	end
	return nil
end


function Engine:LearnDuration(spellID, dObj)
	-- Guard on knownDurations ONLY -- a baseline (hardcoded or seeded) must
	-- not block learning, since the observed value is talent-adjusted and
	-- strictly better than any base number.
	if self.knownDurations[spellID] then return end
	if not dObj then return end
	if InCombatLockdown() then return end

	local ok, total = pcall(ReadTotalDuration, dObj)
	if ok and type(total) == "number" and total > 1.5 then
		self.knownDurations[spellID] = total
		-- Persist to AceDB -- this call was missing, so "learn once, ever"
		-- never survived a /reload and re-learning started from scratch each
		-- session. One number write per spell per learn; no churn.
		self:SavePersistedDuration(spellID, total)
		local rOk, remaining = pcall(ReadRemainingDuration, dObj)
		if rOk and type(remaining) == "number" and remaining > 0 then
			self.cdTimingCache[spellID] = {
				cdStart    = GetTime() - (total - remaining),
				cdDuration = total,
			}
		end
	end
end


-- ============================================================================
-- Spell lifecycle scan (combat-safe; replaces the secret-number poll)
-- ============================================================================
-- We can no longer read remaining time in combat -- every numeric path is
-- secret (proven: docs/EXPERIMENTS.md EXP-001/002). So the entry set is driven
-- off the only readable signals, C_Spell.GetSpellCooldown().isActive/.isOnGCD,
-- and we keep the opaque DurationObject for the renderer to feed into a native
-- Cooldown widget (which draws the exact swipe + countdown for us). Icon
-- POSITION is extrapolated from a duration learned out of combat; the native
-- widget's text stays exact regardless of any extrapolation error.

function Engine:ScanSpells()
	if not (C_Spell and C_Spell.GetSpellCooldown) then return end

	-- Reuse one scratch table across scans (no per-scan alloc).
	self._seenSpells = self._seenSpells or {}
	local seen = self._seenSpells
	wipe(seen)

	local now = GetTime()
	local inCombat = InCombatLockdown()

	for spellID, tracked in pairs(self.trackedSpells) do
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		---@diagnostic disable-next-line: undefined-field
		if ok and info and info.isActive and not info.isOnGCD then
			seen[spellID] = true

			-- Opaque handle for display only -- never read in combat. We get
			-- here only because isActive is true (the spell is fully on cooldown
			-- / out of charges), so GetSpellCooldownDuration is the canonical
			-- source for the remaining time -- including a charge spell's recharge
			-- once it's depleted. The charge-duration object is only a fallback:
			-- some spells the Cooldown Viewer flags hasCharges=true (e.g. Touch of
			-- the Magi) hand back a charge object that resolves to "no cooldown",
			-- which renders a blank icon with no swipe or number. Preferring the
			-- cooldown duration avoids that shadowing.
			local dObj
			if C_Spell.GetSpellCooldownDuration then
				local dok, d = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
				if dok then dObj = d end
			end
			if not dObj and tracked.hasCharges and C_Spell.GetSpellChargeDuration then
				local cok, cd = pcall(C_Spell.GetSpellChargeDuration, spellID, true)
				if cok then dObj = cd end
			end

			-- Out of combat the numbers are readable, so learn the true
			-- (talent/haste-adjusted) duration to feed in-combat extrapolation.
			if not inCombat and dObj then
				self:LearnDuration(spellID, dObj)
			end

			local existing = self.entries[spellID]
			if not existing then
				-- New cooldown. Extrapolate position from a known duration;
				-- the native widget shows the true countdown either way.
				local cat = tracked.category or 0
				-- Position extrapolation quality ladder: learned (talent-
				-- adjusted observation) > baseline (hardcoded or API base
				-- cooldown) > 30s default. The native widget's countdown
				-- text is exact regardless of which one we use here.
				local duration = self.knownDurations[spellID]
					or self.baselineDurations[spellID]
					or 30
				self.entries[spellID] = {
					spellID   = spellID,
					name      = tracked.name,
					icon      = tracked.icon,
					startTime = now,
					duration  = duration,
					endTime   = now + duration,
					laneIndex = self:ResolveLaneIndex(spellID, cat),
					category  = cat,
					dObj      = dObj,
					_source   = "isactive",
				}
			else
				-- Same cooldown still running: keep the extrapolated position
				-- (don't reset startTime), just refresh the opaque handle.
				existing.dObj = dObj or existing.dObj
			end
		end
	end

	-- isActive is authoritative for removal: anything no longer active has
	-- ended OR been reset by a proc. Either way it leaves the timeline now.
	-- Items live in a parallel table (PollAllItems prunes them); test entries
	-- are managed by Tick.
	for spellID, entry in pairs(self.entries) do
		if entry._source ~= "test" and entry.kind ~= "item" and not seen[spellID] then
			self.entries[spellID] = nil
		end
	end
end


-- ============================================================================
-- Item cooldown polling (zero-alloc steady state)
-- ============================================================================
-- Items are far simpler than spells: C_Container.GetItemCooldown returns
-- plain numbers (no secret-value taint, no DurationObject), so we can read
-- and compare directly. No curve evaluation, no fresh-cast flag dance.
--
-- Allocation discipline:
--   - PollOneItem returns multi-values (no result table)
--   - PollAllItems reuses self._seenItems via wipe() (no scratch table)
--   - Existing entries get fields mutated in place (no realloc on refresh)
--   - New entries allocate the entry table once, on first sighting

function Engine:PollOneItem(itemID)
	if not (C_Container and C_Container.GetItemCooldown) then
		return false
	end

	local startTime, duration = C_Container.GetItemCooldown(itemID)
	if not startTime or not duration then return false end
	if duration <= 1.5 then return false end   -- skip GCD-length cooldowns
	if startTime <= 0 then return false end

	local endTime = startTime + duration
	if endTime <= GetTime() then return false end

	return true, startTime, duration, endTime
end


function Engine:PollAllItems()
	self._seenItems = self._seenItems or {}
	local seen = self._seenItems
	wipe(seen)

	for itemID, tracked in pairs(self.trackedItems) do
		local active, startTime, duration, endTime = self:PollOneItem(itemID)
		if active then
			seen[itemID] = true
			local existing = self.entries[itemID]
			if existing then
				-- Refresh in place — no allocation. Mirrors how PollAllSpells
				-- handles its existing entries.
				existing.startTime = startTime
				existing.duration  = duration
				existing.endTime   = endTime
			else
				local cat = tracked.category or ns.CONST.POTION_CATEGORY
				self.entries[itemID] = {
					spellID    = itemID,   -- lane code reads .spellID; reuse field
					itemID     = itemID,
					name       = tracked.name,
					icon       = tracked.icon,
					startTime  = startTime,
					duration   = duration,
					endTime    = endTime,
					laneIndex  = self:ResolveLaneIndex(itemID, cat),
					category   = cat,
					kind       = "item",
					_source    = "item-cooldown",
				}
			end
		end
	end

	-- Prune item entries that finished or were removed from the list.
	for itemID, entry in pairs(self.entries) do
		if entry.kind == "item" and not seen[itemID] then
			self.entries[itemID] = nil
		end
	end
end


-- ============================================================================
-- Test mode (unchanged)
-- ============================================================================

function Engine:StartTestMode()
	self.testActive = true
	wipe(self.entries)
	local now = GetTime()
	local durations = { 5, 15, 30, 60 }
	for i, spellID in ipairs(self.testSpellIDs) do
		local name, icon = GetSpellNameIcon(spellID)
		local dur = durations[i] or 30
		self.entries[spellID] = {
			spellID    = spellID,
			name       = name,
			icon       = icon,
			startTime  = now,
			duration   = dur,
			endTime    = now + dur,
			laneIndex  = 1,
			category   = 0,
			_source    = "test",
		}
	end
end


function Engine:StopTestMode()
	self.testActive = false
	for spellID, entry in pairs(self.entries) do
		if entry._source == "test" then
			self.entries[spellID] = nil
		end
	end
	-- Repopulate live entries immediately. The tick sweep now runs at 1 Hz,
	-- so without this the lanes would sit empty for up to a second after
	-- leaving test mode. One user-triggered scan; no steady-state cost.
	self:ScanSpells()
	self:PollAllItems()
end


-- ============================================================================
-- Tick loop
-- ============================================================================

function Engine:Tick()
	self._tickCount = self._tickCount + 1

	if self.testActive then
		-- Test entries carry plain endTimes; expire them so the preview
		-- counts down and clears. Live spell entries are managed by
		-- ScanSpells (isActive removal), never by endTime -- isActive is
		-- the truth, and our extrapolated endTime can be wrong.
		local now = GetTime()
		for spellID, entry in pairs(self.entries) do
			if entry._source == "test" and entry.endTime and now >= entry.endTime then
				self.entries[spellID] = nil
			end
		end
	else
		-- Safety-net cadence only (every 10th tick = 1 Hz). Cooldown edges
		-- are caught by the event paths (SPELL_UPDATE_COOLDOWN /
		-- UNIT_SPELLCAST_SUCCEEDED / BAG_UPDATE_COOLDOWN); this sweep exists
		-- for anything they miss, e.g. events dropped across a loading
		-- screen. Scanning on every tick allocated one GetSpellCooldown
		-- info table per tracked spell per tick (~400 tables/sec at 40
		-- tracked spells) for data that almost never changed between ticks.
		self._scanCounter = (self._scanCounter or 0) + 1
		if self._scanCounter >= 10 then
			self._scanCounter = 0
			self:ScanSpells()
			self:PollAllItems()
		end
	end

	if ns.Lanes_Refresh then
		for i = 1, 3 do ns.Lanes_Refresh(i) end
	end
end


-- ============================================================================
-- Lifecycle
-- ============================================================================

function Engine:Start(addon)
	self.addon = addon
	self.cooldownViewerFound = (C_CooldownViewer ~= nil
		and type(C_CooldownViewer.IsCooldownViewerAvailable) == "function")

	-- Load known durations from saved variables + hardcoded fallbacks.
	-- This must happen before any polling so Strategy C has data to use.
	self:LoadPersistedDurations()

	if not self._buildScheduled then
		self._buildScheduled = true
		C_Timer.After(1.5, function()
			self:BuildTrackedSpells()
			self:BuildTrackedItems()
			-- Discovery may land after the Filters tab was first opened;
			-- drop its cached lists so they rebuild from the fresh registry.
			if ns.Options_InvalidateFilterLists then
				ns.Options_InvalidateFilterLists()
			end
		end)
	end

	-- Item names/icons that weren't cached at BuildTrackedItems time arrive
	-- via GET_ITEM_INFO_RECEIVED. Update the tracked entry, then nudge the
	-- Filters tab to refresh the matching row's text in place — no form
	-- rebuild, no frame allocation.
	if not self.itemInfoFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		f:SetScript("OnEvent", function(_, _, itemID, success)
			if not (success and itemID and Engine.trackedItems[itemID]) then return end
			local name, icon = GetItemNameIcon(itemID)
			local tracked = Engine.trackedItems[itemID]
			if name then tracked.name = name end
			if icon then tracked.icon = icon end
			if ns.Options_UpdateTrackedItemDisplay then
				ns.Options_UpdateTrackedItemDisplay(itemID, name, icon)
			end
		end)
		self.itemInfoFrame = f
	end

	if not self.specEventFrame then
		local f = CreateFrame("Frame")
		-- Unit-filtered: the unfiltered event also fires when PARTY members
		-- change spec, and each of those fires would wipe our learned
		-- durations for no reason.
		f:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_SPECIALIZATION_CHANGED" then
				wipe(self.knownDurations)
				wipe(self.cdTimingCache)
				-- Re-layer persisted + hardcoded fallback durations under the
				-- fresh slate. Without this the runtime table stayed empty
				-- until the next /reload (which reloads persisted anyway), so
				-- every new cooldown extrapolated from the 30s default.
				self:LoadPersistedDurations()
				self:BuildTrackedSpells()
				self:BuildTrackedItems()
				if ns.Options_InvalidateFilterLists then
					ns.Options_InvalidateFilterLists()
				end
			end
		end)
		self.specEventFrame = f
	end

	-- SPELL_UPDATE_COOLDOWN listener: fires when any cooldown changes (start,
	-- end, or proc reset). Routed through the shared ScheduleDeferredScan
	-- debounce so a burst of changes collapses into a single ScanSpells.
	if not self.spellUpdateFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		f:SetScript("OnEvent", function()
			if Engine.testActive then return end
			ScheduleDeferredScan()
		end)
		self.spellUpdateFrame = f
	end

	-- UNIT_SPELLCAST_SUCCEEDED listener: a successful cast usually starts a
	-- cooldown. isActive (read inside ScanSpells) is authoritative, so we
	-- don't need to match the exact cast spellID or chase overrides. Routed
	-- through the shared debounce: the cast also fires SPELL_UPDATE_COOLDOWN
	-- a few frames later, and the old immediate scan here meant every cast
	-- paid for two full scans ~50ms apart.
	if not self.castSucceededFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		f:SetScript("OnEvent", function(_, _, unit)
			if Engine.testActive then return end
			if unit ~= "player" then return end
			ScheduleDeferredScan()
		end)
		self.castSucceededFrame = f
	end

	-- BAG_UPDATE_COOLDOWN listener: item cooldowns (potions) have their own
	-- start/refresh event, which keeps potion icons appearing promptly now
	-- that the tick sweep runs at 1 Hz. PollAllItems reads plain multi-values
	-- (no table allocation, ~5 items), so it needs no debounce.
	if not self.bagCooldownFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("BAG_UPDATE_COOLDOWN")
		f:SetScript("OnEvent", function()
			if Engine.testActive then return end
			Engine:PollAllItems()
		end)
		self.bagCooldownFrame = f
	end

	if not self.tickFrame then
		local f = CreateFrame("Frame")
		f._elapsed = 0
		f:SetScript("OnUpdate", function(self2, dt)
			self2._elapsed = self2._elapsed + dt
			if self2._elapsed >= 0.1 then
				self2._elapsed = 0
				Engine:Tick()
			end
		end)
		self.tickFrame = f
	end

end


-- ============================================================================
-- Diagnostics
-- ============================================================================

function Engine:RunAPIDiagnostic()
	local cdm = ns.CDM
	if not cdm or not cdm.Print then return end

	cdm:Print("===== Engine state =====")
	cdm:Print("Cooldown Viewer found: " .. tostring(self.cooldownViewerFound))
	cdm:Print("Curves built: " .. tostring(self._curvesBuilt))
	cdm:Print("Tracked spells: " .. self:CountTracked())
	local kd = 0
	for _ in pairs(self.knownDurations) do kd = kd + 1 end
	cdm:Print("Known durations: " .. kd)
	cdm:Print("Active entries: " .. self:CountEntries())
	cdm:Print("Test mode: " .. (self.testActive and "ON" or "off"))
	cdm:Print("Tick count: " .. self._tickCount)
	cdm:Print("Curve eval ok: " .. self._curveEvalSuccess)
	cdm:Print("Curve eval fail: " .. self._curveEvalFail)
	cdm:Print("Fallback (Strategy B) used: " .. self._fallbackUsed)
	cdm:Print("Strategy C (fresh-cast) used: " .. tostring(self._strategyCUsed or 0))
	cdm:Print("Cast events captured: " .. tostring(self._castEventCount or 0))
	-- Active fresh-cast flags (should be ~empty most of the time).
	if self._freshCastFlags then
		local n = 0
		for _ in pairs(self._freshCastFlags) do n = n + 1 end
		cdm:Print("Pending fresh-cast flags: " .. n)
	end

	-- Probe whether IsActive method is available on a fresh DurationObject
	-- so we know the data path being used.
	if C_Spell and C_Spell.GetSpellCooldownDuration then
		local probeOk, probe = pcall(C_Spell.GetSpellCooldownDuration, 6603)
		if probeOk and probe then
			cdm:Print("DurationObject methods: " ..
				(probe.IsActive and "IsActive " or "") ..
				(probe.GetTotalDuration and "GetTotal " or "") ..
				(probe.GetRemainingDuration and "GetRemaining " or "") ..
				(probe.EvaluateRemainingDuration and "Evaluate " or ""))
		end
	end
end


-- Baseline-seeding probe (opt-in diagnostic: /cdmaster seedtest). Reports
-- whether GetSpellBaseCooldown produced usable seconds for the current
-- spec's tracked spells, and which spells have no baseline from any source.
function Engine:RunSeedDiagnostic()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	cdm:Print("===== Baseline duration seeding =====")
	cdm:Print("GetSpellBaseCooldown present: "
		.. tostring(type(GetSpellBaseCooldown) == "function"))

	local learned, hardcoded, seeded, missing = 0, 0, 0, 0
	local sampleSeeded, sampleMissing = {}, {}
	for spellID, tracked in pairs(self.trackedSpells) do
		if self.knownDurations[spellID] then
			learned = learned + 1
		elseif FALLBACK_DURATIONS[spellID] then
			hardcoded = hardcoded + 1
		elseif self.baselineDurations[spellID] then
			seeded = seeded + 1
			if #sampleSeeded < 10 then
				sampleSeeded[#sampleSeeded + 1] = string.format("%s = %.0fs",
					tostring(tracked.name), self.baselineDurations[spellID])
			end
		else
			missing = missing + 1
			if #sampleMissing < 10 then
				sampleMissing[#sampleMissing + 1] = tostring(tracked.name)
			end
		end
	end

	cdm:Print(string.format(
		"Tracked %d | learned %d | hardcoded %d | API-seeded %d | no baseline %d",
		learned + hardcoded + seeded + missing,
		learned, hardcoded, seeded, missing))
	if #sampleSeeded > 0 then
		cdm:Print("API-seeded samples (sanity-check these against tooltips):")
		for _, s in ipairs(sampleSeeded) do cdm:Print("  " .. s) end
	end
	if #sampleMissing > 0 then
		cdm:Print("No baseline (position uses 30s default until learned):")
		for _, s in ipairs(sampleMissing) do cdm:Print("  " .. s) end
	end

	if seeded > 0 then
		cdm:Print("|cff00ff00Verdict: API seeding works on this client.|r Best read on a class WITHOUT hardcoded fallbacks (anything but Paladin/Mage).")
	elseif missing == 0 then
		cdm:Print("|cffEBB706Verdict: inconclusive here -- every tracked spell already has a learned or hardcoded value. Re-run on another class.|r")
	else
		cdm:Print("|cffff5555Verdict: API produced nothing usable. Hardcoded tables (Route 2) needed for uncovered classes.|r")
	end
end


-- ============================================================================
-- Curve-eval probe (opt-in diagnostic: /cdmaster curvetest)
-- ============================================================================
-- Settles empirically whether the curve-evaluation strategy the v0.2.0 notes
-- CLAIMED (but never actually shipped) can de-taint secret cooldown values in
-- COMBAT. For each spell currently on cooldown it classifies every candidate
-- data path with issecretvalue() -- the canonical Midnight taint detector --
-- so each path reports a definitive SECRET / <number> / nil / ERR instead of
-- the fragile type()=="number" guess the live engine uses today.
--
-- Touches nothing in the live poll path; runs only when invoked. The full
-- classification (plain strings only -- never a stored secret value) is saved
-- to db.profile._curveProbe so the OUTCOME is finally written down.

local function ProbeClassify(issecret, fn, ...)
	if type(fn) ~= "function" then return "no-method" end
	local ok, v = pcall(fn, ...)
	if not ok then return "ERR: " .. tostring(v) end   -- v is the error message
	if v == nil then return "nil" end
	-- Must confirm not-secret BEFORE touching the value with format/tostring.
	-- Without a detector we cannot, so we refuse to risk it.
	if not issecret then return "no-detector" end
	if issecret(v) then return "SECRET" end
	local t = type(v)
	if t == "number" then return string.format("%.3f", v) end
	if t == "boolean" then return tostring(v) end
	return t
end


local function ProbeDObj(cdm, issecret, label, dObj, stepCurve, linCurve, idCurve)
	if dObj == nil then
		cdm:Print("  " .. label .. ": <no DurationObject returned>")
		return { dObj = false }
	end
	local rec = {
		dObj      = true,
		remaining = ProbeClassify(issecret, dObj.GetRemainingDuration, dObj),
		total     = ProbeClassify(issecret, dObj.GetTotalDuration, dObj),
		isZero    = ProbeClassify(issecret, dObj.IsZero, dObj),
		-- Correct signature is EvaluateRemainingDuration(curve [, modifier]);
		-- modifier is OPTIONAL, so we omit it. (Probe v1/v2 wrongly passed -1
		-- as the modifier, which the API rejected with "bad argument #3".)
		step      = stepCurve and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, stepCurve) or "n/a",
		linear    = linCurve  and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, linCurve) or "n/a",
		identity  = idCurve   and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, idCurve) or "n/a",
	}
	cdm:Print(string.format("  %s raw : rem=%s  total=%s  isZero=%s", label, rec.remaining, rec.total, rec.isZero))
	-- One eval per line: the error text is the whole point now, and it would be
	-- unreadable crammed three-to-a-line.
	cdm:Print(string.format("  %s eval step    : %s", label, rec.step))
	cdm:Print(string.format("  %s eval linear  : %s", label, rec.linear))
	cdm:Print(string.format("  %s eval identity: %s", label, rec.identity))
	return rec
end


local function ProbeUsableNum(s)
	local n = tonumber(s)
	return n ~= nil and n >= 0   -- excludes the -1 eval-default sentinel
end


function Engine:RunCurveProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	local issecret = _G.issecretvalue   -- canonical Midnight taint detector
	local inCombat = InCombatLockdown()

	cdm:Print("===== Curve-eval probe =====")
	cdm:Print("In combat: " .. (inCombat and "|cff00ff00YES|r" or "|cffff5555no|r (the real test is IN combat)"))
	cdm:Print("issecretvalue() present: " .. tostring(issecret ~= nil))
	cdm:Print("legend: SECRET=taint-blocked  <number>=usable plain value  ERR=call failed")

	if not (C_Spell and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldown) then
		cdm:Print("C_Spell cooldown API missing -- cannot probe.")
		return
	end

	self:EnsureCurves()
	local stepCurve = self.readyCurve      -- Step: remaining -> {1 ready, 0 on-cd}
	local linCurve  = self.progressCurve   -- Linear: 0..600 -> 0..1

	-- Identity curve: 0..600 -> 0..600. If THIS de-taints, the result is the
	-- remaining time in seconds outright -- the timeline holy grail.
	local idCurve
	if C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
		idCurve = C_CurveUtil.CreateCurve()
		if idCurve then
			idCurve:SetType(Enum.LuaCurveType.Linear)
			idCurve:AddPoint(0, 0)
			idCurve:AddPoint(MAX_DURATION, MAX_DURATION)
		end
	end
	cdm:Print(string.format("Curves built: step=%s linear=%s identity=%s",
		tostring(stepCurve ~= nil), tostring(linCurve ~= nil), tostring(idCurve ~= nil)))

	-- Find up to 5 tracked spells currently on cooldown, via the taint-safe
	-- boolean path (isActive/isOnGCD are not secret-protected -- Skiron relies
	-- on exactly this).
	local onCD = {}
	for spellID, tracked in pairs(self.trackedSpells) do
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		---@diagnostic disable-next-line: undefined-field
		if ok and info and info.isActive and not info.isOnGCD then
			onCD[#onCD + 1] = { id = spellID, name = tracked.name }
			if #onCD >= 3 then break end
		end
	end

	if #onCD == 0 then
		cdm:Print("|cffff5555No tracked spells on cooldown right now.|r Put a few on CD (in combat) and re-run /cdmaster curvetest.")
	end

	local log = { inCombat = inCombat, hasIssecret = issecret ~= nil, spells = {} }

	for _, s in ipairs(onCD) do
		cdm:Print(string.format("|cffEBB706[%d] %s|r", s.id, tostring(s.name)))

		-- Legacy plain-number API: C_Spell.GetSpellCooldown(id) returns a table
		-- with startTime/duration/modRate (plus the known-readable isActive/
		-- isOnGCD booleans). If start+duration are plain in combat, the timeline
		-- can be EXACT instead of extrapolated. This is the last untested source.
		local sc = {}
		local okI, info = pcall(C_Spell.GetSpellCooldown, s.id)
		if okI and info then
			sc.startTime = ProbeClassify(issecret, function() return info.startTime end)
			sc.duration  = ProbeClassify(issecret, function() return info.duration end)
			sc.modRate   = ProbeClassify(issecret, function() return info.modRate end)
			---@diagnostic disable-next-line: undefined-field
			sc.isActive  = ProbeClassify(issecret, function() return info.isActive end)
			---@diagnostic disable-next-line: undefined-field
			sc.isOnGCD   = ProbeClassify(issecret, function() return info.isOnGCD end)
			cdm:Print(string.format("  GetSpellCooldown: start=%s  dur=%s  modRate=%s  isActive=%s  isOnGCD=%s",
				sc.startTime, sc.duration, sc.modRate, sc.isActive, sc.isOnGCD))
		else
			cdm:Print("  GetSpellCooldown: <call failed>")
		end

		local okA, dA = pcall(C_Spell.GetSpellCooldownDuration, s.id)
		local okB, dB = pcall(C_Spell.GetSpellCooldownDuration, s.id, true)
		log.spells[#log.spells + 1] = {
			id = s.id, name = s.name,
			sc = sc,
			A = ProbeDObj(cdm, issecret, "A (id)     ", okA and dA or nil, stepCurve, linCurve, idCurve),
			B = ProbeDObj(cdm, issecret, "B (id,true)", okB and dB or nil, stepCurve, linCurve, idCurve),
		}
	end

	-- Verdict: did anything hand back a usable plain number in combat? Track the
	-- legacy GetSpellCooldown start+duration, raw DurationObject reads, the step
	-- curve (low cardinality) and the continuous curves (linear/identity)
	-- separately -- they can each de-taint independently.
	local oldApiUsable, rawUsable, stepUsable, contUsable = false, false, false, false
	for _, sp in ipairs(log.spells) do
		if type(sp.sc) == "table"
			and ProbeUsableNum(sp.sc.startTime) and ProbeUsableNum(sp.sc.duration) then
			oldApiUsable = true
		end
		for _, v in pairs({ sp.A, sp.B }) do
			if type(v) == "table" then
				if ProbeUsableNum(v.remaining) then rawUsable = true end
				if ProbeUsableNum(v.step) then stepUsable = true end
				if ProbeUsableNum(v.linear) or ProbeUsableNum(v.identity) then contUsable = true end
			end
		end
	end

	cdm:Print("===== Verdict =====")
	if not inCombat then
		cdm:Print("Out of combat -- values are normally readable here, so this is only a baseline. |cffEBB706Re-run IN COMBAT for the real test.|r")
	elseif #onCD == 0 then
		cdm:Print("No data captured (nothing was on cooldown).")
	else
		cdm:Print("Old-API start+dur usable:         " .. tostring(oldApiUsable))
		cdm:Print("Raw DurationObject usable:        " .. tostring(rawUsable))
		cdm:Print("Curve STEP de-taints:             " .. tostring(stepUsable))
		cdm:Print("Curve CONTINUOUS (lin/id) usable: " .. tostring(contUsable))
		if oldApiUsable or rawUsable or contUsable then
			cdm:Print("|cff00ff00A plain remaining-time number IS available in combat -> EXACT timeline possible.|r")
		elseif stepUsable then
			cdm:Print("|cffEBB706Only the step curve de-taints -> ready/not-ready only, no position. Timeline stays extrapolated; option C for exact display.|r")
		else
			cdm:Print("|cffff5555No plain number in combat -> hybrid option C: extrapolated position + native Cooldown widgets.|r")
		end
	end

	if cdm.db and cdm.db.profile then
		cdm.db.profile._curveProbe = log
		cdm:Print("Saved to db.profile._curveProbe (written down for next time).")
	end
end
