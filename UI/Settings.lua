local _, ns = ...
local L = ns.L

local EUI = LibStub("EverythingUI-1.0")
local ACCENT = EUI.tokens.accents.CDM
local MEDIA = "Interface\\AddOns\\CooldownMaster\\media\\"

local Settings = {}
ns.Settings = Settings

local function charDB()
	return ns.CDM and ns.CDM.db and ns.CDM.db.char
end

local function globalSettings()
	return ns.CDM and ns.CDM.db and ns.CDM.db.profile.global
end

local ui = EUI:NewContext({
	id         = "CDM",
	title      = ns.CONST.ADDON_DISPLAY,
	version    = ns.CONST.VERSION,
	accent     = ACCENT.accent,
	accentText = ACCENT.accentText,
	L          = L,
	tooltip    = function() return GameTooltip end,
	discord    = function() ns.ShowURL(ns.DISCORD_URL) end,
	-- Looked up here, not in the library, because the locale scanner skips Libs/ and would drop these keys
	labels     = {
		discord         = L["Join our Discord"],
		discordTipTitle = L["Join our Discord"],
		discordTip      = L["Click to copy the invite link."],
		testSound       = L["Plays the currently selected sound."],
		clear           = L["Clear"],
	},
	getLastTab     = function() local c = charDB() return c and c.lastOptionsTab end,
	setLastTab     = function(id) local c = charDB() if c then c.lastOptionsTab = id end end,
	getWindowScale = function() local g = globalSettings() return g and g.optionsScale end,
	setWindowScale = function(v) local g = globalSettings() if g then g.optionsScale = v end end,
})
Settings.ui = ui

-- Field by field, because the library raises on a field it does not know
function ns.ShowDialog(opts)
	ui:ShowDialog({
		title       = ns.CONST.ADDON_DISPLAY,
		text        = opts.text,
		button1     = opts.button1,
		button2     = opts.button2,
		onAccept    = opts.onAccept,
		onCancel    = opts.onCancel,
		hasEditBox  = opts.hasEditBox and true or nil,
		maxLetters  = opts.maxLetters,
		editBoxText = opts.editBoxText,
		readOnly    = opts.readOnly and true or nil,
		danger      = opts.danger and true or nil,
	})
end

function ns.ShowURL(url)
	if not url or url == "" then return end
	ns.ShowDialog({
		text        = L["Press Ctrl+C to copy, then Escape to close."],
		button1     = L["Close"],
		hasEditBox  = true,
		readOnly    = true,
		editBoxText = url,
	})
end

-- A name the player typed may be in an alphabet Barlow cannot draw, so it takes the client's own font
function Settings.PaintName(fs, base, text, color)
	if ui:NeedsClientFont(text) then
		fs:SetFontObject(GameFontHighlight)
		fs:SetShadowOffset(0, 0)
	else
		fs:SetFont(base[1], base[2], base[3])
	end
	fs:SetText(text)
	fs:SetTextColor(ui:Color(color))
end

function Settings.ButtonRow(self, content, card, list, style)
	local row = CreateFrame("Frame", nil, content)
	row:SetHeight(ui:Spacing("buttonHeight"))
	row._euiFill = true
	local prev
	for _, b in ipairs(list) do
		local btn = self:CreateButton(content, b[1], nil, b[2], nil, style)
		if prev then btn:SetPoint("LEFT", prev, "RIGHT", ui:Spacing("buttonGap"), 0) else btn:SetPoint("LEFT", row, "LEFT") end
		prev = btn
	end
	card:Add(row)
end

function Settings.Icon(name)
	return MEDIA .. name
end

