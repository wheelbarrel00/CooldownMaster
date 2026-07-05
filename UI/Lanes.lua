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
local pxWatch = CreateFrame("Frame")
pxWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
pxWatch:RegisterEvent("UI_SCALE_CHANGED")
pxWatch:SetScript("OnEvent", function()
	PIXEL_FACTOR = 768 / select(2, GetPhysicalScreenSize())
end)

-- /cm snap diagnostic: quantize icon travel itself to whole physical pixels. Ships OFF --
-- the live A/B verdict was gliding icons + snapped cooldown carrier (see AcquireIcon);
-- kept as a support tool for exotic scale setups.
local snapIcons = false

function ns.Lanes_ToggleSnapIcons()
	snapIcons = not snapIcons
	PIXEL_FACTOR = 768 / select(2, GetPhysicalScreenSize())
	return snapIcons
end

-- Register the built-in names so saved "CDM Smooth"/"CDM Shadow" resolve and list
-- alongside the user's LSM media; WHITE8x8 keeps the default flat look unchanged.
if LSM then
	pcall(LSM.Register, LSM, "statusbar", "CDM Smooth", WHITE8X8)
	pcall(LSM.Register, LSM, "border",    "CDM Shadow", WHITE8X8)
end


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


local function LaneGatePasses(addon)
	if ns.Engine and ns.Engine.testActive then return true end
	return VisibilityGatePasses(addon.db.profile.global)
end


-- Autohide hides only the chrome (bg/border/name/markers), never the icon children, so
-- cooldowns stay visible out of combat. Unlock force-shows chrome so it can be dragged.
local function ChromeShown(addon, cfg)
	local g = addon.db.profile.global
	if ns.Engine and ns.Engine.testActive then return true end
	if g.unlockFrames then return true end
	if not g.autohide then return true end
	if addon.combat then return true end
	return cfg.overrideAutohide and true or false
end


-- Alpha-toggle the chrome only; never the frame alpha or the icon children (that is what
-- keeps icons lit). Backdrop is the frame's own artwork, so alpha-zero it, don't detach.
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
	if f.label then
		f.label:SetAlpha(show and (addon.db.profile.global.unlockFrames and 0.6 or 0) * a or 0)
	end
	if f.markers and cfg.laneText then
		for i = 1, 5 do
			local m, def = f.markers[i], cfg.laneText[i]
			if m and def then
				if show and def.enabled then m:SetAlpha(a); m:Show() else m:Hide() end
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
	for i = 1, 3 do
		local f = addon.lanes[i]
		if f and f.cfg then
			if LaneGatePasses(addon) then
				f:Show()
				SetLaneChrome(addon, f, f.cfg, ChromeShown(addon, f.cfg))
			else
				f:Hide()
			end
			-- Drag-only mouse: a shown-but-chrome-hidden lane must not swallow clicks.
			f:EnableMouse(unlocked)
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
		local usable = math.max(1, (cfg.height or 17) - (cfg.stHeight or 24))
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
	f.st:SetSize(cfg.stWidth or 7, cfg.stHeight or 24)
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


