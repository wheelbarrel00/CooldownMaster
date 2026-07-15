local ADDON_NAME, ns = ...

ns.Engine = {}
local Engine = ns.Engine

Engine.trackedSpells   = {}
Engine.trackedItems    = {}
-- Keyed by item, not by spell: two quality ranks of one potion cast the SAME use spell.
Engine.itemUseSpell    = {}   -- [itemID] = use spellID
Engine.itemSpells      = {}   -- [use spellID] = true
Engine.lastUsedSpell   = nil
Engine.trackedOffensives = {}
Engine.auraDurations   = {}
Engine.auraObserved    = {}
Engine._offPending     = {}
Engine._offPendingStart = {}  -- [spellID] = entry startTime at drop time, so a recast before the flush is not popped as ready
Engine.auraBind        = {}   -- [auraInstanceID] = spellID, current target only
Engine.auraPending     = {}   -- [auraInstanceID] = { cast, idx }, spell not yet known
Engine.auraOrigin      = {}   -- [auraInstanceID] = { cast, idx }
Engine.auraRec         = {}   -- [spellID] = { start, duration, inst }, current target only
Engine.castMap         = {}   -- persisted [castSpellID] = { debuffSpellID, ... } in the order they land
Engine.auraRoll        = {}   -- persisted [spellID] = seconds a refresh adds
Engine.cdIDToSpellID   = {}
Engine.knownDurations  = {}   -- learned out of combat / persisted; talent-adjusted, overrides baseline
Engine.observedDurations = {} -- learned in combat from a spell's full observed lifetime; below known, above baseline
Engine._seenReady      = {}   -- spellIDs seen off their own cooldown this session; gates trusting an observed span
Engine._activeSince    = {}   -- when each spell's cooldown began (first isActive, during GCD) = its real start
Engine.baselineDurations = {} -- hardcoded fallback or GetSpellBaseCooldown seed; used only when nothing learned
Engine._chargeOnCdSince = {}  -- when a multi-charge spell's on-cooldown state began; debounces the partial-use isActive blip
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

-- Same start+end alone is NOT a shared cooldown: two independent same-duration abilities fired
-- together (e.g. Arcane Power + Icy Veins) must not merge. Items match on itemID, spells on name.
function ns.IsSameSharedCD(a, b)
	-- Test entries are seeded together and recycle donor names, so they would merge into one icon.
	if a._source == "test" or b._source == "test" then return false end
	if a.itemID and b.itemID then return true end
	if a.itemID or b.itemID then return false end
	return a.name ~= nil and a.name == b.name
end


function ns.IsLastUsedItem(e)
	local spellID = Engine.lastUsedSpell
	if spellID == nil or e.itemID == nil then return false end
	return Engine.itemUseSpell[e.itemID] == spellID
end

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


-- A secret value used as a table key poisons the table, so nothing read off an aura record is trusted.
local function PlainOrNil(v)
	local iss = _G.issecretvalue
	if iss and iss(v) then return nil end
	return v
end


-- The first return means an aura EXISTS at this index, not that it read plain. Treating an unreadable buff as the end of the list stops the sweep early.
local function GetPlayerBuff(i)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local d = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not d then return false end
		return true, PlainOrNil(d.name), PlainOrNil(d.spellId), PlainOrNil(d.duration),
			PlainOrNil(d.icon), PlainOrNil(d.expirationTime)
	elseif UnitAura then
		local name, icon, _, _, duration, expiration, _, _, _, spellID = UnitAura("player", i, "HELPFUL")
		if not name then return false end
		return true, name, spellID, duration, icon, expiration
	end
end


-- HARMFUL|PLAYER is what makes an aura "ours" here (sourceUnit reads secret). Name and icon are resolved from the spellID instead - a secret name throws in the Filters tab's table.sort.
local function GetTargetDebuff(i)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local d = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
		if not d then return false end
		local issecret = _G.issecretvalue
		local spellID, instanceID = d.spellId, d.auraInstanceID
		local duration, expiration = d.duration, d.expirationTime
		if issecret then
			if issecret(spellID)    then spellID    = nil end
			if issecret(instanceID) then instanceID = nil end
			if issecret(duration)   then duration   = nil end
			if issecret(expiration) then expiration = nil end
		end
		return true, spellID, duration, expiration, instanceID
	elseif UnitAura then
		local name, _, _, _, duration, expiration, _, _, _, spellID = UnitAura("target", i, "HARMFUL|PLAYER")
		if not name then return false end
		return true, spellID, duration, expiration
	end
	return false
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


-- UNIT_AURA fires in bursts in combat and each ScanBuffs allocates a table per aura, so
-- debounce it the same way (hoisted body + one pending flag) instead of scanning per fire.
local function DeferredBuffPoll()
	Engine._buffScanPending = nil
	Engine:ScanBuffs()
end

local function ScheduleBuffScan()
	if Engine._buffScanPending then return end
	Engine._buffScanPending = true
	C_Timer.After(SCAN_DEBOUNCE, DeferredBuffPoll)
end


local function DeferredCustomAuraScan()
	Engine._customAuraScanPending = nil
	if not Engine.testActive then Engine:ScanCustomAuras() end
end

local function ScheduleCustomAuraScan()
	if Engine._customAuraScanPending then return end
	Engine._customAuraScanPending = true
	C_Timer.After(SCAN_DEBOUNCE, DeferredCustomAuraScan)
end


-- The debounce also lets a kill settle: the target reads dead by the time the scan runs, so the dots it stripped clear silently instead of popping one "ready" each.
local function DeferredOffensiveScan()
	Engine._offensiveScanPending = nil
	if not Engine.testActive then Engine:ScanOffensives() end
end

local function ScheduleOffensiveScan()
	if Engine._offensiveScanPending then return end
	Engine._offensiveScanPending = true
	C_Timer.After(SCAN_DEBOUNCE, DeferredOffensiveScan)
end


-- Bags/equipment change far more often than the tracked-item set actually does, so
-- collapse a burst (looting, swapping) into one rescan + filter-list refresh.
local function DeferredItemRebuild()
	Engine._itemRebuildPending = nil
	if Engine.testActive then return end
	Engine:BuildTrackedItems()
	Engine:PollAllItems()
	if ns.Options_InvalidateFilterLists then ns.Options_InvalidateFilterLists() end
end

local function ScheduleItemRebuild()
	if Engine._itemRebuildPending then return end
	Engine._itemRebuildPending = true
	C_Timer.After(0.5, DeferredItemRebuild)
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
	wipe(self.auraDurations)
	wipe(self.auraObserved)
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

	-- No MIN_TRUSTED_DURATION floor: that guards against a GCD-length cooldown mis-read, and short debuffs are real.
	addon.db.profile.auraDurations = addon.db.profile.auraDurations or {}
	for spellID, duration in pairs(addon.db.profile.auraDurations) do
		if type(spellID) == "number" and type(duration) == "number" and duration > 0 then
			self.auraDurations[spellID] = duration
		elseif type(spellID) == "number" then
			addon.db.profile.auraDurations[spellID] = nil
		end
	end

	addon.db.profile.auraObserved = addon.db.profile.auraObserved or {}
	for spellID, duration in pairs(addon.db.profile.auraObserved) do
		if type(spellID) == "number" and type(duration) == "number" and duration > 0
			and not self.auraDurations[spellID] then
			self.auraObserved[spellID] = duration
		elseif type(spellID) == "number" then
			addon.db.profile.auraObserved[spellID] = nil
		end
	end

	wipe(self.auraRoll)
	addon.db.profile.auraRoll = addon.db.profile.auraRoll or {}
	for spellID, roll in pairs(addon.db.profile.auraRoll) do
		if type(spellID) == "number" and type(roll) == "number" and roll >= 0 then
			self.auraRoll[spellID] = roll
		elseif type(spellID) == "number" then
			addon.db.profile.auraRoll[spellID] = nil
		end
	end

	wipe(self.castMap)
	addon.db.profile.castMap = addon.db.profile.castMap or {}
	for castID, map in pairs(addon.db.profile.castMap) do
		if type(castID) == "number" and type(map) == "table" then
			local clean, seen
			for idx, spellID in pairs(map) do
				if type(idx) == "number" and type(spellID) == "number" then
					seen = seen or {}
					if seen[spellID] then
						addon.db.profile.castMap[castID][idx] = nil
					else
						seen[spellID] = true
						clean = clean or {}
						clean[idx] = spellID
					end
				end
			end
			if clean then
				self.castMap[castID] = clean
			else
				addon.db.profile.castMap[castID] = nil
			end
		else
			addon.db.profile.castMap[castID] = nil
		end
	end

	-- The offensive catalog is discovered at runtime, so reseed it from the persisted lengths or Filters reads blank until each debuff lands again.
	for spellID in pairs(self.auraDurations) do self:TrackOffensive(spellID) end
	for spellID in pairs(self.auraObserved)  do self:TrackOffensive(spellID) end

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


-- Blizzard's own Cooldown Manager drops HideByDefault rows. They are modifier passives (Undisputed
-- Ruling) that carry their parent ability's art, so ingesting one shows a bar wearing Judgment's
-- icon, named for the passive, timing the passive's internal proc cooldown.
local HIDE_BY_DEFAULT = (Enum and Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault) or 2

local function IsHiddenRow(info)
	if type(info.flags) ~= "number" then return false end
	return bit.band(info.flags, HIDE_BY_DEFAULT) ~= 0
end

-- The viewer's overrideSpellID is not always the live replacement, so take it only when the game agrees.
local function ResolveEffectiveID(info)
	local overrideID = info.overrideSpellID
	if not overrideID or overrideID == 0 or overrideID == info.spellID then return info.spellID end
	if C_Spell and C_Spell.GetOverrideSpell then
		local ok, live = pcall(C_Spell.GetOverrideSpell, info.spellID)
		if ok and live ~= overrideID then return info.spellID end
	end
	return overrideID
end


-- Branch on the legacy TAB globals, as the player-book scan does. Retail still exposes a deprecated GetSpellBookItemName, so gating on that name alone sends retail down the legacy path with a "pet" bookType it no longer understands.
local function ReadPetBookItem(i)
	if type(_G.GetNumSpellTabs) == "function" and type(_G.GetSpellBookItemName) == "function" then
		local bookType = _G.BOOKTYPE_PET or "pet"
		local spellID = select(3, _G.GetSpellBookItemName(i, bookType))
		local passive = _G.IsPassiveSpell and _G.IsPassiveSpell(i, bookType)
		return PlainOrNil(spellID), passive
	end
	if C_SpellBook and C_SpellBook.GetSpellBookItemType
		and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet then
		local bank = Enum.SpellBookSpellBank.Pet
		local _, _, spellID = C_SpellBook.GetSpellBookItemType(i, bank)
		-- Third return only. The pet book's actionID is a pet-action id (Attack, Follow, the stances), not a
		-- spell id, and those slots report no spellID at all - which is exactly what filters them out here.
		local passive = C_SpellBook.IsSpellBookItemPassive
			and C_SpellBook.IsSpellBookItemPassive(i, bank)
		return PlainOrNil(spellID), passive
	end
	return nil
end


local function PetBaseCooldown(spellID)
	if type(GetSpellBaseCooldown) ~= "function" then return nil end
	local ok, cdMS, gcdMS = pcall(GetSpellBaseCooldown, spellID)
	if not ok then return nil end
	local issecret = _G.issecretvalue
	if issecret and (issecret(cdMS) or issecret(gcdMS)) then return nil end
	if type(cdMS) ~= "number" then return nil end
	return cdMS, (type(gcdMS) == "number" and gcdMS or 0)
end