-- Each card anchors to the last one shown, so a card this client or mode leaves out leaves no gap
function Settings.CardStack()
	local cards = {}
	local function restack()
		local gap = ui:Spacing("groupGap")
		local prev
		for _, card in ipairs(cards) do
			if card:IsShown() then
				card:ClearAllPoints()
				if prev then
					card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
					card:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gap)
				else
					card:SetPoint("TOPLEFT")
					card:SetPoint("TOPRIGHT")
				end
				prev = card
			end
		end
	end
	return function(card)
		cards[#cards + 1] = card
		restack()
		return card
	end, restack
end

-- apply is left out for a setting read live where it is used, so there is nothing to push
function Settings.Binder(get, apply)
	local B = {}
	function B.key(name, fallback, after)
		return function()
			local v = get()[name]
			if v == nil then return fallback end
			return v
		end, function(v)
			get()[name] = v
			if apply then apply() end
			if after then after(v) end
		end
	end
	function B.sub(tableName, field, fallback, make, after)
		return function()
			local t = get()[tableName]
			if type(t) ~= "table" or t[field] == nil then return fallback end
			return t[field]
		end, function(v)
			local cfg = get()
			if type(cfg[tableName]) ~= "table" then cfg[tableName] = make() end
			cfg[tableName][field] = v
			if apply then apply() end
			if after then after(v) end
		end
	end
	function B.color(name, fallback)
		return function()
			local c = get()[name]
			return type(c) == "table" and c or fallback
		end, function(v)
			if type(v) ~= "table" then return end
			local cfg = get()
			if type(cfg[name]) ~= "table" then cfg[name] = {} end
			local c = cfg[name]
			c.r, c.g, c.b, c.a = v.r, v.g, v.b, v.a
			if apply then apply() end
		end
	end
	function B.highlight(fallback, color, after)
		local function make()
			return { style = fallback, color = { r = color.r, g = color.g, b = color.b, a = color.a } }
		end
		local function styleGet()
			local h = get().highlight
			local s = type(h) == "table" and h.style or fallback
			-- Glow and Border + Flash draw exactly what Flash draws, so a saved one shows as Flash and is kept
			if s == "GLOW" or s == "BORDER_FLASH" then return "FLASH" end
			return s
		end
		local function styleSet(v)
			local cfg = get()
			if type(cfg.highlight) ~= "table" then cfg.highlight = make() end
			cfg.highlight.style = v
			if apply then apply() end
			if after then after(v) end
		end
		local function colorGet()
			local h = get().highlight
			return type(h) == "table" and type(h.color) == "table" and h.color or color
		end
		local function colorSet(v)
			local cfg = get()
			if type(cfg.highlight) ~= "table" then cfg.highlight = make() end
			if type(cfg.highlight.color) ~= "table" then cfg.highlight.color = {} end
			local c = cfg.highlight.color
			c.r, c.g, c.b, c.a = v.r, v.g, v.b, v.a
			if apply then apply() end
		end
		local function on()
			local h = get().highlight
			return ((type(h) == "table" and h.style) or fallback) ~= "NONE"
		end
		return styleGet, styleSet, colorGet, colorSet, on
	end
	return B
end

Settings.FONT_FLAGS = {
	{ value = "NONE",         label = L["None"] },
	{ value = "OUTLINE",      label = L["Outline"] },
	{ value = "THICKOUTLINE", label = L["Thick Outline"] },
}

Settings.ANCHORS = {
	{ value = "TOPLEFT",     label = L["Top Left"] },
	{ value = "TOP",         label = L["Top"] },
	{ value = "TOPRIGHT",    label = L["Top Right"] },
	{ value = "LEFT",        label = L["Left"] },
	{ value = "CENTER",      label = L["Center"] },
	{ value = "RIGHT",       label = L["Right"] },
	{ value = "BOTTOMLEFT",  label = L["Bottom Left"] },
	{ value = "BOTTOM",      label = L["Bottom"] },
	{ value = "BOTTOMRIGHT", label = L["Bottom Right"] },
}

Settings.GROW = {
	{ value = "DOWN",     label = L["Down"] },
	{ value = "UP",       label = L["Up"] },
	{ value = "RIGHT",    label = L["Right"] },
	{ value = "LEFT",     label = L["Left"] },
	{ value = "CENTER_V", label = L["Center (vertical)"] },
	{ value = "CENTER_H", label = L["Center (horizontal)"] },
}

Settings.HIGHLIGHTS = {
	{ value = "NONE",   label = L["None"] },
	{ value = "BORDER", label = L["Border"] },
	{ value = "FLASH",  label = L["Flash"] },
}

Settings.LABEL_ANCHORS = {
	{ value = "TOP",    label = L["Above icon"] },
	{ value = "CENTER", label = L["On icon"] },
	{ value = "BOTTOM", label = L["Below icon"] },
}

Settings.STATUS_ANCHORS = {
	{ value = "TOP",    label = L["Above frame"] },
	{ value = "BOTTOM", label = L["Below frame"] },
	{ value = "LEFT",   label = L["Left"] },
	{ value = "RIGHT",  label = L["Right"] },
}

-- Buff Bars lists Blizzard's own bar-style buffs, which only retail has, and Forever blocks the combat log Classic Offensives needs
function Settings.CategoryIsOffered(key)
	if key == "offensives" then return ns.Compat.HAS_OFFENSIVES and true or false end
	if key == "debuffs" then return ns.Compat.HAS_BLIZZ_CDM and true or false end
	return true
end

function Settings.Dims(deps)
	for _, d in ipairs(deps) do ui:SetDependent(d[1], d[2]() and true or false) end
end

-- Offsets are in each frame's own scaled units, so the reach widens as frames shrink, never under 500
function Settings.OffsetLimit()
	local s = (ns.GetFrameScale and ns.GetFrameScale()) or 1
	return math.max(500, math.floor(500 / s + 0.5))
end

function Settings.Slider(self, content, label, lo, hi, step, get, set, tooltip)
	return self:CreateSlider(content, label, lo, hi, step, get, set, tooltip).EnableTyping()
end

function Settings.TextField(self, content, label, get, set, tooltip, letters)
	return self:CreateTextField(content, label, function() return get() or "" end, set, tooltip,
		{ maxLetters = letters, live = true })
end

function Settings.FontDropdown(self, content, label, get, set, tooltip)
	return self:CreateDropdown(content, label, function() return Settings.Media("font", "Friz Quadrata TT") end,
		get, set, tooltip, nil, nil, Settings.FontFile)
end

function Settings.TextureDropdown(self, content, label, get, set, tooltip)
	return self:CreateDropdown(content, label, function() return Settings.Media("statusbar", "CDM Smooth") end,
		get, set, tooltip, Settings.PaintTexture)
end

function Settings.EdgeDropdown(self, content, label, get, set, tooltip)
	return self:CreateDropdown(content, label, function() return Settings.Media("border", "CDM Shadow") end,
		get, set, tooltip, nil, nil, nil, Settings.EdgeFile)
end

function Settings.FontCard(self, content, push, B, title, prefix, fallback, tooltip)
	local card = push(self:CreateGroup(content, title))
	local get, set = B.key(prefix .. "Font")
	card:Add(Settings.FontDropdown(self, content, L["Font"], get, set, tooltip))
	get, set = B.key(prefix .. "Size", fallback.size)
	card:Add(Settings.Slider(self, content, L["Font Size"], 6, 32, 1, get, set))
	get, set = B.key(prefix .. "Flags", fallback.flags)
	card:Add(self:CreateDropdown(content, L["Font Outline"], Settings.FONT_FLAGS, get, set))
	get, set = B.color(prefix .. "Color", fallback.color)
	card:Add(self:CreateColorPicker(content, L["Font Color"], get, set, nil, true))
	return card
end

local function newStatus() return { enabled = false, text = "[cd.next]", anchor = "BOTTOM" } end

function Settings.StatusCard(self, content, push, B, deps, sync)
	local card = push(self:CreateGroup(content, L["Status Line"]))
	local get, set = B.sub("statusText", "enabled", false, newStatus, sync)
	card:Add(self:CreateCheckbox(content, L["Show Status Line"], get, set,
		L["Draw one line of text on this frame, built from the tags in the box below. Off by default. Use it for a live readout - the next cooldown coming up, how many are on cooldown, or your target's name."]))
	local getText, setText = B.sub("statusText", "text", "", newStatus)
	local text = Settings.TextField(self, content, L["Text"], getText, setText, ns.TAG_HELP_STATUS, 120)
	local tags = Settings.TagRow(self, content, card, ns.TAG_PICKER_GLOBAL, text, getText, setText)
	get, set = B.sub("statusText", "anchor", "BOTTOM", newStatus)
	local where = self:CreateDropdown(content, L["Position"], Settings.STATUS_ANCHORS, get, set)
	get, set = B.key("statusFont")
	local font = Settings.FontDropdown(self, content, L["Font"], get, set)
	get, set = B.key("statusSize", 11)
	local size = Settings.Slider(self, content, L["Font Size"], 6, 32, 1, get, set)
	get, set = B.key("statusFlags", "OUTLINE")
	local flags = self:CreateDropdown(content, L["Font Outline"], Settings.FONT_FLAGS, get, set)
	get, set = B.color("statusColor", { r = 1, g = 1, b = 1, a = 1 })
	local col = self:CreateColorPicker(content, L["Font Color"], get, set, nil, true)
	local on = B.sub("statusText", "enabled", false, newStatus)
	for _, c in ipairs({ text, tags, where, font, size, flags, col }) do
		card:Add(c, { dependent = true })
		deps[#deps + 1] = { c, on }
	end
	return card
end

-- A control is the content's child, not its card's, so a hidden card has to hide what it holds as well
function Settings.ShowCard(card, shown, controls)
	card:SetShown(shown)
	for _, c in ipairs(controls) do c:SetShown(shown) end
	card:Layout()
end

local mediaCache = {}

-- LibSharedMedia refills one list per kind in place as media registers, so the options follow its length
function Settings.Media(kind, fallback)
	local LSM = LibStub("LibSharedMedia-3.0", true)
	local list = LSM and LSM:List(kind)
	local cached = mediaCache[kind]
	if not cached or cached.list ~= list or cached.count ~= #(list or {}) then
		local opts = {}
		for i, key in ipairs(list or {}) do opts[i] = { value = key, label = key } end
		if #opts == 0 then opts[1] = { value = fallback, label = fallback } end
		cached = { list = list, count = #(list or {}), opts = opts }
		mediaCache[kind] = cached
	end
	return cached.opts
end

local function fetch(kind, key)
	local LSM = LibStub("LibSharedMedia-3.0", true)
	return LSM and key and LSM:Fetch(kind, key, true)
end

function Settings.FontFile(key) return fetch("font", key) end
function Settings.EdgeFile(key) return fetch("border", key) end
function Settings.PaintTexture(frame, key) frame.swatch:SetTexture(fetch("statusbar", key)) end

-- The picker commits and cancels through the instance the strip shows, so it is canceled before a switch
local function closePicker()
	local picker = EUI.shared and EUI.shared.colorPicker
	if picker and picker.owner and picker.owner == Settings.frame and ColorPickerFrame and ColorPickerFrame:IsShown() then
		local cancel = picker.cancel
		ColorPickerFrame:Hide()
		if cancel then cancel() end
	end
end
Settings.ClosePicker = closePicker

-- A switched-off instance reads dimmer, and the section's own Enabled box says so in words
function Settings.Strip(state, labelFormat, isOn)
	return function(self, bar)
		local options = {}
		for i = 1, 3 do options[i] = { value = i, label = labelFormat:format(i) } end
		local seg = self:CreateRadioGroup(bar, nil, options,
			function() return state.index end,
			function(v)
				closePicker()
				state.index = v
				self:SelectTab(self._current)
			end)
		seg:SetPoint("LEFT", bar, "LEFT", ui:Spacing("contentSides"), 0)
		seg:SetPoint("RIGHT", bar, "RIGHT", -ui:Spacing("contentSides"), 0)
		bar._controls[#bar._controls + 1] = { Refresh = function()
			for i, b in ipairs(seg.buttons or {}) do b:SetAlpha((i == state.index or isOn(i)) and 1 or 0.5) end
		end }
	end
end

-- Laid out on screen, where the buttons know their width, wrapping to a new line when they do not fit
function Settings.TagRow(self, content, card, list, field, getText, setText)
	local minHeight = ui:Spacing("dependentRowHeight")
	local row = CreateFrame("Frame", nil, content)
	row:SetHeight(minHeight)
	row._euiFill = true
	local hint = self:CreateText(row, L["Click a tag to add it:"], "hint")
	local buttons = {}
	for i, entry in ipairs(list) do
		buttons[i] = self:CreateButton(row, entry[1], nil, function()
			setText((getText() or "") .. entry[2])
			field:Refresh()
		end, (L["Inserts %s"]):format(entry[2]), "ghost")
	end
	local gap, lineGap, pad = 6, 4, 4
	-- The row hangs from the middle of its card row, so the card row grows to the row's height
	function row.Fit()
		for _, b in ipairs(buttons) do b:Fit() end
		local width = row:GetWidth() or 0
		local lineH = 0
		for _, b in ipairs(buttons) do lineH = math.max(lineH, b:GetHeight() or 0) end
		local x, y = (hint:GetStringWidth() or 0) + 10, 0
		for _, b in ipairs(buttons) do
			local w = b:GetWidth() or 0
			if width > 0 and x + w > width then
				x = 0
				y = y + lineH + lineGap
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", row, "TOPLEFT", x, -(pad + y))
			x = x + w + gap
		end
		hint:ClearAllPoints()
		hint:SetPoint("LEFT", row, "TOPLEFT", 0, -(pad + lineH / 2))
		local h = math.max(minHeight, y + lineH + pad * 2)
		row:SetHeight(h)
		local r = row._euiRow
		if r and math.abs(r:GetHeight() - h) > 0.5 then
			r:SetHeight(h)
			card:Layout()
		end
	end
	local fits = content._euiFit or {}
	content._euiFit = fits
	fits[#fits + 1] = row
	row.buttons = buttons
	return row
end

local testButtons = {}

local function paintTest()
	local on = ns.Engine and ns.Engine.testActive and true or false
	for _, pair in ipairs(testButtons) do
		pair.test:SetShown(not on)
		pair.stop:SetShown(on)
	end
end

local function setTest(on)
	local engine = ns.Engine
	if ns.CDM and engine and (engine.testActive and true or false) ~= on then ns.CDM:ToggleTestMode() end
	paintTest()
end

function Settings.Footer(self, bar)
	local unlock = self:CreateCheckbox(bar, L["Unlock Frames"],
		function() local g = globalSettings() return g and g.unlockFrames end,
		function(v)
			local g = globalSettings()
			if not g then return end
			g.unlockFrames = v
			ns.ForEachSurface("RefreshUnlockState", ns.CDM)
			self:SelectTab(self._current)
		end,
		L["Unlock every lane and ready box so you can drag them into place. Backgrounds show while unlocked; lock again to hide the chrome and let clicks pass through."])
	unlock:SetPoint("LEFT")
	local pair = {
		test = self:CreateButton(bar, L["Test"], nil, function() setTest(true) end),
		stop = self:CreateButton(bar, L["Stop Test"], nil, function() setTest(false) end, nil, "primary"),
	}
	pair.test:SetPoint("RIGHT")
	pair.stop:SetPoint("RIGHT")
	testButtons[#testButtons + 1] = pair
	paintTest()
end

-- Every page reads its settings through its getters, so a change made elsewhere only draws the shown page again
function Settings.Redraw()
	local f = Settings.frame
	if f and f:IsShown() and ui._current then ui:SelectTab(ui._current) end
end

function Settings.ProfileChanged()
	-- A red confirm acts on whichever profile is current when Yes is clicked, so one left open under a change is canceled
	local d = ui._dialog
	if d and d.opts and d.opts.danger and d:IsShown() then d.cancel:Click() end
	local f = Settings.frame
	if f and f:IsShown() then ui:ApplyWindowScale() end
	Settings.Redraw()
end

local hooked

-- /cm test can start or stop a test while the window is open
local function watchTest()
	if hooked or not ns.Engine then return end
	hooked = true
	hooksecurefunc(ns.Engine, "StartTestMode", paintTest)
	hooksecurefunc(ns.Engine, "StopTestMode", paintTest)
end

function Settings.Toggle()
	if not Settings.frame then
		local f = ui:BuildSettings("CooldownMasterSettings")
		-- Leaving the window ends Test Mode, so the demo is not left looping
		f:HookScript("OnHide", function()
			if ns.CDM and ns.Engine and ns.Engine.testActive then ns.CDM:ToggleTestMode() end
		end)
		watchTest()
		-- Fired while the old profile is still current, so a canceled picker restores the color where it was taken
		ns.CDM.db.RegisterCallback(Settings, "OnProfileShutdown", closePicker)
		Settings.frame = f
	end
	ui:ToggleSettings()
end

-- The slash command, the minimap button, What's New and a profile change reach the window by these names
ns.Options_Toggle = Settings.Toggle
ns.Options_Rebuild = Settings.ProfileChanged

function ns.Options_Open(tabID)
	if not (Settings.frame and Settings.frame:IsShown()) then Settings.Toggle() end
	if tabID then ui:SelectTab(tabID) end
end
