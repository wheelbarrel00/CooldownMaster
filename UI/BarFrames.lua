--[[
	Cooldown Master - UI/BarFrames.lua
	Status-bar style cooldown frames (Bar Frame 1/2/3).

	Each Bar Frame is a container that holds N horizontal status bars — one per
	currently-active cooldown that routes here. Bar = icon on the left + a
	status bar on the right that empties as the cooldown ticks down + countdown
	text + spell name.

	Architecture mirrors UI/ReadyFrames.lua:
	  - Container has drag/persist/label/backdrop driven by ApplyConfig
	  - Per-frame OnUpdate runs at 60 Hz
	  - Throttled (~10 Hz) reconciliation against Engine.entries decides which
	    bars exist; per-frame value/text update keeps fill smooth at 60 Hz
	  - Routing: Bar Frame 1 with 1->2->3 fallback if 1 disabled

	v1 supports: vertical stack with UP/DOWN grow direction, single bar texture.
	Deferred: transition indicator, LEFT/RIGHT growth, custom bar textures
	via LSM dropdown.
--]]

local ADDON_NAME, ns = ...

-- Cached statusbar fallback texture
local DEFAULT_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function FormatTime(remaining)
	if remaining <= 10 then
		return string.format("%.1f", remaining)
	end
	return string.format("%d", math.floor(remaining + 0.5))
end


-- Acquire (or create) the i'th bar widget on a bar frame. Each bar is a
-- composite widget: container frame + icon texture + StatusBar + name text +
-- countdown text.
local function AcquireBar(f, index)
	local pool = f.barPool
	local bar  = pool[index]
	if bar then return bar end

	local cfg = f.cfg
	local barH = cfg.barHeight or 24
	local iconSize = cfg.iconSize or barH

	-- Container
	bar = CreateFrame("Frame", "CooldownMaster_BarFrame_"..f.index.."_Bar_"..index, f)
	bar:SetSize(cfg.barWidth or 240, barH)

	-- Icon on the left
	bar.icon = bar:CreateTexture(nil, "ARTWORK")
	bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
	bar.icon:SetSize(iconSize, iconSize)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- StatusBar fills the rest
	bar.sb = CreateFrame("StatusBar", nil, bar)
	bar.sb:SetPoint("LEFT",  bar.icon, "RIGHT", 0, 0)
	bar.sb:SetPoint("RIGHT", bar,      "RIGHT", 0, 0)
	bar.sb:SetHeight(barH)
	bar.sb:SetMinMaxValues(0, 1)
	bar.sb:SetValue(1)
	bar.sb:SetStatusBarTexture(cfg.barTexture or DEFAULT_BAR_TEXTURE)

	-- Background behind the StatusBar (shows as the empty portion)
	bar.sbBg = bar.sb:CreateTexture(nil, "BACKGROUND")
	bar.sbBg:SetAllPoints(bar.sb)
	bar.sbBg:SetTexture(cfg.barTexture or DEFAULT_BAR_TEXTURE)

	-- Name text, anchored LEFT inside the statusbar
	bar.name = bar.sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.name:SetPoint("LEFT", bar.sb, "LEFT", 4, 0)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetTextColor(1, 1, 1, 1)

	-- Countdown text, anchored RIGHT inside the statusbar
	bar.time = bar.sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.time:SetPoint("RIGHT", bar.sb, "RIGHT", -4, 0)
	bar.time:SetJustifyH("RIGHT")
	bar.time:SetTextColor(1, 1, 1, 1)

	bar:Hide()
	pool[index] = bar
	return bar
end


-- Apply per-bar config (texture, colors, geometry) to one bar widget.
-- Called when a bar is acquired or when ApplyConfig refreshes the frame.
local function PaintBar(bar, cfg)
	local barH     = cfg.barHeight or 24
	local iconSize = cfg.iconSize  or barH
	local barW     = cfg.barWidth  or 240

	bar:SetSize(barW, barH)
	bar.icon:SetSize(iconSize, iconSize)
	bar.sb:SetHeight(barH)

	bar.sb:SetStatusBarTexture(cfg.barTexture or DEFAULT_BAR_TEXTURE)
	local bc = cfg.barColor or { r = 1, g = 1, b = 1, a = 1 }
	bar.sb:SetStatusBarColor(bc.r, bc.g, bc.b, bc.a or 1)

	bar.sbBg:SetTexture(cfg.barTexture or DEFAULT_BAR_TEXTURE)
	local bg = cfg.barBgColor or { r = 0, g = 0, b = 0, a = 0.5 }
	bar.sbBg:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 1)

	if cfg.showName then bar.name:Show() else bar.name:Hide() end
	if cfg.showTime then bar.time:Show() else bar.time:Hide() end
