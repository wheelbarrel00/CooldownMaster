local ADDON_NAME, ns = ...
local L = ns.L


local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local WHITE8X8     = "Interface\\Buttons\\WHITE8x8"
local BOX_FADE_DUR = 0.3
local FILL_FLOOR   = 0.02   -- keep an isActive bar visibly non-empty while its true end is secret

local function StatusbarTex(name)
	return (LSM and LSM:Fetch("statusbar", name, true)) or WHITE8X8
end

local function ByRemainingDesc(a, b)
	local ae, be = a.endTime or 0, b.endTime or 0
	if ae ~= be then return ae > be end
	return (a.spellID or 0) < (b.spellID or 0)
end

local function ByRemainingAsc(a, b)
	local ae, be = a.endTime or 0, b.endTime or 0
	if ae ~= be then return ae < be end
	return (a.spellID or 0) < (b.spellID or 0)
end

local SHARED_CD_TOL = 0.5
-- The dedupe keeps the first of a merged group, so the last-used tiebreak is what decides which shared-cooldown item gets shown.
local function ByStartTime(a, b)
	if a.startTime ~= b.startTime then
		return (a.startTime or 0) < (b.startTime or 0)
	end
	local au, bu = ns.IsLastUsedItem(a), ns.IsLastUsedItem(b)
	if au ~= bu then return au end
	return (a.spellID or 0) < (b.spellID or 0)
end

local function BarFrameKeepShown(g)
	if not g then return false end
	if ns.Engine and ns.Engine.testActive then return true end
	if not g.autohide then return true end
	return false
end

local function BarFrameHasContent(f)
	for i = 1, #f.barPool do
		local b = f.barPool[i]
		if b and b:IsShown() then return true end
	end
	return false
end

local function UpdateBarHandle(f)
	if not f.dragHandle then return end
	local addon = ns.CDM
	local g = addon and addon.db and addon.db.profile.global
	-- The frame is still shown while it fades out, so the not-shown gate keeps the drag tag off the fading backdrop.
	local shown = g and g.unlockFrames and not addon.combat
		and not (BarFrameHasContent(f) or BarFrameKeepShown(g))
		and not f:IsShown()
	ns.RefreshDragHandle(f.dragHandle, f.cfg and f.cfg.frameName, shown)
end


local function AcquireBar(f, index)
	local pool = f.barPool
	local item = pool[index]
	if item then return item end

	item = CreateFrame("Frame", nil, f)

	item.bar = CreateFrame("StatusBar", nil, item)
	item.bar:SetMinMaxValues(0, 1)
	item.bar:SetValue(0)

	item.barBg = item.bar:CreateTexture(nil, "BACKGROUND")
	item.barBg:SetAllPoints(item.bar)

	-- ns.StyleIcon and ns.ApplyIconBorder look these up by field name, so keep them as tex and border.
	item.iconFrame = CreateFrame("Frame", nil, item)
	item.border = item.iconFrame:CreateTexture(nil, "BACKGROUND")
	item.border:Hide()
	item.tex = item.iconFrame:CreateTexture(nil, "ARTWORK")
	item.tex:SetAllPoints(item.iconFrame)
	item.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- a Masque skin recrops this, see ns.Masque_Add

	-- The cooldown value is secret in combat, so the native widget has to own the countdown text.
	item.cd = CreateFrame("Cooldown", nil, item.bar, "CooldownFrameTemplate")
	item.cd:SetDrawEdge(false)
	item.cd:SetDrawBling(false)
	item.cd:SetDrawSwipe(false)
	item.cd:SetHideCountdownNumbers(false)
	if item.cd.SetCountdownFormatter and ns.GetCountdownFormatter then
		local fmt = ns.GetCountdownFormatter()
		if fmt then item.cd:SetCountdownFormatter(fmt) end
	end

	item.name = item.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	item.name:SetJustifyH("LEFT")
	item.name:SetWordWrap(false)

	ns.Masque_Add("bar", item.iconFrame, item)

	item.hlBorder = CreateFrame("Frame", nil, item,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	item.hlBorder:SetPoint("TOPLEFT", item, "TOPLEFT", -2, 2)
	item.hlBorder:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 2, -2)
	item.hlBorder:SetFrameLevel(item:GetFrameLevel() + 6)
	pcall(item.hlBorder.SetBackdrop, item.hlBorder, { edgeFile = WHITE8X8, edgeSize = 2 })
	item.hlBorder:Hide()

	item.hlFill = item:CreateTexture(nil, "OVERLAY")
	item.hlFill:SetTexture(WHITE8X8)
	item.hlFill:SetBlendMode("ADD")
	item.hlFill:SetAllPoints(item)
	item.hlFill:Hide()

	local okBarFlash, barFlash = pcall(function()
		local ag = item.hlBorder:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetDuration(0.5)
		if a.SetFromAlpha then a:SetFromAlpha(1.0); a:SetToAlpha(0.2)
		elseif a.SetChange then a:SetChange(-0.8) end
		return ag
	end)
	if okBarFlash then item.hlFlash = barFlash end

	item:Hide()
	pool[index] = item
	return item
