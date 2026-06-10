--[[
	Cooldown Master - UI/Lanes.lua
	Lane frame creation and per-tick layout.

	v0 renderer: minimum viable. Horizontal layout, linear time mapping,
	one icon per engine entry, integer/decimal countdown text. Anything
	fancier (vertical lanes, log mode, stacking, animation, class colors,
	tooltips, borders) is marked TODO(rendering) where it would hook in.
--]]

local ADDON_NAME, ns = ...

-- Throttle timestamp for drag-failed warning (no longer used but kept
-- in case StartMoving is tried in a future build).
local _dragFailWarnTime = 0  -- luacheck: ignore


-- Pre-built lookup tables for cooldown countdown text. Built once at file
-- load to eliminate ~450 string.format allocations/sec the per-icon
-- OnUpdate (60 Hz) and the per-tick refresh (10 Hz × 3 lanes) produce
-- combined.
--
-- INTEGER_STRINGS covers 0..600 (10 minutes — fits every meaningful CD).
-- DECIMAL_STRINGS covers 0..100 representing "0.0" through "10.0" in 0.1
-- steps (the sub-10s range where we show one decimal of precision).
local INTEGER_STRINGS = {}
for i = 0, 600 do
	INTEGER_STRINGS[i] = tostring(i)
end

local DECIMAL_STRINGS = {}
for i = 0, 100 do
	DECIMAL_STRINGS[i] = string.format("%.1f", i / 10)
end

-- MINSEC_STRINGS covers 60..600 as "m:ss" (e.g. 119 -> "1:59"), except whole
-- minutes which collapse to a bare minute count (120 -> "2") so the boundary
-- reads "2", then "1:59", "1:58", ...
local MINSEC_STRINGS = {}
for i = 60, 600 do
	local m = math.floor(i / 60)
	local s = i % 60
	if s == 0 then
		MINSEC_STRINGS[i] = tostring(m)
	else
		MINSEC_STRINGS[i] = string.format("%d:%02d", m, s)
	end
end


-- Format remaining time. One decimal when <=10s, integer seconds up to 60s,
-- then m:ss (whole minutes shown bare). Hits the lookup tables above for the
-- common range; falls through to a live string.format only for unexpected
-- out-of-range values.
local function FormatTime(remaining)
	if remaining <= 10 then
		local idx = math.floor(remaining * 10 + 0.5)
		return DECIMAL_STRINGS[idx] or string.format("%.1f", remaining)
	end
	local idx = math.floor(remaining + 0.5)
	if idx < 60 then
		return INTEGER_STRINGS[idx] or string.format("%d", idx)
	end
	local s = idx % 60
	return MINSEC_STRINGS[idx]
		or (s == 0 and string.format("%d", idx / 60))
		or string.format("%d:%02d", math.floor(idx / 60), s)
end


-- Called from Init.OnEnteringWorld once the world is loaded.
function ns.Lanes_Build(addon)
	for i = 1, 3 do
		local cfg = addon.db.profile.lanes[i]
		if cfg.enabled and not addon.lanes[i] then
			ns.Lanes_CreateLane(addon, i, cfg)
		end
	end
end


function ns.Lanes_CreateLane(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Lane_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(cfg.width, cfg.height)
	f:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.x, cfg.y)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)   -- always on; OnMouseDown gates by unlockFrames
	f.laneIndex = index

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
		local laneCfg = cdm and cdm.db.profile.lanes[self.laneIndex]
		if laneCfg then
			laneCfg.anchor = point
			laneCfg.x = math.floor(x + 0.5)
			laneCfg.y = math.floor(y + 0.5)
		end
		if ns.Lanes_Refresh then ns.Lanes_Refresh(self.laneIndex) end
	end)

	f:SetScript("OnUpdate", function(self, elapsed)
		if not self._isDragging then return end

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
	end)

	if ns.Theme then
		ns.Theme.ApplyBackdrop(f,
			{ r = cfg.bgColor.r, g = cfg.bgColor.g, b = cfg.bgColor.b, a = cfg.bgColor.a },
			ns.CONST.RGB.PANEL_BORDER)
	end

	-- Lane label, only visible when frames are unlocked (mirrors CDTL2).
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("CENTER")
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	f.markers = {}
	for i = 1, 5 do
		local m = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		m:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
		m:Hide()
		f.markers[i] = m
	end

	-- Per-lane icon pool. Reused across refreshes; nothing is ever destroyed.
	f.iconPool   = {}
	f.activeIcons = 0
	f.cfg = cfg
	f.index = index

	addon.lanes[index] = f

	-- Apply full config (markers, label, border, alpha) once at creation.
	-- Marker positioning lives only in ApplyConfigBody, and the per-tick
	-- refresh no longer applies config -- without this call, lanes built at
	-- login would render with unpositioned markers.
	ns.Lanes_ApplyConfig(index)
