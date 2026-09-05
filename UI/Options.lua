local ADDON_NAME, ns = ...

local Theme = ns.Theme
local L = ns.L

local TABS = {
	{ id = "global",       label = L["Global"],     builder = nil },
	{ id = "lanes",        label = L["Lanes"],      builder = nil },
	{ id = "ready",        label = L["Ready"],      builder = nil },
	{ id = "bars",         label = L["Bars"],       builder = nil },
	{ id = "filters",      label = L["Filters"],    builder = nil },
	{ id = "colors",       label = L["Colors"],     builder = nil },
	{ id = "profiles",     label = L["Profiles"],   builder = nil },
	{ id = "about",        label = L["About"],      builder = nil, static = true },
}

local panel
local tabButtons = {}
local tabContents = {}
local currentTabID
local optionsStale


local function BuildPanel()
	panel = CreateFrame("Frame", "CooldownMasterOptionsPanel", UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetSize(Theme.PANEL.WIDTH, Theme.PANEL.HEIGHT)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("HIGH")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
	panel:Hide()

	-- Leaving the panel ends test mode so the demo isn't left looping.
	panel:SetScript("OnHide", function()
		if ns.CDM and ns.Engine and ns.Engine.testActive then ns.CDM:ToggleTestMode() end
	end)

	Theme.ApplyBackdrop(panel)

	local header = Theme.CreateHeader(panel, ns.CONST.ADDON_DISPLAY)
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)

	local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	versionText:SetPoint("LEFT", header, "RIGHT", 8, -1)
	versionText:SetText("v" .. ns.CONST.VERSION .. "  -  " .. ns.Compat.FlavorLabel())
	versionText:SetTextColor(0.7, 0.7, 0.7)

	local closeBtn = Theme.CreateButton(panel, "X", 28, 24)
	closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
	closeBtn:SetScript("OnClick", function() panel:Hide() end)

	local tabBar = CreateFrame("Frame", nil, panel)
	tabBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  10, -Theme.PANEL.HEADER_H - 4)
	tabBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -Theme.PANEL.HEADER_H - 4)
	tabBar:SetHeight(Theme.PANEL.TAB_H)

	local content = CreateFrame("Frame", nil, panel,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT",     tabBar, "BOTTOMLEFT",  0, -Theme.PANEL.TAB_GAP)
	content:SetPoint("BOTTOMRIGHT", panel,  "BOTTOMRIGHT", -10, 10)
	Theme.ApplyBackdrop(content,
		{ r = 0, g = 0, b = 0, a = 0.55 },
		ns.CONST.RGB.PANEL_BORDER)

	panel.content = content

	local x = 0
	for _, def in ipairs(TABS) do
		local b = Theme.CreateTab(tabBar, def.label, 105)
		b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
		b:SetScript("OnClick", function() ns.Options_SelectTab(def.id) end)
		tabButtons[def.id] = b
		x = x + 105 + Theme.PANEL.TAB_GAP
	end
end


local function GetOrCreateTabContent(id)
	if tabContents[id] then return tabContents[id] end

	local f = CreateFrame("Frame", nil, panel.content)
	f:SetAllPoints(panel.content)
	f:Hide()
	tabContents[id] = f

	for _, def in ipairs(TABS) do
		if def.id == id then
			if def.builder then
				def.builder(f)
			else
				local fs = Theme.CreateHeader(f, def.label, "GameFontNormalHuge")
				fs:SetPoint("CENTER")
				local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				sub:SetPoint("TOP", fs, "BOTTOM", 0, -8)
				sub:SetText(string.format(L["This tab is not yet implemented in v%s."], ns.CONST.VERSION))
				sub:SetTextColor(0.7, 0.7, 0.7)
			end
			break
		end
	end
	return f
end


function ns.Options_SelectTab(id)
	if not panel then return end
	currentTabID = id
	-- A rebuild deferred while the panel was closed lands here once, on the next open. Clearing the
	-- flag first keeps Options_Rebuild's own tail call from re-entering.
	if optionsStale then
		optionsStale = nil
		ns.Options_Rebuild()
		return
	end
	for _, def in ipairs(TABS) do
		local btn = tabButtons[def.id]
		if btn then btn:SetSelected(def.id == id) end
		local frame = tabContents[def.id]
		if frame then frame:Hide() end
	end
	local frame = GetOrCreateTabContent(id)
	-- A cached tab can hold controls that went stale while it was hidden (see BuildGlobalTab).
	if frame._reseed then frame._reseed() end
	frame:Show()
end


local function ApplyOptionsScale()
	if not panel then return end
	local g = ns.CDM and ns.CDM.db and ns.CDM.db.profile and ns.CDM.db.profile.global
	local s = g and g.optionsScale
	panel:SetScale((type(s) == "number" and s > 0) and s or 1)
end


function ns.Options_Toggle()
	if not panel then BuildPanel() end
	if panel:IsShown() then
		panel:Hide()
	else
		ApplyOptionsScale()
		panel:Show()
		ns.Options_SelectTab(currentTabID or "global")
	end
end


-- Show, never toggle - the What's New popup's Open Options button must not close an open panel.
function ns.Options_Open(tabID)
	if not panel then BuildPanel() end
	ApplyOptionsScale()
	if not panel:IsShown() then panel:Show() end
	ns.Options_SelectTab(tabID or currentTabID or "global")
end


-- A slider fires onChange every drag step, so debounce the re-seed. The hoisted callback keeps the drag closure-free.
local testReseedPending

local function DoTestReseed()
	testReseedPending = nil
	if ns.Engine and ns.Engine.testActive then ns.Engine:StartTestMode() end
end

local function RequestTestReseed()
	if testReseedPending then return end
	if not (ns.Engine and ns.Engine.testActive) then return end
	testReseedPending = true
	C_Timer.After(0.15, DoTestReseed)
end

local function BuildTestTypeOptions()
	local opts = {}
	for _, def in ipairs(ns.CONST.TEST_TYPES) do
		opts[#opts + 1] = { value = def.value, text = def.text }
	end
	return opts
end


local function BuildGlobalTab(content)
	local CDM = ns.CDM
	local pad = Theme.PANEL.CONTENT_PAD
	local checks = {}

	local section = Theme.CreateHeader(content, L["Enabled:"], "GameFontNormal")
	section:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	-- Extend the checkbox hit rect over its label so hovering the row shows the tip. hitExtend
	-- defaults to a wide -180 for the vertical column; the horizontal Always/Group/Instance row
	-- passes a narrower value so a tip doesn't bleed onto the next checkbox.
	local function AttachTip(cb, label, tooltip, hitExtend)
		if not tooltip then return end
		cb:SetHitRectInsets(0, hitExtend or -180, 0, 0)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(label)
			GameTooltip:AddLine(tooltip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	local function MakeCheck(label, key, anchor, xOff, tooltip, hitExtend)
		local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff or 0, -4)
		cb:SetSize(24, 24)
		local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		fs:SetText(label)
		cb:SetChecked(CDM.db.profile.global[key])
		checks[#checks + 1] = { cb = cb, key = key }
		cb:SetScript("OnClick", function(self)
			CDM.db.profile.global[key] = self:GetChecked() and true or false
			-- Per-tick config apply is gone, so push the drag-label repaint explicitly.
			if key == "unlockFrames" then
				ns.ForEachSurface("RefreshUnlockState", CDM)
			elseif key == "autohide" then
				ns.ForEachSurface("RefreshVisibility")
			elseif key == "enabledAlways" then
				-- Lanes only: the In Group / In Instance gate does not apply to boxes or bars.
				if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
			end
		end)
		AttachTip(cb, label, tooltip, hitExtend)
		return cb
	end

	local cbAlways   = MakeCheck(L["Always"],      "enabledAlways",   section, 0,
		L["Show your lanes at all times, no matter where you are. When on, the In Group and In Instance conditions do not matter."], -90)
	local cbGroup    = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbGroup:SetPoint("LEFT", cbAlways, "RIGHT", 120, 0)
	cbGroup:SetSize(24, 24)
	local fsg = cbGroup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsg:SetPoint("LEFT", cbGroup, "RIGHT", 4, 0); fsg:SetText(L["In Group"])
	cbGroup:SetChecked(CDM.db.profile.global.enabledGroup)
	checks[#checks + 1] = { cb = cbGroup, key = "enabledGroup" }
	cbGroup:SetScript("OnClick", function(self)
		CDM.db.profile.global.enabledGroup = self:GetChecked() and true or false
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)
	AttachTip(cbGroup, L["In Group"],
		L["Show your lanes only while you are in a party or raid. Any ticked visibility box can show them, so this stacks with In Instance."], -90)

	local cbInst = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbInst:SetPoint("LEFT", cbGroup, "RIGHT", 120, 0)
	cbInst:SetSize(24, 24)
	local fsi = cbInst:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsi:SetPoint("LEFT", cbInst, "RIGHT", 4, 0); fsi:SetText(L["In Instance"])
	cbInst:SetChecked(CDM.db.profile.global.enabledInstance)
	checks[#checks + 1] = { cb = cbInst, key = "enabledInstance" }
	cbInst:SetScript("OnClick", function(self)
		CDM.db.profile.global.enabledInstance = self:GetChecked() and true or false
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)
	AttachTip(cbInst, L["In Instance"],
		L["Show your lanes only while you are inside a dungeon, raid, or other instance. Any ticked visibility box can show them."], -90)

	local prev = cbAlways
	local toggles = {
		{ L["Unlock Frames"], "unlockFrames", L["Unlock every lane and ready box so you can drag them into place. Backgrounds show while unlocked; lock again to hide the chrome and let clicks pass through."] },
		{ L["Auto-hide Frames"], "autohide", L["Out of combat, hides each lane's background, border, name, and markers, but your tracked cooldown icons stay visible. The chrome returns in combat. Tick a lane's Override Autohide (Lanes > General) to keep its chrome always shown."] },
		{ L["Enable tooltips"], "enableTooltip", L["Show the spell or item tooltip when you hover a cooldown icon on a lane. Icons take the mouse only while frames are locked, so this never blocks dragging."] },
		{ L["Detect Shared Spell Cooldowns"], "detectSharedCD", L["When one ability is tracked under two spell IDs that share a cooldown (a base spell and its talent override, or the same spell in two categories), show one icon and one ready pop instead of duplicates."] },
		{ L["Tint Unusable Icons"], "notUsableTint", L["While a spell or item cannot be used right now (not enough resources, wrong stance, out of range), tint its icon with the Unusable Tint Color below."] },
		{ L["Desaturate Unusable Icons"], "notUsableDesaturate", L["While a spell or item cannot be used right now, draw its icon in greyscale. Can be combined with Tint Unusable Icons."] },
	}
	for _, t in ipairs(toggles) do
		prev = MakeCheck(t[1], t[2], prev, 0, t[3])
	end

	-- The tab frame is cached, but unlockFrames and autohide also change from the minimap button and
	-- /cm lock|unlock. A stale tick swallows the next click, because OnClick writes the toggle of
	-- what is drawn rather than of what is stored. Options_SelectTab re-seeds on every show.
	content._reseed = function()
		local g = ns.CDM.db.profile.global
		for i = 1, #checks do
			checks[i].cb:SetChecked(g[checks[i].key] and true or false)
		end
	end

	local W = ns.Widgets
	local cpUnusable = W.CreateColorPicker(content, {
		label = L["Unusable Tint Color"], color = CDM.db.profile.global.notUsableColor, hasAlpha = false,
		onChange = function(r, g, b)
			local c = CDM.db.profile.global.notUsableColor
			c.r, c.g, c.b = r, g, b
		end,
	})
	cpUnusable:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
	prev = cpUnusable

	local slZoom = W.CreateSlider(content, {
		label = L["Icon Zoom"], min = 1, max = 2, step = 0.05,
		value = CDM.db.profile.global.zoom, width = 220,
		onChange = function(v) CDM.db.profile.global.zoom = v end,
	})
	slZoom:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
	prev = slZoom

	-- State is dataBroker.minimap.hide, not global[key], so it can't use MakeCheck;
	-- flip through the existing DataBroker_ToggleMinimap (Show/Hide owns the LDBIcon).
	local cbMinimap = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbMinimap:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
	cbMinimap:SetSize(24, 24)
	local fsm = cbMinimap:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsm:SetPoint("LEFT", cbMinimap, "RIGHT", 4, 0)
	fsm:SetText(L["Show Minimap Button"])
	cbMinimap:SetChecked(not CDM.db.profile.dataBroker.minimap.hide)
	cbMinimap:SetScript("OnClick", function()
		if ns.DataBroker_ToggleMinimap then ns.DataBroker_ToggleMinimap(CDM) end
	end)
	prev = cbMinimap

	local secUpdates = W.CreateSectionHeader(content, L["Updates"])
	secUpdates:SetWidth(320)
	secUpdates:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 2, -14)
	prev = secUpdates

	-- Account-wide (db.global), not per-profile: the update notice is a per-account preference.
	local ddWhatsNew = W.CreateDropdown(content, {
		label = L["After an update"], width = 200,
		value = CDM.db.global.whatsNewMode or "popup",
		options = {
			{ value = "popup", text = L["Popup window"] },
			{ value = "chat",  text = L["Chat link"]    },
			{ value = "none",  text = L["Off"]          },
		},
		tooltip = L["How Cooldown Master tells you about a new version: a Popup window, a quiet clickable Chat link in your chat, or Off. Reopen the notes any time with /cm whatsnew."],
		onChange = function(v) CDM.db.global.whatsNewMode = v end,
	})
	ddWhatsNew:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
	prev = ddWhatsNew

	local wnBtn = Theme.CreateButton(content, L["Show What's New"], 150, 24)
	wnBtn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
	wnBtn:SetScript("OnClick", function()
		if ns.WhatsNew_Show then ns.WhatsNew_Show() end
	end)

	local g = CDM.db.profile.global

	local testHeader = W.CreateSectionHeader(content, L["Test Mode"])
	testHeader:SetWidth(320)
	testHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 420, -pad)
	local tprev = testHeader

	local function placeTest(widget, gap)
		widget:SetPoint("TOPLEFT", tprev, "BOTTOMLEFT", 0, -(gap or 8))
		tprev = widget
		return widget
	end

	placeTest(W.CreateDropdown(content, {
		label = L["Type"], value = g.testType or "mixed",
		options = BuildTestTypeOptions(), width = 200,
		tooltip = L["Which kind of sample cooldowns to create. Mixed uses a spread of your spells, buffs and utility. Each type is routed with that category's Lane, Bar and Ready Box settings, so this previews your own Filters routing."],
		onChange = function(v) g.testType = v; RequestTestReseed() end,
	}))

	placeTest(W.CreateSlider(content, {
		label = L["Number of Cooldowns"], min = 1, max = 20, step = 1,
		value = g.testCount or 6, width = 240,
		tooltip = L["How many sample cooldowns to create, from 1 to 20. A ready box only holds as many icons as its Max Ready Icons setting, so extras push the oldest pop out."],
		onChange = function(v) g.testCount = v; RequestTestReseed() end,
	}))

	placeTest(W.CreateSlider(content, {
		label = L["First Cooldown Duration"], min = 1, max = 600, step = 1,
		value = g.testFirst or 5, width = 240,
		tooltip = L["Length of the first sample cooldown, in seconds. The rest are spread evenly between this and the Last Cooldown Duration."],
		onChange = function(v) g.testFirst = v; RequestTestReseed() end,
	}))

	placeTest(W.CreateSlider(content, {
		label = L["Last Cooldown Duration"], min = 1, max = 600, step = 1,
		value = g.testLast or 120, width = 240,
		tooltip = L["Length of the last sample cooldown, in seconds. A lane only draws cooldowns up to its Max Time unless you turn off Hide Long Timers, so a value above that will not appear on the lane."],
		onChange = function(v) g.testLast = v; RequestTestReseed() end,
	}))

	placeTest(W.CreateCheckbox(content, {
		label = L["Loop"],
		checked = g.testLoop ~= false,
		tooltip = L["Keep restarting the sample cooldowns after they pop into the ready box. Turn this off to watch them run once and clear."],
		onChange = function(v) g.testLoop = v; RequestTestReseed() end,
	}))

	local testBtn = Theme.CreateButton(content, L["Test"], 110, 30)
	testBtn:SetPoint("TOPLEFT", tprev, "BOTTOMLEFT", 0, -16)
	testBtn:SetScript("OnClick", function()
		if ns.Engine and not ns.Engine.testActive then CDM:ToggleTestMode() end
	end)

	local stopTestBtn = Theme.CreateButton(content, L["Stop Test"], 110, 30)
	stopTestBtn:SetPoint("TOPLEFT", testBtn, "TOPRIGHT", 8, 0)
	stopTestBtn:SetScript("OnClick", function()
		if ns.Engine and ns.Engine.testActive then CDM:ToggleTestMode() end
	end)

	local scaleHeader = W.CreateSectionHeader(content, L["Scale"])
	scaleHeader:SetWidth(320)
	scaleHeader:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -18)

	local frameScaleSlider = W.CreateSlider(content, {
		label = L["Cooldown Frames"], min = 0.5, max = 2, step = 0.05,
		value = g.frameScale or 1, width = 240,
		tooltip = L["Resize the cooldown display - your lanes, bars and ready boxes - together. 1.00 is the normal size, below shrinks them, above enlarges them. They keep their on-screen position as they scale."],
		onChange = function(v)
			if type(v) ~= "number" or v <= 0 then return end
			local old = (type(g.frameScale) == "number" and g.frameScale > 0) and g.frameScale or 1
			g.frameScale = v
			-- Offsets are stored in each frame's own scaled units, so rescale them to hold the on-screen position as the scale changes.
			if old ~= v then
				local ratio = old / v
				for _, key in ipairs({ "lanes", "readyFrames", "barFrames" }) do
					local list = CDM.db.profile[key]
					if list then
						for _, c in pairs(list) do
							if type(c.x) == "number" then c.x = c.x * ratio end
							if type(c.y) == "number" then c.y = c.y * ratio end
						end
					end
				end
			end
			for i = 1, 3 do
				if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(i) end
				if ns.ReadyFrames_ApplyConfig then ns.ReadyFrames_ApplyConfig(i) end
				if ns.Bars_ApplyConfig then ns.Bars_ApplyConfig(i) end
			end
		end,
	})
	frameScaleSlider:SetPoint("TOPLEFT", scaleHeader, "BOTTOMLEFT", 0, -8)

	-- The rescale above rewrote every offset, so cached Appearance forms hold stale values and
	-- stale offset-slider bounds. Drop them on release, never per drag step - each drop orphans a
	-- form tree that WoW never collects.
	local dropForms = function() ns.Options_DropAppearanceForms() end
	if frameScaleSlider._slider then
		frameScaleSlider._slider:HookScript("OnMouseUp", dropForms)
	end
	if frameScaleSlider._edit then
		frameScaleSlider._edit:HookScript("OnEditFocusLost", dropForms)
	end

	-- Applied on RELEASE, never live. This slider is a child of the panel it scales, so scaling
	-- mid-drag moves the slider track under the cursor and the value oscillates (the flashing and
	-- wrong sizes). onChange only records the value; the hooks below apply it once the drag ends.
	local optScaleSlider = W.CreateSlider(content, {
		label = L["Options Window"], min = 0.5, max = 2, step = 0.05,
		value = g.optionsScale or 1, width = 240,
		tooltip = L["Resize this Cooldown Master settings window itself. 1.00 is the normal size. Applies when you let go of the slider or press Enter."],
		onChange = function(v)
			if type(v) == "number" and v > 0 then g.optionsScale = v end
		end,
	})
	optScaleSlider:SetPoint("TOPLEFT", frameScaleSlider, "BOTTOMLEFT", 0, -10)
	if optScaleSlider._slider then
		optScaleSlider._slider:HookScript("OnMouseUp", ApplyOptionsScale)
	end
	if optScaleSlider._edit then
		optScaleSlider._edit:HookScript("OnEditFocusLost", ApplyOptionsScale)
	end
end

for _, def in ipairs(TABS) do
	if def.id == "global" then def.builder = BuildGlobalTab end
end


-- Offsets are stored in each frame's own scaled units, so the slider has to reach further as the
-- frames shrink or Frame Scale can park a value it cannot represent. Keeps a constant screen reach.
local function OffsetLimit()
	local s = (ns.GetFrameScale and ns.GetFrameScale()) or 1
	-- Never narrower than the old fixed range, or a pre-1.8.0 profile sitting at a scale above 1
	-- could hold an offset this slider can no longer represent, and clamp it on the first nudge.
	return math.max(500, math.floor(500 / s + 0.5))
end


local LANES_INNER_RAIL_W = 160
local LANES_SECTION_LIST = {
	{ id = "general",    label = L["General"]    },
	{ id = "appearance", label = L["Appearance"] },
	{ id = "icons",      label = L["Icons"]      },
	{ id = "stacking",   label = L["Stacking"]   },
	{ id = "text",       label = L["Text"]       },
}

local ANCHOR_OPTIONS = {
	{ value = "TOPLEFT",     text = L["Top Left"]     },
	{ value = "TOP",         text = L["Top"]          },
	{ value = "TOPRIGHT",    text = L["Top Right"]    },
	{ value = "LEFT",        text = L["Left"]         },
	{ value = "CENTER",      text = L["Center"]       },
	{ value = "RIGHT",        text = L["Right"]        },
	{ value = "BOTTOMLEFT",  text = L["Bottom Left"]  },
	{ value = "BOTTOM",      text = L["Bottom"]       },
	{ value = "BOTTOMRIGHT", text = L["Bottom Right"] },
}

local MODE_OPTIONS = {
	{ value = "LINEAR",   text = L["Linear"]                },
	{ value = "TIMELINE", text = L["Timeline (seconds)"]    },
	{ value = "LOG",      text = L["Logarithmic (seconds)"] },
	{ value = "SPLIT",    text = L["Split (seconds)"]       },
}

local FONT_FLAG_OPTIONS = {
	{ value = "NONE",         text = L["None"]          },
	{ value = "OUTLINE",      text = L["Outline"]       },
	{ value = "THICKOUTLINE", text = L["Thick Outline"] },
}

local ICON_LABEL_ANCHOR_OPTIONS = {
	{ value = "TOP",    text = L["Above icon"] },
	{ value = "CENTER", text = L["On icon"]    },
	{ value = "BOTTOM", text = L["Below icon"] },
}

local STATUS_ANCHOR_OPTIONS = {
	{ value = "TOP",    text = L["Above frame"] },
	{ value = "BOTTOM", text = L["Below frame"] },
	{ value = "LEFT",   text = L["Left"]        },
	{ value = "RIGHT",  text = L["Right"]       },
}

local LANE_TEXT_ANCHOR_OPTIONS = {
	{ value = "TOP",    text = L["Above lane"] },
	{ value = "CENTER", text = L["On lane"]    },
	{ value = "BOTTOM", text = L["Below lane"] },
}

local MARKER_ANCHOR_MODE_OPTIONS = {
	{ value = "PERCENT",      text = L["Percent of lane"]              },
	{ value = "PERCENT_AUTO", text = L["Percent of lane (auto label)"] },
	{ value = "TIME",         text = L["Time (seconds)"]               },
	{ value = "TIME_AUTO",    text = L["Time (auto label)"]            },
}

-- Linear gives every icon its own cooldown to span, so there is no shared clock a time anchor could read.
local MARKER_ANCHOR_MODE_OPTIONS_PERCENT = {
	MARKER_ANCHOR_MODE_OPTIONS[1],
	MARKER_ANCHOR_MODE_OPTIONS[2],
}

local MARKER_ANCHOR_AS_PERCENT = {
	TIME      = "PERCENT",
	TIME_AUTO = "PERCENT_AUTO",
}

local function BuildFontOptions()
	local opts = {}
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for _, key in ipairs(LSM:List("font")) do
			-- Silent fetch: a font registered by an addon that is no longer installed resolves to nil, and the row falls back to the default face rather than rendering blank.
			opts[#opts + 1] = { value = key, text = key, font = LSM:Fetch("font", key, true) }
		end
	end
	if #opts == 0 then
		opts[1] = { value = "Friz Quadrata TT", text = "Friz Quadrata TT" }
	end
	return opts
end

local TRACKING_OPTIONS = {
	{ value = "NONE",  text = L["None"]  },
	{ value = "GCD",   text = "GCD"   },
	{ value = "SWING", text = L["Swing"] },
}

local function BuildStatusbarOptions()
	local opts = {}
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for _, key in ipairs(LSM:List("statusbar")) do
			opts[#opts + 1] = { value = key, text = key, texture = LSM:Fetch("statusbar", key, true) }
		end
	end
	if #opts == 0 then opts[1] = { value = "CDM Smooth", text = "CDM Smooth" } end
	return opts
end

local function BuildBorderOptions()
	local opts = {}
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for _, key in ipairs(LSM:List("border")) do
			opts[#opts + 1] = { value = key, text = key, edge = LSM:Fetch("border", key, true) }
		end
	end
	if #opts == 0 then opts[1] = { value = "CDM Shadow", text = "CDM Shadow" } end
	return opts
end


local HL_STYLE_OPTIONS = {
	{ value = "NONE",         text = L["None"]           },
	{ value = "BORDER",       text = L["Border"]         },
	{ value = "GLOW",         text = L["Glow"]           },
	{ value = "FLASH",        text = L["Flash"]          },
	{ value = "BORDER_FLASH", text = L["Border + Flash"] },
}


local lanesState = {
	laneIndex   = 1,
	sectionID   = "general",
	subTabBtns  = {},
	railRows    = {},
	formFrames  = {},
}

local YELLOW


local function GetLaneCfg(laneIndex)
	return ns.CDM.db.profile.lanes[laneIndex]
end


local function RefreshLane(laneIndex)
	-- Config is no longer applied per render tick, so push it explicitly before re-rendering.
	if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(laneIndex) end
	if ns.Lanes_Refresh then ns.Lanes_Refresh(laneIndex) end
end


local function RebuildLane(laneIndex)
	if ns.Lanes_RebuildOne then ns.Lanes_RebuildOne(laneIndex) end
end


local function BuildTagTextRow(parent, place, sub, apply, labelText, tagSet, tip)
	local W = ns.Widgets

	local eb = W.CreateEditBox(parent, {
		label = labelText or L["Text"], value = sub.text or "", width = 200, maxLetters = 120,
		tooltip = tip or ns.TAG_HELP,
		onChange = function(t) sub.text = t; apply() end,
	})

	local picker = CreateFrame("Frame", nil, parent)
	local hdr = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hdr:SetPoint("TOPLEFT", picker, "TOPLEFT", 0, 0)
	hdr:SetText(L["Click a tag to add it:"])
	hdr:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)

	local list = tagSet or {}
	local COLS, BW, BH, ROWH, GAP = 3, 115, 18, 20, 6
	for i, entry in ipairs(list) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local b = W.CreateButton(picker, {
			label = entry[1], width = BW, height = BH, tooltip = string.format(L["Inserts %s"], entry[2]),
			onClick = function()
				local nt = (eb:GetValue() or "") .. entry[2]
				eb:SetValue(nt)
				if eb._onChange then eb._onChange(nt) end
			end,
		})
		b:SetPoint("TOPLEFT", picker, "TOPLEFT", col * (BW + GAP), -14 - row * ROWH)
	end
	local rows = math.ceil(#list / COLS)
	local gridH = 14 + rows * ROWH
	picker:SetSize(COLS * BW + (COLS - 1) * GAP, gridH)

	place(eb, math.max(40, gridH))
	picker:SetPoint("TOPLEFT", eb, "TOPRIGHT", 16, 0)
end


local function BuildStatusLineSection(parent, place, pad, cfg, apply)
	local W = ns.Widgets

	local sec = W.CreateSectionHeader(parent, L["Status Line"])
	sec:SetWidth(parent:GetWidth() - pad * 2)
	place(sec, 18)

	cfg.statusText = cfg.statusText or { enabled = false, text = "[cd.next]", anchor = "BOTTOM" }

	place(W.CreateCheckbox(parent, {
		label = L["Show Status Line"],
		checked = cfg.statusText.enabled,
		tooltip = L["Draw one line of text on this frame, built from the tags in the box below. Off by default. Use it for a live readout - the next cooldown coming up, how many are on cooldown, or your target's name."],
		onChange = function(v) cfg.statusText.enabled = v; apply() end,
	}))
	BuildTagTextRow(parent, place, cfg.statusText, apply, L["Text"], ns.TAG_PICKER_GLOBAL, ns.TAG_HELP_STATUS)

	place(W.CreateDropdown(parent, {
		label = L["Position"], value = cfg.statusText.anchor or "BOTTOM",
		options = STATUS_ANCHOR_OPTIONS, width = 240,
		onChange = function(v) cfg.statusText.anchor = v; apply() end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.statusFont, options = BuildFontOptions(), width = 240,
		onChange = function(v) cfg.statusFont = v; apply() end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.statusSize or 11, width = 240,
		onChange = function(v) cfg.statusSize = v; apply() end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.statusFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.statusFlags = v; apply() end,
	}))
	cfg.statusColor = cfg.statusColor or { r = 1, g = 1, b = 1, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.statusColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.statusColor
			c.r, c.g, c.b, c.a = r, g, b, a
			apply()
		end,
	}))
end


local function BuildLaneGeneralForm(parent, laneIndex)
	local W = ns.Widgets
	local cfg = GetLaneCfg(laneIndex)
	local pad = 12
	local rowGap = 10

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateEditBox(parent, {
		label = L["Frame Name"], value = cfg.frameName, width = 240, maxLetters = 32,
		onChange = function(text)
			cfg.frameName = text
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Enabled"], checked = cfg.enabled,
		onChange = function(v)
			cfg.enabled = v
			RebuildLane(laneIndex)
			-- The "(off)" suffix lives in shared option tables that only the Filters BUILDERS
			-- refresh, so a cached surface would keep showing a disabled lane as available.
			if ns.Options_RefreshLaneLabels then ns.Options_RefreshLaneLabels() end
			if ns.Options_InvalidateFilterLists then ns.Options_InvalidateFilterLists() end
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Reversed"], checked = cfg.reversed,
		onChange = function(v) cfg.reversed = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Vertical"], checked = cfg.vertical,
		tooltip = L["Run this lane top-to-bottom instead of left-to-right. Toggling it swaps the lane's Width and Height (Appearance tab) so the bar keeps its shape, just rotated."],
		onChange = function(v)
			cfg.vertical = v
			-- Flip the long/thin axes so a horizontal bar becomes a same-shaped vertical one
			-- (travel axis is Width when horizontal, Height when vertical). Drop the cached
			-- Appearance form so its Width/Height sliders rebuild with the swapped values.
			cfg.width, cfg.height = cfg.height, cfg.width
			local cached = lanesState.formFrames[laneIndex]
			if cached and cached["appearance"] then
				cached["appearance"]:Hide()
				-- Unparent as well as drop. Left parented it stays a child of the panel area while
				-- gone from formFrames, and the hide loops there iterate the table, never the children.
				cached["appearance"]:SetParent(nil)
				cached["appearance"] = nil
			end
			RefreshLane(laneIndex)
		end,
	}))

	local secMode = W.CreateSectionHeader(parent, L["Mode"])
	secMode:SetWidth(parent:GetWidth() - pad * 2)
	place(secMode, 18)

	place(W.CreateDropdown(parent, {
		label = L["Mode"], value = cfg.mode, options = MODE_OPTIONS, width = 200,
		tooltip = L["How a cooldown's time-left maps to its spot on the lane. Linear spaces time evenly; Timeline and Logarithmic compress long timers so near-ready cooldowns spread out; Split places icons using your own time-to-position points below."],
		onChange = function(v)
			cfg.mode = v
			-- Drop the cached Text form: the seconds axis decides which Anchor By choices exist, and that is not a value _refreshAnchors can restate.
			local cached = lanesState.formFrames[laneIndex]
			if cached and cached["text"] then
				cached["text"]:Hide()
				cached["text"]:SetParent(nil)
				cached["text"] = nil
			end
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Max Time (seconds)"], min = 10, max = 360, step = 1,
		value = cfg.maxTime, width = 240,
		onChange = function(v)
			cfg.maxTime = v
			-- Drop the cached Text form so Position (seconds) rebuilds against the new ceiling. Left
			-- alone it keeps the old max and pins the thumb while the edit box shows the real value.
			local cached = lanesState.formFrames[laneIndex]
			if cached and cached["text"] then
				cached["text"]:Hide()
				cached["text"]:SetParent(nil)
				cached["text"] = nil
			end
			RefreshLane(laneIndex)
		end,
	}))

	cfg.split = cfg.split or { count = 1, points = {} }
	if type(cfg.split.points) ~= "table" then cfg.split.points = {} end
	for i = 1, 3 do
		if type(cfg.split.points[i]) ~= "table" then
			cfg.split.points[i] = { t = 30 * i, p = 0.58 + 0.12 * i }
		end
	end

	local secSplit = W.CreateSectionHeader(parent, L["Split Points (Split mode)"])
	secSplit:SetWidth(parent:GetWidth() - pad * 2)
	place(secSplit, 18)

	place(W.CreateSlider(parent, {
		label = L["Split Points"], min = 1, max = 3, step = 1,
		value = cfg.split.count or 1, width = 240,
		onChange = function(v) cfg.split.count = v; RefreshLane(laneIndex) end,
	}))

	for i = 1, 3 do
		local pt = cfg.split.points[i]
		place(W.CreateSlider(parent, {
			label = string.format(L["Point %d Time (sec)"], i), min = 1, max = 360, step = 1,
			value = pt.t, width = 240,
			onChange = function(v) pt.t = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateSlider(parent, {
			label = string.format(L["Point %d Position (%%)"], i), min = 1, max = 99, step = 1,
			value = math.floor((pt.p or 0.5) * 100 + 0.5), width = 240,
			onChange = function(v) pt.p = v / 100; RefreshLane(laneIndex) end,
		}))
	end

	place(W.CreateCheckbox(parent, {
		label = L["Hide Long Timers"], checked = cfg.hideLongTimers,
		onChange = function(v) cfg.hideLongTimers = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Override Autohide"], checked = cfg.overrideAutohide,
		tooltip = L["Keeps this lane's background, border, and markers visible even when Auto-hide Frames is on."],
		onChange = function(v)
			cfg.overrideAutohide = v
			RefreshLane(laneIndex)
			if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
		end,
	}))

	-- On Midnight retail, Blizzard's Cooldown Manager owns secondary tracking, so hide these controls.
	if not ns.Compat.IS_RETAIL then
		local secTrack = W.CreateSectionHeader(parent, L["Secondary Tracking"])
		secTrack:SetWidth(parent:GetWidth() - pad * 2)
		place(secTrack, 18)

		place(W.CreateDropdown(parent, {
			label = L["Primary Tracking"], value = cfg.primaryTracking,
			options = TRACKING_OPTIONS, width = 200,
			tooltip = L["Fills the whole lane like a progress bar for a recurring timer. GCD follows your global cooldown; Swing follows your main-hand swing timer; None turns it off. Uses the ST color and texture below."],
			onChange = function(v) cfg.primaryTracking = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateCheckbox(parent, {
			label = L["Reverse Primary"], checked = cfg.primaryReverse,
			onChange = function(v) cfg.primaryReverse = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateDropdown(parent, {
			label = L["Secondary Tracking"], value = cfg.secondaryTracking,
			options = TRACKING_OPTIONS, width = 200,
			tooltip = L["A second tracking bar, separate from Primary Tracking. GCD or Swing; None turns it off. Its size and color are the ST (Secondary Tracking) options below."],
			onChange = function(v) cfg.secondaryTracking = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateCheckbox(parent, {
			label = L["Reverse Secondary"], checked = cfg.secondaryReverse,
			onChange = function(v) cfg.secondaryReverse = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateSlider(parent, {
			label = L["ST Width"], min = 1, max = 60, step = 1,
			value = cfg.stWidth, width = 220,
			onChange = function(v) cfg.stWidth = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateSlider(parent, {
			label = L["ST Height"], min = 1, max = 120, step = 1,
			value = cfg.stHeight, width = 220,
			tooltip = L["ST stands for Secondary Tracking. Sets the height, in pixels, of the Secondary Tracking bar set above."],
			onChange = function(v) cfg.stHeight = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateDropdown(parent, {
			label = L["ST Texture"], value = cfg.stTexture,
			options = BuildStatusbarOptions(), width = 200,
			tooltip = L["The texture that fills the Secondary Tracking bar. Any statusbar texture from LibSharedMedia is selectable."],
			onChange = function(v) cfg.stTexture = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateColorPicker(parent, {
			label = L["ST Color"], color = cfg.stColor, hasAlpha = true,
			onChange = function(r, g, b, a)
				cfg.stColor.r, cfg.stColor.g, cfg.stColor.b, cfg.stColor.a = r, g, b, a
				RefreshLane(laneIndex)
			end,
		}))
	end

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildLaneAppearanceForm(parent, laneIndex)
	local W = ns.Widgets
	local cfg = GetLaneCfg(laneIndex)
	local pad = 12
	local rowGap = 10

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	-- Use RefreshLane, not RebuildLane: WoW frames are never GC'd, so a slider calling RebuildLane leaked one lane frame (plus label/markers/icon pool) per step. Rebuild is only for `enabled`.
	place(W.CreateSlider(parent, {
		label = L["Width"], min = 1, max = 1300, step = 1,
		value = cfg.width, width = 240,
		onChange = function(v) cfg.width = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Height"], min = 1, max = 1300, step = 1,
		value = cfg.height, width = 240,
		onChange = function(v) cfg.height = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["X Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1,
		value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Y Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1,
		value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Anchor"], value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		onChange = function(v) cfg.anchor = v; RefreshLane(laneIndex) end,
	}))

	local secBG = W.CreateSectionHeader(parent, L["Lane"])
	secBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBG, 18)

	local bgTexDD = W.CreateDropdown(parent, {
		label = L["Lane Texture"], value = cfg.bgTexture,
		options = BuildStatusbarOptions(), width = 200,
		onChange = function(v) cfg.bgTexture = v; RefreshLane(laneIndex) end,
	})
	place(bgTexDD)

	place(W.CreateColorPicker(parent, {
		label = L["Lane Color"], color = cfg.bgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.bgColor.r, cfg.bgColor.g, cfg.bgColor.b, cfg.bgColor.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Use Class Color (Lane)"], checked = cfg.bgClassColor,
		onChange = function(v) cfg.bgClassColor = v; RefreshLane(laneIndex) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, L["Border"])
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Border"], checked = cfg.borderEnabled ~= false,
		onChange = function(v)
			cfg.borderEnabled = v
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Lane Alpha"], min = 0, max = 1, step = 0.05,
		value = cfg.alpha, width = 220,
		onChange = function(v) cfg.alpha = v; RefreshLane(laneIndex) end,
	}))

	local borderTexDD = W.CreateDropdown(parent, {
		label = L["Border Texture"], value = cfg.borderTexture,
		options = BuildBorderOptions(), width = 200,
		tooltip = L["The texture drawn around this lane. A soft texture like CDM Soft Edge needs room to fade, so raise Border Size to about 6 or it squashes into a smear."],
		onChange = function(v) cfg.borderTexture = v; RefreshLane(laneIndex) end,
	})
	place(borderTexDD)

	place(W.CreateColorPicker(parent, {
		label = L["Border Color"], color = cfg.borderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Padding"], min = 0, max = 40, step = 1,
		value = cfg.borderPadding, width = 220,
		onChange = function(v) cfg.borderPadding = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Size"], min = 1, max = 40, step = 1,
		value = cfg.borderSize, width = 220,
		onChange = function(v) cfg.borderSize = v; RefreshLane(laneIndex) end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local STACK_STYLE_OPTIONS = {
	{ value = "GROUPED", text = L["Grouped"] },
	{ value = "SPREAD",  text = L["Spread"]  },
	{ value = "OFFSET",  text = L["Offset"]  },
}

local GROW_DIR_H = {
	{ value = "UP",     text = L["Up"]     },
	{ value = "DOWN",   text = L["Down"]   },
	{ value = "CENTER", text = L["Center"] },
}

local GROW_DIR_V = {
	{ value = "LEFT",   text = L["Left"]   },
	{ value = "RIGHT",  text = L["Right"]  },
	{ value = "CENTER", text = L["Center"] },
}

local function BuildLaneStackingForm(parent, laneIndex)
	local W = ns.Widgets
	local cfg = GetLaneCfg(laneIndex)
	local pad = 12
	local rowGap = 10

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateCheckbox(parent, {
		label = L["Enabled"], checked = cfg.stackEnabled,
		onChange = function(v)
			cfg.stackEnabled = v
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Raise On Mouseover"], checked = cfg.stackRaiseHover,
		onChange = function(v)
			cfg.stackRaiseHover = v
			-- No refresh needed: OnEnter/OnLeave handlers are always attached.
		end,
	}))

	local secBeh = W.CreateSectionHeader(parent, L["Behavior"])
	secBeh:SetWidth(parent:GetWidth() - pad * 2)
	place(secBeh, 18)

	place(W.CreateDropdown(parent, {
		label = L["Stack Style"], value = cfg.stackStyle, options = STACK_STYLE_OPTIONS,
		width = 200,
		tooltip = L["How cooldowns that pile on the same spot are arranged. Grouped packs them into rows and overlaps them to stay within Height; Offset fans every icon evenly across Height; Spread pushes them apart along the lane so each stays visible."],
		onChange = function(v) cfg.stackStyle = v; RefreshLane(laneIndex) end,
	}))

	-- Grow Direction options are snapshotted from cfg.vertical at first build; toggling Vertical updates them only on next visit (forms build lazily per-lane per-section).
	local growOpts = cfg.vertical and GROW_DIR_V or GROW_DIR_H
	place(W.CreateDropdown(parent, {
		label = L["Grow Direction"], value = cfg.stackGrowDirection,
		options = growOpts, width = 200,
		tooltip = L["Which way a Grouped or Offset stack grows from the lane line. Center straddles the line and grows both ways."],
		onChange = function(v) cfg.stackGrowDirection = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Height"], min = 0, max = 300, step = 5,
		value = cfg.stackHeight, width = 240,
		tooltip = L["How much room across the lane the stack may use. When the icons do not all fit, they overlap to stay within it, so raise Height to reduce overlap."],
		onChange = function(v) cfg.stackHeight = v; RefreshLane(laneIndex) end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildLaneIconsForm(parent, laneIndex)
	local W = ns.Widgets
	local cfg = GetLaneCfg(laneIndex)
	local pad = 12
	local rowGap = 10

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateSlider(parent, {
		label = L["Size"], min = 1, max = 128, step = 1,
		value = cfg.iconSize, width = 240,
		onChange = function(v) cfg.iconSize = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Transparency"], min = 0, max = 1, step = 0.05,
		value = cfg.iconAlpha, width = 240,
		onChange = function(v) cfg.iconAlpha = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Icon Offset"], min = -30, max = 30, step = 1,
		value = cfg.iconOffset, width = 240,
		onChange = function(v) cfg.iconOffset = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Cooldown Tint (0 = off)"], min = 0, max = 1, step = 0.05,
		value = cfg.swipeAlpha, width = 240,
		onChange = function(v) cfg.swipeAlpha = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = L["Pulse"], checked = cfg.iconPulse,
		tooltip = L["Makes an icon breathe in and out as it travels, so a lane you care about is easier to catch out of the corner of your eye. Masque skins draw their own icon, so the pulse stands down while one is active."],
		onChange = function(v) cfg.iconPulse = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Pulse Within (sec)"], min = 0, max = 60, step = 1,
		value = cfg.iconPulseWithin, width = 240,
		tooltip = L["Start pulsing only once a cooldown is this close to ready. Set it to 0 to pulse the whole way along the lane."],
		onChange = function(v) cfg.iconPulseWithin = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Pulse Strength"], min = 1, max = 20, step = 1,
		value = cfg.iconPulseSize, width = 240,
		tooltip = L["How many pixels the icon grows at the peak of each pulse."],
		onChange = function(v) cfg.iconPulseSize = v; RefreshLane(laneIndex) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, L["Icon Border"])
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Icon Border"],
		checked = cfg.iconBorder,
		tooltip = L["Draw a clean solid border around every cooldown icon in this lane. Set per lane, so you can border one lane and leave another plain. On by default."],
		onChange = function(v) cfg.iconBorder = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Border Size"], min = 1, max = 6, step = 1,
		value = cfg.iconBorderSize or 1, width = 240,
		onChange = function(v) cfg.iconBorderSize = v; RefreshLane(laneIndex) end,
	}))

	if type(cfg.iconBorderColor) ~= "table" then
		cfg.iconBorderColor = { r = 0, g = 0, b = 0, a = 1 }
	end
	place(W.CreateColorPicker(parent, {
		label = L["Border Color"], color = cfg.iconBorderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.iconBorderColor
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	cfg.highlight = cfg.highlight or { style = "NONE", color = { r = 1, g = 0.82, b = 0, a = 0.6 } }
	if type(cfg.highlight.color) ~= "table" then
		cfg.highlight.color = { r = 1, g = 0.82, b = 0, a = 0.6 }
	end
	local secHL = W.CreateSectionHeader(parent, L["Highlight (Important spells)"])
	secHL:SetWidth(parent:GetWidth() - pad * 2)
	place(secHL, 18)

	place(W.CreateDropdown(parent, {
		label = L["Highlight Style"], value = cfg.highlight.style or "NONE",
		options = HL_STYLE_OPTIONS, width = 200,
		tooltip = L["Visual emphasis drawn on icons flagged Important (per spell, in Filters). Border outlines the icon; Glow and Flash pulse it; Border + Flash does both; None disables it."],
		onChange = function(v) cfg.highlight.style = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateColorPicker(parent, {
		label = L["Highlight Color"], color = cfg.highlight.color, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.highlight.color
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	local secTxt = W.CreateSectionHeader(parent, L["Countdown Timer"])
	secTxt:SetWidth(parent:GetWidth() - pad * 2)
	place(secTxt, 18)

	-- Keep the iconText[2] key. The other slots were removed, but the lane still reads that index.
	place(W.CreateCheckbox(parent, {
		label = L["Show Timer"],
		checked = cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled or false,
		tooltip = L["Show the remaining-time number on each cooldown icon in this lane (for example 1:16, then 45, 44...). Style it with the Timer Font options below."],
		onChange = function(v)
			if cfg.iconText and cfg.iconText[2] then
				cfg.iconText[2].enabled = v
			end
			RefreshLane(laneIndex)
		end,
	}))

	local secFont = W.CreateSectionHeader(parent, L["Timer Font"])
	secFont:SetWidth(parent:GetWidth() - pad * 2)
	place(secFont, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.iconFont, options = BuildFontOptions(), width = 240,
		onChange = function(v) cfg.iconFont = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Font Size (0 = auto)"], min = 0, max = 64, step = 1,
		value = cfg.iconFontSize, width = 240,
		onChange = function(v) cfg.iconFontSize = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.iconFontFlags, options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.iconFontFlags = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.iconFontColor,
		onChange = function(r, g, b, a)
			local c = cfg.iconFontColor
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	local secLbl = W.CreateSectionHeader(parent, L["Icon Label"])
	secLbl:SetWidth(parent:GetWidth() - pad * 2)
	place(secLbl, 18)

	cfg.iconLabel = cfg.iconLabel or { enabled = false, text = "[cd.name]", anchor = "BOTTOM" }

	place(W.CreateCheckbox(parent, {
		label = L["Show Label"],
		checked = cfg.iconLabel.enabled,
		tooltip = L["Draw a line of text on each cooldown icon in this lane, built from the tags in Label Text below. Off by default - lanes otherwise show only the timer number, so this is how you put the ability name on the icon."],
		onChange = function(v) cfg.iconLabel.enabled = v; RefreshLane(laneIndex) end,
	}))

	BuildTagTextRow(parent, place, cfg.iconLabel, function() RefreshLane(laneIndex) end, L["Label Text"], ns.TAG_PICKER_COOLDOWN)

	place(W.CreateDropdown(parent, {
		label = L["Label Position"], value = cfg.iconLabel.anchor or "BOTTOM",
		options = ICON_LABEL_ANCHOR_OPTIONS, width = 240,
		tooltip = L["Where the label sits on the icon. On icon overlaps the timer number."],
		onChange = function(v) cfg.iconLabel.anchor = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Label Font"], value = cfg.iconLabelFont, options = BuildFontOptions(), width = 240,
		onChange = function(v) cfg.iconLabelFont = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Label Size"], min = 6, max = 32, step = 1, value = cfg.iconLabelSize or 10, width = 240,
		onChange = function(v) cfg.iconLabelSize = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Label Outline"], value = cfg.iconLabelFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.iconLabelFlags = v; RefreshLane(laneIndex) end,
	}))

	cfg.iconLabelColor = cfg.iconLabelColor or { r = 1, g = 1, b = 1, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Label Color"], color = cfg.iconLabelColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.iconLabelColor
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildLaneTextForm(parent, laneIndex)
	local W = ns.Widgets
	local cfg = GetLaneCfg(laneIndex)
	local pad = 12
	local rowGap = 10

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	if W.CreateSectionHeader then
		local secDef = W.CreateSectionHeader(parent, L["Default Text"])
		secDef:SetWidth(parent:GetWidth() - pad * 2)
		place(secDef, 18)
	end

	place(W.CreateDropdown(parent, {
		label = L["Label Placement"], value = cfg.laneTextAnchor or "CENTER",
		options = LANE_TEXT_ANCHOR_OPTIONS, width = 240,
		tooltip = L["Where the labels sit relative to the lane bar. Move them off the bar when tall icons cover them. On a vertical lane, Above places them to the right of it and Below to the left."],
		onChange = function(v) cfg.laneTextAnchor = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["X Offset"], min = -100, max = 100, step = 1,
		value = cfg.laneTextOffX or 0, width = 240,
		tooltip = L["Nudges every label sideways from its placement."],
		onChange = function(v) cfg.laneTextOffX = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Y Offset"], min = -100, max = 100, step = 1,
		value = cfg.laneTextOffY or 0, width = 240,
		tooltip = L["Nudges every label up or down from its placement."],
		onChange = function(v) cfg.laneTextOffY = v; RefreshLane(laneIndex) end,
	}))

	local timeAxis = (ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(cfg, 0)) ~= nil

	local anchorRows = {}
	for i = 1, 5 do
		local def = cfg.laneText and cfg.laneText[i]
		if def then
			place(W.CreateCheckbox(parent, {
				label = string.format(L["Label %d enabled"], i), checked = def.enabled,
				onChange = function(v)
					cfg.laneText[i].enabled = v
					RefreshLane(laneIndex)
				end,
			}))
			-- Display only: findOptionLabel falls back to tostring, so a saved TIME_AUTO left off the list would draw as the raw enum.
			local anchorMode = def.anchorMode or "PERCENT"
			if not timeAxis then anchorMode = MARKER_ANCHOR_AS_PERCENT[anchorMode] or anchorMode end
			place(W.CreateDropdown(parent, {
				label = L["Anchor By"], value = anchorMode,
				options = timeAxis and MARKER_ANCHOR_MODE_OPTIONS or MARKER_ANCHOR_MODE_OPTIONS_PERCENT,
				width = 240,
				tooltip = L["Percent holds the label at a fixed spot on the bar. Time holds it at a number of seconds and moves the label to match. The auto label choices write the text for you from the lane's current Mode and Max Time, so the label stays true after you change either one - seconds on Timeline, Logarithmic and Split, and a percent on Linear, which has no shared clock to read."],
				onChange = function(v)
					local d = cfg.laneText[i]
					-- Re-picking the entry already on show is a no-op, not a demotion of the time mode it stands in for.
					if not timeAxis and v == MARKER_ANCHOR_AS_PERCENT[d.anchorMode] then return end
					d.anchorMode = v
					RefreshLane(laneIndex)
				end,
			}))
			place(W.CreateEditBox(parent, {
				label = L["Text"], value = def.text or "", width = 200, maxLetters = 24,
				tooltip = L["What the label reads. The auto label choices ignore this and write the text themselves."],
				onChange = function(text)
					cfg.laneText[i].text = text
					RefreshLane(laneIndex)
				end,
			}))
			-- Both sliders write both fields. Anchor By only picks which one survives a Mode change.
			local pctSlider, secSlider
			pctSlider = place(W.CreateSlider(parent, {
				label = L["Position (percent)"], min = 0, max = 100, step = 1,
				value = math.floor((def.pos or 0) * 100 + 0.5), width = 240,
				tooltip = L["Where the label sits, as a percent along the lane. Moving this also updates Position (seconds) to match."],
				onChange = function(v)
					local d = cfg.laneText[i]
					d.pos = v / 100
					local t = ns.Lanes_PosToTime and ns.Lanes_PosToTime(cfg, d.pos)
					if t then
						-- Stored unrounded: on a LOG lane the first several percent all round to zero
						-- seconds, which would freeze the label at the ready end.
						d.t = t
						if secSlider then secSlider:SetValue(math.floor(t + 0.5)) end
					end
					RefreshLane(laneIndex)
				end,
			}))
			secSlider = place(W.CreateSlider(parent, {
				-- The lane's own Max Time, not the 360 ceiling: onChange clamps here anyway, so a wider
				-- slider just advertises a range it will silently refuse.
				label = L["Position (seconds)"], min = 0, max = cfg.maxTime or 120, step = 1,
				value = def.t or 0, width = 240,
				tooltip = L["Where the label sits, as seconds left on a cooldown. Moving this also updates Position (percent) to match. Linear has no seconds axis, so this does nothing there."],
				onChange = function(v)
					local d = cfg.laneText[i]
					-- Past Max Time the lane saturates, so every higher value would look identical.
					local maxT = cfg.maxTime or 120
					if v > maxT then
						v = maxT
						if secSlider then secSlider:SetValue(v) end
					end
					local p = ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(cfg, v)
					if p then
						d.t   = v
						d.pos = p
						if pctSlider then pctSlider:SetValue(math.floor(p * 100 + 0.5)) end
					end
					RefreshLane(laneIndex)
				end,
			}))
			secSlider:SetEnabled(timeAxis)
			anchorRows[i] = { pct = pctSlider, sec = secSlider }
		end
	end

	-- Section surfaces are cached, so a Mode change made on another page leaves these sliders stale.
	parent._refreshAnchors = function()
		for idx, row in pairs(anchorRows) do
			local d = cfg.laneText and cfg.laneText[idx]
			if d then
				if d.anchorMode == "TIME" or d.anchorMode == "TIME_AUTO" then
					local pp = ns.Lanes_TimeToPos and ns.Lanes_TimeToPos(cfg, d.t or 0)
					if pp then d.pos = pp end
				else
					local tt = ns.Lanes_PosToTime and ns.Lanes_PosToTime(cfg, d.pos or 0)
					if tt then d.t = tt end
				end
				row.pct:SetValue(math.floor((d.pos or 0) * 100 + 0.5))
				-- Clamp the DISPLAY only. Writing it back would flatten every marker's seconds
				-- the moment Max Time was lowered, and that is not something the user can undo.
				row.sec:SetValue(math.floor(math.min(d.t or 0, cfg.maxTime or 120) + 0.5))
			end
		end
	end

	local secMarker = W.CreateSectionHeader(parent, L["Marker Font"])
	secMarker:SetWidth(parent:GetWidth() - pad * 2)
	place(secMarker, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.laneTextFont, options = BuildFontOptions(), width = 240,
		tooltip = L["Font for the position markers along this lane (Ready, 25, 50, 75, 100 percent)."],
		onChange = function(v) cfg.laneTextFont = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.laneTextSize or 9, width = 240,
		onChange = function(v) cfg.laneTextSize = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.laneTextFlags or "NONE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.laneTextFlags = v; RefreshLane(laneIndex) end,
	}))
	cfg.laneTextColor = cfg.laneTextColor or { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.laneTextColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.laneTextColor
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	local secLabel = W.CreateSectionHeader(parent, L["Name Tag Font"])
	secLabel:SetWidth(parent:GetWidth() - pad * 2)
	place(secLabel, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.labelFont, options = BuildFontOptions(), width = 240,
		tooltip = L["Font for this lane's name tag (shown above the bar while frames are unlocked)."],
		onChange = function(v) cfg.labelFont = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.labelSize or 12, width = 240,
		onChange = function(v) cfg.labelSize = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.labelFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.labelFlags = v; RefreshLane(laneIndex) end,
	}))
	cfg.labelColor = cfg.labelColor or { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.labelColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.labelColor
			c.r, c.g, c.b, c.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))

	BuildStatusLineSection(parent, place, pad, cfg, function() RefreshLane(laneIndex) end)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildLaneFormSurface(panelArea, laneIndex, sectionID)
	local scroll = CreateFrame("ScrollFrame", nil, panelArea, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panelArea, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", panelArea, "BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(panelArea:GetWidth() - 26, 1)
	scroll:SetScrollChild(child)

	-- A ScrollFrame is created SHOWN, so a builder that throws leaves this one visible AND
	-- unreturned, which strands it over every later section until a reload. Contain the throw.
	local ok, err = pcall(function()
		if sectionID == "general" then
			BuildLaneGeneralForm(child, laneIndex)
		elseif sectionID == "appearance" then
			BuildLaneAppearanceForm(child, laneIndex)
		elseif sectionID == "stacking" then
			BuildLaneStackingForm(child, laneIndex)
		elseif sectionID == "icons" then
			BuildLaneIconsForm(child, laneIndex)
		elseif sectionID == "text" then
			BuildLaneTextForm(child, laneIndex)
		end
	end)
	if not ok and _G.CooldownMaster then
		_G.CooldownMaster:Print(string.format("|cffff4040lane form error (lane %s / %s):|r %s",
			tostring(laneIndex), tostring(sectionID), tostring(err)))
	end

	scroll:Hide()
	return scroll
end


local function ShowLaneSection(panelArea, laneIndex, sectionID)
	lanesState.formFrames[laneIndex] = lanesState.formFrames[laneIndex] or {}
	for _, surf in pairs(lanesState.formFrames[laneIndex]) do
		surf:Hide()
	end
	for li, sections in pairs(lanesState.formFrames) do
		if li ~= laneIndex then
			for _, surf in pairs(sections) do surf:Hide() end
		end
	end

	local surf = lanesState.formFrames[laneIndex][sectionID]
	if not surf then
		surf = BuildLaneFormSurface(panelArea, laneIndex, sectionID)
		lanesState.formFrames[laneIndex][sectionID] = surf
	end
	for _, kid in ipairs({ panelArea:GetChildren() }) do
		if kid ~= surf and kid.GetScrollChild then kid:Hide() end
	end
	surf:Show()
	local formChild = surf.GetScrollChild and surf:GetScrollChild()
	if formChild and formChild._refreshAnchors then formChild._refreshAnchors() end

	lanesState.laneIndex = laneIndex
	lanesState.sectionID = sectionID

	for _, row in ipairs(lanesState.railRows) do
		local active = row._sectionID == sectionID
		row.text:SetTextColor(
			active and YELLOW.r or 1,
			active and YELLOW.g or 1,
			active and YELLOW.b or 1,
			1)
	end

	for li, btn in ipairs(lanesState.subTabBtns) do
		btn:SetSelected(li == laneIndex)
	end
end


YELLOW = ns.CONST.RGB.YELLOW

local function BuildLanesTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	local subBar = CreateFrame("Frame", nil, content)
	subBar:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)
	subBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, -pad)
	subBar:SetHeight(Theme.PANEL.TAB_H)

	wipe(lanesState.subTabBtns)
	local x = 0
	for i = 1, 3 do
		local b = Theme.CreateTab(subBar, string.format(L["Lane %d"], i), 90)
		b:SetPoint("TOPLEFT", subBar, "TOPLEFT", x, 0)
		lanesState.subTabBtns[i] = b
		x = x + 90 + Theme.PANEL.TAB_GAP
	end

	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	local rail = CreateFrame("Frame", nil, body,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
	rail:SetWidth(LANES_INNER_RAIL_W)
	Theme.ApplyBackdrop(rail,
		{ r = 0, g = 0, b = 0, a = 0.4 }, ns.CONST.RGB.PANEL_BORDER)

	local formArea = CreateFrame("Frame", nil, body)
	formArea:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
	formArea:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

	for i, b in ipairs(lanesState.subTabBtns) do
		b:SetScript("OnClick", function()
			ShowLaneSection(formArea, i, lanesState.sectionID)
		end)
	end

	wipe(lanesState.railRows)
	local ry = -8
	for _, sec in ipairs(LANES_SECTION_LIST) do
		local row = CreateFrame("Button", nil, rail)
		row:SetPoint("TOPLEFT",  rail, "TOPLEFT",  6, ry)
		row:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -6, ry)
		row:SetHeight(22)
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("LEFT", row, "LEFT", 4, 0)
		fs:SetText(sec.label)
		row.text = fs
		row._sectionID = sec.id

		fs:SetTextColor(1, 1, 1)
		row:EnableMouse(true)
		row:SetScript("OnClick", function()
			ShowLaneSection(formArea, lanesState.laneIndex, sec.id)
		end)
		row:SetScript("OnEnter", function()
			if sec.id ~= lanesState.sectionID then
				fs:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
			end
		end)
		row:SetScript("OnLeave", function()
			if sec.id ~= lanesState.sectionID then
				fs:SetTextColor(1, 1, 1)
			end
		end)

		lanesState.railRows[#lanesState.railRows + 1] = row
		ry = ry - 26
	end

	ShowLaneSection(formArea, lanesState.laneIndex, lanesState.sectionID)
	-- Frame Scale drops cached Appearance forms while this tab is hidden, and showing a cached tab
	-- re-creates nothing, so without this the pane comes back empty with its rail row still lit.
	content._reseed = function()
		local sections = lanesState.formFrames[lanesState.laneIndex]
		if not (sections and sections[lanesState.sectionID]) then
			ShowLaneSection(formArea, lanesState.laneIndex, lanesState.sectionID)
		end
	end
end

for _, def in ipairs(TABS) do
	if def.id == "lanes" then def.builder = BuildLanesTab end
end


local FILTERS_INNER_RAIL_W = 160

local filtersState = {
	selectedSubTab          = "defaults",
	selectedDefaultsKey     = "spells",
	formFrames              = {},
	railRows                = {},
	enabledSensitive        = {},
	enabledChecks           = {},
}

local function GetFilterCfg(key)
	return ns.CDM.db.profile.filters[key]
end


-- Deferred a frame - the checkbox whose callback fires this sits on the surface being torn down.
local function RefreshFilterListForm(key)
	C_Timer.After(0, function()
		-- A needless rebuild orphans a full row tree, which WoW never GCs, to redraw the same pixels.
		if filtersState.enabledSensitive[key] then
			local surf = filtersState.formFrames[key]
			if surf then
				surf:Hide()
				filtersState.formFrames[key] = nil
			end
		end

		-- The Defaults surface has its own checkbox for this flag and nothing else invalidates it.
		local defaults = filtersState.formFrames["defaults"]
		if defaults and key == filtersState.selectedDefaultsKey then
			defaults:Hide()
			filtersState.formFrames["defaults"] = nil
		end

		-- A surface kept above still holds a checkbox seeded from the old value, so re-seed it in place.
		local cfg = GetFilterCfg(key)
		local check = filtersState.enabledChecks[key]
		if cfg and check and filtersState.formFrames[key] then
			check:SetValue(cfg.enabled)
		end

		local shown = filtersState.selectedSubTab
		if filtersState._refresh and (shown == key or shown == "defaults") then
			filtersState._refresh()
		end
	end)
end

-- Read-only: returns the stored override or nil. Merely viewing a spell must NOT persist an
-- empty {} into spellOverrides (a SavedVariable). Materialization is deferred to SetSpellOverride.
local function GetSpellOverride(spellID)
	local so = ns.CDM.db.profile.spellOverrides
	return so and so[spellID]
end

-- Pruned back to nil once it holds nothing, so choosing "Default" everywhere leaves no empty table behind.
local function SetSpellOverride(spellID, field, value)
	local p = ns.CDM.db.profile
	if value == nil then
		local so = p.spellOverrides
		local ov = so and so[spellID]
		if not ov then return end
		ov[field] = nil
		if next(ov) == nil then so[spellID] = nil end
		return
	end
	p.spellOverrides = p.spellOverrides or {}
	local ov = p.spellOverrides[spellID]
	if not ov then ov = {}; p.spellOverrides[spellID] = ov end
	ov[field] = value
end

local function CustomStore()
	local p = ns.CDM.db.profile
	p.customCooldowns = p.customCooldowns or { nextId = 1, defs = {} }
	p.customCooldowns.defs = p.customCooldowns.defs or {}
	return p.customCooldowns
end

local categoryScratch = {}
local EMPTY_TABLE = {}

local function CollectCategoryIDs(categoryKey)
	wipe(categoryScratch)
	if categoryKey == "custom" then
		for id in pairs(CustomStore().defs) do
			categoryScratch[#categoryScratch + 1] = id
		end
		return categoryScratch
	end
	local engine = ns.Engine
	if not engine then return categoryScratch end
	for spellID, info in pairs(engine.trackedSpells or EMPTY_TABLE) do
		if engine:GetCategoryFilterKey(info.category) == categoryKey then
			categoryScratch[#categoryScratch + 1] = spellID
		end
	end
	for itemID, info in pairs(engine.trackedItems or EMPTY_TABLE) do
		if engine:GetCategoryFilterKey(info.category) == categoryKey then
			categoryScratch[#categoryScratch + 1] = itemID
		end
	end
	for spellID, info in pairs(engine.trackedOffensives or EMPTY_TABLE) do
		if engine:GetCategoryFilterKey(info.category) == categoryKey then
			categoryScratch[#categoryScratch + 1] = spellID
		end
	end
	return categoryScratch
end

-- Clear the override rather than stamp the default onto each spell - that keeps the category
-- default live for later changes and stops spellOverrides growing a row per tracked spell.
local function ClearOverrideField(categoryKey, field)
	local ids = CollectCategoryIDs(categoryKey)
	for i = 1, #ids do
		SetSpellOverride(ids[i], field, nil)
	end
	if ns.Engine then ns.Engine:ReapplyRouting() end
	if ns.Options_InvalidateFilterLists then ns.Options_InvalidateFilterLists() end
end

local setAllState = {}

StaticPopupDialogs["COOLDOWNMASTER_FILTERS_SET_ALL"] = {
	text = L["Set every cooldown in %s to follow the category default for %s? Any per-spell choice for that setting is cleared."],
	button1 = YES,
	button2 = NO,
	OnAccept = function() ClearOverrideField(setAllState.key, setAllState.field) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}


local function AddSetAll(parent, dd, key, field, fieldLabel, categoryLabel, tooltip)
	local btn = ns.Widgets.CreateButton(parent, {
		label = L["Set All"], width = 70, tooltip = tooltip,
		onClick = function()
			setAllState.key, setAllState.field = key, field
			StaticPopup_Show("COOLDOWNMASTER_FILTERS_SET_ALL", categoryLabel, fieldLabel, setAllState)
		end,
	})
	btn:SetPoint("LEFT", dd, "RIGHT", 8, -5)
	return btn
end

local FILTER_LANE_OPTIONS = {
	{ value = 0, text = L["Default"] },  -- 0 = nil sentinel, stored as nil
	{ value = 1, text = L["Lane 1"]  },
	{ value = 2, text = L["Lane 2"]  },
	{ value = 3, text = L["Lane 3"]  },
}

local FILTER_LANE_FOR_DEFAULTS = {
	{ value = 1, text = L["Lane 1"] },
	{ value = 2, text = L["Lane 2"] },
	{ value = 3, text = L["Lane 3"] },
}

-- Mutate the option tables in place - every dropdown already built holds them by reference.
local function RefreshLaneOptionLabels()
	local lanes = ns.CDM and ns.CDM.db and ns.CDM.db.profile.lanes
	for i = 1, 3 do
		local cfg = lanes and lanes[i]
		local text = (cfg and cfg.enabled == false)
			and string.format(L["Lane %d (off)"], i) or string.format(L["Lane %d"], i)
		FILTER_LANE_OPTIONS[i + 1].text = text
		FILTER_LANE_FOR_DEFAULTS[i].text = text
	end
end

ns.Options_RefreshLaneLabels = RefreshLaneOptionLabels

local FILTER_READYBOX_FOR_DEFAULTS = {
	{ value = 0, text = L["Off"]   },
	{ value = 1, text = L["Box 1"] },
	{ value = 2, text = L["Box 2"] },
	{ value = 3, text = L["Box 3"] },
}

local FILTER_BAR_FOR_DEFAULTS = {
	{ value = 0, text = L["Off"]    },
	{ value = 1, text = L["Bars 1"] },
	{ value = 2, text = L["Bars 2"] },
	{ value = 3, text = L["Bars 3"] },
}

local FILTER_READYBOX_OPTIONS = {
	{ value = -1, text = L["Default"] },  -- -1 = nil sentinel, stored as nil
	{ value = 0,  text = L["Off"]     },
	{ value = 1,  text = L["Box 1"]   },
	{ value = 2,  text = L["Box 2"]   },
	{ value = 3,  text = L["Box 3"]   },
}

local FILTER_BAR_OPTIONS = {
	{ value = -1, text = L["Default"] },  -- -1 = nil sentinel, stored as nil
	{ value = 0,  text = L["Off"]     },
	{ value = 1,  text = L["Bars 1"]  },
	{ value = 2,  text = L["Bars 2"]  },
	{ value = 3,  text = L["Bars 3"]  },
}

-- Per-spell ready treatment, packed as bits: bit0 = important (highlight), bit1 = pinned.
local FILTER_READYFLAG_OPTIONS = {
	{ value = 0, text = L["Normal"]    },
	{ value = 1, text = L["Important"] },
	{ value = 2, text = L["Pinned"]    },
	{ value = 3, text = L["Imp + Pin"] },
}

local function BuildDefaultsCategoryDropdownOptions()
	local opts = {}
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		opts[#opts + 1] = { value = def.key, text = def.label }
	end
	return opts
end


local function BuildFiltersDefaultsForm(parent)
	local W = ns.Widgets
	local pad = 12
	local rowGap = 10

	RefreshLaneOptionLabels()

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local band = ns.CDM.db.profile.laneByDuration
	local function BandChanged()
		if ns.Engine then ns.Engine:ReapplyRouting() end
	end

	local secBand = W.CreateSectionHeader(parent, L["Route by Cooldown Length"])
	secBand:SetWidth(parent:GetWidth() - pad * 2)
	place(secBand, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Sort cooldowns into lanes by length"], checked = band.enabled,
		tooltip = L["Sends a cooldown to a lane based on how long it is rather than what kind it is, so short cooldowns can run a fast lane and long ones a slow lane. A lane you picked for an individual spell still wins over this, and anything whose length CooldownMaster has not learned yet falls back to the category defaults below."],
		onChange = function(v) band.enabled = v; BandChanged() end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Short Up To (sec)"], min = 5, max = 300, step = 1,
		value = band.shortMax, width = 240,
		tooltip = L["A cooldown this long or shorter counts as short."],
		onChange = function(v) band.shortMax = v; BandChanged() end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Short Lane"], value = band.shortLane or 1,
		options = FILTER_LANE_FOR_DEFAULTS, width = 200,
		onChange = function(v) band.shortLane = v; BandChanged() end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Medium Up To (sec)"], min = 5, max = 600, step = 1,
		value = band.midMax, width = 240,
		tooltip = L["A cooldown longer than Short Up To but no longer than this counts as medium. Anything above it is long."],
		onChange = function(v) band.midMax = v; BandChanged() end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Medium Lane"], value = band.midLane or 2,
		options = FILTER_LANE_FOR_DEFAULTS, width = 200,
		onChange = function(v) band.midLane = v; BandChanged() end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Long Lane"], value = band.longLane or 3,
		options = FILTER_LANE_FOR_DEFAULTS, width = 200,
		onChange = function(v) band.longLane = v; BandChanged() end,
	}))

	local secCat = W.CreateSectionHeader(parent, L["Category Defaults"])
	secCat:SetWidth(parent:GetWidth() - pad * 2)
	place(secCat, 18)

	local pickerLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pickerLabel:SetText(L["Pick a category to edit its defaults:"])
	pickerLabel:SetTextColor(1, 1, 1)
	place(pickerLabel, 16)
	W.AttachLabelTip(parent, pickerLabel, {
		label   = L["Pick a category to edit its defaults:"],
		tooltip = L["These settings apply to every spell in the chosen category. To override an individual spell, use that category's sub-tab on the left."],
	})

	local categoryDropdown = W.CreateDropdown(parent, {
		label = "", value = filtersState.selectedDefaultsKey,
		options = BuildDefaultsCategoryDropdownOptions(),
		width = 200,
		onChange = function(v)
			filtersState.selectedDefaultsKey = v
			if filtersState.formFrames["defaults"] then
				filtersState.formFrames["defaults"]:Hide()
				filtersState.formFrames["defaults"] = nil
			end
			if filtersState._refresh then filtersState._refresh() end
		end,
	})
	place(categoryDropdown)

	y = y - 4

	local key = filtersState.selectedDefaultsKey
	local cfg = GetFilterCfg(key)
	if not cfg then
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetText(string.format(L["Unknown category: %s"], tostring(key)))
		fs:SetTextColor(0.7, 0.4, 0.4)
		place(fs, 16)
		parent:SetHeight(math.abs(y) + pad)
		return
	end

	local label = key
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		if def.key == key then label = def.label; break end
	end

	local sec = W.CreateSectionHeader(parent, string.format(L["%s Defaults"], label))
	sec:SetWidth(parent:GetWidth() - pad * 2)
	place(sec, 18)

	place(W.CreateCheckbox(parent, {
		label   = L["Enabled"],
		checked = cfg.enabled,
		tooltip = L["Untick to stop tracking this whole category. None of its cooldowns will show on a lane or pop a ready frame."],
		onChange = function(v)
			cfg.enabled = v
			RefreshFilterListForm(key)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label   = L["Show by Default"],
		checked = cfg.showByDefault,
		tooltip = L["On: spells in this category show unless you hide one individually. Off: spells stay hidden until you enable each one."],
		onChange = function(v) cfg.showByDefault = v end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Ignore Threshold (sec)"], min = 60, max = 3600, step = 5,
		value = cfg.ignoreThreshold or 1800, width = 240,
		tooltip = L["Stop tracking any cooldown in this category whose full length is longer than this many seconds. Use it to hide very long cooldowns (like 30+ minute abilities) so they never show on a lane or pop ready. A spell you explicitly enable in the list below still shows. Unlike a lane's Max Time, this filters by the ability's total cooldown, not how much of the timeline is drawn."],
		onChange = function(v) cfg.ignoreThreshold = v end,
	}))

	local laneDD = W.CreateDropdown(parent, {
		label = L["Default Lane"],
		value = cfg.defaultLane or 1,
		options = FILTER_LANE_FOR_DEFAULTS,
		width = 200,
		tooltip = L["Which lane this category's cooldowns travel along. The chosen lane must also be enabled on the Lanes tab - one marked (off) draws nothing."],
		onChange = function(v)
			cfg.defaultLane = v
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	place(laneDD)
	AddSetAll(parent, laneDD, key, "lane", L["Lane"], label,
		L["Makes every cooldown in this category follow the Default Lane above. Any per-spell Lane you picked in the category's list is cleared. Show, Bar, Ready Box, Important and Pinned choices are left alone."])

	local readyDD = W.CreateDropdown(parent, {
		label = L["Ready Box"],
		value = cfg.readyBox or 0,
		options = FILTER_READYBOX_FOR_DEFAULTS,
		width = 200,
		onChange = function(v) cfg.readyBox = v end,
	})
	place(readyDD)
	AddSetAll(parent, readyDD, key, "readyBox", L["Ready Box"], label,
		L["Makes every cooldown in this category follow the Ready Box above. Any per-spell Ready Box you picked in the category's list is cleared. Show, Lane, Bar, Important and Pinned choices are left alone."])

	local barDD = W.CreateDropdown(parent, {
		label = L["Default Bar"],
		value = cfg.defaultBar or 0,
		options = FILTER_BAR_FOR_DEFAULTS,
		width = 200,
		tooltip = L["Which bar frame this category's cooldowns appear in. The chosen Bars frame must also be enabled on the Bars tab. Off shows no bar."],
		onChange = function(v)
			cfg.defaultBar = v
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	place(barDD)
	AddSetAll(parent, barDD, key, "bar", L["Bar"], label,
		L["Makes every cooldown in this category follow the Default Bar above. Any per-spell Bar you picked in the category's list is cleared. Show, Lane, Ready Box, Important and Pinned choices are left alone."])

	parent:SetHeight(math.abs(y) + pad)
end


function ns.Options_UpdateTrackedItemDisplay(itemID, displayName, displayIcon)
	if not (filtersState.itemRows and filtersState.itemRows[itemID]) then return end
	local r = filtersState.itemRows[itemID]
	if displayName and r.name then r.name:SetText(displayName) end
	if displayIcon and r.icon then r.icon:SetTexture(displayIcon) end
end


local function DropFilterListSurfaces()
	for key, surf in pairs(filtersState.formFrames) do
		if key ~= "defaults" then
			surf:Hide()
			filtersState.formFrames[key] = nil
		end
	end
	if filtersState.itemRows then wipe(filtersState.itemRows) end
end


-- Drop cached per-category list surfaces after Engine rebuilds the spell/item registries - without
-- this each list is a one-time snapshot (stale after a spec swap, "No spells discovered yet" sticking
-- forever). Defaults stays cached, it only reflects saved settings.
function ns.Options_InvalidateFilterLists()
	-- Dropping orphans the old surface's frames (WoW never GCs them), and bag loot fires this every
	-- couple of seconds. Mark it stale instead - ShowFiltersSubTab drops once on the next view.
	if not (panel and panel:IsShown()) then
		filtersState._listsStale = true
		return
	end
	DropFilterListSurfaces()
	if filtersState._refresh then filtersState._refresh() end
end


-- These rows build their dropdowns label-less, and the factory hangs its tooltip off the label, so a
-- tooltip passed in the config would never be hoverable. The box binds only OnClick, so hook it here.
local function AttachRowTip(frame, title, text)
	if not frame then return end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end


local function BuildSpellRow(parent, spellID, info, yPos)
	local W = ns.Widgets
	local rowH = 26

	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(parent:GetWidth() - 24, rowH)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yPos)

	local tex = row:CreateTexture(nil, "ARTWORK")
	tex:SetSize(20, 20)
	tex:SetPoint("LEFT", row, "LEFT", 0, 0)
	if info.icon then tex:SetTexture(info.icon) end
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetPoint("LEFT", tex, "RIGHT", 8, 0)
	name:SetWidth(180)
	name:SetJustifyH("LEFT")
	name:SetText(info.name or string.format(L["Spell %d"], spellID))
	name:SetTextColor(1, 1, 1)

	-- Item rows key on the itemID, so spellID IS the itemID there. A custom's synthetic id is no real spell.
	local idHit = CreateFrame("Frame", nil, row)
	idHit:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0)
	idHit:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 0, 0)
	idHit:EnableMouse(true)
	idHit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if info.kind == "item" then
			if info.link then GameTooltip:SetHyperlink(info.link) else GameTooltip:SetItemByID(spellID) end
		elseif info.buffSpellID then
			GameTooltip:SetSpellByID(info.buffSpellID)
		elseif spellID >= ns.CONST.CUSTOM_ID_BASE then
			GameTooltip:SetText(info.name or L["Cooldown"], 1, 1, 1)
			GameTooltip:AddLine(L["Custom cooldown"], 0.6, 0.6, 0.6)
		else
			GameTooltip:SetSpellByID(spellID)
		end
		GameTooltip:Show()
	end)
	idHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local override = GetSpellOverride(spellID)
	local categoryKey = ns.Engine and ns.Engine:GetCategoryFilterKey(info.category)
	local fcfg = categoryKey and GetFilterCfg(categoryKey)
	local effectiveVisible
	if override and override.visible ~= nil then
		effectiveVisible = override.visible
	else
		effectiveVisible = fcfg and fcfg.showByDefault ~= false
	end

	local cb = W.CreateCheckbox(row, {
		label = L["Show"],
		checked = effectiveVisible,
		tooltip = L["Track this cooldown and draw it. Untick to hide it from every lane, bar and ready box. Until you touch it here, it follows this category's Show By Default setting."],
		onChange = function(v) SetSpellOverride(spellID, "visible", v) end,
	})
	cb:SetPoint("LEFT", name, "RIGHT", 8, 0)
	-- The factory widens a tooltip'd checkbox's hit rect across its whole 220px root, which in a packed
	-- row turns the dead space before the Lane dropdown into a Show toggle. Keep the hit rect on the box.
	if cb._cb then cb._cb:SetHitRectInsets(0, 0, 0, 0) end

	local laneVal = (override and override.lane) or 0  -- 0 sentinel for "Default"
	local dd = W.CreateDropdown(row, {
		label = "",
		value = laneVal,
		options = FILTER_LANE_OPTIONS,
		width = 80,
		onChange = function(v)
			SetSpellOverride(spellID, "lane", v ~= 0 and v or nil)
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	dd:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	AttachRowTip(dd.box, L["Lane"],
		L["Which lane this cooldown travels in. Default follows this category's Default Lane, set on the Defaults tab."])

	local barVal = override and override.bar
	if barVal == nil then barVal = -1 end  -- -1 sentinel for "Default"
	local bdd = W.CreateDropdown(row, {
		label = "",
		value = barVal,
		options = FILTER_BAR_OPTIONS,
		width = 80,
		onChange = function(v)
			SetSpellOverride(spellID, "bar", v ~= -1 and v or nil)
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	bdd:SetPoint("LEFT", dd, "RIGHT", 8, 0)
	AttachRowTip(bdd.box, L["Bar"],
		L["Which bar frame this cooldown shows on. Default follows this category's Default Bar. Off keeps it off the bars without hiding it from your lanes or ready boxes."])

	local rbVal = override and override.readyBox
	if rbVal == nil then rbVal = -1 end  -- -1 sentinel for "Default"
	local rdd = W.CreateDropdown(row, {
		label = "",
		value = rbVal,
		options = FILTER_READYBOX_OPTIONS,
		width = 80,
		onChange = function(v)
			SetSpellOverride(spellID, "readyBox", v ~= -1 and v or nil)
		end,
	})
	rdd:SetPoint("LEFT", bdd, "RIGHT", 8, 0)
	AttachRowTip(rdd.box, L["Ready Box"],
		L["Which ready box this pops into the moment the cooldown comes up. Default follows this category's Ready Box. Off means it never pops."])

	local flagVal = ((override and override.important) and 1 or 0) + ((override and override.pinned) and 2 or 0)
	local fdd = W.CreateDropdown(row, {
		label = "",
		value = flagVal,
		options = FILTER_READYFLAG_OPTIONS,
		width = 80,
		onChange = function(v)
			SetSpellOverride(spellID, "important", (v % 2) == 1 or nil)
			SetSpellOverride(spellID, "pinned",    v >= 2 or nil)
		end,
	})
	fdd:SetPoint("LEFT", rdd, "RIGHT", 8, 0)
	AttachRowTip(fdd.box, L["Flags"],
		L["How this one behaves once it pops into a ready box.\n\nNormal - fades after the box's Display Duration.\n\nImportant - highlights the icon and holds it for the box's Highlight Duration instead, and plays the box's Highlight Sound (set to None until you pick one).\n\nPinned - the icon never fades. It stays until you reload or switch profile, and a box full of pinned icons has no room for new pops.\n\nImp + Pin - both."])

	-- Offensives is the only auto-discovered, persisted list, so it is the only place a leaked entry can lodge. Narrow so the button clears the scrollbar on a full list.
	if info.category == ns.CONST.OFFENSIVE_CATEGORY then
		local del = W.CreateButton(row, {
			label = "X", width = 22,
			tooltip = L["Remove this from Offensives. Use it to clear a debuff that leaked in from another player on a shared target. If the spell is actually yours, it relearns the next time you cast it."],
			onClick = function()
				-- Deferred a frame - the forget rebuilds this list, tearing down the surface this button lives on.
				C_Timer.After(0, function()
					if ns.Engine and ns.Engine.ForgetOffensive then ns.Engine:ForgetOffensive(spellID) end
				end)
			end,
		})
		del:SetPoint("LEFT", fdd.box, "RIGHT", 8, 0)   -- to fdd.box, not fdd - the dropdown's box sits below its label, so the padded frame center rides high
	end

	-- Classic only: a cooldown spell that also grants a self-buff can show a second icon that times the buff. Retail buffs are secret in combat, so the option is not offered there.
	if not ns.Compat.HAS_BLIZZ_CDM and (info.category == 0 or info.category == 1) then
		local bcb = W.CreateCheckbox(row, {
			label = "",
			checked = (override and override.trackBuff) and true or false,
			tooltip = L["Also track this spell's buff. Adds a second icon that counts down how long the buff lasts, separate from the cooldown. Off by default - leave it off for spells that do not give you a buff."],
			onChange = function(v)
				SetSpellOverride(spellID, "trackBuff", v or nil)
				if ns.Engine and ns.Engine.RefreshBuffTracking then ns.Engine:RefreshBuffTracking(spellID) end
			end,
		})
		bcb:SetPoint("LEFT", fdd.box, "RIGHT", 8, 0)
		-- Same hit-rect trap as the Show box: a tooltip'd checkbox widens its hit rect across the row unless pinned back.
		if bcb._cb then bcb._cb:SetHitRectInsets(0, 0, 0, 0) end
	end

	-- Register item rows (keyed by itemID == spellID by convention) so the async ItemMixin load can update name/icon in place. Spells are always cached by build time.
	if info.kind == "item" then
		filtersState.itemRows = filtersState.itemRows or {}
		filtersState.itemRows[spellID] = { name = name, icon = tex }
	end

	return row, rowH
end


-- These x offsets are BuildSpellRow's anchor chain summed, so a control moved there must move here.
local FILTER_COL_HEADERS = { { L["Show"], 216 }, { L["Lane"], 440 }, { L["Bar"], 528 }, { L["Ready Box"], 616 }, { L["Flags"], 704 } }
local function BuildFiltersColumnHeader(parent, yPos, categoryKey)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(parent:GetWidth() - 24, 16)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yPos)
	local Y = ns.CONST.RGB.YELLOW
	for _, c in ipairs(FILTER_COL_HEADERS) do
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", row, "LEFT", c[2], 0)
		fs:SetText(c[1])
		fs:SetTextColor(Y.r, Y.g, Y.b)
	end
	if categoryKey == "offensives" then
		-- Row x 786, just left of the Delete button, so it clears the Flags dropdown (ends 784) and the scrollbar.
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", row, "LEFT", 786, 0)
		fs:SetText(L["Remove"])
		fs:SetTextColor(Y.r, Y.g, Y.b)
	elseif not ns.Compat.HAS_BLIZZ_CDM and (categoryKey == "spells" or categoryKey == "items") then
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("LEFT", row, "LEFT", 786, 0)
		fs:SetText(L["Buff"])
		fs:SetTextColor(Y.r, Y.g, Y.b)
	end
end


local function BuildFiltersSpellListForm(parent, categoryKey)
	local pad = 12
	local rowGap = 4

	RefreshLaneOptionLabels()

	-- Wipe so a stale FontString ref cannot SetText a row that is no longer shown.
	if (categoryKey == "potions" or categoryKey == "trinkets") and filtersState.itemRows then
		wipe(filtersState.itemRows)
	end

	-- Must stay above the empty-list return below - Offensives starts empty, and this is the only switch that enables it.
	local top = -pad
	local catCfg = GetFilterCfg(categoryKey)
	if catCfg then
		local cb = ns.Widgets.CreateCheckbox(parent, {
			label   = L["Track this category"],
			checked = catCfg.enabled,
			tooltip = L["Untick to stop tracking this whole category. None of its cooldowns show on a lane or a bar, or pop a ready frame. This is the same setting as Enabled on the Defaults tab."],
			onChange = function(v)
				catCfg.enabled = v
				RefreshFilterListForm(categoryKey)
			end,
		})
		cb:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, top)
		filtersState.enabledChecks[categoryKey] = cb
		top = top - 26
	end

	-- Onboarding for a /cm command (no control to hang a tooltip on), so it lives on the panel like the custom-form hint.
	if categoryKey == "offensives" then
		local isOff = catCfg and catCfg.enabled == false

		local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		title:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, top)
		title:SetText(isOff and L["Offensives is turned off"] or L["Learning your offensives"])
		title:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
		top = top - 18

		local body = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		body:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, top)
		body:SetWidth(parent:GetWidth() - pad * 2 - 20)
		body:SetJustifyH("LEFT")
		body:SetTextColor(0.7, 0.7, 0.7)

		local how
		if ns.Compat.HAS_COMBAT_LOG then
			how = L["Harmful effects you put on a target are detected automatically as you apply them - nothing to set up."]
		else
			how = L["A target's debuff cannot be identified in combat, so Cooldown Master learns which of your abilities applies which effect out of combat, from what lands just after you cast.\n\nSince 12.1 the game withholds that too, so an effect it has not already learned cannot be picked up at all. /cm offlearn tells you when your client is withholding it rather than leaving you guessing, and where the game still allows learning, it walks you through one ability at a time - type /cm offlearn, cast the ability, let combat end, then /cm offlearn stop. Anything already learned keeps tracking normally."]
		end
		if isOff then
			how = L["This category tracks the harmful effects you put on your target - damage-over-time effects, and debuffs like stuns - so each one travels a lane and pops a ready box when it drops. Nothing in this category is tracked while it is switched off - tick Track this category above to switch it on.\n\n"] .. how
		end
		body:SetText(how)
		top = top - (body:GetStringHeight() + 12)
	end

	local engine = ns.Engine
	local matches = {}
	if engine and engine.trackedSpells then
		for spellID, info in pairs(engine.trackedSpells) do
			local key = engine:GetCategoryFilterKey(info.category)
			if key == categoryKey then
				matches[#matches + 1] = { spellID = spellID, info = info }
			end
		end
	end
	if engine and engine.trackedItems then
		for itemID, info in pairs(engine.trackedItems) do
			local key = engine:GetCategoryFilterKey(info.category)
			if key == categoryKey then
				matches[#matches + 1] = { spellID = itemID, info = info }
			end
		end
	end
	if engine and engine.trackedOffensives then
		for spellID, info in pairs(engine.trackedOffensives) do
			local key = engine:GetCategoryFilterKey(info.category)
			if key == categoryKey then
				matches[#matches + 1] = { spellID = spellID, info = info }
			end
		end
	end

	table.sort(matches, function(a, b)
		local an = (a.info.name or ""):lower()
		local bn = (b.info.name or ""):lower()
		if an == bn then return a.spellID < b.spellID end
		return an < bn
	end)

	-- Toggling the category only redraws these two, so every other list can keep its frames.
	filtersState.enabledSensitive[categoryKey] = (categoryKey == "offensives") or (#matches == 0)

	if #matches == 0 then
		local text
		if categoryKey == "offensives" then
			-- Offensives spells out the switch in its own block above, so a second copy here would just repeat it.
			if not catCfg or catCfg.enabled ~= false then
				text = L["No harmful effects discovered yet.\nThe effects you put on a target are listed here as you apply them."]
			end
		-- Must stay above the switched-off branch below - this list can never fill, so blaming the switch would send the user to tick a box that changes nothing.
		elseif categoryKey == "debuffs" and not ns.Compat.HAS_BLIZZ_CDM then
			text = L["This category stays empty on this version of the game.\nIt lists Blizzard's own bar-style tracked buffs, which exist only on retail. The harmful effects you put on a target are under Offensives."]
		elseif catCfg and catCfg.enabled == false then
			text = L["This category is switched off, so none of its cooldowns show on a lane or a bar, or pop a ready box.\nTick Track this category above to switch it on."]
		else
			text = L["No spells discovered yet for this category.\nLog in or /reload to populate the list."]
		end
		if text then
			local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			fs:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, top)
			fs:SetWidth(parent:GetWidth() - pad * 2 - 20)
			fs:SetText(text)
			fs:SetTextColor(0.7, 0.7, 0.7)
			fs:SetJustifyH("LEFT")
			parent:SetHeight(math.abs(top) + fs:GetStringHeight() + 40)
			return
		end
		parent:SetHeight(math.abs(top) + 60)
		return
	end

	local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, top)
	header:SetText(string.format(L["%d spells tracked. \"Default\" follows this category's Defaults tab; the last column flags a spell Important or Pinned."], #matches))
	header:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)

	BuildFiltersColumnHeader(parent, top - 20, categoryKey)

	local y = top - 40
	for _, item in ipairs(matches) do
		local _, h = BuildSpellRow(parent, item.spellID, item.info, y)
		y = y - h - rowGap
	end

	parent:SetHeight(math.abs(y) + pad)
end


local CUSTOM_TRIGGER_TYPE_OPTIONS = {
	{ value = "spell", text = L["Spell cast"]  },
	{ value = "aura",  text = L["Aura gained"] },
}

local CUSTOM_TRIGGER_TIP = L["Spell cast starts the timer when you cast the entered spell. On-use trinkets, potions and flasks all count - enter the spell the item casts. This is the reliable choice.\n\nAura gained starts it when you gain the entered buff. On retail, the game hides your buffs from addons while you are in combat, so a buff gained mid-fight cannot be seen and the timer will not start. Prefer Spell cast for anything you cast or use."]


local function SortedCustomDefs()
	local store = CustomStore()
	local ids = {}
	for id in pairs(store.defs) do ids[#ids + 1] = id end
	table.sort(ids)
	return ids, store
end


-- The placeholder is stored bare because def.name is saved, so a client language switch
-- must not strip a def of the sentinel that lets a real spell name replace it.
local function CustomDisplayName(def)
	if def.name == "New Custom" then return L["New Custom"] end
	return def.name or L["Custom"]
end


local function ResolveCustomDef(def)
	if not (def.triggerID and C_Spell and C_Spell.GetSpellInfo) then return end
	local info = C_Spell.GetSpellInfo(def.triggerID)
	if info then
		def.icon = info.iconID or def.icon
		if not def.name or def.name == "" or def.name == "New Custom" then
			def.name = info.name
		end
	end
end


local function NewCustomDef()
	-- Older profiles default the custom filter category to disabled, so force it on or the new cooldown is silently filtered out.
	local p = ns.CDM.db.profile
	if p.filters and p.filters.custom then
		p.filters.custom.enabled = true
		p.filters.custom.showByDefault = true
	end

	local store = CustomStore()
	store.nextId = store.nextId or 1
	local id = ns.CONST.CUSTOM_ID_BASE + store.nextId
	store.nextId = store.nextId + 1
	store.defs[id] = {
		id          = id,
		name        = "New Custom",
		icon        = 134400,
		triggerType = "spell",
		triggerID   = nil,
		durationMs  = 30000,
		enabled     = true,
	}
	return id
end


local function DeleteCustomDef(id)
	local p = ns.CDM.db.profile
	if p.customCooldowns and p.customCooldowns.defs then p.customCooldowns.defs[id] = nil end
	if p.spellOverrides then p.spellOverrides[id] = nil end
	if ns.Engine and ns.Engine.entries then ns.Engine.entries[id] = nil end
	if filtersState.customSelected == id then filtersState.customSelected = nil end
end


-- Deferred a frame - the widget whose callback we are in lives on the surface this tears down.
local function RefreshCustomForm()
	if ns.Engine and ns.Engine.RebuildCustomTriggers then ns.Engine:RebuildCustomTriggers() end

	-- Read now - the deferred teardown below drops the scroll frame and its position with it.
	local prev = filtersState.formFrames["custom"]
	local offset = prev and prev:GetVerticalScroll() or 0

	C_Timer.After(0, function()
		if filtersState.formFrames["custom"] then
			filtersState.formFrames["custom"]:Hide()
			filtersState.formFrames["custom"] = nil
		end
		if filtersState._refresh and filtersState.selectedSubTab == "custom" then
			filtersState._refresh()

			-- Opening an editor (Edit or Add) scrolls to it - read after the rebuild set customEditorY - instead of holding the old position, so a long list does not leave it below the fold.
			if filtersState.customScrollToEditor then
				filtersState.customScrollToEditor = nil
				if filtersState.customEditorY then offset = math.max(0, filtersState.customEditorY - 30) end
			end

			local surf = filtersState.formFrames["custom"]
			if surf and offset > 0 then
				-- The scroll range is only recomputed next frame, so force it or the set clamps against a stale 0.
				if surf.UpdateScrollChildRect then surf:UpdateScrollChildRect() end
				local maxScroll = surf:GetVerticalScrollRange() or 0
				if offset > maxScroll then offset = maxScroll end
				surf:SetVerticalScroll(offset)

				-- A delete shortens the form, so the range can shrink again after this frame.
				C_Timer.After(0, function()
					if filtersState.formFrames["custom"] ~= surf then return end
					local maxNow = surf:GetVerticalScrollRange() or 0
					if surf:GetVerticalScroll() > maxNow then surf:SetVerticalScroll(maxNow) end
				end)
			end
		end
	end)
end


StaticPopupDialogs["COOLDOWNMASTER_DELETE_CUSTOM"] = {
	text = L["Delete this custom cooldown?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, id) DeleteCustomDef(id); RefreshCustomForm() end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}


local function BuildCustomDefBlock(parent, def, y)
	local W = ns.Widgets
	local pad, rowGap = 12, 8
	local id = def.id
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local head = W.CreateSectionHeader(parent, CustomDisplayName(def))
	head:SetWidth(parent:GetWidth() - pad * 2)
	place(head, 18)

	place(W.CreateEditBox(parent, {
		label = L["Name"], value = def.name, width = 240, maxLetters = 40, commitOnly = true,
		tooltip = L["Shown on the cooldown's icon tooltip and bar. Left blank, it follows the trigger spell's name."],
		onChange = function(t)
			if t == "" then
				def.name = nil
				ResolveCustomDef(def)
			else
				def.name = t
			end
			RefreshCustomForm()
		end,
	}))

	local isAura = (def.triggerType or "spell") == "aura"

	local rowY = y
	local typeDD = W.CreateDropdown(parent, {
		label = L["Trigger"], value = def.triggerType or "spell",
		options = CUSTOM_TRIGGER_TYPE_OPTIONS, width = 120, tooltip = CUSTOM_TRIGGER_TIP,
		onChange = function(v) def.triggerType = v; RefreshCustomForm() end,
	})
	typeDD:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, rowY)

	local idBox = W.CreateEditBox(parent, {
		label = L["Trigger ID"], value = def.triggerID and tostring(def.triggerID) or "",
		width = 100, maxLetters = 10, numeric = true, commitOnly = true,
		tooltip = isAura
			and L["The buff's spell ID (often different from the ability that grants it). Not sure of the ID? Use the Detect button."]
			or L["The spell ID you cast that fires this cooldown. For an on-use item, enter the spell the item casts."],
		onChange = function(t)
			def.triggerID = tonumber(t)
			ResolveCustomDef(def)
			RefreshCustomForm()
		end,
	})
	idBox:SetPoint("TOPLEFT", typeDD, "TOPRIGHT", 12, 0)

	local prev = parent:CreateTexture(nil, "ARTWORK")
	prev:SetSize(22, 22)
	prev:SetPoint("LEFT", idBox, "RIGHT", 12, 0)
	prev:SetTexture(def.icon or 134400)
	prev:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	if isAura and ns.Engine and ns.Engine.ArmAuraCapture then
		local detect = W.CreateButton(parent, {
			label = L["Detect"], width = 90,
			tooltip = L["Click, then gain the buff in-game within 15 seconds - CDM fills in its ID, name, icon and duration."],
			onClick = function(self2)
				self2:SetLabel(L["Gain a buff..."])
				ns.Engine:ArmAuraCapture(function(spellID, name, icon, duration)
					def.triggerID = spellID
					if icon then def.icon = icon end
					if name and (not def.name or def.name == "" or def.name == "New Custom") then
						def.name = name
					end
					-- 0 is a permanent buff, so only a real timer overrides the default
					if duration and duration > 0 then def.durationMs = math.floor(duration * 1000 + 0.5) end
					RefreshCustomForm()
				end)
				C_Timer.After(15, function()
					if ns.Engine._auraCaptureArmed then
						ns.Engine:CancelAuraCapture()
						RefreshCustomForm()
					end
				end)
			end,
		})
		detect:SetPoint("LEFT", prev, "RIGHT", 12, 0)
	end
	y = rowY - 48 - rowGap

	place(W.CreateSlider(parent, {
		label = L["Duration (sec)"], min = 1, max = 3600, step = 1,
		value = (def.durationMs or 30000) / 1000, width = 240,
		tooltip = L["How long the timer runs after the trigger fires. Type an exact value in the box below the slider."],
		onChange = function(v) def.durationMs = v * 1000 end,
	}))

	local ov = ns.CDM.db.profile.spellOverrides and ns.CDM.db.profile.spellOverrides[id]
	local routeY = y

	local laneVal = (ov and ov.lane) or 0
	local laneDD = W.CreateDropdown(parent, {
		label = L["Lane"], value = laneVal, options = FILTER_LANE_OPTIONS, width = 84,
		onChange = function(v)
			SetSpellOverride(id, "lane", v ~= 0 and v or nil)
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	laneDD:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, routeY)

	local barVal = ov and ov.bar
	if barVal == nil then barVal = -1 end
	local barDD = W.CreateDropdown(parent, {
		label = L["Bar"], value = barVal, options = FILTER_BAR_OPTIONS, width = 84,
		onChange = function(v)
			SetSpellOverride(id, "bar", v ~= -1 and v or nil)
			if ns.Engine then ns.Engine:ReapplyRouting() end
		end,
	})
	barDD:SetPoint("TOPLEFT", laneDD, "TOPRIGHT", 8, 0)

	local rbVal = ov and ov.readyBox
	if rbVal == nil then rbVal = -1 end
	local rbDD = W.CreateDropdown(parent, {
		label = L["Ready Box"], value = rbVal, options = FILTER_READYBOX_OPTIONS, width = 84,
		onChange = function(v) SetSpellOverride(id, "readyBox", v ~= -1 and v or nil) end,
	})
	rbDD:SetPoint("TOPLEFT", barDD, "TOPRIGHT", 8, 0)

	local flagVal = ((ov and ov.important) and 1 or 0) + ((ov and ov.pinned) and 2 or 0)
	local flagDD = W.CreateDropdown(parent, {
		label = L["Flags"], value = flagVal, options = FILTER_READYFLAG_OPTIONS, width = 84,
		onChange = function(v)
			SetSpellOverride(id, "important", (v % 2 == 1) or nil)
			SetSpellOverride(id, "pinned", (v >= 2) or nil)
		end,
	})
	flagDD:SetPoint("TOPLEFT", rbDD, "TOPRIGHT", 8, 0)
	y = routeY - 44 - rowGap

	local enY = y
	local en = W.CreateCheckbox(parent, {
		label = L["Enabled"], checked = def.enabled ~= false,
		onChange = function(v)
			def.enabled = v
			if ns.Engine and ns.Engine.RebuildCustomTriggers then ns.Engine:RebuildCustomTriggers() end
			if not v and ns.Engine and ns.Engine.entries then ns.Engine.entries[id] = nil end
		end,
	})
	en:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, enY)

	local del = W.CreateButton(parent, {
		label = L["Delete"], width = 90, tooltip = L["Remove this custom cooldown."],
		onClick = function() StaticPopup_Show("COOLDOWNMASTER_DELETE_CUSTOM", nil, nil, id) end,
	})
	del:SetPoint("TOPLEFT", en, "TOPRIGHT", 60, -1)
	y = enY - 26 - rowGap * 2

	return y
end


-- Only one editor opens at a time, so a long list of customs does not stack a tall editor each.
local function BuildCustomListRow(parent, def, y, selected)
	local W = ns.Widgets
	local pad, rowH = 12, 22
	local id = def.id

	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(rowH, rowH)
	icon:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
	icon:SetTexture(def.icon or 134400)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local del = W.CreateButton(parent, {
		label = "X", width = 24, tooltip = L["Remove this custom cooldown."],
		onClick = function() StaticPopup_Show("COOLDOWNMASTER_DELETE_CUSTOM", nil, nil, id) end,
	})
	del:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -pad, y + 1)

	local edit = W.CreateButton(parent, {
		label = selected and L["Editing"] or L["Edit"], width = 62,
		onClick = function()
			local opening = filtersState.customSelected ~= id
			filtersState.customSelected = opening and id or nil
			if opening then filtersState.customScrollToEditor = true end
			RefreshCustomForm()
		end,
	})
	edit:SetPoint("TOPRIGHT", del, "TOPLEFT", -6, 0)

	local toggle = W.CreateButton(parent, {
		label = (def.enabled ~= false) and L["On"] or L["Off"], width = 42,
		tooltip = L["Toggle this custom cooldown on or off without opening it."],
		onClick = function()
			def.enabled = (def.enabled == false)
			if ns.Engine and ns.Engine.RebuildCustomTriggers then ns.Engine:RebuildCustomTriggers() end
			if def.enabled == false and ns.Engine and ns.Engine.entries then ns.Engine.entries[id] = nil end
			RefreshCustomForm()
		end,
	})
	toggle:SetPoint("TOPRIGHT", edit, "TOPLEFT", -6, 0)

	local name = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	name:SetPoint("RIGHT", toggle, "LEFT", -8, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetText(CustomDisplayName(def))
	if selected then
		name:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	elseif def.enabled == false then
		name:SetTextColor(0.5, 0.5, 0.5)
	else
		name:SetTextColor(1, 1, 1)
	end

	return y - rowH - 6
end


local function BuildFiltersCustomForm(parent)
	local W = ns.Widgets
	RefreshLaneOptionLabels()
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetText(L["Custom cooldowns run a local timer you define - a fixed duration plus a trigger. They never read a live cooldown, so they behave the same in combat."])
	hint:SetTextColor(0.7, 0.7, 0.7)
	hint:SetWidth(parent:GetWidth() - pad * 2 - 20)
	hint:SetJustifyH("LEFT")
	place(hint, 32)

	local ids, store = SortedCustomDefs()

	if #ids == 0 then
		local none = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		none:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		none:SetText(L["No custom cooldowns yet. Add one below."])
		y = y - 20 - rowGap
	else
		for _, id in ipairs(ids) do
			y = BuildCustomListRow(parent, store.defs[id], y, filtersState.customSelected == id)
		end
		y = y - 4
	end

	place(W.CreateButton(parent, {
		label = L["Add Custom Cooldown"], width = 200,
		tooltip = L["Create a new custom cooldown - its editor opens below so you can set its trigger and duration."],
		onClick = function()
			filtersState.customSelected = NewCustomDef()
			filtersState.customScrollToEditor = true
			RefreshCustomForm()
		end,
	}), 24)

	local sel = filtersState.customSelected
	if sel and store.defs[sel] then
		filtersState.customEditorY = math.abs(y)
		local divider = parent:CreateTexture(nil, "ARTWORK")
		divider:SetHeight(1)
		divider:SetColorTexture(1, 1, 1, 0.08)
		divider:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -pad, y)
		y = y - 8
		y = BuildCustomDefBlock(parent, store.defs[sel], y)
	elseif #ids > 0 then
		local tip = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		tip:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		tip:SetText(L["Select a custom cooldown above to edit it."])
		y = y - 20 - rowGap
	end

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildFiltersFormSurface(panelArea, subTabKey)
	local scroll = CreateFrame("ScrollFrame", nil, panelArea, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT",     panelArea, "TOPLEFT",     0,   0)
	scroll:SetPoint("BOTTOMRIGHT", panelArea, "BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(panelArea:GetWidth() - 26, 1)
	scroll:SetScrollChild(child)

	if subTabKey == "defaults" then
		BuildFiltersDefaultsForm(child)
	elseif subTabKey == "custom" then
		BuildFiltersCustomForm(child)
	else
		BuildFiltersSpellListForm(child, subTabKey)
	end

	scroll:Hide()
	return scroll
end


local function ShowFiltersSubTab(panelArea, subTabKey)
	if filtersState._listsStale then
		filtersState._listsStale = nil
		DropFilterListSurfaces()
	end
	for _, surf in pairs(filtersState.formFrames) do surf:Hide() end

	local surf = filtersState.formFrames[subTabKey]
	if not surf then
		surf = BuildFiltersFormSurface(panelArea, subTabKey)
		filtersState.formFrames[subTabKey] = surf
	end
	surf:Show()

	filtersState.selectedSubTab = subTabKey

	for _, row in ipairs(filtersState.railRows) do
		if row.key == subTabKey then
			row.label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
			row.bg:Show()
		else
			row.label:SetTextColor(1, 1, 1)
			row.bg:Hide()
		end
	end
end


local function BuildFiltersTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, L["Filters"], "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local rail = CreateFrame("Frame", nil, content)
	rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
	rail:SetSize(FILTERS_INNER_RAIL_W, 1)

	local formArea = CreateFrame("Frame", nil, content)
	formArea:SetPoint("TOPLEFT",     rail, "TOPRIGHT",    12, 0)
	formArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	-- Rebuild recreates formArea; drop cached surfaces parented to the old one (mirrors BuildReadyTab).
	wipe(filtersState.formFrames)
	wipe(filtersState.railRows)

	local railEntries = {
		{ key = "defaults", label = L["Defaults"] },
	}
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		railEntries[#railEntries + 1] = def
	end

	local y = 0
	for _, entry in ipairs(railEntries) do
		local row = CreateFrame("Button", nil, rail)
		row:SetSize(FILTERS_INNER_RAIL_W, 22)
		row:SetPoint("TOPLEFT", rail, "TOPLEFT", 0, y)

		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetColorTexture(ns.CONST.RGB.RED_DIM.r, ns.CONST.RGB.RED_DIM.g, ns.CONST.RGB.RED_DIM.b, 0.6)
		bg:Hide()

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", row, "LEFT", 8, 0)
		label:SetText(entry.label)
		label:SetTextColor(1, 1, 1)

		row.bg    = bg
		row.label = label
		row.key   = entry.key

		row:SetScript("OnClick", function()
			ShowFiltersSubTab(formArea, entry.key)
		end)

		filtersState.railRows[#filtersState.railRows + 1] = row
		y = y - 24
	end

	filtersState._refresh = function()
		ShowFiltersSubTab(formArea, filtersState.selectedSubTab)
	end

	-- Reopening reuses the cached tab frame without re-running this builder, so a discovery that
	-- landed while the panel was shut would leave the stale list up until a rail row was clicked.
	content._reseed = function()
		if filtersState._listsStale then filtersState._refresh() end
	end

	ShowFiltersSubTab(formArea, filtersState.selectedSubTab)
end

for _, def in ipairs(TABS) do
	if def.id == "filters" then def.builder = BuildFiltersTab end
end


local CLASS_TOKENS_RETAIL = {
	"DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
	"MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
	"SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASS_TOKENS_CLASSIC = {
	"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST",
	"ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

-- MoP adds Death Knight and Monk; no Demon Hunter/Evoker yet.
local CLASS_TOKENS_MOP = {
	"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN",
	"PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASS_DISPLAY_NAMES = {
	DEATHKNIGHT = "Death Knight",
	DEMONHUNTER = "Demon Hunter",
	DRUID = "Druid",
	EVOKER = "Evoker",
	HUNTER = "Hunter",
	MAGE = "Mage",
	MONK = "Monk",
	PALADIN = "Paladin",
	PRIEST = "Priest",
	ROGUE = "Rogue",
	SHAMAN = "Shaman",
	WARLOCK = "Warlock",
	WARRIOR = "Warrior",
}

-- Blizzard localizes this in every client language, so it wins over our English names and the L[] store.
local function ClassDisplayName(token)
	local g = LOCALIZED_CLASS_NAMES_MALE
	return (g and g[token]) or CLASS_DISPLAY_NAMES[token] or token
end


local function BuildColorsTab(content)
	local W = ns.Widgets
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, L["Class Colors"], "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local tokens = ns.Compat.IS_MOP and CLASS_TOKENS_MOP
		or (ns.Compat.IS_RETAIL and CLASS_TOKENS_RETAIL or CLASS_TOKENS_CLASSIC)

	local cols = 3
	local cellW = math.floor((Theme.PANEL.WIDTH - pad * 2 - 40) / cols)
	local cellH = 30

	for i, token in ipairs(tokens) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = pad + col * cellW
		local y = -(pad + 30 + row * cellH)

		local profile = ns.CDM.db.profile
		if not profile.classColors[token] then
			-- Copy, don't alias CONST.CLASS_COLORS (edits would leak into the shared default); seed alpha.
			local base = ns.CONST.CLASS_COLORS[token]
			profile.classColors[token] = base
				and { r = base.r, g = base.g, b = base.b, a = base.a or 1 }
				or { r = 1, g = 1, b = 1, a = 1 }
		end

		local cp = W.CreateColorPicker(content, {
			label = ClassDisplayName(token),
			color = profile.classColors[token],
			hasAlpha = true,
			onChange = function(r, g, b, a)
				local c = profile.classColors[token]
				c.r, c.g, c.b = r, g, b
				c.a = a or 1
				-- Class-color substitution in Lanes_ApplyConfig no longer runs per tick, so push it explicitly.
				for li = 1, 3 do
					if ns.Lanes_ApplyConfig then ns.Lanes_ApplyConfig(li) end
					if ns.Lanes_Refresh then ns.Lanes_Refresh(li) end
				end
			end,
		})
		cp:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
	end
end

for _, def in ipairs(TABS) do
	if def.id == "colors" then def.builder = BuildColorsTab end
end


-- Profile import/export via the embedded AceSerializer + LibDeflate. AceDB's copyDefaults rawsets
-- every default straight into the profile table instead of leaving them on a metatable, so
-- db.profile is a complete tree rather than a sparse set of non-default keys.

-- Learned runtime state is per character, not a setting: it bloats the export string and would hand
-- the recipient another character's cooldown and dot learning. Stripped on the way out, and the
-- recipient's own copy is preserved on the way in.
local LEARNED_KEYS = {
	knownDurations    = true,
	observedDurations = true,
	auraDurations     = true,
	auraObserved      = true,
	castMap           = true,
	auraRoll          = true,
	-- Not learned state but a migration marker, and it belongs here for the same reason: an import
	-- resets the profile, and losing the flag would re-run the one-time castMap purge on the
	-- recipient's own learning.
	castMapPurged     = true,
}

local function ProfileExportString()
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

local function ProfileDecode(str)
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

-- The real profile nests 5 deep at most (lanes -> [1] -> highlight -> color -> r), so the cap only
-- ever trips on a hand-edited string, where dropping the branch beats overflowing the Lua stack.
local function OverlayProfile(dst, src, depth)
	if depth > 12 then return end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			OverlayProfile(dst[k], v, depth + 1)
		else
			dst[k] = v
		end
	end
end

-- ResetProfile, not wipe: AceDB rawsets defaults into the profile, so a wiped key is gone for good
-- rather than falling back to one. Callbacks off - OnProfileReset would rebuild on bare defaults first.
local function ApplyImportedProfile(prof)
	local p = ns.CDM.db.profile
	local keep = {}
	for k in pairs(LEARNED_KEYS) do keep[k] = p[k] end
	ns.CDM.db:ResetProfile(nil, true)
	OverlayProfile(p, prof, 1)
	for k, v in pairs(keep) do p[k] = v end
	ns.CDM:ApplyProfile()
end


StaticPopupDialogs["COOLDOWNMASTER_RESET_PROFILE"] = {
	text = L["Reset profile \"%s\" to default settings?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		local db = ns.CDM and ns.CDM.db
		if db then db:ResetProfile() end
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["COOLDOWNMASTER_DELETE_PROFILE"] = {
	text = L["Delete profile \"%s\"? This cannot be undone."],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		data = data or (self and self.data)
		local db = ns.CDM and ns.CDM.db
		local name = data and data.name
		if db and name then
			db:DeleteProfile(name)
			if ns.Options_Rebuild then ns.Options_Rebuild() end
		end
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Retail 12.0's GameDialog rewrite renamed the popup's box to EditBox and dropped the lowercase
-- alias the Classic flavors still use. Reading the old name alone errors the dialog open.
local function PopupEditBox(popup)
	return popup and (popup.EditBox or popup.editBox)
end

StaticPopupDialogs["COOLDOWNMASTER_IMPORT_PROFILE"] = {
	text = L["Paste an exported string to overwrite the current profile \"%s\"."],
	button1 = L["Import"],
	button2 = CANCEL,
	hasEditBox = true,
	editBoxWidth = 350,
	OnShow = function(self)
		local eb = PopupEditBox(self)
		if not eb then return end
		eb:SetText("")
		eb:SetMaxLetters(0)   -- import strings are long, never truncate
		eb:SetFocus()
	end,
	OnAccept = function(self)
		local eb = PopupEditBox(self)
		local prof, err = ProfileDecode(eb and eb:GetText())
		if not prof then
			ns.CDM:Print(string.format(L["Import failed: %s"], err or L["invalid string"]))
			return
		end
		ApplyImportedProfile(prof)
		ns.CDM:Print(string.format(L["Imported into profile \"%s\"."], ns.CDM.db:GetCurrentProfile()))
	end,
	EditBoxOnEnterPressed = function(self) self:ClearFocus() end,
	-- By name, not self:GetParent():Hide() - that assumes the box is a direct child of the popup.
	EditBoxOnEscapePressed = function() StaticPopup_Hide("COOLDOWNMASTER_IMPORT_PROFILE") end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}


local function BuildProfilesTab(content)
	local db = ns.CDM and ns.CDM.db
	if not db then return end
	local W   = ns.Widgets
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, L["Profiles"], "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local current = db:GetCurrentProfile()

	local curLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	curLabel:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -(pad + 26))
	curLabel:SetText(string.format(L["Current profile: |cffEBB706%s|r"], current))
	curLabel:SetTextColor(1, 1, 1)

	local allOpts, otherOpts = {}, {}
	local names = db:GetProfiles()
	table.sort(names)
	for _, name in ipairs(names) do
		allOpts[#allOpts + 1] = { value = name, text = name }
		if name ~= current then
			otherOpts[#otherOpts + 1] = { value = name, text = name }
		end
	end

	local ddW  = 220
	local btnX = pad + ddW + 16
	local step = 58
	local y    = -(pad + 58)

	local switchDD = W.CreateDropdown(content, {
		label = L["Active profile"], value = current, width = ddW, options = allOpts,
		onChange = function(v)
			if v and v ~= db:GetCurrentProfile() then db:SetProfile(v) end
		end,
	})
	switchDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
	y = y - step

	local newName = ""
	local newBox = W.CreateEditBox(content, {
		label = L["New profile name"], width = ddW, maxLetters = 32,
		onChange = function(t) newName = t end,
	})
	newBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
	local createBtn = Theme.CreateButton(content, L["Create"], 90, 24)
	createBtn:SetPoint("TOPLEFT", content, "TOPLEFT", btnX, y - 16)
	createBtn:SetScript("OnClick", function()
		local name = (newName or ""):trim()
		if name == "" then
			ns.CDM:Print(L["Enter a profile name first."])
			return
		end
		if name == db:GetCurrentProfile() then
			ns.CDM:Print(string.format(L["Already on profile: %s"], name))
			return
		end
		for _, existing in ipairs(db:GetProfiles()) do
			if existing == name then
				ns.CDM:Print(string.format(L["Profile already exists: %s (switch with Active profile, or pick a new name)."], name))
				return
			end
		end
		db:SetProfile(name)   -- creates the new profile and switches to it
		newName = ""
		newBox:SetValue("")
		ns.CDM:Print(string.format(L["Created and switched to profile: %s"], name))
	end)
	y = y - step

	if #otherOpts > 0 then
		local copyTarget = otherOpts[1].value
		local copyDD = W.CreateDropdown(content, {
			label = L["Copy settings from"], value = copyTarget, width = ddW, options = otherOpts,
			onChange = function(v) copyTarget = v end,
		})
		copyDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
		local copyBtn = Theme.CreateButton(content, L["Copy"], 90, 24)
		copyBtn:SetPoint("TOPLEFT", content, "TOPLEFT", btnX, y - 16)
		copyBtn:SetScript("OnClick", function()
			if copyTarget and copyTarget ~= db:GetCurrentProfile() then
				db:CopyProfile(copyTarget)
			end
		end)
		y = y - step

		local delTarget = otherOpts[1].value
		local delDD = W.CreateDropdown(content, {
			label = L["Delete profile"], value = delTarget, width = ddW, options = otherOpts,
			onChange = function(v) delTarget = v end,
		})
		delDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
		local delBtn = Theme.CreateButton(content, L["Delete"], 90, 24)
		delBtn:SetPoint("TOPLEFT", content, "TOPLEFT", btnX, y - 16)
		delBtn:SetScript("OnClick", function()
			if delTarget and delTarget ~= db:GetCurrentProfile() then
				StaticPopup_Show("COOLDOWNMASTER_DELETE_PROFILE", delTarget, nil, { name = delTarget })
			end
		end)
		y = y - step
	else
		local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y - 4)
		hint:SetText(L["Create another profile to enable Copy and Delete."])
		y = y - step
	end

	local resetBtn = Theme.CreateButton(content, L["Reset current profile to defaults"], 280, 28)
	resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y - 8)
	resetBtn:SetScript("OnClick", function()
		StaticPopup_Show("COOLDOWNMASTER_RESET_PROFILE", db:GetCurrentProfile())
	end)

	local exportBtn = Theme.CreateButton(content, L["Export"], 130, 24)
	exportBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -12)
	exportBtn:SetScript("OnClick", function()
		local s = ProfileExportString()
		if s and ns.ShowURL then ns.ShowURL(s) else ns.CDM:Print(L["Export failed."]) end
	end)
	local importBtn = Theme.CreateButton(content, L["Import"], 130, 24)
	importBtn:SetPoint("TOPLEFT", exportBtn, "TOPRIGHT", 16, 0)
	importBtn:SetScript("OnClick", function()
		StaticPopup_Show("COOLDOWNMASTER_IMPORT_PROFILE", db:GetCurrentProfile())
	end)

	-- Gate on GetSpecInfo(1) so a flavor that reports a spec count but cannot resolve
	-- per-index info self-hides instead of erroring.
	local numSpecs = ns.Compat.GetNumSpecs()
	if numSpecs and numSpecs > 0 and ns.Compat.GetSpecInfo(1) then
		local rx = 470
		local specHeader = Theme.CreateHeader(content, L["Auto-switch by Specialization"], "GameFontNormalLarge")
		specHeader:SetPoint("TOPLEFT", content, "TOPLEFT", rx, -pad)

		local specHint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		specHint:SetPoint("TOPLEFT", content, "TOPLEFT", rx, -(pad + 24))
		specHint:SetText(L["Switch profile automatically when you change spec."])
		specHint:SetTextColor(0.7, 0.7, 0.7)

		local specOpts = { { value = "", text = L["(no auto-switch)"] } }
		for _, name in ipairs(names) do
			specOpts[#specOpts + 1] = { value = name, text = name }
		end

		local map = ns.CDM.db.char.specProfiles
		local ry  = -(pad + 58)
		for i = 1, numSpecs do
			local specID, specName = ns.Compat.GetSpecInfo(i)
			if specID then
				local dd = W.CreateDropdown(content, {
					label = specName, value = map[specID] or "", width = ddW, options = specOpts,
					onChange = function(v)
						ns.CDM.db.char.specProfiles[specID] = (v ~= "" and v) or nil
					end,
				})
				dd:SetPoint("TOPLEFT", content, "TOPLEFT", rx, ry)
				ry = ry - step
			end
		end
	end
end

for _, def in ipairs(TABS) do
	if def.id == "profiles" then def.builder = BuildProfilesTab end
end


function ns.Options_Rebuild()
	if not panel then return end
	-- Tearing a tab down orphans its frames (WoW never destroys a frame), so rebuilding with the
	-- panel closed leaks a whole tree on every profile switch, spec change and talent edit, all
	-- session. Defer to the next open, which rebuilds once - Options_SelectTab consumes this.
	if not panel:IsShown() then
		optionsStale = true
		return
	end
	-- Keep profile-independent tabs (About) cached; recreating them only leaks frames
	-- (never GC'd) since their content doesn't depend on db.profile.
	for _, def in ipairs(TABS) do
		if not def.static then
			local frame = tabContents[def.id]
			if frame then
				frame:Hide()
				frame:SetParent(nil)
				tabContents[def.id] = nil
			end
		end
	end
	wipe(lanesState.formFrames)
	wipe(filtersState.formFrames)
	-- Drop the stale closure: it captured the now-orphaned formArea, and
	-- Options_InvalidateFilterLists would otherwise fire it into a dead frame (blank Filters tab).
	filtersState._refresh = nil
	filtersState.itemRows = nil
	ns.Options_SelectTab(currentTabID or "global")
end


local ABOUT_GOLD  = "|cffEBB706"
local ABOUT_MUTED = "|cffb3b3b3"
local ABOUT_WHITE = "|cffe6e6e6"
local ABOUT_CLOSE = "|r"

-- Latin handles only: a CJK name renders as empty boxes in the Western game font.
local ABOUT_TRANSLATORS = {
	{ name = "Zox",      line = L["Thanks to %s, who translated my other addons into French."] },
	{ name = "Malevi4",  line = L["Thanks to %s, who translated my other addons into Russian."] },
	{ name = "labrie75", line = L["Thanks to %s, who translated my other addons into Korean."] },
	{ name = "Keriaovo", line = L["Thanks to %s, who translated my other addons into Simplified Chinese."] },
	{ name = "BNS333",   line = L["Thanks to %s, who translated my other addons into Traditional Chinese."] },
	{ name = "Stonetwist", line = L["Thanks to %s, who translated my other addons into German."] },
}

local ABOUT_GITHUB_URL   = "https://github.com/wheelbarrel00/CooldownMaster"
local ABOUT_BUG_URL      = "https://github.com/wheelbarrel00/CooldownMaster/issues"
local ABOUT_RELEASES_URL = "https://github.com/wheelbarrel00/CooldownMaster/releases"

local ABOUT_COMMANDS = {
	{ cmd = "/cm",         desc = L["Open or close the options window (or /cdmaster)"] },
	{ cmd = "/cm lock",    desc = L["Lock the lane frames"] },
	{ cmd = "/cm unlock",  desc = L["Unlock the lane frames for moving"] },
	{ cmd = "/cm test",    desc = L["Toggle sample cooldowns (set them up in Global > Test Mode)"] },
	{ cmd = "/cm reset",   desc = L["Reset the current profile to defaults"] },
	{ cmd = "/cm version", desc = L["Print the version and game flavor"] },
	{ cmd = "/cm whatsnew", desc = L["Reopen the What's New window"] },
}

local ABOUT_OTHER_ADDONS = {
	{ name = "Everything Quests",
	  cf   = "https://www.curseforge.com/wow/addons/everything-quests",
	  gh   = "https://github.com/wheelbarrel00/EverythingQuests" },
	{ name = "Everything Delves",
	  cf   = "https://www.curseforge.com/wow/addons/everything-delves",
	  gh   = "https://github.com/wheelbarrel00/EverythingDelves" },
	{ name = "Loot Pro",
	  cf   = "https://www.curseforge.com/wow/addons/loot-pro",
	  gh   = "https://github.com/wheelbarrel00/LootPro" },
}

local function BuildAboutTab(content)
	local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -28, 4)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = self:GetVerticalScrollRange() or 0
		local new = math.min(maxScroll, math.max(0, (self:GetVerticalScroll() or 0) - delta * 36))
		self:SetVerticalScroll(new)
	end)

	-- Scroll-child width isn't resolved at build time, so size it (and text wrap) to a constant that fits the content area.
	local SC_W, WRAP, LEFT = 1000, 960, 4
	local sc = CreateFrame("Frame", nil, scroll)
	sc:SetSize(SC_W, 1)
	scroll:SetScrollChild(sc)

	local Y = -6
	local RED = ns.CONST.RGB.RED

	local function header(text)
		local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		fs:SetTextColor(RED.r, RED.g, RED.b)
		fs:SetText(text)
		fs:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
		local line = sc:CreateTexture(nil, "ARTWORK")
		line:SetHeight(1)
		line:SetColorTexture(0.30, 0.30, 0.30, 0.8)
		line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
		line:SetWidth(WRAP - LEFT)
		Y = Y - 28
	end

	local function body(text, indent, size)
		size = size or 12
		local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + (indent or 0), Y)
		fs:SetFont(fs:GetFont(), size)
		fs:SetWidth(WRAP - (indent or 0))
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		fs:SetText(text)
		local h = fs:GetStringHeight() or size
		if h < size then h = size end
		Y = Y - h - 4
	end

	local function gap(px) Y = Y - (px or 8) end

	local function makeLink(label, onClick)
		local b = CreateFrame("Button", nil, sc)
		b:SetHeight(16)
		local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("LEFT", b, "LEFT", 0, 0)
		t:SetText(label)
		t:SetTextColor(0.92, 0.72, 0.02)
		b.text = t
		b:SetWidth((t:GetStringWidth() or 40) + 2)
		b:SetScript("OnClick", onClick)
		b:SetScript("OnEnter", function(s) s.text:SetTextColor(1, 1, 1) end)
		b:SetScript("OnLeave", function(s) s.text:SetTextColor(0.92, 0.72, 0.02) end)
		return b
	end

	local function linkRow(links)
		local prev
		for i, lk in ipairs(links) do
			local b = makeLink(lk.label, lk.onClick)
			if i == 1 then
				b:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
			else
				local sep = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				sep:SetText(ABOUT_MUTED .. "  |  " .. ABOUT_CLOSE)
				sep:SetPoint("LEFT", prev, "RIGHT", 2, 0)
				b:SetPoint("LEFT", sep, "RIGHT", 2, 0)
			end
			prev = b
		end
		Y = Y - 24
	end

	local ver = (C_AddOns and C_AddOns.GetAddOnMetadata
		and C_AddOns.GetAddOnMetadata(ns.CONST.ADDON_NAME, "Version"))
		or ns.CONST.VERSION or "?"

	local title = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
	title:SetFont(title:GetFont(), 22, "OUTLINE")
	title:SetText(ns.CONST.ADDON_DISPLAY)
	title:SetTextColor(RED.r, RED.g, RED.b)
	Y = Y - 28

	local sub = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	sub:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
	sub:SetText(ABOUT_GOLD .. "v" .. ver .. ABOUT_CLOSE
		.. ABOUT_MUTED .. "    " .. string.format(L["by %s"], "Wheelbarrel00")
		.. "    -    " .. ns.Compat.FlavorLabel() .. ABOUT_CLOSE)
	Y = Y - 22

	-- Only retail has a built-in Cooldown Manager to complement.
	body(ABOUT_WHITE .. (ns.Compat.HAS_BLIZZ_CDM
		and L["A timeline-style lane cooldown tracker that complements Blizzard's built-in Cooldown Manager."]
		or L["A timeline-style lane cooldown tracker for your spells, items, and buffs."]) .. ABOUT_CLOSE)
	gap(10)

	linkRow({
		{ label = L["Join our Discord"], onClick = function() ns.ShowURL(ns.DISCORD_URL) end },
		{ label = L["GitHub"],           onClick = function() ns.ShowURL(ABOUT_GITHUB_URL) end },
		{ label = L["Report a Bug"],     onClick = function() ns.ShowURL(ABOUT_BUG_URL) end },
	})
	gap(8)

	header(L["Commands"])
	for _, c in ipairs(ABOUT_COMMANDS) do
		local cmd = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cmd:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
		cmd:SetText(ABOUT_GOLD .. c.cmd .. ABOUT_CLOSE)
		local d = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		d:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + 150, Y)
		d:SetText(ABOUT_WHITE .. c.desc .. ABOUT_CLOSE)
		Y = Y - 18
	end
	gap(2)
	body(ABOUT_MUTED .. L["Tip: left-click the minimap button to open Options, right-click to lock or unlock frames."] .. ABOUT_CLOSE, 0, 11)
	gap(10)

	header(L["Tutorials"])
	body(ABOUT_MUTED .. L["Video tutorials are coming soon."] .. ABOUT_CLOSE)
	gap(10)

	header(L["More Add-ons by Wheelbarrel00"])
	for _, a in ipairs(ABOUT_OTHER_ADDONS) do
		local n = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		n:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
		n:SetText(ABOUT_WHITE .. a.name .. ABOUT_CLOSE)
		local cfLink = makeLink("CurseForge", function() ns.ShowURL(a.cf) end)
		cfLink:SetPoint("LEFT", n, "LEFT", 200, 0)
		local sep = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		sep:SetText(ABOUT_MUTED .. "  |  " .. ABOUT_CLOSE)
		sep:SetPoint("LEFT", cfLink, "RIGHT", 2, 0)
		local ghLink = makeLink(L["GitHub"], function() ns.ShowURL(a.gh) end)
		ghLink:SetPoint("LEFT", sep, "RIGHT", 2, 0)
		Y = Y - 20
	end
	gap(10)

	header(L["Credits"])
	body(ABOUT_WHITE .. string.format(
		L["Cooldown Master carries forward the idea behind |cffEBB706%1$s|r by |cffEBB706%2$s|r - the timeline-cooldown addon that inspired this one. After Midnight changed how cooldowns work, I rebuilt the concept from the ground up for 12.0 with his blessing. Full credit for the original timeline-cooldown idea goes to him. Thank you, cliffclive."],
		"CooldownTimeline2 (CDTL2)", "cliffclive") .. ABOUT_CLOSE)
	gap(10)

	header(L["Translations"])
	body(ABOUT_WHITE .. L["Cooldown Master shares part of its text with my other addons, and those phrases are the work of the translators below. The rest was written in-house in their style and with their permission, so anything wrong in it is my mistake and not theirs. Corrections are very welcome."] .. ABOUT_CLOSE)
	-- The name is a %s so a translator can place it where their language wants it.
	for _, t in ipairs(ABOUT_TRANSLATORS) do
		body(ABOUT_WHITE .. string.format(t.line, ABOUT_GOLD .. t.name .. ABOUT_CLOSE .. ABOUT_WHITE) .. ABOUT_CLOSE)
	end
	gap(10)

	header(L["Thanks"])
	body(ABOUT_WHITE .. L["Built with feedback, reports, and ideas from the community. Thank you!"] .. ABOUT_CLOSE)
	gap(10)

	header(L["Changelog"])
	for _, entry in ipairs(ns.Changelog or {}) do
		local vh = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		vh:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
		vh:SetFont(vh:GetFont(), 13, "OUTLINE")
		vh:SetText(ABOUT_GOLD .. "v" .. entry.version .. ABOUT_CLOSE
			.. ABOUT_MUTED .. "    " .. (entry.date or "") .. ABOUT_CLOSE)
		Y = Y - 18
		for _, sec in ipairs(entry.sections or {}) do
			local sh = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			sh:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + 10, Y)
			sh:SetFont(sh:GetFont(), 11, "OUTLINE")
			sh:SetTextColor(RED.r, RED.g, RED.b)
			sh:SetText(sec.head)
			Y = Y - 16
			for _, item in ipairs(sec.items or {}) do
				body(ABOUT_WHITE .. "- " .. item .. ABOUT_CLOSE, 18, 11)
			end
			gap(2)
		end
		gap(8)
	end

	local older = makeLink(L["Older versions are on GitHub"], function() ns.ShowURL(ABOUT_RELEASES_URL) end)
	older:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
	Y = Y - 28

	sc:SetHeight(math.max(1, -Y + 10))
	if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
end

for _, def in ipairs(TABS) do
	if def.id == "about" then def.builder = BuildAboutTab end
end


local READY_SECTION_LIST = {
	{ id = "general",    label = L["General"]    },
	{ id = "appearance", label = L["Appearance"] },
	{ id = "icons",      label = L["Icons"]      },
	{ id = "text",       label = L["Text"]       },
	{ id = "highlight",  label = L["Highlight"]  },
}

local READY_GROW_OPTIONS = {
	{ value = "DOWN",     text = L["Down"]                },
	{ value = "UP",       text = L["Up"]                  },
	{ value = "RIGHT",    text = L["Right"]               },
	{ value = "LEFT",     text = L["Left"]                },
	{ value = "CENTER_V", text = L["Center (vertical)"]   },
	{ value = "CENTER_H", text = L["Center (horizontal)"] },
}

local READY_HL_STYLE_OPTIONS = HL_STYLE_OPTIONS

local readyState = {
	boxIndex   = 1,
	sectionID  = "general",
	subTabBtns = {},
	railRows   = {},
	formFrames = {},
}

local function GetReadyCfg(i) return ns.CDM.db.profile.readyFrames[i] end

local function ReadyApply(i)
	if ns.ReadyFrames_ApplyConfig then ns.ReadyFrames_ApplyConfig(i) end
end

local function ReadySoundOptions()
	local opts = { { value = "None", text = L["None"] } }
	for _, s in ipairs(ns.READY_BUILTIN_SOUNDS or {}) do
		opts[#opts + 1] = { value = s.name, text = s.name }
	end
	local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
	if ok and LSM and LSM.List then
		for _, name in ipairs(LSM:List("sound") or {}) do
			if name ~= "None" then
				opts[#opts + 1] = { value = name, text = name }
			end
		end
	end
	return opts
end


local function BuildReadyGeneralForm(parent, i)
	local W = ns.Widgets
	local cfg = GetReadyCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateEditBox(parent, {
		label = L["Frame Name"], value = cfg.frameName, width = 240, maxLetters = 32,
		onChange = function(t) cfg.frameName = t; ReadyApply(i) end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Enabled"], checked = cfg.enabled,
		onChange = function(v)
			cfg.enabled = v
			if ns.ReadyFrames_RebuildOne then ns.ReadyFrames_RebuildOne(i) end
		end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Grow Direction"], value = cfg.growDirection, options = READY_GROW_OPTIONS, width = 200,
		onChange = function(v) cfg.growDirection = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Display Duration (sec)"], min = 1, max = 20, step = 1, value = cfg.normalDuration, width = 240,
		onChange = function(v) cfg.normalDuration = v end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Post-Combat Hide (sec, 0 = off)"], min = 0, max = 30, step = 1, value = cfg.pTime or 0, width = 240,
		onChange = function(v) cfg.pTime = v end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Max Ready Icons"], min = 1, max = 10, step = 1, value = cfg.maxIcons or 10, width = 240,
		onChange = function(v) cfg.maxIcons = v end,
	}))
	local sndDD = place(W.CreateDropdown(parent, {
		label = L["Ready Sound"], value = cfg.normalSound or "None", options = ReadySoundOptions(), width = 240,
		onChange = function(v) cfg.normalSound = v end,
	}))
	local sndPlay = Theme.CreateButton(parent, L["Play"], 46, 22)
	sndPlay:SetPoint("TOPLEFT", sndDD, "TOPRIGHT", 6, -18)
	sndPlay:SetScript("OnClick", function()
		if ns.ReadyFrames_PreviewSound then ns.ReadyFrames_PreviewSound(cfg.normalSound) end
	end)

	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetText(L["Tip: enable Unlock Frames on the Global tab, then drag this box into position."])
	place(hint, 16)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildReadyAppearanceForm(parent, i)
	local W = ns.Widgets
	local cfg = GetReadyCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateSlider(parent, {
		label = L["X Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1, value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Y Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1, value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; ReadyApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Anchor"], value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		tooltip = L["Screen point the box is pinned to, then nudged by the X and Y offsets above. Also the point the ready icons grow out from."],
		onChange = function(v) cfg.anchor = v; ReadyApply(i) end,
	}))

	local secBG = W.CreateSectionHeader(parent, L["Background"])
	secBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBG, 18)

	place(W.CreateColorPicker(parent, {
		label = L["Background Color"], color = cfg.bgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.bgColor.r, cfg.bgColor.g, cfg.bgColor.b, cfg.bgColor.a = r, g, b, a
			ReadyApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Box Alpha"], min = 0, max = 1, step = 0.05, value = cfg.alpha, width = 220,
		onChange = function(v) cfg.alpha = v; ReadyApply(i) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, L["Border"])
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Border"], checked = cfg.borderEnabled ~= false,
		onChange = function(v) cfg.borderEnabled = v; ReadyApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Border Color"], color = cfg.borderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a = r, g, b, a
			ReadyApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Padding"], min = 0, max = 40, step = 1, value = cfg.borderPadding, width = 220,
		onChange = function(v) cfg.borderPadding = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Size"], min = 1, max = 40, step = 1, value = cfg.borderSize, width = 220,
		onChange = function(v) cfg.borderSize = v; ReadyApply(i) end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildReadyIconsForm(parent, i)
	local W = ns.Widgets
	local cfg = GetReadyCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateSlider(parent, {
		label = L["Size"], min = 1, max = 128, step = 1, value = cfg.iconSize, width = 240,
		onChange = function(v) cfg.iconSize = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Transparency"], min = 0, max = 1, step = 0.05, value = cfg.iconAlpha, width = 240,
		onChange = function(v) cfg.iconAlpha = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Icon Offset"], min = -30, max = 30, step = 1, value = cfg.iconOffset, width = 240,
		onChange = function(v) cfg.iconOffset = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Spacing"], min = 0, max = 40, step = 1, value = cfg.yPadding, width = 240,
		onChange = function(v) cfg.yPadding = v; ReadyApply(i) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, L["Icon Border"])
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Icon Border"],
		checked = cfg.iconBorder,
		tooltip = L["Draw a clean solid border around each ready icon in this box. Set per box. On by default."],
		onChange = function(v) cfg.iconBorder = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Size"], min = 1, max = 6, step = 1, value = cfg.iconBorderSize or 1, width = 240,
		onChange = function(v) cfg.iconBorderSize = v; ReadyApply(i) end,
	}))
	if type(cfg.iconBorderColor) ~= "table" then
		cfg.iconBorderColor = { r = 0, g = 0, b = 0, a = 1 }
	end
	place(W.CreateColorPicker(parent, {
		label = L["Border Color"], color = cfg.iconBorderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.iconBorderColor
			c.r, c.g, c.b, c.a = r, g, b, a
			ReadyApply(i)
		end,
	}))

	local secLbl = W.CreateSectionHeader(parent, L["Icon Label"])
	secLbl:SetWidth(parent:GetWidth() - pad * 2)
	place(secLbl, 18)

	cfg.iconLabel = cfg.iconLabel or { enabled = false, text = "[cd.name]", anchor = "CENTER" }

	place(W.CreateCheckbox(parent, {
		label = L["Show Label"],
		checked = cfg.iconLabel.enabled,
		tooltip = L["Draw a line of text on each ready icon in this box, built from the tags in Label Text below. Off by default - a ready icon is otherwise just art, so this is how you name what came up."],
		onChange = function(v) cfg.iconLabel.enabled = v; ReadyApply(i) end,
	}))

	BuildTagTextRow(parent, place, cfg.iconLabel, function() ReadyApply(i) end, L["Label Text"], ns.TAG_PICKER_READY)

	place(W.CreateDropdown(parent, {
		label = L["Label Position"], value = cfg.iconLabel.anchor or "CENTER",
		options = ICON_LABEL_ANCHOR_OPTIONS, width = 240,
		tooltip = L["Where the label sits on the icon. On icon draws it over the art."],
		onChange = function(v) cfg.iconLabel.anchor = v; ReadyApply(i) end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Label Font"], value = cfg.iconLabelFont, options = BuildFontOptions(), width = 240,
		onChange = function(v) cfg.iconLabelFont = v; ReadyApply(i) end,
	}))

	place(W.CreateSlider(parent, {
		label = L["Label Size"], min = 6, max = 32, step = 1, value = cfg.iconLabelSize or 10, width = 240,
		onChange = function(v) cfg.iconLabelSize = v; ReadyApply(i) end,
	}))

	place(W.CreateDropdown(parent, {
		label = L["Label Outline"], value = cfg.iconLabelFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.iconLabelFlags = v; ReadyApply(i) end,
	}))

	cfg.iconLabelColor = cfg.iconLabelColor or { r = 1, g = 1, b = 1, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Label Color"], color = cfg.iconLabelColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.iconLabelColor
			c.r, c.g, c.b, c.a = r, g, b, a
			ReadyApply(i)
		end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildReadyTextForm(parent, i)
	local W = ns.Widgets
	local cfg = GetReadyCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local secLabel = W.CreateSectionHeader(parent, L["Name Tag Font"])
	secLabel:SetWidth(parent:GetWidth() - pad * 2)
	place(secLabel, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.labelFont, options = BuildFontOptions(), width = 240,
		tooltip = L["Font for this box's name tag (shown above the box while frames are unlocked)."],
		onChange = function(v) cfg.labelFont = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.labelSize or 12, width = 240,
		onChange = function(v) cfg.labelSize = v; ReadyApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.labelFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 240,
		onChange = function(v) cfg.labelFlags = v; ReadyApply(i) end,
	}))
	cfg.labelColor = cfg.labelColor or { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.labelColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.labelColor
			c.r, c.g, c.b, c.a = r, g, b, a
			ReadyApply(i)
		end,
	}))

	BuildStatusLineSection(parent, place, pad, cfg, function() ReadyApply(i) end)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildReadyHighlightForm(parent, i)
	local W = ns.Widgets
	local cfg = GetReadyCfg(i)
	cfg.highlight = cfg.highlight or {}
	cfg.highlight.color = cfg.highlight.color or { r = 1, g = 0.82, b = 0, a = 0.6 }
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local intro = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	intro:SetText(L["Applies to spells flagged Important in the Filters tab. Important spells use the hold and sound below instead of the normal ones."])
	intro:SetTextColor(0.7, 0.7, 0.7)
	intro:SetWidth(parent:GetWidth() - pad * 2 - 20)
	intro:SetJustifyH("LEFT")
	place(intro, 32)

	place(W.CreateDropdown(parent, {
		label = L["Highlight Style"], value = cfg.highlight.style or "BORDER", options = READY_HL_STYLE_OPTIONS, width = 200,
		onChange = function(v) cfg.highlight.style = v end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Highlight Color"], color = cfg.highlight.color, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.highlight.color.r, cfg.highlight.color.g, cfg.highlight.color.b, cfg.highlight.color.a = r, g, b, a
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Highlight Duration (sec)"], min = 1, max = 30, step = 1, value = cfg.highlightDuration or 10, width = 240,
		onChange = function(v) cfg.highlightDuration = v end,
	}))
	local hsDD = place(W.CreateDropdown(parent, {
		label = L["Highlight Sound"], value = cfg.highlightSound or "None", options = ReadySoundOptions(), width = 240,
		onChange = function(v) cfg.highlightSound = v end,
	}))
	local hsPlay = Theme.CreateButton(parent, L["Play"], 46, 22)
	hsPlay:SetPoint("TOPLEFT", hsDD, "TOPRIGHT", 6, -18)
	hsPlay:SetScript("OnClick", function()
		if ns.ReadyFrames_PreviewSound then ns.ReadyFrames_PreviewSound(cfg.highlightSound) end
	end)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildReadyFormSurface(panelArea, i, sectionID)
	local scroll = CreateFrame("ScrollFrame", nil, panelArea, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panelArea, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", panelArea, "BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(panelArea:GetWidth() - 26, 1)
	scroll:SetScrollChild(child)

	if sectionID == "general" then
		BuildReadyGeneralForm(child, i)
	elseif sectionID == "appearance" then
		BuildReadyAppearanceForm(child, i)
	elseif sectionID == "icons" then
		BuildReadyIconsForm(child, i)
	elseif sectionID == "text" then
		BuildReadyTextForm(child, i)
	elseif sectionID == "highlight" then
		BuildReadyHighlightForm(child, i)
	end

	scroll:Hide()
	return scroll
end


local function ShowReadySection(panelArea, i, sectionID)
	readyState.formFrames[i] = readyState.formFrames[i] or {}
	for _, surf in pairs(readyState.formFrames[i]) do surf:Hide() end
	for bi, sections in pairs(readyState.formFrames) do
		if bi ~= i then for _, surf in pairs(sections) do surf:Hide() end end
	end

	local surf = readyState.formFrames[i][sectionID]
	if not surf then
		surf = BuildReadyFormSurface(panelArea, i, sectionID)
		readyState.formFrames[i][sectionID] = surf
	end
	surf:Show()

	readyState.boxIndex  = i
	readyState.sectionID = sectionID

	for _, row in ipairs(readyState.railRows) do
		local active = row._sectionID == sectionID
		row.text:SetTextColor(active and YELLOW.r or 1, active and YELLOW.g or 1, active and YELLOW.b or 1, 1)
	end
	for bi, btn in ipairs(readyState.subTabBtns) do
		btn:SetSelected(bi == i)
	end
end


local function BuildReadyTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	local subBar = CreateFrame("Frame", nil, content)
	subBar:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)
	subBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, -pad)
	subBar:SetHeight(Theme.PANEL.TAB_H)

	-- A profile-switch rebuild recreates this tab's frames, so drop surfaces parented to the old one.
	wipe(readyState.subTabBtns)
	wipe(readyState.railRows)
	wipe(readyState.formFrames)
	local x = 0
	for i = 1, 3 do
		local b = Theme.CreateTab(subBar, string.format(L["Box %d"], i), 90)
		b:SetPoint("TOPLEFT", subBar, "TOPLEFT", x, 0)
		readyState.subTabBtns[i] = b
		x = x + 90 + Theme.PANEL.TAB_GAP
	end

	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	local rail = CreateFrame("Frame", nil, body,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
	rail:SetWidth(LANES_INNER_RAIL_W)
	Theme.ApplyBackdrop(rail,
		{ r = 0, g = 0, b = 0, a = 0.4 }, ns.CONST.RGB.PANEL_BORDER)

	local formArea = CreateFrame("Frame", nil, body)
	formArea:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
	formArea:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

	for i, b in ipairs(readyState.subTabBtns) do
		b:SetScript("OnClick", function()
			ShowReadySection(formArea, i, readyState.sectionID)
		end)
	end

	local ry = -8
	for _, sec in ipairs(READY_SECTION_LIST) do
		local row = CreateFrame("Button", nil, rail)
		row:SetPoint("TOPLEFT",  rail, "TOPLEFT",  6, ry)
		row:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -6, ry)
		row:SetHeight(22)
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("LEFT", row, "LEFT", 4, 0)
		fs:SetText(sec.label)
		fs:SetTextColor(1, 1, 1)
		row.text = fs
		row._sectionID = sec.id
		row:EnableMouse(true)
		row:SetScript("OnClick", function()
			ShowReadySection(formArea, readyState.boxIndex, sec.id)
		end)
		row:SetScript("OnEnter", function()
			if sec.id ~= readyState.sectionID then fs:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b) end
		end)
		row:SetScript("OnLeave", function()
			if sec.id ~= readyState.sectionID then fs:SetTextColor(1, 1, 1) end
		end)
		readyState.railRows[#readyState.railRows + 1] = row
		ry = ry - 26
	end

	ShowReadySection(formArea, readyState.boxIndex, readyState.sectionID)
	content._reseed = function()
		local sections = readyState.formFrames[readyState.boxIndex]
		if not (sections and sections[readyState.sectionID]) then
			ShowReadySection(formArea, readyState.boxIndex, readyState.sectionID)
		end
	end
end

for _, def in ipairs(TABS) do
	if def.id == "ready" then def.builder = BuildReadyTab end
end


local BARS_SECTION_LIST = {
	{ id = "general",    label = L["General"]    },
	{ id = "appearance", label = L["Appearance"] },
	{ id = "bar",        label = L["Bar"]        },
}

local BAR_SORT_OPTIONS = {
	{ value = "DESCENDING", text = L["Longest first"]  },
	{ value = "ASCENDING",  text = L["Shortest first"] },
}

local BAR_ICON_POS_OPTIONS = {
	{ value = "LEFT",  text = L["Left"]  },
	{ value = "RIGHT", text = L["Right"] },
}

local barsState = {
	frameIndex = 1,
	sectionID  = "general",
	subTabBtns = {},
	railRows   = {},
	formFrames = {},
}

-- Every X/Y Offset slider lives in an Appearance form, so Frame Scale only has to invalidate
-- those three. Declared here because it is the first point all three state tables exist.
function ns.Options_DropAppearanceForms()
	for _, state in ipairs({ lanesState, readyState, barsState }) do
		for _, sections in pairs(state.formFrames) do
			local surf = sections["appearance"]
			if surf then
				surf:Hide()
				-- Unparent as well as drop, or it stays a child of the panel area while gone from
				-- formFrames, where every hide loop looks for it.
				surf:SetParent(nil)
				sections["appearance"] = nil
			end
		end
	end
end


local function GetBarCfg(i) return ns.CDM.db.profile.barFrames[i] end

local function BarApply(i)
	if ns.Bars_ApplyConfig then ns.Bars_ApplyConfig(i) end
	if ns.Bars_Refresh then ns.Bars_Refresh(i) end
end


local function BuildBarGeneralForm(parent, i)
	local W = ns.Widgets
	local cfg = GetBarCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateEditBox(parent, {
		label = L["Frame Name"], value = cfg.frameName, width = 240, maxLetters = 32,
		onChange = function(t) cfg.frameName = t; BarApply(i) end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Enabled"], checked = cfg.enabled,
		onChange = function(v)
			cfg.enabled = v
			if ns.Bars_RebuildOne then ns.Bars_RebuildOne(i) end
		end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Grow Direction"], value = cfg.growDirection, options = READY_GROW_OPTIONS, width = 200,
		tooltip = L["Direction the bars stack as more cooldowns become active."],
		onChange = function(v) cfg.growDirection = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Sort Order"], value = cfg.sortDir or "DESCENDING", options = BAR_SORT_OPTIONS, width = 200,
		tooltip = L["Longest first puts the cooldown with the most time left at the start of the grow direction."],
		onChange = function(v) cfg.sortDir = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Max Bars"], min = 1, max = 20, step = 1, value = cfg.maxBars or 10, width = 240,
		tooltip = L["Cap on how many bars this frame shows at once."],
		onChange = function(v) cfg.maxBars = v; BarApply(i) end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Show Extremely Long Cooldowns"], checked = cfg.showLongCooldowns,
		tooltip = L["Lets this frame show cooldowns up to 60 minutes long, ignoring the Ignore Threshold that keeps them off your lanes. Anything shorter than 60 minutes is covered too, not only the very longest. It applies to this bar frame alone, so your lanes and ready boxes are unaffected, and a cooldown you hid by hand on its Filters row stays hidden. Tick it on the frame your cooldowns actually go to, which is set by Default Bar under Filters, and make sure that frame is enabled on the Bars tab. Bear in mind an hour-long bar keeps its place in the list for the whole hour, so raise Max Bars or give it a frame of its own."],
		onChange = function(v) cfg.showLongCooldowns = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		-- Ceiling matches the lane Max Time slider: a hand-off above that has no lane that could catch it.
		label = L["Hand Off Below (sec)"], min = 0, max = 360, step = 5,
		value = cfg.handOffBelow or 0, width = 240,
		tooltip = L["This frame lets go of a cooldown once it has this many seconds left, so a lane can take it the rest of the way. 0 keeps every cooldown on the bar until it is ready.\n\nThis only decides when the BAR lets go. What decides when the lane picks up is that lane's own Max Time and Hide Long Timers, so set this to the lane's Max Time and make sure Hide Long Timers is on for it. Without that the lane draws the cooldown the whole time, parked at the far end, instead of waiting its turn.\n\nA value above the lane's Max Time leaves a stretch where neither one draws it. It applies to everything routed to this frame, not only to long cooldowns."],
		onChange = function(v) cfg.handOffBelow = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Spacing"], min = 0, max = 40, step = 1, value = cfg.spacing or 0, width = 240,
		tooltip = L["Gap, in pixels, between stacked bars."],
		onChange = function(v) cfg.spacing = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Frame Padding"], min = 0, max = 40, step = 1, value = cfg.padding or 0, width = 240,
		onChange = function(v) cfg.padding = v; BarApply(i) end,
	}))

	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetText(L["Tip: turn on Unlock Frames (Global tab) to drag this frame, and Test (Global tab) to preview bars."])
	hint:SetWidth(parent:GetWidth() - pad * 2 - 20)
	hint:SetJustifyH("LEFT")
	place(hint, 28)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildBarAppearanceForm(parent, i)
	local W = ns.Widgets
	local cfg = GetBarCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateSlider(parent, {
		label = L["X Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1, value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Y Offset"], min = -OffsetLimit(), max = OffsetLimit(), step = 1, value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Anchor"], value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		tooltip = L["Screen point the frame is pinned to, then nudged by the X and Y offsets above."],
		onChange = function(v) cfg.anchor = v; BarApply(i) end,
	}))

	local secBG = W.CreateSectionHeader(parent, L["Background"])
	secBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBG, 18)

	place(W.CreateColorPicker(parent, {
		label = L["Background Color"], color = cfg.bgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.bgColor.r, cfg.bgColor.g, cfg.bgColor.b, cfg.bgColor.a = r, g, b, a
			BarApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Frame Alpha"], min = 0, max = 1, step = 0.05, value = cfg.alpha, width = 220,
		onChange = function(v) cfg.alpha = v; BarApply(i) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, L["Border"])
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Border"], checked = cfg.borderEnabled ~= false,
		onChange = function(v) cfg.borderEnabled = v; BarApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Border Color"], color = cfg.borderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a = r, g, b, a
			BarApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Padding"], min = 0, max = 40, step = 1, value = cfg.borderPadding, width = 220,
		onChange = function(v) cfg.borderPadding = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Border Size"], min = 1, max = 40, step = 1, value = cfg.borderSize, width = 220,
		onChange = function(v) cfg.borderSize = v; BarApply(i) end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildBarStyleForm(parent, i)
	local W = ns.Widgets
	local cfg = GetBarCfg(i)
	local pad, rowGap = 12, 10
	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	place(W.CreateSlider(parent, {
		label = L["Bar Width"], min = 50, max = 500, step = 1, value = cfg.barWidth, width = 240,
		onChange = function(v) cfg.barWidth = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Bar Height"], min = 4, max = 60, step = 1, value = cfg.barHeight, width = 240,
		onChange = function(v) cfg.barHeight = v; BarApply(i) end,
	}))

	local secFG = W.CreateSectionHeader(parent, L["Foreground"])
	secFG:SetWidth(parent:GetWidth() - pad * 2)
	place(secFG, 18)

	place(W.CreateDropdown(parent, {
		label = L["Texture"], value = cfg.fgTexture, options = BuildStatusbarOptions(), width = 200,
		onChange = function(v) cfg.fgTexture = v; BarApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Color"], color = cfg.fgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.fgColor.r, cfg.fgColor.g, cfg.fgColor.b, cfg.fgColor.a = r, g, b, a
			BarApply(i)
		end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Use Class Color"], checked = cfg.fgClassColor,
		tooltip = L["Fill the bar with your class color instead of the color above."],
		onChange = function(v) cfg.fgClassColor = v; BarApply(i) end,
	}))

	local secBarBG = W.CreateSectionHeader(parent, L["Bar Background"])
	secBarBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBarBG, 18)

	place(W.CreateDropdown(parent, {
		label = L["Texture"], value = cfg.barBgTexture, options = BuildStatusbarOptions(), width = 200,
		onChange = function(v) cfg.barBgTexture = v; BarApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Color"], color = cfg.barBgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.barBgColor.r, cfg.barBgColor.g, cfg.barBgColor.b, cfg.barBgColor.a = r, g, b, a
			BarApply(i)
		end,
	}))

	local secIcon = W.CreateSectionHeader(parent, L["Icon"])
	secIcon:SetWidth(parent:GetWidth() - pad * 2)
	place(secIcon, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Icon"], checked = cfg.showIcon ~= false,
		onChange = function(v) cfg.showIcon = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Icon Position"], value = cfg.iconPosition or "LEFT", options = BAR_ICON_POS_OPTIONS, width = 200,
		onChange = function(v) cfg.iconPosition = v; BarApply(i) end,
	}))

	local secText = W.CreateSectionHeader(parent, L["Text"])
	secText:SetWidth(parent:GetWidth() - pad * 2)
	place(secText, 18)

	place(W.CreateCheckbox(parent, {
		label = L["Show Name"], checked = cfg.showName ~= false,
		onChange = function(v) cfg.showName = v; BarApply(i) end,
	}))
	place(W.CreateCheckbox(parent, {
		label = L["Show Time"], checked = cfg.showTime ~= false,
		tooltip = L["Show the countdown number, drawn by the game's own cooldown widget so it stays correct in combat."],
		onChange = function(v) cfg.showTime = v; BarApply(i) end,
	}))
	local secName = W.CreateSectionHeader(parent, L["Name"])
	secName:SetWidth(parent:GetWidth() - pad * 2)
	place(secName, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.barFont, options = BuildFontOptions(), width = 240,
		onChange = function(v) cfg.barFont = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.barFontSize or 12, width = 240,
		onChange = function(v) cfg.barFontSize = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.barFontFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 200,
		onChange = function(v) cfg.barFontFlags = v; BarApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Name Color"], color = cfg.barFontColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.barFontColor.r, cfg.barFontColor.g, cfg.barFontColor.b, cfg.barFontColor.a = r, g, b, a
			BarApply(i)
		end,
	}))

	local secTime = W.CreateSectionHeader(parent, L["Time"])
	secTime:SetWidth(parent:GetWidth() - pad * 2)
	place(secTime, 18)

	place(W.CreateDropdown(parent, {
		label = L["Time Font"], value = cfg.barTimeFont, options = BuildFontOptions(), width = 240,
		tooltip = L["Font for the countdown number, drawn by the game's cooldown widget. Restyling applies on Retail."],
		onChange = function(v) cfg.barTimeFont = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Time Size"], min = 6, max = 32, step = 1, value = cfg.barTimeSize or 12, width = 240,
		onChange = function(v) cfg.barTimeSize = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Time Outline"], value = cfg.barTimeFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 200,
		onChange = function(v) cfg.barTimeFlags = v; BarApply(i) end,
	}))
	cfg.barTimeColor = cfg.barTimeColor or { r = 1, g = 1, b = 1, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Time Color"], color = cfg.barTimeColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.barTimeColor.r, cfg.barTimeColor.g, cfg.barTimeColor.b, cfg.barTimeColor.a = r, g, b, a
			BarApply(i)
		end,
	}))

	local secTag = W.CreateSectionHeader(parent, L["Name Tag"])
	secTag:SetWidth(parent:GetWidth() - pad * 2)
	place(secTag, 18)

	place(W.CreateDropdown(parent, {
		label = L["Font"], value = cfg.labelFont, options = BuildFontOptions(), width = 240,
		tooltip = L["Font for this frame's name tag (shown above the frame while frames are unlocked)."],
		onChange = function(v) cfg.labelFont = v; BarApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = L["Font Size"], min = 6, max = 32, step = 1, value = cfg.labelSize or 12, width = 240,
		onChange = function(v) cfg.labelSize = v; BarApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = L["Font Outline"], value = cfg.labelFlags or "OUTLINE", options = FONT_FLAG_OPTIONS, width = 200,
		onChange = function(v) cfg.labelFlags = v; BarApply(i) end,
	}))
	cfg.labelColor = cfg.labelColor or { r = 0.9216, g = 0.7176, b = 0.0235, a = 1 }
	place(W.CreateColorPicker(parent, {
		label = L["Font Color"], color = cfg.labelColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			local c = cfg.labelColor
			c.r, c.g, c.b, c.a = r, g, b, a
			BarApply(i)
		end,
	}))

	cfg.highlight = cfg.highlight or { style = "BORDER", color = { r = 1, g = 0.82, b = 0, a = 0.8 } }
	cfg.highlight.color = cfg.highlight.color or { r = 1, g = 0.82, b = 0, a = 0.8 }
	local secHL = W.CreateSectionHeader(parent, L["Highlight (Important spells)"])
	secHL:SetWidth(parent:GetWidth() - pad * 2)
	place(secHL, 18)

	place(W.CreateDropdown(parent, {
		label = L["Highlight Style"], value = cfg.highlight.style or "BORDER", options = HL_STYLE_OPTIONS, width = 200,
		tooltip = L["Emphasis drawn on the bar of a spell flagged Important (per spell, in the Filters tab)."],
		onChange = function(v) cfg.highlight.style = v; BarApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = L["Highlight Color"], color = cfg.highlight.color, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.highlight.color.r, cfg.highlight.color.g, cfg.highlight.color.b, cfg.highlight.color.a = r, g, b, a
			BarApply(i)
		end,
	}))

	BuildStatusLineSection(parent, place, pad, cfg, function() BarApply(i) end)

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildBarFormSurface(panelArea, i, sectionID)
	local scroll = CreateFrame("ScrollFrame", nil, panelArea, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panelArea, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", panelArea, "BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(panelArea:GetWidth() - 26, 1)
	scroll:SetScrollChild(child)

	if sectionID == "general" then
		BuildBarGeneralForm(child, i)
	elseif sectionID == "appearance" then
		BuildBarAppearanceForm(child, i)
	elseif sectionID == "bar" then
		BuildBarStyleForm(child, i)
	end

	scroll:Hide()
	return scroll
end


local function ShowBarSection(panelArea, i, sectionID)
	barsState.formFrames[i] = barsState.formFrames[i] or {}
	for _, surf in pairs(barsState.formFrames[i]) do surf:Hide() end
	for bi, sections in pairs(barsState.formFrames) do
		if bi ~= i then for _, surf in pairs(sections) do surf:Hide() end end
	end

	local surf = barsState.formFrames[i][sectionID]
	if not surf then
		surf = BuildBarFormSurface(panelArea, i, sectionID)
		barsState.formFrames[i][sectionID] = surf
	end
	surf:Show()

	barsState.frameIndex = i
	barsState.sectionID  = sectionID

	for _, row in ipairs(barsState.railRows) do
		local active = row._sectionID == sectionID
		row.text:SetTextColor(active and YELLOW.r or 1, active and YELLOW.g or 1, active and YELLOW.b or 1, 1)
	end
	for bi, btn in ipairs(barsState.subTabBtns) do
		btn:SetSelected(bi == i)
	end
end


local function BuildBarsTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	local subBar = CreateFrame("Frame", nil, content)
	subBar:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)
	subBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, -pad)
	subBar:SetHeight(Theme.PANEL.TAB_H)

	-- A profile-switch rebuild recreates this tab's frames, so drop surfaces parented to the old one.
	wipe(barsState.subTabBtns)
	wipe(barsState.railRows)
	wipe(barsState.formFrames)
	local x = 0
	for i = 1, 3 do
		local b = Theme.CreateTab(subBar, string.format(L["Bars %d"], i), 90)
		b:SetPoint("TOPLEFT", subBar, "TOPLEFT", x, 0)
		barsState.subTabBtns[i] = b
		x = x + 90 + Theme.PANEL.TAB_GAP
	end

	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	local rail = CreateFrame("Frame", nil, body,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
	rail:SetWidth(LANES_INNER_RAIL_W)
	Theme.ApplyBackdrop(rail,
		{ r = 0, g = 0, b = 0, a = 0.4 }, ns.CONST.RGB.PANEL_BORDER)

	local formArea = CreateFrame("Frame", nil, body)
	formArea:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
	formArea:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

	for i, b in ipairs(barsState.subTabBtns) do
		b:SetScript("OnClick", function()
			ShowBarSection(formArea, i, barsState.sectionID)
		end)
	end

	local ry = -8
	for _, sec in ipairs(BARS_SECTION_LIST) do
		local row = CreateFrame("Button", nil, rail)
		row:SetPoint("TOPLEFT",  rail, "TOPLEFT",  6, ry)
		row:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -6, ry)
		row:SetHeight(22)
		local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("LEFT", row, "LEFT", 4, 0)
		fs:SetText(sec.label)
		fs:SetTextColor(1, 1, 1)
		row.text = fs
		row._sectionID = sec.id
		row:EnableMouse(true)
		row:SetScript("OnClick", function()
			ShowBarSection(formArea, barsState.frameIndex, sec.id)
		end)
		row:SetScript("OnEnter", function()
			if sec.id ~= barsState.sectionID then fs:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b) end
		end)
		row:SetScript("OnLeave", function()
			if sec.id ~= barsState.sectionID then fs:SetTextColor(1, 1, 1) end
		end)
		barsState.railRows[#barsState.railRows + 1] = row
		ry = ry - 26
	end

	ShowBarSection(formArea, barsState.frameIndex, barsState.sectionID)
	content._reseed = function()
		local sections = barsState.formFrames[barsState.frameIndex]
		if not (sections and sections[barsState.sectionID]) then
			ShowBarSection(formArea, barsState.frameIndex, barsState.sectionID)
		end
	end
end

for _, def in ipairs(TABS) do
	if def.id == "bars" then def.builder = BuildBarsTab end
end
