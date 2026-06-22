local ADDON_NAME, ns = ...

local _dragFailWarnTime = 0  -- luacheck: ignore


-- Prebuilt countdown-text tables avoid ~450 string.format allocs/sec from the
-- 60 Hz OnUpdate and 10 Hz x 3-lane refresh. INTEGER_STRINGS 0..600 (10 min);
-- DECIMAL_STRINGS 0..100 = "0.0".."10.0" in 0.1 steps (sub-10s precision).
local INTEGER_STRINGS = {}
for i = 0, 600 do
	INTEGER_STRINGS[i] = tostring(i)
end

local DECIMAL_STRINGS = {}
for i = 0, 100 do
	DECIMAL_STRINGS[i] = string.format("%.1f", i / 10)
end

-- MINSEC_STRINGS 60..600 as "m:ss", but whole minutes collapse to a bare count
-- (120 -> "2", then "1:59", "1:58", ...) rather than "2:00".
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


local function VisibilityGatePasses(g)
	if g.enabledAlways then return true end
	local pass = false
	if g.enabledGroup    and IsInGroup()    then pass = true end
	if g.enabledInstance and IsInInstance() then pass = true end
	return pass
end


local function LaneShouldShow(addon, cfg)
	local g = addon.db.profile.global
	-- Unlocked or test mode = positioning; force lanes on so they can be seen/dragged.
	if g.unlockFrames or (ns.Engine and ns.Engine.testActive) then return true end
	if not VisibilityGatePasses(g) then return false end
	if g.autohide and not addon.combat and not cfg.overrideAutohide then return false end
	return true
end


local function ApplyVisibility(addon)
	if not (addon and addon.db and addon.lanes) then return end
	for i = 1, 3 do
		local f = addon.lanes[i]
		if f and f.cfg then
			if LaneShouldShow(addon, f.cfg) then f:Show() else f:Hide() end
		end
	end
end


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

	f.iconPool   = {}
	f.activeIcons = 0
	f.cfg = cfg
	f.index = index

	addon.lanes[index] = f

	-- Required: marker positioning lives only in ApplyConfigBody and the per-tick
	-- refresh no longer applies config, so lanes built at login would otherwise
	-- render with unpositioned markers.
	ns.Lanes_ApplyConfig(index)
	ApplyVisibility(addon)
end


-- Remaining time is secret in combat, so we can't format it; the Cooldown widget
-- calls this privileged formatter with the secret value. Breakpoints = Blizzard
-- defaults minus the minute-collapse, giving whole seconds under 1:00 then M:SS
-- all the way up (default shows bare minutes like "4m" above 2 minutes).
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


local function AcquireIcon(laneFrame, i, iconSize)
	local pool = laneFrame.iconPool
	local btn  = pool[i]
	if btn then return btn end

	btn = CreateFrame("Frame", nil, laneFrame)
	btn:SetSize(iconSize, iconSize)

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trim default icon border

	-- In combat the remaining time is a secret value we cannot read (see
	-- docs/EXPERIMENTS.md), so we feed this widget the opaque DurationObject via
	-- SetCooldownFromDurationObject; items / test use SetCooldown.
	btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	btn.cd:SetAllPoints(btn)
	btn.cd:SetDrawEdge(false)
	btn.cd:SetDrawBling(false)
	btn.cd:SetHideCountdownNumbers(false)
	if btn.cd.SetCountdownFormatter then
		local fmt = GetCountdownFormatter()
		if fmt then btn.cd:SetCountdownFormatter(fmt) end
	end

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
		if remaining < 0 then remaining = 0 end
		local cfg = self._cfg
		if not cfg then return end
		self:SetAlpha((cfg.iconAlpha) or 1)
		local off      = cfg.iconOffset or 0
		local iconSize = self._iconSize or 40
		-- TIMELINE = shared seconds axis (position is real time-left scaled to maxTime);
		-- default = each icon spans the lane over its own cooldown.
		local denom = (cfg.mode == "TIMELINE") and (cfg.maxTime or 120) or (self._duration or 120)
		local progress = math.min(1, math.max(0, remaining / denom))
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
	end)

	pool[i] = btn
	return btn
end


