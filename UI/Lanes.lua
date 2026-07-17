local ADDON_NAME, ns = ...

local _dragFailWarnTime = 0  -- luacheck: ignore

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local STANDARD_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE8X8 = "Interface\\Buttons\\WHITE8x8"

-- Smallest lane fraction an isActive (retail, extrapolated) icon may sit at. Its remaining time is
-- secret in combat, so if our extrapolation undershoots the real cooldown the icon would otherwise
-- snap to the exact ready edge with the widget still counting down; this holds it a hair short.
local ICON_READY_FLOOR = 0.02

-- UI units per physical pixel numerator (768/screen height); a coordinate divided by
-- (PIXEL_FACTOR / effectiveScale) is in physical pixels. Verified against Blizzard's
-- PixelUtil.GetPixelToUIUnitFactor on a live 4K/0.5-scale setup.
local PIXEL_FACTOR = 768 / select(2, GetPhysicalScreenSize())

-- Frame edges landing between physical pixels smear a WHITE8x8 border across two rows, so two
-- identical lanes can render different borders. The sub-pixel nudge leaves the saved offset alone.
function ns.SnapFrameToPixelGrid(frame)
	if not frame or frame._isDragging then return end
	if frame.IsMoving and frame:IsMoving() then return end
	local scale = frame:GetEffectiveScale()
	if not scale or scale <= 0 then return end
	local psize = PIXEL_FACTOR / scale
	local point, relTo, relPoint, x, y = frame:GetPoint()
	if not point then return end
	local w, h = frame:GetWidth(), frame:GetHeight()
	if w and h and w > 0 and h > 0 then
		local sw = math.floor(w / psize + 0.5) * psize
		local sh = math.floor(h / psize + 0.5) * psize
		if math.abs(sw - w) > 0.01 or math.abs(sh - h) > 0.01 then frame:SetSize(sw, sh) end
	end
	local l, b = frame:GetLeft(), frame:GetBottom()
	if not (l and b) then return end
	local dx = math.floor(l / psize + 0.5) * psize - l
	local dy = math.floor(b / psize + 0.5) * psize - b
	if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then
		frame:SetPoint(point, relTo, relPoint, x + dx, y + dy)
	end
end

function ns.GetFrameScale()
	local cdm = ns.CDM
	local g = cdm and cdm.db and cdm.db.profile and cdm.db.profile.global
	local s = g and g.frameScale
	return (type(s) == "number" and s > 0) and s or 1
end

local function ReSnapAllFrames()
	local addon = ns.CDM
	if not addon then return end
	for i = 1, 3 do
		if addon.lanes and addon.lanes[i] then ns.SnapFrameToPixelGrid(addon.lanes[i]) end
		if addon.readyFrames and addon.readyFrames[i] then ns.SnapFrameToPixelGrid(addon.readyFrames[i]) end
		if addon.barFrames and addon.barFrames[i] then ns.SnapFrameToPixelGrid(addon.barFrames[i]) end
	end
end

local pxWatch = CreateFrame("Frame")
pxWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
pxWatch:RegisterEvent("UI_SCALE_CHANGED")
pxWatch:SetScript("OnEvent", function()
	PIXEL_FACTOR = 768 / select(2, GetPhysicalScreenSize())
	ReSnapAllFrames()
end)

-- Register the built-in names so saved "CDM Smooth"/"CDM Shadow" resolve and list
-- alongside the user's LSM media; WHITE8x8 keeps the default flat look unchanged.
-- A border edgeFile is sliced into 8 square cells, so that art must be an 8-cell strip.
local MEDIA = [[Interface\AddOns\CooldownMaster\media\]]
if LSM then
	pcall(LSM.Register, LSM, "statusbar", "CDM Smooth", WHITE8X8)
	pcall(LSM.Register, LSM, "border",    "CDM Shadow", WHITE8X8)
	pcall(LSM.Register, LSM, "statusbar", "CDM Gradient",  MEDIA .. "statusbar-gradient.tga")
	pcall(LSM.Register, LSM, "statusbar", "CDM Glass",     MEDIA .. "statusbar-glass.tga")
	pcall(LSM.Register, LSM, "border",    "CDM Soft Edge", MEDIA .. "border-soft.tga")
end


function ns.ResolveFont(fontName, size, flags)
	local path = (LSM and LSM:Fetch("font", fontName, true)) or STANDARD_FONT
	if flags == "NONE" then flags = "" end
	if not size or size <= 0 then size = 12 end
	return path, size, flags or ""
end


local function VisibilityGatePasses(g)
	if g.enabledAlways then return true end
	local pass = false
	if g.enabledGroup    and IsInGroup()    then pass = true end
	if g.enabledInstance and IsInInstance() then pass = true end
	return pass
end


local function LaneGatePasses(addon)
	if ns.Engine and ns.Engine.testActive then return true end
	return VisibilityGatePasses(addon.db.profile.global)
end


-- Autohide hides only the chrome (bg/border/name/markers), never the icon children, so
-- cooldowns stay visible out of combat. Unlock no longer forces chrome on -- a drag handle
-- (ns.CreateDragHandle) keeps an autohidden frame findable, so autohide works while unlocked.
local function ChromeShown(addon, cfg)
	local g = addon.db.profile.global
	if ns.Engine and ns.Engine.testActive then return true end
	if not g.autohide then return true end
	if addon.combat then return true end
	return cfg.overrideAutohide and true or false
end


-- Alpha-toggle the chrome only; never the frame alpha or the icon children (that is what
-- keeps icons lit). Backdrop is the frame's own artwork, so alpha-zero it, don't detach.
function ns.ApplyStatusTextStyle(anchorFrame, fs, cfg)
	local sc = cfg.statusColor or ns.CONST.RGB.YELLOW
	fs:SetFont(ns.ResolveFont(cfg.statusFont, cfg.statusSize, cfg.statusFlags))
	fs:SetTextColor(sc.r, sc.g, sc.b, 1)
	fs:ClearAllPoints()
	local anch = (cfg.statusText and cfg.statusText.anchor) or "BOTTOM"
	if anch == "TOP" then
		fs:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 2)
	elseif anch == "LEFT" then
		fs:SetPoint("RIGHT", anchorFrame, "LEFT", -4, 0)
	elseif anch == "RIGHT" then
		fs:SetPoint("LEFT", anchorFrame, "RIGHT", 4, 0)
	else
		fs:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -2)
	end
end


local function SetLaneChrome(addon, f, cfg, show)
	-- cfg.alpha fades the bar chrome only; icons keep their own iconAlpha (the frame stays opaque).
	local a = cfg.alpha or 1
	local bg = f._chromeBg
	if bg then
		pcall(f.SetBackdropColor, f, bg.r, bg.g, bg.b, show and (bg.a or 1) * a or 0)
	end
	local bc = f._chromeBorder
	if bc then
		pcall(f.SetBackdropBorderColor, f, bc.r, bc.g, bc.b, show and (bc.a or 1) * a or 0)
	else
		pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0)
	end
	-- A FontString's SetAlpha overrides the alpha passed to SetTextColor, so color-picker opacity is folded in here.
	if f.label then
		local lta = (cfg.labelColor and cfg.labelColor.a) or 1
		f.label:SetAlpha(show and (addon.db.profile.global.unlockFrames and 0.6 or 0) * a * lta or 0)
	end
	if f.statusText then
		if show and cfg.statusText and cfg.statusText.enabled then
			-- Resolve once on the show transition so a re-show never flashes text frozen from before it hid.
			local s = ns.RenderTag(cfg.statusText.text, nil)
			f._statusStr = s
			f.statusText:SetText(s)
			f.statusText:SetAlpha(a * ((cfg.statusColor and cfg.statusColor.a) or 1))
			f.statusText:Show()
		else
			f.statusText:Hide()
		end
	end
	if f.markers and cfg.laneText then
		local mta = (cfg.laneTextColor and cfg.laneTextColor.a) or 1
		for i = 1, 5 do
			local m, def = f.markers[i], cfg.laneText[i]
			if m and def then
				if show and def.enabled then m:SetAlpha(a * mta); m:Show() else m:Hide() end
			end
		end
	end
	-- Tracking bars are combat-rhythm chrome, so they hide with the rest of it; the flag also
	-- stops the per-frame UpdateTracking from re-showing them while chrome is hidden.
	f._chromeHidden = not show
	if not show then
		if f.primaryFill then f.primaryFill:Hide() end
		if f.st then f.st:Hide() end
	end
