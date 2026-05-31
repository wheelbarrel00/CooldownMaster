--[[
	Cooldown Master - Init.lua
	Main addon object, initialization, slash commands.
--]]

local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB    = LibStub("AceDB-3.0")

-- Create the addon. We mix in AceConsole and AceEvent for slash commands and
-- event registration; everything else (DataBroker, options, engine) attaches
-- in their own files.
local CDM = AceAddon:NewAddon(ns.CONST.ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.CDM = CDM
_G[ns.CONST.ADDON_NAME] = CDM   -- expose globally so `/dump CooldownMaster` works in-game

CDM.version = ns.CONST.VERSION
CDM.lanes = {}        -- runtime lane frames, keyed 1..3
CDM.cooldowns = {}    -- active cooldown objects
CDM.testing = false


-- AceAddon lifecycle: called once after all addon files have loaded.
function CDM:OnInitialize()
	-- Single account-wide profile. Storing under "default" inside an AceDB so we
	-- still get profile-handling utilities (copy / reset / export) for free,
	-- without exposing per-character profiles in the UI.
	self.db = AceDB:New(ns.CONST.SV_KEY, { profile = ns.DEFAULTS }, "Default")

	-- v0.3.0 migration: scope was reduced to lanes only. Strip orphaned
	-- bar/ready saved values and the obsolete defaultBar/defaultReady filter
	-- routing keys. Safe to run repeatedly; later versions can drop this block.
	self:MigrateV030()

	-- Seed class color overrides on first run if the user hasn't customised them.
	if next(self.db.profile.classColors) == nil then
		for class, rgb in pairs(ns.CONST.CLASS_COLORS) do
			self.db.profile.classColors[class] = { r = rgb.r, g = rgb.g, b = rgb.b }
		end
	end

	-- Slash commands → opens the options panel (or runs subcommands).
	for _, cmd in ipairs(ns.CONST.SLASH_COMMANDS) do
		self:RegisterChatCommand(cmd, "OnSlash")
	end

	-- Stub hooks; real implementations live in their own files.
	if ns.DataBroker_Init then ns.DataBroker_Init(self) end
end


-- One-time cleanup of saved values left over from the pre-0.3.0 multi-frame
-- scope (Bars + Ready). Idempotent; can be removed in a later major version.
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

	-- Fold the legacy perSpellRouting map into spellOverrides, where Filters
	-- now stores both visibility and lane preferences in one shape:
	--   spellOverrides[spellID] = { visible = bool, lane = int|nil }
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


-- Called by AceAddon after OnInitialize, when the addon is enabled.
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
	-- Hook point for spawning lane frames once world data is available.
	if ns.Lanes_Build then ns.Lanes_Build(self) end

	-- Wire SPELL_UPDATE_COOLDOWN + visibility events into the engine.
	if ns.Events and ns.Events.Register and not self._eventsWired then
		ns.Events.Register(self)
		self._eventsWired = true
	end

	-- Boot the cooldown engine. Safe to call again on subsequent world enters;
	-- Engine:Start() is idempotent (it reuses the same tick frame).
	if ns.Engine and ns.Engine.Start then
		ns.Engine:Start(self)
	end

	-- Schedule the one-shot frame discovery probe (2s delay so Blizzard's UI
	-- has time to construct its frames after login).
	if ns.Engine and ns.Engine.ScheduleFrameDiscovery then
		ns.Engine:ScheduleFrameDiscovery()
	end
end


-- Slash command dispatcher. `/cdmaster` opens the options panel; subcommands give
-- quick keyboard access to common actions.
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
		self.testing = not self.testing
		self:Print("Test mode: " .. (self.testing and "|cff00ff00on|r" or "|cffff5555off|r"))

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
		self:Print("Test mode: " .. (self.testing and "on" or "off"))
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
		local now = GetTime()
		for uid, e in pairs(engine.entries) do
			local remaining = (e.endTime or now) - now
			if remaining < 0 then remaining = 0 end
			self:Print(string.format("  [%d] %s (id=%s) %.1fs lane=%s",
				uid,
				tostring(e.name),
				tostring(e.spellID),
				remaining,
				tostring(e.laneIndex)))
		end

	else
		self:Print("Commands: /cdmaster | lock | unlock | test | reset | version | debug | api | curvetest | spells | haste | frames | slot")
	end
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
			base    = engine.baseCooldowns and engine.baseCooldowns[spellID] or 0,
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


-- AceConsole's Print() prefix is plain text; override to use our themed prefix.
function CDM:Print(...)
	print(ns.ChatPrefix() .. table.concat({ tostringall(...) }, " "))
end