end


-- Reposition all currently-shown bars in the frame based on grow direction
-- and padding. Also resizes the container to fit.
local function RelayoutBarFrame(f)
	local cfg      = f.cfg
	local barW     = cfg.barWidth  or 240
	local barH     = cfg.barHeight or 24
	local yPad     = cfg.yPadding  or 2
	local xPad     = cfg.xPadding  or 0
	local step     = barH + yPad
	local active   = {}

	for i = 1, #f.barPool do
		local bar = f.barPool[i]
		if bar and bar:IsShown() then
			active[#active + 1] = bar
		end
	end

	for k, bar in ipairs(active) do
		bar:ClearAllPoints()
		if cfg.growDirection == "DOWN" then
			bar:SetPoint("TOP", f, "TOP", xPad, -xPad - step * (k - 1))
		else  -- UP (default)
			bar:SetPoint("BOTTOM", f, "BOTTOM", xPad, xPad + step * (k - 1))
		end
	end

	local count = math.max(1, #active)
	f:SetSize(barW + xPad * 2, count * step - yPad + xPad * 2)
end


-- Find or create a bar slot for the given spellID. Reuses an unused slot if
-- one exists; otherwise extends the pool.
local function GetOrCreateBarForSpell(f, spellID, entry)
	-- Already showing this spell?
	for i = 1, #f.barPool do
		local bar = f.barPool[i]
		if bar and bar:IsShown() and bar._spellID == spellID then
			return bar
		end
	end
	-- Find a hidden pool slot
	for i = 1, #f.barPool do
		local bar = f.barPool[i]
		if bar and not bar:IsShown() then
			return AcquireBar(f, i)  -- already exists, just return
		end
	end
	-- Create a fresh slot
	local idx = #f.barPool + 1
	return AcquireBar(f, idx)
end


-- Walk Engine.entries and reconcile against currently-shown bars. New entries
-- get a bar; bars whose entry no longer exists get hidden and freed.
-- Returns true if the active set changed (so caller knows to relayout).
local function ReconcileBars(f)
	local addon = ns.CDM
	if not addon then return false end
	local engine = ns.Engine
	if not engine then return false end

	local entries = engine.entries or {}
	local cfg = f.cfg
	local now = GetTime()
	local changed = false

	-- Build a set of spellIDs that should currently have a bar
	local wanted = {}
	for spellID, entry in pairs(entries) do
		if entry.endTime and entry.endTime > now then
			wanted[spellID] = entry
		end
	end

	-- Remove bars whose spell is no longer in entries
	for i = 1, #f.barPool do
		local bar = f.barPool[i]
		if bar and bar:IsShown() then
			if not wanted[bar._spellID] then
				bar:Hide()
				bar._spellID = nil
				changed = true
			end
		end
	end

	-- Add bars for entries that don't have one yet
	for spellID, entry in pairs(wanted) do
		local found = false
		for i = 1, #f.barPool do
			local bar = f.barPool[i]
			if bar and bar:IsShown() and bar._spellID == spellID then
				found = true
				break
			end
		end
		if not found then
			local bar = GetOrCreateBarForSpell(f, spellID, entry)
			PaintBar(bar, cfg)
			bar._spellID  = spellID
			bar._endTime  = entry.endTime
			bar._duration = entry.duration
			bar.icon:SetTexture(entry.icon or "")
			bar.name:SetText(entry.name or "")
			bar:Show()
			changed = true
		end
	end

	return changed
end


-- Per-frame value/text update: smooth StatusBar fill and countdown text at
-- 60 Hz. Reads endTime/duration that were stashed on each bar by Reconcile.
local function UpdateBarValues(f)
	local now = GetTime()
	local cfg = f.cfg
	local showTime = cfg.showTime
	for i = 1, #f.barPool do
		local bar = f.barPool[i]
		if bar and bar:IsShown() and bar._endTime then
			local remaining = bar._endTime - now
			if remaining <= 0 then
				bar.sb:SetValue(0)
				if showTime then bar.time:SetText("0.0") end
			else
				local progress = remaining / (bar._duration or 1)
				if progress > 1 then progress = 1 end
				bar.sb:SetValue(progress)
				if showTime then bar.time:SetText(FormatTime(remaining)) end
			end
		end
	end
end


-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function ns.BarFrames_Build(addon)
	-- Defensive cleanup of saved values (in case of partial migrations)
	for i = 1, 3 do
		local cfg = addon.db.profile.barFrames[i]
		if cfg then
			if type(cfg.bgColor)     ~= "table" then cfg.bgColor     = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 } end
			if type(cfg.borderColor) ~= "table" then cfg.borderColor = { r = 0,   g = 0,   b = 0,   a = 1    } end
			if type(cfg.barColor)    ~= "table" then cfg.barColor    = { r = 0.92, g = 0.72, b = 0.02, a = 1 } end
			if type(cfg.barBgColor)  ~= "table" then cfg.barBgColor  = { r = 0.05, g = 0.05, b = 0.05, a = 0.6 } end
			if type(cfg.anchor)      ~= "string" then cfg.anchor   = "CENTER" end
			if type(cfg.x)           ~= "number" then cfg.x        = 0 end
			if type(cfg.y)           ~= "number" then cfg.y        = -120 end
			if type(cfg.barWidth)    ~= "number" then cfg.barWidth  = 240 end
			if type(cfg.barHeight)   ~= "number" then cfg.barHeight = 24 end
			if type(cfg.iconSize)    ~= "number" then cfg.iconSize  = 24 end
			if type(cfg.alpha)       ~= "number" then cfg.alpha     = 1.0 end
			if cfg.showName == nil then cfg.showName = true end
			if cfg.showTime == nil then cfg.showTime = true end
		end
	end

	for i = 1, 3 do
		local cfg = addon.db.profile.barFrames[i]
		if cfg.enabled and not addon.barFrames[i] then
			ns.BarFrames_CreateFrame(addon, i, cfg)
			ns.BarFrames_ApplyConfig(i)
		end
	end
end


function ns.BarFrames_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_BarFrame_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(cfg.barWidth or 240, cfg.barHeight or 24)
	f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -120)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.index    = index
	f.cfg      = cfg
	f.barPool  = {}
	f.activeBars = 0
	f._reconcileAccum = 0

	-- Drag handling (mirrors Lanes/ReadyFrames)
	f:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local cdm = _G.CooldownMaster
		if not (cdm and cdm.db and cdm.db.profile.global.unlockFrames) then return end
		local cursorX, cursorY = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		self._dragStartCursorX = cursorX / scale
		self._dragStartCursorY = cursorY / scale
		local point, _, _, x, y = self:GetPoint()
		self._dragStartFrameX = x
		self._dragStartFrameY = y
		self._dragStartPoint  = point
		self._isDragging      = true
	end)

	f:SetScript("OnMouseUp", function(self, button)
		if not self._isDragging then return end
		self._isDragging = false
		local point, _, _, x, y = self:GetPoint()
		local cdm = _G.CooldownMaster
		local bfCfg = cdm and cdm.db.profile.barFrames[self.index]
		if bfCfg then
			bfCfg.anchor = point
			bfCfg.x = math.floor(x + 0.5)
			bfCfg.y = math.floor(y + 0.5)
		end
	end)

	f:SetScript("OnUpdate", function(self, elapsed)
		-- Drag handling first
		if self._isDragging then
			local cursorX, cursorY = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			cursorX = cursorX / scale
			cursorY = cursorY / scale
			local dx = cursorX - self._dragStartCursorX
			local dy = cursorY - self._dragStartCursorY
			self:ClearAllPoints()
			self:SetPoint(
				self._dragStartPoint or "CENTER",
				UIParent,
				self._dragStartPoint or "CENTER",
				self._dragStartFrameX + dx,
				self._dragStartFrameY + dy
			)
			return
		end

		-- 60 Hz: smooth value + text update
		UpdateBarValues(self)

		-- ~10 Hz: reconcile against Engine.entries (add new bars, remove finished)
		self._reconcileAccum = (self._reconcileAccum or 0) + elapsed
		if self._reconcileAccum >= 0.1 then
			self._reconcileAccum = 0
			if ReconcileBars(self) then
				RelayoutBarFrame(self)
			end
		end
	end)

	-- Unlock-state label (matches Lanes/Ready pattern)
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("CENTER")
	label:SetText(cfg.frameName or ("Bar Frame " .. index))
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	addon.barFrames[index] = f
end


