local ADDON_NAME, ns = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB    = LibStub("AceDB-3.0")

local CDM = AceAddon:NewAddon(ns.CONST.ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.CDM = CDM
_G[ns.CONST.ADDON_NAME] = CDM   -- expose globally so `/dump CooldownMaster` works in-game

CDM.version = ns.CONST.VERSION
CDM.lanes = {}
CDM.readyFrames = {}
CDM.barFrames = {}
CDM.cooldowns = {}
-- Free-lists for frame reuse (WoW never GC's frames): `lanes`/`readyFrames` hold the
-- active ones, the pools hold every frame ever built so rebuilds reuse not recreate.
CDM.lanePool = {}
CDM.readyFramePool = {}
CDM.barFramePool = {}


ns.DISCORD_URL = "https://discord.gg/vm8K2WfQUE"

local urlPopup
function ns.ShowURL(url)
	if not url then return end
	if not urlPopup then
		local f = CreateFrame("Frame", "CooldownMasterURLPopup", UIParent,
			BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(440, 120)
		f:SetPoint("CENTER")
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		ns.Theme.ApplyBackdrop(f)

		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", f, "TOP", 0, -12)
		title:SetText(ns.CONST.ADDON_DISPLAY)
		title:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)

		local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
		hint:SetText("Press Ctrl+C to copy, then Escape to close.")

		local eb = CreateFrame("EditBox", nil, f,
			BackdropTemplateMixin and "BackdropTemplate" or nil)
		eb:SetSize(400, 22)
		eb:SetPoint("TOP", hint, "BOTTOM", 0, -10)
		eb:SetAutoFocus(false)
		eb:SetFontObject("GameFontHighlight")
		eb:SetTextInsets(6, 6, 2, 2)
		ns.Theme.ApplyBackdrop(eb, { r = 0.05, g = 0.05, b = 0.05, a = 1 }, ns.CONST.RGB.PANEL_BORDER)
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
		eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		f.editBox = eb

		local close = ns.Theme.CreateButton(f, "Close", 90, 24)
		close:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
		close:SetScript("OnClick", function() f:Hide() end)

		urlPopup = f
	end
	urlPopup.editBox:SetText(url)
	urlPopup.editBox:SetCursorPosition(0)
	urlPopup.editBox:HighlightText()
	urlPopup.editBox:SetFocus()
	urlPopup:Show()
end


function CDM:OnInitialize()
	self.db = AceDB:New(ns.CONST.SV_KEY, { profile = ns.DEFAULTS }, "Default")

	-- Per-character spec->profile map for auto-switch; db.char so it survives profile
	-- switches. Empty = no auto-switch.
	self.db.char.specProfiles = self.db.char.specProfiles or {}

	self:MigrateV030()

	if next(self.db.profile.classColors) == nil then
		for class, rgb in pairs(ns.CONST.CLASS_COLORS) do
			self.db.profile.classColors[class] = { r = rgb.r, g = rgb.g, b = rgb.b }
		end
	end

	for _, cmd in ipairs(ns.CONST.SLASH_COMMANDS) do
		self:RegisterChatCommand(cmd, "OnSlash")
	end

	-- A profile switch/copy/reset swaps db.profile to a different table, so rebuild from the new one.
	self.db.RegisterCallback(self, "OnProfileChanged", "ApplyProfile")
	self.db.RegisterCallback(self, "OnProfileCopied",  "ApplyProfile")
	self.db.RegisterCallback(self, "OnProfileReset",   "ApplyProfile")

	if ns.DataBroker_Init then ns.DataBroker_Init(self) end
end


-- One-time pre-0.3.0 key cleanup. Idempotent - safe to delete in a later major version.
function CDM:MigrateV030()
	local p = self.db and self.db.profile
	if not p then return end

	-- Dead diagnostic key: /cm curvetest writes db.profile._curveProbe for same-session
	-- inspection; clear it on load so it never ships permanently in saved variables.
	if p._curveProbe ~= nil then p._curveProbe = nil end

	-- Prune empty per-spell override tables a prior build persisted just from viewing the
	-- Filters list; they carry no settings (GetSpellOverride no longer creates them).
	if type(p.spellOverrides) == "table" then
		for id, ov in pairs(p.spellOverrides) do
			if type(ov) == "table" and next(ov) == nil then
				p.spellOverrides[id] = nil
			end
		end
	end

	if type(p.filters) == "table" then
		for _, f in pairs(p.filters) do
			if type(f) == "table" then
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


function CDM:ApplyProfile()
	if next(self.db.profile.classColors) == nil then
		for class, rgb in pairs(ns.CONST.CLASS_COLORS) do
			self.db.profile.classColors[class] = { r = rgb.r, g = rgb.g, b = rgb.b }
		end
	end
	self:MigrateV030()
	-- Learned durations are per-profile; without this a manual profile switch keeps running
	-- on the old profile's values until the next zoning.
	if ns.Engine and ns.Engine.LoadPersistedDurations then
		ns.Engine:LoadPersistedDurations()
	end
	if ns.Engine and ns.Engine.ClearCustomEntries then
		ns.Engine:ClearCustomEntries()
	end
	if ns.Engine and ns.Engine.RebuildCustomTriggers then
		ns.Engine:RebuildCustomTriggers()
	end
	-- Offensives track what is already on the target, so they reproject against the new profile at once instead of waiting for a recast.
	if ns.Engine and ns.Engine.RebuildOffensiveEntries then
		ns.Engine:RebuildOffensiveEntries()
	end
	for i = 1, 3 do
		if ns.Lanes_RebuildOne then ns.Lanes_RebuildOne(i) end
		if ns.ReadyFrames_RebuildOne then ns.ReadyFrames_RebuildOne(i) end
		if ns.Bars_RebuildOne then ns.Bars_RebuildOne(i) end
	end
	if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(self) end
	if ns.ReadyFrames_RefreshUnlockState then ns.ReadyFrames_RefreshUnlockState(self) end
	if ns.Bars_RefreshUnlockState then ns.Bars_RefreshUnlockState(self) end
	if ns.DataBroker_ApplyProfile then ns.DataBroker_ApplyProfile(self) end
	-- Defer to next frame: ApplyProfile can run from the Active-profile dropdown's onChange, and
	-- Options_Rebuild SetParent(nil)s that dropdown mid-callback; letting the callback unwind first
	-- avoids tearing down a frame still on the stack. (Rebuild wipes the filter caches itself.)
	if ns.Options_Rebuild then
		C_Timer.After(0, function()
			if ns.Options_Rebuild then ns.Options_Rebuild() end
		end)
	end
end


function CDM:OnEnable()
	self:RegisterEvent("PLAYER_LOGIN",          "OnPlayerLogin")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
	-- Specs exist on retail + MoP only; gate registration so spec-less flavors
	-- (Era/TBC) don't register an unknown event.
	if ns.Compat.GetNumSpecs() then
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
	end
end


function CDM:OnPlayerLogin()
	-- Runs once per session, driven from whichever of PLAYER_LOGIN / first PLAYER_ENTERING_WORLD
	-- reaches us first (PLAYER_LOGIN can be missed -- see OnEnteringWorld).
	if self._loginHandled then return end
	self._loginHandled = true

	if self.db.profile.global.firstRun then
		self:Print(ns.Colorize(ns.CONST.HEX.YELLOW,
			"Welcome! Type /cdmaster to open the options panel."))
		self.db.profile.global.firstRun = false
	end
	if ns.WhatsNew_OnLogin then ns.WhatsNew_OnLogin() end
	self:ApplySpecProfile()
end


-- Switch to the profile mapped to the active spec (Profiles tab > Auto-switch by
-- Specialization). No-op when unmapped, already active, the spec API is absent
-- (Classic), or the mapped profile was deleted.
function CDM:ApplySpecProfile()
	if not self.db.char.specProfiles then return end
	local idx = ns.Compat.GetSpecIndex()
	if not idx then return end
	local specID = ns.Compat.GetSpecInfo(idx)
	if not specID then return end
	local target = self.db.char.specProfiles[specID]
	if not target or target == self.db:GetCurrentProfile() then return end
	for _, name in ipairs(self.db:GetProfiles()) do
		if name == target then
			self.db:SetProfile(target)
			return
		end
	end
end


function CDM:OnSpecChanged(_, unit)
	if unit and unit ~= "player" then return end
	self:ApplySpecProfile()
end


function CDM:OnEnteringWorld()
	-- A /reload mid-combat misses PLAYER_REGEN_DISABLED, so seed combat from the
	-- live API before the first visibility pass (the autohide gate reads self.combat).
	self.combat = InCombatLockdown()
	if ns.Lanes_Build then ns.Lanes_Build(self) end
	if ns.ReadyFrames_Build then ns.ReadyFrames_Build(self) end
	if ns.Bars_Build then ns.Bars_Build(self) end
	-- Build is idempotent and won't re-evaluate existing lanes, so refresh the
	-- In Instance / In Group gate explicitly on every world enter.
	if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	if ns.Bars_RefreshVisibility then ns.Bars_RefreshVisibility() end

	if ns.Events and ns.Events.Register and not self._eventsWired then
		ns.Events.Register(self)
		self._eventsWired = true
	end

	-- Idempotent across world enters: Engine:Start reuses the same tick frame.
	if ns.Engine and ns.Engine.Start then
		ns.Engine:Start(self)
	end

	-- AceAddon enables us mid-PLAYER_LOGIN dispatch on a fresh login, so the PLAYER_LOGIN
	-- handler registered in OnEnable can miss its own event. This fires reliably, so run the
	-- once-per-session login work here too (self-guarded, so a real PLAYER_LOGIN is harmless).
	self:OnPlayerLogin()
end


function CDM:OnSlash(input)
	input = (input or ""):trim():lower()

	if input == "" or input == "config" or input == "options" then
		if ns.Options_Toggle then ns.Options_Toggle() end

	elseif input == "lock" then
		self.db.profile.global.unlockFrames = false
		self:Print("Frames |cff" .. ns.CONST.HEX.YELLOW .. "locked|r.")
		if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(self) end
		if ns.ReadyFrames_RefreshUnlockState then ns.ReadyFrames_RefreshUnlockState(self) end
		if ns.Bars_RefreshUnlockState then ns.Bars_RefreshUnlockState(self) end

	elseif input == "unlock" then
		self.db.profile.global.unlockFrames = true
		self:Print("Frames |cff" .. ns.CONST.HEX.YELLOW .. "unlocked|r.")
		if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(self) end
		if ns.ReadyFrames_RefreshUnlockState then ns.ReadyFrames_RefreshUnlockState(self) end
		if ns.Bars_RefreshUnlockState then ns.Bars_RefreshUnlockState(self) end

	elseif input == "test" then
		self:ToggleTestMode()

	elseif input == "reset" then
		self.db:ResetProfile()
		self:Print("Settings reset to defaults.")

	elseif input == "version" then
		self:Print("Version " .. self.version .. " on " .. ns.Compat.FlavorLabel())

	elseif input == "whatsnew" or input == "news" then
		if ns.WhatsNew_Show then ns.WhatsNew_Show() end

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

	elseif input == "offprobe" then
		if ns.Engine and ns.Engine.RunOffensiveProbe then
			ns.Engine:RunOffensiveProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "off" then
		if ns.Engine and ns.Engine.RunOffensiveDump then
			ns.Engine:RunOffensiveDump()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "off arm" then
		if ns.Compat.HAS_COMBAT_LOG then
			self:Print("off trace is retail-only (Classic offensives run off the combat log, not the cast-driven binder).")
		elseif ns.Engine then
			ns.Engine._offTraceUntil = GetTime() + 20
			self:Print("|cff00ff00off trace armed 20s.|r Run your FULL rotation on the target now. Watching CAST / RENDER / REANCHOR / PEND / DROP / BIND for the offensive binder.")
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "tagprobe" then
		if ns.RunTagProbe then
			ns.RunTagProbe()
		else
			self:Print("Tags not loaded.")
		end

	elseif input == "auraprobe" then
		if ns.Engine and ns.Engine.ArmAuraInstanceProbe then
			ns.Engine:ArmAuraInstanceProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "auraapi" then
		if ns.Engine and ns.Engine.RunAuraApiProbe then
			ns.Engine:RunAuraApiProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "offreset" then
		if ns.Engine and ns.Engine.ResetOffensiveLearning then
			ns.Engine:ResetOffensiveLearning()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "offlearn" then
		if ns.Compat.HAS_COMBAT_LOG then
			self:Print("Guided offensive learning is retail-only (Classic reads debuffs straight off the combat log).")
		elseif not ns.Engine then
			self:Print("Engine not loaded.")
		elseif ns.Engine.testActive then
			self:Print("Exit Test Mode first, then run /cm offlearn.")
		else
			ns.Engine:StartOffLearn()
			self:Print("|cff00ff00Offensive learn armed.|r Target a dummy, cast ONE dot ability, then STOP and let combat drop (~6s) so I can read what it applied. Repeat for each ability. A /reload or logout cancels it - just run /cm offlearn again. /cm offlearn stop to end.")
		end

	elseif input == "offlearn stop" then
		if ns.Engine and ns.Engine.StopOffLearn then
			ns.Engine:StopOffLearn()
			self:Print("Offensive learn stopped.")
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "items" then
		if ns.Engine and ns.Engine.RunItemDump then
			ns.Engine:RunItemDump()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "buffs" then
		if ns.Engine and ns.Engine.RunBuffProbe then
			ns.Engine:RunBuffProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "petprobe" or input == "pettest" then
		if ns.Engine and ns.Engine.RunPetProbe then
			ns.Engine:RunPetProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "seedtest" then
		if ns.Engine and ns.Engine.RunSeedDiagnostic then
			ns.Engine:RunSeedDiagnostic()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "anchor" then
		if ns.Engine and ns.Engine.RunAnchorProbe then
			ns.Engine:RunAnchorProbe()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "anchor arm" then
		if not ns.Compat.HAS_BLIZZ_CDM then
			-- The tracer lives in the retail ScanSpells loop; Classic dispatch never reaches it,
			-- so arming here would print the banner and then nothing, forever.
			self:Print("anchor trace is retail-only (Classic scans real cooldown numbers directly).")
		elseif ns.Engine then
			ns.Engine._traceUntil = GetTime() + 12
			wipe(ns.Engine._traceState)
			self:Print("anchor trace armed 12s -- legend: A/a=isActive G/g=onGCD V/v=active E/e=entry M/m=multiCharge")
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "cdv" then
		if ns.Engine and ns.Engine.RunCooldownViewerDump then
			ns.Engine:RunCooldownViewerDump()
		else
			self:Print("Engine not loaded.")
		end

	elseif input == "spells" then
		self:OnSlashSpells()

	elseif input == "haste" then
		self:OnSlashHaste()

	elseif input == "tracking" then
		if ns.Lanes_TrackingReport then ns.Lanes_TrackingReport() end

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
			-- Position-duration ladder: dur is what the icon extrapolates from. If dur is
			-- much shorter than the live %.1fs above, the icon races to the ready edge.
			self:Print(string.format("       dur=%.1f known=%s obs=%s base=%s fresh=%s seenReady=%s",
				e.duration or 0,
				tostring(engine.knownDurations[e.spellID]),
				tostring(engine.observedDurations[e.spellID]),
				tostring(engine.baselineDurations[e.spellID]),
				tostring(e._fresh),
				tostring(engine._seenReady and engine._seenReady[e.spellID])))
		end

		-- Live charge-spell state (combat-safe fields only; currentCharges is secret). Shows
		-- why a charge spell does/doesn't track: it should be tracked only when usable=false.
		for spellID, tracked in pairs(engine.trackedSpells or {}) do
			if tracked.hasCharges then
				local cdok, info = pcall(C_Spell.GetSpellCooldown, spellID)
				local uok, usable = pcall(C_Spell.IsSpellUsable, spellID)
				local chok, ch = pcall(C_Spell.GetSpellCharges, spellID)
				local maxC = (chok and type(ch) == "table" and ch.maxCharges) or "?"
				self:Print(string.format("  charge %s (id=%s): isActive=%s onGCD=%s usable=%s maxCharges=%s entry=%s",
					tostring(tracked.name), tostring(spellID),
					tostring(cdok and info and info.isActive),
					tostring(cdok and info and info.isOnGCD),
					tostring(uok and usable),
					tostring(maxC),
					engine.entries[spellID] and "yes" or "no"))
			end
		end

	else
		self:Print("Commands: /cm (or /cdmaster) | lock | unlock | test | reset | version | whatsnew | debug | api | curvetest | seedtest | petprobe | offprobe | off | offlearn | auraprobe | auraapi | offreset | tagprobe | items | buffs | anchor | cdv | spells | haste | tracking")
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
	if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
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