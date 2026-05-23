--[[
	Cooldown Master - UI/Options.lua

	Custom main panel hosting horizontal tabs along the top edge:
	  Global | Lanes | Ready | Bars | Filters | Colors | Profiles | Import/Export | Changelog

	Each tab populates a single content area below the tab bar. Sub-tabs
	(Lane 1/2/3, etc.) are built by the per-tab modules in this same folder.

	v0.1 status: panel + tab-switching is live. The Global tab is populated as
	a working example. Other tabs render a placeholder header until their
	modules are filled in.
--]]

local ADDON_NAME, ns = ...

local Theme = ns.Theme

-- Tab definitions. Each entry: { id, label, builder }
-- The builder is called once, the first time the tab is shown, and receives
-- the content frame to populate.
local TABS = {
	{ id = "global",       label = "Global",        builder = nil }, -- assigned below
	{ id = "lanes",        label = "Lanes",         builder = nil },
	{ id = "filters",      label = "Filters",       builder = nil },
	{ id = "colors",       label = "Colors",        builder = nil },
	{ id = "profiles",     label = "Profiles",      builder = nil },
	{ id = "importexport", label = "Import/Export", builder = nil },
	{ id = "changelog",    label = "Changelog",     builder = nil },
}

local panel  -- the main panel frame; created lazily on first open
local tabButtons = {}
local tabContents = {}
local currentTabID


-- ---------------------------------------------------------------------------
-- Panel construction
-- ---------------------------------------------------------------------------

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

	-- Header bar (yellow title, red close button)
	local header = Theme.CreateHeader(panel, ns.CONST.ADDON_DISPLAY)
	header:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)

	local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	versionText:SetPoint("LEFT", header, "RIGHT", 8, -1)
	versionText:SetText("v" .. ns.CONST.VERSION .. "  -  " .. ns.Compat.FlavorLabel())
	versionText:SetTextColor(0.7, 0.7, 0.7)

	local closeBtn = Theme.CreateButton(panel, "X", 28, 24)
	closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
	closeBtn:SetScript("OnClick", function() panel:Hide() end)

	-- Tab bar
	local tabBar = CreateFrame("Frame", nil, panel)
	tabBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  10, -Theme.PANEL.HEADER_H - 4)
	tabBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -Theme.PANEL.HEADER_H - 4)
	tabBar:SetHeight(Theme.PANEL.TAB_H)

	-- Content area (everything below the tabs)
	local content = CreateFrame("Frame", nil, panel,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	content:SetPoint("TOPLEFT",     tabBar, "BOTTOMLEFT",  0, -Theme.PANEL.TAB_GAP)
	content:SetPoint("BOTTOMRIGHT", panel,  "BOTTOMRIGHT", -10, 10)
	Theme.ApplyBackdrop(content,
		{ r = 0, g = 0, b = 0, a = 0.55 },
		ns.CONST.RGB.PANEL_BORDER)

	panel.content = content

	-- Build each tab button along the bar.
	local x = 0
	for _, def in ipairs(TABS) do
		local b = Theme.CreateTab(tabBar, def.label, 105)
		b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
		b:SetScript("OnClick", function() ns.Options_SelectTab(def.id) end)
		tabButtons[def.id] = b
		x = x + 105 + Theme.PANEL.TAB_GAP
	end
end


-- Sub-frame for a single tab's content. Created lazily.
local function GetOrCreateTabContent(id)
	if tabContents[id] then return tabContents[id] end

	local f = CreateFrame("Frame", nil, panel.content)
	f:SetAllPoints(panel.content)
	f:Hide()
	tabContents[id] = f

	-- Find the matching builder and run it.
	for _, def in ipairs(TABS) do
		if def.id == id then
			if def.builder then
				def.builder(f)
			else
				-- Placeholder for tabs we haven't filled in yet.
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


-- ---------------------------------------------------------------------------
-- Global tab (working example so v0.1 has at least one filled-in tab)
-- ---------------------------------------------------------------------------

local function BuildGlobalTab(content)
	local CDM = ns.CDM
	local pad = Theme.PANEL.CONTENT_PAD

	local section = Theme.CreateHeader(content, "Enabled:", "GameFontNormal")
	section:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)

	-- Three checkboxes in a row: Always / In Group / In Instance
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
	end)

	local cbInst = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	cbInst:SetPoint("LEFT", cbGroup, "RIGHT", 120, 0)
	cbInst:SetSize(24, 24)
	local fsi = cbInst:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fsi:SetPoint("LEFT", cbInst, "RIGHT", 4, 0); fsi:SetText("In Instance")
	cbInst:SetChecked(CDM.db.profile.global.enabledInstance)
	cbInst:SetScript("OnClick", function(self)
		CDM.db.profile.global.enabledInstance = self:GetChecked() and true or false
	end)

	-- Single-column toggles below.
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

	-- Test button at the bottom.
	local testBtn = Theme.CreateButton(content, "Open Test Panel", 180, 30)
	testBtn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -24)
	testBtn:SetScript("OnClick", function()
		CDM.testing = not CDM.testing
		CDM:Print("Test mode " .. (CDM.testing and "ON" or "OFF"))
	end)