-- HasPetSpells returns the COUNT of pet spells despite its name, not a boolean.
local function PetSpellCount()
	local hasPetSpells = (C_SpellBook and C_SpellBook.HasPetSpells) or _G.HasPetSpells
	if type(hasPetSpells) ~= "function" then return nil end
	local ok, n = pcall(hasPetSpells)
	if not ok or type(n) ~= "number" then return nil end
	return n
end


function Engine:DropPetSpells()
	for id, tracked in pairs(self.trackedSpells) do
		if tracked.category == ns.CONST.PET_CATEGORY then
			self.trackedSpells[id] = nil
			self.entries[id] = nil
		end
	end
end


-- A pet's filler attack (Bite, Claw, Smack) sits on a real 3s cooldown, so the player scan's
-- "cooldown longer than the GCD" gate would put a permanently cycling icon on the lane.
local MIN_PET_COOLDOWN_MS = 5000


-- The pet book is a flat 1..n index, not tab+offset like the player book, and IsPlayerSpell rejects every pet ability, so pet-book membership is the gate instead.
function Engine:AddTrackedPetSpells()
	local numPetSpells = PetSpellCount()
	if not numPetSpells or numPetSpells <= 0 then return end

	for i = 1, numPetSpells do
		local okItem, spellID, passive = pcall(ReadPetBookItem, i)
		if not okItem then spellID = nil end

		if spellID and not passive and not self.trackedSpells[spellID] then
			local cdMS, gcdMS = PetBaseCooldown(spellID)
			if cdMS and cdMS >= MIN_PET_COOLDOWN_MS and cdMS > gcdMS then
				local name, icon = GetSpellNameIcon(spellID)
				if name then
					self.trackedSpells[spellID] = {
						name     = name,
						icon     = icon,
						category = ns.CONST.PET_CATEGORY,
					}
				end
			end
		end
	end
end


-- A control spell's debuff shares its spellID with the spell (Frost Nova, Hammer of Justice) and the cooldown owns that key, so hand back whatever the aura scan claimed before the tracked set was built.
function Engine:DropOffensiveCollisions()
	for spellID in pairs(self.trackedOffensives) do
		if self.trackedSpells[spellID] then
			self.trackedOffensives[spellID] = nil
			local e = self.entries[spellID]
			if e and e._source == "offensive" then self.entries[spellID] = nil end
		end
	end
end


function Engine:BuildTrackedSpells()
	wipe(self.trackedSpells)
	wipe(self.cdIDToSpellID)

	if not ns.Compat.HAS_BLIZZ_CDM then
		self:BuildTrackedSpellsClassic()
		self:DropOffensiveCollisions()
		self._trackedBuilt = true
		self:ResyncEntryDisplay()
		return
	end

	if not (C_CooldownViewer
		and C_CooldownViewer.GetCooldownViewerCategorySet
		and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
		-- Still counts as built. Leaving the flag unset keeps the offensive scan dormant all session.
		self._trackedBuilt = true
		return
	end

	for category = 0, 3 do
		local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category)
		if ok and ids then
			for _, cooldownID in ipairs(ids) do
				local infoOk, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
				if infoOk and info and info.isKnown and not IsHiddenRow(info) then
					local effectiveID = ResolveEffectiveID(info)

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

	self:AddTrackedPetSpells()

	self:DropOffensiveCollisions()
	self._trackedBuilt = true

	self:SeedBaselineDurations()
	self:ResyncEntryDisplay()
end


-- An entry copies its name and icon at birth, so a spell still on cooldown across a talent or spec
-- swap would keep the pre-swap label until it expires. Untracked now means it was dropped, so it goes.
function Engine:ResyncEntryDisplay()
	for id, e in pairs(self.entries) do
		if e._source == "isactive" or e._source == "classic" then
			local tracked = self.trackedSpells[id]
			if tracked then
				e.name      = tracked.name
				e.icon      = tracked.icon
				e.category  = tracked.category or e.category
				e.laneIndex = self:ResolveLaneIndex(id, e.category)
				e.barIndex  = self:ResolveBarIndex(id, e.category)
			else
				self.entries[id] = nil
			end
		end
	end
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

	self:AddTrackedPetSpells()
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
					barIndex  = self:ResolveBarIndex(spellID, cat),
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

	-- A loading screen briefly reports cooldowns as inactive, which would pop the whole set ready at once.
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


-- Classic buffs (Seals, Blessings) have no cooldown, so track them as auras timed by remaining duration. Category 2 is the Buffs filter/lane.
function Engine:ScanBuffs()
	self._seenBuffs = self._seenBuffs or {}
	local seen = self._seenBuffs
	wipe(seen)
	local now = GetTime()
	local discovered = false

	for i = 1, 40 do
		local present, name, spellID, duration, icon, expiration = GetPlayerBuff(i)
		if not present then break end
		if spellID and duration and duration > 0 and expiration and expiration > now
			and IsPlayerSpell and IsPlayerSpell(spellID) then
			local tracked = self.trackedSpells[spellID]
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
							barIndex  = self:ResolveBarIndex(spellID, 2),
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


-- Classic only ([destGUID] = { [spellID] = { start, duration } }): a hostile unit's GUID is secret on retail, and a secret table key poisons the table.
local debuffs = {}
local playerGUID

-- A refresh rolls the unspent remainder into the new application, capped at 30% of base. No aura API reads this in combat, so it is modelled.
local PANDEMIC_FRACTION = 0.3


-- Silent by design: a dot gone because the target changed or died was not used up, so popping it "ready" would be a lie.
function Engine:ClearOffensiveEntries()
	for spellID, e in pairs(self.entries) do
		if e._source == "offensive" then self.entries[spellID] = nil end
	end
	wipe(self._offPending)
	wipe(self._offPendingStart)
end


-- Name and icon are re-resolved while still missing: spell data can be uncached on first sighting, and this table is never rebuilt.
function Engine:TrackOffensive(spellID)
	local tracked = self.trackedOffensives[spellID]
	if tracked and tracked.name and tracked.name ~= "?" then return tracked end

	local name, icon = GetSpellNameIcon(spellID)
	local isNew = not tracked
	if isNew then
		tracked = { category = ns.CONST.OFFENSIVE_CATEGORY }
		self.trackedOffensives[spellID] = tracked
	end
	tracked.name = name
	tracked.icon = icon
	if isNew and ns.Options_InvalidateFilterLists then
		ns.Options_InvalidateFilterLists()
	end
	return tracked
end


function Engine:SyncOffensiveEntry(spellID, rec)
	local cat = ns.CONST.OFFENSIVE_CATEGORY
	local e = self.entries[spellID]
	if e and e._source ~= "offensive" then return end   -- a cooldown owns this key outright

	if not (rec and rec.start and rec.duration and rec.duration > 0)
		or not self:IsSpellVisible(spellID, cat) then
		if e then self.entries[spellID] = nil end
		return
	end

	local tracked = self:TrackOffensive(spellID)
	if not e then
		e = {}
		self.entries[spellID] = e
	end
	e.spellID   = spellID
	e.name      = tracked.name
	e.icon      = tracked.icon
	e.startTime = rec.start
	e.duration  = rec.duration
	e.endTime   = rec.start + rec.duration
	e.laneIndex = self:ResolveLaneIndex(spellID, cat)
	e.barIndex  = self:ResolveBarIndex(spellID, cat)
	e.category  = cat
	e._source   = "offensive"
end


function Engine:RebuildOffensiveEntries()
	if not ns.Compat.HAS_COMBAT_LOG then
		return self:ReseedTargetAuras()
	end

	self:ClearOffensiveEntries()
	if not self._trackedBuilt or self.testActive then return end
	if not self:IsCategoryEnabled(ns.CONST.OFFENSIVE_CATEGORY) then return end
	if not UnitExists("target") or UnitIsDead("target") then return end

	local byGUID = debuffs[UnitGUID("target")]
	if not byGUID then return end
	for spellID, rec in pairs(byGUID) do
		self:SyncOffensiveEntry(spellID, rec)
	end
end


