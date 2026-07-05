local ADDON_NAME, ns = ...

ns.Engine = {}
local Engine = ns.Engine

Engine.trackedSpells   = {}
Engine.trackedItems    = {}
Engine.cdIDToSpellID   = {}
Engine.knownDurations  = {}   -- learned out of combat / persisted; talent-adjusted, overrides baseline
Engine.observedDurations = {} -- learned in combat from a spell's full observed lifetime; below known, above baseline
Engine._seenReady      = {}   -- spellIDs seen off their own cooldown this session; gates trusting an observed span
Engine._activeSince    = {}   -- when each spell's cooldown began (first isActive, during GCD) = its real start
Engine.baselineDurations = {} -- hardcoded fallback or GetSpellBaseCooldown seed; used only when nothing learned
Engine._chargeOnCdSince = {}  -- when a multi-charge spell's on-cooldown state began; debounces the partial-use isActive blip
Engine.cdTimingCache   = {}
Engine.entries         = {}
Engine.cooldownViewerFound = false
Engine.testActive      = false
Engine.testSpellIDs    = { 184575, 853, 633, 642 }
-- Gate ready-popup suppression during the loading-screen cooldown blackout (ScanSpells).
Engine._loadingScreen      = false
Engine._readyBlackoutUntil = 0
-- Cast->re-anchor pipeline counters for the /cm anchor probe (numbers only; no per-cast allocs).
Engine._probe = { seen = 0, matched = 0, anchored = 0, aliasHit = 0 }
Engine._traceState = {}   -- per-spell last state string for the /cm anchor arm tracer

-- C_CooldownViewer enumerates spells only, so potion itemIDs are listed here as a
-- baseline and read via C_Container.GetItemCooldown; BuildTrackedItems also bag-scans.
local POTION_ITEMS = {
	241308, 241304, 241309, 241323, 258318,
}

-- Blizzard ItemConsumableSubclass IDs (verify in-game): 1 = Potion, 3 = Flask/Phial.
local TRACKED_CONSUMABLE_SUBCLASS = { [1] = true, [3] = true }
local TRINKET_SLOTS = { 13, 14 }

Engine.readyCurve      = nil
Engine.progressCurve   = nil
local MAX_DURATION = 600
-- A persisted/learned duration at or below this is a GCD-length mis-read, not a real cooldown.
-- Both the load filter and the trust check (KNOWN_TRUST_MIN) reject it so the spell falls back to
-- its baseline instead of extrapolating from ~1.5s and snapping to the ready edge with time left.
local MIN_TRUSTED_DURATION = 2.5

local READY_BLACKOUT_GRACE = 3      -- grace (s) after a loading screen; cooldowns re-sync late
local READY_MAX_POPS_PER_SCAN = 3   -- more ready edges than this in one scan = a blackout, not real
-- Two ready edges count as one shared cooldown if they started together and end within this
-- window; mirrors the lane dedupe (UI/Lanes.lua) so ready pops collapse the same way.
local SHARED_CD_TOL = 0.5

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


-- Player's i-th HELPFUL aura via modern C_UnitAuras, or legacy UnitAura on Classic.
local function GetPlayerBuff(i)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if d then return d.name, d.spellId, d.duration, d.icon, d.expirationTime end
	elseif UnitAura then
		local name, icon, _, _, duration, expiration, _, _, _, spellID = UnitAura("player", i, "HELPFUL")
		return name, spellID, duration, icon, expiration
	end
end


-- Instant path: nil until the item is cached; addItem's ItemMixin fills it in async.
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


-- Collapse the cast's UNIT_SPELLCAST_SUCCEEDED + SPELL_UPDATE_COOLDOWN (and proc
-- bursts) into one ScanSpells; each scan allocates a table per tracked spell, so
-- scan count is the dominant GC knob.
local SCAN_DEBOUNCE = 0.1
local function ScheduleDeferredScan()
	if Engine._spellUpdatePending then return end
	Engine._spellUpdatePending = true
	C_Timer.After(SCAN_DEBOUNCE, DeferredCooldownPoll)
end


-- Bags/equipment change far more often than the tracked-item set actually does, so
-- collapse a burst (looting, swapping) into one rescan + filter-list refresh.
local function ScheduleItemRebuild()
	if Engine._itemRebuildPending then return end
	Engine._itemRebuildPending = true
	C_Timer.After(0.5, function()
		Engine._itemRebuildPending = nil
		if Engine.testActive then return end
		Engine:BuildTrackedItems()
		Engine:PollAllItems()
		if ns.Options_InvalidateFilterLists then ns.Options_InvalidateFilterLists() end
	end)
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


-- Persisted to AceDB so each spell is observed once ever, surviving /reload and login.

