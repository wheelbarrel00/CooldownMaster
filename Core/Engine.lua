local ADDON_NAME, ns = ...

ns.Engine = {}
local Engine = ns.Engine

Engine.trackedSpells   = {}
Engine.trackedItems    = {}
Engine.cdIDToSpellID   = {}
Engine.knownDurations  = {}   -- learned out of combat / persisted; talent-adjusted, overrides baseline
Engine.baselineDurations = {} -- hardcoded fallback or GetSpellBaseCooldown seed; used only when nothing learned
Engine.cdTimingCache   = {}
Engine.entries         = {}
Engine.cooldownViewerFound = false
Engine.testActive      = false
Engine.testSpellIDs    = { 184575, 853, 633, 642 }

-- C_CooldownViewer enumerates spells only, so potion itemIDs are listed here
-- and read directly via C_Container.GetItemCooldown.
local POTION_ITEMS = {
	241308, 241304, 241309, 241323, 258318,
}

Engine.readyCurve      = nil
Engine.progressCurve   = nil
local MAX_DURATION = 600

-- Baseline (no haste/talent) cooldowns; a learned read overrides these because
-- it accounts for talent modifications. Covers Paladin (Ret) and Mage (all specs).
local FALLBACK_DURATIONS = {
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

	[365350] = 90,   -- Arcane Surge
	[321507] = 45,   -- Touch of the Magi
	[12051]  = 90,   -- Evocation
	[205025] = 60,   -- Presence of Mind
	[157980] = 25,   -- Supernova
	[153626] = 60,   -- Arcane Orb (talent)

	[190319] = 120,  -- Combustion
	[257541] = 25,   -- Phoenix Flames (charge-based)
	[108853] = 12,   -- Fire Blast (charge-based)
	[31661]  = 20,   -- Dragon's Breath
	[153561] = 45,   -- Meteor
	[157981] = 25,   -- Blast Wave

	[84714]  = 60,   -- Frozen Orb
	[12472]  = 180,  -- Icy Veins
	[235219] = 270,  -- Cold Snap (resets Frost cooldowns)
	[205021] = 75,   -- Ray of Frost
	[153595] = 30,   -- Comet Storm
	[157997] = 25,   -- Ice Nova
	[33395]  = 25,   -- Freeze (water elemental / pet)

	[6948]   = 600,  -- Hearthstone
}

Engine._tickCount        = 0
Engine._curvesBuilt      = false


local function GetSpellNameIcon(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		if info then return info.name, info.iconID end
	end
	return "?", 134400
end


-- Async on first cache miss: returns nil until GET_ITEM_INFO_RECEIVED fires.
local function GetItemNameIcon(itemID)
	if not (C_Item and C_Item.GetItemInfo) then return nil, nil end
	local name = C_Item.GetItemInfo(itemID)
	local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or nil
	return name, icon
end


-- Hoisted to module scope so event handlers reuse one function reference rather
-- than allocate a closure per fire (SPELL_UPDATE_COOLDOWN fires 20-50 times/sec).
local function DeferredCooldownPoll()
	Engine._spellUpdatePending = nil
	if not Engine.testActive then
		Engine:ScanSpells()
	end
end


-- A cast fires UNIT_SPELLCAST_SUCCEEDED and SPELL_UPDATE_COOLDOWN within a few
-- frames; this 100ms window collapses the pair (and proc bursts) into one
-- ScanSpells. Each scan allocates a GetSpellCooldown table per tracked spell,
-- so scan count is the dominant GC knob.
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


-- Known durations are saved to AceDB so each spell only needs to be observed
-- once ever, surviving /reload and login.

function Engine:LoadPersistedDurations()
	local addon = ns.CDM
	if not (addon and addon.db) then return end
	addon.db.profile.knownDurations = addon.db.profile.knownDurations or {}

	for spellID, duration in pairs(addon.db.profile.knownDurations) do
		if type(spellID) == "number" and type(duration) == "number"
			and duration > 1.5 then
			self.knownDurations[spellID] = duration
		end
	end

	-- Fallbacks go in baselineDurations, not knownDurations: layering them into
	-- knownDurations makes LearnDuration's "already known" guard skip learning the
	-- real talent-adjusted duration.
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


local function BuildReadyCurve()
	if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum
		and Enum.LuaCurveType and Enum.LuaCurveType.Step) then
		return nil
	end
	local c = C_CurveUtil.CreateCurve()
	if not c then return nil end
	c:SetType(Enum.LuaCurveType.Step)
	c:AddPoint(0,     1)   -- remaining=0 -> ready
	c:AddPoint(0.001, 0)   -- remaining>0 -> on cooldown
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