end


-- Native cooldown countdown formatter. The remaining time is secret in combat,
-- so we cannot format it ourselves -- but the Cooldown widget calls this
-- privileged formatter with the (secret) value and renders the result. These
-- breakpoints are Blizzard's defaults minus the minute-collapse one, giving a
-- continuous clock: whole seconds under 1:00, then M:SS all the way up (instead
-- of the default that shows bare minutes like "4m" above 2 minutes).
local CDFormatter   -- nil = untried, false = unavailable, object = ready
local function GetCountdownFormatter()
	if CDFormatter ~= nil then return CDFormatter or nil end
	if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
		and Enum and Enum.NumericRuleFormatRounding) then
		CDFormatter = false
		return nil
	end
	local f = C_StringUtil.CreateNumericRuleFormatter()
	if not (f and f.SetBreakpoints) then
		CDFormatter = false
		return nil
	end
	local Up = Enum.NumericRuleFormatRounding.Up
	-- LS lacks the formatter's type def; SetBreakpoints takes the table (Skiron ships this).
	---@diagnostic disable-next-line: redundant-parameter
	f:SetBreakpoints({
		{ threshold = 0,  displayStyle = "secondsOnly", step = 1, rounding = Up, format = "%d" },
		{ threshold = 60, displayStyle = "clock",       step = 1, rounding = Up, format = "%d:%02d",
			components = { { div = 60 }, { mod = 60 } } },
	})
	CDFormatter = f
	return f
end


-- Acquire (or create) the i'th icon button on a lane frame.
local function AcquireIcon(laneFrame, i, iconSize)
	local pool = laneFrame.iconPool
	local btn  = pool[i]
	if btn then return btn end

	btn = CreateFrame("Frame", nil, laneFrame)
	btn:SetSize(iconSize, iconSize)

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trim default icon border

	-- Native cooldown swipe + countdown. In combat the remaining time is a
	-- secret value we cannot read (see docs/EXPERIMENTS.md), so we feed this
	-- widget the opaque DurationObject via SetCooldownFromDurationObject and let
	-- Blizzard render the exact swipe + number. Items / test use SetCooldown.
	btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	btn.cd:SetAllPoints(btn)
	btn.cd:SetDrawEdge(false)
	btn.cd:SetDrawBling(false)
	btn.cd:SetHideCountdownNumbers(false)
	if btn.cd.SetCountdownFormatter then
		local fmt = GetCountdownFormatter()
		if fmt then btn.cd:SetCountdownFormatter(fmt) end
	end

	btn.time = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.time:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
	btn.time:SetTextColor(1, 1, 1, 1)

	-- Charge count, bottom-left corner. Hidden by default; shown when the
	-- entry has charges/maxCharges set.
	btn.charges = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.charges:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
	btn.charges:SetTextColor(1, 1, 1, 1)
	btn.charges:Hide()

	-- TODO(rendering): class color tint overlay
	-- TODO(rendering): border texture (CDM Shadow / configured)
	-- TODO(rendering): tooltip on mouseover
	-- TODO(rendering): iconText[] templated strings (Defaults.iconText)

	-- Raise on mouseover: bump frame level on enter, restore on leave.
	-- stackRaiseHover controls whether stacking makes this meaningful;
	-- scripts are always attached (cheap, and avoids rewiring on toggle).
	btn:SetScript("OnEnter", function(self)
		if self:GetParent() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel() + 50)
		end
	end)
	btn:SetScript("OnLeave", function(self)
		if self:GetParent() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel() + 1)
		end
	end)

	btn:SetScript("OnUpdate", function(self)
		if not self._endTime then return end
		local remaining = self._endTime - GetTime()
		if remaining < 0 then remaining = 0 end   -- extrapolation underran; clamp to ready end
		local cfg = self._cfg
		if not cfg then return end
		self:SetAlpha((cfg.iconAlpha) or 1)
		local off      = cfg.iconOffset or 0
		local iconSize = self._iconSize or 40
		local progress = math.min(1, math.max(0, remaining / (self._duration or 120)))
		self:ClearAllPoints()
		if cfg.vertical then
			local laneH   = cfg.height or 400
			local usableH = math.max(1, laneH - iconSize)
			local y = progress * usableH
			if cfg.reversed then
				self:SetPoint("TOP", self:GetParent(), "TOP", off, -y)
			else
				self:SetPoint("BOTTOM", self:GetParent(), "BOTTOM", off, y)
			end
		else
			local laneW  = cfg.width or 400
			local usable = math.max(1, laneW - iconSize)
			local x = progress * usable
			if cfg.reversed then
				self:SetPoint("RIGHT", self:GetParent(), "RIGHT", -x, off)
			else
				self:SetPoint("LEFT", self:GetParent(), "LEFT", x, off)
			end
		end
		-- Countdown text is owned by the native Cooldown widget now.
	end)

	pool[i] = btn
	return btn