end


local function ApplyVisibility(addon)
	if not (addon and addon.db and addon.lanes) then return end
	local unlocked = addon.db.profile.global.unlockFrames
	local gate = LaneGatePasses(addon)
	for i = 1, 3 do
		local f = addon.lanes[i]
		if f and f.cfg then
			local chrome = gate and ChromeShown(addon, f.cfg)
			if gate then
				f:Show()
				SetLaneChrome(addon, f, f.cfg, chrome)
			else
				f:Hide()
			end
			-- Grab the strip only while it is actually visible. An invisible autohidden strip
			-- would silently eat clicks, so the drag handle takes over when the chrome is hidden.
			f:EnableMouse(unlocked and chrome and true or false)
			if f.dragHandle then
				ns.RefreshDragHandle(f.dragHandle, f.cfg.frameName, unlocked and gate and not chrome)
			end
		end
	end
end


-- Recurring-timer tracking (GCD / main-hand swing) drawn on the lane: primaryTracking fills
-- the whole lane, secondaryTracking is a small bar sliding across it. Retail's Cooldown
-- Manager owns this, so it stays off there (matching the hidden options).
local TRACKING_ENABLED = not ns.Compat.IS_RETAIL

-- 61304 is Blizzard's hidden Global Cooldown spell (canonical GCD probe on the modern
-- engine); 8921 (Moonfire, no cooldown of its own) is a fallback for older clients.
local GCD_SPELLS = { 61304, 8921 }

local swingEnd, swingSpeed   -- main-hand swing state, player-wide
local swingActive = false    -- any enabled lane tracking SWING; gates the combat-log work

function ns.Lanes_HandleSwingLog()
	if not swingActive then return end
	local _, sub, _, srcGUID = CombatLogGetCurrentEventInfo()
	if srcGUID ~= UnitGUID("player") then return end
	-- isOffHand lands at a different arg index for a landed hit vs a miss.
	local isOffHand
	if sub == "SWING_DAMAGE" then
		isOffHand = select(21, CombatLogGetCurrentEventInfo())
	elseif sub == "SWING_MISSED" then
		isOffHand = select(13, CombatLogGetCurrentEventInfo())
	else
		return
	end
	if isOffHand then return end
	local mh = UnitAttackSpeed("player")
	if mh and mh > 0 then
		swingSpeed = mh
		swingEnd   = GetTime() + mh
	end
end

local function RecomputeTrackingNeeds()
	local addon = ns.CDM
	swingActive = false
	if TRACKING_ENABLED and addon and addon.db then
		for i = 1, 3 do
			local cfg = addon.db.profile.lanes[i]
			if cfg and cfg.enabled
				and (cfg.primaryTracking == "SWING" or cfg.secondaryTracking == "SWING") then
				swingActive = true
				break
			end
		end
	end
	if not addon then return end
	if swingActive then
		addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", ns.Lanes_HandleSwingLog)
	else
		addon:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

local function gcdFraction(id)
	local start, duration = ns.Compat.GetSpellCooldown(id)
	if start and duration and start > 0 and duration > 0 then
		local p = (start + duration - GetTime()) / duration
		if p < 0 then return 0 elseif p > 1 then return 1 end
		return p
	end
end

local function CalcTracking(which)
	if which == "GCD" then
		-- Prefer the spellbook probe (a spell the player actually knows, so it reflects the
		-- GCD on every flavor); fall back to the fixed IDs that only work on newer clients.
		local probe = ns.Engine and ns.Engine.gcdProbe
		if probe then
			local p = gcdFraction(probe)
			if p then return p end
		end
		for _, id in ipairs(GCD_SPELLS) do
			local p = gcdFraction(id)
			if p then return p end
		end
		return 0
	elseif which == "SWING" then
		if not swingEnd or not swingSpeed or swingSpeed <= 0 then return 1 end
		local remaining = swingEnd - GetTime()
		if remaining <= 0 then return 1 end
		return remaining / swingSpeed
	end
	return 0
end

-- The Reverse toggle flips relative to the lane's own direction, so by default the tick
-- sweeps the same way the cooldown icons travel.
local function PositionPrimary(f, cfg, v)
	local fill = f.primaryFill
	fill:ClearAllPoints()
	local rev = (cfg.primaryReverse and true or false) ~= (cfg.reversed and true or false)
	if cfg.vertical then
		fill:SetWidth(cfg.width or 575)
		fill:SetHeight(math.max(0.5, v * (cfg.height or 17)))
		local pt = rev and "TOP" or "BOTTOM"
		fill:SetPoint(pt, f, pt, 0, 0)
	else
		fill:SetHeight(cfg.height or 17)
		fill:SetWidth(math.max(0.5, v * (cfg.width or 575)))
		local pt = rev and "RIGHT" or "LEFT"
		fill:SetPoint(pt, f, pt, 0, 0)
	end
end

local function PositionSecondary(f, cfg, v)
	local st = f.st
	st:ClearAllPoints()
	local rev = (cfg.secondaryReverse and true or false) ~= (cfg.reversed and true or false)
	if cfg.vertical then
		local usable = math.max(1, (cfg.height or 17) - (cfg.stWidth or 7))
		local y = v * usable
		if rev then st:SetPoint("TOP", f, "TOP", 0, -y)
		else st:SetPoint("BOTTOM", f, "BOTTOM", 0, y) end
	else
		local usable = math.max(1, (cfg.width or 575) - (cfg.stWidth or 7))
		local x = v * usable
		if rev then st:SetPoint("RIGHT", f, "RIGHT", -x, 0)
		else st:SetPoint("LEFT", f, "LEFT", x, 0) end
	end
end

local function ApplyTrackingConfig(f, cfg)
	if not (f and f.st and f.primaryFill) then return end
	local col = cfg.stColor or { r = 1, g = 1, b = 1, a = 1 }
	local tex = (LSM and LSM:Fetch("statusbar", cfg.stTexture, true)) or WHITE8X8
	f.st:SetTexture(tex)
	f.st:SetVertexColor(col.r, col.g, col.b, col.a or 1)
	-- Vertical lane: the tick crosses on X and stays thin on the Y travel axis, so swap its dims (PositionSecondary mirrors this).
	if cfg.vertical then
		f.st:SetSize(cfg.stHeight or 24, cfg.stWidth or 7)
	else
		f.st:SetSize(cfg.stWidth or 7, cfg.stHeight or 24)
	end
	f.primaryFill:SetTexture(tex)
	f.primaryFill:SetVertexColor(col.r, col.g, col.b, col.a or 1)
	-- Gate the per-frame UpdateTracking so idle NONE/NONE lanes (the default) do no work.
	f._track = (cfg.primaryTracking and cfg.primaryTracking ~= "NONE")
		or (cfg.secondaryTracking and cfg.secondaryTracking ~= "NONE") or false
	if not f._track then
		f.primaryFill:Hide()
		f.st:Hide()
	end
end