-- /cm text: can the native countdown widget's displayed STRING be mirrored onto our own
-- FontString? The widget converts the secret duration to text C-side; if that string is
-- readable (or displayable even while secret), we can render the countdown on a plain
-- gliding FontString -- which WoW moves smoothly (CDTL2/FCT-proven) -- instead of the
-- widget's internal text, whose C-side layout shimmers/hops in motion.
function ns.Lanes_TextProbe()
	local cdm = ns.CDM
	if not cdm then return end
	local iss = _G.issecretvalue
	local found
	for i = 1, 3 do
		local lane = cdm.lanes and cdm.lanes[i]
		for j = 1, (lane and lane.activeIcons) or 0 do
			local btn = lane.iconPool[j]
			if btn and btn:IsShown() and btn.cd then found = btn; break end
		end
		if found then break end
	end
	if not found then
		cdm:Print("text probe: no live lane icon -- start Test Mode or put something on cooldown.")
		return
	end
	local fs
	for i = 1, found.cd:GetNumRegions() do
		local r = select(i, found.cd:GetRegions())
		if r and r.GetObjectType and r:GetObjectType() == "FontString" then fs = r; break end
	end
	if not fs then
		cdm:Print("text probe: native countdown FontString NOT reachable from Lua.")
		return
	end
	local okG, txt = pcall(fs.GetText, fs)
	local secret = (okG and iss and iss(txt)) or false
	cdm:Print(string.format("text probe: inCombat=%s GetText ok=%s secret=%s type=%s value=%s",
		tostring(InCombatLockdown()), tostring(okG), tostring(secret),
		okG and type(txt) or "?",
		(okG and not secret) and tostring(txt) or "?"))
	ns._probeFS = ns._probeFS or UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	local okS, sErr = pcall(ns._probeFS.SetText, ns._probeFS, txt)
	-- Everything downstream can be secret (width, even the error object); never tostring
	-- a value before issecretvalue clears it -- that throw is what ate this print in v1.
	local okW, w = pcall(ns._probeFS.GetStringWidth, ns._probeFS)
	local wSecret = (okW and iss and iss(w)) or false
	local errShow = "-"
	if not okS then
		local okT, es = pcall(tostring, sErr)
		errShow = (okT and es) or "<untostringable>"
	end
	cdm:Print(string.format("text probe: SetText-on-own-FS ok=%s widthSecret=%s width=%s err=%s",
		tostring(okS), tostring(wSecret),
		(okW and not wSecret) and tostring(w) or "?", errShow))
	-- Accepting a secret string is not the same as DRAWING it: park the scratch FS mid-screen
	-- so the user can see whether a digit actually renders.
	ns._probeFS:ClearAllPoints()
	ns._probeFS:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
	ns._probeFS:Show()
	C_Timer.After(5, function() ns._probeFS:Hide() end)
	cdm:Print("text probe: look ABOVE SCREEN CENTER for ~5s -- is a number visible there?")
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


function ns.Lanes_CreateLane(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Lane_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(cfg.width, cfg.height)
	f:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.x, cfg.y)
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

	f.markers = {}
	for i = 1, 5 do
		local m = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		local mfp, _, mfl = m:GetFont()
		if mfp then m:SetFont(mfp, 9, mfl) end
		m:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
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

	-- Highlight overlay for Important spells (Border / Glow / Flash), mirroring the
	-- ready box. Additive border anchored a few px out so it tracks icon size.
	btn.hl = btn:CreateTexture(nil, "OVERLAY")
	btn.hl:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	btn.hl:SetBlendMode("ADD")
	btn.hl:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6)
	btn.hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
	btn.hl:Hide()
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

		-- /cm snap diagnostic: quantize travel to whole physical pixels (see header note).
		-- Snapped in SCREEN space: the lane's own origin sits on a fractional pixel at most
		-- UI scales, so lane-local snapping reproduces that fraction in every icon position
		-- and can park the text layout on a rounding boundary (verified on a 4K/0.5 setup).
		if snapIcons then
			local psize  = PIXEL_FACTOR / self:GetEffectiveScale()
			local parent = self:GetParent()
			local base
			if point == "LEFT" then base = parent:GetLeft()
			elseif point == "RIGHT" then base = parent:GetRight()
			elseif point == "BOTTOM" then base = parent:GetBottom()
			elseif point == "TOP" then base = parent:GetTop() end
			if base then
				coord = math.floor((base + coord) / psize + 0.5) * psize - base
			else
				coord = math.floor(coord / psize + 0.5) * psize
			end
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
	btn._hlStyle = nil
	if btn.cd then btn.cd:Clear() end
	btn:Hide()
end


local DEFAULT_HL_COLOR = { r = 1, g = 0.82, b = 0, a = 0.6 }

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

	local zoom = g.zoom or 1
	if zoom < 1 then zoom = 1 end
	if btn._zoom ~= zoom then
		btn._zoom = zoom
		local inset = (1 - ICON_BASE_VISIBLE / zoom) * 0.5
		tex:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
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
	elseif spellID and C_Spell and C_Spell.IsSpellUsable then
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