function Engine:LoadPersistedDurations()
	local addon = ns.CDM
	if not (addon and addon.db) then return end
	-- Start from the active profile alone: every learn is persisted the moment it happens, so
	-- nothing is lost, and a previously active profile's knowns can no longer skew BestDuration
	-- or mis-trigger the observed-duration purge below after a manual profile switch.
	wipe(self.knownDurations)
	wipe(self.observedDurations)
	addon.db.profile.knownDurations = addon.db.profile.knownDurations or {}

	for spellID, duration in pairs(addon.db.profile.knownDurations) do
		if type(spellID) == "number" and type(duration) == "number"
			and duration >= MIN_TRUSTED_DURATION then
			self.knownDurations[spellID] = duration
		elseif type(spellID) == "number" then
			-- Purge GCD-length garbage a pre-floor build persisted (e.g. Divine Shield stored as
			-- 1.5s): it made the icon undershoot and park at the ready edge. Dropping it self-heals
			-- the saved file so the spell re-learns cleanly or falls back to baseline.
			addon.db.profile.knownDurations[spellID] = nil
		end
	end

	addon.db.profile.observedDurations = addon.db.profile.observedDurations or {}
	for spellID, duration in pairs(addon.db.profile.observedDurations) do
		local known = type(spellID) == "number" and self.knownDurations[spellID]
		if type(spellID) == "number" and type(duration) == "number"
			and duration >= MIN_TRUSTED_DURATION
			-- A span several times the precise out-of-combat read is a spam artifact from
			-- before charge recasts re-anchored the entry (one entry lived across many casts);
			-- keep observed only when it's plausibly a single real cooldown.
			and not (known and duration > known * 3) then
			self.observedDurations[spellID] = duration
		elseif type(spellID) == "number" then
			addon.db.profile.observedDurations[spellID] = nil
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

	if not ns.Compat.HAS_BLIZZ_CDM then
		self:BuildTrackedSpellsClassic()
		return
	end

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


-- Classic has no C_CooldownViewer: scan the spellbook, keep spells whose base cooldown exceeds the GCD.
function Engine:BuildTrackedSpellsClassic()
	if type(GetSpellBaseCooldown) ~= "function" then return end

	self.gcdProbe = nil
	local seenNames = {}
	local function consider(spellID)
		if not spellID or self.trackedSpells[spellID] then return end
		-- The spellbook enumerates inactive-spec tabs too (a Blood DK sees Frost's Pillar of
		-- Frost); IsPlayerSpell keeps only what the active spec can actually cast.
		if IsPlayerSpell and not IsPlayerSpell(spellID) then return end
		local cdMS, gcdMS = GetSpellBaseCooldown(spellID)
		-- First known on-GCD, no-cooldown spell doubles as a GCD probe: its live cooldown
		-- reflects the GCD on pre-3.0 clients where spell 61304/Moonfire don't (per-class).
		if not self.gcdProbe and gcdMS and gcdMS > 0 and (not cdMS or cdMS <= gcdMS) then
			self.gcdProbe = spellID
		end
		if not cdMS or cdMS <= 0 or cdMS <= (gcdMS or 0) then return end
		local name, icon = GetSpellNameIcon(spellID)
		-- MoP ships per-spec spell variants under one name (Soul Reaper x3); dedupe by name.
		if not name or seenNames[name] then return end
		seenNames[name] = true
		local cat = ns.CONST.CLASSIC_UTILITY_SPELLS[spellID] and 1 or 0
		self.trackedSpells[spellID] = { name = name, icon = icon, category = cat }
	end

	if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
		local bookType = BOOKTYPE_SPELL or "spell"
		for tab = 1, GetNumSpellTabs() do
			local offset, numSlots = select(3, GetSpellTabInfo(tab))
			if offset and numSlots then
				for j = offset + 1, offset + numSlots do
					consider((select(3, GetSpellBookItemName(j, bookType))))
				end
			end
		end
	elseif C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemType then
		local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
			if line and line.itemIndexOffset and line.numSpellBookItems then
				for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
					consider((select(2, C_SpellBook.GetSpellBookItemType(j, bank))))
				end
			end
		end
	end
end