-- Records the dropped dot's start so FlushOffensivePops can tell a real expiry from a recast that
-- landed in the same window. One live instance per spellID, so a spellID is pending at most once.
function Engine:QueueOffensivePop(spellID)
	local pending = self._offPending
	pending[#pending + 1] = spellID
	local e = self.entries[spellID]
	self._offPendingStart[spellID] = (e and e.startTime) or false
end


-- Batched on purpose: dots have staggered lengths, so several dropping at once is the target being stripped (an evade, an immunity, a dispel), not each one expiring.
function Engine:FlushOffensivePops()
	local pending = self._offPending
	local n = #pending
	if n == 0 then return end

	local starts = self._offPendingStart
	local massVanish = n > READY_MAX_POPS_PER_SCAN
	local blackout = self._loadingScreen or GetTime() < (self._readyBlackoutUntil or 0)
	for i = 1, n do
		local spellID = pending[i]
		local e = self.entries[spellID]
		-- A recast between the drop and this flush re-anchors the entry to a fresh start, so the dot is live, not ready. Neither pop it nor delete it.
		if e and e._source == "offensive" and e.startTime == starts[spellID] then
			if not massVanish and not blackout and ns.ReadyFrames_OnReadyTransition then
				ns.ReadyFrames_OnReadyTransition(spellID, e)
			end
			self.entries[spellID] = nil
		end
	end
	wipe(pending)
	wipe(starts)
end


-- Retail 12.0 forbids addons the combat log and secrets a target aura's spellId in combat, so a debuff is identified by the cast that applied it - UNIT_SPELLCAST_SUCCEEDED stays plain. Aura reads are a bonus layer that 12.1 turns into Lua errors, so every one is guarded.

local CAST_BIND_WINDOW = 2.0   -- a debuff lands within a couple of frames of the cast that applied it


function Engine:ClearTargetAuras()
	wipe(self.auraBind)
	wipe(self.auraPending)
	wipe(self.auraOrigin)
	wipe(self.auraRec)
	self:ClearOffensiveEntries()
end


function Engine:LearnCastDebuff(castID, idx, spellID)
	if not (castID and idx and spellID) then return end
	local map = self.castMap[castID]
	if not map then
		map = {}
		self.castMap[castID] = map
	end
	if map[idx] == spellID then return end
	map[idx] = spellID

	-- A cast cannot apply the same debuff twice, so surrender the stale slot: two slots resolving to one spellID collide on the same entry key and the other debuff can never render.
	for i, id in pairs(map) do
		if i ~= idx and id == spellID then map[i] = nil end
	end

	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.castMap = addon.db.profile.castMap or {}
		local saved = addon.db.profile.castMap[castID]
		if not saved then
			saved = {}
			addon.db.profile.castMap[castID] = saved
		end
		saved[idx] = spellID
		for i, id in pairs(saved) do
			if i ~= idx and id == spellID then saved[i] = nil end
		end
	end
end


function Engine:BindAura(inst, spellID, aura, now)
	-- HARMFUL|PLAYER does not actually mean "cast by me" (sourceUnit is secret), so without this another player's dots on a shared target get adopted. Both booleans stay plain in 12.0 and 12.1.
	if aura and (aura.isHarmful == false or aura.isFromPlayerOrPlayerPet == false) then return end

	-- A control spell's debuff carries the spell's own id (Hammer of Justice 853, Frost Nova 122), and offensives are exempt from the cooldown prune, so the hijacked icon would stick on the lane.
	if self.trackedSpells[spellID] then return end
	if not self:IsSpellVisible(spellID, ns.CONST.OFFENSIVE_CATEGORY) then return end

	self.auraBind[inst] = spellID
	self.auraPending[inst] = nil
	self:TrackOffensive(spellID)

	local duration   = aura and PlainOrNil(aura.duration)
	local expiration = aura and PlainOrNil(aura.expirationTime)
	if duration and duration > 0 then self:StoreAuraDuration(spellID, duration) end

	local rec = self.auraRec[spellID]
	if not rec then
		rec = {}
		self.auraRec[spellID] = rec
	end
	rec.inst = inst

	-- Clamp the start at now: a pandemic roll-over in the future drives remaining/duration above 1 and pins the icon at the lane start.
	if duration and duration > 0 and expiration then
		local startTime = expiration - duration
		if startTime > now then startTime = now end
		rec.start    = startTime
		rec.duration = expiration - startTime
	else
		rec.start    = now
		rec.duration = self:BestAuraDuration(spellID)
	end

	self:SyncOffensiveEntry(spellID, rec)
end


function Engine:StoreAuraRoll(spellID, roll)
	if type(roll) ~= "number" or roll < 0 then return end
	self.auraRoll[spellID] = roll
	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.auraRoll = addon.db.profile.auraRoll or {}
		addon.db.profile.auraRoll[spellID] = roll
	end
end


function Engine:LearnAuraRoll(spellID, rec, now)
	local base = self:BestAuraDuration(spellID)
	if not (base and rec and rec.start) then return end

	local roll = (now - rec.start) - base
	-- Past the pandemic cap this is a refresh we never saw (a proc, an off-GCD source) sitting on a stale start, and learning from it teaches an ever-growing length.
	if roll > base * PANDEMIC_FRACTION + 0.5 then return end
	-- The start is the cast and the debuff lands a moment later, so under a second is latency, not a rollover.
	if roll < 1 then roll = 0 end

	local cur = self.auraRoll[spellID]
	if cur and roll <= cur + 0.25 then return end
	self:StoreAuraRoll(spellID, roll)
end


function Engine:DropAuraInstance(inst, pop)
	self.auraPending[inst] = nil
	self.auraOrigin[inst] = nil
	local spellID = self.auraBind[inst]
	if not spellID then return end
	self.auraBind[inst] = nil

	local rec = self.auraRec[spellID]
	if rec and rec.inst == inst then
		-- Only a dot that ran to its own end teaches a length. A dispelled or killed-off one was cut short.
		if pop then self:LearnAuraRoll(spellID, rec, GetTime()) end
		self.auraRec[spellID] = nil
	end

	if pop then
		self:QueueOffensivePop(spellID)
	else
		local e = self.entries[spellID]
		if e and e._source == "offensive" then self.entries[spellID] = nil end
	end
end


-- In combat a new debuff's spellId is secret, so identity comes from the cast that just went out plus the order the debuffs arrive in, against a mapping learned where the values read plain.
function Engine:BindAddedAuras(added, now)
	local batch = self._auraBatch or {}
	self._auraBatch = batch
	wipe(batch)

	for i = 1, #added do
		local a = added[i]
		if a.isHarmful and a.isFromPlayerOrPlayerPet then
			batch[#batch + 1] = a
		end
	end
	if #batch == 0 then return end

	local castID = self._castID
	if castID and (now - (self._castAt or 0)) > CAST_BIND_WINDOW then castID = nil end
	local map = castID and self.castMap[castID] or nil

	for i = 1, #batch do
		local a = batch[i]
		local inst = PlainOrNil(a.auraInstanceID)
		if not inst then return end   -- 12.1: no plain handle, so the cast-driven core carries it alone

		-- The slot counter is per CAST, not per batch: a cast's debuffs can be split across several UNIT_AURA events.
		local idx
		if castID then
			self._castSeq = (self._castSeq or 0) + 1
			idx = self._castSeq
		end

		local spellID = PlainOrNil(a.spellId)
		if spellID then
			if idx then self:LearnCastDebuff(castID, idx, spellID) end
			self:BindAura(inst, spellID, a, now)
			if idx then self.auraOrigin[inst] = { cast = castID, idx = idx } end
		elseif idx then
			local known = map and map[idx]
			self.auraOrigin[inst] = { cast = castID, idx = idx }
			-- Never hand one spell to two live instances: they collide on the same entry key and the other debuff can never render.
			if known and not self.auraRec[known] then
				self:BindAura(inst, known, a, now)
			else
				self.auraPending[inst] = { cast = castID, idx = idx }
			end
		end
	end
end


-- Out of combat is the only window where an instance bound blind can say which spell it was, so the cast mapping is learned (and persisted) here.
function Engine:ResolvePendingAuras()
	if not next(self.auraPending) then return end
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
	if not UnitExists("target") then return end

	local now = GetTime()
	for inst, p in pairs(self.auraPending) do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "target", inst)
		if ok and type(a) == "table" then
			local spellID = PlainOrNil(a.spellId)
			if spellID then
				self:LearnCastDebuff(p.cast, p.idx, spellID)
				self:BindAura(inst, spellID, a, now)
			end
		end
	end
end


-- The live instance list stays plain in combat on 12.0, so a missed removal edge cannot strand an icon. On 12.1 it returns a secret vector, which proves nothing and is dropped.
function Engine:ReconcileTargetAuras()
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return end
	if not next(self.auraBind) and not next(self.auraPending) then return end

	local ok, list = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, "target", "HARMFUL|PLAYER")
	if not ok or PlainOrNil(list) == nil or type(list) ~= "table" then return end

	local live = self._auraLive or {}
	self._auraLive = live
	wipe(live)
	for i = 1, #list do
		local inst = PlainOrNil(list[i])
		if inst then live[inst] = true end
	end

	for inst in pairs(self.auraBind) do
		if not live[inst] then self:DropAuraInstance(inst, false) end
	end
	for inst in pairs(self.auraPending) do
		if not live[inst] then self.auraPending[inst] = nil end
	end
end


function Engine:HandleTargetAuras(updateInfo)
	if self.testActive or not self._trackedBuilt then return end
	if not self:IsCategoryEnabled(ns.CONST.OFFENSIVE_CATEGORY) then
		if next(self.auraBind) then self:ClearTargetAuras() end
		return
	end
	if not UnitExists("target") or UnitIsDead("target") then
		self:ClearTargetAuras()
		return
	end

	-- No updateInfo, or a full refresh, means the incremental stream cannot be trusted. Same unit though, so the cast origins stay valid.
	if not updateInfo or updateInfo.isFullUpdate then
		self:ReseedTargetAuras(true)
		return
	end

	local now = GetTime()
	local added = updateInfo.addedAuras
	if added then self:BindAddedAuras(added, now) end

	local removed = updateInfo.removedAuraInstanceIDs
	if removed then
		local killed = UnitIsDead("target")
		for i = 1, #removed do
			local inst = PlainOrNil(removed[i])
			if inst then self:DropAuraInstance(inst, not killed) end
		end
	end

	-- updatedAuraInstanceIDs is deliberately ignored: it fires on every stack tick, so re-anchoring on it resets a stacking dot to full every couple of seconds.
end


-- A refresh reuses the aura's instance, so no added edge ever fires for it. Our own recast is the only re-anchor signal, and a stack tick cannot fake it.
function Engine:OnCastForAuras(spellID, now)
	self._castID, self._castAt = spellID, now
	self._castSeq = 0

	local map = self.castMap[spellID]
	if not map then return end
	-- pairs, not 1..#map: the slot-surrender in LearnCastDebuff and the load-time dedupe can leave a hole at index 1, and #{[2]=x} is 0 in Lua 5.1, which would skip every slot.
	for _, id in pairs(map) do
		local rec = self.auraRec[id]
		local base = self:BestAuraDuration(id)
		if rec and rec.start and base then
			local remaining = (rec.start + (rec.duration or 0)) - now
			if remaining < 0 then remaining = 0 end
			local roll = self.auraRoll[id] or 0
			if roll > remaining then roll = remaining end
			rec.start    = now
			rec.duration = base + roll
			self:SyncOffensiveEntry(id, rec)
		end
	end
end


-- sameTarget means a full refresh on the unit we already watch, not a swap: after a swap the cast origins describe the previous target's instances and could teach castMap the wrong slot, which persists.
function Engine:ReseedTargetAuras(sameTarget)
	local origin = self._originKeep or {}
	self._originKeep = origin
	wipe(origin)
	if sameTarget then
		for inst, o in pairs(self.auraOrigin)  do origin[inst] = o end
		for inst, p in pairs(self.auraPending) do origin[inst] = origin[inst] or p end
	end

	self:ClearTargetAuras()
	if self.testActive or not self._trackedBuilt then return end
	if not self:IsCategoryEnabled(ns.CONST.OFFENSIVE_CATEGORY) then return end
	if not UnitExists("target") or UnitIsDead("target") then return end
	if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
		and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end

	local ok, list = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, "target", "HARMFUL|PLAYER")
	if not ok or PlainOrNil(list) == nil or type(list) ~= "table" then return end

	-- In combat a re-targeted mob's dots cannot be identified (spellId is secret and no cast of ours explains them), so they stay anonymous and render nothing until combat drops.
	local now = GetTime()
	for i = 1, #list do
		local inst = PlainOrNil(list[i])
		if inst then
			local ok2, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "target", inst)
			if ok2 and type(a) == "table" then
				local spellID = PlainOrNil(a.spellId)
				if spellID then
					local o = origin[inst]
					if o then self:LearnCastDebuff(o.cast, o.idx, spellID) end
					self:BindAura(inst, spellID, a, now)
					if o then self.auraOrigin[inst] = o end
				end
			end
		end
	end
end


-- A binding made in combat is a guess from the cast plus the slot order, so re-check it against the aura once that reads plain again or a cast whose debuffs landed out of order stays mislabelled for good.
function Engine:VerifyBindings()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
	if not next(self.auraBind) then return end
	if not UnitExists("target") then return end

	local now = GetTime()
	for inst, bound in pairs(self.auraBind) do
		local ok, a = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "target", inst)
		if ok and type(a) == "table" then
			local truth = PlainOrNil(a.spellId)
			if truth and truth ~= bound then
				local o = self.auraOrigin[inst]
				if o then self:LearnCastDebuff(o.cast, o.idx, truth) end

				local e = self.entries[bound]
				if e and e._source == "offensive" then self.entries[bound] = nil end
				self.auraRec[bound] = nil

				self:BindAura(inst, truth, a, now)
			end
		end
	end
end


function Engine:ScanOffensivesRetail()
	if not UnitExists("target") or UnitIsDead("target") then
		if next(self.auraBind) or next(self.auraPending) then self:ClearTargetAuras() end
		return
	end
	self:ResolvePendingAuras()
	self:VerifyBindings()
	self:ReconcileTargetAuras()
end


-- The Classic path below runs off the combat log, which retail 12.0 forbids to addons. It names the aura edges exactly, and a stack tick is its own subevent rather than masquerading as a refresh.

-- A secret value throws on tostring, so a diagnostic that formats one takes the addon down with it.
local function SafeStr(v)
	local issecret = _G.issecretvalue
	if issecret and issecret(v) then return "|cffff5555<secret>|r" end
	return tostring(v)
end