end


-- Apply non-structural lane config (size, position, alpha, colors). Cheap
-- enough to call every refresh; option-panel callbacks invoke it eagerly so
-- previewing values feels responsive.
-- Body extracted to a module-level function so the pcall wrapper below can
-- reference it by name instead of allocating a fresh closure every call.
-- Identical pcall behavior, identical taint protection — just no closure
-- churn at 30 Hz across 3 lanes.
local function ApplyConfigBody(laneIndex)
	local addon = ns.CDM
	if not addon then return end
	local laneFrame = addon.lanes and addon.lanes[laneIndex]
	if not laneFrame then return end
	local cfg = laneFrame.cfg
	if not cfg then return end

	-- Resolve foreground / background colors, optionally substituting the
	-- player's class color when fgClassColor / bgClassColor is set.
	local _, classToken = UnitClass("player")
	local classCol = classToken and addon.db.profile.classColors[classToken]

	local bg = cfg.bgColor
	if cfg.bgClassColor and classCol then bg = classCol end

	-- Backdrop application. Two competing concerns:
	--   1. Allocation pressure — calling SetBackdrop with a fresh table
	--      every refresh allocates two tables (outer + insets) at ~30 Hz
	--      across 3 lanes (~3,600 allocs/min).
	--   2. Live updates — Blizzard's BackdropTemplateMixin reference-
	--      compares the backdropInfo table and skips work when the same
	--      reference comes back. Mutating the cached fields is invisible
	--      to that comparison, so border-size/border-color tweaks didn't
	--      take effect until /reload re-created the lane frame.
	-- Solution: cache the table for the steady-state case (nothing
	-- changed → reuse → no allocation, no SetBackdrop call needed), but
	-- detect structural changes and swap in a fresh reference so
	-- SetBackdrop re-applies. Allocation only happens when the user
	-- actually tweaks border settings.
	local borderOn = cfg.borderEnabled ~= false
	local edgeFile = borderOn and "Interface\\Buttons\\WHITE8x8" or ""
	local edgeSize = borderOn and (cfg.borderSize or 1) or 0
	local pad      = borderOn and (cfg.borderPadding or 0) or 0
	local bd = laneFrame._backdropCache
	local needsNew = (not bd)
		or bd.edgeFile ~= edgeFile
		or bd.edgeSize ~= edgeSize
		or bd.insets.left ~= pad
	if needsNew then
		bd = {
			bgFile   = "Interface\\Buttons\\WHITE8x8",
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets   = { left = pad, right = pad, top = pad, bottom = pad },
		}
		laneFrame._backdropCache = bd
		pcall(laneFrame.SetBackdrop, laneFrame, bd)
	end
	pcall(laneFrame.SetBackdropColor, laneFrame, bg.r, bg.g, bg.b, bg.a or 1)
	if borderOn then
		local bc = cfg.borderColor
		if bc then
			pcall(laneFrame.SetBackdropBorderColor, laneFrame,
				bc.r, bc.g, bc.b, bc.a or 1)
		end
	else
		pcall(laneFrame.SetBackdropBorderColor, laneFrame, 0, 0, 0, 0)
	end

	laneFrame:SetSize(cfg.width, cfg.height)
	-- Do not reposition while the user is dragging — would fight the mouse.
	-- IsMoving may not exist on all frame types; guard defensively.
	local isMoving = laneFrame.IsMoving and laneFrame:IsMoving()
	if not isMoving then
		laneFrame:ClearAllPoints()
		laneFrame:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.x, cfg.y)
	end
	laneFrame:SetAlpha(cfg.alpha or 1)

	if laneFrame.label then
		laneFrame.label:SetText(cfg.frameName or "")
		laneFrame.label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	end

	if laneFrame.markers and cfg.laneText then
		for i = 1, 5 do
			local m = laneFrame.markers[i]
			local def = cfg.laneText[i]
			if m and def then
				if def.enabled then
					m:SetText(def.text or "")
					m:ClearAllPoints()
					local pos = def.pos or 0
					if cfg.reversed then pos = 1 - pos end
					if cfg.vertical then
						local laneH = cfg.height or 400
						if i == 1 then
							m:SetPoint("BOTTOM", laneFrame, "BOTTOM", 0, 2)
						elseif i == 5 then
							m:SetPoint("TOP", laneFrame, "TOP", 0, -2)
						else
							m:SetPoint("CENTER", laneFrame, "BOTTOM", 0, pos * laneH)
						end
					else
						local laneW = cfg.width or 400
						if i == 1 then
							m:SetPoint("LEFT", laneFrame, "LEFT", 5, 0)
						elseif i == 5 then
							m:SetPoint("RIGHT", laneFrame, "RIGHT", -5, 0)
						else
							m:SetPoint("CENTER", laneFrame, "LEFT", pos * laneW, 0)
						end
					end
					m:Show()
				else
					m:Hide()
				end
			end
		end
	end
