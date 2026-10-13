local _, ns = ...
local L = ns.L

local Settings = ns.Settings
local ui = Settings.ui

local CHECK_SIZE, NAME_GAP = 14, 10

local function db() return ns.CDM.db end

local function say(msg) ns.CDM:Print(msg) end

-- Per-character learning, not settings: never exported, and an import keeps the player's own
local LEARNED_KEYS = {
	knownDurations    = true,
	observedDurations = true,
	auraDurations     = true,
	auraObserved      = true,
	castMap           = true,
	auraRoll          = true,
	-- A migration marker: lost in an import, the castMap purge would run on the player's learning again
	castMapPurged     = true,
}

-- AceDB rawsets every default into the profile, so the export carries the complete tree
local function exportString()
	local ser = LibStub("AceSerializer-3.0", true)
	local def = LibStub("LibDeflate", true)
	if not (ser and def and ns.CDM) then return nil end
	local settings = {}
	for k, v in pairs(ns.CDM.db.profile) do
		if not LEARNED_KEYS[k] then settings[k] = v end
	end
	local payload = ser:Serialize({
		addon   = ns.CONST.ADDON_NAME,
		version = ns.CONST.VERSION,
		profile = settings,
	})
	return def:EncodeForPrint(def:CompressDeflate(payload, { level = 9 }))
end

local function decode(str)
	local ser = LibStub("AceSerializer-3.0", true)
	local def = LibStub("LibDeflate", true)
	if not (ser and def) then return nil, L["serialization libraries unavailable"] end
	str = (str or ""):gsub("%s", "")
	if str == "" then return nil, L["empty string"] end
	local compressed = def:DecodeForPrint(str)
	if not compressed then return nil, L["not a valid import string"] end
	local payload = def:DecompressDeflate(compressed)
	if not payload then return nil, L["could not decompress"] end
	local ok, data = ser:Deserialize(payload)
	if not ok or type(data) ~= "table" then return nil, L["could not read profile data"] end
	if data.addon ~= ns.CONST.ADDON_NAME or type(data.profile) ~= "table" then
		return nil, L["not a Cooldown Master profile string"]
	end
	return data.profile
end