function Engine:HandleAuraLog()
	local _, sub, _, srcGUID, _, _, _, dstGUID, _, _, _, spellID, _, _, auraType = CombatLogGetCurrentEventInfo()

	-- Checked ahead of the filters below because these subevents carry no source and no aura type.
	if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" or sub == "UNIT_DISSIPATES" then
		if dstGUID then
			debuffs[dstGUID] = nil
			-- The removal events that would normally clear the icons can arrive AFTER this one, when their record is already gone.
			if dstGUID == UnitGUID("target") then self:ClearOffensiveEntries() end
		end
		return
	end

	if not playerGUID then playerGUID = UnitGUID("player") end

	if auraType ~= "DEBUFF" then return end
	if srcGUID ~= playerGUID then return end
	if not (spellID and dstGUID) then return end
	if not self._trackedBuilt then return end
	if self.trackedSpells[spellID] then return end
	if not self:IsCategoryEnabled(ns.CONST.OFFENSIVE_CATEGORY) then return end

	local now = GetTime()
	local isTarget = (dstGUID == UnitGUID("target"))
	local byGUID = debuffs[dstGUID]
	local rec = byGUID and byGUID[spellID]

	if sub == "SPELL_AURA_APPLIED" then
		self:TrackOffensive(spellID)
		if not byGUID then
			byGUID = {}
			debuffs[dstGUID] = byGUID
		end
		if not rec then
			rec = {}
			byGUID[spellID] = rec
		end
		rec.start     = now
		rec.duration  = self:BestAuraDuration(spellID)
		rec.refreshed = false
		if isTarget then self:SyncOffensiveEntry(spellID, rec) end

	elseif sub == "SPELL_AURA_REFRESH" then
		-- No record means the dot was up before we started watching, and a maintained dot never fires APPLIED again. Flagged refreshed so it can never teach a length from a start we did not witness.
		if not rec then
			self:TrackOffensive(spellID)
			if not byGUID then
				byGUID = {}
				debuffs[dstGUID] = byGUID
			end
			rec = { start = now, duration = self:BestAuraDuration(spellID), refreshed = true }
			byGUID[spellID] = rec
			if isTarget then self:SyncOffensiveEntry(spellID, rec) end
			return
		end

		-- Only from a CLEAN application: a refreshed record's life is base plus a rollover, which teaches a length longer than the truth.
		if rec.start and not rec.refreshed then
			self:ObserveAuraDuration(spellID, now - rec.start)
		end

		local base = self:BestAuraDuration(spellID)
		if base then
			local remaining = (rec.start and rec.duration) and (rec.start + rec.duration - now) or 0
			if remaining < 0 then remaining = 0 end
			local roll = base * PANDEMIC_FRACTION
			if remaining < roll then roll = remaining end
			rec.duration = base + roll
		end
		rec.start     = now
		rec.refreshed = true
		if isTarget then self:SyncOffensiveEntry(spellID, rec) end

	elseif sub == "SPELL_AURA_APPLIED_DOSE" then
		-- A stack tick is not a refresh, so the start must NOT be re-anchored here. The dot now outlives what this record can account for, so it is disqualified from teaching a length.
		if rec then rec.refreshed = true end

	elseif sub == "SPELL_AURA_REMOVED" then
		-- Deliberately not gated on rec: UNIT_DIED can land first and take the record with it, stranding the icon on the lane with nothing left to remove it.
		if byGUID then
			byGUID[spellID] = nil
			if next(byGUID) == nil then debuffs[dstGUID] = nil end
		end

		-- The kill and this removal can arrive in either order, so re-check: a dot cut short by the kill teaches a span shorter than the truth and pops a "recast me" nobody asked for.
		local killed = isTarget and UnitIsDead("target")
		if rec and rec.start and not rec.refreshed and not killed then
			self:ObserveAuraDuration(spellID, now - rec.start)
		end

		if isTarget then
			if killed then
				local e = self.entries[spellID]
				if e and e._source == "offensive" then self.entries[spellID] = nil end
			else
				self:QueueOffensivePop(spellID)
			end
		end
	end
end


-- Bounds the table on leaving combat: a mob that despawned or leashed never sent a removal. The current target is kept, since a dot can outlive the fight.
function Engine:ResetAuraLog()
	local keep = UnitGUID and UnitGUID("target")
	for guid in pairs(debuffs) do
		if guid ~= keep then debuffs[guid] = nil end
	end
end


function Engine:ScanOffensives()
	if self.testActive or not self._trackedBuilt then return end

	if not self:IsCategoryEnabled(ns.CONST.OFFENSIVE_CATEGORY) then
		self:ClearOffensiveEntries()
		if not ns.Compat.HAS_COMBAT_LOG then self:ClearTargetAuras() end
		return
	end

	if not ns.Compat.HAS_COMBAT_LOG then
		return self:ScanOffensivesRetail()
	end

	if not UnitExists("target") or UnitIsDead("target") then
		self:ClearOffensiveEntries()
		return
	end

	local guid = UnitGUID("target")
	local now  = GetTime()

	self._seenOff = self._seenOff or {}
	local seen = self._seenOff
	wipe(seen)
	local unreadable = false

	for i = 1, 40 do
		local present, spellID, duration, expiration = GetTargetDebuff(i)
		if not present then break end

		-- A secret aura is skipped, not treated as absent: the combat log's record already stands, and there is nothing here to correct it with.
		if not spellID then
			unreadable = true
		elseif duration and duration > 0 and expiration
			and not self.trackedSpells[spellID] then

			seen[spellID] = true
			self:StoreAuraDuration(spellID, duration)

			local byGUID = debuffs[guid]
			if not byGUID then
				byGUID = {}
				debuffs[guid] = byGUID
			end
			local rec = byGUID[spellID]
			if not rec then
				rec = {}
				byGUID[spellID] = rec
			end

			local startTime = expiration - duration
			if startTime > now then startTime = now end
			rec.start    = startTime
			rec.duration = expiration - startTime

			self:SyncOffensiveEntry(spellID, rec)
		end
	end

	-- Backstop for a removal edge the combat log missed, which would strand an icon on the lane forever. Silent, and a pass holding a secret aura proves nothing and must not prune.
	if not unreadable then
		local byGUID = debuffs[guid]
		for spellID, e in pairs(self.entries) do
			if e._source == "offensive" and not seen[spellID] then
				self.entries[spellID] = nil
				if byGUID then byGUID[spellID] = nil end
			end
		end
	end
end


