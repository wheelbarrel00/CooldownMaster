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
		if remaining <= 0 then return end
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
		if remaining <= 10 then
			self.time:SetText(string.format("%.1f", remaining))
		else
			self.time:SetText(string.format("%d", math.floor(remaining + 0.5)))
		end
	end)

	pool[i] = btn
	return btn
end


-- Format remaining time. Integer seconds when >10, one decimal when <=10.
local function FormatTime(remaining)
	if remaining <= 10 then
		return string.format("%.1f", remaining)
	end
	return string.format("%d", math.floor(remaining + 0.5))
end


-- Apply non-structural lane config (size, position, alpha, colors). Cheap
-- enough to call every refresh; option-panel callbacks invoke it eagerly so
-- previewing values feels responsive.
function ns.Lanes_ApplyConfig(laneIndex)
	local ok, err = pcall(function()
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

		-- Apply full backdrop with live border settings so changes take effect
		-- immediately. Re-calling SetBackdrop each tick is cheap.
		local borderOn = cfg.borderEnabled ~= false
		local edgeFile = borderOn and "Interface\\Buttons\\WHITE8x8" or ""
		local edgeSize = borderOn and (cfg.borderSize or 1) or 0
		local pad      = borderOn and (cfg.borderPadding or 0) or 0
		pcall(laneFrame.SetBackdrop, laneFrame, {
			bgFile   = "Interface\\Buttons\\WHITE8x8",
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets   = { left = pad, right = pad, top = pad, bottom = pad },
		})
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
	end)
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
		ns.Lanes_CreateLane(addon, laneIndex, cfg)
		ns.Lanes_ApplyConfig(laneIndex)
	end
end


-- Re-render the given lane based on the engine's current entries.
-- Called from Engine:Tick() at ~10 Hz.
function ns.Lanes_Refresh(laneIndex)
	local ok, err = pcall(function()
		local addon = ns.CDM
		if not addon then return end
		local laneFrame = addon.lanes and addon.lanes[laneIndex]
		if not laneFrame then return end
		local cfg = laneFrame.cfg
		if not cfg then return end

		-- Apply per-tick config so option changes are visible immediately.
		ns.Lanes_ApplyConfig(laneIndex)

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
					if remaining > 0 then
						local hideForLong = (remaining > maxTime) and cfg.hideLongTimers
						if not hideForLong then
							i = i + 1
							local btn = AcquireIcon(laneFrame, i, iconSize)
							btn:SetSize(iconSize, iconSize)
							if e.icon then
								btn.tex:SetTexture(e.icon)
							else
								btn.tex:SetTexture(nil)
							end
							btn.time:SetText(FormatTime(remaining))

							-- Slot 2 (time text) visibility.
							if cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled then
								btn.time:Show()
							else
								btn.time:Hide()
							end

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

		-- Hide pool slots beyond what we actually used this frame.
		for j = i + 1, laneFrame.activeIcons do
			local btn = laneFrame.iconPool[j]
			if btn then
				btn._endTime = nil
				btn:Hide()
			end
		end
		laneFrame.activeIcons = i
	end)
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
