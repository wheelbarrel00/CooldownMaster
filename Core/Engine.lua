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
Engine.cdIDToSpellID   = {}   -- [cooldownID] = spellID  (reverse lookup)
Engine.knownDurations  = {}   -- [spellID] = total duration in seconds (learned)
Engine.cdTimingCache   = {}   -- [spellID] = { cdStart, cdDuration } (extrapolation cache)
Engine.entries         = {}   -- [spellID] = { spellID, name, icon, startTime, duration, endTime, ... }
Engine.cooldownViewerFound = false
Engine.testActive      = false
Engine.testSpellIDs    = { 184575, 853, 633, 642 }

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
-- Coverage focuses on Paladin retail spells from the user's actual tracked
-- list, plus universal items/utilities. Easy to extend later.
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

	-- Layer hardcoded fallbacks UNDER persisted (persisted wins because
	-- it's potentially talent-adjusted from real observation).
	for spellID, duration in pairs(FALLBACK_DURATIONS) do
		if not self.knownDurations[spellID] then
			self.knownDurations[spellID] = duration
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
		if ns.CDM and ns.CDM.Print then
			ns.CDM:Print("Curves built: ready + progress")
		end
		return true
	end
	return false
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

					local name, icon = GetSpellNameIcon(effectiveID)
					self.trackedSpells[effectiveID] = {
						name       = name,
						icon       = icon,
						category   = info.category,
						hasCharges = info.charges,
						cooldownID = cooldownID,
					}
					self.cdIDToSpellID[cooldownID] = effectiveID
				end
			end
		end
	end

	if ns.CDM and ns.CDM.Print then
		ns.CDM:Print("Tracking " .. self:CountTracked() .. " spells from Cooldown Viewer.")
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

function Engine:LearnDuration(spellID, dObj)
	if self.knownDurations[spellID] then return end
	if not dObj then return end
	if InCombatLockdown() then return end

	local ok, total = pcall(function()
		if dObj.GetTotalDuration then
			return dObj:GetTotalDuration()
		end
		return nil
	end)
	if ok and type(total) == "number" and total > 1.5 then
		self.knownDurations[spellID] = total
		local rOk, remaining = pcall(function()
			if dObj.GetRemainingDuration then
				return dObj:GetRemainingDuration()
			end
			return nil
		end)
		if rOk and type(remaining) == "number" and remaining > 0 then
			self.cdTimingCache[spellID] = {
				cdStart    = GetTime() - (total - remaining),
				cdDuration = total,
			}
		end
	end
end


function Engine:PollOneSpell(spellID, tracked)
	if not (C_Spell and C_Spell.GetSpellCooldownDuration) then
		return nil
	end

	-- Always try the direct read first. Out of combat, values are
	-- readable. In combat, they're often secret — but pcall+type check
	-- catches that cleanly. If the read fails, we fall through to
	-- Strategy B (cache extrapolation).
	local dObj
	if tracked.hasCharges and C_Spell.GetSpellChargeDuration then
		local cOk, cD = pcall(C_Spell.GetSpellChargeDuration, spellID)
		if cOk then dObj = cD end
	end
	if not dObj then
		local ok, d = pcall(C_Spell.GetSpellCooldownDuration, spellID)
		if ok then dObj = d end
	end

	if dObj then
		local total, remaining
		local readOk = pcall(function()
			if dObj.GetTotalDuration then
				total = dObj:GetTotalDuration()
			end
			if dObj.GetRemainingDuration then
				remaining = dObj:GetRemainingDuration()
			end
		end)

		-- We need BOTH values to be plain numbers. If either is secret
		-- (in combat) or missing, fall through to extrapolation below.
		if readOk
			and type(total) == "number"
			and type(remaining) == "number" then

			-- Comparisons are safe here because type() == "number"
			-- guarantees the value isn't secret (secret values report
			-- as type "number" but trip a separate flag — however
			-- if our pcall succeeded AND type returned, we're clean).
			-- If this turns out not to be true, wrap in pcall.
			local cmpOk, valid = pcall(function()
				return total > 1.5 and remaining > 0.05
			end)

			if cmpOk and valid then
				self._curveEvalSuccess = self._curveEvalSuccess + 1

				local now = GetTime()
				local cdStart = now - (total - remaining)

				-- Persist to saved vars so /reload doesn't lose learning.
				-- Only update if we don't already have a value, OR if the
				-- newly observed value is significantly different (talent
				-- change, etc.).
				local prev = self.knownDurations[spellID]
				if not prev or math.abs(prev - total) > 1 then
					self.knownDurations[spellID] = total
					self:SavePersistedDuration(spellID, total)
				end

				self.cdTimingCache[spellID] = {
					cdStart    = cdStart,
					cdDuration = total,
				}

				return {
					startTime = cdStart,
					duration  = total,
					endTime   = cdStart + total,
				}
			end
		end

		-- Read attempted, failed or returned secret values.
		-- Track in counter only if we actually got something back —
		-- a nil dObj wouldn't be a "fail."
		if readOk then
			self._curveEvalFail = self._curveEvalFail + 1
		end
	end

	-- Strategy B fallback: extrapolate from cache built earlier.
	local cache = self.cdTimingCache[spellID]
	if not cache then
		-- Strategy C: We have a KNOWN duration (hardcoded or persisted)
		-- but no cache. If this is being polled because of an event
		-- trigger (set by OnSpellUpdate below), assume a fresh cast.
		-- The "freshly cast" flag is consumed once per spell.
		if self._freshCastFlags and self._freshCastFlags[spellID] then
			self._freshCastFlags[spellID] = nil
			local known = self.knownDurations[spellID]
			if known and known > 1.5 then
				local now = GetTime()
				self.cdTimingCache[spellID] = {
					cdStart    = now,
					cdDuration = known,
				}
				self._strategyCUsed = (self._strategyCUsed or 0) + 1
				return {
					startTime = now,
					duration  = known,
					endTime   = now + known,
				}
			end
		end
		return nil
	end

	local now = GetTime()
	local rem = (cache.cdStart + cache.cdDuration) - now
	if rem <= 0 then return nil end

	self._fallbackUsed = self._fallbackUsed + 1
	return {
		startTime = cache.cdStart,
		duration  = cache.cdDuration,
		endTime   = cache.cdStart + cache.cdDuration,
	}
end


function Engine:PollAllSpells()
	if not self:EnsureCurves() then return end

	local seen = {}

	for spellID, tracked in pairs(self.trackedSpells) do
		local timing = self:PollOneSpell(spellID, tracked)
		if timing then
			seen[spellID] = true
			local existing = self.entries[spellID]

			-- Decide whether to replace the entry or just refresh endTime.
			-- Wrap comparison in pcall in case timing values are still secret.
			local shouldReplace = not existing
			if existing then
				local cmpOk, diff = pcall(function()
					return math.abs((existing.endTime or 0) - (timing.endTime or 0))
				end)
				if not cmpOk or type(diff) ~= "number" or diff > 0.5 then
					shouldReplace = true
				end
			end

			if shouldReplace then
				local cat = tracked.category or 0
				self.entries[spellID] = {
					spellID    = spellID,
					name       = tracked.name,
					icon       = tracked.icon,
					startTime  = timing.startTime,
					duration   = timing.duration,
					endTime    = timing.endTime,
					laneIndex  = self:ResolveLaneIndex(spellID, cat),
					category   = cat,
					_source    = "curve-eval",
				}
			else
				existing.endTime = timing.endTime
			end
		end
	end

	-- Prune entries that were not seen this poll, BUT preserve entries
	-- where we still have a valid cache. The cache is more reliable than
	-- a single failed poll attempt — if the spell's timer in cdTimingCache
	-- says it's still running, keep showing it. The Tick prune step
	-- handles natural expiration via endTime.
	local now = GetTime()
	for spellID, entry in pairs(self.entries) do
		if not seen[spellID] and entry._source ~= "test" then
			local cache = self.cdTimingCache[spellID]
			if cache and (cache.cdStart + cache.cdDuration) > now then
				-- Cache says this entry is still valid. Keep it; refresh
				-- endTime from the cache to be safe.
				entry.endTime = cache.cdStart + cache.cdDuration
			else
				-- No cache, or cache expired. Safe to prune.
				self.entries[spellID] = nil
			end
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
end


-- ============================================================================
-- Tick loop
-- ============================================================================

function Engine:Tick()
	self._tickCount = self._tickCount + 1
	local now = GetTime()

	-- Prune naturally-expired entries. endTime values could be tainted
	-- if they came from a secret-tainted progress eval, so wrap in pcall.
	for spellID, entry in pairs(self.entries) do
		if entry.endTime then
			local cmpOk, expired = pcall(function()
				return now >= entry.endTime
			end)
			if cmpOk and expired then
				self.entries[spellID] = nil
			end
		end
	end

	if not self.testActive then
		self:PollAllSpells()
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
			self:EnsureCurves()
		end)
	end

	if not self.specEventFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_SPECIALIZATION_CHANGED" then
				wipe(self.knownDurations)
				wipe(self.cdTimingCache)
				self:BuildTrackedSpells()
			end
		end)
		self.specEventFrame = f
	end

	-- SPELL_UPDATE_COOLDOWN listener — fires when ANY cooldown changes.
	-- Schedules a deferred poll so UNIT_SPELLCAST_SUCCEEDED has a chance
	-- to set fresh-cast flags before we run the poll. Without the defer,
	-- there's a race: SPELL_UPDATE_COOLDOWN may fire before UCS, causing
	-- PollAllSpells to skip the spell (no flag yet), and then UCS sets
	-- the flag but no poll runs.
	if not self.spellUpdateFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		f:SetScript("OnEvent", function(_, event)
			if Engine.testActive then return end
			-- Defer ~50ms; UCS typically fires within 1-2 frames of
			-- the cast event burst.
			C_Timer.After(0.05, function()
				if not Engine.testActive then
					Engine:PollAllSpells()
				end
			end)
		end)
		self.spellUpdateFrame = f
	end

	-- UNIT_SPELLCAST_SUCCEEDED listener — fires when a specific spell
	-- is cast successfully. We use this to set the "fresh cast" flag
	-- for that one spell, so Strategy C can seed its cache from a
	-- known-duration value when direct reads are tainted in combat.
	if not self.castSucceededFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		f:SetScript("OnEvent", function(_, event, unit, _, spellID)
			if Engine.testActive then return end
			if unit ~= "player" then return end
			if not spellID then return end
			-- The spell that was cast may not be in trackedSpells if it's
			-- a base ID and we track the override (or vice versa). Try
			-- both: direct match first, then a matching override.
			local matchedID
			if Engine.trackedSpells[spellID] then
				matchedID = spellID
			else
				-- Sweep trackedSpells looking for an override match.
				-- This is rare but covers cases like Avenging Wrath
				-- variants where the talent override has a different ID
				-- than the cast event reports.
				for trackedID, info in pairs(Engine.trackedSpells) do
					if info.cooldownID and Engine.cdIDToSpellID
						and Engine.cdIDToSpellID[info.cooldownID] == spellID then
						matchedID = trackedID
						break
					end
				end
			end
			if matchedID then
				Engine._freshCastFlags = Engine._freshCastFlags or {}
				Engine._freshCastFlags[matchedID] = true
				Engine._castEventCount = (Engine._castEventCount or 0) + 1
				-- Immediate poll to consume the flag while it's fresh.
				Engine:PollAllSpells()
			end
		end)
		self.castSucceededFrame = f
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

	if ns.CDM and ns.CDM.Print then
		ns.CDM:Print("Engine started: curve-evaluation strategy")
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