local function UpdateTracking(f)
	local cfg = f.cfg
	if not (cfg and f.st) then return end

	if cfg.primaryTracking and cfg.primaryTracking ~= "NONE" then
		local v = CalcTracking(cfg.primaryTracking)
		-- Hide at the extremes too: an idle swing reads 1, which must not sit as a full fill.
		if v > 0 and v < 1 then PositionPrimary(f, cfg, v); f.primaryFill:Show()
		else f.primaryFill:Hide() end
	else
		f.primaryFill:Hide()
	end

	if cfg.secondaryTracking and cfg.secondaryTracking ~= "NONE" then
		local v = CalcTracking(cfg.secondaryTracking)
		-- Hide at the extremes so an idle GCD/swing leaves no tick parked at the lane edge.
		if v > 0 and v < 1 then PositionSecondary(f, cfg, v); f.st:Show()
		else f.st:Hide() end
	else
		f.st:Hide()
	end
end




local trackMon
function ns.Lanes_TrackingReport()
	local addon = ns.CDM
	if not addon then return end
	addon:Print(string.format("Tracking enabled: %s | swingActive: %s | swingSpeed: %s",
		tostring(TRACKING_ENABLED), tostring(swingActive), tostring(swingSpeed)))
	for i = 1, 3 do
		local cfg = addon.db.profile.lanes[i]
		local f = addon.lanes and addon.lanes[i]
		if cfg then
			addon:Print(string.format("Lane %d: pri=%s sec=%s | frame=%s st=%s fill=%s",
				i, tostring(cfg.primaryTracking), tostring(cfg.secondaryTracking),
				f and "yes" or "NO", (f and f.st) and "yes" or "NO",
				(f and f.primaryFill) and "yes" or "NO"))
		end
	end
	-- GCD/swing are transient, so sample for 5s instead of snapshotting the idle moment.
	trackMon = trackMon or CreateFrame("Frame")
	trackMon._t, trackMon._gcd, trackMon._sw = 0, 0, 1
	addon:Print("Sampling 5s -- cast a few spells and swing at a target now...")
	trackMon:SetScript("OnUpdate", function(self, e)
		self._t = self._t + e
		local g = CalcTracking("GCD"); if g > self._gcd then self._gcd = g end
		local s = CalcTracking("SWING"); if s < self._sw then self._sw = s end
		if self._t >= 5 then
			self:SetScript("OnUpdate", nil)
			addon:Print(string.format("Sampled peaks -> GCD reached: %.2f | Swing dropped to: %.2f",
				self._gcd, self._sw))
		end
	end)
end


function ns.Lanes_Build(addon)
	for i = 1, 3 do
		local cfg = addon.db.profile.lanes[i]
		if cfg.enabled and not addon.lanes[i] then
			ns.Lanes_CreateLane(addon, i, cfg)
		end
	end
end


-- Draggable name-tag pinned to a frame's center, shown only while unlocked AND the frame's
-- chrome is autohidden -- so an otherwise-invisible lane or ready box stays findable and movable.
function ns.CreateDragHandle(target, fallback, onMoved)
	local h = CreateFrame("Frame", nil, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	h:SetFrameStrata("HIGH")
	h:SetPoint("CENTER", target, "CENTER", 0, 0)
	h:SetSize(60, 20)
	h:EnableMouse(true)
	h:Hide()
	h.fallback = fallback
	if ns.Theme then
		ns.Theme.ApplyBackdrop(h, { r = 0, g = 0, b = 0, a = 0.85 }, ns.CONST.RGB.RED)
	end
	local txt = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	txt:SetPoint("CENTER")
	txt:SetText(fallback or "")
	txt:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	h.text = txt

	h:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local cursorX, cursorY = GetCursorPosition()
		local scale = target:GetEffectiveScale()
		self._sx, self._sy = cursorX / scale, cursorY / scale
		local point, _, _, x, y = target:GetPoint()
		self._fx, self._fy, self._fp = x, y, point or "CENTER"
		self._dragging = true
	end)
	h:SetScript("OnMouseUp", function(self, button)
		if not self._dragging then return end
		self._dragging = false
		local point, _, _, x, y = target:GetPoint()
		if onMoved then onMoved(point or "CENTER", math.floor(x + 0.5), math.floor(y + 0.5)) end
	end)
	-- A mid-drag hide (box pop, combat start, gate flip) would strand _dragging=true and make the
	-- frame chase the cursor when it re-shows, so finalize the drag here the same as OnMouseUp.
	h:SetScript("OnHide", function(self)
		if not self._dragging then return end
		self._dragging = false
		local point, _, _, x, y = target:GetPoint()
		if onMoved then onMoved(point or "CENTER", math.floor(x + 0.5), math.floor(y + 0.5)) end
	end)
	h:SetScript("OnUpdate", function(self)
		if not self._dragging then return end
		local cursorX, cursorY = GetCursorPosition()
		local scale = target:GetEffectiveScale()
		target:ClearAllPoints()
		target:SetPoint(self._fp, UIParent, self._fp,
			self._fx + (cursorX / scale - self._sx),
			self._fy + (cursorY / scale - self._sy))
	end)

	return h
end

function ns.RefreshDragHandle(h, name, shown)
	if not h then return end
	if not shown then h:Hide() return end
	if not name or name == "" then name = h.fallback or "" end
	h.text:SetText(name)
	h:SetWidth(math.max(60, (h.text:GetStringWidth() or 0) + 16))
	h:Show()
end


function ns.Lanes_CreateLane(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Lane_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(cfg.width, cfg.height)
	f:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.x, cfg.y)
	f:SetScale(ns.GetFrameScale())
	f:SetClampedToScreen(true)
	f:EnableMouse(addon.db.profile.global.unlockFrames)   -- drag-only; ApplyVisibility keeps it in sync
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
		if TRACKING_ENABLED and self._track and not self._chromeHidden then UpdateTracking(self) end
		ns.Lanes_RepackSpread(self)
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

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	-- Name floats just above the bar so it never overlaps the % markers, at any lane height.
	label:SetPoint("BOTTOM", f, "TOP", 0, 2)
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	statusText:Hide()
	f.statusText = statusText

	f.markers = {}
	for i = 1, 5 do
		local m = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		m:Hide()
		f.markers[i] = m
	end

	if TRACKING_ENABLED then
		f.primaryFill = f:CreateTexture(nil, "ARTWORK")
		f.primaryFill:Hide()
		f.st = f:CreateTexture(nil, "OVERLAY", nil, 2)
		f.st:Hide()
		ApplyTrackingConfig(f, cfg)
	end

	f.iconPool   = {}
	f.activeIcons = 0
	f.cfg = cfg
	f.index = index

	f.dragHandle = ns.CreateDragHandle(f, "Lane "..index, function(point, x, y)
		local laneCfg = addon.db.profile.lanes[index]
		if laneCfg then
			laneCfg.anchor = point
			laneCfg.x = x
			laneCfg.y = y
		end
		if ns.Lanes_Refresh then ns.Lanes_Refresh(index) end
	end)

	addon.lanes[index] = f
	addon.lanePool[index] = f   -- free-list entry; reused across profile/enable changes

	-- Required: marker positioning lives only in ApplyConfigBody and the per-tick
	-- refresh no longer applies config, so lanes built at login would otherwise
	-- render with unpositioned markers.
	ns.Lanes_ApplyConfig(index)
	ApplyVisibility(addon)
end


-- Remaining time is secret in combat, so the Cooldown widget calls this privileged
-- formatter with the secret value. Breakpoints = Blizzard defaults minus the minute-collapse:
-- whole seconds under 1:00, then M:SS all the way up (default shows bare minutes above 2 min).
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
ns.GetCountdownFormatter = GetCountdownFormatter


