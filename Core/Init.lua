local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB    = LibStub("AceDB-3.0")

local CDM = AceAddon:NewAddon(ns.CONST.ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.CDM = CDM
_G[ns.CONST.ADDON_NAME] = CDM   -- expose globally so `/dump CooldownMaster` works in-game

CDM.version = ns.CONST.VERSION
CDM.lanes = {}
CDM.cooldowns = {}


function CDM:OnInitialize()
	-- Account-wide: one fixed "Default" profile, so AceDB copy/reset/export still work without exposing per-character profiles.
	self.db = AceDB:New(ns.CONST.SV_KEY, { profile = ns.DEFAULTS }, "Default")

	self:MigrateV030()

	if next(self.db.profile.classColors) == nil then
		for class, rgb in pairs(ns.CONST.CLASS_COLORS) do
			self.db.profile.classColors[class] = { r = rgb.r, g = rgb.g, b = rgb.b }
		end
	end

	for _, cmd in ipairs(ns.CONST.SLASH_COMMANDS) do
		self:RegisterChatCommand(cmd, "OnSlash")
	end

	if ns.DataBroker_Init then ns.DataBroker_Init(self) end
end


-- One-time migration off the pre-0.3.0 Bars/Ready scope. Idempotent; safe to delete in a later major version.
function CDM:MigrateV030()
	local p = self.db and self.db.profile
	if not p then return end

	if p.barFrames   ~= nil then p.barFrames   = nil end
	if p.readyFrames ~= nil then p.readyFrames = nil end

	if type(p.filters) == "table" then
		for _, f in pairs(p.filters) do
			if type(f) == "table" then
				if f.defaultBar   ~= nil then f.defaultBar   = nil end
				if f.defaultReady ~= nil then f.defaultReady = nil end
			end
		end
	end

	if type(p.perSpellRouting) == "table" then
		p.spellOverrides = p.spellOverrides or {}
		for spellID, laneIdx in pairs(p.perSpellRouting) do
			if type(spellID) == "number" and type(laneIdx) == "number" then
				local existing = p.spellOverrides[spellID]
				if type(existing) ~= "table" then
					p.spellOverrides[spellID] = { lane = laneIdx }
				else
					existing.lane = existing.lane or laneIdx
				end
			end
		end
		p.perSpellRouting = nil
	end
end


function CDM:OnEnable()
	self:RegisterEvent("PLAYER_LOGIN",          "OnPlayerLogin")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
end


function CDM:OnPlayerLogin()
	if self.db.profile.global.firstRun then
		self:Print(ns.Colorize(ns.CONST.HEX.YELLOW,
			"Welcome! Type /cdmaster to open the options panel."))
		self.db.profile.global.firstRun = false
	end
	self.db.profile.global.previousVersion = self.version
end


function CDM:OnEnteringWorld()
	if ns.Lanes_Build then ns.Lanes_Build(self) end

	if ns.Events and ns.Events.Register and not self._eventsWired then
		ns.Events.Register(self)
		self._eventsWired = true
	end

	-- Idempotent across world enters: Engine:Start reuses the same tick frame.
	if ns.Engine and ns.Engine.Start then
		ns.Engine:Start(self)
	end

	-- 2s delay lets Blizzard build its UI frames after login before we probe for them.
	if ns.Engine and ns.Engine.ScheduleFrameDiscovery then
		ns.Engine:ScheduleFrameDiscovery()
	end
end


function CDM:OnSlash(input)
	input = (input or ""):trim():lower()

	if input == "" or input == "config" or input == "options" then
		if ns.Options_Toggle then ns.Options_Toggle() end

	elseif input == "lock" then
		self.db.profile.global.unlockFrames = false
		self:Print("Frames |cff" .. ns.CONST.HEX.YELLOW .. "locked|r.")
		if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(self) end

	elseif input == "unlock" then
		self.db.profile.global.unlockFrames = true
		self:Print("Frames |cff" .. ns.CONST.HEX.YELLOW .. "unlocked|r.")
		if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(self) end

	elseif input == "test" then
		self:ToggleTestMode()

	elseif input == "reset" then
		self.db:ResetProfile()
		self:Print("Settings reset. /reload to rebuild frames.")

	elseif input == "version" then
		self:Print("Version " .. self.version .. " on " .. ns.Compat.FlavorLabel())

	elseif input == "api" then
		if ns.Engine and ns.Engine.RunAPIDiagnostic then
			ns.Engine:RunAPIDiagnostic()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "curvetest" or input == "curveprobe" then
		if ns.Engine and ns.Engine.RunCurveProbe then
			ns.Engine:RunCurveProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "seedtest" then
		if ns.Engine and ns.Engine.RunSeedDiagnostic then
			ns.Engine:RunSeedDiagnostic()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "spells" then
		self:OnSlashSpells()

	elseif input == "haste" then
		self:OnSlashHaste()

	elseif input == "frames" then
		if ns.Engine and ns.Engine.DiscoverBlizzardFrames then
			ns.Engine:DiscoverBlizzardFrames()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "slot" then
		if ns.Engine and ns.Engine.DiscoverActiveSlot then
			ns.Engine:DiscoverActiveSlot()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "debug" then
		local engine = ns.Engine
		if not engine then
			self:Print("Engine not loaded.")
			return
		end
		self:Print("Active entries: " .. engine:CountEntries())
		self:Print("C_CooldownViewer found: " .. tostring(engine.cooldownViewerFound))
		self:Print("Test mode: " .. (engine.testActive and "on" or "off"))
		self:Print("unlockFrames = " .. tostring(self.db.profile.global.unlockFrames))
		for i = 1, 3 do
			local f = self.lanes and self.lanes[i]
			if f then
				local laneCfg = self.db.profile.lanes[i]
				CDM:Print(string.format(
					"Lane %d: anchor=%s x=%s y=%s isDragging=%s",
					i,
					tostring(laneCfg and laneCfg.anchor),
					tostring(laneCfg and laneCfg.x),
					tostring(laneCfg and laneCfg.y),
					tostring(f._isDragging)))
			else
				CDM:Print("Lane " .. i .. ": <not created>")
			end
		end
		-- iconText[2] is the [cd.time] number; off means swipe-but-no-number (config, not a bug).
		for i = 1, 3 do
			local laneCfg = self.db.profile.lanes[i]
			local t2 = laneCfg and laneCfg.iconText and laneCfg.iconText[2]
			self:Print(string.format("Lane %d [cd.time] number: %s",
				i, t2 and tostring(t2.enabled) or "n/a"))
		end
		local now = GetTime()
		for uid, e in pairs(engine.entries) do
			local remaining = (e.endTime or now) - now
			if remaining < 0 then remaining = 0 end
			local tracked = engine.trackedSpells and engine.trackedSpells[e.spellID]
			self:Print(string.format("  [%d] %s (id=%s) %.1fs lane=%s dObj=%s charges=%s src=%s fed=%s",
				uid,
				tostring(e.name),
				tostring(e.spellID),
				remaining,
				tostring(e.laneIndex),
				e.dObj ~= nil and "yes" or "NO",
				tracked and tostring(tracked.hasCharges) or "?",
				tostring(e._source),
				tostring(e._cdFedPath)))
		end

	else
		self:Print("Commands: /cdmaster | lock | unlock | test | reset | version | debug | api | curvetest | seedtest | spells | haste | frames | slot")
	end
end


function CDM:ToggleTestMode()
	local engine = ns.Engine
	if not engine then
		self:Print("Engine not loaded.")
		return
	end
	if engine.testActive then
		engine:StopTestMode()
	else
		engine:StartTestMode()
	end
	self:Print("Test mode: " .. (engine.testActive and "|cff00ff00on|r" or "|cffff5555off|r"))
end


function CDM:OnSlashSpells()
	local engine = ns.Engine
	if not engine or not engine.trackedSpells then
		self:Print("Engine not started.")
		return
	end

	local list = {}
	for spellID, t in pairs(engine.trackedSpells) do
		table.insert(list, {
			id      = spellID,
			name    = t.name or "?",
			cat     = t.category,
			charges = t.hasCharges,
			cdid    = t.cooldownID,
			base    = engine.knownDurations[spellID]
				or engine.baselineDurations[spellID]
				or 0,
		})
	end
	table.sort(list, function(a, b) return a.name < b.name end)

	self:Print(string.format("===== Tracked spells: %d =====", #list))
	for _, s in ipairs(list) do
		self:Print(string.format(
			"[%d] %s | base=%.1fs | cat=%s | charges=%s | cdID=%s",
			s.id, s.name, s.base or 0, tostring(s.cat),
			tostring(s.charges), tostring(s.cdid)))
	end
end


function CDM:OnSlashHaste()
	local engine = ns.Engine
	self:Print(string.format(
		"Cached haste: %s",
		tostring(engine and engine.cachedHaste or "nil")))

	local ok, live = pcall(GetHaste)
	if ok then
		self:Print(string.format("Live haste: %s", tostring(live)))
	else
		self:Print("Live haste: <unreadable, likely in combat>")
	end

	self:Print("===== Active entries =====")
	local now = GetTime()
	if engine and engine.entries then
		for spellID, e in pairs(engine.entries) do
			local remaining = (e.endTime or now) - now
			self:Print(string.format(
				"[%d] %s | start=%.1f | dur=%.1f | end=%.1f | rem=%.1fs | lane=%s",
				spellID, e.name or "?",
				e.startTime or 0, e.duration or 0, e.endTime or 0,
				remaining, tostring(e.laneIndex)))
		end
	end
end


function CDM:Print(...)
	print(ns.ChatPrefix() .. table.concat({ tostringall(...) }, " "))
end