-- Per-lane Font object for the icon countdown. The native Cooldown widget draws the
-- timer (its value is secret in combat, so we can't), but SetCountdownFont restyles it
-- via this live font object — reconfiguring it updates the shown text immediately.
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
	-- Frame stays opaque so icons keep their own iconAlpha; cfg.alpha fades the bar chrome (SetLaneChrome).
	laneFrame:SetAlpha(1)

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

	ApplyTrackingConfig(laneFrame, cfg)
	RecomputeTrackingNeeds()

	-- This path restored chrome to full; re-apply the current show/hide state.
	SetLaneChrome(addon, laneFrame, cfg, ChromeShown(addon, cfg))
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
		if pooled then pooled:Hide() end
		addon.lanes[laneIndex] = nil
	end
end


-- Stable slot assignment: pairs() order is unspecified and shifts as entries are added/removed,
-- reshuffling icons between pool slots and flickering their textures/swipes. Sort by startTime
-- so a fresh cooldown appends to the last slot (existing icons keep theirs); spellID breaks ties.
local refreshScratch = {}
local function ByStartTime(a, b)
	if a.startTime ~= b.startTime then
		return (a.startTime or 0) < (b.startTime or 0)
	end
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
				if remaining > 0 or e._source == "isactive" then
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
				if math.abs((e.endTime or 0) - (kept.endTime or 0)) <= SHARED_CD_TOL then
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
		end
		if btn._texIcon ~= e.icon then
			btn._texIcon = e.icon
			btn.tex:SetTexture(e.icon)
		end
		-- Feed the native cooldown once per instance, keyed on spellID+startTime so a
		-- reused pool slot re-feeds when it switches spells.
		if btn._cdSpellID ~= e.spellID or btn._cdStart ~= e.startTime then
			btn._cdSpellID = e.spellID
			btn._cdItemID  = e.itemID   -- nil for spells; picks SetItemByID vs SetSpellByID in the tooltip
			btn._cdStart   = e.startTime
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

	-- Stacking declutters clustered cooldowns, recomputed at refresh cadence (~10 Hz); membership
	-- shifts slowly since icons crawl <4 px between refreshes. GROUPED packs overlaps into
	-- perpendicular rows (_stackOff); SPREAD pushes them apart along the lane (_spreadShift).
	local stacking = cfg.stackEnabled and count > 1
		and (cfg.stackStyle == "GROUPED" or cfg.stackStyle == "SPREAD")
	if stacking then
		local laneDim = cfg.vertical and (cfg.height or 400) or (cfg.width or 400)
		local usable  = math.max(1, laneDim - iconSize)

		wipe(stackOrder)
		for idx = 1, count do
			local btn = laneFrame.iconPool[idx]
			local remaining = (btn._endTime or now) - now
			if remaining < 0 then remaining = 0 end
			local p = ModeProgress(cfg, remaining, btn._duration)
			-- Mirror the render path's ready-edge floor so stacking decides from where
			-- icons actually draw, not up to 2% of lane short of it.
			if btn._isActive and p < ICON_READY_FLOOR then p = ICON_READY_FLOOR end
			btn._stackCoord = p * usable
			stackOrder[idx] = btn
		end
		table.sort(stackOrder, ByStackCoord)

		if cfg.stackStyle == "SPREAD" then
			-- Walk nearest-ready first; nudge each less-ready icon out so it sits at least
			-- one icon-width past the previous one. Keeps icons on the lane line (no row
			-- offset), trading exact cooldown position for non-overlap.
			local placedPrev
			for i = 1, count do
				local btn = stackOrder[i]
				local nat = btn._stackCoord
				local placed = nat
				if placedPrev and placed < placedPrev + iconSize then
					placed = placedPrev + iconSize
				end
				if placed > usable then placed = usable end
				btn._spreadShift = placed - nat
				btn._stackOff    = 0
				placedPrev = placed
			end
		else
			local rowStep = iconSize
			local maxRows = math.max(1, math.floor((cfg.stackHeight or 0) / rowStep))
			local dirSign
			if cfg.vertical then
				dirSign = (cfg.stackGrowDirection == "LEFT") and -1 or 1
			else
				dirSign = (cfg.stackGrowDirection == "DOWN") and -1 or 1
			end

			wipe(stackRowEnd)
			for i = 1, count do
				local btn  = stackOrder[i]
				local left = btn._stackCoord
				local row
				for r = 1, maxRows do
					if not stackRowEnd[r] or left >= stackRowEnd[r] then row = r; break end
				end
				if not row then
					-- All rows full within the height budget: drop into the one that frees
					-- soonest (smallest right edge) and accept the partial overlap.
					row = 1
					for r = 2, maxRows do
						if stackRowEnd[r] < stackRowEnd[row] then row = r end
					end
				end
				stackRowEnd[row] = left + iconSize
				btn._stackOff    = (row - 1) * rowStep * dirSign
				btn._spreadShift = 0
			end
		end
	else
		for idx = 1, count do
			local btn = laneFrame.iconPool[idx]
			btn._stackOff    = 0
			btn._spreadShift = 0
		end
	end

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