function ns.BarFrames_ApplyConfig(index)
	local ok, err = pcall(function()
		local addon = ns.CDM
		if not addon then return end
		local f = addon.barFrames and addon.barFrames[index]
		if not f then return end
		local cfg = addon.db.profile.barFrames[index]
		if not cfg then return end

		-- Repair guards (in case sliders ever wrote a scalar by accident)
		if type(cfg.bgColor)     ~= "table" then cfg.bgColor     = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 } end
		if type(cfg.borderColor) ~= "table" then cfg.borderColor = { r = 0,   g = 0,   b = 0,   a = 1    } end
		if type(cfg.barColor)    ~= "table" then cfg.barColor    = { r = 0.92, g = 0.72, b = 0.02, a = 1 } end
		if type(cfg.barBgColor)  ~= "table" then cfg.barBgColor  = { r = 0.05, g = 0.05, b = 0.05, a = 0.6 } end

		f.cfg = cfg

		-- Re-anchor (only if not currently dragging)
		local isMoving = f.IsMoving and f:IsMoving()
		if not isMoving then
			f:ClearAllPoints()
			f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -120)
		end

		-- Container backdrop
		local borderOn = cfg.borderEnabled == true
		local edgeFile = borderOn and "Interface\\Buttons\\WHITE8x8" or ""
		local edgeSize = borderOn and (cfg.borderSize or 1) or 0
		local bpad     = borderOn and (cfg.borderPadding or 0) or 0
		pcall(f.SetBackdrop, f, {
			bgFile   = "Interface\\Buttons\\WHITE8x8",
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets   = { left = bpad, right = bpad, top = bpad, bottom = bpad },
		})
		local bg = cfg.bgColor
		pcall(f.SetBackdropColor, f, bg.r, bg.g, bg.b, bg.a or 1)
		if borderOn then
			local bc = cfg.borderColor
			pcall(f.SetBackdropBorderColor, f, bc.r, bc.g, bc.b, bc.a or 1)
		else
			pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0)
		end
		f:SetAlpha(cfg.alpha or 1)

		-- Repaint each existing bar with current config
		for i = 1, #f.barPool do
			local bar = f.barPool[i]
			if bar then PaintBar(bar, cfg) end
		end

		-- Label
		if f.label then
			f.label:SetText(cfg.frameName or "")
			f.label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
		end

		RelayoutBarFrame(f)
	end)
	if not ok then
		if _G.CooldownMaster then
			_G.CooldownMaster:Print("BarFrames_ApplyConfig error: " .. tostring(err))
		end
	end
end


function ns.BarFrames_RebuildOne(index)
	local addon = ns.CDM
	if not addon or not addon.db then return end
	local cfg = addon.db.profile.barFrames[index]
	if not cfg then return end

	local existing = addon.barFrames and addon.barFrames[index]
	if existing then
		existing:Hide()
		existing:SetParent(nil)
		addon.barFrames[index] = nil
	end

	if cfg.enabled then
		ns.BarFrames_CreateFrame(addon, index, cfg)
		ns.BarFrames_ApplyConfig(index)
	end
end


function ns.BarFrames_RefreshUnlockState(addon)
	for i = 1, 3 do
		local f = addon.barFrames and addon.barFrames[i]
		if f and f.label then
			local unlocked = addon.db.profile.global.unlockFrames
			f.label:SetAlpha(unlocked and 0.6 or 0)
		end
	end
end