-- Cooldown remaining -> 0..1 position along the lane. TIMELINE = shared seconds axis (maxTime);
-- LOG = same axis logarithmic (last seconds spread wide, long cooldowns compress); default =
-- each icon spans its own cooldown. Shared by the per-icon OnUpdate and the stacking pass so
-- they never drift; memo LOG's maxTime-only denominator so we don't math.log it every frame.
local logDenomCache = {}
local function ModeProgress(cfg, remaining, duration)
	local p
	local m = cfg.mode
	if m == "TIMELINE" then
		p = remaining / (cfg.maxTime or 120)
	elseif m == "LOG" then
		local mt = cfg.maxTime or 120
		local denom = logDenomCache[mt]
		if not denom then denom = math.log(1 + mt); logDenomCache[mt] = denom end
		p = math.log(1 + remaining) / denom
	elseif m == "SPLIT" then
		local sp = cfg.split
		local maxT = cfg.maxTime or 120
		local v = remaining
		if v > maxT then v = maxT end
		-- Piecewise-linear remap through (0,0) -> up to 3 (time,pos) splits -> (maxT,1),
		-- so the user spreads imminent seconds and compresses far ones on their own curve.
		local n = (sp and sp.count) or 0
		local pts = sp and sp.points
		local pv, pp = 0, 0
		p = nil
		if pts then
			for i = 1, n do
				local pt = pts[i]
				if pt and v <= pt.t then
					local span = pt.t - pv
					p = (span > 0) and (pp + (pt.p - pp) * ((v - pv) / span)) or pp
					break
				elseif pt then
					pv, pp = pt.t, pt.p
				end
			end
		end
		if not p then
			local span = maxT - pv
			p = (span > 0) and (pp + (1 - pp) * ((v - pv) / span)) or 1
		end
	else
		p = remaining / (duration or 120)
	end
	if p < 0 then return 0 elseif p > 1 then return 1 end
	return p
end