end


local function LayoutBarInternals(item, cfg, bh)
	local showIcon = cfg.showIcon ~= false
	local iconW = showIcon and bh or 0

	item.iconFrame:ClearAllPoints()
	item.bar:ClearAllPoints()
	if showIcon then
		item.iconFrame:SetSize(bh, bh)
		if item._msqSize ~= bh then
			item._msqSize = bh
			ns.Masque_ReSkin(item)
		end
		item.iconFrame:Show()
		if (cfg.iconPosition or "LEFT") == "RIGHT" then
			item.iconFrame:SetPoint("RIGHT", item, "RIGHT", 0, 0)
			item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
			item.bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -iconW, 0)
		else
			item.iconFrame:SetPoint("LEFT", item, "LEFT", 0, 0)
			item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", iconW, 0)
			item.bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
		end
	else
		item.iconFrame:Hide()
		item.bar:SetAllPoints(item)
	end

	item.name:ClearAllPoints()
	item.name:SetPoint("LEFT", item.bar, "LEFT", 3, 0)
	item.name:SetPoint("RIGHT", item.bar, "RIGHT", -3, 0)

	item.cd:ClearAllPoints()
	item.cd:SetPoint("TOPRIGHT", item.bar, "TOPRIGHT", 0, 0)
	item.cd:SetPoint("BOTTOMRIGHT", item.bar, "BOTTOMRIGHT", 0, 0)
	item.cd:SetWidth(math.max(bh * 1.6, 28))
end


local function StyleBar(item, cfg, classCol)
	local fgTexName = cfg.fgTexture or "CDM Smooth"
	if item._fgTexName ~= fgTexName then
		item._fgTexName = fgTexName
		item.bar:SetStatusBarTexture(StatusbarTex(fgTexName))
	end

	local fc = cfg.fgColor or { r = 0.2, g = 0.6, b = 1, a = 1 }
	local r, g2, b, a = fc.r, fc.g, fc.b, fc.a or 1
	if cfg.fgClassColor and classCol then r, g2, b = classCol.r, classCol.g, classCol.b end
	if item._fgR ~= r or item._fgG ~= g2 or item._fgB ~= b or item._fgA ~= a then
		item._fgR, item._fgG, item._fgB, item._fgA = r, g2, b, a
		item.bar:SetStatusBarColor(r, g2, b, a)
	end

	local bgTexName = cfg.barBgTexture or "CDM Smooth"
	if item._bgTexName ~= bgTexName then
		item._bgTexName = bgTexName
		item.barBg:SetTexture(StatusbarTex(bgTexName))
	end
	local bc = cfg.barBgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
	item.barBg:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)

	local flags = cfg.barFontFlags or "OUTLINE"
	if flags == "NONE" then flags = "" end
	local size = cfg.barFontSize
	if not size or size <= 0 then size = 12 end
	local fontPath = ns.FontPath(cfg.barFont)
	local sig = tostring(fontPath) .. "|" .. size .. "|" .. flags
	if item._fontSig ~= sig then
		item._fontSig = sig
		item.name:SetFont(fontPath, size, flags)
	end
	local nc = cfg.barFontColor or { r = 1, g = 1, b = 1, a = 1 }
	item.name:SetTextColor(nc.r, nc.g, nc.b, nc.a or 1)
