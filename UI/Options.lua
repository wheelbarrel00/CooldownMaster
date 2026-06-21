local ADDON_NAME, ns = ...

local Theme = ns.Theme

local TABS = {
	{ id = "global",       label = "Global",        builder = nil },
	{ id = "lanes",        label = "Lanes",         builder = nil },
	{ id = "ready",        label = "Ready",         builder = nil },
	{ id = "filters",      label = "Filters",       builder = nil },
	{ id = "colors",       label = "Colors",        builder = nil },
	{ id = "profiles",     label = "Profiles",      builder = nil },
	{ id = "about",        label = "About",         builder = nil },
}

local panel
local tabButtons = {}
local tabContents = {}
local currentTabID


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
				sub:SetText("This tab is not yet implemented in v" .. ns.CONST.VERSION .. ".")
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
	for _, def in ipairs(TABS) do
		local btn = tabButtons[def.id]
		if btn then btn:SetSelected(def.id == id) end
		local frame = tabContents[def.id]
		if frame then frame:Hide() end
	end
	GetOrCreateTabContent(id):Show()
end


function ns.Options_Toggle()
	if not panel then BuildPanel() end
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
		ns.Options_SelectTab(currentTabID or "global")
	end
end


local function BuildGlobalTab(content)
	local CDM = ns.CDM
	local pad = Theme.PANEL.CONTENT_PAD

	local section = Theme.CreateHeader(content, "Enabled:", "GameFontNormal")
	section:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local function MakeCheck(label, key, anchor, xOff)
		local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff or 0, -4)
		cb:SetSize(24, 24)
		local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		fs:SetText(label)
		cb:SetChecked(CDM.db.profile.global[key])
		cb:SetScript("OnClick", function(self)
			CDM.db.profile.global[key] = self:GetChecked() and true or false
			-- Per-tick config apply is gone, so push the drag-label repaint explicitly.
			if key == "unlockFrames" then
				if ns.Lanes_RefreshUnlockState then ns.Lanes_RefreshUnlockState(CDM) end  -- also re-applies visibility
				if ns.ReadyFrames_RefreshUnlockState then ns.ReadyFrames_RefreshUnlockState(CDM) end
			elseif (key == "enabledAlways" or key == "autohide")
				and ns.Lanes_RefreshVisibility then
				ns.Lanes_RefreshVisibility()
			end
		end)
		return cb
	end

	local cbAlways   = MakeCheck("Always",      "enabledAlways",   section, 0)
	local cbGroup    = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbGroup:SetPoint("LEFT", cbAlways, "RIGHT", 120, 0)
	cbGroup:SetSize(24, 24)
	local fsg = cbGroup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsg:SetPoint("LEFT", cbGroup, "RIGHT", 4, 0); fsg:SetText("In Group")
	cbGroup:SetChecked(CDM.db.profile.global.enabledGroup)
	cbGroup:SetScript("OnClick", function(self)
		CDM.db.profile.global.enabledGroup = self:GetChecked() and true or false
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)

	local cbInst = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbInst:SetPoint("LEFT", cbGroup, "RIGHT", 120, 0)
	cbInst:SetSize(24, 24)
	local fsi = cbInst:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsi:SetPoint("LEFT", cbInst, "RIGHT", 4, 0); fsi:SetText("In Instance")
	cbInst:SetChecked(CDM.db.profile.global.enabledInstance)
	cbInst:SetScript("OnClick", function(self)
		CDM.db.profile.global.enabledInstance = self:GetChecked() and true or false
		if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
	end)

	local prev = cbAlways
	local toggles = {
		{ "Unlock Frames",         "unlockFrames"   },
		{ "Auto-hide Frames",      "autohide"       },
		{ "Enable tooltips",       "enableTooltip"  },
		{ "Detect Shared Spell Cooldowns", "detectSharedCD" },
		{ "Tint Unusable Icons",   "notUsableTint"  },
	}
	for _, t in ipairs(toggles) do
		prev = MakeCheck(t[1], t[2], prev, 0)
	end

	local testBtn = Theme.CreateButton(content, "Toggle Test Mode", 180, 30)
	testBtn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -24)
	testBtn:SetScript("OnClick", function()
		CDM:ToggleTestMode()
	end)
end

for _, def in ipairs(TABS) do
	if def.id == "global" then def.builder = BuildGlobalTab end
end


local LANES_INNER_RAIL_W = 160
local LANES_SECTION_LIST = {
	{ id = "general",    label = "General",    active = true  },
	{ id = "appearance", label = "Appearance", active = true  },
	{ id = "icons",      label = "Icons",      active = true  },
	{ id = "stacking",   label = "Stacking",   active = true  },
	{ id = "text",       label = "Text",       active = true  },
}