-- Classic cooldown numbers are readable in combat (no secret values): entries carry real
-- start/duration and no dObj, so RefreshBody feeds the widget via SetCooldown.
function Engine:ScanSpellsClassic()
	local getCD = ns.Compat and ns.Compat.GetSpellCooldown
	if not getCD then return end

	self._seenSpells = self._seenSpells or {}
	local seen = self._seenSpells
	wipe(seen)
	local now = GetTime()

	for spellID, tracked in pairs(self.trackedSpells) do
		local start, duration = getCD(spellID)
		-- A real cooldown, not the shared 1.5s GCD every spell reports while one is running.
		if start and duration and start > 0 and duration > 1.5 then
			seen[spellID] = true
			local endTime = start + duration
			local e = self.entries[spellID]
			if not e then
				local cat = tracked.category or 0
				self.entries[spellID] = {
					spellID   = spellID,
					name      = tracked.name,
					icon      = tracked.icon,
					startTime = start,
					duration  = duration,
					endTime   = endTime,
					laneIndex = self:ResolveLaneIndex(spellID, cat),
					category  = cat,
					_source   = "classic",
				}
			else
				e.startTime = start
				e.duration  = duration
				e.endTime   = endTime
			end
		end
	end

	-- A loading screen briefly reports cooldowns as inactive, which would pop the whole set
	-- ready at once; keep entries and stay silent until the blackout window passes.
	local blackout = self._loadingScreen or now < (self._readyBlackoutUntil or 0)
	if not blackout then
		self._readyEdges = self._readyEdges or {}
		local edges = self._readyEdges
		wipe(edges)
		for spellID, e in pairs(self.entries) do
			if e._source == "classic" and not seen[spellID] then
				edges[#edges + 1] = spellID
			end
		end
		for _, spellID in ipairs(edges) do
			local e = self.entries[spellID]
			if self.trackedSpells[spellID] and ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(spellID, e)
			end
			self.entries[spellID] = nil
		end
	end
end


-- Classic buffs (Seals, Blessings) have no cooldown, so track them as auras timed by remaining
-- duration. Category 2 routes to the Buffs filter/lane; discovered lazily as auras appear.
function Engine:ScanBuffs()
	self._seenBuffs = self._seenBuffs or {}
	local seen = self._seenBuffs
	wipe(seen)
	local now = GetTime()
	local discovered = false

	for i = 1, 40 do
		local name, spellID, duration, icon, expiration = GetPlayerBuff(i)
		if not name then break end
		if spellID and duration and duration > 0 and expiration and expiration > now
			and IsPlayerSpell and IsPlayerSpell(spellID) then
			local tracked = self.trackedSpells[spellID]
			-- Don't fight a spell already tracked as a cooldown.
			if not tracked or tracked.category == 2 then
				if not tracked then
					self.trackedSpells[spellID] = { name = name, icon = icon, category = 2 }
					discovered = true
				end
				if self:IsSpellVisible(spellID, 2) then
					seen[spellID] = true
					local e = self.entries[spellID]
					if not e then
						self.entries[spellID] = {
							spellID   = spellID,
							name      = name,
							icon      = icon,
							startTime = expiration - duration,
							duration  = duration,
							endTime   = expiration,
							laneIndex = self:ResolveLaneIndex(spellID, 2),
							category  = 2,
							_source   = "buff",
						}
					elseif e._source == "buff" then
						e.startTime = expiration - duration
						e.duration  = duration
						e.endTime   = expiration
					end
				end
			end
		end
	end

	-- Loading screens briefly report no auras; keep entries and stay silent in the blackout.
	local blackout = self._loadingScreen or now < (self._readyBlackoutUntil or 0)
	if not blackout then
		self._buffEdges = self._buffEdges or {}
		local edges = self._buffEdges
		wipe(edges)
		for spellID, e in pairs(self.entries) do
			if e._source == "buff" and not seen[spellID] then
				edges[#edges + 1] = spellID
			end
		end
		for _, spellID in ipairs(edges) do
			local e = self.entries[spellID]
			if self:IsSpellVisible(spellID, 2) and ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(spellID, e)
			end
			self.entries[spellID] = nil
		end
	end

	if discovered and ns.Options_InvalidateFilterLists then
		ns.Options_InvalidateFilterLists()
	end
end


function Engine:BuildTrackedItems()
	wipe(self.trackedItems)

	if not (C_Container and C_Container.GetItemCooldown) then
		return
	end

	local function addItem(itemID, category, slot)
		if not itemID or self.trackedItems[itemID] then return end
		local name, icon = GetItemNameIcon(itemID)
		self.trackedItems[itemID] = {
			name     = name or ("Item " .. itemID),
			icon     = icon or 134400,
			category = category,
			kind     = "item",
			slot     = slot,   -- set for equipped trinkets (polled via the inventory slot)
		}
		-- ItemMixin fills real name/icon/link once the item data loads (or now if cached).
		if Item and Item.CreateFromItemID then
			local item = Item:CreateFromItemID(itemID)
			if not item:IsItemEmpty() then
				item:ContinueOnItemLoad(function()
					local tracked = Engine.trackedItems[itemID]
					if not tracked then return end
					tracked.name = item:GetItemName() or tracked.name
					tracked.icon = item:GetItemIcon() or tracked.icon
					tracked.link = item:GetItemLink()
					if ns.Options_UpdateTrackedItemDisplay then
						ns.Options_UpdateTrackedItemDisplay(itemID, tracked.name, tracked.icon)
					end
				end)
			end
		end
	end

	-- Retail Midnight potion IDs; absent on Classic/TBC, so there the bag scan below is the only source.
	if ns.Compat.HAS_BLIZZ_CDM then
		for _, itemID in ipairs(POTION_ITEMS) do
			addItem(itemID, ns.CONST.POTION_CATEGORY)
		end
	end

	-- Auto-discover carried potions/flasks from the bags (reagent bag excluded).
	local consumableClass = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
	if C_Item and C_Item.GetItemInfoInstant then
		for bag = 0, (NUM_BAG_SLOTS or 4) do
			local numSlots = C_Container.GetContainerNumSlots(bag) or 0
			for slot = 1, numSlots do
				local itemID = C_Container.GetContainerItemID(bag, slot)
				if itemID then
					local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
					if classID == consumableClass and TRACKED_CONSUMABLE_SUBCLASS[subclassID] then
						addItem(itemID, ns.CONST.POTION_CATEGORY)
					end
				end
			end
		end
	end

	-- Equipped on-use trinkets (slots 13/14). GetItemSpell is nil for passive trinkets.
	if C_Item and C_Item.GetItemSpell and GetInventoryItemID then
		for _, eslot in ipairs(TRINKET_SLOTS) do
			local itemID = GetInventoryItemID("player", eslot)
			if itemID and C_Item.GetItemSpell(itemID) then
				addItem(itemID, ns.CONST.TRINKET_CATEGORY, eslot)
			end
		end
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

	-- Ignore Threshold: hide an ability whose full cooldown is longer than the category's
	-- threshold -- a static "don't track hour-long cooldowns" filter, distinct from a lane's
	-- maxTime display window. Only when the length is known; an explicit override above wins.
	local thr = fcfg.ignoreThreshold
	if thr and spellID then
		local dur = self:BestDuration(spellID)
		if dur and dur > thr then return false end
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
-- allocate two closures per call (runs every scan for each unlearned active spell).
local function ReadTotalDuration(dObj)
	if dObj.GetTotalDuration then
		local v = dObj:GetTotalDuration()
		-- Can come back secret even out of combat lockdown (instances, or a scan landing on
		-- the combat-end boundary); returning it would let the caller's compare taint-throw.
		local issecret = _G.issecretvalue
		if issecret and issecret(v) then return nil end
		return v
	end
	return nil
end

local function ReadRemainingDuration(dObj)
	if dObj.GetRemainingDuration then
		local v = dObj:GetRemainingDuration()
		local issecret = _G.issecretvalue
		if issecret and issecret(v) then return nil end
		return v
	end
	return nil
end


-- A learned (known) duration this short is indistinguishable from a GCD-length mis-read.
local KNOWN_TRUST_MIN = MIN_TRUSTED_DURATION

-- A multi-charge spell blips isActive for ~1 GCD on a partial-charge use (and isOnGCD comes
-- back nil for these, so it can't gate the blip). Only track once the on-cooldown state has
-- persisted past this, so just a real full-depletion recharge (far longer) shows. > base GCD.
local CHARGE_TRACK_DELAY = 1.6

function Engine:LearnDuration(spellID, dObj)
	if not dObj then return end
	if InCombatLockdown() then return end

	-- Re-learn (overwrite) rather than write-once, so a value gone stale across a patch or
	-- tuning self-corrects from the next clean out-of-combat read. The GCD-length floor rejects
	-- a read taken during the GCD -- that's how a bogus too-short known got stored before.
	local ok, total = pcall(ReadTotalDuration, dObj)
	if ok and type(total) == "number" and total > KNOWN_TRUST_MIN then
		local cur = self.knownDurations[spellID]
		-- Skip a no-op rewrite, but keep the window tight so a small real correction
		-- (a learned 7.9 tightening to a true 8.0) still lands.
		if cur and math.abs(cur - total) < 0.05 then return end
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


-- Learn a cooldown's real length from its observed wall-clock span when it finishes
-- (combat-safe, no secret read); rescues spells whose extrapolation undershoots (charge
-- spells, or any never seen on cooldown out of combat). Stored below knownDurations so a
-- precise out-of-combat read still wins. Converge UP only: the longest span seen is the true cd.
function Engine:ObserveDuration(spellID, observed)
	if type(observed) ~= "number" or observed <= 1.5 then return end
	local current = self.observedDurations[spellID]
	if current and observed <= current + 0.5 then return end
	self.observedDurations[spellID] = observed
	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.observedDurations = addon.db.profile.observedDurations or {}
		addon.db.profile.observedDurations[spellID] = observed
	end
end


-- A successful cast restarts the cooldown NOW: re-anchor the start so a spell recast before
-- a scan caught its ready gap keeps extrapolating from this cast, not the run's first (which
-- pinned the icon at the ready edge).
function Engine:OnTrackedCast(spellID)
	if not spellID then return end
	local p = self._probe
	local tracked = self.trackedSpells and self.trackedSpells[spellID]
	if not tracked and C_Spell and C_Spell.GetBaseSpell then
		-- Override casts (Templar Slash firing for tracked Templar Strike) arrive under their
		-- own ID; map back to the tracked base so the shared cooldown still re-anchors.
		-- C_Spell.GetBaseSpell is the Midnight API (Skiron/ToxiUI use it; FindBaseSpellByID is dead).
		local base = C_Spell.GetBaseSpell(spellID)
		if base and base ~= spellID and self.trackedSpells[base] then
			spellID, tracked = base, self.trackedSpells[base]
			p.aliasHit = p.aliasHit + 1
		end
	end
	if not tracked then return end
	p.matched = p.matched + 1
	local now = GetTime()
	local e = self.entries[spellID]
	if tracked.hasCharges then
		-- A depleted charge spell can't be cast at 0 charges, so a cast landing while its
		-- entry is live proves a charge just recharged and was spell-queue-consumed before
		-- any scan saw isActive drop. Without this the entry extrapolates from a start many
		-- casts old and parks at the ready edge; restart the next-charge wait from this cast.
		if e and e._source == "isactive" then
			self._activeSince[spellID] = now
			e.startTime = now
			e.endTime   = now + (e.duration or 0)
			e._fresh    = true
			p.anchored, p.lastAnchorAt, p.lastAnchorID = p.anchored + 1, now, spellID
			if self._traceUntil and ns.CDM then
				ns.CDM:Print(string.format("[trace] %s ANCHORED (charge cast)", tostring(tracked.name)))
			end
		end
		return
	end
	self._activeSince[spellID] = now
	if e and e._source == "isactive" then
		e.startTime = now
		e.endTime   = now + (e.duration or 0)
		e._fresh    = true
		p.anchored, p.lastAnchorAt, p.lastAnchorID = p.anchored + 1, now, spellID
		if self._traceUntil and ns.CDM then
			ns.CDM:Print(string.format("[trace] %s ANCHORED (cast)", tostring(tracked.name)))
		end
	end
end


-- /cm anchor: one-shot report of the cast->re-anchor pipeline plus live entry ages, to
-- pin down why a parked icon isn't re-anchoring (event dead / secret spellID / gate miss).
function Engine:RunAnchorProbe()
	local cdm = ns.CDM
	if not cdm then return end
	local p = self._probe
	local now = GetTime()
	cdm:Print(string.format("anchor probe: castSeen=%d matched=%d anchored=%d aliasHit=%d",
		p.seen, p.matched, p.anchored, p.aliasHit))
	local okID, lastID = pcall(tostring, p.lastID)
	cdm:Print(string.format("last cast: id=%s secret=%s ago=%s | last anchor: id=%s ago=%s",
		okID and lastID or "?", tostring(p.lastSecret),
		p.lastSeenAt and string.format("%.1fs", now - p.lastSeenAt) or "never",
		tostring(p.lastAnchorID),
		p.lastAnchorAt and string.format("%.1fs", now - p.lastAnchorAt) or "never"))
	for id, e in pairs(self.entries) do
		if e._source == "isactive" then
			local tracked = self.trackedSpells[id]
			cdm:Print(string.format(
				"  %s (id=%d): startAge=%.1f dur=%.1f extRemain=%.1f hasCharges=%s activeSince=%s",
				tostring(e.name), id,
				now - (e.startTime or now), e.duration or 0, (e.endTime or now) - now,
				tostring(tracked and tracked.hasCharges),
				self._activeSince[id]
					and string.format("%.1fs ago", now - self._activeSince[id]) or "nil"))
		end
	end
end


-- Extrapolation duration. A plausible out-of-combat known (exact, haste/talent-adjusted) wins
-- outright; the in-combat observation only rescues a missing or GCD-bogus known, as the longer
-- of the two (obs over-counts recasts, so it can't be trusted over a good known). Baseline/
-- default are the caller's fallback below this.
function Engine:BestDuration(spellID)
	local k = self.knownDurations[spellID]
	local o = self.observedDurations[spellID]
	if k and k > KNOWN_TRUST_MIN then return k end
	if k and o then return (k > o) and k or o end
	return k or o
end


-- Sort ready edges by cooldown start (then spellID) so shared-cooldown siblings are
-- contiguous and the lowest spellID leads its group; module-level to avoid a per-scan closure.
local function ByReadyEdge(a, b)
	local ea, eb = Engine.entries[a], Engine.entries[b]
	local sa = (ea and ea.startTime) or 0
	local sb = (eb and eb.startTime) or 0
	if sa ~= sb then return sa < sb end
	return a < b
end


-- Remaining time is secret in combat (docs/EXPERIMENTS.md EXP-001/002), so the entry set is
-- driven off the readable GetSpellCooldown().isActive/.isOnGCD booleans; the opaque
-- DurationObject feeds a native Cooldown widget for the exact swipe, only position is extrapolated.
function Engine:ScanSpells()
	if not ns.Compat.HAS_BLIZZ_CDM then
		self:ScanSpellsClassic()
		self:ScanBuffs()
		return
	end
	if not (C_Spell and C_Spell.GetSpellCooldown) then return end

	self._seenSpells = self._seenSpells or {}
	local seen = self._seenSpells
	wipe(seen)

	local now = GetTime()
	local inCombat = InCombatLockdown()

	for spellID, tracked in pairs(self.trackedSpells) do
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)

		-- A true multi-charge spell (Shimmer, Fire Blast) reports isActive = false while any
		-- charge remains, so it's on cooldown only once fully depleted. currentCharges is
		-- SECRET in combat (reading or comparing it taints and throws) but maxCharges is, so
		-- maxCharges > 1 plus the isActive gate below means fully depleted; then feed the
		-- charge-duration object (blank for charge spells). 1-charge spells use the normal path.
		-- Probed once per tracked-set build and cached (per-scan probing allocated a table per
		-- spell per scan; gating on the CooldownViewer charges flag missed stale flags), so the
		-- cache refreshes on the TRAIT_CONFIG_UPDATED / spec-change rebuilds.
		local multiCharge = tracked.multiCharge
		if multiCharge == nil then
			multiCharge = false
			if C_Spell.GetSpellCharges then
				local cok, ci = pcall(C_Spell.GetSpellCharges, spellID)
				if cok and type(ci) == "table" and ci.maxCharges and ci.maxCharges > 1 then
					multiCharge = true
				end
			end
			tracked.multiCharge = multiCharge
		end

		---@diagnostic disable-next-line: undefined-field
		local rawActive = ok and info and info.isActive
		---@diagnostic disable-next-line: undefined-field
		local active = rawActive and not info.isOnGCD

		-- Anchor bookkeeping must use the GCD-FILTERED state: the GCD blips EVERY ready spell
		-- isActive+isOnGCD for its duration (verified via /cm anchor trace), and under chained-GCD
		-- rotation spam the 0.1s-debounced scans land inside successive blips, so a stamp taken
		-- from bare isActive survives for many seconds; a charge entry born later inherited that
		-- ancient stamp and spawned already parked at the ready edge.
		if active then
			if not self._activeSince[spellID] then self._activeSince[spellID] = now end
		elseif ok and info then
			self._activeSince[spellID] = nil
			-- Genuinely off its own cooldown (not just GCD-blipped; charges may remain): a
			-- later depletion's observed span can be trusted as a full cooldown.
			if not rawActive then self._seenReady[spellID] = true end
		end

		-- Multi-charge blip filter: a partial use blips isActive for ~1 GCD (isOnGCD is nil here
		-- so it can't gate it, and IsSpellUsable ignores charge count), while full depletion holds
		-- it for the whole recharge. Require the active state to persist past CHARGE_TRACK_DELAY so
		-- only a real recharge shows. 1-charge/non-charge spells exempt.
		if multiCharge then
			if active then
				self._chargeOnCdSince[spellID] = self._chargeOnCdSince[spellID] or now
				if now - self._chargeOnCdSince[spellID] < CHARGE_TRACK_DELAY then
					active = false
				end
			else
				self._chargeOnCdSince[spellID] = nil
			end
		end

		-- /cm anchor arm: 12s state tracer. Prints only on transitions, so chat stays readable;
		-- one nil-check per spell per scan when disarmed.
		if self._traceUntil then
			if now > self._traceUntil then
				self._traceUntil = nil
				if ns.CDM then ns.CDM:Print("anchor trace done.") end
			elseif rawActive or self.entries[spellID] or self._traceState[spellID] then
				local st = (rawActive and "A" or "a")
					.. ((ok and info and info.isOnGCD) and "G" or "g")
					.. (active and "V" or "v")
					.. (self.entries[spellID] and "E" or "e")
					.. (multiCharge and "M" or "m")
				if st ~= self._traceState[spellID] then
					self._traceState[spellID] = st
					local e2 = self.entries[spellID]
					if ns.CDM then
						ns.CDM:Print(string.format("[trace] %s %s startAge=%s activeSince=%s",
							tostring(tracked.name or spellID), st,
							e2 and string.format("%.1f", now - (e2.startTime or now)) or "-",
							self._activeSince[spellID]
								and string.format("%.1f", now - self._activeSince[spellID]) or "-"))
					end
				end
			end
		end

		if active then
			seen[spellID] = true

			local dObj
			if multiCharge and C_Spell.GetSpellChargeDuration then
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
				-- Position-extrapolation ladder: longer of learned/observed > baseline > 30s.
				local duration = self:BestDuration(spellID)
					or self.baselineDurations[spellID]
					or 30
				local startTime = self._activeSince[spellID] or now
				-- An anchor so old the extrapolated cooldown would already be over renders the
				-- icon parked at the ready edge from birth; it carries no information, so
				-- anchor at discovery instead and let the icon make one full travel.
				if startTime + duration <= now then startTime = now end
				self.entries[spellID] = {
					spellID   = spellID,
					name      = tracked.name,
					icon      = tracked.icon,
					startTime = startTime,
					duration  = duration,
					endTime   = startTime + duration,
					laneIndex = self:ResolveLaneIndex(spellID, cat),
					category  = cat,
					dObj      = dObj,
					-- Trust the span for learning only if we saw this spell ready first.
					_fresh    = self._seenReady[spellID] or false,
					_source   = "isactive",
				}
				if self._traceUntil and ns.CDM then
					ns.CDM:Print(string.format("[trace] %s ENTRY CREATED start=%.1fs-ago dur=%.1f",
						tostring(tracked.name), now - startTime, duration))
				end
			else
				-- Still running: keep the extrapolated position (don't reset
				-- startTime), just refresh the handle.
				existing.dObj = dObj or existing.dObj
				-- A duration learned after the entry was created (born in combat at the 30s default,
				-- then learned) replaces the stale guess: keep startTime, correct only the span (dObj exact).
				local learned = self:BestDuration(spellID)
				if learned and existing.duration ~= learned then
					existing.duration = learned
					existing.endTime  = existing.startTime + learned
				end
			end
		end
	end

	-- A loading screen briefly reports every cooldown as not-active, so a scan landing there
	-- would pop the whole set ready at once. Suppress popups in the blackout window (keep
	-- entries), and as a backstop stay silent if an implausibly large batch goes ready at once.
	local blackout = self._loadingScreen or now < (self._readyBlackoutUntil or 0)

	self._readyEdges = self._readyEdges or {}
	local edges = self._readyEdges
	wipe(edges)
	for spellID, entry in pairs(self.entries) do
		if entry._source ~= "test" and entry.kind ~= "item" and not seen[spellID] then
			-- Hidden spells stay out of the ready sweep + shared-cd dedupe (else a hidden sibling can
			-- suppress a visible one); clear the finished entry instead of popping it.
			if not blackout and not self:IsSpellVisible(spellID, entry.category) then
				self.entries[spellID] = nil
			else
				edges[#edges + 1] = spellID
			end
		end
	end
	local massVanish = #edges > READY_MAX_POPS_PER_SCAN

	-- Shared-cooldown dedupe for ready pops: one ability tracked under two spellIDs (base +
	-- override, or two Cooldown Viewer categories) ends both edges in this scan, popping one icon
	-- each. Collapse siblings (same start, end within SHARED_CD_TOL) to the lowest spellID, gated
	-- on the opt-in flag. Runs before the box routing below (a per-box check can't see the
	-- cross-box pair); skipped under blackout/massVanish. Dropped siblings' entries are nil'd here.
	if not blackout and not massVanish and #edges > 1 then
		local addon = ns.CDM
		local g = addon and addon.db and addon.db.profile.global
		if g and g.detectSharedCD then
			table.sort(edges, ByReadyEdge)
			local w = 0
			for r = 1, #edges do
				local id = edges[r]
				local e  = self.entries[id]
				local dup = false
				if e then
					for k = w, 1, -1 do
						local kept = self.entries[edges[k]]
						if not kept or kept.startTime ~= e.startTime then break end
						if math.abs((e.endTime or 0) - (kept.endTime or 0)) <= SHARED_CD_TOL then
							dup = true
							break
						end
					end
				end
				if dup then
					self.entries[id] = nil
				else
					w = w + 1
					edges[w] = id
				end
			end
			for r = #edges, w + 1, -1 do edges[r] = nil end
		end
	end

	for _, spellID in ipairs(edges) do
		if not blackout then
			-- Gate on trackedSpells so a spec swap that de-tracks a mid-cooldown spell
			-- discards it silently rather than popping a false ready (or learning a
			-- partial span from a cooldown that ended only because we stopped tracking it).
			if not massVanish and self.trackedSpells and self.trackedSpells[spellID] then
				local e = self.entries[spellID]
				-- _fresh: only learn from a cooldown whose start we actually saw, so the
				-- wall-clock span is the real length (see ObserveDuration / _seenReady).
				if e and e._fresh and e._source == "isactive" and e.startTime then
					self:ObserveDuration(spellID, now - e.startTime)
				end
				if ns.ReadyFrames_OnReadyTransition then
					ns.ReadyFrames_OnReadyTransition(spellID, e)
				end
			end
			if self._traceUntil and self._traceState[spellID] and ns.CDM then
				ns.CDM:Print(string.format("[trace] %s ENTRY REMOVED (ready edge, popped=%s)",
					tostring(spellID), tostring(not massVanish)))
			end
			self.entries[spellID] = nil
		end
	end
end


-- Bag items poll by itemID via C_Container; equipped trinkets poll by inventory slot.
function Engine:PollOneItem(itemID, tracked)
	local startTime, duration
	if tracked and tracked.slot then
		if not GetInventoryItemCooldown then return false end
		startTime, duration = GetInventoryItemCooldown("player", tracked.slot)
	elseif C_Container and C_Container.GetItemCooldown then
		startTime, duration = C_Container.GetItemCooldown(itemID)
	else
		return false
	end

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

	self._itemOrder = self._itemOrder or {}
	local order = self._itemOrder
	wipe(order)
	for itemID in pairs(self.trackedItems) do
		order[#order + 1] = itemID
	end
	table.sort(order)

	-- Combat potions share one cooldown, so dedupe by startTime (lowest itemID wins):
	-- one use = one icon and one ready pop, not one per carried potion.
	self._cdSeen = self._cdSeen or {}
	local cdSeen = self._cdSeen
	wipe(cdSeen)

	for _, itemID in ipairs(order) do
		local tracked = self.trackedItems[itemID]
		local active, startTime, duration, endTime = self:PollOneItem(itemID, tracked)
		if tracked and active and not cdSeen[startTime] then
			cdSeen[startTime] = true
			seen[itemID] = true
			local existing = self.entries[itemID]
			if existing then
				existing.startTime = startTime
				existing.duration  = duration
				existing.endTime   = endTime
			else
				local cat = tracked.category or ns.CONST.POTION_CATEGORY
				self.entries[itemID] = {
					spellID    = itemID,
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

	local blackout = self._loadingScreen or GetTime() < (self._readyBlackoutUntil or 0)
	for itemID, entry in pairs(self.entries) do
		if entry.kind == "item" and not seen[itemID] and not blackout then
			-- untracked (used up / unequipped) = silent removal, not a ready edge
			if self.trackedItems[itemID] and ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(itemID, entry)
			end
			self.entries[itemID] = nil
		end
	end
end


local TEST_DURATIONS = { 6, 11, 18, 28, 42, 60 }

-- Sourced from the player's tracked set so the demo is flavor-correct and honors their routing.
function Engine:CollectTestPicks(maxN)
	local byCat = {}
	for spellID, tracked in pairs(self.trackedSpells) do
		if tracked.name and tracked.name ~= "?" then
			local c = tracked.category or 0
			byCat[c] = byCat[c] or {}
			byCat[c][#byCat[c] + 1] = spellID
		end
	end

	local picks = {}
	local order = { 0, 2, 1, 3 }   -- spells, buffs, utility, debuffs
	local cursor = {}
	local added = true
	while #picks < maxN and added do
		added = false
		for _, c in ipairs(order) do
			local list = byCat[c]
			local pos = (cursor[c] or 0) + 1
			if list and list[pos] then
				cursor[c] = pos
				picks[#picks + 1] = { spellID = list[pos], category = c }
				added = true
				if #picks >= maxN then break end
			end
		end
	end

	if #picks == 0 then
		for _, spellID in ipairs(self.testSpellIDs) do
			picks[#picks + 1] = { spellID = spellID, category = 0 }
		end
	end
	return picks
end


function Engine:StartTestMode()
	self.testActive = true
	wipe(self.entries)
	local now = GetTime()

	local picks = self:CollectTestPicks(#TEST_DURATIONS)
	for i, pick in ipairs(picks) do
		local spellID = pick.spellID
		local tracked = self.trackedSpells[spellID]
		local name, icon
		if tracked then name, icon = tracked.name, tracked.icon end
		if not name then name, icon = GetSpellNameIcon(spellID) end
		local dur = TEST_DURATIONS[i] or TEST_DURATIONS[#TEST_DURATIONS]
		self.entries[spellID] = {
			spellID   = spellID,
			name      = name,
			icon      = icon,
			startTime = now,
			duration  = dur,
			endTime   = now + dur,
			laneIndex = self:ResolveLaneIndex(spellID, pick.category),
			category  = pick.category,
			_source   = "test",
			_testDur  = dur,
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
	if ns.ReadyFrames_ClearAll then ns.ReadyFrames_ClearAll() end
	-- Repopulate immediately: the tick sweep runs at 1 Hz, so without this the
	-- lanes would sit empty for up to a second after leaving test mode.
	self:ScanSpells()
	self:PollAllItems()
end


function Engine:Tick()
	self._tickCount = self._tickCount + 1

	if self.testActive then
		-- Finish: pop to the ready frame like a real cooldown, then re-seed so the demo loops.
		local now = GetTime()
		for spellID, entry in pairs(self.entries) do
			if entry._source == "test" and entry.endTime and now >= entry.endTime then
				if ns.ReadyFrames_OnReadyTransition then
					ns.ReadyFrames_OnReadyTransition(spellID, entry)
				end
				local dur = entry._testDur or entry.duration or 30
				entry.startTime = now
				entry.duration  = dur
				entry.endTime   = now + dur
			end
		end
	else
		-- Safety-net sweep every 10th tick (1 Hz): covers cooldown edges the event paths miss
		-- (e.g. dropped across a loading screen). Scanning every tick allocated ~400 tables/sec
		-- at 40 tracked spells, for data that rarely changed between ticks. Item poll staggered
		-- to a different tick so no single frame carries both sweeps (read as a travel hitch).
		self._scanCounter = (self._scanCounter or 0) + 1
		if self._scanCounter == 5 then
			self:PollAllItems()
		elseif self._scanCounter >= 10 then
			self._scanCounter = 0
			self:ScanSpells()
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

	if not self.specEventFrame then
		local f = CreateFrame("Frame")
		-- Unit-filter to "player": the unfiltered event also fires for party
		-- members' spec changes, which would needlessly wipe learned durations.
		f:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_SPECIALIZATION_CHANGED" then
				wipe(self.knownDurations)
				wipe(self.cdTimingCache)
				-- In-memory only (not persisted): a new spec must re-observe a spell going
				-- ready before its span is trusted, so a shared spell mid-cooldown across the
				-- swap isn't learned short.
				wipe(self._seenReady)
				wipe(self._activeSince)
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

	-- Retail talent changes within a spec alter the tracked set and charge counts but fire no
	-- PLAYER_SPECIALIZATION_CHANGED; rebuild on trait commits (debounced -- login fires a burst).
	if ns.Compat.HAS_BLIZZ_CDM and not self.traitFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("TRAIT_CONFIG_UPDATED")
		f:SetScript("OnEvent", function()
			if self._traitRebuildPending then return end
			self._traitRebuildPending = true
			C_Timer.After(1, function()
				self._traitRebuildPending = false
				self:BuildTrackedSpells()
				if ns.Options_InvalidateFilterLists then
					ns.Options_InvalidateFilterLists()
				end
			end)
		end)
		self.traitFrame = f
	end

	-- Classic's tracked set comes from a spellbook scan, so rebuild it when the spellbook
	-- changes (learning spells, MoP talent swaps). SPELLS_CHANGED fires in bursts, so debounce.
	if not ns.Compat.HAS_BLIZZ_CDM and not self.spellsChangedFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("SPELLS_CHANGED")
		f:SetScript("OnEvent", function()
			if self._spellsRebuildPending then return end
			self._spellsRebuildPending = true
			C_Timer.After(1, function()
				self._spellsRebuildPending = false
				self:BuildTrackedSpells()
				if ns.Options_InvalidateFilterLists then
					ns.Options_InvalidateFilterLists()
				end
			end)
		end)
		self.spellsChangedFrame = f
	end

	-- Classic buffs change on UNIT_AURA (not SPELL_UPDATE_COOLDOWN); rescan the player's auras on change.
	if not ns.Compat.HAS_BLIZZ_CDM and not self.auraEventFrame then
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_AURA", "player")
		f:SetScript("OnEvent", function() self:ScanBuffs() end)
		self.auraEventFrame = f
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

	-- The scan is driven off isActive (authoritative), so it needn't match the cast spellID;
	-- OnTrackedCast uses it to re-anchor the cooldown start (best effort -- an override ID won't
	-- match). Debounced because the cast also fires SPELL_UPDATE_COOLDOWN a few frames later.
	if not self.castSucceededFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		f:SetScript("OnEvent", function(_, _, unit, _, spellID)
			if Engine.testActive then return end
			if unit ~= "player" then return end
			local p = Engine._probe
			p.seen, p.lastSeenAt, p.lastID = p.seen + 1, GetTime(), spellID
			local iss = _G.issecretvalue
			p.lastSecret = (iss and iss(spellID)) or false
			Engine:OnTrackedCast(spellID)
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

	-- Rediscover tracked items when the bags change (new/used potions) or a trinket is
	-- swapped (slots 13/14). BAG_UPDATE_DELAYED already collapses a batch of BAG_UPDATEs.
	if not self.itemRebuildFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("BAG_UPDATE_DELAYED")
		f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		f:SetScript("OnEvent", function(_, event, slot)
			if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= 13 and slot ~= 14 then return end
			ScheduleItemRebuild()
		end)
		self.itemRebuildFrame = f
	end

	-- PLAYER_ENTERING_WORLD also clears the flag in case LOADING_SCREEN_DISABLED is
	-- missed, which would otherwise leave it stuck on and suppress every popup.
	if not self.loadingScreenFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("LOADING_SCREEN_ENABLED")
		f:RegisterEvent("LOADING_SCREEN_DISABLED")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")
		f:SetScript("OnEvent", function(_, event)
			if event == "LOADING_SCREEN_ENABLED" then
				Engine._loadingScreen = true
			else
				Engine._loadingScreen = false
				Engine._readyBlackoutUntil = GetTime() + READY_BLACKOUT_GRACE
			end
		end)
		self.loadingScreenFrame = f
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