-- GetSpellBaseCooldown returns the BASE cooldown in milliseconds (no
-- haste/talent). Lookup precedence: learned/persisted > hardcoded fallback >
-- this seed > 30s default.

-- Runs inside pcall so a comparison against a secret value (were the detector
-- ever unavailable) fails closed instead of erroring up the stack.
local function ReadBaseCooldownSeconds(spellID)
	local cdMS = GetSpellBaseCooldown(spellID)
	if cdMS == nil then return nil end
	local issecret = _G.issecretvalue
	if issecret and issecret(cdMS) then return nil end
	if type(cdMS) ~= "number" then return nil end
	-- Skip GCD-length/zero (charge spells report 0 here; recharge is learned instead).
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
		if not self.knownDurations[spellID]
			and not self.baselineDurations[spellID] then
			local ok, secs = pcall(ReadBaseCooldownSeconds, spellID)
			if ok and secs then
				self.baselineDurations[spellID] = secs
			end
		end
	end
end


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

					-- A spell can appear in multiple Cooldown Viewer categories;
					-- the ascending scan keeps the first (lowest) as its primary
					-- category, while later duplicates still record their cooldownID.
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

	self:SeedBaselineDurations()
end


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


function Engine:DefaultLaneForCategory(category)
	if category == 0 then return 1
	elseif category == 1 then return 2
	elseif category == 2 then return 3
	elseif category == 3 then return 3
	end
	return 1
end


-- Returns nil for categories outside the mapping (test entries, future categories).
function Engine:GetCategoryFilterKey(category)
	return ns.CONST.CATEGORY_TO_FILTER_KEY[category]
end


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

		local override = profile.spellOverrides and profile.spellOverrides[spellID]
		if override and override.lane then
			return override.lane
		end

		local key = self:GetCategoryFilterKey(category)
		local fcfg = key and profile.filters and profile.filters[key]
		if fcfg and fcfg.defaultLane then
			return fcfg.defaultLane
		end
	end
	return self:DefaultLaneForCategory(category)
end


-- Hoisted to module scope so LearnDuration's pcalls reuse these rather than
-- allocate two closures per call (it runs every scan for each not-yet-learned
-- active spell).
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
	-- Guard on knownDurations only: a baseline must not block learning the
	-- strictly-better talent-adjusted observation.
	if self.knownDurations[spellID] then return end
	if not dObj then return end
	if InCombatLockdown() then return end

	local ok, total = pcall(ReadTotalDuration, dObj)
	if ok and type(total) == "number" and total > 1.5 then
		self.knownDurations[spellID] = total
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