end


-- The widget owns its countdown text (secret in combat), so restyle it through this live Font object.
local function ConfigureBarTimeFont(f, cfg)
	local name = "CDMBarTimeFont" .. (f.index or 1)
	local fontObj = _G[name] or CreateFont(name)
	fontObj:SetFont(ns.ResolveFont(cfg.barTimeFont, cfg.barTimeSize, cfg.barTimeFlags))
	local c = cfg.barTimeColor
	fontObj:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, c and c.a or 1)
	f._timeFontName = name
	return name
end


local DEFAULT_BAR_HL_COLOR = { r = 1, g = 0.82, b = 0, a = 0.8 }

local function ClearBarHighlight(item)
	if item.hlFlash then item.hlFlash:Stop() end
	if item.hlBorder then item.hlBorder:SetAlpha(1); item.hlBorder:Hide() end
	if item.hlFill then item.hlFill:Hide() end
	item._hlStyle = nil
end

-- Gate on the effective style and color or the refresh restarts the flash animation every tick.
local function ApplyBarHighlight(item, cfg, important)
	if not item.hlBorder then return end
	local hl = cfg.highlight
	local style = (important and hl and hl.style) or "NONE"
	if style == "NONE" then
		if item._hlStyle ~= "NONE" then
			ClearBarHighlight(item)
			item._hlStyle = "NONE"
		end
		return
	end
	local c = (hl and hl.color) or DEFAULT_BAR_HL_COLOR
	if item._hlStyle == style and item._hlR == c.r and item._hlG == c.g
		and item._hlB == c.b and item._hlA == c.a then
		return
	end
	item._hlStyle, item._hlR, item._hlG, item._hlB, item._hlA = style, c.r, c.g, c.b, c.a
	if item.hlFlash then item.hlFlash:Stop() end
	item.hlBorder:SetAlpha(1)
	pcall(item.hlBorder.SetBackdropBorderColor, item.hlBorder, c.r or 1, c.g or 1, c.b or 1, c.a or 0.8)
	item.hlBorder:Show()
	if item.hlFill then
		item.hlFill:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
		item.hlFill:SetAlpha((c.a or 0.6) * 0.30)
		item.hlFill:Show()
	end
	if style ~= "BORDER" and item.hlFlash then item.hlFlash:Play() end
end