-- Merged into the reset profile, so a key an older string lacks keeps its default
local function overlay(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			overlay(dst[k], v)
		else
			dst[k] = v
		end
	end
end

-- Reset silently, so nothing rebuilds on bare defaults before the string is merged in
local function applyImported(prof)
	local p = ns.CDM.db.profile
	local keep = {}
	for k in pairs(LEARNED_KEYS) do keep[k] = p[k] end
	ns.CDM.db:ResetProfile(nil, true)
	overlay(p, prof)
	for k, v in pairs(keep) do p[k] = v end
	ns.CDM:ApplyProfile()
end

local names = {}

local function profileNames()
	db():GetProfiles(names)
	table.sort(names)
	return names
end

local function exists(name)
	for _, n in ipairs(profileNames()) do
		if n == name then return true end
	end
	return false
end

local pageSync

local function refresh()
	if pageSync then pageSync() end
end

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and deepCopy(v) or v end
	return out
end

local function validName(name)
	if name == "" then
		say(L["Enter a profile name first."])
	elseif name == db():GetCurrentProfile() then
		say(L["Already on profile: %s"]:format(name))
	elseif exists(name) then
		say(L["Profile already exists: %s (switch to it in the list, or pick a new name)."]:format(name))
	else
		return true
	end
	return false
end

local function promptName(text, duplicate, typed)
	ns.ShowDialog({
		text        = text,
		button1     = L["Create"],
		button2     = CANCEL,
		hasEditBox  = true,
		maxLetters  = 32,
		editBoxText = typed,
		onAccept    = function(entered)
			local name = (entered or ""):match("^%s*(.-)%s*$")
			if not validName(name) then
				promptName(text, duplicate, name)
				return
			end
			-- Copied in before the switch, so the Engine applies one profile and never a bare one first
			if duplicate then db().profiles[name] = deepCopy(db().profile) end
			db():SetProfile(name)
			say(L["Created and switched to profile: %s"]:format(name))
			refresh()
		end,
	})
end

local function switchTo(name)
	if name and name ~= db():GetCurrentProfile() then db():SetProfile(name) end
	refresh()
end

local function askCopy(name)
	ns.ShowDialog({
		text     = L["Copy every setting from \"%s\" into your current profile, \"%s\"? Your current settings are replaced."]:format(name, db():GetCurrentProfile()),
		button1  = YES,
		button2  = NO,
		danger   = true,
		onAccept = function()
			if name ~= db():GetCurrentProfile() and exists(name) then
				Settings.ClosePicker()
				db():CopyProfile(name)
			end
		end,
	})
end

local function askDelete(name)
	ns.ShowDialog({
		text     = L["Delete profile \"%s\"? This cannot be undone."]:format(name),
		button1  = YES,
		button2  = NO,
		danger   = true,
		onAccept = function()
			if name ~= db():GetCurrentProfile() and exists(name) then db():DeleteProfile(name) end
			refresh()
		end,
	})
end

local function askReset()
	ns.ShowDialog({
		text     = L["Reset profile \"%s\" to default settings?"]:format(db():GetCurrentProfile()),
		button1  = YES,
		button2  = NO,
		danger   = true,
		onAccept = function()
			Settings.ClosePicker()
			db():ResetProfile()
		end,
	})
end

local function export()
	local s = exportString()
	if s then ns.ShowURL(s) else say(L["Export failed."]) end
end

local function askImport()
	ns.ShowDialog({
		text       = L["Paste an exported string to overwrite the current profile \"%s\"."]:format(db():GetCurrentProfile()),
		button1    = L["Import"],
		button2    = CANCEL,
		hasEditBox = true,
		danger     = true,
		onAccept   = function(text)
			local prof, err = decode(text)
			if not prof then
				say(L["Import failed: %s"]:format(err or L["invalid string"]))
				return
			end
			Settings.ClosePicker()
			applyImported(prof)
			say(L["Imported into profile \"%s\"."]:format(db():GetCurrentProfile()))
		end,
	})
end

local function profileRow(self, content, box, i)
	local pad, height = ui:Spacing("rowPadding"), ui:Spacing("rowHeight")
	local r = CreateFrame("Frame", nil, box)
	r:SetHeight(height)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * height)
	r:SetPoint("TOPRIGHT", 0, -(i - 1) * height)
	if i > 1 then ui:Paint(r, nil, "divider", "T") end
	r.tint = r:CreateTexture(nil, "BACKGROUND")
	r.tint:SetAllPoints()
	r.tint:SetColorTexture(ui:Color("accentSoft"))
	r.check = r:CreateTexture(nil, "ARTWORK")
	r.check:SetSize(CHECK_SIZE, CHECK_SIZE)
	r.check:SetPoint("LEFT", pad, 0)
	r.check:SetTexture(ui:Texture("check"))
	r.check:SetVertexColor(ui:Color("accentHi"))
	r.delete = self:CreateButton(r, L["Delete"], nil, function() askDelete(r.profile) end)
	r.copy = self:CreateButton(r, L["Copy"], nil, function() askCopy(r.profile) end)
	r.switch = self:CreateButton(r, L["Switch"], nil, function() switchTo(r.profile) end)
	r.delete:SetPoint("RIGHT", -pad, 0)
	r.copy:SetPoint("RIGHT", r.delete, "LEFT", -ui:Spacing("buttonGap"), 0)
	r.switch:SetPoint("RIGHT", r.copy, "LEFT", -ui:Spacing("buttonGap"), 0)
	r.buttons = { r.switch, r.copy, r.delete }
	-- Listed on the page as well, the only list the window sizes again once the page is on screen
	local fits = content._euiFit or {}
	content._euiFit = fits
	for _, b in ipairs(r.buttons) do fits[#fits + 1] = b end
	r.name = self:CreateText(r, "", "label")
	r.font = { r.name:GetFont() }
	r.name:SetWordWrap(false)
	r.name:SetPoint("LEFT", r.check, "RIGHT", NAME_GAP, 0)
	r.name:SetPoint("RIGHT", r.switch, "LEFT", -NAME_GAP, 0)
	return r
end

local specChoices, specKey = {}, nil

-- A deleted profile keeps its mapping, so the field names it until another is picked
local function specOptions()
	local list = profileNames()
	local key = table.concat(list, "\001")
	if key ~= specKey then
		specKey = key
		for i = #specChoices, 1, -1 do specChoices[i] = nil end
		specChoices[1] = { value = "", label = L["(no auto-switch)"] }
		for _, n in ipairs(list) do specChoices[#specChoices + 1] = { value = n, label = n } end
	end
	return specChoices
end

local function specCard(self, content, push)
	local fields = {}
	-- GetSpecInfo(1) as well, so a client that counts specs it cannot name shows no card instead of erroring
	local numSpecs = ns.Compat.GetNumSpecs()
	if not (numSpecs and numSpecs > 0 and ns.Compat.GetSpecInfo(1)) then return fields end
	local card = push(self:CreateGroup(content, L["Auto-switch by Specialization"]))
	self:AttachTooltip(card.label, L["Auto-switch by Specialization"], L["Switch profile automatically when you change spec."])
	local function map() return ns.CDM.db.char.specProfiles end
	for i = 1, numSpecs do
		local specID, specName = ns.Compat.GetSpecInfo(i)
		if specID then
			local dd = self:CreateDropdown(content, specName, specOptions,
				function() return map()[specID] or "" end,
				function(v) map()[specID] = (v ~= "" and v) or nil end)
			card:Add(dd)
			fields[#fields + 1] = dd
		end
	end
	return fields
end

local function build(self, content)
	local push = Settings.CardStack()
	local card = push(self:CreateGroup(content, L["Profiles"]))
	local box = CreateFrame("Frame", nil, content)
	box._euiFill = true
	card:Add(box, { height = ui:Spacing("rowHeight") })
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", box._euiRow, "TOPLEFT")
	box:SetPoint("BOTTOMRIGHT", box._euiRow, "BOTTOMRIGHT")
	Settings.ButtonRow(self, content, card, {
		{ L["New Profile"], function() promptName(L["Name for the new (empty) profile:"]) end },
		{ L["Duplicate Current"], function() promptName(L["Name for the copy of the current profile:"], true) end },
	})
	Settings.ButtonRow(self, content, push(self:CreateGroup(content, nil)), {
		{ L["Export"], export },
		{ L["Import"], askImport },
	})
	local specs = specCard(self, content, push)

	local rows = {}
	pageSync = function()
		local current = db():GetCurrentProfile()
		local list = profileNames()
		for i, name in ipairs(list) do
			local r = rows[i] or profileRow(self, content, box, i)
			rows[i] = r
			local active = name == current
			r.profile = name
			Settings.PaintName(r.name, r.font, name, "text")
			r.tint:SetShown(active)
			r.check:SetShown(active)
			for _, b in ipairs(r.buttons) do b:SetShown(not active) end
			r:Show()
		end
		for i = #list + 1, #rows do rows[i]:Hide() end
		local h = #list * ui:Spacing("rowHeight")
		if math.abs((box._euiRow:GetHeight() or 0) - h) > 0.5 then
			box._euiRow:SetHeight(h)
			card:Layout()
		end
		for _, dd in ipairs(specs) do dd:Refresh() end
		ui:MeasureContent(content)
	end
end

ui:RegisterTab({
	id      = "profiles",
	title   = L["Profiles"],
	order   = 70,
	icon    = Settings.Icon("icon-person"),
	build   = build,
	refresh = function() refresh() end,
	footer  = function(self, bar)
		self:CreateButton(bar, L["Reset current profile to defaults"], nil, askReset, nil, "danger"):SetPoint("RIGHT")
	end,
})