-- Remaining time is secret in combat (docs/EXPERIMENTS.md EXP-001/002), so the
-- entry set is driven off the readable C_Spell.GetSpellCooldown().isActive/
-- .isOnGCD booleans. The opaque DurationObject is handed to a native Cooldown
-- widget for the exact swipe/countdown; only icon position is extrapolated from
-- a duration learned out of combat.
function Engine:ScanSpells()
	if not (C_Spell and C_Spell.GetSpellCooldown) then return end

	self._seenSpells = self._seenSpells or {}
	local seen = self._seenSpells
	wipe(seen)

	local now = GetTime()
	local inCombat = InCombatLockdown()

	for spellID, tracked in pairs(self.trackedSpells) do
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)

		-- A true multi-charge spell (Shimmer, Fire Blast) reports isActive = false
		-- while any charge remains, and its spell-cooldown duration object comes back
		-- blank while a charge regenerates. Detect the recharge from the readable
		-- charge COUNT (maxCharges > 1, currentCharges < maxCharges; counts aren't
		-- secret in combat the way the durations are) so we can both TRACK it while a
		-- charge is regenerating and feed the widget the charge-duration object.
		-- Single-cooldown and 1-charge pseudo-charge spells (Touch of the Magi) fail
		-- the maxCharges > 1 test and keep the spell-cooldown path unchanged.
		local recharging, curCharges = false, nil
		if C_Spell.GetSpellCharges then
			local cok, ci = pcall(C_Spell.GetSpellCharges, spellID)
			if cok and type(ci) == "table" then
				curCharges = ci.currentCharges
				if ci.maxCharges and curCharges and ci.maxCharges > 1
					and curCharges < ci.maxCharges then
					recharging = true
				end
			end
		end

		---@diagnostic disable-next-line: undefined-field
		local active = ok and info and info.isActive and not info.isOnGCD
		if active or recharging then
			seen[spellID] = true

			local dObj
			if recharging and C_Spell.GetSpellChargeDuration then
				local cok, cd = pcall(C_Spell.GetSpellChargeDuration, spellID, true)
				if cok then dObj = cd end
			end
			if not dObj and C_Spell.GetSpellCooldownDuration then
				local dok, d = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
				if dok then dObj = d end
			end
			if not dObj and tracked.hasCharges and C_Spell.GetSpellChargeDuration then
				local cok, cd = pcall(C_Spell.GetSpellChargeDuration, spellID, true)
				if cok then dObj = cd end
			end

			-- Numbers are readable only out of combat: learn the talent/haste-
			-- adjusted duration here to feed in-combat extrapolation.
			if not inCombat and dObj then
				self:LearnDuration(spellID, dObj)
			end

			local existing = self.entries[spellID]
			if not existing then
				local cat = tracked.category or 0
				-- Position-extrapolation ladder: learned > baseline > 30s default.
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
					_charges  = curCharges,
				}
			else
				-- Still running: keep the extrapolated position (don't reset
				-- startTime), just refresh the handle.
				existing.dObj = dObj or existing.dObj
				-- Charge spells regenerate one charge at a time; when a charge lands
				-- mid-recharge the next charge's window restarts, so restart the
				-- extrapolated position (the countdown number stays exact via dObj).
				if curCharges and existing._charges and curCharges ~= existing._charges then
					existing.startTime = now
					existing.duration  = self.knownDurations[spellID]
						or self.baselineDurations[spellID]
						or existing.duration or 30
					existing.endTime   = now + existing.duration
					existing._charges  = curCharges
				end
			end
		end
	end

	-- isActive is authoritative for removal (covers proc resets). Items are
	-- pruned by PollAllItems and test entries by Tick, so skip both here.
	for spellID, entry in pairs(self.entries) do
		if entry._source ~= "test" and entry.kind ~= "item" and not seen[spellID] then
			-- Active->inactive edge = the spell is ready; fire the popup before discarding.
			-- Gate on trackedSpells so a spec swap that de-tracks a mid-cooldown spell
			-- discards it silently instead of firing a false ready popup.
			if self.trackedSpells and self.trackedSpells[spellID] and ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(spellID, entry)
			end
			self.entries[spellID] = nil
		end
	end
end


-- C_Container.GetItemCooldown returns plain numbers (no secret-value taint, no
-- DurationObject), so items can be read and compared directly.

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

	for itemID, entry in pairs(self.entries) do
		if entry.kind == "item" and not seen[itemID] then
			if ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(itemID, entry)
			end
			self.entries[itemID] = nil
		end
	end
end


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
	-- Repopulate immediately: the tick sweep runs at 1 Hz, so without this the
	-- lanes would sit empty for up to a second after leaving test mode.
	self:ScanSpells()
	self:PollAllItems()
end