end


function ns.Lanes_ApplyConfig(laneIndex)
	local ok, err = pcall(ApplyConfigBody, laneIndex)
	if not ok then
		if not ns._lanesApplyConfigErr or (GetTime() - ns._lanesApplyConfigErr) > 5 then
			ns._lanesApplyConfigErr = GetTime()
			if _G.CooldownMaster then
				_G.CooldownMaster:Print("Lanes_ApplyConfig error: " .. tostring(err))
			end
		end
	end
end


-- Destroy and recreate one lane frame. Used by the Lanes options tab when a
-- structural change happens (enable/disable, size, anchor) so the new state
-- takes effect immediately.
function ns.Lanes_RebuildOne(laneIndex)
	local addon = ns.CDM
	if not addon or not addon.db then return end
	local cfg = addon.db.profile.lanes[laneIndex]
	if not cfg then return end

	local existing = addon.lanes and addon.lanes[laneIndex]
	if existing then
		existing:Hide()
		existing:SetParent(nil)
		addon.lanes[laneIndex] = nil
	end

	if cfg.enabled then
		ns.Lanes_CreateLane(addon, laneIndex, cfg)   -- applies config itself
	end
end


-- Body extracted to a module-level function so the pcall wrapper below can
-- reference it by name instead of allocating a fresh closure every call.
-- Identical pcall behavior, identical taint protection — just no closure
-- churn at 30 Hz across 3 lanes.
local function RefreshBody(laneIndex)
	local addon = ns.CDM
	if not addon then return end
	local laneFrame = addon.lanes and addon.lanes[laneIndex]
	if not laneFrame then return end
	local cfg = laneFrame.cfg
	if not cfg then return end

	-- ApplyConfig is NOT called here anymore. It used to run on every refresh
	-- (10 Hz x 3 lanes), re-anchoring the frame, re-setting the label, and
	-- repositioning all five markers each tick for config that almost never
	-- changes. Config is now applied explicitly: once at lane creation, and
	-- by every option-change path (the Lanes/Colors tab callbacks call
	-- Lanes_ApplyConfig before refreshing).

	local engine = ns.Engine
	local entries = engine and engine:GetActiveEntries() or nil

	local iconSize = cfg.iconSize or 40
	local laneW    = cfg.width    or 400
	local maxTime  = cfg.maxTime  or 120
	local now      = GetTime()
	local usable   = math.max(1, laneW - iconSize)

	-- Walk entries, place each one. Track count so we can hide leftovers.
	local i = 0
	if entries then
		for _, e in pairs(entries) do
			if e.endTime
				-- Only render entries routed to this lane. ResolveLaneIndex
				-- may shift over time as filter settings change, so we
				-- consult the latest cached value on each entry.
				and (e.laneIndex == laneIndex
				     or (e.laneIndex == nil and laneIndex == 1))
				-- Filter visibility check (category enabled + per-spell
				-- override + showByDefault fallback).
				and (engine:IsSpellVisible(e.spellID, e.category)) then
				local remaining = e.endTime - now
				-- Spell entries are kept alive by isActive (ScanSpells removes
				-- them at the true cooldown end), so render them even if our
				-- extrapolated remaining ran out -- position clamps at the ready
				-- end and the native widget shows the true countdown.
				if remaining > 0 or e._source == "isactive" then
					local hideForLong = remaining > maxTime and cfg.hideLongTimers
					if not hideForLong then
						i = i + 1
						local btn = AcquireIcon(laneFrame, i, iconSize)
						btn:SetSize(iconSize, iconSize)
						if e.icon then
							btn.tex:SetTexture(e.icon)
						else
							btn.tex:SetTexture(nil)
						end
						-- Feed the native cooldown once per cooldown instance,
						-- keyed on spellID+startTime so a reused pool slot re-feeds
						-- when it switches spells. The widget renders the exact
						-- swipe + countdown -- the only combat-safe way to show
						-- real remaining time (we never read the number ourselves).
						if btn._cdSpellID ~= e.spellID or btn._cdStart ~= e.startTime then
							btn._cdSpellID = e.spellID
							btn._cdStart   = e.startTime
							-- Prefer the opaque DurationObject (exact swipe +
							-- countdown in combat). But if it's missing OR the
							-- privileged setter throws (stale/secret handle, or a
							-- charge-duration object that resolved to nothing), the
							-- widget would be left with no cooldown at all -- a
							-- bright icon, no swipe, no number, pinned by isActive.
							-- So always fall back to plain extrapolated numbers,
							-- which still render a correct-looking countdown.
							local fed = false
							if e.dObj and btn.cd.SetCooldownFromDurationObject then
								fed = pcall(btn.cd.SetCooldownFromDurationObject, btn.cd, e.dObj)
							end
							if not fed and e.startTime and e.duration then
								btn.cd:SetCooldown(e.startTime, e.duration)   -- items / test / dObj-feed fallback
							end
							btn._cdFedPath = fed and "dObj" or "numbers"
							e._cdFedPath   = btn._cdFedPath   -- surfaced by /cdmaster debug
						end

						-- Native widget owns the countdown text; the slot-2 toggle
						-- just controls whether its number is drawn.
						local showTime = cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled
						btn.cd:SetHideCountdownNumbers(not showTime)
						btn.time:Hide()

						-- Slot 1 (charges) visibility — only when entry has charge data.
						if cfg.iconText and cfg.iconText[1] and cfg.iconText[1].enabled
							and e.charges and e.maxCharges then
							btn.charges:SetText(string.format("%d/%d", e.charges, e.maxCharges))
							btn.charges:Show()
						else
							btn.charges:Hide()
						end

						btn:Show()
					btn._endTime    = e.endTime
					btn._duration   = e.duration
					btn._cfg        = cfg
					btn._iconSize   = iconSize
					-- TODO(rendering): stacking — group icons within
						-- iconSize/2 of each other when cfg.stackEnabled
						-- TODO(rendering): animation tween between successive
						-- positions instead of snapping each tick
					end
				end
			end
		end
	end

	-- Hide pool slots beyond what we actually used this frame. Clear the native
	-- cooldown and instance keys so a reused slot re-feeds cleanly next time.
	for j = i + 1, laneFrame.activeIcons do
		local btn = laneFrame.iconPool[j]
		if btn then
			btn._endTime   = nil
			btn._cdSpellID = nil
			btn._cdStart   = nil
			if btn.cd then btn.cd:Clear() end
			btn:Hide()
		end
	end
	laneFrame.activeIcons = i