-- Body extracted to a module-level function so the pcall wrapper can reference it
-- by name rather than allocating a fresh closure at 30 Hz across 3 lanes.
local function ApplyConfigBody(laneIndex)
	local addon = ns.CDM
	if not addon then return end
	local laneFrame = addon.lanes and addon.lanes[laneIndex]
	if not laneFrame then return end
	local cfg = laneFrame.cfg
	if not cfg then return end

	local _, classToken = UnitClass("player")
	local classCol = classToken and addon.db.profile.classColors[classToken]

	local bg = cfg.bgColor
	if cfg.bgClassColor and classCol then bg = classCol end

	-- BackdropTemplateMixin reference-compares the backdropInfo table and skips
	-- work on the same reference, so mutating cached fields silently fails until
	-- /reload. Cache the table for the steady state (no alloc), but on a
	-- structural change swap in a fresh reference so SetBackdrop re-applies.
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
	-- Don't reposition mid-drag (fights the mouse); IsMoving may be absent on
	-- some frame types, so guard the call.
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


-- Body extracted to a module-level function so the pcall wrapper can reference it
-- by name rather than allocating a fresh closure at 30 Hz across 3 lanes.
local function RefreshBody(laneIndex)
	local addon = ns.CDM
	if not addon then return end
	local laneFrame = addon.lanes and addon.lanes[laneIndex]
	if not laneFrame then return end
	local cfg = laneFrame.cfg
	if not cfg then return end

	-- Hidden by autohide / the visibility gate: clear the pool once so a re-show
	-- starts clean, then skip the per-tick render work (incl. lazy icon creation).
	if not laneFrame:IsShown() then
		for j = 1, laneFrame.activeIcons do
			local btn = laneFrame.iconPool[j]
			if btn then
				btn._endTime   = nil
				btn._cdSpellID = nil
				btn._cdStart   = nil
				if btn.cd then btn.cd:Clear() end
				btn:Hide()
			end
		end
		laneFrame.activeIcons = 0
		return
	end

	-- Deliberately does NOT call ApplyConfig: it used to run every refresh,
	-- repositioning markers each tick for config that rarely changes. Config is
	-- now applied only at creation and from the option-change paths.

	local engine = ns.Engine
	local entries = engine and engine:GetActiveEntries() or nil

	local iconSize = cfg.iconSize or 40
	local maxTime  = cfg.maxTime  or 120
	local now      = GetTime()

	local i = 0
	if entries then
		for _, e in pairs(entries) do
			if e.endTime
				-- e.laneIndex may shift as filter settings change, so read the
				-- latest cached value each pass (nil routes to lane 1).
				and (e.laneIndex == laneIndex
				     or (e.laneIndex == nil and laneIndex == 1))
				and (engine:IsSpellVisible(e.spellID, e.category)) then
				local remaining = e.endTime - now
				-- isActive entries are removed by ScanSpells at the true cooldown
				-- end, so render them even if our extrapolated remaining ran out.
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
						-- Feed the native cooldown once per instance, keyed on
						-- spellID+startTime so a reused pool slot re-feeds when it
						-- switches spells.
						if btn._cdSpellID ~= e.spellID or btn._cdStart ~= e.startTime then
							btn._cdSpellID = e.spellID
							btn._cdStart   = e.startTime
							-- Prefer the opaque DurationObject, but the privileged
							-- setter can throw on a stale/secret handle and leave the
							-- widget with no cooldown, so fall back to extrapolated
							-- numbers when it's missing or pcall fails.
							local fed = false
							if e.dObj and btn.cd.SetCooldownFromDurationObject then
								fed = pcall(btn.cd.SetCooldownFromDurationObject, btn.cd, e.dObj)
							end
							if not fed and e.startTime and e.duration then
								btn.cd:SetCooldown(e.startTime, e.duration)
							end
							btn._cdFedPath = fed and "dObj" or "numbers"
							e._cdFedPath   = btn._cdFedPath   -- surfaced by /cdmaster debug
						end

						-- The native widget owns the countdown text; this toggle only
						-- controls whether its number is drawn.
						local showTime = cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled
						btn.cd:SetHideCountdownNumbers(not showTime)

						btn:Show()
					btn._endTime    = e.endTime
					btn._duration   = e.duration
					btn._cfg        = cfg
					btn._iconSize   = iconSize
					end
				end
			end
		end
	end

	-- Clear the instance keys on unused pool slots so a reused slot re-feeds
	-- its cooldown cleanly next time.
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


function ns.Lanes_RefreshUnlockState(addon)
	for i = 1, 3 do
		local f = addon.lanes[i]
		if f and f.label then
			local unlocked = addon.db.profile.global.unlockFrames
			f.label:SetAlpha(unlocked and 0.6 or 0)
		end
	end
	-- Unlocking force-shows lanes, so lock-state changes can flip visibility.
	ApplyVisibility(addon)
end


function ns.Lanes_OnCombatChange(inCombat)
	ApplyVisibility(ns.CDM)
end


function ns.Lanes_RefreshVisibility()
	ApplyVisibility(ns.CDM)
end