end

-- Wire the Global builder into the TABS list.
for _, def in ipairs(TABS) do
	if def.id == "global" then def.builder = BuildGlobalTab end
end


-- ---------------------------------------------------------------------------
-- Lanes tab
--
-- Layout:
--   [Lane 1][Lane 2][Lane 3] sub-tabs at the top.
--   Left column (160px): inner-rail with section names. "General" and
--   "Appearance" are active. "Icons", "Stacking", "Text" are placeholders
--   for v0.3.
--   Right column: scrollable form for the selected section.
--
-- All field onChange callbacks call ns.Lanes_Refresh(laneIndex) to give an
-- immediate live preview. Structural changes (size/position/anchor) also
-- call ns.Lanes_RebuildOne(laneIndex).
-- ---------------------------------------------------------------------------

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
	{ value = "LINEAR", text = "Linear"      },
	{ value = "LOG",    text = "Linear (%)"  },
}

local TRACKING_OPTIONS = {
	{ value = "NONE",  text = "None"  },
	{ value = "GCD",   text = "GCD"   },
	{ value = "SWING", text = "Swing" },
}

local TEXTURE_OPTIONS_FG = { { value = "CDM Smooth", text = "CDM Smooth" } }
local TEXTURE_OPTIONS_BORDER = { { value = "CDM Shadow", text = "CDM Shadow" } }


-- Module-locals: which lane and section the user is currently viewing.
local lanesState = {
	laneIndex   = 1,
	sectionID   = "general",
	subTabBtns  = {},
	railRows    = {},
	formFrames  = {},  -- [laneIndex][sectionID] = scroll content frame
}

local YELLOW  -- assigned in BuildLanesTab once Constants are guaranteed loaded
local lanesPanelArea  -- captured form-area frame, set in BuildLanesTab


local function GetLaneCfg(laneIndex)
	return ns.CDM.db.profile.lanes[laneIndex]
end


local function RefreshLane(laneIndex)
	if ns.Lanes_Refresh then ns.Lanes_Refresh(laneIndex) end
end


local function RebuildLane(laneIndex)
	if ns.Lanes_RebuildOne then ns.Lanes_RebuildOne(laneIndex) end
end


-- Build the General form for the given lane. Parent must be a content frame
-- already sized inside the scroll child.
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
		onChange = function(v) cfg.overrideAutohide = v; RefreshLane(laneIndex) end,
	}))

	-- Secondary-tracking block. On Midnight, Blizzard's Cooldown Manager owns
	-- secondary tracking, so we hide these controls instead of letting the
	-- user think they configure something live.
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