local function AcquireIcon(laneFrame, i, iconSize)
	local pool = laneFrame.iconPool
	local btn  = pool[i]
	if btn then return btn end

	btn = CreateFrame("Frame", nil, laneFrame)
	btn:SetSize(iconSize, iconSize)

	-- Per-lane icon border (off by default): a solid backing that extends a few px beyond the
	-- icon so a clean ring shows around it. Below ARTWORK so the icon covers its center; sized,
	-- colored, and toggled per lane in RefreshBody via ApplyIconBorder.
	btn.border = btn:CreateTexture(nil, "BACKGROUND")
	btn.border:Hide()

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trim default icon border

	-- Carrier for the cooldown widget: the icon glides sub-pixel (smooth texture), but the
	-- countdown text is laid out C-side on the physical pixel grid, so gliding it shimmers
	-- the digits (A/B-verified). The widget rides this frame, which the OnUpdate holds on
	-- whole screen pixels -- it trails the texture by at most half a pixel.
	btn.cdAnchor = CreateFrame("Frame", nil, btn)
	btn.cdAnchor:SetSize(iconSize, iconSize)
	btn.cdAnchor:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)

	-- In combat the remaining time is a secret value we cannot read (see
	-- docs/EXPERIMENTS.md), so we feed this widget the opaque DurationObject via
	-- SetCooldownFromDurationObject; items / test use SetCooldown.
	btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	btn.cd:SetAllPoints(btn.cdAnchor)
	btn.cd:SetDrawEdge(false)
	btn.cd:SetDrawBling(false)
	btn.cd:SetHideCountdownNumbers(false)
	if btn.cd.SetCountdownFormatter then
		local fmt = GetCountdownFormatter()
		if fmt then btn.cd:SetCountdownFormatter(fmt) end
	end

	-- Parented to cdAnchor (held on whole pixels by the OnUpdate) so the label stays crisp while the icon glides sub-pixel.
	btn.tagText = btn.cdAnchor:CreateFontString(nil, "OVERLAY")
	btn.tagText:Hide()

	-- Highlight overlay for Important spells (Border / Glow / Flash), mirroring the
	-- ready box. Additive border anchored a few px out so it tracks icon size.
	btn.hl = btn:CreateTexture(nil, "OVERLAY")
	btn.hl:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	btn.hl:SetBlendMode("ADD")
	btn.hl:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6)
	btn.hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
	btn.hl:Hide()

	-- Full-icon glow so the highlight fills the icon, not just its edge (the border texture
	-- alone leaves the center empty). Additive, colored to match; the border carries the flash.
	btn.hlFill = btn:CreateTexture(nil, "OVERLAY")
	btn.hlFill:SetTexture(WHITE8X8)
	btn.hlFill:SetBlendMode("ADD")
	btn.hlFill:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	btn.hlFill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
	btn.hlFill:Hide()

	local okFlash, flash = pcall(function()
		local ag = btn.hl:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetDuration(0.5)
		if a.SetFromAlpha then a:SetFromAlpha(1.0); a:SetToAlpha(0.2)
		elseif a.SetChange then a:SetChange(-0.8) end
		return ag
	end)
	if okFlash then btn.hlFlash = flash end

	ns.Masque_Add("lane", btn)

	btn:SetScript("OnEnter", function(self)
		-- Raise above stack-mates so an occluded stacked icon can be hovered; only
		-- meaningful when stacking overlaps icons, so gate it on the toggle.
		if self._cfg and self._cfg.stackRaiseHover and self:GetParent() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel() + 50)
		end
		local cdm = ns.CDM
		if not (cdm and cdm.db.profile.global.enableTooltip and self._cdSpellID) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self._cdItemID then
			GameTooltip:SetItemByID(self._cdItemID)
		elseif self._cdCustom then
			GameTooltip:SetText(self._cdName or "Cooldown", 1, 1, 1)
			if self._cdSpellID < ns.CONST.TEST_ID_BASE then
				GameTooltip:AddLine("Custom cooldown", 0.6, 0.6, 0.6)
			end
		else
			GameTooltip:SetSpellByID(self._cdSpellID)
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function(self)
		if self._cfg and self._cfg.stackRaiseHover and self:GetParent() then
			self:SetFrameLevel(self:GetParent():GetFrameLevel() + 1)
		end
		GameTooltip:Hide()
	end)

	btn:SetScript("OnUpdate", function(self)
		if not self._endTime then return end
		local cfg = self._cfg
		if not cfg then return end
		local remaining = self._endTime - GetTime()
		if remaining < 0 then remaining = 0 end

		-- Alpha is config-driven, not time-driven: only push it on change, not every
		-- frame (it's the same value 60x/sec otherwise).
		local alpha = cfg.iconAlpha or 1
		if self._alpha ~= alpha then
			self._alpha = alpha
			self:SetAlpha(alpha)
		end

		local off      = (cfg.iconOffset or 0) + (self._stackOff or 0)
		local iconSize = self._iconSize or 40
		local progress = ModeProgress(cfg, remaining, self._duration)
		if self._isActive and progress < ICON_READY_FLOOR then progress = ICON_READY_FLOOR end

		-- SPREAD stacking nudges icons apart along the lane axis; 0 for every other mode.
		local shift = self._spreadShift or 0
		local point, coord
		if cfg.vertical then
			local usableH = math.max(1, (cfg.height or 400) - iconSize)
			local y = progress * usableH + shift
			if y < 0 then y = 0 elseif y > usableH then y = usableH end
			if cfg.reversed then point, coord = "TOP", -y else point, coord = "BOTTOM", y end
		else
			local usable = math.max(1, (cfg.width or 400) - iconSize)
			local x = progress * usable + shift
			if x < 0 then x = 0 elseif x > usable then x = usable end
			if cfg.reversed then point, coord = "RIGHT", -x else point, coord = "LEFT", x end
		end

		-- Float coord, not pixel-rounded: SetPoint renders sub-pixel so the icon glides; rounding reintroduces stair-stepping.
		if self._anchPoint ~= point or self._anchCoord ~= coord or self._anchOff ~= off then
			self._anchPoint, self._anchCoord, self._anchOff = point, coord, off
			self:ClearAllPoints()
			if cfg.vertical then
				self:SetPoint(point, self:GetParent(), point, off, coord)
			else
				self:SetPoint(point, self:GetParent(), point, coord, off)
			end
		end

		-- Hold the cooldown carrier (swipe + countdown digits) on whole physical pixels while
		-- the icon texture glides sub-pixel: the C-side text layout shimmers when its frame
		-- sits between pixels (A/B-verified at 4K). Offset is at most half a pixel. Runs after
		-- the SetPoint above so the rect read reflects THIS frame's position.
		local ca = self.cdAnchor
		if ca then
			local l, b = self:GetLeft(), self:GetBottom()
			if l and b then
				local psize = PIXEL_FACTOR / self:GetEffectiveScale()
				local dx = math.floor(l / psize + 0.5) * psize - l
				local dy = math.floor(b / psize + 0.5) * psize - b
				if dx ~= self._cdDx or dy ~= self._cdDy then
					self._cdDx, self._cdDy = dx, dy
					ca:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", dx, dy)
				end
			end
		end
	end)

	pool[i] = btn
	return btn
end


-- Reset a pooled icon's instance keys so a reused slot re-feeds its cooldown cleanly.
local function ClearLaneIcon(btn)
	if not btn then return end
	btn._endTime     = nil
	btn._cdSpellID   = nil
	btn._cdCustom    = nil
	btn._cdName      = nil
	btn._cdStart     = nil
	btn._stackOff    = nil
	btn._spreadShift = nil
	btn._isActive    = nil
	if btn._tinted and btn.tex then
		btn._tinted = nil
		btn.tex:SetVertexColor(1, 1, 1)
		btn.tex:SetDesaturated(false)
	end
	if btn.hlFlash then btn.hlFlash:Stop() end
	if btn.hl then btn.hl:Hide() end
	if btn.hlFill then btn.hlFill:Hide() end
	btn._hlStyle = nil
	if btn.cd then btn.cd:Clear() end
	btn:Hide()
end


local DEFAULT_HL_COLOR = { r = 1, g = 0.82, b = 0, a = 0.8 }

-- Lane-icon highlight for Important spells, reusing the ready-box overlay. Gated on the
-- effective style+color so the 10 Hz refresh doesn't restart the flash every tick.
local function ApplyLaneHighlight(btn, cfg, important)
	if not btn.hl then return end
	local hl = cfg.highlight
	local style = (important and hl and hl.style) or "NONE"
	if style == "NONE" then
		if btn._hlStyle ~= "NONE" then
			btn._hlStyle = "NONE"
			if btn.hlFlash then btn.hlFlash:Stop() end
			btn.hl:Hide()
			if btn.hlFill then btn.hlFill:Hide() end
		end
		return
	end
	local c = (hl and hl.color) or DEFAULT_HL_COLOR
	if btn._hlStyle == style and btn._hlR == c.r and btn._hlG == c.g
		and btn._hlB == c.b and btn._hlA == c.a then
		return
	end
	btn._hlStyle, btn._hlR, btn._hlG, btn._hlB, btn._hlA = style, c.r, c.g, c.b, c.a
	if btn.hlFlash then btn.hlFlash:Stop() end
	btn.hl:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
	btn.hl:SetAlpha(c.a or 0.6)
	btn.hl:Show()
	if btn.hlFill then
		btn.hlFill:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
		btn.hlFill:SetAlpha((c.a or 0.6) * 0.5)
		btn.hlFill:Show()
	end
	if style ~= "BORDER" and btn.hlFlash then btn.hlFlash:Play() end
end


-- Default icon-border trim (matches the texcoord set at creation); the zoom multiplier
-- scales the visible fraction relative to this baseline so zoom = 1 leaves the look unchanged.
local ICON_BASE_VISIBLE = 1 - 0.08 * 2

-- Shared per-icon styling for lanes AND ready frames: configurable zoom + the "unusable"
-- tint/desaturate. IsSpellUsable is a plain boolean (combat-safe). Cached so the usable path
-- makes no setter calls after the first frame; texcoord re-applied only when zoom changes.
function ns.StyleIcon(btn, spellID, itemID, g)
	local tex = btn and btn.tex
	if not (tex and g) then return end

	-- A Masque skin owns the TexCoord (it re-crops via its own mask), so our zoom stands down there.
	if not ns.Masque_IsSkinned(btn) then
		local zoom = g.zoom or 1
		if zoom < 1 then zoom = 1 end
		if btn._zoom ~= zoom then
			btn._zoom = zoom
			local inset = (1 - ICON_BASE_VISIBLE / zoom) * 0.5
			tex:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
		end
	end

	local tint, desat = g.notUsableTint, g.notUsableDesaturate
	if not (tint or desat) then
		if btn._tinted then
			btn._tinted = nil
			tex:SetVertexColor(1, 1, 1)
			tex:SetDesaturated(false)
		end
		return
	end

	local usable = true
	if itemID then
		if C_Item and C_Item.IsUsableItem then usable = C_Item.IsUsableItem(itemID) end
	elseif spellID and spellID < ns.CONST.CUSTOM_ID_BASE and C_Spell and C_Spell.IsSpellUsable then
		-- A custom cooldown's synthetic id is no real spell, so skip the usable check (always usable).
		usable = C_Spell.IsSpellUsable(spellID)
	end

	if usable == false then
		if tint then
			local c = g.notUsableColor
			tex:SetVertexColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
		else
			tex:SetVertexColor(1, 1, 1)
		end
		tex:SetDesaturated(desat and true or false)
		btn._tinted = true
	elseif btn._tinted then
		btn._tinted = nil
		tex:SetVertexColor(1, 1, 1)
		tex:SetDesaturated(false)
	end
end


local DEFAULT_ICON_BORDER = { r = 0, g = 0, b = 0, a = 1 }

-- Icon border shared by lane icons and ready icons (cfg = the lane / ready-box table). Memoized
-- on the enabled flag, size, and color so the refresh only re-anchors/recolors on an actual
-- change; the border is a solid backing that extends `size` px beyond the icon, showing a ring.
function ns.ApplyIconBorder(btn, cfg)
	local b = btn.border
	if not b then return end
	-- Handed to Masque as the Normal region, which hides it and draws the skin's ring instead.
	if ns.Masque_IsSkinned(btn) then return end
	if not cfg.iconBorder then
		if btn._bOn ~= false then
			btn._bOn = false
			b:Hide()
		end
		return
	end
	local sz = cfg.iconBorderSize or 1
	local c  = cfg.iconBorderColor or DEFAULT_ICON_BORDER
	local a  = c.a or 1
	if btn._bOn and btn._bSz == sz
		and btn._bR == c.r and btn._bG == c.g and btn._bB == c.b and btn._bA == a then
		return
	end
	btn._bOn, btn._bSz = true, sz
	btn._bR, btn._bG, btn._bB, btn._bA = c.r, c.g, c.b, a
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", btn, "TOPLEFT", -sz, sz)
	b:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", sz, -sz)
	b:SetColorTexture(c.r, c.g, c.b, a)
	b:Show()
end


-- Per-lane Font object for the icon countdown. The native Cooldown widget draws the
-- timer (its value is secret in combat, so we can't), but SetCountdownFont restyles it
-- via this live font object - reconfiguring it updates the shown text immediately.
local function ConfigureLaneCountFont(laneFrame, cfg)
	local name = "CDMLaneCountFont" .. (laneFrame.index or 1)
	local fontObj = _G[name] or CreateFont(name)
	local path = (LSM and LSM:Fetch("font", cfg.iconFont, true)) or STANDARD_FONT
	local flags = cfg.iconFontFlags or "OUTLINE"
	if flags == "NONE" then flags = "" end
	-- 0/unset = auto: scale with icon size so the count matches the native sizing.
	local size = cfg.iconFontSize
	if not size or size <= 0 then size = math.max(6, math.floor((cfg.iconSize or 40) * 0.4)) end
	fontObj:SetFont(path, size, flags)
	local c = cfg.iconFontColor
	fontObj:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, c and c.a or 1)
	laneFrame._countFontName = name
	return name
end


local function ConfigureLaneTagFont(laneFrame, cfg)
	local name = "CDMLaneTagFont" .. (laneFrame.index or 1)
	local fontObj = _G[name] or CreateFont(name)
	local path = (LSM and LSM:Fetch("font", cfg.iconLabelFont, true)) or STANDARD_FONT
	local flags = cfg.iconLabelFlags or "OUTLINE"
	if flags == "NONE" then flags = "" end
	local size = cfg.iconLabelSize
	if not size or size <= 0 then size = 10 end
	fontObj:SetFont(path, size, flags)
	local c = cfg.iconLabelColor
	fontObj:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, c and c.a or 1)
	laneFrame._tagFontObj = fontObj
	laneFrame._tagLive = ns.TemplateHasLiveTag(cfg.iconLabel and cfg.iconLabel.text)
	return fontObj
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

	-- BackdropTemplateMixin reference-compares the backdropInfo table and skips work on the
	-- same reference, so mutating cached fields silently fails until /reload. Cache it for the
	-- steady state (no alloc), but on a structural change swap in a fresh reference to re-apply.
	local borderOn = cfg.borderEnabled ~= false
	local bgFile   = (LSM and LSM:Fetch("statusbar", cfg.bgTexture, true)) or WHITE8X8
	local edgeTex  = (LSM and LSM:Fetch("border", cfg.borderTexture, true)) or WHITE8X8
	local edgeFile = borderOn and edgeTex or ""
	local edgeSize = borderOn and (cfg.borderSize or 1) or 0
	local pad      = borderOn and (cfg.borderPadding or 0) or 0
	local bd = laneFrame._backdropCache
	local needsNew = (not bd)
		or bd.bgFile ~= bgFile
		or bd.edgeFile ~= edgeFile
		or bd.edgeSize ~= edgeSize
		or bd.insets.left ~= pad
	if needsNew then
		bd = {
			bgFile   = bgFile,
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

	-- Cache resolved chrome colors so SetLaneChrome can alpha-toggle the backdrop cheaply.
	laneFrame._chromeBg     = bg
	laneFrame._chromeBorder = (borderOn and cfg.borderColor) or nil

	laneFrame:SetSize(cfg.width, cfg.height)
	-- Don't reposition mid-drag (fights the mouse); IsMoving may be absent on
	-- some frame types, so guard the call.
	local isMoving = laneFrame.IsMoving and laneFrame:IsMoving()
	if not isMoving then
		laneFrame:ClearAllPoints()
		laneFrame:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.x, cfg.y)
	end
	laneFrame:SetScale(ns.GetFrameScale())
	-- Frame stays opaque so icons keep their own iconAlpha; cfg.alpha fades the bar chrome (SetLaneChrome).
	laneFrame:SetAlpha(1)
	ns.SnapFrameToPixelGrid(laneFrame)

	if laneFrame.label then
		local lc = cfg.labelColor or ns.CONST.RGB.YELLOW
		laneFrame.label:SetFont(ns.ResolveFont(cfg.labelFont, cfg.labelSize, cfg.labelFlags))
		laneFrame.label:SetTextColor(lc.r, lc.g, lc.b, 1)
		laneFrame.label:SetText(cfg.frameName or "")
		laneFrame.label:SetAlpha((addon.db.profile.global.unlockFrames and 0.6 or 0) * (lc.a or 1))
	end

	if laneFrame.statusText then
		ns.ApplyStatusTextStyle(laneFrame, laneFrame.statusText, cfg)
		laneFrame._statusStr = nil   -- force the next tick to re-resolve so new text/anchor shows at once
	end

	if laneFrame.markers and cfg.laneText then
		local mPath, mSize, mFlags = ns.ResolveFont(cfg.laneTextFont, cfg.laneTextSize, cfg.laneTextFlags)
		local mc = cfg.laneTextColor or ns.CONST.RGB.YELLOW
		for i = 1, 5 do
			local m = laneFrame.markers[i]
			local def = cfg.laneText[i]
			if m and def then
				if def.enabled then
					m:SetFont(mPath, mSize, mFlags)
					m:SetTextColor(mc.r, mc.g, mc.b, 1)
					m:SetText(def.text or "")
					m:ClearAllPoints()
					local pos = def.pos or 0
					if cfg.reversed then pos = 1 - pos end
					-- Labels at the extremes pin to the lane end (inset) so they don't clip;
					-- everything between centers on its position.
					if cfg.vertical then
						local laneH = cfg.height or 400
						if pos <= 0.02 then
							m:SetPoint("BOTTOM", laneFrame, "BOTTOM", 0, 2)
						elseif pos >= 0.98 then
							m:SetPoint("TOP", laneFrame, "TOP", 0, -2)
						else
							m:SetPoint("CENTER", laneFrame, "BOTTOM", 0, pos * laneH)
						end
					else
						local laneW = cfg.width or 400
						if pos <= 0.02 then
							m:SetPoint("LEFT", laneFrame, "LEFT", 5, 0)
						elseif pos >= 0.98 then
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

	ConfigureLaneCountFont(laneFrame, cfg)
	ConfigureLaneTagFont(laneFrame, cfg)

	ApplyTrackingConfig(laneFrame, cfg)
	RecomputeTrackingNeeds()

	-- This path restored chrome to full; re-apply the current show/hide state.
	local chrome = ChromeShown(addon, cfg)
	SetLaneChrome(addon, laneFrame, cfg, chrome)
	if laneFrame.dragHandle then
		local g = addon.db.profile.global
		ns.RefreshDragHandle(laneFrame.dragHandle, cfg.frameName,
			g.unlockFrames and LaneGatePasses(addon) and not chrome)
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

	-- Reuse the pooled frame: destroy-and-recreate orphaned the whole lane tree (never
	-- GC'd) on every profile switch and enable-toggle.
	local pooled = addon.lanePool[laneIndex]

	if cfg.enabled then
		if pooled then
			for j = 1, pooled.activeIcons do
				ClearLaneIcon(pooled.iconPool[j])
			end
			pooled.activeIcons = 0
			pooled.cfg = cfg   -- a profile switch swaps in a different lane cfg table
			addon.lanes[laneIndex] = pooled
			ns.Lanes_ApplyConfig(laneIndex)
			ApplyVisibility(addon)   -- ApplyConfig doesn't toggle show/hide
		else
			ns.Lanes_CreateLane(addon, laneIndex, cfg)   -- applies config itself
		end
	else
		if pooled then
			pooled:Hide()
			if pooled.dragHandle then pooled.dragHandle:Hide() end   -- UIParent child, won't hide with the frame
		end
		addon.lanes[laneIndex] = nil
		-- Re-evaluate swing tracking: a disabled lane that used SWING must release the
		-- combat-log hook, which the enabled/ApplyConfig path handles but this branch skipped.
		RecomputeTrackingNeeds()
	end
end


-- Stable slot assignment: pairs() order is unspecified and shifts as entries are added/removed,
-- reshuffling icons between pool slots and flickering their textures/swipes. Sort by startTime
-- so a fresh cooldown appends to the last slot (existing icons keep theirs); spellID breaks ties.
local refreshScratch = {}
-- The shared-cooldown dedupe keeps the FIRST of a group, so this order picks which potion is shown.
local function ByStartTime(a, b)
	if a.startTime ~= b.startTime then
		return (a.startTime or 0) < (b.startTime or 0)
	end
	local au, bu = ns.IsLastUsedItem(a), ns.IsLastUsedItem(b)
	if au ~= bu then return au end
	return a.spellID < b.spellID
end

-- Two entries count as one shared cooldown if they started together and end within
-- this window; the slack keeps a learned-vs-baseline duration mismatch from un-merging.
local SHARED_CD_TOL = 0.5


-- Reused scratch for the GROUPED stacking pass (kept module-level so the per-refresh
-- pack allocates nothing). Sorted by lane position; spellID breaks ties for stability.
local stackOrder  = {}
local stackRowEnd = {}
local function ByStackCoord(a, b)
	if a._stackCoord ~= b._stackCoord then
		return a._stackCoord < b._stackCoord
	end
	return (a._cdSpellID or 0) < (b._cdSpellID or 0)
end


local function ResetStackLevel(btn, base)
	if btn._stackLevel then
		btn._stackLevel = nil
		btn:SetFrameLevel(base)
	end
end

-- Stacking placement. GROUPED packs overlaps into perpendicular rows and OFFSET fans every icon
-- across stackHeight (both write _stackOff, the stable cross-axis offset); SPREAD pushes icons
-- apart along the lane (_spreadShift). Extracted so the 60 Hz lane OnUpdate can re-run SPREAD
-- live: its shift is relative to each icon's natural position, which the per-icon OnUpdate keeps
-- moving, so a shift computed only at the ~10 Hz refresh makes a blocked icon drift off its slot
-- then snap back each refresh -- a visible sawtooth as two icons pass. The cross-axis offsets are
-- stable between refreshes, so they need no live re-run.
local function ApplyStacking(laneFrame, cfg, count, iconSize, now)
	local style = cfg.stackStyle
	local base  = laneFrame:GetFrameLevel() + 1
	local stacking = cfg.stackEnabled and count > 1
		and (style == "GROUPED" or style == "SPREAD" or style == "OFFSET")
	if not stacking then
		for idx = 1, count do
			local btn = laneFrame.iconPool[idx]
			if btn then
				btn._stackOff    = 0
				btn._spreadShift = 0
				ResetStackLevel(btn, base)
			end
		end
		return
	end

	local laneDim = cfg.vertical and (cfg.height or 400) or (cfg.width or 400)
	local usable  = math.max(1, laneDim - iconSize)

	wipe(stackOrder)
	local n = 0
	for idx = 1, count do
		local btn = laneFrame.iconPool[idx]
		if btn and btn._endTime then
			local remaining = btn._endTime - now
			if remaining < 0 then remaining = 0 end
			local p = ModeProgress(cfg, remaining, btn._duration)
			-- Mirror the render path's ready-edge floor so stacking decides from where
			-- icons actually draw, not up to 2% of lane short of it.
			if btn._isActive and p < ICON_READY_FLOOR then p = ICON_READY_FLOOR end
			btn._stackCoord = p * usable
			n = n + 1
			stackOrder[n] = btn
		end
	end
	if n < 2 then
		local btn = stackOrder[1]
		if btn then btn._stackOff = 0; btn._spreadShift = 0; ResetStackLevel(btn, base) end
		return
	end
	table.sort(stackOrder, ByStackCoord)

	if style == "SPREAD" then
		-- Walk nearest-ready first; nudge each less-ready icon out so it sits at least one
		-- icon-width past the previous one. Keeps icons on the lane line (no row offset).
		local placedPrev
		for i = 1, n do
			local btn = stackOrder[i]
			local nat = btn._stackCoord
			local placed = nat
			if placedPrev and placed < placedPrev + iconSize then
				placed = placedPrev + iconSize
			end
			if placed > usable then placed = usable end
			btn._spreadShift = placed - nat
			btn._stackOff    = 0
			ResetStackLevel(btn, base)
			placedPrev = placed
		end
		return
	end

	-- GROUPED and OFFSET share the cross-axis grow rules: UP/RIGHT positive, DOWN/LEFT negative,
	-- CENTER straddles the lane line. Icons overlap once the pile exceeds stackHeight, so give each
	-- a rising frame level by sort position (a stable layer order; last in sort draws on top).
	local grow    = cfg.stackGrowDirection
	local center  = grow == "CENTER"
	local dirSign = (grow == "DOWN" or grow == "LEFT") and -1 or 1
	local height  = cfg.stackHeight or 0

	if style == "OFFSET" then
		local step = height / (n - 1)
		for i = 1, n do
			local btn = stackOrder[i]
			local o   = step * (i - 1)
			if center then o = o - height / 2 else o = o * dirSign end
			btn._stackOff    = o
			btn._spreadShift = 0
			local lvl = base + i
			if btn._stackLevel ~= lvl then btn._stackLevel = lvl; btn:SetFrameLevel(lvl) end
		end
		return
	end

	-- GROUPED: first-fit icons that overlap along the lane into rows, then size the row step so the
	-- whole band fits within stackHeight -- rows compress and overlap instead of the pile growing
	-- off the lane. maxRow (the deepest column) sets the compression.
	wipe(stackRowEnd)
	local maxRow = 1
	for i = 1, n do
		local btn  = stackOrder[i]
		local left = btn._stackCoord
		local r = 1
		while stackRowEnd[r] and left < stackRowEnd[r] do r = r + 1 end
		stackRowEnd[r] = left + iconSize
		btn._stackRow  = r
		if r > maxRow then maxRow = r end
	end

	local step = iconSize
	if maxRow > 1 and iconSize * maxRow > height then
		step = math.max(0, (height - iconSize) / (maxRow - 1))
	end
	local centerShift = center and ((maxRow - 1) * step) / 2 or 0

	for i = 1, n do
		local btn    = stackOrder[i]
		local rowOff = (btn._stackRow - 1) * step
		if center then btn._stackOff = rowOff - centerShift
		else btn._stackOff = rowOff * dirSign end
		btn._spreadShift = 0
		local lvl = base + i
		if btn._stackLevel ~= lvl then btn._stackLevel = lvl; btn:SetFrameLevel(lvl) end
	end
end


-- SPREAD spacing must track live positions (see ApplyStacking), so the 60 Hz lane OnUpdate
-- re-runs it: a passing icon then stays glued to its neighbor instead of drift-and-snapping
-- once per refresh. Self-gates to SPREAD lanes; no-op otherwise.
function ns.Lanes_RepackSpread(laneFrame)
	local cfg = laneFrame.cfg
	if not (cfg and cfg.stackEnabled and cfg.stackStyle == "SPREAD") then return end
	local count = laneFrame.activeIcons or 0
	if count < 2 then return end
	ApplyStacking(laneFrame, cfg, count, cfg.iconSize or 40, GetTime())
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
			ClearLaneIcon(laneFrame.iconPool[j])
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

	-- Runs even when the lane has no icons (placed after the shown-gate), and is skipped while chrome is autohidden.
	local stcfg = cfg.statusText
	if stcfg and stcfg.enabled and laneFrame.statusText and not laneFrame._chromeHidden then
		local sstr = ns.RenderTag(stcfg.text, nil)
		if laneFrame._statusStr ~= sstr then
			laneFrame._statusStr = sstr
			laneFrame.statusText:SetText(sstr)
		end
	end

	-- Icons take mouse only when tooltips are on AND frames are locked, so an unlocked
	-- lane still drags freely and tooltip-off play has no mouse capture at all.
	local g       = addon.db.profile.global
	local mouseOn = g.enableTooltip and not g.unlockFrames

	local visible = refreshScratch
	wipe(visible)
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
				-- Offensives likewise: they are only removed on the real fall-off edge, so an
				-- underestimated length must park the icon at the ready edge, not vanish mid-dot.
				if remaining > 0 or e._source == "isactive" or e._source == "offensive" then
					if not (remaining > maxTime and cfg.hideLongTimers) then
						visible[#visible + 1] = e
					end
				end
			end
		end
	end
	table.sort(visible, ByStartTime)

	-- Shared-cooldown dedupe for the lane render (the Engine mirrors this for ready pops). Sorted by
	-- startTime, so spells sharing a cooldown are contiguous; drop any whose start+length
	-- matches one already kept in the same start group, leaving the lowest-spellID icon.
	if g.detectSharedCD and #visible > 1 then
		local w = 0
		for r = 1, #visible do
			local e = visible[r]
			local dup = false
			for k = w, 1, -1 do
				local kept = visible[k]
				if kept.startTime ~= e.startTime then break end
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

	local count = #visible
	local overrides = addon.db.profile.spellOverrides
	for idx = 1, count do
		local e = visible[idx]
		local btn = AcquireIcon(laneFrame, idx, iconSize)
		-- Steady-state guards: these setters ran with identical values 10x/sec per icon;
		-- the wasted layout/texture work landed on render frames and read as a travel hitch.
		if btn._iconSize ~= iconSize then
			btn:SetSize(iconSize, iconSize)
			btn.cdAnchor:SetSize(iconSize, iconSize)
			ns.Masque_ReSkin(btn)
		end
		if btn._texIcon ~= e.icon then
			btn._texIcon = e.icon
			btn.tex:SetTexture(e.icon)
		end
		-- Feed the native cooldown once per instance, keyed on spellID+startTime so a
		-- reused pool slot re-feeds when it switches spells.
		if btn._cdSpellID ~= e.spellID or btn._cdStart ~= e.startTime or btn._cdGen ~= e._feedGen then
			btn._cdSpellID = e.spellID
			btn._cdItemID  = e.itemID   -- nil for spells; picks SetItemByID vs SetSpellByID in the tooltip
			btn._cdCustom  = (e.spellID or 0) >= ns.CONST.CUSTOM_ID_BASE
			btn._cdName    = e.name
			btn._cdStart   = e.startTime
			btn._cdGen     = e._feedGen
			btn._justFed   = true   -- position synchronously below, before this frame renders
			-- Prefer the opaque DurationObject, but the privileged setter can throw on
			-- a stale/secret handle and leave the widget with no cooldown, so fall back
			-- to extrapolated numbers when it's missing or pcall fails.
			local fed = false
			if e.dObj and btn.cd.SetCooldownFromDurationObject then
				fed = pcall(btn.cd.SetCooldownFromDurationObject, btn.cd, e.dObj)
			end
			if not fed and e.startTime and e.duration then
				btn.cd:SetCooldown(e.startTime, e.duration)
			end
			btn._cdFedPath = fed and "dObj" or "numbers"
			e._cdFedPath   = btn._cdFedPath   -- surfaced by /cdmaster debug

			-- SetCountdownFont is Retail-only (Midnight); feeding the cooldown can also reset
			-- the count font, so re-bind our live font object on each feed.
			if btn.cd.SetCountdownFont and laneFrame._countFontName then
				btn.cd:SetCountdownFont(laneFrame._countFontName)
			end
			-- Feeding can also reset swipe color / number visibility; drop the memos so the
			-- guarded setters below re-apply on this pass.
			btn._hideNums, btn._swipeA = nil, nil
		end

		-- The native widget owns the countdown text; this toggle only controls
		-- whether its number is drawn. Guarded: re-running these with identical values
		-- 10x/sec per icon put avoidable widget work on render frames.
		local showTime = (cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled)
			and true or false
		if btn._hideNums ~= showTime then
			btn._hideNums = showTime
			btn.cd:SetHideCountdownNumbers(not showTime)
		end

		-- Cooldown-swipe darkness (0 = no tint).
		local swipeA = cfg.swipeAlpha or 0.8
		if btn._swipeA ~= swipeA then
			btn._swipeA = swipeA
			btn.cd:SetSwipeColor(0, 0, 0, swipeA)
		end

		ns.StyleIcon(btn, e.spellID, e.itemID, g)
		ns.ApplyIconBorder(btn, cfg)

		local lbl = cfg.iconLabel
		if lbl and lbl.enabled then
			if btn._tagFontObj ~= laneFrame._tagFontObj then
				btn._tagFontObj = laneFrame._tagFontObj
				if laneFrame._tagFontObj then btn.tagText:SetFontObject(laneFrame._tagFontObj) end
			end
			local anch = lbl.anchor or "BOTTOM"
			if btn._tagAnchor ~= anch then
				btn._tagAnchor = anch
				btn.tagText:ClearAllPoints()
				if anch == "TOP" then
					btn.tagText:SetPoint("BOTTOM", btn.cdAnchor, "TOP", 0, 1)
				elseif anch == "CENTER" then
					btn.tagText:SetPoint("CENTER", btn.cdAnchor, "CENTER", 0, 0)
				else
					btn.tagText:SetPoint("TOP", btn.cdAnchor, "BOTTOM", 0, -1)
				end
			end
			-- A static template moves only when this slot's entry does, so re-resolve on an entry or template change. A live template resolves each pass.
			if laneFrame._tagLive or btn._tagEntry ~= e.spellID or btn._tagTemplate ~= lbl.text then
				btn._tagEntry = e.spellID
				btn._tagTemplate = lbl.text
				local str = ns.RenderTag(lbl.text, e)
				if btn._tagStr ~= str then
					btn._tagStr = str
					btn.tagText:SetText(str)
				end
			end
			if not btn._tagShown then
				btn._tagShown = true
				btn.tagText:Show()
			end
		elseif btn._tagShown ~= false then
			btn._tagShown = false
			btn.tagText:Hide()
		end

		if btn._mouseOn ~= mouseOn then
			btn._mouseOn = mouseOn
			btn:EnableMouse(mouseOn)
		end

		btn:Show()
		btn._endTime  = e.endTime
		btn._duration = e.duration
		btn._cfg      = cfg
		btn._iconSize = iconSize
		btn._isActive = e._source == "isactive"   -- gates the ready-edge floor (extrapolated position only)

		local ov = overrides and overrides[e.spellID]
		ApplyLaneHighlight(btn, cfg, ov and ov.important == true)
	end

	-- Stacking declutters clustered cooldowns. GROUPED and OFFSET here at refresh cadence (~10 Hz)
	-- is fine (their offset is on the stable cross axis); SPREAD is also re-run live at 60 Hz by the
	-- lane OnUpdate so passing icons stay glued instead of drift-and-snapping (see ApplyStacking).
	ApplyStacking(laneFrame, cfg, count, iconSize, now)

	-- A slot that changed occupants (resort/re-anchor/reuse) still sits at its previous
	-- anchor and would render one ghost frame there before its OnUpdate runs; position it
	-- synchronously now. Runs after stacking so _stackOff/_spreadShift are current.
	for idx = 1, count do
		local btn = laneFrame.iconPool[idx]
		if btn._justFed then
			btn._justFed = nil
			local h = btn:GetScript("OnUpdate")
			if h then h(btn, 0) end
		end
	end

	-- Clear the instance keys on unused pool slots so a reused slot re-feeds
	-- its cooldown cleanly next time.
	for j = count + 1, laneFrame.activeIcons do
		ClearLaneIcon(laneFrame.iconPool[j])
	end
	laneFrame.activeIcons = count
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
	-- Applies chrome + drag-mouse + label in one pass; only the gate (never lock) hides a lane.
	ApplyVisibility(addon)
end


function ns.Lanes_OnCombatChange(inCombat)
	ApplyVisibility(ns.CDM)
end


function ns.Lanes_RefreshVisibility()
	ApplyVisibility(ns.CDM)
end