local relayoutScratch = {}
local function RelayoutBarFrame(f)
	local cfg     = f.cfg
	local bw      = cfg.barWidth  or 200
	local bh      = cfg.barHeight or 20
	local spacing = cfg.spacing or 0
	local grow    = cfg.growDirection or "UP"
	local horizontal = grow == "LEFT" or grow == "RIGHT" or grow == "CENTER_H"

	local borderOn  = cfg.borderEnabled ~= false
	local borderIns = borderOn and ((cfg.borderSize or 0) + (cfg.borderPadding or 0)) or 0
	local margin    = borderIns + (cfg.padding or 0)

	local active = relayoutScratch
	wipe(active)
	for i = 1, #f.barPool do
		local item = f.barPool[i]
		if item and item:IsShown() then active[#active + 1] = item end
	end
	local count = #active

	local crossW = horizontal and bw or bh
	local step   = crossW + spacing
	local blockLen = (math.max(1, count) - 1) * step + crossW
	local half = (blockLen - crossW) / 2

	for k, item in ipairs(active) do
		item:SetSize(bw, bh)
		item:ClearAllPoints()
		local off = step * (k - 1)
		if grow == "DOWN" then
			item:SetPoint("TOP", f, "TOP", 0, -margin - off)
		elseif grow == "RIGHT" then
			item:SetPoint("LEFT", f, "LEFT", margin + off, 0)
		elseif grow == "LEFT" then
			item:SetPoint("RIGHT", f, "RIGHT", -margin - off, 0)
		elseif grow == "CENTER_V" then
			item:SetPoint("CENTER", f, "CENTER", 0, half - off)
		elseif grow == "CENTER_H" then
			item:SetPoint("CENTER", f, "CENTER", -half + off, 0)
		else
			item:SetPoint("BOTTOM", f, "BOTTOM", 0, margin + off)
		end
		LayoutBarInternals(item, cfg, bh)
	end

	if horizontal then
		f:SetSize(blockLen + margin * 2, bh + margin * 2)
	else
		f:SetSize(bw + margin * 2, blockLen + margin * 2)
	end

	local cdm = ns.CDM
	local g = cdm and cdm.db and cdm.db.profile.global
	if count > 0 or BarFrameKeepShown(g) then
		f._boxFade = nil
		f:SetAlpha(cfg.alpha or 1)
		f:Show()
	end
	if ns.SnapFrameToPixelGrid then ns.SnapFrameToPixelGrid(f) end
	UpdateBarHandle(f)
end


local function ClearBars(f)
	for i = 1, #f.barPool do
		local item = f.barPool[i]
		if item then
			item._cdSpellID, item._cdStart, item._cdGen = nil, nil, nil
			ClearBarHighlight(item)
			item:Hide()
		end
	end
	f._boxFade   = nil
	f.activeBars = 0
	-- This path hides bars without a relayout, so re-square the frame or it fades out at its last size.
	RelayoutBarFrame(f)
end


function ns.Bars_Build(addon)
	for i = 1, 3 do
		local cfg = addon.db.profile.barFrames and addon.db.profile.barFrames[i]
		if cfg and cfg.enabled and not addon.barFrames[i] then
			ns.Bars_CreateFrame(addon, i, cfg)
			ns.Bars_ApplyConfig(i)
		end
	end
end


function ns.Bars_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Bars_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(cfg.barWidth or 200, cfg.barHeight or 20)
	f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -300)
	if ns.GetFrameScale then f:SetScale(ns.GetFrameScale()) end
	f:SetClampedToScreen(true)
	f:EnableMouse(addon.db.profile.global.unlockFrames)   -- drag-only - RefreshUnlockState keeps it in sync
	f.index      = index
	f.cfg        = cfg
	f.barPool    = {}
	f.activeBars = 0

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

	local function FinalizeDrag(self)
		if not self._isDragging then return end
		self._isDragging = false
		local point, _, _, x, y = self:GetPoint()
		local cdm = _G.CooldownMaster
		local bcfg = cdm and cdm.db.profile.barFrames[self.index]
		if bcfg then
			bcfg.anchor = point
			bcfg.x = math.floor(x + 0.5)
			bcfg.y = math.floor(y + 0.5)
		end
		-- Same reason as the ready boxes: the relayout's snap only runs when the bar set changes.
		if ns.SnapFrameToPixelGrid then ns.SnapFrameToPixelGrid(self) end
	end

	f:SetScript("OnMouseUp", FinalizeDrag)
	-- An ancestor hide (UIParent) or a pooling hide eats the mouse-up, so finalize here too.
	f:SetScript("OnHide", FinalizeDrag)

	f:SetScript("OnUpdate", function(self, elapsed)
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

		local cfg = self.cfg
		local now = GetTime()
		local g = ns.CDM and ns.CDM.db and ns.CDM.db.profile.global

		local visible = 0
		for i = 1, #self.barPool do
			local item = self.barPool[i]
			if item and item:IsShown() then
				visible = visible + 1
				local remaining = (item._endTime or now) - now
				if remaining < 0 then remaining = 0 end
				local dur  = item._duration or 0
				local fill = dur > 0 and (remaining / dur) or 0
				if fill > 1 then fill = 1 elseif fill < 0 then fill = 0 end
				if item._isActive and fill < FILL_FLOOR then fill = FILL_FLOOR end
				item.bar:SetValue(fill)
			end
		end

		-- OnUpdate only runs while the frame is shown, so this fade-then-hide owns the empty-frame hide.
		local boxAlpha = (cfg and cfg.alpha) or 1
		if visible > 0 or BarFrameKeepShown(g) then
			if self._boxFade then
				self._boxFade = nil
				self:SetAlpha(boxAlpha)
			end
		else
			self._boxFade = (self._boxFade or 0) + elapsed
			if self._boxFade >= BOX_FADE_DUR then
				self:SetAlpha(boxAlpha)
				self._boxFade = nil
				self:Hide()
				UpdateBarHandle(self)
			else
				self:SetAlpha(boxAlpha * (1 - self._boxFade / BOX_FADE_DUR))
			end
		end
	end)

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOM", f, "TOP", 0, 2)
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:Hide()
	f.statusText = statusText

	f.dragHandle = ns.CreateDragHandle(f, string.format(L["Bar %d"], index), function(point, x, y)
		local bcfg = addon.db.profile.barFrames[index]
		if bcfg then
			bcfg.anchor = point
			bcfg.x = x
			bcfg.y = y
		end
	end)

	addon.barFrames[index] = f
	addon.barFramePool[index] = f