-- Build the Appearance form.
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

	place(W.CreateSlider(parent, {
		label = "Width", min = 1, max = 600, step = 1,
		value = cfg.width, width = 240,
		onChange = function(v) cfg.width = v; RebuildLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Height", min = 1, max = 600, step = 1,
		value = cfg.height, width = 240,
		onChange = function(v) cfg.height = v; RebuildLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "X Offset", min = -500, max = 500, step = 1,
		value = cfg.x, width = 240,
		onChange = function(v) cfg.x = v; RebuildLane(laneIndex) end,
	}))
	place(W.CreateSlider(parent, {
		label = "Y Offset", min = -500, max = 500, step = 1,
		value = cfg.y, width = 240,
		onChange = function(v) cfg.y = v; RebuildLane(laneIndex) end,
	}))
	place(W.CreateDropdown(parent, {
		label = "Anchor", value = cfg.anchor, options = ANCHOR_OPTIONS, width = 200,
		onChange = function(v) cfg.anchor = v; RebuildLane(laneIndex) end,
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


-- ---------------------------------------------------------------------------
-- Stacking form
-- ---------------------------------------------------------------------------

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
			-- No immediate refresh needed; OnEnter/OnLeave handlers are
			-- always attached. Effect is only meaningful when stacking is on.
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

	-- Grow Direction options depend on cfg.vertical. The dropdown is built
	-- when this form is first shown; switching Vertical on the General tab
	-- and coming back here will rebuild the form with updated options on
	-- next visit (forms are built lazily per-lane per-section).
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


-- Build a scroll-frame + content child for a particular (lane, section).
-- Returns the outer scroll frame so the caller can show/hide it.
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
	-- Hide every previously built form for this lane, then show the requested
	-- one (build it lazily).
	lanesState.formFrames[laneIndex] = lanesState.formFrames[laneIndex] or {}
	for _, surf in pairs(lanesState.formFrames[laneIndex]) do
		surf:Hide()
	end
	-- Hide other lanes' forms too.
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

	-- Re-color the rail rows to indicate the active section.
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

	-- Re-color sub-tab buttons.
	for li, btn in ipairs(lanesState.subTabBtns) do
		btn:SetSelected(li == laneIndex)
	end
end


YELLOW = ns.CONST.RGB.YELLOW  -- module-local; used by ShowLaneSection above


local function BuildLanesTab(content)
	local pad = Theme.PANEL.CONTENT_PAD

	-- Sub-tab strip (Lane 1 / Lane 2 / Lane 3).
	local subBar = CreateFrame("Frame", nil, content)
	subBar:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -pad)
	subBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -pad, -pad)
	subBar:SetHeight(Theme.PANEL.TAB_H)

	wipe(lanesState.subTabBtns)
	local x = 0
	for i = 1, 3 do
		local b = Theme.CreateTab(subBar, "Lane " .. i, 90)
		b:SetPoint("TOPLEFT", subBar, "TOPLEFT", x, 0)
		-- OnClick is rebound below once lanesPanelArea exists.
		lanesState.subTabBtns[i] = b
		x = x + 90 + Theme.PANEL.TAB_GAP
	end

	-- Below the sub-tabs: a body frame that holds the rail + the form area.
	local body = CreateFrame("Frame", nil, content)
	body:SetPoint("TOPLEFT", subBar, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	-- Inner-rail (left column).
	local rail = CreateFrame("Frame", nil, body,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
	rail:SetWidth(LANES_INNER_RAIL_W)
	Theme.ApplyBackdrop(rail,
		{ r = 0, g = 0, b = 0, a = 0.4 }, ns.CONST.RGB.PANEL_BORDER)

	-- Form area (right column). Forms (one per lane+section) live inside.
	local formArea = CreateFrame("Frame", nil, body)
	formArea:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
	formArea:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
	lanesPanelArea = formArea

	-- Now that formArea exists, wire sub-tab clicks.
	for i, b in ipairs(lanesState.subTabBtns) do
		b:SetScript("OnClick", function()
			ShowLaneSection(formArea, i, lanesState.sectionID)
		end)
	end

	-- Build rail rows.
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

	-- Initial selection: Lane 1 / General.
	ShowLaneSection(formArea, lanesState.laneIndex, lanesState.sectionID)
end

-- Wire it in.
for _, def in ipairs(TABS) do
	if def.id == "lanes" then def.builder = BuildLanesTab end
end


-- ---------------------------------------------------------------------------
-- Filters tab — controls which discovered spells / items / buffs / debuffs
-- get rendered in lanes, plus per-spell lane routing overrides.
-- ---------------------------------------------------------------------------

local FILTERS_INNER_RAIL_W = 160

local filtersState = {
	selectedSubTab          = "defaults",  -- "defaults" or category key
	selectedDefaultsKey     = "spells",    -- which category's defaults are shown
	formFrames              = {},          -- [subTabKey] = scroll frame
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

-- Lane dropdown options (1/2/3) plus "Default" sentinel that maps to nil.
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

-- Categories the Defaults sub-tab can edit. Order matches FILTER_CATEGORIES.
local function BuildDefaultsCategoryDropdownOptions()
	local opts = {}
	for _, def in ipairs(ns.CONST.FILTER_CATEGORIES) do
		opts[#opts + 1] = { value = def.key, text = def.label }
	end
	return opts
end


-- Build the body of the Defaults sub-tab: a category-picker dropdown plus a
-- form showing the selected category's enabled / showByDefault / threshold /
-- defaultLane settings.
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

	-- Category picker. Two-line label: a clear primary instruction in white,
	-- and a smaller gray hint that explains the relationship between this
	-- panel and the per-category sub-tabs in the rail.
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
			-- Rebuild the form rows below for the new category by triggering
			-- a tab refresh (cheapest approach: hide/rebuild the surface).
			if filtersState.formFrames["defaults"] then
				filtersState.formFrames["defaults"]:Hide()
				filtersState.formFrames["defaults"] = nil
			end
			if filtersState._refresh then filtersState._refresh() end
		end,
	})
	place(categoryDropdown)

	-- Spacer
	y = y - 4

	-- Selected category's settings
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

	-- Find the display label for this category
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


-- Public hook called by Engine when an async GET_ITEM_INFO_RECEIVED arrives
-- for one of our tracked items. Updates the matching row's name + icon in
-- place — no frame creation/destruction, no allocation. If the Filters tab
-- form hasn't been built yet (or has no row for this itemID), it's a no-op
-- and the next BuildSpellRow call will pick up the now-cached values.
function ns.Options_UpdateTrackedItemDisplay(itemID, displayName, displayIcon)
	if not (filtersState.itemRows and filtersState.itemRows[itemID]) then return end
	local r = filtersState.itemRows[itemID]
	if displayName and r.name then r.name:SetText(displayName) end
	if displayIcon and r.icon then r.icon:SetTexture(displayIcon) end
end


-- One row inside a per-category spell list. Renders icon + name +
-- visible checkbox + lane dropdown. yPos is the TOPLEFT y of this row.
local function BuildSpellRow(parent, spellID, info, yPos)
	local W = ns.Widgets
	local rowH = 26

	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(parent:GetWidth() - 24, rowH)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yPos)

	-- Icon
	local tex = row:CreateTexture(nil, "ARTWORK")
	tex:SetSize(20, 20)
	tex:SetPoint("LEFT", row, "LEFT", 0, 0)
	if info.icon then tex:SetTexture(info.icon) end
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Name
	local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	name:SetPoint("LEFT", tex, "RIGHT", 8, 0)
	name:SetWidth(180)
	name:SetJustifyH("LEFT")
	name:SetText(info.name or ("Spell " .. spellID))
	name:SetTextColor(1, 1, 1)

	-- Visible checkbox (using a small inline checkbox via Widgets)
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

	-- Lane dropdown
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

	-- Register item rows so GET_ITEM_INFO_RECEIVED can update name/icon in
	-- place when async item data arrives. Keyed by itemID (== spellID for
	-- item entries by convention). Spells don't need this — their info is
	-- always cached by the time the row is built.
	if info.kind == "item" then
		filtersState.itemRows = filtersState.itemRows or {}
		filtersState.itemRows[spellID] = { name = name, icon = tex }
	end

	return row, rowH
end


-- Build the per-category spell list for Spells/Items/Buffs/Debuffs sub-tabs.
local function BuildFiltersSpellListForm(parent, categoryKey)
	local pad = 12
	local rowGap = 4

	-- Find all tracked spells/items matching this category. Items live in a
	-- parallel table populated by Engine:BuildTrackedItems; rows reuse the
	-- same shape (.spellID is the lookup key — for items, that's itemID).
	-- Reset the item-row registry so stale FontString refs from a previous
	-- build can't fire a SetText on a no-longer-shown row.
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

	-- Sort by name (stable)
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

	-- Header row
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


-- Build the scroll surface for one Filters sub-tab.
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
		-- Inactive category (offensives / petspells / custom)
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

	-- Update visual selected state on rail rows
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

	-- Left rail with sub-tab buttons
	local rail = CreateFrame("Frame", nil, content)
	rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
	rail:SetSize(FILTERS_INNER_RAIL_W, 1)

	-- Form area to the right of rail
	local formArea = CreateFrame("Frame", nil, content)
	formArea:SetPoint("TOPLEFT",     rail, "TOPRIGHT",    12, 0)
	formArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -pad, pad)

	wipe(filtersState.railRows)

	-- The "Defaults" entry at the top of the rail, then the FILTER_CATEGORIES.
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

	-- Refresh hook so the Defaults sub-tab dropdown can request a rebuild.
	filtersState._refresh = function()
		ShowFiltersSubTab(formArea, filtersState.selectedSubTab)
	end

	-- Initial selection
	ShowFiltersSubTab(formArea, filtersState.selectedSubTab)
end

for _, def in ipairs(TABS) do
	if def.id == "filters" then def.builder = BuildFiltersTab end
end


-- ---------------------------------------------------------------------------
-- Colors tab — class color overrides used by class-color toggles in Lanes.
-- ---------------------------------------------------------------------------

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

	-- 3 columns x N rows grid. Each cell gets a color picker.
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
				-- TODO(rendering): tell each lane that uses class color to redraw.
				if ns.Lanes_Refresh then
					for li = 1, 3 do ns.Lanes_Refresh(li) end
				end
			end,
		})
		cp:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
	end
end

for _, def in ipairs(TABS) do
	if def.id == "colors" then def.builder = BuildColorsTab end
end
