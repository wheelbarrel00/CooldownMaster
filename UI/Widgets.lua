local ADDON_NAME, ns = ...

ns.Widgets = {}
local Widgets = ns.Widgets


local RGB     = ns.CONST.RGB
local YELLOW  = RGB.YELLOW
local RED     = RGB.RED
local RED_DIM = RGB.RED_DIM
local PANEL_BG     = RGB.PANEL_BG
local PANEL_BORDER = RGB.PANEL_BORDER


-- Invariant descriptor; SetBackdrop reads it at call time, so one shared table is safe.
local WIDGET_BACKDROP = {
	bgFile   = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
	insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Duplicates Theme.ApplyBackdrop to avoid a load-time circular file dependency.
local function applyBackdrop(frame, fillColor, borderColor)
	frame:SetBackdrop(WIDGET_BACKDROP)
	local bg = fillColor   or PANEL_BG
	local bd = borderColor or PANEL_BORDER
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)
end


-- Slider/dropdown labels are FontStrings (no mouse input), so lay a transparent hit frame
-- over the label to surface cfg.tooltip on hover. Sits above the label only, so it never
-- blocks the control beneath it.
local function attachLabelTooltip(root, label, cfg)
	if not cfg.tooltip then return end
	local hit = CreateFrame("Frame", nil, root)
	hit:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 0)
	hit:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, 0)
	hit:EnableMouse(true)
	hit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(cfg.label or "")
		GameTooltip:AddLine(cfg.tooltip, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
end


function Widgets.AttachLabelTip(root, label, cfg)
	attachLabelTooltip(root, label, cfg)
end


function Widgets.CreateSectionHeader(parent, labelText)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(18)

	local left = f:CreateTexture(nil, "ARTWORK")
	left:SetColorTexture(YELLOW.r, YELLOW.g, YELLOW.b, 0.9)
	left:SetHeight(1)
	left:SetPoint("LEFT", f, "LEFT", 0, 0)

	local right = f:CreateTexture(nil, "ARTWORK")
	right:SetColorTexture(YELLOW.r, YELLOW.g, YELLOW.b, 0.9)
	right:SetHeight(1)
	right:SetPoint("RIGHT", f, "RIGHT", 0, 0)

	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(labelText or "")
	label:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	left:SetPoint("RIGHT", label, "LEFT", -6, 0)
	right:SetPoint("LEFT", label, "RIGHT", 6, 0)

	f.label = label
	return f
end


function Widgets.CreateCheckbox(parent, cfg)
	cfg = cfg or {}
	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(220, 24)

	local cb = CreateFrame("CheckButton", nil, root, "UICheckButtonTemplate")
	cb:SetPoint("LEFT", root, "LEFT", 0, 0)
	cb:SetSize(24, 24)

	local fs = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(cfg.label or "")

	cb:SetChecked(cfg.checked and true or false)
	cb:SetScript("OnClick", function(self)
		local v = self:GetChecked() and true or false
		if root._onChange then root._onChange(v) end
	end)

	if cfg.tooltip then
		-- Extend the hit rect over the label so hovering anywhere on the row shows the tip.
		cb:SetHitRectInsets(0, cb:GetWidth() - root:GetWidth(), 0, 0)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(cfg.label or "")
			GameTooltip:AddLine(cfg.tooltip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	root._cb       = cb
	root._onChange = cfg.onChange

	function root:GetValue() return cb:GetChecked() and true or false end
	function root:SetValue(v) cb:SetChecked(v and true or false) end

	return root
end


function Widgets.CreateSlider(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 220
	local minV  = cfg.min or 0
	local maxV  = cfg.max or 100
	local step  = cfg.step or 1

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 56)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)
	attachLabelTooltip(root, label, cfg)

	local track = CreateFrame("Frame", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	track:SetPoint("TOP", label, "BOTTOM", 0, -4)
	track:SetSize(width, 8)
	applyBackdrop(track, { r = 0.08, g = 0.08, b = 0.08, a = 1 }, PANEL_BORDER)

	local minLabel = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	minLabel:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -1)
	minLabel:SetText(tostring(minV))
	minLabel:SetTextColor(1, 1, 1)

	local maxLabel = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	maxLabel:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -1)
	maxLabel:SetText(tostring(maxV))
	maxLabel:SetTextColor(1, 1, 1)

	local slider = CreateFrame("Slider", nil, track, "OptionsSliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetAllPoints(track)
	if slider.Low  then slider.Low:Hide()  end
	if slider.High then slider.High:Hide() end
	if slider.Text then slider.Text:Hide() end

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(RED.r, RED.g, RED.b, 1)
	thumb:SetSize(10, 16)
	slider:SetThumbTexture(thumb)

	local edit = CreateFrame("EditBox", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	edit:SetPoint("TOP", track, "BOTTOM", 0, -2)
	edit:SetSize(70, 18)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetJustifyH("CENTER")
	edit:SetTextInsets(2, 2, 1, 1)
	applyBackdrop(edit, { r = 0.05, g = 0.05, b = 0.05, a = 1 }, PANEL_BORDER)

	-- Guards against slider<->edit<->onChange feedback recursion.
	local syncing = false

	local function fmt(v)
		if step >= 1 then
			return string.format("%d", math.floor(v + 0.5))
		end
		return string.format("%.2f", v)
	end

	local function fire(v)
		if root._onChange then root._onChange(v) end
	end

	slider:SetScript("OnValueChanged", function(self, value)
		if syncing then return end
		syncing = true
		edit:SetText(fmt(value))
		syncing = false
		fire(value)
	end)

	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusLost", function(self)
		local v = tonumber(self:GetText())
		if v then
			if v < minV then v = minV end
			if v > maxV then v = maxV end
			if syncing then return end
			syncing = true
			slider:SetValue(v)
			edit:SetText(fmt(v))
			syncing = false
			fire(v)
		else
			edit:SetText(fmt(slider:GetValue()))
		end
	end)

	local initialV = cfg.value
	if type(initialV) ~= "number" then initialV = minV end
	-- Seeding clamps a stored value outside min/max, so hold the guard or that clamp is written back.
	syncing = true
	slider:SetValue(initialV)
	syncing = false
	edit:SetText(fmt(initialV))

	root._onChange = cfg.onChange
	root._slider   = slider
	root._edit     = edit

	function root:GetValue() return slider:GetValue() end
	function root:SetValue(v)
		if type(v) ~= "number" then return end
		if syncing then return end
		syncing = true
		slider:SetValue(v)
		edit:SetText(fmt(v))
		syncing = false
	end

	return root
end


-- Draws a row in the very font it names. A font file that fails to load leaves the FontString with
-- NO font and it renders nothing at all, and SetFont's return value is only documented for EditBox,
-- so success is read back with GetFont. The restore is an explicit SetFont rather than
-- SetFontObject, which does not undo an earlier SetFont.
local function applyPreviewFont(fs, path)
	local file, size, flags = GameFontNormal:GetFont()
	size = size or 12
	-- Probed first: a font registered by a since-uninstalled addon throws here, and this runs
	-- over every font the client has registered, so it is where a dead path surfaces.
	if path and path ~= "" and ns.FontPathLoads(path) then
		fs:SetFont(path, size, flags)
		if fs:GetFont() then return end
	end
	if file then
		fs:SetFont(file, size, flags)
	else
		fs:SetFontObject(GameFontNormal)
	end
end


function Widgets.CreateDropdown(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 180
	local options = cfg.options or {}

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 44)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)
	attachLabelTooltip(root, label, cfg)

	local btn = CreateFrame("Button", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetPoint("TOP", label, "BOTTOM", 0, -2)
	btn:SetSize(width, 22)
	applyBackdrop(btn, RED, PANEL_BORDER)
	root.box = btn   -- the visible box (below the label) - anchor a sibling here to line it up with the dropdown

	local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
	btnText:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	local chev = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	chev:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
	chev:SetText("v")
	chev:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	local list = CreateFrame("Frame", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
	list:SetWidth(width)
	list:SetFrameStrata("DIALOG")
	applyBackdrop(list, RED, PANEL_BORDER)
	list:Hide()

	local content = CreateFrame("Frame", nil, list)
	content:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	content:SetWidth(width)

	root._currentValue = cfg.value
	root._optionRows   = {}
	root._onChange     = cfg.onChange

	local function findOptionLabel(value)
		for _, opt in ipairs(options) do
			if opt.value == value then return opt.text end
		end
		return tostring(value or "")
	end

	local function findOptionFont(value)
		for _, opt in ipairs(options) do
			if opt.value == value then return opt.font end
		end
	end

	-- Only a font list carries a path per option. Decided once for the whole dropdown rather than per
	-- call, so a font whose file will not resolve falls back to the default instead of leaving the
	-- previously previewed face on the box.
	local hasFontPreview = false
	for _, opt in ipairs(options) do
		if opt.font then
			hasFontPreview = true
			break
		end
	end

	local swatchKind
	for _, opt in ipairs(options) do
		if opt.texture then swatchKind = "texture" break end
		if opt.edge then swatchKind = "edge" break end
	end
	local SWATCH_W, SWATCH_H = 58, 12
	-- A border swatch is its own size: four EDGE_INSET corners have to leave a visible straight run
	-- between them or every edgeFile draws as the same corner blob.
	local EDGE_W, EDGE_H, EDGE_INSET = 28, SWATCH_H + 6, 6
	local swatchRoom = swatchKind and (((swatchKind == "edge") and EDGE_W or SWATCH_W) + 10) or 0

	local function setButtonText(value)
		btnText:SetText(findOptionLabel(value))
		if hasFontPreview then applyPreviewFont(btnText, findOptionFont(value)) end
	end

	setButtonText(root._currentValue)

	local function selectValue(value)
		root._currentValue = value
		setButtonText(value)
		list:Hide()
		if root._onChange then root._onChange(value) end
	end

	local rowH = 20
	local MAX_LIST_W = 320
	local MAX_LIST_H = 280

	-- One Button plus a NineSlice backdrop per option pushed the lane option forms past Classic's
	-- script watchdog - LibSharedMedia reports about 500 statusbar textures once a pack is installed.
	local visibleN = math.min(#options, math.floor(MAX_LIST_H / rowH))
	if visibleN < 1 then visibleN = 1 end
	local maxTop = math.max(1, #options - visibleN + 1)
	local topIndex = 1

	list:SetHeight(rowH * visibleN)
	content:SetHeight(rowH * visibleN)

	local function Repaint()
		for i = 1, #root._optionRows do
			local row = root._optionRows[i]
			local opt = options[topIndex + i - 1]
			if opt then
				row._value = opt.value
				-- OnLeave can be skipped when the list hides under the cursor, and a pooled row is a
				-- position rather than an option, so a stuck highlight would land on the wrong entry.
				row:SetBackdropColor(RED_DIM.r, RED_DIM.g, RED_DIM.b, RED_DIM.a)
				row.text:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
				row.text:SetText(opt.text)
				if hasFontPreview then applyPreviewFont(row.text, opt.font) end
				if swatchKind == "texture" then
					row.swatch:SetTexture(opt.texture or "")
					row.swatch:SetShown(opt.texture ~= nil)
				elseif swatchKind == "edge" then
					-- Memoized: SetBackdrop rebuilds a NineSlice, and this repaints on every scroll tick.
					if row._edgePath ~= opt.edge then
						row._edgePath = opt.edge
						if opt.edge then
							row.swatch:SetBackdrop({ edgeFile = opt.edge, edgeSize = EDGE_INSET })
							row.swatch:SetBackdropBorderColor(1, 1, 1, 1)
						else
							row.swatch:SetBackdrop(nil)
						end
					end
					row.swatch:SetShown(opt.edge ~= nil)
				end
				row:Show()
			else
				row:Hide()
			end
		end
	end

	local built = false
	local function EnsureRows()
		if built then return end
		built = true
		for i = 1, visibleN do
			local row = CreateFrame("Button", nil, content,
				BackdropTemplateMixin and "BackdropTemplate" or nil)
			row:SetSize(width, rowH)
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowH))
			applyBackdrop(row, RED_DIM, PANEL_BORDER)

			local rt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			rt:SetPoint("LEFT", row, "LEFT", 6, 0)
			-- Giving the string a width is what makes justification apply, and GameFontNormal is
			-- centered, so the explicit LEFT is load-bearing here.
			rt:SetPoint("RIGHT", row, "RIGHT", -6 - swatchRoom, 0)
			rt:SetJustifyH("LEFT")
			rt:SetWordWrap(false)
			rt:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
			row.text = rt

			if swatchKind == "texture" then
				local sw = row:CreateTexture(nil, "ARTWORK")
				sw:SetSize(SWATCH_W, SWATCH_H)
				sw:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				row.swatch = sw
			elseif swatchKind == "edge" then
				local sw = CreateFrame("Frame", nil, row,
					BackdropTemplateMixin and "BackdropTemplate" or nil)
				sw:SetSize(EDGE_W, EDGE_H)
				sw:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				row.swatch = sw
			end

			row:SetScript("OnEnter", function(self)
				self:SetBackdropColor(YELLOW.r, YELLOW.g, YELLOW.b, 1)
				rt:SetTextColor(RED.r, RED.g, RED.b)
			end)
			row:SetScript("OnLeave", function(self)
				self:SetBackdropColor(RED_DIM.r, RED_DIM.g, RED_DIM.b, RED_DIM.a)
				rt:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
			end)
			row:SetScript("OnClick", function(self) selectValue(self._value) end)

			root._optionRows[i] = row
		end
	end

	-- A label can be wider than the caller's box ("Lane 3 (off)" in an 84px column), so the open list
	-- is measured on a scratch string, not on the pool, whose faces belong to whatever rows are painted.
	local sized = false
	local function EnsureWidth()
		if sized then return end
		sized = true
		local scratch = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		scratch:Hide()
		local listW = width
		for _, opt in ipairs(options) do
			if hasFontPreview then applyPreviewFont(scratch, opt.font) end
			scratch:SetText(opt.text)
			local textW = scratch:GetStringWidth() + 14 + swatchRoom
			if textW > listW then
				listW = math.min(MAX_LIST_W, textW)
				if listW >= MAX_LIST_W then break end
			end
		end
		if listW > width then
			list:SetWidth(listW)
			content:SetWidth(listW)
			for i = 1, #root._optionRows do
				root._optionRows[i]:SetWidth(listW)
			end
		end
	end

	if #options > visibleN then
		list:EnableMouseWheel(true)
		list:SetScript("OnMouseWheel", function(_, delta)
			local nt = topIndex - delta * 3
			if nt < 1 then nt = 1 elseif nt > maxTop then nt = maxTop end
			if nt ~= topIndex then
				topIndex = nt
				Repaint()
			end
		end)
	end

	btn:SetScript("OnClick", function()
		if list:IsShown() then
			list:Hide()
			return
		end
		EnsureRows()
		EnsureWidth()
		topIndex = 1
		Repaint()
		list:Show()
	end)

	function root:SetEnabled(enabled)
		if enabled then
			btn:Enable()
			btn:SetAlpha(1)
		else
			btn:Disable()
			btn:SetAlpha(0.5)
			list:Hide()
		end
	end

	function root:GetValue() return root._currentValue end
	function root:SetValue(v)
		root._currentValue = v
		setButtonText(v)
	end

	return root
end


-- The picker's `opacity` field and GetColorAlpha are TRANSPARENCY (1 - alpha) on the Classic
-- flavors and on the legacy OpacitySliderFrame, but TRUE alpha on retail. No API reports which
-- convention a client uses, so gate on the flavor the way Ace3 does (WOW_PROJECT_MAINLINE).
local INVERTED_ALPHA = not ns.Compat.IS_RETAIL


function Widgets.CreateColorPicker(parent, cfg)
	cfg = cfg or {}
	local hasAlpha = cfg.hasAlpha ~= false
	local color = cfg.color or { r = 1, g = 1, b = 1, a = 1 }

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(180, 24)

	local swatch = CreateFrame("Button", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	swatch:SetPoint("LEFT", root, "LEFT", 0, 0)
	swatch:SetSize(20, 20)
	applyBackdrop(swatch, color, PANEL_BORDER)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)

	root._color    = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
	root._onChange = cfg.onChange

	local function applySwatchColor(c)
		swatch:SetBackdropColor(c.r, c.g, c.b, c.a or 1)
	end

	local function fire()
		local c = root._color
		if root._onChange then root._onChange(c.r, c.g, c.b, c.a) end
	end

	local function buildPickerInfo()
		local startR, startG, startB, startA =
			root._color.r, root._color.g, root._color.b, root._color.a or 1
		-- Both callbacks re-read the whole color because the modern frame does not reliably fire
		-- opacityFunc on an opacity-only drag.
		local function readColor()
			local r, g, b
			if ColorPickerFrame.GetColorRGB then
				r, g, b = ColorPickerFrame:GetColorRGB()
			else
				r, g, b = _G.ColorPickerFrame:GetColorRGB()
			end
			if r then root._color.r, root._color.g, root._color.b = r, g, b end
			if hasAlpha then
				local t
				if ColorPickerFrame.GetColorAlpha then
					t = ColorPickerFrame:GetColorAlpha()
				elseif _G.OpacitySliderFrame and _G.OpacitySliderFrame.GetValue then
					t = _G.OpacitySliderFrame:GetValue()
				end
				if t ~= nil then
					root._color.a = INVERTED_ALPHA and (1 - t) or t
				end
			end
			applySwatchColor(root._color)
			fire()
		end
		local info = {
			r = startR, g = startG, b = startB,
			opacity = INVERTED_ALPHA and (1 - startA) or startA,
			hasOpacity = hasAlpha,
			swatchFunc = readColor,
			opacityFunc = readColor,
			-- Restore the captured start values rather than the frame's own previousValues: the
			-- modern picker puts alpha in `.a` and the legacy one used `.opacity`, so reading either
			-- field silently misses on the other client and Cancel would keep the dragged alpha.
			cancelFunc = function()
				root._color.r, root._color.g, root._color.b = startR, startG, startB
				if hasAlpha then root._color.a = startA end
				applySwatchColor(root._color)
				fire()
			end,
		}
		return info
	end

	swatch:SetScript("OnClick", function()
		local info = buildPickerInfo()
		-- Prefer modern SetupColorPickerAndShow (12.0+); fall back to legacy OpenColorPicker.
		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			local ok = pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
			if ok then return end
		end
		if _G.OpenColorPicker then
			pcall(_G.OpenColorPicker, info)
		end
	end)

	function root:GetValue()
		local c = root._color
		return c.r, c.g, c.b, c.a
	end
	function root:SetValue(r, g, b, a)
		root._color.r = r or root._color.r
		root._color.g = g or root._color.g
		root._color.b = b or root._color.b
		root._color.a = a or root._color.a
		applySwatchColor(root._color)
	end

	return root
end


function Widgets.CreateEditBox(parent, cfg)
	cfg = cfg or {}
	local width = cfg.width or 200

	local root = CreateFrame("Frame", nil, parent)
	root:SetSize(width, 40)

	local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", root, "TOP", 0, 0)
	label:SetText(cfg.label or "")
	label:SetTextColor(1, 1, 1)
	attachLabelTooltip(root, label, cfg)

	local edit = CreateFrame("EditBox", nil, root,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	edit:SetPoint("TOP", label, "BOTTOM", 0, -2)
	edit:SetSize(width, 20)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlight")
	edit:SetTextInsets(4, 4, 1, 1)
	edit:SetMaxLetters(cfg.maxLetters or 64)
	if cfg.numeric then edit:SetNumeric(true) end
	applyBackdrop(edit, { r = 0.05, g = 0.05, b = 0.05, a = 1 }, PANEL_BORDER)

	if cfg.value then edit:SetText(cfg.value) end

	root._onChange = cfg.onChange

	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusGained", function()
		edit:SetBackdropBorderColor(YELLOW.r, YELLOW.g, YELLOW.b, 1)
	end)
	edit:SetScript("OnEditFocusLost", function(self)
		edit:SetBackdropBorderColor(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, PANEL_BORDER.a)
		if root._onChange then root._onChange(self:GetText()) end
	end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and not cfg.commitOnly and root._onChange then
			root._onChange(self:GetText())
		end
	end)

	function root:GetValue() return edit:GetText() end
	function root:SetValue(t) edit:SetText(t or "") end

	return root
end


function Widgets.CreateButton(parent, cfg)
	cfg = cfg or {}
	local root = CreateFrame("Button", nil, parent,
		BackdropTemplateMixin and "BackdropTemplate" or nil)
	root:SetSize(cfg.width or 100, cfg.height or 22)
	applyBackdrop(root, RED, PANEL_BORDER)

	local text = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER")
	text:SetText(cfg.label or "")
	text:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)

	root:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			self:SetBackdropColor(YELLOW.r, YELLOW.g, YELLOW.b, 1)
			text:SetTextColor(RED.r, RED.g, RED.b)
		end
		if cfg.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(cfg.label or "")
			GameTooltip:AddLine(cfg.tooltip, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	root:SetScript("OnLeave", function(self)
		self:SetBackdropColor(RED.r, RED.g, RED.b, 1)
		text:SetTextColor(YELLOW.r, YELLOW.g, YELLOW.b)
		GameTooltip:Hide()
	end)
	root:SetScript("OnClick", function(self)
		if cfg.onClick then cfg.onClick(self) end
	end)

	function root:SetEnabled(enabled)
		if enabled then
			self:Enable()
			self:SetAlpha(1)
		else
			self:Disable()
			self:SetAlpha(0.5)
		end
	end
	function root:SetLabel(t) text:SetText(t or "") end

	return root
end