function Engine:ProbeAuraUpdate(unit, updateInfo)
	if GetTime() > self._auraProbeUntil then
		self._auraProbeUntil = nil
		return
	end
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	local lastCast = self._probe and self._probe.lastID
	local castAge  = (self._probe and self._probe.lastSeenAt) and (GetTime() - self._probe.lastSeenAt) or 999

	if not updateInfo then
		cdm:Print(string.format("UNIT_AURA %s | no updateInfo (full refresh)", tostring(unit)))
		return
	end

	cdm:Print(string.format("|cffffff00UNIT_AURA|r %s | full=%s inCombat=%s | lastCast=%s (%.1fs ago)",
		tostring(unit), tostring(updateInfo.isFullUpdate), tostring(InCombatLockdown()),
		SafeStr(lastCast), castAge))

	local added = updateInfo.addedAuras
	if added then
		for i = 1, #added do
			local a = added[i]
			cdm:Print(string.format("  |cff00ff00ADDED|r inst=%s - every field:", SafeStr(a.auraInstanceID)))
			local keys = self._probeKeys or {}
			self._probeKeys = keys
			wipe(keys)
			for k in pairs(a) do keys[#keys + 1] = k end
			table.sort(keys)
			for k = 1, #keys do
				cdm:Print(string.format("      %s = %s", keys[k], SafeStr(a[keys[k]])))
			end
		end
	end

	local upd = updateInfo.updatedAuraInstanceIDs
	if upd then
		for i = 1, #upd do
			cdm:Print("  UPDATED inst=" .. SafeStr(upd[i]))
		end
	end

	local rem = updateInfo.removedAuraInstanceIDs
	if rem then
		for i = 1, #rem do
			cdm:Print("  REMOVED inst=" .. SafeStr(rem[i]))
		end
	end
end


local function Try(label, fn, ...)
	local cdm = ns.CDM
	if type(fn) ~= "function" then
		cdm:Print("   " .. label .. " -> |cff888888absent|r")
		return
	end
	local ok, a = pcall(fn, ...)
	if not ok then
		cdm:Print("   " .. label .. " -> |cffff5555THREW|r " .. SafeStr(a))
		return
	end
	local iss = _G.issecretvalue
	if iss and iss(a) then
		cdm:Print("   " .. label .. " -> |cffff5555<secret>|r")
		return
	end
	if a == nil then
		cdm:Print("   " .. label .. " -> nil")
		return
	end
	if type(a) == "table" then
		cdm:Print(string.format("   %s -> |cff00ff00table|r inst=%s spellId=%s name=%s dur=%s exp=%s",
			label, SafeStr(a.auraInstanceID), SafeStr(a.spellId), SafeStr(a.name),
			SafeStr(a.duration), SafeStr(a.expirationTime)))
		return a
	end
	cdm:Print(string.format("   %s -> |cff00ff00%s|r (%s)", label, SafeStr(a), type(a)))
	return a
end


function Engine:RunAuraApiProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end
	if not C_UnitAuras then cdm:Print("No C_UnitAuras on this flavor.") return end
	if not UnitExists("target") then cdm:Print("Need a target with your debuffs on it.") return end

	local A = C_UnitAuras
	cdm:Print(string.format("===== Aura API probe ===== inCombat=%s", tostring(InCombatLockdown())))

	local ids = {}
	for spellID in pairs(self.trackedOffensives) do ids[#ids + 1] = spellID end
	if #ids == 0 then ids = { 197277, 408383 } end
	table.sort(ids)

	cdm:Print("|cffffff00-- ASK BY SPELL (the identity question) --|r")
	for i = 1, #ids do
		local id = ids[i]
		local name = GetSpellNameIcon(id)
		cdm:Print(string.format("|cffffff00[%d] %s|r", id, tostring(name)))
		Try("GetUnitAuraBySpellID(target,id)",              A.GetUnitAuraBySpellID, "target", id)
		Try("GetUnitAuraBySpellID(target,id,HARMFUL)",      A.GetUnitAuraBySpellID, "target", id, "HARMFUL")
		Try("GetUnitAuraBySpellID(target,id,HARMFUL|PLAYER)", A.GetUnitAuraBySpellID, "target", id, "HARMFUL|PLAYER")
		if name then
			Try("GetAuraDataBySpellName(target,name,HARMFUL|PLAYER)", A.GetAuraDataBySpellName, "target", name, "HARMFUL|PLAYER")
		end
		Try("GetCooldownAuraBySpellID(id)",                 A.GetCooldownAuraBySpellID, id)
	end

	cdm:Print("|cffffff00-- ASK BY INSTANCE (what each live aura will tell us) --|r")
	local ok, list = pcall(A.GetUnitAuraInstanceIDs, "target", "HARMFUL|PLAYER")
	if not (ok and type(list) == "table") then
		cdm:Print("GetUnitAuraInstanceIDs -> " .. SafeStr(list))
		return
	end
	local parts = {}
	for i = 1, #list do parts[#parts + 1] = SafeStr(list[i]) end
	cdm:Print("GetUnitAuraInstanceIDs(target, HARMFUL|PLAYER) -> " .. table.concat(parts, ", "))

	for i = 1, #list do
		local inst = list[i]
		cdm:Print(string.format("|cffffff00inst %s|r", SafeStr(inst)))
		Try("IsAuraFilteredOutByInstanceID(HARMFUL|PLAYER)", A.IsAuraFilteredOutByInstanceID, "target", inst, "HARMFUL|PLAYER")
		local dObj = Try("GetAuraDuration(target,inst)", A.GetAuraDuration, "target", inst)
		-- GetAuraBaseDuration rejects both the instance ID and the AuraData table, so its "auraInstance" is some third handle we have not found.
		if dObj then
			Try("GetAuraBaseDuration(durationObject)",        A.GetAuraBaseDuration, dObj)
			Try("GetAuraBaseDuration(durationObject,spellID)", A.GetAuraBaseDuration, dObj, ids[1])
			Try("GetRefreshExtendedDuration(durationObject)", A.GetRefreshExtendedDuration, dObj)
		end
	end

	cdm:Print("|cffffff00-- GetUnitAuras: the one call never tried, and the likeliest source of an 'auraInstance' --|r")
	local ok2, auras = pcall(A.GetUnitAuras, "target", "HARMFUL|PLAYER")
	if not ok2 then
		cdm:Print("   GetUnitAuras THREW " .. SafeStr(auras))
	elseif PlainOrNil(auras) == nil then
		cdm:Print("   GetUnitAuras -> |cffff5555<secret>|r")
	elseif type(auras) ~= "table" then
		cdm:Print("   GetUnitAuras -> " .. SafeStr(auras) .. " (" .. type(auras) .. ")")
	else
		cdm:Print(string.format("   GetUnitAuras -> table of %d", #auras))
		for i = 1, #auras do
			local u = auras[i]
			cdm:Print(string.format("   [%d] type=%s value=%s", i, type(u), SafeStr(u)))
			Try("  GetAuraBaseDuration(it)",        A.GetAuraBaseDuration, u)
			Try("  GetAuraBaseDuration(it,spellID)", A.GetAuraBaseDuration, u, ids[1])
			Try("  GetRefreshExtendedDuration(it)", A.GetRefreshExtendedDuration, u)
			Try("  DoesAuraHaveExpirationTime(it)", A.DoesAuraHaveExpirationTime, u)
		end
	end
end


function Engine:RunItemDump()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	cdm:Print("===== Tracked items =====")
	local n = 0
	for itemID, t in pairs(self.trackedItems) do
		n = n + 1
		local useSpell
		if C_Item and C_Item.GetItemSpell then
			local _, sid = C_Item.GetItemSpell(itemID)
			useSpell = sid
		end
		cdm:Print(string.format("  [%d] %s | cat=%s useSpell=%s",
			itemID, tostring(t.name), tostring(t.category), tostring(useSpell)))
	end
	if n == 0 then cdm:Print("  no tracked items") end

	local m = 0
	for itemID, spellID in pairs(self.itemUseSpell) do
		m = m + 1
		cdm:Print(string.format("  useSpell map: item %s -> spell %s", tostring(itemID), tostring(spellID)))
	end
	if m == 0 then cdm:Print("  |cffff5555useSpell map is EMPTY|r - no item's use spell was ever resolved") end

	cdm:Print("lastUsedSpell = " .. tostring(self.lastUsedSpell)
		.. "  (nil means no item cast has matched the map yet)")

	cdm:Print("--- live item entries (what the merge actually chooses between) ---")
	local live, now = 0, GetTime()
	for id, e in pairs(self.entries) do
		if e.itemID then
			live = live + 1
			cdm:Print(string.format("  ENTRY [%s] %s | itemID=%s start=%.2f remaining=%.1fs lastUsed=%s",
				tostring(id), tostring(e.name), tostring(e.itemID), e.startTime or 0,
				(e.endTime or now) - now, tostring(ns.IsLastUsedItem(e))))
		end
	end
	if live == 0 then cdm:Print("  |cffff5555no live item entries|r") end
	if live == 1 then cdm:Print("  only ONE item entry - so nothing is being merged, and the potion you") end
	if live == 1 then cdm:Print("  drank never produced an entry of its own.") end
end


function Engine:RunBuffProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end
	cdm:Print(string.format("===== Player buffs ===== inCombat=%s", tostring(InCombatLockdown())))

	local i, shown = 1, 0
	while i <= 40 do
		local present, name, spellID, duration, icon, expiration = GetPlayerBuff(i)
		if not present then break end
		shown = shown + 1
		cdm:Print(string.format("  [%d] spellId=%s name=%s dur=%s exp=%s icon=%s",
			i, SafeStr(spellID), SafeStr(name), SafeStr(duration), SafeStr(expiration), SafeStr(icon)))
		i = i + 1
	end
	if shown == 0 then cdm:Print("  no buffs on the player") end
	cdm:Print("A nil spellId in combat is a SECRET one - enumerating buffs cannot identify them.")

	cdm:Print("|cffffff00-- ASK BY SPELL: can a trigger confirm its own buff? --|r")
	local A = C_UnitAuras
	if not A then cdm:Print("  no C_UnitAuras") return end

	local ids = {}
	local store = ns.CDM and ns.CDM.db and ns.CDM.db.profile.customCooldowns
	if store and store.defs then
		for _, def in pairs(store.defs) do
			if def.triggerType == "aura" and def.triggerID then ids[#ids + 1] = def.triggerID end
		end
	end
	if #ids == 0 then
		cdm:Print("  no aura-triggered customs configured - add one, or its trigger id cannot be tested")
		return
	end

	for i = 1, #ids do
		local id = ids[i]
		local nm = GetSpellNameIcon(id)
		cdm:Print(string.format("|cffffff00[%d] %s|r", id, tostring(nm)))
		Try("GetPlayerAuraBySpellID(id)",           A.GetPlayerAuraBySpellID, id)
		Try("GetUnitAuraBySpellID(player,id)",      A.GetUnitAuraBySpellID, "player", id)
		Try("GetUnitAuraBySpellID(player,id,HELPFUL)", A.GetUnitAuraBySpellID, "player", id, "HELPFUL")
	end
end


function Engine:ResetOffensiveLearning()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	self:ClearTargetAuras()
	wipe(self.trackedOffensives)
	wipe(self.auraDurations)
	wipe(self.auraObserved)
	wipe(self.auraRoll)
	wipe(self.castMap)

	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.auraDurations = {}
		addon.db.profile.auraObserved  = {}
		addon.db.profile.auraRoll      = {}
		addon.db.profile.castMap       = {}
	end

	if ns.Options_InvalidateFilterLists then ns.Options_InvalidateFilterLists() end
	cdm:Print("Offensives: catalog, learned lengths and cast mappings all cleared. They relearn as you cast.")
end


function Engine:ArmAuraInstanceProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	if C_UnitAuras then
		local names = {}
		for k, v in pairs(C_UnitAuras) do
			if type(v) == "function" then names[#names + 1] = k end
		end
		table.sort(names)
		cdm:Print("C_UnitAuras exposes: " .. table.concat(names, ", "))
	end

	self._auraProbeUntil = GetTime() + 25
	cdm:Print("|cff00ff00Aura-instance probe armed for 25s.|r Get IN COMBAT, then cast a DoT on your target,")
	cdm:Print("and let it fall off naturally. Watching UNIT_AURA on the target.")
	cdm:Print("Looking for: any PLAIN field on an ADDED aura that identifies WHICH SPELL it is.")
end


function Engine:RunOffensiveDump()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end
	local cat = ns.CONST.OFFENSIVE_CATEGORY

	cdm:Print("===== Offensives state =====")
	cdm:Print(string.format("trackedBuilt=%s  categoryEnabled=%s  inCombat=%s",
		tostring(self._trackedBuilt),
		tostring(self:IsCategoryEnabled(cat)),
		tostring(InCombatLockdown())))

	local n = 0
	for spellID, t in pairs(self.trackedOffensives) do
		n = n + 1
		cdm:Print(string.format("  catalog [%d] %s | lane=%s bar=%s visible=%s length=%s",
			spellID, tostring(t.name),
			tostring(self:ResolveLaneIndex(spellID, cat)),
			tostring(self:ResolveBarIndex(spellID, cat)),
			tostring(self:IsSpellVisible(spellID, cat)),
			tostring(self:BestAuraDuration(spellID))))
	end
	if n == 0 then cdm:Print("  catalog is EMPTY") end

	if not ns.Compat.HAS_COMBAT_LOG then
		cdm:Print("Source: |cff00ff00cast-driven|r (the combat log is forbidden on this flavor)")
		local n2 = 0
		for inst, spellID in pairs(self.auraBind) do
			n2 = n2 + 1
			local rec = self.auraRec[spellID]
			cdm:Print(string.format("  bound inst=%s -> [%d] %s | start=%.1fs-ago dur=%s",
				tostring(inst), spellID, tostring((self.trackedOffensives[spellID] or {}).name),
				GetTime() - ((rec and rec.start) or GetTime()), tostring(rec and rec.duration)))
		end
		if n2 == 0 then cdm:Print("  no bound aura instances on this target") end

		local n3 = 0
		for inst, p in pairs(self.auraPending) do
			n3 = n3 + 1
			cdm:Print(string.format("  |cffffff00unresolved|r inst=%s from cast %s (slot %s) - needs an out-of-combat look",
				tostring(inst), tostring(p.cast), tostring(p.idx)))
		end
		if n3 > 0 then cdm:Print("  (unresolved instances render nothing until their spell is known)") end

		local n4 = 0
		for castID, map in pairs(self.castMap) do
			n4 = n4 + 1
			local parts = {}
			for idx, id in pairs(map) do parts[#parts + 1] = string.format("%s=%s", tostring(idx), tostring(id)) end
			cdm:Print(string.format("  castMap [%s] -> %s", tostring(castID), table.concat(parts, ", ")))
		end
		if n4 == 0 then cdm:Print("  castMap is EMPTY (no cast has been matched to its debuffs yet)") end
	end

	local guid = (ns.Compat.HAS_COMBAT_LOG and UnitGUID) and UnitGUID("target") or nil
	if not guid then
		if ns.Compat.HAS_COMBAT_LOG then cdm:Print("No target, so no debuff record to show.") end
	else
		local byGUID = debuffs[guid]
		if not byGUID or next(byGUID) == nil then
			cdm:Print("Combat-log record for this target: |cffff5555none|r")
		else
			local now = GetTime()
			for spellID, rec in pairs(byGUID) do
				cdm:Print(string.format("  record [%d] start=%.1fs-ago dur=%s refreshed=%s",
					spellID, now - (rec.start or now), tostring(rec.duration), tostring(rec.refreshed)))
			end
		end
	end

	local live, now = 0, GetTime()
	for spellID, e in pairs(self.entries) do
		if e._source == "offensive" then
			live = live + 1
			cdm:Print(string.format("  ENTRY [%d] %s | lane=%s remaining=%.1fs of %.1fs",
				spellID, tostring(e.name), tostring(e.laneIndex),
				(e.endTime or now) - now, e.duration or 0))
		end
	end
	if live == 0 then cdm:Print("  no live offensive entries") end
end


function Engine:BuildTrackedItems()
	wipe(self.trackedItems)
	wipe(self.itemUseSpell)
	wipe(self.itemSpells)

	if not (C_Container and C_Container.GetItemCooldown) then
		return
	end

	-- Every potion shares one category cooldown, so the merged icon has to pick one item. The use spell says which one was drunk, and its cast id stays plain in combat.
	local function mapItemSpell(itemID)
		if not (C_Item and C_Item.GetItemSpell) then return end
		local _, spellID = C_Item.GetItemSpell(itemID)
		if not spellID then return end
		Engine.itemUseSpell[itemID] = spellID
		Engine.itemSpells[spellID] = true
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
		mapItemSpell(itemID)
		-- ItemMixin fills real name/icon/link once the item data loads (or now if cached).
		if Item and Item.CreateFromItemID then
			local item = Item:CreateFromItemID(itemID)
			-- An id Blizzard has retired never loads, so it would sit in Filters forever as a nameless "Item 258318" that can never fire.
			if item:IsItemEmpty() then
				self.trackedItems[itemID] = nil
				return
			end
			do
				item:ContinueOnItemLoad(function()
					local tracked = Engine.trackedItems[itemID]
					if not tracked then return end
					tracked.name = item:GetItemName() or tracked.name
					tracked.icon = item:GetItemIcon() or tracked.icon
					tracked.link = item:GetItemLink()
					-- The use spell is unreadable until the item data loads, so map it again here.
					mapItemSpell(itemID)
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


function Engine:IsCategoryEnabled(category)
	local addon = ns.CDM
	if not (addon and addon.db) then return true end
	local key = self:GetCategoryFilterKey(category)
	local fcfg = key and addon.db.profile.filters and addon.db.profile.filters[key]
	if not fcfg then return true end
	return fcfg.enabled ~= false
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
		-- An offensive is timed by aura length, which lives in its own store, so the cooldown store reads nil for one and the threshold would silently do nothing.
		local dur = (category == ns.CONST.OFFENSIVE_CATEGORY)
			and self:BestAuraDuration(spellID)
			or self:BestDuration(spellID)
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


function Engine:ResolveBarIndex(spellID, category)
	local addon = ns.CDM
	if addon and addon.db then
		local profile = addon.db.profile

		local override = profile.spellOverrides and profile.spellOverrides[spellID]
		if override and override.bar ~= nil then
			return override.bar
		end

		local key = self:GetCategoryFilterKey(category)
		local fcfg = key and profile.filters and profile.filters[key]
		if fcfg and fcfg.defaultBar ~= nil then
			return fcfg.defaultBar
		end
	end
	return 0
end


-- Routing is resolved once at entry creation, so a settings change would otherwise not reach live entries.
function Engine:ReapplyRouting()
	for id, e in pairs(self.entries) do
		e.laneIndex = self:ResolveLaneIndex(id, e.category)
		e.barIndex  = self:ResolveBarIndex(id, e.category)
	end
end


-- Hoisted to module scope so LearnDuration's pcall reuses it rather than
-- allocate a closure per call (runs every scan for each unlearned active spell).
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
	end
end


-- Aura lengths live in their own store: a control spell's debuff shares the ability's spellID (Frost Nova 122), so one keyspace would overwrite the cooldown with the much shorter debuff length, and persist it.
function Engine:StoreAuraDuration(spellID, total)
	if type(total) ~= "number" or total <= 0 then return end
	local cur = self.auraDurations[spellID]
	if cur and math.abs(cur - total) < 0.05 then return end
	self.auraDurations[spellID] = total
	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.auraDurations = addon.db.profile.auraDurations or {}
		addon.db.profile.auraDurations[spellID] = total
	end
end


-- Beyond this a debuff is a permanent or out-of-combat one, not a dot worth travelling a lane.
local MAX_AURA_DURATION = 600

-- Fallback for a length that never reads plain, timed off the combat log. Converges up only: a dot cut short by an evade or a dispel must never pin the length low for good.
function Engine:ObserveAuraDuration(spellID, observed)
	if type(observed) ~= "number" or observed <= 1 or observed > MAX_AURA_DURATION then return end
	if self.auraDurations[spellID] then return end
	local cur = self.auraObserved[spellID]
	if cur and observed <= cur + 0.5 then return end
	self.auraObserved[spellID] = observed
	local addon = ns.CDM
	if addon and addon.db then
		addon.db.profile.auraObserved = addon.db.profile.auraObserved or {}
		addon.db.profile.auraObserved[spellID] = observed
	end
end


function Engine:BestAuraDuration(spellID)
	return self.auraDurations[spellID] or self.auraObserved[spellID]
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
			e.dObj      = nil
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
		-- The handle describes the cooldown that just ENDED, and the privileged setter accepts an
		-- expired one and renders nothing (no swipe, no number) rather than failing over to numbers.
		-- Drop it so the re-feed uses plain numbers until the next scan hands back a live handle.
		e.dObj      = nil
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


-- These sources have their own removal sweep, so the cooldown scan must not prune them: they are absent from its seen set every pass, which reads as "went ready".
local FOREIGN_SOURCE = { test = true, custom = true, offensive = true }


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
					barIndex  = self:ResolveBarIndex(spellID, cat),
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
				-- A re-anchor drops the handle, so re-attaching one has to force the render frames to
				-- re-feed. They key on startTime, which the re-anchor already consumed.
				if dObj and not existing.dObj then
					existing._feedGen = (existing._feedGen or 0) + 1
				end
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
		if not FOREIGN_SOURCE[entry._source] and entry.kind ~= "item" and not seen[spellID] then
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
						if math.abs((e.endTime or 0) - (kept.endTime or 0)) <= SHARED_CD_TOL
							and ns.IsSameSharedCD(e, kept) then
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


-- PollAllItems hands a shared cooldown to the FIRST item it meets, so this order decides which potion shows. Module-scope so the 1 Hz poll allocates no comparator closure.
local function ByLastUsedThenID(a, b)
	-- An item that already holds an entry keeps it, or drinking a flask mid-potion-cooldown would displace the potion on screen - swapping the icon mid-countdown and popping a false "ready".
	local ea = Engine.entries[a] ~= nil
	local eb = Engine.entries[b] ~= nil
	if ea ~= eb then return ea end

	local used = Engine.lastUsedSpell
	if used then
		local au = Engine.itemUseSpell[a] == used
		local bu = Engine.itemUseSpell[b] == used
		if au ~= bu then return au end
	end
	return a < b
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
	table.sort(order, ByLastUsedThenID)

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
					barIndex   = self:ResolveBarIndex(itemID, cat),
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


local MIXED_ORDER = { 0, 2, 1, 3 }   -- spells, buffs, utility, debuffs
local UNKNOWN_ICON = 134400

-- Pooled across seeds: testDonorCount is the live length, not #testDonors (stale entries linger past it).
local testDonors, testDonorCount = {}, 0

local function AddDonor(name, icon, category)
	testDonorCount = testDonorCount + 1
	local d = testDonors[testDonorCount]
	if not d then d = {}; testDonors[testDonorCount] = d end
	d.name, d.icon, d.category = name, icon, category
end

function Engine:CollectTestDonors(category)
	testDonorCount = 0

	if category == ns.CONST.POTION_CATEGORY or category == ns.CONST.TRINKET_CATEGORY then
		for _, tracked in pairs(self.trackedItems) do
			if tracked.category == category and tracked.name and tracked.name ~= "?" then
				AddDonor(tracked.name, tracked.icon, category)
			end
		end

	elseif category then
		for _, tracked in pairs(self.trackedSpells) do
			if tracked.category == category and tracked.name and tracked.name ~= "?" then
				AddDonor(tracked.name, tracked.icon, category)
			end
		end

	else
		local byCat = {}
		for _, tracked in pairs(self.trackedSpells) do
			if tracked.name and tracked.name ~= "?" then
				local c = tracked.category or 0
				byCat[c] = byCat[c] or {}
				byCat[c][#byCat[c] + 1] = tracked
			end
		end
		local cursor, added = {}, true
		while added do
			added = false
			for _, c in ipairs(MIXED_ORDER) do
				local list = byCat[c]
				local pos = (cursor[c] or 0) + 1
				if list and list[pos] then
					cursor[c] = pos
					AddDonor(list[pos].name, list[pos].icon, c)
					added = true
				end
			end
		end
	end

	if testDonorCount == 0 then
		for _, spellID in ipairs(self.testSpellIDs) do
			local name, icon = GetSpellNameIcon(spellID)
			if name then AddDonor(name, icon, category or 0) end
		end
	end
	return testDonorCount
end


function Engine:StartTestMode()
	local g = ns.CDM.db.profile.global
	local count = math.floor(math.max(1, math.min(20, g.testCount or 6)))
	local first = math.max(1, math.min(600, g.testFirst or 5))
	local last  = math.max(1, math.min(600, g.testLast or 120))

	local typeDef = ns.CONST.TEST_TYPES[1]
	for _, def in ipairs(ns.CONST.TEST_TYPES) do
		if def.value == g.testType then typeDef = def; break end
	end

	if ns.ReadyFrames_ClearAll then ns.ReadyFrames_ClearAll() end
	self.testActive = true
	-- Never wipe() the whole table here: customs have no live source to re-read, so they would be lost for good.
	for id, entry in pairs(self.entries) do
		if entry._source ~= "custom" then self.entries[id] = nil end
	end

	local n    = self:CollectTestDonors(typeDef.category)
	local now  = GetTime()
	local span = (count > 1) and ((last - first) / (count - 1)) or 0
	local visible = 0

	for i = 1, count do
		local id    = ns.CONST.TEST_ID_BASE + i
		local dur   = first + span * (i - 1)
		local donor = (n > 0) and testDonors[((i - 1) % n) + 1] or nil
		local cat   = typeDef.category or (donor and donor.category) or MIXED_ORDER[((i - 1) % 4) + 1]

		-- No dObj and no itemID keeps test entries off the secret-value path, so the demo renders the same on every flavor.
		self.entries[id] = {
			spellID   = id,
			name      = (donor and donor.name) or ("Test " .. typeDef.text .. " " .. i),
			icon      = (donor and donor.icon) or UNKNOWN_ICON,
			startTime = now,
			duration  = dur,
			endTime   = now + dur,
			laneIndex = self:ResolveLaneIndex(id, cat),
			barIndex  = self:ResolveBarIndex(id, cat),
			category  = cat,
			_source   = "test",
			_testDur  = dur,
		}
		if self:IsSpellVisible(id, cat) then visible = visible + 1 end
	end

	-- Only on the edge: a slider drag re-seeds repeatedly and would otherwise spam the warning.
	if visible == 0 and not self._testHiddenWarned then
		ns.CDM:Print("Test mode: this category is hidden in Filters, so nothing will show.")
	end
	self._testHiddenWarned = visible == 0
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
	self:RebuildOffensiveEntries()
	self:ScanOffensives()
end


-- Fabricated from the user's duration, so no dObj: the render path stays clear of the secret-value pipeline.
function Engine:FireCustomCooldown(def, now)
	if not (def and def.id) then return end
	local dur = (def.durationMs or 0) / 1000
	if dur <= 0 then return end
	now = now or GetTime()
	local cat = ns.CONST.CUSTOM_CATEGORY
	local e = self.entries[def.id]
	if not e then
		e = {}
		self.entries[def.id] = e
	end
	e.spellID   = def.id
	e.name      = def.name
	e.icon      = def.icon
	e.startTime = now
	e.duration  = dur
	e.endTime   = now + dur
	e.category  = cat
	e.laneIndex = self:ResolveLaneIndex(def.id, cat)
	e.barIndex  = self:ResolveBarIndex(def.id, cat)
	e._source   = "custom"
end


-- Holds def refs, not ids, so a live duration edit is honored at fire time.
local customSpellTriggers = {}
local customAuraTriggers  = {}

function Engine:RebuildCustomTriggers()
	wipe(customSpellTriggers)
	wipe(customAuraTriggers)
	local addon = ns.CDM
	local store = addon and addon.db and addon.db.profile.customCooldowns
	if not (store and store.defs) then return end
	for _, def in pairs(store.defs) do
		if def.enabled ~= false and def.triggerID and def.durationMs then
			local tbl = (def.triggerType == "aura") and customAuraTriggers or customSpellTriggers
			local list = tbl[def.triggerID]
			if not list then list = {}; tbl[def.triggerID] = list end
			list[#list + 1] = def
		end
	end
end


function Engine:HasCustomAuraTriggers()
	return next(customAuraTriggers) ~= nil
end


-- The ScanSpells prune skips customs, so a profile switch has to clear the live ones by hand.
-- Clearing the aura prev set makes the next scan re-seed instead of false-firing on buffs already up.
function Engine:ClearCustomEntries()
	for id, entry in pairs(self.entries) do
		if entry._source == "custom" then self.entries[id] = nil end
	end
	self._customAuraPrev = nil
end


function Engine:FireCustomSpellTrigger(spellID)
	local defs = customSpellTriggers[spellID]
	if not defs then return end
	local now = GetTime()
	for i = 1, #defs do
		self:FireCustomCooldown(defs[i], now)
	end
end


-- A nil prev set means the first scan only seeds, so a buff already up at login is not a false gained-edge.
function Engine:ScanCustomAuras()
	if not next(customAuraTriggers) then return end
	-- Loading screens briefly report no auras. Skip WITHOUT touching prev, so a buff that survived
	-- the zone is not seen as a fresh gained-edge when it reappears.
	if self._loadingScreen or GetTime() < (self._readyBlackoutUntil or 0) then return end
	local prev = self._customAuraPrev
	local seen = self._customAuraSeen or {}
	self._customAuraSeen = seen
	for k in pairs(seen) do seen[k] = nil end
	local now = GetTime()
	local i = 1
	local unreadable = false
	while true do
		local present, _, spellID = GetPlayerBuff(i)
		if not present then break end
		-- In combat the player's own buffs read secret, so a present-but-unreadable buff must not clear prev as though it fell off.
		if spellID then
			local defs = customAuraTriggers[spellID]
			if defs then
				seen[spellID] = true
				if prev and not prev[spellID] then
					for k = 1, #defs do self:FireCustomCooldown(defs[k], now) end
				end
			end
		else
			unreadable = true
		end
		i = i + 1
	end

	prev = prev or {}
	self._customAuraPrev = prev
	-- A pass with an unreadable buff in it proves nothing about what fell off, so only a fully readable pass may say a buff is gone.
	if not unreadable then
		for k in pairs(prev) do prev[k] = nil end
	end
	for k in pairs(seen) do prev[k] = true end
end


-- On retail a buff is secret in combat, so one first gained mid-fight is invisible to ScanCustomAuras and never enters prev. Leaving combat makes it readable again, and without this the next scan reads it as a fresh gain and fires the custom late. Fold whatever is up into prev WITHOUT firing.
function Engine:ReseedCustomAuras()
	if not next(customAuraTriggers) then return end
	local prev = self._customAuraPrev or {}
	self._customAuraPrev = prev
	local i = 1
	while true do
		local present, _, spellID = GetPlayerBuff(i)
		if not present then break end
		if spellID and customAuraTriggers[spellID] then prev[spellID] = true end
		i = i + 1
	end
end


function Engine:ArmAuraCapture(onCapture)
	local snap = self._auraCaptureSnap or {}
	self._auraCaptureSnap = snap
	for k in pairs(snap) do snap[k] = nil end
	local i = 1
	while true do
		local present, _, spellID = GetPlayerBuff(i)
		if not present then break end
		if spellID then snap[spellID] = true end
		i = i + 1
	end
	self._auraCaptureCb = onCapture
	self._auraCaptureArmed = true
end

function Engine:CancelAuraCapture()
	self._auraCaptureArmed = false
	self._auraCaptureCb = nil
end

function Engine:PollAuraCapture()
	if not self._auraCaptureArmed then return end
	local snap = self._auraCaptureSnap
	local i = 1
	while true do
		local present, name, spellID, _, icon = GetPlayerBuff(i)
		if not present then break end
		if spellID and not (snap and snap[spellID]) then
			local cb = self._auraCaptureCb
			self:CancelAuraCapture()
			if cb then cb(spellID, name, icon) end
			return
		end
		i = i + 1
	end
end


function Engine:Tick()
	self._tickCount = self._tickCount + 1

	-- Customs have no cooldown-API edge, so Tick owns their ready pop. It sits outside the testActive
	-- branch below because customs survive the demo and would otherwise pop stale the moment it ends.
	local cnow = GetTime()
	local cblackout = self._loadingScreen or cnow < (self._readyBlackoutUntil or 0)
	if not cblackout then
		for id, entry in pairs(self.entries) do
			if entry._source == "custom" and entry.endTime and cnow >= entry.endTime then
				if ns.ReadyFrames_OnReadyTransition then
					ns.ReadyFrames_OnReadyTransition(id, entry)
				end
				self.entries[id] = nil
			end
		end
	end

	if self.testActive then
		local now = GetTime()
		local loop = ns.CDM.db.profile.global.testLoop ~= false
		local remaining = 0
		for spellID, entry in pairs(self.entries) do
			if entry._source == "test" then
				if entry.endTime and now >= entry.endTime then
					if ns.ReadyFrames_OnReadyTransition then
						ns.ReadyFrames_OnReadyTransition(spellID, entry)
					end
					if loop then
						local dur = entry._testDur or entry.duration or 30
						entry.startTime = now
						entry.duration  = dur
						entry.endTime   = now + dur
						remaining = remaining + 1
					else
						self.entries[spellID] = nil
					end
				else
					remaining = remaining + 1
				end
			end
		end
		-- With looping off the demo drains, and leaving testActive set would suspend every real
		-- data path (they all early-out on it). Toggle outside the loop - StopTestMode rescans.
		if remaining == 0 then
			ns.CDM:ToggleTestMode()
		end
	else
		self:FlushOffensivePops()

		-- Safety-net sweep every 10th tick (1 Hz): covers cooldown edges the event paths miss
		-- (e.g. dropped across a loading screen). Scanning every tick allocated ~400 tables/sec
		-- at 40 tracked spells, for data that rarely changed between ticks. Item poll staggered
		-- to a different tick so no single frame carries both sweeps (read as a travel hitch).
		self._scanCounter = (self._scanCounter or 0) + 1
		if self._scanCounter == 5 then
			self:PollAllItems()
		elseif self._scanCounter == 8 then
			self:ScanOffensives()
		elseif self._scanCounter >= 10 then
			self._scanCounter = 0
			self:ScanSpells()
		end
	end

	if ns.Lanes_Refresh then
		for i = 1, 3 do ns.Lanes_Refresh(i) end
	end
	if ns.Bars_Refresh then
		for i = 1, 3 do ns.Bars_Refresh(i) end
	end
end


function Engine:Start(addon)
	self.addon = addon
	self.cooldownViewerFound = (C_CooldownViewer ~= nil
		and type(C_CooldownViewer.IsCooldownViewerAvailable) == "function")

	-- Must run before any polling so the extrapolator has data to use.
	self:LoadPersistedDurations()
	self:RebuildCustomTriggers()

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

	-- Specs (and this event) exist on retail + MoP only; skip on spec-less Era/TBC.
	if ns.Compat.GetNumSpecs() and not self.specEventFrame then
		local f = CreateFrame("Frame")
		-- Unit-filter to "player": the unfiltered event also fires for party
		-- members' spec changes, which would needlessly wipe learned durations.
		f:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_SPECIALIZATION_CHANGED" then
				wipe(self.knownDurations)
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

	-- Pet abilities enter and leave the tracked set with the pet, which no spell or trait event covers. Both events fire in bursts on summon, so debounce.
	if not self.petFrame then
		local function SchedulePetRebuild()
			if self._petRebuildPending then return end
			self._petRebuildPending = true
			C_Timer.After(1, function()
				self._petRebuildPending = false
				self:BuildTrackedSpells()
				if ns.Options_InvalidateFilterLists then
					ns.Options_InvalidateFilterLists()
				end
			end)
		end

		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_PET", "player")
		f:RegisterEvent("PET_BAR_UPDATE")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" then
				if not self._petRebuildDeferred then return end
				self._petRebuildDeferred = nil
				SchedulePetRebuild()
				return
			end

			local guid = UnitGUID and UnitGUID("pet") or nil
			local count = PetSpellCount()
			-- PET_BAR_UPDATE also fires for autocast and stance toggles, which change no spell.
			if guid == self._petGUID and count == self._petSpellCount then return end

			-- Drop them now: a scan inside the rebuild's debounce window reads the old pet's abilities as not-active while still tracked, which the ready-edge sweep pops as "ready".
			if guid ~= self._petGUID then self:DropPetSpells() end
			self._petGUID, self._petSpellCount = guid, count

			-- Discovery needs a readable base cooldown, which is secret in combat.
			if InCombatLockdown() then
				self._petRebuildDeferred = true
				return
			end
			SchedulePetRebuild()
		end)
		self.petFrame = f
	end

	-- Classic buffs change on UNIT_AURA (not SPELL_UPDATE_COOLDOWN); rescan the player's auras on change.
	if not ns.Compat.HAS_BLIZZ_CDM and not self.auraEventFrame then
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_AURA", "player")
		f:SetScript("OnEvent", ScheduleBuffScan)
		self.auraEventFrame = f
	end

	if not self.offensiveFrame then
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_AURA", "target")
		f:RegisterEvent("PLAYER_TARGET_CHANGED")
		f:SetScript("OnEvent", function(_, event, unit, updateInfo)
			if Engine._auraProbeUntil then Engine:ProbeAuraUpdate(unit, updateInfo) end
			if Engine.testActive then return end

			-- Retail reads the aura stream itself: the instance handles stay plain in combat, and they are the only edge signal left now that the combat log is forbidden.
			if not ns.Compat.HAS_COMBAT_LOG then
				if event == "PLAYER_TARGET_CHANGED" then
					Engine:ReseedTargetAuras()
				else
					Engine:HandleTargetAuras(updateInfo)
				end
				return
			end

			if event == "PLAYER_TARGET_CHANGED" then
				-- Not debounced: the combat log already knows what the new target is carrying, so the lane is correct on the same frame as the swap.
				Engine:RebuildOffensiveEntries()
				Engine:ScanOffensives()
				return
			end
			ScheduleOffensiveScan()
		end)
		self.offensiveFrame = f
	end

	-- Its own frame: the addon object's COMBAT_LOG_EVENT_UNFILTERED slot belongs to the swing tracker (UI/Lanes.lua), which registers and unregisters it on demand, so sharing would have the two silently cancel each other.
	if not self.auraLogFrame then
		local f = CreateFrame("Frame")
		if ns.Compat.HAS_COMBAT_LOG then
			f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" then
				if not ns.Compat.HAS_COMBAT_LOG then
					Engine:ResolvePendingAuras()
					Engine:VerifyBindings()
					return
				end
				Engine:ResetAuraLog()
				return
			end
			Engine:HandleAuraLog()
		end)
		self.auraLogFrame = f
	end

	-- The aura frame above is Classic-only, so custom aura triggers need their own always-on listener.
	if not self.customAuraFrame then
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_AURA", "player")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" then
				if not Engine.testActive then Engine:ReseedCustomAuras() end
				return
			end
			if Engine._auraCaptureArmed then Engine:PollAuraCapture() end
			if Engine.testActive then return end
			if not Engine:HasCustomAuraTriggers() then return end
			ScheduleCustomAuraScan()
		end)
		self.customAuraFrame = f
	end

	-- Debounced so a burst of cooldown changes collapses into a single scan.
	if not self.spellUpdateFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		-- Pet cooldowns have their own event and do not raise SPELL_UPDATE_COOLDOWN.
		f:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
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
			-- Pet abilities are tracked spells too, but their casts arrive on the "pet" unit.
			local isPlayer = unit == "player"
			if not isPlayer and unit ~= "pet" then return end
			local p = Engine._probe
			p.seen, p.lastSeenAt, p.lastID = p.seen + 1, GetTime(), spellID
			local iss = _G.issecretvalue
			p.lastSecret = (iss and iss(spellID)) or false
			Engine:OnTrackedCast(spellID)
			-- Never index a table with a secret spellID (Midnight) - it would not match a plain-number key anyway.
			if isPlayer and not p.lastSecret then Engine:FireCustomSpellTrigger(spellID) end
			if isPlayer and not p.lastSecret and Engine.itemSpells[spellID] then
				Engine.lastUsedSpell = spellID
			end
			if isPlayer and not p.lastSecret and not ns.Compat.HAS_COMBAT_LOG then
				Engine:OnCastForAuras(spellID, GetTime())
			end
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


-- Unlike PetBaseCooldown, which collapses every failure into nil, this keeps a missing API and a secret value apart.
local function PetBaseCooldownDetail(spellID)
	if type(GetSpellBaseCooldown) ~= "function" then return "|cffff5555no-method|r" end
	local ok, cdMS, gcdMS = pcall(GetSpellBaseCooldown, spellID)
	if not ok then return "|cffff5555ERR|r: " .. SafeStr(cdMS) end
	if cdMS == nil then return "nil" end
	local iss = _G.issecretvalue
	if iss and (iss(cdMS) or iss(gcdMS)) then return "|cffff5555SECRET|r" end
	if type(cdMS) ~= "number" then return type(cdMS) end
	return string.format("%.0fms (gcd %s)", cdMS,
		type(gcdMS) == "number" and string.format("%.0fms", gcdMS) or "-")
end


local function PetBookRaw(i, useLegacy)
	if useLegacy then
		local ok, a, b, c = pcall(_G.GetSpellBookItemName, i, _G.BOOKTYPE_PET or "pet")
		if not ok then return "|cffff5555ERR|r: " .. SafeStr(a) end
		return string.format("r1=%s r2=%s r3=%s", SafeStr(a), SafeStr(b), SafeStr(c))
	end
	if not (C_SpellBook and C_SpellBook.GetSpellBookItemType) then return "no-method" end
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
	local ok, a, b, c = pcall(C_SpellBook.GetSpellBookItemType, i, bank)
	if not ok then return "|cffff5555ERR|r: " .. SafeStr(a) end
	return string.format("itemType=%s actionID=%s spellID=%s", SafeStr(a), SafeStr(b), SafeStr(c))
end


function Engine:RunPetProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	local issecret = _G.issecretvalue
	local yes, no = "|cff00ff00yes|r", "|cffff5555NO|r"
	cdm:Print("===== Pet probe =====")
	cdm:Print("In combat: " .. (InCombatLockdown() and "|cff00ff00YES|r" or "no"))
	cdm:Print("legend: SECRET=taint-blocked  <number>=usable plain value  ERR=call failed")

	local petOut = UnitExists and UnitExists("pet")
	cdm:Print("Pet out: " .. (petOut and yes or no))
	if not petOut then
		cdm:Print("|cffff5555Summon a pet, put an ability on cooldown, then re-run.|r")
	end

	cdm:Print(string.format("APIs: GetSpellBaseCooldown=%s  GetSpellCooldown=%s  GetSpellCooldownDuration=%s",
		type(GetSpellBaseCooldown) == "function" and yes or no,
		(C_Spell and C_Spell.GetSpellCooldown) and yes or no,
		(C_Spell and C_Spell.GetSpellCooldownDuration) and yes or no))

	local hasPetSpells = (C_SpellBook and C_SpellBook.HasPetSpells) or _G.HasPetSpells
	if type(hasPetSpells) ~= "function" then
		cdm:Print("|cffff5555No HasPetSpells on this client -- pet discovery impossible.|r")
		return
	end

	local okCount, numPetSpells, petToken = pcall(hasPetSpells)
	cdm:Print(string.format("HasPetSpells() -> count=%s token=%s",
		okCount and SafeStr(numPetSpells) or "ERR", SafeStr(petToken)))
	if not okCount or type(numPetSpells) ~= "number" or numPetSpells <= 0 then
		cdm:Print("|cffff5555No pet spellbook to enumerate.|r")
		return
	end

	local useLegacy = type(_G.GetNumSpellTabs) == "function" and type(_G.GetSpellBookItemName) == "function"
	cdm:Print(string.format("Branch: %s (the one AddTrackedPetSpells takes)",
		useLegacy and "LEGACY spellbook" or "MODERN C_SpellBook"))

	self:EnsureCurves()
	local onCD, discovered = {}, 0

	for i = 1, numPetSpells do
		cdm:Print(string.format("  [%d] raw: %s", i, PetBookRaw(i, useLegacy)))

		local okItem, spellID, passive = pcall(ReadPetBookItem, i)
		if not okItem then
			cdm:Print("      |cffff5555ReadPetBookItem ERR|r: " .. SafeStr(spellID))
			spellID = nil
		end

		if spellID then
			local name = GetSpellNameIcon(spellID)
			local base = PetBaseCooldownDetail(spellID)
			local cdMS, gcdMS = PetBaseCooldown(spellID)
			local tracks = cdMS and cdMS >= MIN_PET_COOLDOWN_MS and cdMS > (gcdMS or 0) and not passive and name
			if tracks then discovered = discovered + 1 end

			cdm:Print(string.format("      id=%s %s passive=%s baseCD=%s -> %s",
				SafeStr(spellID), SafeStr(name), SafeStr(passive or false), base,
				tracks and "|cff00ff00TRACKED|r" or "|cff888888skipped|r"))

			if C_Spell and C_Spell.GetSpellCooldown then
				local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
				if not ok then
					cdm:Print("      GetSpellCooldown: |cffff5555ERR|r: " .. SafeStr(info))
				elseif info == nil then
					cdm:Print("      GetSpellCooldown: |cffff5555nil -- pet ids REJECTED|r")
				elseif type(info) ~= "table" then
					cdm:Print("      GetSpellCooldown: " .. SafeStr(info))
				else
					cdm:Print(string.format("      GetSpellCooldown: start=%s dur=%s isActive=%s isOnGCD=%s",
						ProbeClassify(issecret, function() return info.startTime end),
						ProbeClassify(issecret, function() return info.duration end),
						---@diagnostic disable-next-line: undefined-field
						ProbeClassify(issecret, function() return info.isActive end),
						---@diagnostic disable-next-line: undefined-field
						ProbeClassify(issecret, function() return info.isOnGCD end)))
					---@diagnostic disable-next-line: undefined-field
					if info.isActive then
						onCD[#onCD + 1] = { id = spellID, name = name }
					end
				end
			end
		end
	end

	cdm:Print(string.format("Discovery: %d of %d pet book entries would be TRACKED.", discovered, numPetSpells))

	if #onCD == 0 then
		cdm:Print("|cffEBB706No pet ability reads as on cooldown.|r If one IS on cooldown right now, the ids are rejected.")
	end
	for _, s in ipairs(onCD) do
		cdm:Print(string.format("|cffEBB706%s (%s) is on cooldown:|r", SafeStr(s.name), SafeStr(s.id)))
		if C_Spell and C_Spell.GetSpellCooldownDuration then
			local okD, dObj = pcall(C_Spell.GetSpellCooldownDuration, s.id, true)
			ProbeDObj(cdm, issecret, "  dObj", okD and dObj or nil,
				self.readyCurve, self.progressCurve, nil)
		end
	end

	if type(_G.GetPetActionCooldown) == "function" then
		for slot = 1, (_G.NUM_PET_ACTION_SLOTS or 10) do
			local ok, start, duration, enable = pcall(_G.GetPetActionCooldown, slot)
			if ok and PlainOrNil(start) and PlainOrNil(start) ~= 0 then
				cdm:Print(string.format("  GetPetActionCooldown(%d): start=%s dur=%s enable=%s", slot,
					ProbeClassify(issecret, function() return start end),
					ProbeClassify(issecret, function() return duration end),
					ProbeClassify(issecret, function() return enable end)))
			end
		end
	else
		cdm:Print("GetPetActionCooldown: absent on this client.")
	end

	local tracked, live = 0, 0
	for id, t in pairs(self.trackedSpells) do
		if t.category == ns.CONST.PET_CATEGORY then
			tracked = tracked + 1
			if self.entries[id] then live = live + 1 end
		end
	end
	cdm:Print(string.format("CDM state: %d pet spells in the tracked set, %d with a live entry.", tracked, live))
end


function Engine:RunOffensiveProbe()
	local cdm = ns.CDM
	if not (cdm and cdm.Print) then return end

	local issecret = _G.issecretvalue
	cdm:Print("===== Offensive probe =====")
	cdm:Print("In combat: " .. (InCombatLockdown() and "|cff00ff00YES|r" or "|cffff5555no|r"))
	cdm:Print("legend: SECRET=taint-blocked  <number>=usable plain value  ERR=call failed")

	if not (UnitExists and UnitExists("target")) then
		cdm:Print("|cffff5555No target.|r Target a mob, apply a damage-over-time effect, then re-run IN COMBAT.")
		return
	end

	cdm:Print(string.format("C_UnitAuras: GetAuraDataByIndex=%s GetAuraDuration=%s IsAuraFilteredOut=%s",
		tostring(C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataByIndex ~= nil),
		tostring(C_UnitAuras ~= nil and C_UnitAuras.GetAuraDuration ~= nil),
		tostring(C_UnitAuras ~= nil and C_UnitAuras.IsAuraFilteredOutByInstanceID ~= nil)))

	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		cdm:Print("Legacy client: the UnitAura path is used and every number is plain. Nothing to probe.")
		return
	end

	self:EnsureCurves()

	local found = 0
	for i = 1, 40 do
		local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
		if not ok or not d then break end
		found = found + 1

		cdm:Print(string.format("|cffEBB706[%s] %s|r",
			ProbeClassify(issecret, function() return d.spellId end),
			ProbeClassify(issecret, function() return d.name end)))
		cdm:Print(string.format("  duration=%s expiration=%s applications=%s sourceUnit=%s instanceID=%s",
			ProbeClassify(issecret, function() return d.duration end),
			ProbeClassify(issecret, function() return d.expirationTime end),
			ProbeClassify(issecret, function() return d.applications end),
			ProbeClassify(issecret, function() return d.sourceUnit end),
			ProbeClassify(issecret, function() return d.auraInstanceID end)))

		if C_UnitAuras.IsAuraFilteredOutByInstanceID then
			cdm:Print("  IsAuraFilteredOut(HARMFUL|PLAYER): " .. ProbeClassify(issecret,
				C_UnitAuras.IsAuraFilteredOutByInstanceID, "target", d.auraInstanceID, "HARMFUL|PLAYER"))
		end
		if C_UnitAuras.GetAuraDuration then
			local okD, dObj = pcall(C_UnitAuras.GetAuraDuration, "target", d.auraInstanceID)
			ProbeDObj(cdm, issecret, "aura dObj", okD and dObj or nil,
				self.readyCurve, self.progressCurve, nil)
		end
	end

	if found == 0 then
		cdm:Print("|cffEBB706No harmful auras of ours on the target.|r Apply one and re-run.")
		return
	end

	local discovered = 0
	for _ in pairs(self.trackedOffensives) do discovered = discovered + 1 end
	cdm:Print(string.format("Offensives discovered so far: %d", discovered))

	cdm:Print("Learned lengths (exact = read off the aura, timed = clocked off the combat log):")
	for spellID, dur in pairs(self.auraDurations) do
		cdm:Print(string.format("  exact %s = %.1fs", tostring(GetSpellNameIcon(spellID)), dur))
	end
	for spellID, dur in pairs(self.auraObserved) do
		cdm:Print(string.format("  timed %s = %.1fs", tostring(GetSpellNameIcon(spellID)), dur))
	end
	if not next(self.auraDurations) and not next(self.auraObserved) then
		cdm:Print("  |cffff5555none yet|r - no dot can render until one lands here.")
	end
end