local ANCHOR_OPTIONS = {
	{ value = "TOPLEFT",     text = "Top Left"     },
	{ value = "TOP",         text = "Top"          },
	{ value = "TOPRIGHT",    text = "Top Right"    },
	{ value = "LEFT",        text = "Left"         },
	{ value = "CENTER",      text = "Center"       },
	{ value = "RIGHT",        text = "Right"        },
	{ value = "BOTTOMLEFT",  text = "Bottom Left"  },
	{ value = "BOTTOM",      text = "Bottom"       },
	{ value = "BOTTOMRIGHT", text = "Bottom Right" },
}

local MODE_OPTIONS = {
	{ value = "LINEAR",   text = "Linear"             },
	{ value = "TIMELINE", text = "Timeline (seconds)" },
}

local TRACKING_OPTIONS = {
	{ value = "NONE",  text = "None"  },
	{ value = "GCD",   text = "GCD"   },
	{ value = "SWING", text = "Swing" },
}

local TEXTURE_OPTIONS_FG = { { value = "CDM Smooth", text = "CDM Smooth" } }
local TEXTURE_OPTIONS_BORDER = { { value = "CDM Shadow", text = "CDM Shadow" } }


local lanesState = {
	laneIndex   = 1,
	sectionID   = "general",
	subTabBtns  = {},
	railRows    = {},
	formFrames  = {},
}