end


local refreshScratch = {}
local function RefreshBarBody(index)
	local addon = ns.CDM
	if not addon then return end
	local f = addon.barFrames and addon.barFrames[index]
	if not f then return end
	local cfg = f.cfg
	if not cfg then return end

	local engine  = ns.Engine
	local entries = engine and engine:GetActiveEntries() or nil
	local now     = GetTime()

	local sbcfg = cfg.statusText
	if sbcfg and sbcfg.enabled and f.statusText and f:IsShown() then
		local sstr = ns.RenderTag(sbcfg.text, nil)
		if f._statusStr ~= sstr then
			f._statusStr = sstr
			f.statusText:SetText(sstr)
		end
	end

	local g       = addon.db.profile.global
	local _, classToken = UnitClass("player")
	local classCol = classToken and addon.db.profile.classColors[classToken]
	local overrides = addon.db.profile.spellOverrides

	local visible = refreshScratch
	wipe(visible)
	if entries then
		for _, e in pairs(entries) do
			if e.endTime
				and (e.barIndex or 0) == index
				and engine:IsSpellVisible(e.spellID, e.category) then
				-- An entry past its extrapolated end would draw an empty bar, so drop it and let the engine confirm ready.
				-- isactive and offensive entries are removed on the real edge, so keep them past the
				-- extrapolated end rather than vanishing mid-cooldown. Mirrors the lane.
				if e.endTime - now > 0 or e._source == "isactive" or e._source == "offensive" then
					visible[#visible + 1] = e
				end
			end
		end
	end

	-- Sort by startTime first: the backward scan below breaks on the first different startTime.
	if g.detectSharedCD and #visible > 1 then
		table.sort(visible, ByStartTime)
		local w = 0
		for r = 1, #visible do
			local e = visible[r]
			local dup = false
			for k = w, 1, -1 do
				local kept = visible[k]
				-- Tolerance, not equality - starts differing by a hair must still compare (see Core/Engine.lua).
				if ((e.startTime or 0) - (kept.startTime or 0)) > SHARED_CD_TOL then break end
				if math.abs((e.endTime or 0) - (kept.endTime or 0)) <= SHARED_CD_TOL
					and ns.IsSameSharedCD(e, kept) then
					dup = true
					break
				end
			end
			if not dup then
				w = w + 1
				visible[w] = e
			end
		end
		for r = #visible, w + 1, -1 do visible[r] = nil end
	end

	table.sort(visible, cfg.sortDir == "ASCENDING" and ByRemainingAsc or ByRemainingDesc)

	local count = #visible
	local maxBars = cfg.maxBars or 10
	if maxBars > 0 and count > maxBars then count = maxBars end

	local showTime = cfg.showTime ~= false
	local showName = cfg.showName ~= false

	for idx = 1, count do
		local e = visible[idx]
		local item = AcquireBar(f, idx)

		if item._texIcon ~= e.icon then
			item._texIcon = e.icon
			item.tex:SetTexture(e.icon)
		end

		-- Feed the DurationObject when we can - it is the only combat-legal source of the real number.
		if item._cdSpellID ~= e.spellID or item._cdStart ~= e.startTime or item._cdGen ~= e._feedGen then
			item._cdSpellID = e.spellID
			item._cdItemID  = e.itemID
			item._cdStart   = e.startTime
			item._cdGen     = e._feedGen
			local fed = false
			if e.dObj and item.cd.SetCooldownFromDurationObject then
				fed = pcall(item.cd.SetCooldownFromDurationObject, item.cd, e.dObj)
			end
			if not fed and e.startTime and e.duration then
				item.cd:SetCooldown(e.startTime, e.duration)
			end
			-- Feeding the cooldown resets the count font, so re-bind it on each feed (SetCountdownFont is Retail-only).
			if item.cd.SetCountdownFont and f._timeFontName then
				pcall(item.cd.SetCountdownFont, item.cd, f._timeFontName)
			end
			item._showTime = nil   -- re-assert number visibility after a feed
		end

		if item._showTime ~= showTime then
			item._showTime = showTime
			item.cd:SetHideCountdownNumbers(not showTime)
		end

		local nameStr = showName and (e.name or "") or ""
		if item._nameStr ~= nameStr then
			item._nameStr = nameStr
			item.name:SetText(nameStr)
		end
		item.name:SetShown(showName)

		StyleBar(item, cfg, classCol)
		ns.StyleIcon(item, e.spellID, e.itemID, g)

		local ov = overrides and overrides[e.spellID]
		ApplyBarHighlight(item, cfg, ov and ov.important == true)

		item._endTime  = e.endTime
		item._duration = e.duration
		item._isActive = e._source == "isactive"
		item._spellID  = e.spellID
		item._itemID   = e.itemID
		item:Show()
	end

	local changed = f.activeBars ~= count
	for j = count + 1, f.activeBars do
		local item = f.barPool[j]
		if item then
			item._cdSpellID, item._cdStart, item._cdGen = nil, nil, nil
			ClearBarHighlight(item)
			item:Hide()
		end
	end
	f.activeBars = count

	if changed then RelayoutBarFrame(f) end
end


function ns.Bars_Refresh(index)
	local ok, err = pcall(RefreshBarBody, index)
	if not ok then
		if not ns._barsRefreshErr or (GetTime() - ns._barsRefreshErr) > 5 then
			ns._barsRefreshErr = GetTime()
			if _G.CooldownMaster then
				_G.CooldownMaster:Print("Bars_Refresh error: " .. tostring(err))
			end
		end
	end
end


function ns.Bars_ApplyConfig(index)
	local ok, err = pcall(function()
		local addon = ns.CDM
		if not addon then return end
		local f = addon.barFrames and addon.barFrames[index]
		if not f then return end
		local cfg = addon.db.profile.barFrames[index]
		if not cfg then return end

		local isMoving = f.IsMoving and f:IsMoving()
		if not isMoving then
			f:ClearAllPoints()
			f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -300)
		end
		if ns.GetFrameScale then f:SetScale(ns.GetFrameScale()) end

		if type(cfg.bgColor) ~= "table" then
			cfg.bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 }
		end
		if type(cfg.borderColor) ~= "table" then
			cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		local borderOn = cfg.borderEnabled ~= false
		local edgeFile = borderOn and WHITE8X8 or ""
		local edgeSize = borderOn and (cfg.borderSize or 1) or 0
		local bpad     = borderOn and (cfg.borderPadding or 0) or 0
		pcall(f.SetBackdrop, f, {
			bgFile   = WHITE8X8,
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

		if f.label then
			-- SetAlpha overrides a FontString's SetTextColor alpha, so fold the color opacity into the region alpha.
			local lc = cfg.labelColor or ns.CONST.RGB.YELLOW
			f.label:SetFont(ns.ResolveFont(cfg.labelFont, cfg.labelSize, cfg.labelFlags))
			f.label:SetTextColor(lc.r, lc.g, lc.b, 1)
			f.label:SetText(cfg.frameName or "")
			f.label:SetAlpha((addon.db.profile.global.unlockFrames and 0.6 or 0) * (lc.a or 1))
		end

		if f.statusText then
			if cfg.statusText and cfg.statusText.enabled then
				ns.ApplyStatusTextStyle(f, f.statusText, cfg)
				-- cfg.alpha rides the parent frame, which cascades onto this child, so fold in only the color alpha here.
				f.statusText:SetAlpha((cfg.statusColor and cfg.statusColor.a) or 1)
				f.statusText:Show()
				f._statusStr = nil
			else
				f.statusText:Hide()
			end
		end

		ConfigureBarTimeFont(f, cfg)

		for i = 1, #f.barPool do
			local item = f.barPool[i]
			if item then
				item._fgTexName, item._bgTexName, item._fontSig = nil, nil, nil
				item._fgR, item._nameStr = nil, nil
				item._hlStyle = nil
			end
		end
		RelayoutBarFrame(f)
	end)
	if not ok then
		if _G.CooldownMaster then
			_G.CooldownMaster:Print("Bars_ApplyConfig error: " .. tostring(err))
		end
	end
end


function ns.Bars_RebuildOne(index)
	local addon = ns.CDM
	if not addon or not addon.db then return end
	local cfg = addon.db.profile.barFrames and addon.db.profile.barFrames[index]
	if not cfg then return end

	local pooled = addon.barFramePool[index]
	if cfg.enabled then
		if pooled then
			ClearBars(pooled)
			pooled.cfg = cfg
			-- RefreshUnlockState skips a disabled frame, so a pooled one comes back with a stale mouse state.
			pooled:EnableMouse(addon.db.profile.global.unlockFrames)
			addon.barFrames[index] = pooled
			ns.Bars_ApplyConfig(index)
		else
			ns.Bars_CreateFrame(addon, index, cfg)
			ns.Bars_ApplyConfig(index)
		end
	else
		if pooled then
			pooled:Hide()
			if pooled.dragHandle then pooled.dragHandle:Hide() end
		end
		addon.barFrames[index] = nil
	end
end


function ns.Bars_RefreshUnlockState(addon)
	for i = 1, 3 do
		local f = addon.barFrames and addon.barFrames[i]
		if f then
			local unlocked = addon.db.profile.global.unlockFrames
			-- A locked bar frame has no drag to serve, so leaving the mouse on would silently eat world clicks.
			f:EnableMouse(unlocked)
			if f.label then
				local lta = (f.cfg and f.cfg.labelColor and f.cfg.labelColor.a) or 1
				f.label:SetAlpha((unlocked and 0.6 or 0) * lta)
			end
			RelayoutBarFrame(f)
		end
	end
end


function ns.Bars_RefreshVisibility()
	local addon = ns.CDM
	if not addon then return end
	for i = 1, 3 do
		local f = addon.barFrames and addon.barFrames[i]
		if f then RelayoutBarFrame(f) end
	end
end