end


-- Re-render the given lane based on the engine's current entries.
-- Called from Engine:Tick() at ~10 Hz.
function ns.Lanes_Refresh(laneIndex)
	local ok, err = pcall(RefreshBody, laneIndex)
	if not ok then
		if not ns._lanesRefreshErr or (GetTime() - ns._lanesRefreshErr) > 5 then
			ns._lanesRefreshErr = GetTime()
			if _G.CooldownMaster then
				_G.CooldownMaster:Print("Lanes_Refresh error: " .. tostring(err))
			end
		end
	end
end


-- Update EnableMouse and label alpha on all existing lane frames without
-- rebuilding them. Called after /cdmaster lock|unlock.
function ns.Lanes_RefreshUnlockState(addon)
	-- EnableMouse is always true on lane frames; OnDragStart gates by
	-- unlockFrames. Only need to update the unlock label visibility here.
	for i = 1, 3 do
		local f = addon.lanes[i]
		if f and f.label then
			local unlocked = addon.db.profile.global.unlockFrames
			f.label:SetAlpha(unlocked and 0.6 or 0)
		end
	end
end


function ns.Lanes_OnCombatChange(inCombat)
	-- TODO: handle autohide on combat exit.
end


function ns.Lanes_RefreshVisibility()
	-- TODO: respect Always / In Group / In Instance toggles.
end
