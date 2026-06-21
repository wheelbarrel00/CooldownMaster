local ADDON_NAME, ns = ...

local ICON_SIZE = 40

local function AcquireReadyIcon(f, index)
	local pool = f.iconPool
	local btn  = pool[index]
	if btn then return btn end

	btn = CreateFrame("Frame", "CooldownMaster_Ready_"..f.index.."_Btn_"..index, f)
	btn:SetSize(ICON_SIZE, ICON_SIZE)

	btn.tex = btn:CreateTexture(nil, "ARTWORK")
	btn.tex:SetAllPoints(btn)
	btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	btn.time = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.time:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
	btn.time:SetTextColor(1, 1, 1, 1)

	btn.charges = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	btn.charges:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
	btn.charges:SetTextColor(1, 1, 1, 1)
	btn.charges:Hide()

	btn:Hide()
	pool[index] = btn
	return btn
end

local function RelayoutReadyFrame(f)
	local cfg      = f.cfg
	local iconSize = cfg.iconSize or ICON_SIZE
	local yPad     = cfg.yPadding or 0
	local xPad     = cfg.xPadding or 0
	local xOff     = cfg.iconOffset or 0
	local step     = iconSize + yPad

	-- Border inset is added to the margin so icons aren't clipped by the border.
	local borderOn  = cfg.borderEnabled == true or cfg.borderEnabled == nil
	local borderIns = borderOn and ((cfg.borderSize or 0) + (cfg.borderPadding or 0)) or 0
	local margin    = borderIns + xPad

	local active   = {}

	for i = 1, #f.iconPool do
		local btn = f.iconPool[i]
		if btn and btn:IsShown() then
			active[#active + 1] = btn
		end
	end

	for k, btn in ipairs(active) do
		btn:SetSize(iconSize, iconSize)
		btn:ClearAllPoints()
		if cfg.growDirection == "UP" then
			btn:SetPoint("BOTTOM", f, "BOTTOM", xOff, margin + step * (k - 1))
		else
			btn:SetPoint("TOP", f, "TOP", xOff, -margin - step * (k - 1))
		end
	end

	local count    = math.max(1, #active)
	local innerH   = (count - 1) * step + iconSize
	f:SetSize(iconSize + margin * 2, innerH + margin * 2)
end

function ns.ReadyFrames_Build(addon)
	-- Repair saved cfg fields corrupted by an older bug (e.g. color tables written as scalars).
	for i = 1, 3 do
		local cfg = addon.db.profile.readyFrames[i]
		if cfg then
			if type(cfg.bgColor) ~= "table" then
				cfg.bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
			end
			if type(cfg.borderColor) ~= "table" then
				cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
			end
			if type(cfg.iconSize) ~= "number" then
				cfg.iconSize = 40
			end
			if type(cfg.iconAlpha) ~= "number" then
				cfg.iconAlpha = 1.0
			end
			if type(cfg.iconOffset) ~= "number" then
				cfg.iconOffset = 0
			end
			if type(cfg.iconText) ~= "table" then
				cfg.iconText = {
					{ enabled = true,  text = "[cd.stacks]" },
					{ enabled = true,  text = "[cd.time]"   },
					{ enabled = false, text = ""            },
				}
			end
		end
	end
	for i = 1, 3 do
		local cfg = addon.db.profile.readyFrames[i]
		if cfg.enabled and not addon.readyFrames[i] then
			ns.ReadyFrames_CreateFrame(addon, i, cfg)
			ns.ReadyFrames_ApplyConfig(i)
		end
	end
end


function ns.ReadyFrames_CreateFrame(addon, index, cfg)
	local f = CreateFrame("Frame", "CooldownMaster_Ready_"..index, UIParent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(ICON_SIZE, ICON_SIZE)
	f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -250)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.laneIndex = index  -- kept for parity; used in drag save
	f.index     = index
	f.cfg       = cfg
	f.iconPool  = {}
	f.activeIcons = 0

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
		local rfCfg = cdm and cdm.db.profile.readyFrames[self.index]
		if rfCfg then
			rfCfg.anchor = point
			rfCfg.x = math.floor(x + 0.5)
			rfCfg.y = math.floor(y + 0.5)
		end
	end)

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
		local cfgAlpha = (cfg and cfg.iconAlpha) or 1
		local timeEnabled = cfg and cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled
		local needRelayout = false
		for i = 1, #self.iconPool do
			local btn = self.iconPool[i]
			if btn and btn:IsShown() then
				btn._readyTime = (btn._readyTime or 0) - elapsed
				if btn._readyTime <= 0 then
					btn:Hide()
					btn:SetAlpha(1)
					needRelayout = true
				elseif btn._readyTime <= 1.0 then
					btn:SetAlpha(cfgAlpha * btn._readyTime)
				else
					btn:SetAlpha(cfgAlpha)
				end

				if btn._readyTime > 0 then
					if timeEnabled then
						if btn._readyTime <= 10 then
							btn.time:SetText(string.format("%.1f", btn._readyTime))
						else
							btn.time:SetText(string.format("%d", math.floor(btn._readyTime + 0.5)))
						end
						btn.time:Show()
					else
						btn.time:Hide()
					end
				end
			end
		end
		if needRelayout then
			RelayoutReadyFrame(self)
		end
	end)

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("CENTER")
	label:SetText(cfg.frameName)
	label:SetTextColor(ns.CONST.RGB.YELLOW.r, ns.CONST.RGB.YELLOW.g, ns.CONST.RGB.YELLOW.b)
	label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
	f.label = label

	addon.readyFrames[index] = f