local YELLOW
local lanesPanelArea


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
		label = "Frame Name", value = cfg.frameName, width = 240, maxLetters = 32,
		onChange = function(text)
			cfg.frameName = text
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Enabled", checked = cfg.enabled,
		onChange = function(v)
			cfg.enabled = v
			RebuildLane(laneIndex)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Reversed", checked = cfg.reversed,
		onChange = function(v) cfg.reversed = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Vertical", checked = cfg.vertical,
		onChange = function(v) cfg.vertical = v; RefreshLane(laneIndex) end,
	}))

	local secMode = W.CreateSectionHeader(parent, "Mode")
	secMode:SetWidth(parent:GetWidth() - pad * 2)
	place(secMode, 18)

	place(W.CreateDropdown(parent, {
		label = "Mode", value = cfg.mode, options = MODE_OPTIONS, width = 200,
		onChange = function(v) cfg.mode = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = "Max Time (seconds)", min = 10, max = 180, step = 1,
		value = cfg.maxTime, width = 240,
		onChange = function(v) cfg.maxTime = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Hide Long Timers", checked = cfg.hideLongTimers,
		onChange = function(v) cfg.hideLongTimers = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Override Autohide", checked = cfg.overrideAutohide,
		onChange = function(v)
			cfg.overrideAutohide = v
			RefreshLane(laneIndex)
			if ns.Lanes_RefreshVisibility then ns.Lanes_RefreshVisibility() end
		end,
	}))

	-- On Midnight retail, Blizzard's Cooldown Manager owns secondary tracking, so hide these controls.
	if not ns.Compat.IS_RETAIL then
		local secTrack = W.CreateSectionHeader(parent, "Secondary Tracking")
		secTrack:SetWidth(parent:GetWidth() - pad * 2)
		place(secTrack, 18)

		place(W.CreateDropdown(parent, {
			label = "Primary Tracking", value = cfg.primaryTracking,
			options = TRACKING_OPTIONS, width = 200,
			onChange = function(v) cfg.primaryTracking = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateCheckbox(parent, {
			label = "Reverse Primary", checked = cfg.primaryReverse,
			onChange = function(v) cfg.primaryReverse = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateDropdown(parent, {
			label = "Secondary Tracking", value = cfg.secondaryTracking,
			options = TRACKING_OPTIONS, width = 200,
			onChange = function(v) cfg.secondaryTracking = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateCheckbox(parent, {
			label = "Reverse Secondary", checked = cfg.secondaryReverse,
			onChange = function(v) cfg.secondaryReverse = v; RefreshLane(laneIndex) end,
		}))

		place(W.CreateSlider(parent, {
			label = "ST Width", min = 1, max = 60, step = 1,
			value = cfg.stWidth, width = 220,
			onChange = function(v) cfg.stWidth = v; RefreshLane(laneIndex) end,
		}))
		place(W.CreateSlider(parent, {
			label = "ST Height", min = 1, max = 120, step = 1,
			value = cfg.stHeight, width = 220,
			onChange = function(v) cfg.stHeight = v; RefreshLane(laneIndex) end,
		}))

		local stTexDD = W.CreateDropdown(parent, {
			label = "ST Texture", value = cfg.stTexture,
			options = TEXTURE_OPTIONS_FG, width = 200,
			onChange = function(v) cfg.stTexture = v; RefreshLane(laneIndex) end,
		})
		stTexDD:SetEnabled(false)  -- only one entry; locked until v0.3 LSM hookup
		place(stTexDD)

		place(W.CreateColorPicker(parent, {
			label = "ST Color", color = cfg.stColor, hasAlpha = true,
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
		label = "Width", min = 1, max = 600, step = 1,
		value = cfg.width, width = 240,
		onChange = function(v) cfg.width = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Height", min = 1, max = 600, step = 1,
		value = cfg.height, width = 240,
		onChange = function(v) cfg.height = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "X Offset", min = -500, max = 500, step = 1,
		value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Y Offset", min = -500, max = 500, step = 1,
		value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateDropdown(parent, {
		label = "Anchor", value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		onChange = function(v) cfg.anchor = v; RefreshLane(laneIndex) end,
	}))

	local secFG = W.CreateSectionHeader(parent, "Foreground")
	secFG:SetWidth(parent:GetWidth() - pad * 2)
	place(secFG, 18)

	local fgTexDD = W.CreateDropdown(parent, {
		label = "Foreground Texture", value = cfg.fgTexture,
		options = TEXTURE_OPTIONS_FG, width = 200,
		onChange = function(v) cfg.fgTexture = v; RefreshLane(laneIndex) end,
	})
	fgTexDD:SetEnabled(false)
	place(fgTexDD)

	place(W.CreateColorPicker(parent, {
		label = "Foreground Color", color = cfg.fgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.fgColor.r, cfg.fgColor.g, cfg.fgColor.b, cfg.fgColor.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))
	place(W.CreateCheckbox(parent, {
		label = "Use Class Color (Foreground)", checked = cfg.fgClassColor,
		onChange = function(v) cfg.fgClassColor = v; RefreshLane(laneIndex) end,
	}))

	local secBG = W.CreateSectionHeader(parent, "Background")
	secBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBG, 18)

	local bgTexDD = W.CreateDropdown(parent, {
		label = "Background Texture", value = cfg.bgTexture,
		options = TEXTURE_OPTIONS_FG, width = 200,
		onChange = function(v) cfg.bgTexture = v; RefreshLane(laneIndex) end,
	})
	bgTexDD:SetEnabled(false)
	place(bgTexDD)

	place(W.CreateColorPicker(parent, {
		label = "Background Color", color = cfg.bgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.bgColor.r, cfg.bgColor.g, cfg.bgColor.b, cfg.bgColor.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))
	place(W.CreateCheckbox(parent, {
		label = "Use Class Color (Background)", checked = cfg.bgClassColor,
		onChange = function(v) cfg.bgClassColor = v; RefreshLane(laneIndex) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, "Border")
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = "Show Border", checked = cfg.borderEnabled ~= false,
		onChange = function(v)
			cfg.borderEnabled = v
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateSlider(parent, {
		label = "Lane Alpha", min = 0, max = 1, step = 0.05,
		value = cfg.alpha, width = 220,
		onChange = function(v) cfg.alpha = v; RefreshLane(laneIndex) end,
	}))

	local borderTexDD = W.CreateDropdown(parent, {
		label = "Border Texture", value = cfg.borderTexture,
		options = TEXTURE_OPTIONS_BORDER, width = 200,
		onChange = function(v) cfg.borderTexture = v; RefreshLane(laneIndex) end,
	})
	borderTexDD:SetEnabled(false)
	place(borderTexDD)

	place(W.CreateColorPicker(parent, {
		label = "Border Color", color = cfg.borderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a = r, g, b, a
			RefreshLane(laneIndex)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = "Border Padding", min = 0, max = 40, step = 1,
		value = cfg.borderPadding, width = 220,
		onChange = function(v) cfg.borderPadding = v; RefreshLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Border Size", min = 1, max = 40, step = 1,
		value = cfg.borderSize, width = 220,
		onChange = function(v) cfg.borderSize = v; RefreshLane(laneIndex) end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


local STACK_STYLE_OPTIONS = {
	{ value = "GROUPED", text = "Grouped"         },
	{ value = "SPREAD",  text = "Spread (coming soon)" },
}

local GROW_DIR_H = {
	{ value = "UP",   text = "Up"   },
	{ value = "DOWN", text = "Down" },
}

local GROW_DIR_V = {
	{ value = "LEFT",  text = "Left"  },
	{ value = "RIGHT", text = "Right" },
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
		label = "Enabled", checked = cfg.stackEnabled,
		onChange = function(v)
			cfg.stackEnabled = v
			RefreshLane(laneIndex)
		end,
	}))

	place(W.CreateCheckbox(parent, {
		label = "Raise On Mouseover", checked = cfg.stackRaiseHover,
		onChange = function(v)
			cfg.stackRaiseHover = v
			-- No refresh needed: OnEnter/OnLeave handlers are always attached.
		end,
	}))

	local secBeh = W.CreateSectionHeader(parent, "Behavior")
	secBeh:SetWidth(parent:GetWidth() - pad * 2)
	place(secBeh, 18)

	place(W.CreateDropdown(parent, {
		label = "Stack Style", value = cfg.stackStyle, options = STACK_STYLE_OPTIONS,
		width = 200,
		onChange = function(v) cfg.stackStyle = v; RefreshLane(laneIndex) end,
	}))

	-- Grow Direction options are snapshotted from cfg.vertical at first build; toggling Vertical updates them only on next visit (forms build lazily per-lane per-section).
	local growOpts = cfg.vertical and GROW_DIR_V or GROW_DIR_H
	place(W.CreateDropdown(parent, {
		label = "Grow Direction", value = cfg.stackGrowDirection,
		options = growOpts, width = 200,
		onChange = function(v) cfg.stackGrowDirection = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = "Height", min = 0, max = 300, step = 5,
		value = cfg.stackHeight, width = 240,
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
		label = "Size", min = 1, max = 128, step = 1,
		value = cfg.iconSize, width = 240,
		onChange = function(v) cfg.iconSize = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = "Transparency", min = 0, max = 1, step = 0.05,
		value = cfg.iconAlpha, width = 240,
		onChange = function(v) cfg.iconAlpha = v; RefreshLane(laneIndex) end,
	}))

	place(W.CreateSlider(parent, {
		label = "Offset", min = -30, max = 30, step = 1,
		value = cfg.iconOffset, width = 240,
		onChange = function(v) cfg.iconOffset = v; RefreshLane(laneIndex) end,
	}))

	local secTxt = W.CreateSectionHeader(parent, "Icon Text")
	secTxt:SetWidth(parent:GetWidth() - pad * 2)
	place(secTxt, 18)

	local slotLabels = { "Slot 1 (Charges)", "Slot 2 (Timer)", "Slot 3" }
	for i = 1, 3 do
		local slot = cfg.iconText and cfg.iconText[i]
		place(W.CreateCheckbox(parent, {
			label = slotLabels[i] .. " enabled",
			checked = slot and slot.enabled or false,
			onChange = function(v)
				if cfg.iconText and cfg.iconText[i] then
					cfg.iconText[i].enabled = v
				end
				RefreshLane(laneIndex)
			end,
		}))
	end

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
		local secDef = W.CreateSectionHeader(parent, "Default Text")
		secDef:SetWidth(parent:GetWidth() - pad * 2)
		place(secDef, 18)
	end

	for i = 1, 5 do
		local def = cfg.laneText and cfg.laneText[i]
		if def then
			local label = string.format("Show \"%s\"", def.text or ("Marker " .. i))
			place(W.CreateCheckbox(parent, {
				label = label, checked = def.enabled,
				onChange = function(v)
					cfg.laneText[i].enabled = v
					RefreshLane(laneIndex)
				end,
			}))
		end
	end

	parent:SetHeight(math.abs(y) + pad)
end


local function BuildLaneFormSurface(panelArea, laneIndex, sectionID)
	local scroll = CreateFrame("ScrollFrame", nil, panelArea, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panelArea, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", panelArea, "BOTTOMRIGHT", -22, 0)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(panelArea:GetWidth() - 26, 1)
	scroll:SetScrollChild(child)

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
	else
		local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("CENTER")
		fs:SetText("Coming in v0.3")
		fs:SetTextColor(0.7, 0.7, 0.7)
		child:SetHeight(60)
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
	surf:Show()

	lanesState.laneIndex = laneIndex
	lanesState.sectionID = sectionID

	for _, row in ipairs(lanesState.railRows) do
		local active = row._sectionID == sectionID
		if row._isActiveSection then
			row.text:SetTextColor(
				active and YELLOW.r or 1,
				active and YELLOW.g or 1,
				active and YELLOW.b or 1,
				1)
		end
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
		local b = Theme.CreateTab(subBar, "Lane " .. i, 90)
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
	lanesPanelArea = formArea

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
		row._isActiveSection = sec.active

		if sec.active then
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
		else
			fs:SetAlpha(0.5)
			fs:SetTextColor(1, 1, 1)
			row:EnableMouse(true)
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText("Coming in v0.3")
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		lanesState.railRows[#lanesState.railRows + 1] = row
		ry = ry - 26
	end

	ShowLaneSection(formArea, lanesState.laneIndex, lanesState.sectionID)
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
}

local function GetFilterCfg(key)
	return ns.CDM.db.profile.filters[key]
end

local function GetSpellOverride(spellID)
	local p = ns.CDM.db.profile
	p.spellOverrides = p.spellOverrides or {}
	p.spellOverrides[spellID] = p.spellOverrides[spellID] or {}
	return p.spellOverrides[spellID]
end

local FILTER_LANE_OPTIONS = {
	{ value = 0, text = "Default" },  -- 0 = nil sentinel; stored as nil
	{ value = 1, text = "Lane 1"  },
	{ value = 2, text = "Lane 2"  },
	{ value = 3, text = "Lane 3"  },
}

local FILTER_LANE_FOR_DEFAULTS = {
	{ value = 1, text = "Lane 1" },
	{ value = 2, text = "Lane 2" },
	{ value = 3, text = "Lane 3" },
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

	local y = -pad
	local function place(widget, height)
		widget:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
		y = y - (height or widget:GetHeight()) - rowGap
		return widget
	end

	local pickerLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pickerLabel:SetText("Pick a category to edit its defaults:")
	pickerLabel:SetTextColor(1, 1, 1)
	place(pickerLabel, 16)

	local hintLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hintLabel:SetText("These settings apply to every spell in the chosen category. To override an individual spell, use that category's sub-tab on the left.")
	hintLabel:SetTextColor(0.7, 0.7, 0.7)
	hintLabel:SetWidth(parent:GetWidth() - pad * 2 - 30)
	hintLabel:SetJustifyH("LEFT")
	place(hintLabel, 28)

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
		fs:SetText("Unknown category: " .. tostring(key))
		fs:SetTextColor(0.7, 0.4, 0.4)
		place(fs, 16)
		parent:SetHeight(math.abs(y) + pad)
		return
	end

	local label = key
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		if def.key == key then label = def.label; break end
	end

	local sec = W.CreateSectionHeader(parent, label .. " Defaults")
	sec:SetWidth(parent:GetWidth() - pad * 2)
	place(sec, 18)

	place(W.CreateCheckbox(parent, {
		label   = "Enabled",
		checked = cfg.enabled,
		onChange = function(v) cfg.enabled = v end,
	}))

	place(W.CreateCheckbox(parent, {
		label   = "Show by Default",
		checked = cfg.showByDefault,
		onChange = function(v) cfg.showByDefault = v end,
	}))

	place(W.CreateSlider(parent, {
		label = "Ignore Threshold (sec)", min = 5, max = 3600, step = 5,
		value = cfg.ignoreThreshold or 1800, width = 240,
		onChange = function(v) cfg.ignoreThreshold = v end,
	}))

	place(W.CreateDropdown(parent, {
		label = "Default Lane",
		value = cfg.defaultLane or 1,
		options = FILTER_LANE_FOR_DEFAULTS,
		width = 200,
		onChange = function(v) cfg.defaultLane = v end,
	}))

	parent:SetHeight(math.abs(y) + pad)
end


function ns.Options_UpdateTrackedItemDisplay(itemID, displayName, displayIcon)
	if not (filtersState.itemRows and filtersState.itemRows[itemID]) then return end
	local r = filtersState.itemRows[itemID]
	if displayName and r.name then r.name:SetText(displayName) end
	if displayIcon and r.icon then r.icon:SetTexture(displayIcon) end
end


-- Drop cached per-category list surfaces after Engine rebuilds the spell/item registries; without this each list is a one-time snapshot (stale after spec swap, "No spells discovered yet" sticking forever). Defaults stays cached as it only reflects saved settings.
function ns.Options_InvalidateFilterLists()
	for key, surf in pairs(filtersState.formFrames) do
		if key ~= "defaults" then
			surf:Hide()
			filtersState.formFrames[key] = nil
		end
	end
	if filtersState.itemRows then wipe(filtersState.itemRows) end
	if filtersState._refresh then filtersState._refresh() end
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
	name:SetText(info.name or ("Spell " .. spellID))
	name:SetTextColor(1, 1, 1)

	local override = GetSpellOverride(spellID)
	local categoryKey = ns.Engine and ns.Engine:GetCategoryFilterKey(info.category)
	local fcfg = categoryKey and GetFilterCfg(categoryKey)
	local effectiveVisible
	if override.visible ~= nil then
		effectiveVisible = override.visible
	else
		effectiveVisible = fcfg and fcfg.showByDefault ~= false
	end

	local cb = W.CreateCheckbox(row, {
		label = "Show",
		checked = effectiveVisible,
		onChange = function(v) override.visible = v end,
	})
	cb:SetPoint("LEFT", name, "RIGHT", 8, 0)

	local laneVal = override.lane or 0  -- 0 sentinel for "Default"
	local dd = W.CreateDropdown(row, {
		label = "",
		value = laneVal,
		options = FILTER_LANE_OPTIONS,
		width = 90,
		onChange = function(v)
			if v == 0 then
				override.lane = nil
			else
				override.lane = v
			end
		end,
	})
	dd:SetPoint("LEFT", cb, "RIGHT", 90, 0)

	-- Register item rows (keyed by itemID == spellID by convention) so async GET_ITEM_INFO_RECEIVED can update name/icon in place. Spells are always cached by build time.
	if info.kind == "item" then
		filtersState.itemRows = filtersState.itemRows or {}
		filtersState.itemRows[spellID] = { name = name, icon = tex }
	end

	return row, rowH
end


local function BuildFiltersSpellListForm(parent, categoryKey)
	local pad = 12
	local rowGap = 4

	-- Items live in a parallel table (Engine:BuildTrackedItems); rows key on .spellID, which is itemID for items. Reset itemRows so stale FontString refs can't SetText a no-longer-shown row.
	if categoryKey == "potions" and filtersState.itemRows then
		wipe(filtersState.itemRows)
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

	table.sort(matches, function(a, b)
		local an = (a.info.name or ""):lower()
		local bn = (b.info.name or ""):lower()
		if an == bn then return a.spellID < b.spellID end
		return an < bn
	end)

	if #matches == 0 then
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, -pad)
		fs:SetText("No spells discovered yet for this category.\nLog in or /reload to populate the list.")
		fs:SetTextColor(0.7, 0.7, 0.7)
		fs:SetJustifyH("LEFT")
		parent:SetHeight(80)
		return
	end

	local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, -pad)
	header:SetText(string.format("%d spells tracked. Toggle visibility and override lane routing per spell.", #matches))
	header:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)

	local y = -pad - 22
	for _, item in ipairs(matches) do
		local _, h = BuildSpellRow(parent, item.spellID, item.info, y)
		y = y - h - rowGap
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
	elseif subTabKey == "spells"  or subTabKey == "items"
	    or subTabKey == "buffs"   or subTabKey == "debuffs"
	    or subTabKey == "potions" then
		BuildFiltersSpellListForm(child, subTabKey)
	else
		local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("CENTER")
		fs:SetText("Coming in v0.4")
		fs:SetTextColor(0.7, 0.7, 0.7)
		child:SetHeight(60)
	end

	scroll:Hide()
	return scroll
end


local function ShowFiltersSubTab(panelArea, subTabKey)
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
			if row.active then
				row.label:SetTextColor(1, 1, 1)
			else
				row.label:SetTextColor(0.45, 0.45, 0.45)
			end
			row.bg:Hide()
		end
	end
end


local function BuildFiltersTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, "Filters", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local rail = CreateFrame("Frame", nil, content)
	rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
	rail:SetSize(FILTERS_INNER_RAIL_W, 1)

	local formArea = CreateFrame("Frame", nil, content)
	formArea:SetPoint("TOPLEFT",     rail, "TOPRIGHT",    12, 0)
	formArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	wipe(filtersState.railRows)

	local railEntries = {
		{ key = "defaults", label = "Defaults", active = true },
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
		if not entry.active then
			label:SetTextColor(0.45, 0.45, 0.45)
		else
			label:SetTextColor(1, 1, 1)
		end

		row.bg     = bg
		row.label  = label
		row.key    = entry.key
		row.active = entry.active

		if entry.active then
			row:SetScript("OnClick", function()
				ShowFiltersSubTab(formArea, entry.key)
			end)
		else
			row:EnableMouse(false)
		end

		filtersState.railRows[#filtersState.railRows + 1] = row
		y = y - 24
	end

	filtersState._refresh = function()
		ShowFiltersSubTab(formArea, filtersState.selectedSubTab)
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


local function BuildColorsTab(content)
	local W = ns.Widgets
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, "Class Colors", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local tokens = ns.Compat.IS_RETAIL and CLASS_TOKENS_RETAIL or CLASS_TOKENS_CLASSIC

	local cols = 3
	local cellW = math.floor((Theme.PANEL.WIDTH - pad * 2 - 40) / cols)
	local cellH = 30

	for i, token in ipairs(tokens) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = pad + col * cellW
		local y = -(pad + 30 + row * cellH)

		local profile = ns.CDM.db.profile
		profile.classColors[token] = profile.classColors[token]
			or ns.CONST.CLASS_COLORS[token]
			or { r = 1, g = 1, b = 1, a = 1 }

		local cp = W.CreateColorPicker(content, {
			label = CLASS_DISPLAY_NAMES[token] or token,
			color = profile.classColors[token],
			hasAlpha = false,
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


StaticPopupDialogs["COOLDOWNMASTER_RESET_PROFILE"] = {
	text = "Reset profile \"%s\" to default settings?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		local db = ns.CDM and ns.CDM.db
		if db then db:ResetProfile() end
	end,
	timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["COOLDOWNMASTER_DELETE_PROFILE"] = {
	text = "Delete profile \"%s\"? This cannot be undone.",
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


local function BuildProfilesTab(content)
	local db = ns.CDM and ns.CDM.db
	if not db then return end
	local W   = ns.Widgets
	local pad = Theme.PANEL.CONTENT_PAD

	local header = Theme.CreateHeader(content, "Profiles", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	local current = db:GetCurrentProfile()

	local curLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	curLabel:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -(pad + 26))
	curLabel:SetText("Current profile: |cffEBB706" .. current .. "|r")
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
		label = "Active profile", value = current, width = ddW, options = allOpts,
		onChange = function(v)
			if v and v ~= db:GetCurrentProfile() then db:SetProfile(v) end
		end,
	})
	switchDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
	y = y - step

	local newName = ""
	local newBox = W.CreateEditBox(content, {
		label = "New profile name", width = ddW, maxLetters = 32,
		onChange = function(t) newName = t end,
	})
	newBox:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
	local createBtn = Theme.CreateButton(content, "Create", 90, 24)
	createBtn:SetPoint("TOPLEFT", content, "TOPLEFT", btnX, y - 16)
	createBtn:SetScript("OnClick", function()
		local name = (newName or ""):trim()
		if name ~= "" then db:SetProfile(name) end
	end)
	y = y - step

	if #otherOpts > 0 then
		local copyTarget = otherOpts[1].value
		local copyDD = W.CreateDropdown(content, {
			label = "Copy settings from", value = copyTarget, width = ddW, options = otherOpts,
			onChange = function(v) copyTarget = v end,
		})
		copyDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
		local copyBtn = Theme.CreateButton(content, "Copy", 90, 24)
		copyBtn:SetPoint("TOPLEFT", content, "TOPLEFT", btnX, y - 16)
		copyBtn:SetScript("OnClick", function()
			if copyTarget and copyTarget ~= db:GetCurrentProfile() then
				db:CopyProfile(copyTarget)
			end
		end)
		y = y - step

		local delTarget = otherOpts[1].value
		local delDD = W.CreateDropdown(content, {
			label = "Delete profile", value = delTarget, width = ddW, options = otherOpts,
			onChange = function(v) delTarget = v end,
		})
		delDD:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y)
		local delBtn = Theme.CreateButton(content, "Delete", 90, 24)
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
		hint:SetText("Create another profile to enable Copy and Delete.")
		y = y - step
	end

	local resetBtn = Theme.CreateButton(content, "Reset current profile to defaults", 280, 28)
	resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", pad, y - 8)
	resetBtn:SetScript("OnClick", function()
		StaticPopup_Show("COOLDOWNMASTER_RESET_PROFILE", db:GetCurrentProfile())
	end)
end

for _, def in ipairs(TABS) do
	if def.id == "profiles" then def.builder = BuildProfilesTab end
end


function ns.Options_Rebuild()
	if not panel then return end
	for _, frame in pairs(tabContents) do
		frame:Hide()
		frame:SetParent(nil)
	end
	wipe(tabContents)
	wipe(lanesState.formFrames)
	wipe(filtersState.formFrames)
	filtersState.itemRows = nil
	ns.Options_SelectTab(currentTabID or "global")
end


local ABOUT_GOLD  = "|cffEBB706"
local ABOUT_MUTED = "|cffb3b3b3"
local ABOUT_WHITE = "|cffe6e6e6"
local ABOUT_CLOSE = "|r"

local ABOUT_GITHUB_URL   = "https://github.com/wheelbarrel00/CooldownMaster"
local ABOUT_BUG_URL      = "https://github.com/wheelbarrel00/CooldownMaster/issues"
local ABOUT_RELEASES_URL = "https://github.com/wheelbarrel00/CooldownMaster/releases"

local ABOUT_COMMANDS = {
	{ cmd = "/cdmaster",         desc = "Open or close the options window" },
	{ cmd = "/cdmaster lock",    desc = "Lock the lane frames" },
	{ cmd = "/cdmaster unlock",  desc = "Unlock the lane frames for moving" },
	{ cmd = "/cdmaster test",    desc = "Toggle sample cooldowns in Lane 1" },
	{ cmd = "/cdmaster reset",   desc = "Reset the current profile to defaults" },
	{ cmd = "/cdmaster version", desc = "Print the version and game flavor" },
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
		.. ABOUT_MUTED .. "    by Wheelbarrel00"
		.. "    -    for WoW Midnight (12.0.x)" .. ABOUT_CLOSE)
	Y = Y - 22

	body(ABOUT_WHITE .. "A timeline-style lane cooldown tracker that complements Blizzard's built-in Cooldown Manager." .. ABOUT_CLOSE)
	gap(10)

	linkRow({
		{ label = "Join our Discord", onClick = function() ns.ShowURL(ns.DISCORD_URL) end },
		{ label = "GitHub",           onClick = function() ns.ShowURL(ABOUT_GITHUB_URL) end },
		{ label = "Report a Bug",     onClick = function() ns.ShowURL(ABOUT_BUG_URL) end },
	})
	gap(8)

	header("Commands")
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
	body(ABOUT_MUTED .. "Tip: left-click the minimap button to open Options, right-click to lock or unlock frames." .. ABOUT_CLOSE, 0, 11)
	gap(10)

	header("Tutorials")
	body(ABOUT_MUTED .. "Video tutorials are coming soon." .. ABOUT_CLOSE)
	gap(10)

	header("More Add-ons by Wheelbarrel00")
	for _, a in ipairs(ABOUT_OTHER_ADDONS) do
		local n = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		n:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
		n:SetText(ABOUT_WHITE .. a.name .. ABOUT_CLOSE)
		local cfLink = makeLink("CurseForge", function() ns.ShowURL(a.cf) end)
		cfLink:SetPoint("LEFT", n, "LEFT", 200, 0)
		local sep = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		sep:SetText(ABOUT_MUTED .. "  |  " .. ABOUT_CLOSE)
		sep:SetPoint("LEFT", cfLink, "RIGHT", 2, 0)
		local ghLink = makeLink("GitHub", function() ns.ShowURL(a.gh) end)
		ghLink:SetPoint("LEFT", sep, "RIGHT", 2, 0)
		Y = Y - 20
	end
	gap(10)

	header("Thanks")
	body(ABOUT_WHITE .. "Built with feedback, reports, and ideas from the community. Thank you!" .. ABOUT_CLOSE)
	gap(10)

	header("Changelog")
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

	local older = makeLink("Older versions are on GitHub", function() ns.ShowURL(ABOUT_RELEASES_URL) end)
	older:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
	Y = Y - 28

	sc:SetHeight(math.max(1, -Y + 10))
	if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
end

for _, def in ipairs(TABS) do
	if def.id == "about" then def.builder = BuildAboutTab end
end


local READY_SECTION_LIST = {
	{ id = "general",    label = "General"    },
	{ id = "appearance", label = "Appearance" },
	{ id = "icons",      label = "Icons"      },
}

local READY_GROW_OPTIONS = {
	{ value = "DOWN", text = "Down" },
	{ value = "UP",   text = "Up"   },
}

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
	local opts = { { value = "None", text = "None" } }
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
		label = "Frame Name", value = cfg.frameName, width = 240, maxLetters = 32,
		onChange = function(t) cfg.frameName = t; ReadyApply(i) end,
	}))
	place(W.CreateCheckbox(parent, {
		label = "Enabled", checked = cfg.enabled,
		onChange = function(v)
			cfg.enabled = v
			if ns.ReadyFrames_RebuildOne then ns.ReadyFrames_RebuildOne(i) end
		end,
	}))
	place(W.CreateDropdown(parent, {
		label = "Grow Direction", value = cfg.growDirection, options = READY_GROW_OPTIONS, width = 200,
		onChange = function(v) cfg.growDirection = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Display Duration (sec)", min = 1, max = 20, step = 1, value = cfg.normalDuration, width = 240,
		onChange = function(v) cfg.normalDuration = v end,
	}))
	place(W.CreateDropdown(parent, {
		label = "Ready Sound", value = cfg.normalSound or "None", options = ReadySoundOptions(), width = 240,
		onChange = function(v) cfg.normalSound = v end,
	}))

	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetText("Tip: enable Unlock Frames on the Global tab, then drag this box into position.")
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
		label = "X Offset", min = -500, max = 500, step = 1, value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Y Offset", min = -500, max = 500, step = 1, value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; ReadyApply(i) end,
	}))
	place(W.CreateDropdown(parent, {
		label = "Anchor", value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		onChange = function(v) cfg.anchor = v; ReadyApply(i) end,
	}))

	local secBG = W.CreateSectionHeader(parent, "Background")
	secBG:SetWidth(parent:GetWidth() - pad * 2)
	place(secBG, 18)

	place(W.CreateColorPicker(parent, {
		label = "Background Color", color = cfg.bgColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.bgColor.r, cfg.bgColor.g, cfg.bgColor.b, cfg.bgColor.a = r, g, b, a
			ReadyApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = "Box Alpha", min = 0, max = 1, step = 0.05, value = cfg.alpha, width = 220,
		onChange = function(v) cfg.alpha = v; ReadyApply(i) end,
	}))

	local secBorder = W.CreateSectionHeader(parent, "Border")
	secBorder:SetWidth(parent:GetWidth() - pad * 2)
	place(secBorder, 18)

	place(W.CreateCheckbox(parent, {
		label = "Show Border", checked = cfg.borderEnabled ~= false,
		onChange = function(v) cfg.borderEnabled = v; ReadyApply(i) end,
	}))
	place(W.CreateColorPicker(parent, {
		label = "Border Color", color = cfg.borderColor, hasAlpha = true,
		onChange = function(r, g, b, a)
			cfg.borderColor.r, cfg.borderColor.g, cfg.borderColor.b, cfg.borderColor.a = r, g, b, a
			ReadyApply(i)
		end,
	}))
	place(W.CreateSlider(parent, {
		label = "Border Padding", min = 0, max = 40, step = 1, value = cfg.borderPadding, width = 220,
		onChange = function(v) cfg.borderPadding = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Border Size", min = 1, max = 40, step = 1, value = cfg.borderSize, width = 220,
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
		label = "Size", min = 1, max = 128, step = 1, value = cfg.iconSize, width = 240,
		onChange = function(v) cfg.iconSize = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Transparency", min = 0, max = 1, step = 0.05, value = cfg.iconAlpha, width = 240,
		onChange = function(v) cfg.iconAlpha = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Offset", min = -30, max = 30, step = 1, value = cfg.iconOffset, width = 240,
		onChange = function(v) cfg.iconOffset = v; ReadyApply(i) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Spacing", min = 0, max = 40, step = 1, value = cfg.yPadding, width = 240,
		onChange = function(v) cfg.yPadding = v; ReadyApply(i) end,
	}))

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

	-- A profile-switch rebuild recreates this tab's frames; drop cached form
	-- surfaces parented to the old (now orphaned) frame so they rebuild fresh.
	wipe(readyState.subTabBtns)
	wipe(readyState.railRows)
	wipe(readyState.formFrames)
	local x = 0
	for i = 1, 3 do
		local b = Theme.CreateTab(subBar, "Box " .. i, 90)
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
end

for _, def in ipairs(TABS) do
	if def.id == "ready" then def.builder = BuildReadyTab end
end