function Engine:Tick()
	self._tickCount = self._tickCount + 1

	if self.testActive then
		-- Expire test entries by endTime. Live entries are removed only by
		-- ScanSpells (isActive), since the extrapolated endTime can be wrong.
		local now = GetTime()
		for spellID, entry in pairs(self.entries) do
			if entry._source == "test" and entry.endTime and now >= entry.endTime then
				self.entries[spellID] = nil
			end
		end
	else
		-- Safety-net sweep every 10th tick (1 Hz). Cooldown edges are caught by
		-- the event paths; this only covers events they miss (e.g. dropped across
		-- a loading screen). Scanning every tick allocated ~400 tables/sec at 40
		-- tracked spells, for data that rarely changed between ticks.
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


function Engine:Start(addon)
	self.addon = addon
	self.cooldownViewerFound = (C_CooldownViewer ~= nil
		and type(C_CooldownViewer.IsCooldownViewerAvailable) == "function")

	-- Must run before any polling so the extrapolator has data to use.
	self:LoadPersistedDurations()

	if not self._buildScheduled then
		self._buildScheduled = true
		C_Timer.After(1.5, function()
			self:BuildTrackedSpells()
			self:BuildTrackedItems()
			-- Discovery may land after the Filters tab opened; drop cached lists.
			if ns.Options_InvalidateFilterLists then
				ns.Options_InvalidateFilterLists()
			end
		end)
	end

	-- Item names/icons not cached at BuildTrackedItems time arrive later via
	-- GET_ITEM_INFO_RECEIVED.
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
		-- Unit-filter to "player": the unfiltered event also fires for party
		-- members' spec changes, which would needlessly wipe learned durations.
		f:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_SPECIALIZATION_CHANGED" then
				wipe(self.knownDurations)
				wipe(self.cdTimingCache)
				-- Re-layer persisted + fallback durations after the wipe, else the
				-- runtime table stays empty until /reload and everything
				-- extrapolates from the 30s default.
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

	-- Debounced so a burst of cooldown changes collapses into a single scan.
	if not self.spellUpdateFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		f:SetScript("OnEvent", function()
			if Engine.testActive then return end
			ScheduleDeferredScan()
		end)
		self.spellUpdateFrame = f
	end

	-- isActive (read in ScanSpells) is authoritative, so we needn't match the
	-- cast spellID or chase overrides. Debounced because the cast also fires
	-- SPELL_UPDATE_COOLDOWN a few frames later (otherwise two scans per cast).
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

	-- Item cooldowns have their own event, keeping potion icons prompt under the
	-- 1 Hz sweep. PollAllItems reads plain multi-values (~5 items), so no debounce.
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


local function ProbeClassify(issecret, fn, ...)
	if type(fn) ~= "function" then return "no-method" end
	local ok, v = pcall(fn, ...)
	if not ok then return "ERR: " .. tostring(v) end
	if v == nil then return "nil" end
	-- Confirm not-secret before touching v with format/tostring; without a
	-- detector we cannot, so refuse to risk it.
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
		-- EvaluateRemainingDuration(curve [, modifier]); modifier is optional and
		-- omitted (passing -1 is rejected with "bad argument #3").
		step      = stepCurve and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, stepCurve) or "n/a",
		linear    = linCurve  and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, linCurve) or "n/a",
		identity  = idCurve   and ProbeClassify(issecret, dObj.EvaluateRemainingDuration, dObj, idCurve) or "n/a",
	}
	cdm:Print(string.format("  %s raw : rem=%s  total=%s  isZero=%s", label, rec.remaining, rec.total, rec.isZero))
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
	local stepCurve = self.readyCurve
	local linCurve  = self.progressCurve

	-- Identity curve (0..600 -> 0..600): if it de-taints, the result is the
	-- remaining time in seconds outright.
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

	-- isActive/isOnGCD are not secret-protected (the taint-safe path Skiron uses).
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

		-- Last untested source: if GetSpellCooldown's start+duration are plain in
		-- combat, the timeline can be exact rather than extrapolated.
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

	-- Track the four paths separately: each can de-taint independently.
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