end


function ns.ReadyFrames_OnReadyTransition(spellID, entry)
	local addon = ns.CDM
	if not addon then return end

	local target
	for i = 1, 3 do
		local rf   = addon.readyFrames and addon.readyFrames[i]
		local rcfg = addon.db.profile.readyFrames[i]
		if rf and rcfg and rcfg.enabled then
			target = rf
			break
		end
	end
	if not target then return end

	local cfg = target.cfg

	local slot = nil
	for i = 1, #target.iconPool do
		local btn = target.iconPool[i]
		if btn and not btn:IsShown() then
			slot = i
			break
		end
	end
	if not slot then
		slot = #target.iconPool + 1
	end

	local btn = AcquireReadyIcon(target, slot)
	btn.tex:SetTexture(entry.icon or "")
	btn._spellID        = spellID
	btn._readyTime      = cfg.normalDuration or 5
	btn._totalReadyTime = cfg.normalDuration or 5
	btn:SetAlpha(cfg.iconAlpha or 1)

	if cfg.iconText and cfg.iconText[1] and cfg.iconText[1].enabled
	   and entry.charges and entry.maxCharges then
		btn.charges:SetText(string.format("%d/%d", entry.charges, entry.maxCharges))
		btn.charges:Show()
	else
		btn.charges:Hide()
	end

	if cfg.iconText and cfg.iconText[2] and cfg.iconText[2].enabled then
		local t = btn._readyTime
		if t <= 10 then
			btn.time:SetText(string.format("%.1f", t))
		else
			btn.time:SetText(string.format("%d", math.floor(t + 0.5)))
		end
		btn.time:Show()
	else
		btn.time:Hide()
	end

	btn:Show()

	RelayoutReadyFrame(target)

	local soundName = cfg.normalSound
	if soundName and soundName ~= "None" then
		local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
		if ok and LSM then
			local soundPath = LSM:Fetch("sound", soundName)
			if soundPath then
				pcall(PlaySoundFile, soundPath, "Master")
			end
		end
	end
end


function ns.ReadyFrames_RefreshUnlockState(addon)
	for i = 1, 3 do
		local f = addon.readyFrames and addon.readyFrames[i]
		if f and f.label then
			local unlocked = addon.db.profile.global.unlockFrames
			f.label:SetAlpha(unlocked and 0.6 or 0)
		end
	end
end


function ns.ReadyFrames_ApplyConfig(index)
	local ok, err = pcall(function()
		local addon = ns.CDM
		if not addon then return end
		local f = addon.readyFrames and addon.readyFrames[index]
		if not f then return end
		local cfg = addon.db.profile.readyFrames[index]
		if not cfg then return end

		local isMoving = f.IsMoving and f:IsMoving()
		if not isMoving then
			f:ClearAllPoints()
			f:SetPoint(cfg.anchor or "CENTER", UIParent, cfg.anchor or "CENTER", cfg.x or 0, cfg.y or -250)
		end

		local borderOn = cfg.borderEnabled ~= false
		-- Repair color cfg corrupted by an older bug (scalars instead of tables).
		if type(cfg.bgColor) ~= "table" then
			cfg.bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
		end
		if type(cfg.borderColor) ~= "table" then
			cfg.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		local edgeFile = borderOn and "Interface\\Buttons\\WHITE8x8" or ""
		local edgeSize = borderOn and (cfg.borderSize or 1) or 0
		local bpad     = borderOn and (cfg.borderPadding or 0) or 0
		pcall(f.SetBackdrop, f, {
			bgFile   = "Interface\\Buttons\\WHITE8x8",
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets   = { left = bpad, right = bpad, top = bpad, bottom = bpad },
		})
		local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.85 }
		pcall(f.SetBackdropColor, f, bg.r, bg.g, bg.b, bg.a or 1)
		if borderOn then
			local bc = cfg.borderColor
			if bc then pcall(f.SetBackdropBorderColor, f, bc.r, bc.g, bc.b, bc.a or 1) end
		else
			pcall(f.SetBackdropBorderColor, f, 0, 0, 0, 0)
		end
		f:SetAlpha(cfg.alpha or 1)

		if f.label then
			f.label:SetText(cfg.frameName or "")
			f.label:SetAlpha(addon.db.profile.global.unlockFrames and 0.6 or 0)
		end

		RelayoutReadyFrame(f)
	end)
	if not ok then
		if _G.CooldownMaster then
			_G.CooldownMaster:Print("ReadyFrames_ApplyConfig error: " .. tostring(err))
		end
	end
end


function ns.ReadyFrames_RebuildOne(index)
	local addon = ns.CDM
	if not addon or not addon.db then return end
	local cfg = addon.db.profile.readyFrames[index]
	if not cfg then return end

	local existing = addon.readyFrames and addon.readyFrames[index]
	if existing then
		existing:Hide()
		existing:SetParent(nil)
		addon.readyFrames[index] = nil
	end

	if cfg.enabled then
		ns.ReadyFrames_CreateFrame(addon, index, cfg)
		ns.ReadyFrames_ApplyConfig(index)
	end
end
