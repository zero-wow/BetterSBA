local ADDON_NAME, NS = ...

local T = NS.THEME

local BACKDROP_PANEL = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

----------------------------------------------------------------
-- Panel
----------------------------------------------------------------
function NS.CreatePanel(name, parent, w, h)
    local f = NS.CreateFrame("Frame", name, parent or NS.UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetBackdrop(BACKDROP_PANEL)
    f:SetBackdropColor(NS.unpack(T.BG))
    f:SetBackdropBorderColor(NS.unpack(T.BORDER))
    f:SetFrameStrata("DIALOG")
    return f
end

----------------------------------------------------------------
-- Section header
----------------------------------------------------------------
function NS.CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY")
    header:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    header:SetTextColor(NS.unpack(T.ACCENT))
    header:SetText(text)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", parent, "RIGHT", -14, 0)

    return header, line
end

----------------------------------------------------------------
-- Collapsible Section Card (futuristic animated container)
----------------------------------------------------------------
function NS.CreateCollapsibleSection(parent, title, buildFunc, layoutFunc)
    local HEADER_H = 26
    local PADDING = 8

    -- Card container
    local card = NS.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetBackdrop(BACKDROP_PANEL)
    card:SetBackdropColor(NS.unpack(T.BG_CARD))
    card:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.5)

    -- Header bar (clickable)
    local header = NS.CreateFrame("Button", nil, card)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)

    -- Arrow indicator
    local arrow = header:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(NS.NERD_FONT, 10, NS.GetConfigFontOutline())
    arrow:SetPoint("LEFT", 10, 0)
    arrow:SetTextColor(NS.unpack(T.ACCENT_DIM))
    arrow:SetText(NS.GLYPH_TRI_DOWN)

    -- Title text
    local titleText = header:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    titleText:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    titleText:SetTextColor(NS.unpack(T.ACCENT))
    titleText:SetText(title)

    -- Animated underline (pulses when expanded)
    local underline = header:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 8, 1)
    underline:SetPoint("BOTTOMRIGHT", -8, 1)
    underline:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)

    -- Content frame (holds widgets)
    local content = NS.CreateFrame("Frame", nil, card)
    content:SetPoint("TOPLEFT", 0, -HEADER_H)
    content:SetPoint("RIGHT", 0, 0)

    -- State
    local expanded = true
    local contentH = 0

    -- Build content (widgets created inside buildFunc)
    contentH = buildFunc(content)

    content:SetHeight(contentH)

    local function UpdateCard()
        if expanded then
            card:SetHeight(HEADER_H + contentH)
            content:Show()
            arrow:SetText(NS.GLYPH_TRI_DOWN)
            underline:Show()
            titleText:SetTextColor(NS.unpack(T.ACCENT))
            card:SetBackdropBorderColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.4)
            for _, d in NS.ipairs(dots) do d:Show() end
            -- Fade in content
            content:SetAlpha(0)
            local fadeStart = GetTime()
            local fadeFrame = NS.CreateFrame("Frame")
            fadeFrame:SetScript("OnUpdate", function(self)
                local pct = (GetTime() - fadeStart) / 0.15
                if pct >= 1 then
                    content:SetAlpha(1)
                    self:SetScript("OnUpdate", nil)
                else
                    content:SetAlpha(pct)
                end
            end)
        else
            card:SetHeight(HEADER_H)
            content:Hide()
            arrow:SetText(NS.GLYPH_TRI_RIGHT)
            underline:Hide()
            titleText:SetTextColor(NS.unpack(T.TEXT_DIM))
            card:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.3)
            for _, d in NS.ipairs(dots) do d:Hide() end
        end
        if layoutFunc then layoutFunc() end
    end

    header:SetScript("OnClick", function()
        expanded = not expanded
        UpdateCard()
    end)
    header:SetScript("OnEnter", function()
        if expanded then
            titleText:SetTextColor(NS.unpack(T.ACCENT_BRIGHT))
        else
            titleText:SetTextColor(NS.unpack(T.ACCENT))
        end
    end)
    header:SetScript("OnLeave", function()
        if expanded then
            titleText:SetTextColor(NS.unpack(T.ACCENT))
        else
            titleText:SetTextColor(NS.unpack(T.TEXT_DIM))
        end
    end)

    -- Initial state
    UpdateCard()

    -- Public API
    card.content = content
    card.IsExpanded = function() return expanded end
    card.SetExpanded = function(_, val)
        expanded = val
        UpdateCard()
    end
    card.GetContentHeight = function() return contentH end

    return card
end

----------------------------------------------------------------
-- Toggle (square checkbox)
----------------------------------------------------------------
function NS.CreateToggle(parent, label, dbKey, yOffset, onChange)
    local size = 14
    local pw = parent._contentWidth or parent:GetWidth()
    local row = NS.CreateFrame("Button", nil, parent)
    row:SetSize(pw - 28, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local box = NS.CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(size, size)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(BACKDROP_PANEL)

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT))
    lbl:SetText(label)

    local function Refresh()
        local on = NS.db[dbKey]
        if on then
            local sc = parent._sectionColor or T.TOGGLE_ON
            box:SetBackdropColor(sc[1], sc[2], sc[3], sc[4] or 1)
            box:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.6)
            fill:SetColorTexture(sc[1], sc[2], sc[3], 0.9)
            fill:Show()
        else
            box:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
            box:SetBackdropBorderColor(NS.unpack(T.BORDER))
            fill:Hide()
        end
    end

    row:SetScript("OnClick", function()
        NS.db[dbKey] = not NS.db[dbKey]
        Refresh()
        if onChange then onChange(NS.db[dbKey]) end
    end)

    row:SetScript("OnEnter", function()
        local sc = parent._sectionColorBright or T.ACCENT_BRIGHT
        lbl:SetTextColor(NS.unpack(sc))
    end)
    row:SetScript("OnLeave", function()
        lbl:SetTextColor(NS.unpack(T.TEXT))
    end)

    Refresh()
    row.Refresh = Refresh
    return row
end

----------------------------------------------------------------
-- Slider (flat fill bar, no thumb)
----------------------------------------------------------------
function NS.CreateSlider(parent, label, dbKey, min, max, step, yOffset, onChange)
    local pw = parent._contentWidth or parent:GetWidth()
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(pw - 28, 32)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    local valText = row:CreateFontString(nil, "OVERLAY")
    valText:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    valText:SetPoint("TOPRIGHT", 0, 0)
    valText:SetTextColor(NS.unpack(T.TEXT))

    local track = NS.CreateFrame("Frame", nil, row, "BackdropTemplate")
    track:SetHeight(6)
    track:SetPoint("TOPLEFT", 0, -16)
    track:SetPoint("TOPRIGHT", 0, -16)
    track:SetBackdrop(BACKDROP_PANEL)
    track:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    track:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local fillBar = track:CreateTexture(nil, "ARTWORK")
    fillBar:SetPoint("TOPLEFT", 1, -1)
    fillBar:SetPoint("BOTTOMLEFT", 1, 1)
    local sc = parent._sectionColor or T.ACCENT
    fillBar:SetColorTexture(sc[1], sc[2], sc[3], 0.8)

    local function SetValue(val)
        val = math.max(min, math.min(max, val))
        if step >= 1 then
            val = NS.math_floor(val / step + 0.5) * step
        else
            val = NS.math_floor(val / step + 0.5) * step
            val = tonumber(string.format("%.2f", val))
        end
        NS.db[dbKey] = val
        local pct = (val - min) / (max - min)
        local trackWidth = track:GetWidth() - 2
        if trackWidth > 0 then
            fillBar:SetWidth(math.max(1, pct * trackWidth))
        end
        if step >= 1 then
            valText:SetText(tostring(NS.math_floor(val)))
        else
            valText:SetText(string.format("%.1f", val))
        end
        if onChange then onChange(val) end
    end

    local dragging = false
    track:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            dragging = true
            local cx = select(1, GetCursorPosition()) / self:GetEffectiveScale()
            local left = self:GetLeft()
            local width = self:GetWidth()
            local pct = math.max(0, math.min(1, (cx - left) / width))
            SetValue(min + pct * (max - min))
        end
    end)
    track:SetScript("OnMouseUp", function() dragging = false end)
    track:SetScript("OnUpdate", function(self)
        if dragging then
            local cx = select(1, GetCursorPosition()) / self:GetEffectiveScale()
            local left = self:GetLeft()
            local width = self:GetWidth()
            if width and width > 0 then
                local pct = math.max(0, math.min(1, (cx - left) / width))
                SetValue(min + pct * (max - min))
            end
        end
    end)

    -- Delay initial position until frame is sized
    row:SetScript("OnShow", function() SetValue(NS.db[dbKey]) end)
    C_Timer.After(0, function() SetValue(NS.db[dbKey]) end)

    row.SetValue = SetValue
    row.Refresh = function() SetValue(NS.db[dbKey]) end
    return row
end

----------------------------------------------------------------
-- Dropdown (generic, for string option lists)
----------------------------------------------------------------
function NS.CreateDropdown(parent, label, dbKey, options, yOffset, onChange, width)
    local W = width or ((parent._contentWidth or parent:GetWidth()) - 28)
    local ROW_H = 20

    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    -- Button showing current value
    local btn = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    btn:SetSize(W, 20)
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetBackdrop(BACKDROP_PANEL)
    btn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(NS.unpack(parent._sectionColor or T.ACCENT))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(NS.NERD_FONT, 8, NS.GetConfigFontOutline())
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText(NS.GLYPH_CHEVRON_DOWN)

    -- Dropdown panel (parented to UIParent to avoid scroll frame clipping)
    local dropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    dropdown:SetWidth(W)
    dropdown:SetHeight(#options * ROW_H + 4)
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetFrameLevel(100)
    dropdown:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    dropdown:Hide()
    dropdown:EnableMouse(true)

    -- Create entries
    local entries = {}
    local Refresh -- forward declaration

    for i, opt in NS.ipairs(options) do
        local entry = NS.CreateFrame("Button", nil, dropdown)
        entry:SetHeight(ROW_H)
        entry:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H - 2)
        entry:SetPoint("RIGHT", dropdown, "RIGHT", -2, 0)

        local hl = entry:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

        entry.text = entry:CreateFontString(nil, "OVERLAY")
        entry.text:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
        entry.text:SetPoint("LEFT", 8, 0)
        entry.text:SetJustifyH("LEFT")
        entry.text:SetText(opt)

        entry:SetScript("OnClick", function()
            NS.db[dbKey] = opt
            Refresh()
            dropdown:Hide()
            if onChange then onChange(opt) end
        end)

        entries[i] = entry
    end

    Refresh = function()
        btnText:SetText(NS.db[dbKey])
        local sc = parent._sectionColor or T.ACCENT
        for i, entry in NS.ipairs(entries) do
            if options[i] == NS.db[dbKey] then
                entry.text:SetTextColor(NS.unpack(sc))
            else
                entry.text:SetTextColor(NS.unpack(T.TEXT))
            end
        end
    end

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
            arrow:SetText(NS.GLYPH_CHEVRON_DOWN)
        else
            local popupW = W
            for _, entry in NS.ipairs(entries) do
                local tw = entry.text:GetStringWidth()
                if tw then popupW = math.max(popupW, tw + 20) end
            end
            dropdown:SetWidth(popupW)
            Refresh()
            dropdown:Show()
            arrow:SetText(NS.GLYPH_CHEVRON_UP)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    dropdown:SetScript("OnHide", function() arrow:SetText(NS.GLYPH_CHEVRON_DOWN) end)
    parent:HookScript("OnHide", function() dropdown:Hide() end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
    row.lbl = lbl
    return row
end

----------------------------------------------------------------
-- TextBox + Dropdown combo (Ctrl+Click shows dropdown of presets)
----------------------------------------------------------------
function NS.CreateTextBoxDropdown(parent, label, dbKey, presets, yOffset, onChange, width)
    local W = width or ((parent._contentWidth or parent:GetWidth()) - 28)
    local ROW_H = 20

    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    local hint = row:CreateFontString(nil, "OVERLAY")
    hint:SetFont(NS.GetConfigFontPath(), 8, NS.GetConfigFontOutline())
    hint:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    hint:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    hint:SetText("Ctrl+Click for presets")

    local editBox = NS.CreateFrame("EditBox", nil, row, "BackdropTemplate")
    editBox:SetSize(W, 20)
    editBox:SetPoint("TOPLEFT", 0, -16)
    editBox:SetBackdrop(BACKDROP_PANEL)
    editBox:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    editBox:SetBackdropBorderColor(NS.unpack(T.BORDER))
    editBox:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    editBox:SetTextColor(NS.unpack(parent._sectionColor or T.ACCENT))
    editBox:SetTextInsets(6, 6, 0, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(200)
    editBox:SetText(NS.db[dbKey] or "")

    editBox:SetScript("OnEnterPressed", function(self)
        local val = self:GetText()
        if val and val ~= "" then
            NS.db[dbKey] = val
            if onChange then onChange(val) end
        end
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(NS.db[dbKey] or "")
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetText(NS.db[dbKey] or "")
    end)

    local dropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    dropdown:SetWidth(W)
    dropdown:SetHeight(#presets * ROW_H + 4)
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetFrameLevel(100)
    dropdown:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
    dropdown:Hide()
    dropdown:EnableMouse(true)

    for i, opt in NS.ipairs(presets) do
        local entry = NS.CreateFrame("Button", nil, dropdown)
        entry:SetHeight(ROW_H)
        entry:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H - 2)
        entry:SetPoint("RIGHT", dropdown, "RIGHT", -2, 0)

        local hl = entry:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

        entry.text = entry:CreateFontString(nil, "OVERLAY")
        entry.text:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
        entry.text:SetPoint("LEFT", 8, 0)
        entry.text:SetJustifyH("LEFT")

        local displayText = opt
        local sc = parent._sectionColor or T.ACCENT
        if NS.type(opt) == "table" then
            displayText = opt.label or opt[1]
            entry._value = opt.value or opt[1]
        else
            entry._value = opt
        end
        entry.text:SetText(displayText)

        entry:SetScript("OnClick", function()
            NS.db[dbKey] = entry._value
            editBox:SetText(entry._value)
            dropdown:Hide()
            if onChange then onChange(entry._value) end
        end)
        entry:SetScript("OnEnter", function()
            entry.text:SetTextColor(sc[1], sc[2], sc[3])
        end)
        entry:SetScript("OnLeave", function()
            if entry._value == NS.db[dbKey] then
                entry.text:SetTextColor(sc[1], sc[2], sc[3])
            else
                entry.text:SetTextColor(NS.unpack(T.TEXT))
            end
        end)

        if entry._value == NS.db[dbKey] then
            entry.text:SetTextColor(sc[1], sc[2], sc[3])
        else
            entry.text:SetTextColor(NS.unpack(T.TEXT))
        end
    end

    editBox:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            if dropdown:IsShown() then
                dropdown:Hide()
            else
                dropdown:Show()
            end
        end
    end)

    editBox:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    editBox:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    parent:HookScript("OnHide", function() dropdown:Hide() end)

    row.editBox = editBox
    row.lbl = lbl
    row.Refresh = function()
        editBox:SetText(NS.db[dbKey] or "")
    end
    return row
end

----------------------------------------------------------------
-- Color swatch (opens WoW ColorPickerFrame)
----------------------------------------------------------------
function NS.CreateColorSwatch(parent, label, dbKey, yOffset, onChange)
    local pw = parent._contentWidth or parent:GetWidth()
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(pw - 28, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    local swatch = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(40, 16)
    swatch:SetPoint("RIGHT", 0, 0)
    swatch:SetBackdrop(BACKDROP_PANEL)
    swatch:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local colorTex = swatch:CreateTexture(nil, "ARTWORK")
    colorTex:SetPoint("TOPLEFT", 2, -2)
    colorTex:SetPoint("BOTTOMRIGHT", -2, 2)

    local function Refresh()
        local c = NS.db[dbKey]
        colorTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        swatch:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    end

    swatch:SetScript("OnClick", function()
        local c = NS.db[dbKey]
        local prevR, prevG, prevB, prevA = c[1], c[2], c[3], c[4] or 1

        local function ApplyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1
            NS.db[dbKey] = { r, g, b, a }
            Refresh()
            if onChange then onChange(NS.db[dbKey]) end
        end

        local info = {
            r = prevR, g = prevG, b = prevB, opacity = prevA,
            hasOpacity = true,
            swatchFunc = ApplyColor,
            opacityFunc = ApplyColor,
            cancelFunc = function()
                NS.db[dbKey] = { prevR, prevG, prevB, prevA }
                Refresh()
                if onChange then onChange(NS.db[dbKey]) end
            end,
        }

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            -- Fallback for older API
            ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = 1 - prevA
            ColorPickerFrame.func = ApplyColor
            ColorPickerFrame.opacityFunc = ApplyColor
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame.previousValues = { prevR, prevG, prevB }
            ColorPickerFrame:Show()
        end
    end)

    swatch:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    swatch:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    Refresh()
    row.Refresh = Refresh
    return row
end

----------------------------------------------------------------
-- Font dropdown (searchable, with per-entry font preview)
----------------------------------------------------------------
function NS.CreateFontDropdown(parent, label, dbKey, yOffset, onChange, width)
    local ROW_H = 22
    local VISIBLE = 8
    local W = width or ((parent._contentWidth or parent:GetWidth()) - 28)

    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    -- Button showing current font
    local btn = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    btn:SetSize(W, 20)
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetBackdrop(BACKDROP_PANEL)
    btn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(NS.NERD_FONT, 8, NS.GetConfigFontOutline())
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText(NS.GLYPH_CHEVRON_DOWN)

    -- Dropdown panel (parented to UIParent to avoid scroll frame clipping)
    local dropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    dropdown:SetWidth(W)
    dropdown:SetHeight(VISIBLE * ROW_H + 32)
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetFrameLevel(100)
    dropdown:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    dropdown:Hide()
    dropdown:EnableMouse(true)

    -- Search box
    local search = NS.CreateFrame("EditBox", nil, dropdown, "BackdropTemplate")
    search:SetSize(W - 8, 20)
    search:SetPoint("TOPLEFT", 4, -4)
    search:SetBackdrop(BACKDROP_PANEL)
    search:SetBackdropColor(NS.unpack(T.BG))
    search:SetBackdropBorderColor(NS.unpack(T.BORDER_ACCENT))
    search:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    search:SetTextColor(NS.unpack(T.TEXT))
    search:SetTextInsets(6, 6, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(50)

    local placeholder = search:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetTextColor(NS.unpack(T.TEXT_MUTED))
    placeholder:SetText("Search fonts...")

    -- Entry container
    local container = NS.CreateFrame("Frame", nil, dropdown)
    container:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -4, -4)
    container:SetPoint("RIGHT", dropdown, "RIGHT", 0, 0)
    container:SetHeight(VISIBLE * ROW_H)

    -- State
    local entries = {}
    local filteredList = {}
    local scrollOffset = 0
    local Refresh -- forward declaration

    -- Create visible entry slots
    for i = 1, VISIBLE do
        local entry = NS.CreateFrame("Button", nil, container)
        entry:SetHeight(ROW_H)
        entry:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        entry:SetPoint("RIGHT", container, "RIGHT", 0, 0)

        local hl = entry:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

        entry.text = entry:CreateFontString(nil, "OVERLAY")
        entry.text:SetPoint("LEFT", 8, 0)
        entry.text:SetPoint("RIGHT", -8, 0)
        entry.text:SetJustifyH("LEFT")

        entry:SetScript("OnClick", function(self)
            if self.fontName then
                NS.db[dbKey] = self.fontName
                Refresh()
                dropdown:Hide()
                if onChange then onChange(self.fontName) end
            end
        end)

        entries[i] = entry
    end

    local function PopulateEntries()
        local searchText = (search:GetText() or ""):lower()
        local fontList = NS.GetFontList()

        filteredList = {}
        for _, fontName in NS.ipairs(fontList) do
            if searchText == "" or fontName:lower():find(searchText, 1, true) then
                filteredList[#filteredList + 1] = fontName
            end
        end

        local maxOff = math.max(0, #filteredList - VISIBLE)
        if scrollOffset > maxOff then scrollOffset = maxOff end

        for i = 1, VISIBLE do
            local entry = entries[i]
            local fontName = filteredList[scrollOffset + i]
            if fontName then
                entry.fontName = fontName
                local fontPath = NS.GetFontPath(fontName)
                if not entry.text:SetFont(fontPath, 11, NS.GetConfigFontOutline()) then
                    entry.text:SetFont("Fonts\\FRIZQT__.TTF", 11, NS.GetConfigFontOutline())
                end
                entry.text:SetText(fontName)
                local fsc = parent._sectionColor or T.ACCENT
                if fontName == NS.db[dbKey] then
                    entry.text:SetTextColor(NS.unpack(fsc))
                else
                    entry.text:SetTextColor(NS.unpack(T.TEXT))
                end
                entry:Show()
            else
                entry:Hide()
            end
        end

        -- Auto-size popup to fit widest visible entry
        local popupW = W
        for i = 1, VISIBLE do
            local entry = entries[i]
            if entry:IsShown() and entry.text then
                local tw = entry.text:GetStringWidth()
                if tw then popupW = math.max(popupW, tw + 20) end
            end
        end
        dropdown:SetWidth(popupW)
        search:SetWidth(popupW - 8)
    end

    Refresh = function()
        local fontName = NS.db[dbKey]
        local fontPath = NS.GetFontPath(fontName)
        if not btnText:SetFont(fontPath, 11, NS.GetConfigFontOutline()) then
            btnText:SetFont("Fonts\\FRIZQT__.TTF", 11, NS.GetConfigFontOutline())
        end
        btnText:SetText(fontName)
        btnText:SetTextColor(NS.unpack(parent._sectionColor or T.ACCENT))
    end

    search:SetScript("OnTextChanged", function(self, userInput)
        placeholder:SetShown(self:GetText() == "")
        -- Only reset scroll when the USER typed something, not when
        -- SetWidth/SetText programmatic changes fire OnTextChanged
        if userInput then
            scrollOffset = 0
            PopulateEntries()
        end
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dropdown:Hide()
    end)

    local function OnDropdownScroll(_, delta)
        scrollOffset = scrollOffset - delta
        scrollOffset = math.max(0, math.min(scrollOffset, math.max(0, #filteredList - VISIBLE)))
        PopulateEntries()
    end
    -- Enable mouse wheel on all layers so events never leak through
    -- to the config panel scroll frame underneath
    dropdown:EnableMouseWheel(true)
    dropdown:SetScript("OnMouseWheel", OnDropdownScroll)
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", OnDropdownScroll)
    search:EnableMouseWheel(true)
    search:SetScript("OnMouseWheel", OnDropdownScroll)
    for i = 1, VISIBLE do
        entries[i]:EnableMouseWheel(true)
        entries[i]:SetScript("OnMouseWheel", OnDropdownScroll)
    end

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            search:SetText("")
            scrollOffset = 0
            PopulateEntries()
            dropdown:Show()
            search:SetFocus()
            arrow:SetText(NS.GLYPH_CHEVRON_UP)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    dropdown:SetScript("OnHide", function() arrow:SetText(NS.GLYPH_CHEVRON_DOWN) end)
    parent:HookScript("OnHide", function() dropdown:Hide() end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
    row.lbl = lbl
    return row
end

----------------------------------------------------------------
-- Color swatch with tooltip
----------------------------------------------------------------
function NS.CreateColorSwatchWithTooltip(parent, label, dbKey, yOffset, onChange, tooltipTitle, tooltipLines)
    local row = NS.CreateColorSwatch(parent, label, dbKey, yOffset, onChange)

    if tooltipTitle then
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local sc = parent._sectionColor or T.ACCENT
            GameTooltip:SetText(tooltipTitle, sc[1], sc[2], sc[3])
            if tooltipLines then
                for _, line in NS.ipairs(tooltipLines) do
                    GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return row
end

----------------------------------------------------------------
-- Tooltip importance color codes (for colored alt-text)
----------------------------------------------------------------
NS.TC = {
    KEY  = "|cFFFFD100",   -- gold — keybinds, hotkeys, action keys
    UI   = "|cFF66B8D9",   -- cyan — UI element names
    VAL  = "|cFF44FF44",   -- green — important values, positive states
    WARN = "|cFFFF8844",   -- orange — warnings, constraints, limits
    NUM  = "|cFFDDA0DD",   -- plum — numeric values, ranges
    R    = "|r",           -- reset
}

----------------------------------------------------------------
-- Custom tooltip (own font — supports all glyphs)
----------------------------------------------------------------
local customTip
local tipLines = {}
local TIP_PAD_X = 10
local TIP_PAD_Y = 8
local TIP_LINE_H = 13
local TIP_SPACE_H = 6
local TIP_MAX_W = 280

local function EnsureCustomTip()
    if customTip then return customTip end
    local f = NS.CreateFrame("Frame", "BetterSBA_Tooltip", NS.UIParent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_PANEL)
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    f:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.8)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:Hide()
    customTip = f
    return f
end

local function ShowCustomTip(owner, title, lines, sectionColor)
    local tip = EnsureCustomTip()
    local fontPath = NS.GetConfigFontPath()
    local fontOutline = NS.GetConfigFontOutline()
    local sc = sectionColor or T.ACCENT
    local lineIdx = 0

    local function GetLine()
        lineIdx = lineIdx + 1
        local fs = tipLines[lineIdx]
        if not fs then
            fs = tip:CreateFontString(nil, "OVERLAY")
            tipLines[lineIdx] = fs
        end
        fs:Show()
        return fs
    end

    local hdr = GetLine()
    hdr:SetFont(fontPath, 11, fontOutline)
    hdr:SetTextColor(sc[1], sc[2], sc[3])
    hdr:SetText(title)
    hdr:SetJustifyH("LEFT")
    hdr:SetWordWrap(false)
    hdr:SetPoint("TOPLEFT", tip, "TOPLEFT", TIP_PAD_X, -TIP_PAD_Y)
    hdr:SetWidth(TIP_MAX_W - TIP_PAD_X * 2)

    local maxW = hdr:GetStringWidth()
    local y = -TIP_PAD_Y - 14

    if lines then
        for _, text in NS.ipairs(lines) do
            if text == " " then
                y = y - TIP_SPACE_H
            else
                local fs = GetLine()
                fs:SetFont(fontPath, 10, fontOutline)
                fs:SetTextColor(0.85, 0.85, 0.85)
                fs:SetText(text)
                fs:SetJustifyH("LEFT")
                fs:SetWordWrap(true)
                fs:SetWidth(TIP_MAX_W - TIP_PAD_X * 2)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", tip, "TOPLEFT", TIP_PAD_X, y)
                local lw = fs:GetStringWidth()
                if lw > maxW then maxW = lw end
                local lh = fs:GetStringHeight()
                y = y - (lh > TIP_LINE_H and lh or TIP_LINE_H)
            end
        end
    end

    for i = lineIdx + 1, #tipLines do
        tipLines[i]:Hide()
    end

    local tipW = math.min(TIP_MAX_W, maxW + TIP_PAD_X * 2 + 4)
    if tipW < 120 then tipW = 120 end
    local tipH = math.abs(y) + TIP_PAD_Y
    tip:SetSize(tipW, tipH)

    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
    tip:Show()
end

local function HideCustomTip()
    if customTip then customTip:Hide() end
end

----------------------------------------------------------------
-- Add tooltip to any row frame (hooks OnEnter/OnLeave)
----------------------------------------------------------------
function NS.AddTooltip(row, title, lines, parent)
    if not row or not title then return end
    row:HookScript("OnEnter", function(self)
        local sc = (parent and parent._sectionColor) or T.ACCENT
        ShowCustomTip(self, title, lines, sc)
    end)
    row:HookScript("OnLeave", HideCustomTip)
end

----------------------------------------------------------------
-- Close button
----------------------------------------------------------------
function NS.CreateCloseButton(parent)
    local btn = NS.CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)

    local txt = btn:CreateFontString(nil, "OVERLAY")
    txt:SetFont(NS.GetConfigFontPath(), 14, NS.GetConfigFontOutline())
    txt:SetPoint("CENTER", 0, 0)
    txt:SetTextColor(NS.unpack(T.TEXT_DIM))
    txt:SetText("x")

    btn:SetScript("OnEnter", function() txt:SetTextColor(NS.unpack(T.DANGER)) end)
    btn:SetScript("OnLeave", function() txt:SetTextColor(NS.unpack(T.TEXT_DIM)) end)
    btn:SetScript("OnClick", function() parent:Hide() end)

    return btn
end

----------------------------------------------------------------
-- Generic Nested Folder Dropdown (reusable hierarchical dropdown)
----------------------------------------------------------------
function NS.CreateNestedDropdown(config)
    local parent = config.parent
    local W = config.width or ((parent._contentWidth or parent:GetWidth()) - 28)
    local ENTRY_H = 22
    local FOLDER_H = 20
    local MAX_H = 320
    local PREVIEW_W = config.previewWidth or 0
    local MAX_STRIP_COLORS = 8

    -- Forward declaration
    local Refresh

    -- Trigger button (same style as regular dropdown)
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, config.yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetFont(NS.GetConfigFontPath(), config.fontSize or 10, NS.GetConfigFontOutline())
    lbl:SetText(config.label)

    local btn = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    btn:SetSize(W, 20)
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetBackdrop(BACKDROP_PANEL)
    btn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    btn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(NS.GetConfigFontPath(), config.fontSize or 10, NS.GetConfigFontOutline())
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(NS.unpack(parent._sectionColor or T.ACCENT))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(NS.NERD_FONT, 8, NS.GetConfigFontOutline())
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText(NS.GLYPH_CHEVRON_DOWN)

    -- Popup panel
    local dropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    dropdown:SetWidth(math.max(W, 200))
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetFrameLevel(100)
    dropdown:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    dropdown:Hide()
    dropdown:EnableMouse(true)

    -- Scroll frame inside popup
    local scrollFrame = NS.CreateFrame("ScrollFrame", nil, dropdown)
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -2, 2)
    local scrollChild = NS.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(math.max(W, 200) - 4)
    scrollFrame:SetScrollChild(scrollChild)

    -- Flyout submenu system: main dropdown shows folders only,
    -- hovering a folder opens a submenu panel to the right
    local POPUP_W = math.max(W, 200)
    local hideGen = 0
    local function CancelHide() hideGen = hideGen + 1 end

    local subPanels = {}
    local subData = {}

    local function HideSubmenusFrom(d)
        for i = d, 4 do if subPanels[i] then subPanels[i]:Hide() end end
    end

    local function ScheduleHideAll()
        hideGen = hideGen + 1
        local g = hideGen
        NS.C_Timer_After(0.3, function()
            if hideGen ~= g then return end
            HideSubmenusFrom(1)
            dropdown:Hide()
        end)
    end

    dropdown:SetScript("OnEnter", CancelHide)
    dropdown:SetScript("OnLeave", ScheduleHideAll)

    local function EnsureSubmenu(depth)
        if subPanels[depth] then return end
        local p = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
        p:SetWidth(POPUP_W)
        p:SetBackdrop(BACKDROP_PANEL)
        p:SetBackdropColor(NS.unpack(T.BG_DARK))
        p:SetBackdropBorderColor(NS.unpack(T.BORDER))
        p:SetFrameStrata("TOOLTIP")
        p:SetFrameLevel(100 + depth * 2)
        p:EnableMouse(true)
        p:Hide()
        p:SetScript("OnEnter", CancelHide)
        p:SetScript("OnLeave", ScheduleHideAll)
        local sf = NS.CreateFrame("ScrollFrame", nil, p)
        sf:SetPoint("TOPLEFT", 2, -2)
        sf:SetPoint("BOTTOMRIGHT", -2, 2)
        local sc = NS.CreateFrame("Frame", nil, sf)
        sc:SetWidth(POPUP_W - 4)
        sf:SetScrollChild(sc)
        subPanels[depth] = p
        subData[depth] = { scroll = sf, child = sc, items = {}, folders = {} }
        parent:HookScript("OnHide", function() p:Hide() end)
    end

    local function GetSubItem(depth, idx)
        EnsureSubmenu(depth)
        local sd = subData[depth]
        if sd.items[idx] then return sd.items[idx] end
        local f = NS.CreateFrame("Button", nil, sd.child)
        f:SetHeight(ENTRY_H)
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.4)
        local selBg = f:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.08)
        selBg:Hide()
        f._selBg = selBg
        if PREVIEW_W > 0 then
            local strip = NS.CreateFrame("Frame", nil, f)
            strip:SetSize(PREVIEW_W, 12)
            f._strip = strip
            f._stripTextures = {}
            for j = 1, MAX_STRIP_COLORS do
                local tex = strip:CreateTexture(nil, "ARTWORK")
                tex:Hide()
                f._stripTextures[j] = tex
            end
            local iconTex = f:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(14, 14)
            iconTex:Hide()
            f._iconTex = iconTex
            local glyphFs = f:CreateFontString(nil, "OVERLAY")
            glyphFs:SetFont(NS.NERD_FONT, 12, "")
            glyphFs:Hide()
            f._glyphFs = glyphFs
        end
        local nameText = f:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(NS.unpack(T.TEXT))
        f._name = nameText
        local star = f:CreateFontString(nil, "OVERLAY")
        star:SetFont(NS.NERD_FONT, 9, "")
        star:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)
        star:Hide()
        f._star = star
        sd.items[idx] = f
        return f
    end

    local function GetSubFolder(depth, idx)
        EnsureSubmenu(depth)
        local sd = subData[depth]
        if sd.folders[idx] then return sd.folders[idx] end
        local f = NS.CreateFrame("Button", nil, sd.child)
        f:SetHeight(FOLDER_H)
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.3)
        local nameText = f:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(NS.NERD_FONT, 9, "OUTLINE")
        nameText:SetTextColor(NS.unpack(T.TEXT_DIM))
        f._name = nameText
        local arw = f:CreateFontString(nil, "OVERLAY")
        arw:SetFont(NS.NERD_FONT, 8, "OUTLINE")
        arw:SetPoint("RIGHT", -6, 0)
        arw:SetTextColor(NS.unpack(T.TEXT_MUTED))
        arw:SetText(NS.GLYPH_TRI_RIGHT)
        f._arrow = arw
        sd.folders[idx] = f
        return f
    end

    local function BuildTree(items)
        local root = { children = {}, items = {} }
        local favorites = { children = {}, items = {} }
        for _, item in NS.ipairs(items) do
            if item.isFavorite then
                favorites.items[#favorites.items + 1] = item
            end
            local path = item.path
            if path ~= "Favorites" then
                local node = root
                if path and path ~= "" then
                    for segment in path:gmatch("([^\\]+)") do
                        if not node.children[segment] then
                            node.children[segment] = { children = {}, items = {} }
                        end
                        node = node.children[segment]
                    end
                    node.items[#node.items + 1] = item
                elseif not path or path == "" then
                    local folderName = (item.isBuiltin) and "Other" or "Custom"
                    if not node.children[folderName] then
                        node.children[folderName] = { children = {}, items = {} }
                    end
                    node.children[folderName].items[#node.children[folderName].items + 1] = item
                end
            end
        end
        return root, favorites
    end

    local function SortedChildNames(node)
        local names = {}
        for name in NS.pairs(node.children) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            if a == "Custom" or a == "Other" then return false end
            if b == "Custom" or b == "Other" then return true end
            return a < b
        end)
        return names
    end

    local PopulateSubmenu
    PopulateSubmenu = function(depth, node, favItems, anchorFrame, anchorPanel)
        EnsureSubmenu(depth)
        local sd = subData[depth]
        local panel = subPanels[depth]
        HideSubmenusFrom(depth + 1)
        for _, f in NS.ipairs(sd.items) do f:Hide() end
        for _, f in NS.ipairs(sd.folders) do f:Hide() end

        local currentVal = NS.db[config.dbKey]
        local yOff = 0
        local iIdx, fIdx = 0, 0

        local itemList = favItems or (node and node.items) or {}
        for _, item in NS.ipairs(itemList) do
            iIdx = iIdx + 1
            local f = GetSubItem(depth, iIdx)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 0, -yOff)
            f:SetWidth(POPUP_W - 4)
            local leftOff = 4
            local isSelected = (item.name == currentVal)
            local pType = item.entryType or "strip"
            if f._strip then f._strip:Hide() end
            if f._iconTex then f._iconTex:Hide() end
            if f._glyphFs then f._glyphFs:Hide() end
            if f._inputBox then f._inputBox:Hide() end
            if pType == "strip" and f._strip and config.renderPreview then
                f._strip:ClearAllPoints()
                f._strip:SetPoint("LEFT", leftOff, 0)
                config.renderPreview(f._strip, f._stripTextures, item)
                f._strip:Show()
                leftOff = leftOff + PREVIEW_W + 6
            elseif pType == "icon" and f._iconTex and item.icon then
                f._iconTex:ClearAllPoints()
                f._iconTex:SetPoint("LEFT", leftOff, 0)
                f._iconTex:SetTexture(item.icon)
                f._iconTex:Show()
                leftOff = leftOff + 18
            elseif pType == "glyph" and f._glyphFs and item.glyph then
                f._glyphFs:ClearAllPoints()
                f._glyphFs:SetPoint("LEFT", leftOff, 0)
                f._glyphFs:SetTextColor(item.glyphColor and item.glyphColor[1] or T.TEXT_DIM[1], item.glyphColor and item.glyphColor[2] or T.TEXT_DIM[2], item.glyphColor and item.glyphColor[3] or T.TEXT_DIM[3])
                f._glyphFs:SetText(item.glyph)
                f._glyphFs:Show()
                leftOff = leftOff + f._glyphFs:GetStringWidth() + 6
            elseif pType == "input" and item.inputKey then
                if not f._inputBox then
                    local ib = NS.CreateFrame("EditBox", nil, f, "BackdropTemplate")
                    ib:SetSize(50, 16)
                    ib:SetBackdrop(BACKDROP_PANEL)
                    ib:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
                    ib:SetBackdropBorderColor(NS.unpack(T.BORDER))
                    ib:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
                    ib:SetTextColor(NS.unpack(T.TEXT))
                    ib:SetJustifyH("CENTER")
                    ib:SetAutoFocus(false)
                    ib:SetScript("OnEnter", function() CancelHide() end)
                    ib:SetScript("OnEditFocusGained", function() CancelHide() end)
                    f._inputBox = ib
                end
                f._inputBox:ClearAllPoints()
                f._inputBox:SetPoint("RIGHT", -4, 0)
                f._inputBox:SetText(NS.db[item.inputKey] or item.inputDefault or "")
                f._inputBox:Show()
                local inputItem = item
                f._inputBox:SetScript("OnEnterPressed", function(self)
                    local val = tonumber(self:GetText())
                    if val then
                        NS.db[inputItem.inputKey] = val
                        NS.db[config.dbKey] = inputItem.name
                        Refresh()
                        if config.onChange then config.onChange(inputItem.name) end
                    end
                    self:ClearFocus()
                    HideSubmenusFrom(1)
                    dropdown:Hide()
                end)
                f._inputBox:SetScript("OnEscapePressed", function(self)
                    self:ClearFocus()
                    ScheduleHideAll()
                end)
            end
            local fs = item.fontSize or config.fontSize or 10
            f._name:SetFont(NS.GetConfigFontPath(), fs, NS.GetConfigFontOutline())
            f._name:ClearAllPoints()
            f._name:SetPoint("LEFT", leftOff, 0)
            if pType == "input" and f._inputBox then
                f._name:SetPoint("RIGHT", f._inputBox, "LEFT", -4, 0)
            else
                f._name:SetPoint("RIGHT", -4, 0)
            end
            f._name:SetText(item.name)
            if isSelected then
                f._name:SetTextColor(NS.unpack(T.ACCENT))
                f._selBg:Show()
            else
                f._name:SetTextColor(NS.unpack(T.TEXT))
                f._selBg:Hide()
            end
            if item.isFavorite and not favItems then
                f._star:ClearAllPoints()
                f._star:SetPoint("RIGHT", -4, 0)
                f._star:SetText(NS.GLYPH_STAR_FILLED)
                f._star:Show()
            else
                f._star:Hide()
            end
            local itemData = item
            local isSel = isSelected
            f:SetScript("OnEnter", function()
                CancelHide()
                HideSubmenusFrom(depth + 1)
                if not isSel then f._name:SetTextColor(NS.unpack(T.ACCENT_BRIGHT)) end
            end)
            f:SetScript("OnLeave", function()
                ScheduleHideAll()
                if not isSel then f._name:SetTextColor(NS.unpack(T.TEXT)) end
            end)
            f:SetScript("OnClick", function()
                NS.db[config.dbKey] = itemData.name
                Refresh()
                HideSubmenusFrom(1)
                dropdown:Hide()
                if config.onChange then config.onChange(itemData.name) end
            end)
            f:Show()
            yOff = yOff + ENTRY_H
        end

        if node then
            local childNames = SortedChildNames(node)
            for _, childName in NS.ipairs(childNames) do
                fIdx = fIdx + 1
                local f = GetSubFolder(depth, fIdx)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", 0, -yOff)
                f:SetWidth(POPUP_W - 4)
                f._name:ClearAllPoints()
                f._name:SetPoint("LEFT", 6, 0)
                f._name:SetText(childName)
                local childNode = node.children[childName]
                f:SetScript("OnEnter", function()
                    CancelHide()
                    f._name:SetTextColor(NS.unpack(T.TEXT))
                    f._arrow:SetTextColor(NS.unpack(T.TEXT))
                    PopulateSubmenu(depth + 1, childNode, nil, f, panel)
                end)
                f:SetScript("OnLeave", function()
                    ScheduleHideAll()
                    f._name:SetTextColor(NS.unpack(T.TEXT_DIM))
                    f._arrow:SetTextColor(NS.unpack(T.TEXT_MUTED))
                end)
                f:Show()
                yOff = yOff + FOLDER_H
            end
        end

        sd.child:SetHeight(yOff + 4)
        local panelH = math.min(yOff + 6, MAX_H)
        panel:SetHeight(panelH)
        if yOff + 6 > MAX_H then
            sd.scroll:EnableMouseWheel(true)
            sd.scroll:SetScript("OnMouseWheel", function(self, delta)
                local cur = self:GetVerticalScroll()
                local maxS = yOff + 6 - MAX_H
                self:SetVerticalScroll(math.max(0, math.min(maxS, cur - delta * ENTRY_H * 3)))
            end)
        else
            sd.scroll:EnableMouseWheel(false)
            sd.scroll:SetVerticalScroll(0)
        end

        panel:ClearAllPoints()
        local rightEdge = anchorPanel:GetRight()
        local folderTop = anchorFrame:GetTop()
        if rightEdge and folderTop then
            panel:SetPoint("TOPLEFT", NS.UIParent, "BOTTOMLEFT", rightEdge + 2, folderTop)
        end
        panel:Show()
    end

    local mainFolders = {}
    local function GetMainFolder(idx)
        if mainFolders[idx] then return mainFolders[idx] end
        local f = NS.CreateFrame("Button", nil, scrollChild)
        f:SetHeight(FOLDER_H)
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.3)
        local nameText = f:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(NS.NERD_FONT, 9, "OUTLINE")
        nameText:SetTextColor(NS.unpack(T.TEXT_DIM))
        f._name = nameText
        local arw = f:CreateFontString(nil, "OVERLAY")
        arw:SetFont(NS.NERD_FONT, 8, "OUTLINE")
        arw:SetPoint("RIGHT", -6, 0)
        arw:SetTextColor(NS.unpack(T.TEXT_MUTED))
        arw:SetText(NS.GLYPH_TRI_RIGHT)
        f._arrow = arw
        mainFolders[idx] = f
        return f
    end

    local mainSpecials = {}
    local function GetMainSpecial(idx)
        if mainSpecials[idx] then return mainSpecials[idx] end
        local f = NS.CreateFrame("Button", nil, scrollChild)
        f:SetHeight(ENTRY_H)
        local hl = f:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.4)
        local selBg = f:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.08)
        selBg:Hide()
        f._selBg = selBg
        if PREVIEW_W > 0 then
            local strip = NS.CreateFrame("Frame", nil, f)
            strip:SetSize(PREVIEW_W, 12)
            f._strip = strip
            f._stripTextures = {}
            for j = 1, MAX_STRIP_COLORS do
                local tex = strip:CreateTexture(nil, "ARTWORK")
                tex:Hide()
                f._stripTextures[j] = tex
            end
            local iconTex = f:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(14, 14)
            iconTex:Hide()
            f._iconTex = iconTex
            local glyphFs = f:CreateFontString(nil, "OVERLAY")
            glyphFs:SetFont(NS.NERD_FONT, 12, "")
            glyphFs:Hide()
            f._glyphFs = glyphFs
        end
        local nameText = f:CreateFontString(nil, "OVERLAY")
        nameText:SetFont(NS.GetConfigFontPath(), 11, NS.GetConfigFontOutline())
        nameText:SetJustifyH("LEFT")
        nameText:SetTextColor(NS.unpack(T.TEXT))
        f._name = nameText
        local star = f:CreateFontString(nil, "OVERLAY")
        star:SetFont(NS.NERD_FONT, 9, "")
        star:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)
        star:Hide()
        f._star = star
        mainSpecials[idx] = f
        return f
    end

    local function RenderMainDropdown()
        for _, f in NS.ipairs(mainFolders) do f:Hide() end
        for _, f in NS.ipairs(mainSpecials) do f:Hide() end
        HideSubmenusFrom(1)
        local items = config.getItems()
        local tree, favs = BuildTree(items)

        local yOff = 0
        local currentVal = NS.db[config.dbKey]

        local flatItems = config.items or config.specialTop
        if flatItems then
            for si, item in NS.ipairs(flatItems) do
                local f = GetMainSpecial(si)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOff)
                f:SetWidth(POPUP_W - 4)
                local leftOff = 4
                local isSelected = (item.name == currentVal)
                local pType = item.entryType or "strip"
                if f._strip then f._strip:Hide() end
                if f._iconTex then f._iconTex:Hide() end
                if f._glyphFs then f._glyphFs:Hide() end
                if f._inputBox then f._inputBox:Hide() end
                if pType == "strip" and f._strip and config.renderPreview then
                    f._strip:ClearAllPoints()
                    f._strip:SetPoint("LEFT", leftOff, 0)
                    config.renderPreview(f._strip, f._stripTextures, item)
                    f._strip:Show()
                    leftOff = leftOff + PREVIEW_W + 6
                elseif pType == "icon" and f._iconTex and item.icon then
                    f._iconTex:ClearAllPoints()
                    f._iconTex:SetPoint("LEFT", leftOff, 0)
                    f._iconTex:SetTexture(item.icon)
                    f._iconTex:Show()
                    leftOff = leftOff + 18
                elseif pType == "glyph" and f._glyphFs and item.glyph then
                    f._glyphFs:ClearAllPoints()
                    f._glyphFs:SetPoint("LEFT", leftOff, 0)
                    f._glyphFs:SetTextColor(item.glyphColor and item.glyphColor[1] or T.TEXT_DIM[1], item.glyphColor and item.glyphColor[2] or T.TEXT_DIM[2], item.glyphColor and item.glyphColor[3] or T.TEXT_DIM[3])
                    f._glyphFs:SetText(item.glyph)
                    f._glyphFs:Show()
                    leftOff = leftOff + f._glyphFs:GetStringWidth() + 6
                elseif pType == "input" and item.inputKey then
                    if not f._inputBox then
                        local ib = NS.CreateFrame("EditBox", nil, f, "BackdropTemplate")
                        ib:SetSize(50, 16)
                        ib:SetBackdrop(BACKDROP_PANEL)
                        ib:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
                        ib:SetBackdropBorderColor(NS.unpack(T.BORDER))
                        ib:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
                        ib:SetTextColor(NS.unpack(T.TEXT))
                        ib:SetJustifyH("CENTER")
                        ib:SetAutoFocus(false)
                        ib:SetScript("OnEnter", function() CancelHide() end)
                        ib:SetScript("OnEditFocusGained", function() CancelHide() end)
                        f._inputBox = ib
                    end
                    f._inputBox:ClearAllPoints()
                    f._inputBox:SetPoint("RIGHT", -4, 0)
                    f._inputBox:SetText(NS.db[item.inputKey] or item.inputDefault or "")
                    f._inputBox:Show()
                    local inputItem = item
                    f._inputBox:SetScript("OnEnterPressed", function(self)
                        local val = tonumber(self:GetText())
                        if val then
                            NS.db[inputItem.inputKey] = val
                            NS.db[config.dbKey] = inputItem.name
                            Refresh()
                            if config.onChange then config.onChange(inputItem.name) end
                        end
                        self:ClearFocus()
                        HideSubmenusFrom(1)
                        dropdown:Hide()
                    end)
                    f._inputBox:SetScript("OnEscapePressed", function(self)
                        self:ClearFocus()
                        ScheduleHideAll()
                    end)
                end
                local fs = item.fontSize or config.fontSize or 10
                f._name:SetFont(NS.GetConfigFontPath(), fs, NS.GetConfigFontOutline())
                f._name:ClearAllPoints()
                f._name:SetPoint("LEFT", leftOff, 0)
                if pType == "input" and f._inputBox then
                    f._name:SetPoint("RIGHT", f._inputBox, "LEFT", -4, 0)
                else
                    f._name:SetPoint("RIGHT", -4, 0)
                end
                f._name:SetText(item.name)
                if isSelected then
                    f._name:SetTextColor(NS.unpack(T.ACCENT))
                    f._selBg:Show()
                else
                    f._name:SetTextColor(NS.unpack(T.TEXT))
                    f._selBg:Hide()
                end
                f._star:Hide()
                local itemData = item
                local isSel = isSelected
                f:SetScript("OnEnter", function()
                    CancelHide()
                    HideSubmenusFrom(1)
                    if not isSel then f._name:SetTextColor(NS.unpack(T.ACCENT_BRIGHT)) end
                end)
                f:SetScript("OnLeave", function()
                    ScheduleHideAll()
                    if not isSel then f._name:SetTextColor(NS.unpack(T.TEXT)) end
                end)
                f:SetScript("OnClick", function()
                    NS.db[config.dbKey] = itemData.name
                    Refresh()
                    if itemData.entryType == "input" then
                        CancelHide()
                        return
                    end
                    HideSubmenusFrom(1)
                    dropdown:Hide()
                    if config.onChange then config.onChange(itemData.name) end
                end)
                f:Show()
                yOff = yOff + ENTRY_H
            end
        end

        local entries = {}
        if #favs.items > 0 then
            entries[#entries + 1] = { name = NS.GLYPH_STAR_FILLED .. " Favorites", favItems = favs.items }
        end
        local sorted = SortedChildNames(tree)
        for _, name in NS.ipairs(sorted) do
            entries[#entries + 1] = { name = name, node = tree.children[name] }
        end
        for i, entry in NS.ipairs(entries) do
            local f = GetMainFolder(i)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 0, -yOff)
            f:SetWidth(POPUP_W - 4)
            f._name:ClearAllPoints()
            f._name:SetPoint("LEFT", 6, 0)
            f._name:SetText(entry.name)
            local eNode = entry.node
            local eFavItems = entry.favItems
            f:SetScript("OnEnter", function()
                CancelHide()
                f._name:SetTextColor(NS.unpack(T.TEXT))
                f._arrow:SetTextColor(NS.unpack(T.TEXT))
                PopulateSubmenu(1, eNode, eFavItems, f, dropdown)
            end)
            f:SetScript("OnLeave", function()
                ScheduleHideAll()
                f._name:SetTextColor(NS.unpack(T.TEXT_DIM))
                f._arrow:SetTextColor(NS.unpack(T.TEXT_MUTED))
            end)
            f:Show()
            yOff = yOff + FOLDER_H
        end
        scrollChild:SetHeight(yOff + 4)
        dropdown:SetHeight(math.min(yOff + 6, MAX_H))
        if yOff + 6 > MAX_H then
            scrollFrame:EnableMouseWheel(true)
            scrollFrame:SetScript("OnMouseWheel", function(self, delta)
                local cur = self:GetVerticalScroll()
                local maxS = yOff + 6 - MAX_H
                self:SetVerticalScroll(math.max(0, math.min(maxS, cur - delta * ENTRY_H * 3)))
            end)
        else
            scrollFrame:EnableMouseWheel(false)
            scrollFrame:SetVerticalScroll(0)
        end
    end

    Refresh = function()
        local val = NS.db[config.dbKey] or ""
        local flatItems = config.items or config.specialTop
        if flatItems then
            for _, item in NS.ipairs(flatItems) do
                if item.name == val and item.entryType == "input" and item.inputKey then
                    local inputVal = NS.db[item.inputKey]
                    if inputVal then
                        local display = val .. ": " .. inputVal
                        if #display > 20 then display = val .. ": " .. string.sub(NS.tostring(inputVal), 1, 6) end
                        val = display
                    end
                    break
                end
            end
        end
        btnText:SetText(val)
    end

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
            HideSubmenusFrom(1)
        else
            Refresh()
            RenderMainDropdown()
            dropdown:Show()
            arrow:SetText(NS.GLYPH_CHEVRON_UP)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(NS.unpack(parent._sectionColorDim or T.ACCENT_DIM))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    dropdown:HookScript("OnHide", function() arrow:SetText(NS.GLYPH_CHEVRON_DOWN) end)
    parent:HookScript("OnHide", function()
        dropdown:Hide()
        HideSubmenusFrom(1)
    end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
    row.lbl = lbl
    return row
end

----------------------------------------------------------------
-- Palette Dropdown (thin wrapper around CreateNestedDropdown)
----------------------------------------------------------------
function NS.CreatePaletteDropdown(parent, label, dbKey, yOffset, onChange, width)
    return NS.CreateNestedDropdown({
        parent = parent,
        label = label,
        dbKey = dbKey,
        yOffset = yOffset,
        onChange = onChange,
        width = width,
        previewWidth = 60,
        items = {
            { name = "Random", entryType = "none" },
        },
        getItems = function()
            local list = NS:GetPaletteList()
            local items = {}
            for _, name in NS.ipairs(list) do
                items[#items + 1] = {
                    name = name,
                    path = NS:GetPalettePath(name) or "",
                    isFavorite = NS:IsPaletteFavorite(name),
                    isBuiltin = NS:IsBuiltinPalette(name),
                    colors = NS:GetPalette(name),
                }
            end
            return items
        end,
        renderPreview = function(strip, textures, item)
            local colors = item.colors
            if not colors then return end
            if not strip._bg then
                local bg = strip:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.08, 0.08, 0.10, 1)
                strip._bg = bg
            end
            strip._bg:Show()
            local count = math.min(#colors, 8)
            local stripW = strip:GetWidth()
            local stripH = strip:GetHeight()
            local bdr = 1
            local innerW = stripW - bdr * 2
            for j = 1, 8 do
                local tex = textures[j]
                if j <= count then
                    local left = bdr + math.floor(((j - 1) * innerW) / count + 0.5)
                    local right = bdr + math.floor((j * innerW) / count + 0.5)
                    tex:ClearAllPoints()
                    tex:SetSize(math.max(1, right - left), stripH - bdr * 2)
                    tex:SetPoint("TOPLEFT", strip, "TOPLEFT", left, -bdr)
                    tex:SetColorTexture(colors[j][1], colors[j][2], colors[j][3], 1)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
        end,
    })
end

----------------------------------------------------------------
-- Options Dropdown (flat list via nested dropdown — supports entryType per entry)
----------------------------------------------------------------
function NS.CreateOptionsDropdown(parent, label, dbKey, options, yOffset, onChange, width)
    local entries = {}
    for _, name in NS.ipairs(options) do
        if NS.type(name) == "table" then
            entries[#entries + 1] = name
        else
            entries[#entries + 1] = {
                name = name,
                entryType = "none",
            }
        end
    end
    return NS.CreateNestedDropdown({
        parent = parent,
        label = label,
        dbKey = dbKey,
        yOffset = yOffset,
        onChange = onChange,
        width = width,
        previewWidth = 0,
        items = entries,
        getItems = function() return {} end,
    })
end

----------------------------------------------------------------
-- Timing Dropdown (thin wrapper — presets + Specific with input)
----------------------------------------------------------------
function NS.CreateTimingDropdown(parent, label, dbKey, inputKey, yOffset, onChange, width)
    local entries = {}
    for _, name in NS.ipairs(NS.PARTICLE_TIMINGS) do
        entries[#entries + 1] = {
            name = name,
            entryType = "none",
        }
    end
    entries[#entries + 1] = {
        name = "Specific",
        entryType = "input",
        inputKey = inputKey,
        inputDefault = "0.3",
    }
    return NS.CreateNestedDropdown({
        parent = parent,
        label = label,
        dbKey = dbKey,
        yOffset = yOffset,
        onChange = onChange,
        width = width,
        previewWidth = 0,
        items = entries,
        getItems = function() return {} end,
    })
end

----------------------------------------------------------------
-- Palette Editor (modal popup for creating/editing color palettes)
----------------------------------------------------------------
local paletteEditorFrame = nil
local MAX_PALETTE_COLORS = 12
local MIN_PALETTE_COLORS = 2

local function CreateTextButton(parent, text, onClick)
    local btn = NS.CreateFrame("Button", nil, parent)
    btn:SetSize(60, 16)
    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
    lbl:SetPoint("CENTER")
    lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
    lbl:SetText(text)
    btn:SetScript("OnEnter", function() lbl:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3]) end)
    btn:SetScript("OnLeave", function() lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3]) end)
    btn:SetScript("OnClick", function()
        lbl:SetTextColor(1, 1, 1)
        NS.C_Timer_After(0.15, function() lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3]) end)
        if onClick then onClick() end
    end)
    btn._lbl = lbl
    return btn
end

function NS.ShowPaletteEditor(configPanel, dbKey, onClose, createMode)
    if paletteEditorFrame then
        paletteEditorFrame:Hide()
    end

    local W, H = 320, 420
    local f = NS.CreatePanel("BetterSBA_PaletteEditor", NS.UIParent, W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:EnableMouse(true)
    f:SetBackdropBorderColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.6)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(NS.GetConfigFontPath(), 11, "OUTLINE")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetTextColor(NS.unpack(T.ACCENT))
    title:SetText(createMode and "Create Palette" or "Palette Editor")

    -- Favorite star toggle (forward-declared, wired up after currentPaletteName is defined)
    local favStar = NS.CreateFrame("Button", nil, f)
    favStar:SetSize(20, 20)
    favStar:SetPoint("LEFT", title, "RIGHT", 8, 0)
    local favStarText = favStar:CreateFontString(nil, "OVERLAY")
    favStarText:SetFont(NS.NERD_FONT, 14, "")
    favStarText:SetPoint("CENTER")

    NS.CreateCloseButton(f)

    -- Palette list dropdown
    local listLabel = f:CreateFontString(nil, "OVERLAY")
    listLabel:SetFont(NS.GetConfigFontPath(), 9, "")
    listLabel:SetPoint("TOPLEFT", 10, -32)
    listLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    listLabel:SetText("Select Palette")

    local listBtn = NS.CreateFrame("Button", nil, f, "BackdropTemplate")
    listBtn:SetSize(W - 20, 20)
    listBtn:SetPoint("TOPLEFT", 10, -44)
    listBtn:SetBackdrop(BACKDROP_PANEL)
    listBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    listBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local listText = listBtn:CreateFontString(nil, "OVERLAY")
    listText:SetFont(NS.GetConfigFontPath(), 10, "")
    listText:SetPoint("LEFT", 6, 0)
    listText:SetPoint("RIGHT", -20, 0)
    listText:SetJustifyH("LEFT")
    listText:SetTextColor(NS.unpack(T.ACCENT))

    -- State
    local currentPaletteName = createMode and "" or (NS.db[dbKey] or "Confetti")
    local editColors = {}  -- working copy of colors
    local isBuiltin = false
    local swatches = {}

    -- Wire up favorite star toggle
    local function RefreshFavStar()
        if currentPaletteName == "" then
            favStar:Hide()
            return
        end
        favStar:Show()
        if NS:IsPaletteFavorite(currentPaletteName) then
            favStarText:SetText(NS.GLYPH_STAR_FILLED)
            favStarText:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
        else
            favStarText:SetText(NS.GLYPH_STAR_EMPTY)
            favStarText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        end
    end
    favStar:SetScript("OnClick", function()
        if currentPaletteName == "" then return end
        NS:SetPaletteFavorite(currentPaletteName, not NS:IsPaletteFavorite(currentPaletteName))
        RefreshFavStar()
    end)
    favStar:SetScript("OnEnter", function()
        favStarText:SetTextColor(T.ACCENT_BRIGHT[1], T.ACCENT_BRIGHT[2], T.ACCENT_BRIGHT[3])
    end)
    favStar:SetScript("OnLeave", function() RefreshFavStar() end)
    RefreshFavStar()

    -- Name field
    local nameLabel = f:CreateFontString(nil, "OVERLAY")
    nameLabel:SetFont(NS.GetConfigFontPath(), 9, "")
    nameLabel:SetPoint("TOPLEFT", 10, -72)
    nameLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    nameLabel:SetText("Palette Name")

    local nameBox = NS.CreateFrame("EditBox", nil, f, "BackdropTemplate")
    nameBox:SetSize(W - 20, 20)
    nameBox:SetPoint("TOPLEFT", 10, -84)
    nameBox:SetBackdrop(BACKDROP_PANEL)
    nameBox:SetBackdropColor(NS.unpack(T.BG))
    nameBox:SetBackdropBorderColor(NS.unpack(T.BORDER))
    nameBox:SetFont(NS.GetConfigFontPath(), 10, "")
    nameBox:SetTextColor(NS.unpack(T.TEXT))
    nameBox:SetTextInsets(6, 6, 0, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(30)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Folder field
    local folderLabel = f:CreateFontString(nil, "OVERLAY")
    folderLabel:SetFont(NS.GetConfigFontPath(), 9, "")
    folderLabel:SetPoint("TOPLEFT", 10, -108)
    folderLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    folderLabel:SetText("Folder")

    local folderBox = NS.CreateFrame("EditBox", nil, f, "BackdropTemplate")
    folderBox:SetSize(W - 20, 20)
    folderBox:SetPoint("TOPLEFT", 10, -120)
    folderBox:SetBackdrop(BACKDROP_PANEL)
    folderBox:SetBackdropColor(NS.unpack(T.BG))
    folderBox:SetBackdropBorderColor(NS.unpack(T.BORDER))
    folderBox:SetFont(NS.GetConfigFontPath(), 10, "")
    folderBox:SetTextColor(NS.unpack(T.TEXT))
    folderBox:SetTextInsets(6, 6, 0, 0)
    folderBox:SetAutoFocus(false)
    folderBox:SetMaxLetters(50)
    folderBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Folder placeholder text
    local folderPlaceholder = folderBox:CreateFontString(nil, "OVERLAY")
    folderPlaceholder:SetFont(NS.GetConfigFontPath(), 10, "")
    folderPlaceholder:SetPoint("LEFT", 6, 0)
    folderPlaceholder:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.6)
    folderPlaceholder:SetText("e.g. Nature")
    folderBox:SetScript("OnTextChanged", function(self)
        folderPlaceholder:SetShown(self:GetText() == "")
    end)
    folderBox:SetScript("OnEditFocusGained", function() folderPlaceholder:Hide() end)
    folderBox:SetScript("OnEditFocusLost", function(self)
        folderPlaceholder:SetShown(self:GetText() == "")
    end)

    -- Color swatches area
    local swatchLabel = f:CreateFontString(nil, "OVERLAY")
    swatchLabel:SetFont(NS.GetConfigFontPath(), 9, "")
    swatchLabel:SetPoint("TOPLEFT", 10, -144)
    swatchLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    swatchLabel:SetText("Colors (click to edit)")

    local swatchFrame = NS.CreateFrame("Frame", nil, f)
    swatchFrame:SetSize(W - 20, 80)
    swatchFrame:SetPoint("TOPLEFT", 10, -156)

    -- Preview strip
    local previewLabel = f:CreateFontString(nil, "OVERLAY")
    previewLabel:SetFont(NS.GetConfigFontPath(), 9, "")
    previewLabel:SetPoint("TOPLEFT", 10, -242)
    previewLabel:SetTextColor(NS.unpack(T.TEXT_DIM))
    previewLabel:SetText("Preview")

    local previewStrip = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewStrip:SetSize(W - 20, 16)
    previewStrip:SetPoint("TOPLEFT", 10, -254)
    previewStrip:SetBackdrop(BACKDROP_PANEL)
    previewStrip:SetBackdropColor(0, 0, 0, 0.5)
    previewStrip:SetBackdropBorderColor(NS.unpack(T.BORDER))
    local previewTextures = {}

    local function RefreshPreview()
        -- Clear old textures
        for _, tex in NS.ipairs(previewTextures) do tex:Hide() end

        local count = #editColors
        if count == 0 then return end
        local stripW = previewStrip:GetWidth() - 2
        local segW = stripW / count

        for i, clr in NS.ipairs(editColors) do
            local tex = previewTextures[i]
            if not tex then
                tex = previewStrip:CreateTexture(nil, "ARTWORK")
                previewTextures[i] = tex
            end
            tex:SetSize(math.max(1, segW), 12)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", previewStrip, "TOPLEFT", 1 + (i-1) * segW, -2)
            tex:SetColorTexture(clr[1], clr[2], clr[3], 1)
            tex:Show()
        end
    end

    local function RefreshSwatches()
        -- Clear old swatches
        for _, sw in NS.ipairs(swatches) do sw:Hide() end

        local cols = 6
        local swSize = 32
        local gap = 4

        for i, clr in NS.ipairs(editColors) do
            local sw = swatches[i]
            if not sw then
                sw = NS.CreateFrame("Button", nil, swatchFrame, "BackdropTemplate")
                sw:SetSize(swSize, swSize)
                sw:SetBackdrop(BACKDROP_PANEL)
                sw.colorTex = sw:CreateTexture(nil, "ARTWORK")
                sw.colorTex:SetPoint("TOPLEFT", 2, -2)
                sw.colorTex:SetPoint("BOTTOMRIGHT", -2, 2)

                -- Remove button (x in corner)
                sw.removeBtn = NS.CreateFrame("Button", nil, sw)
                sw.removeBtn:SetSize(10, 10)
                sw.removeBtn:SetPoint("TOPRIGHT", 2, 2)
                local xText = sw.removeBtn:CreateFontString(nil, "OVERLAY")
                xText:SetFont(NS.GetConfigFontPath(), 8, "OUTLINE")
                xText:SetPoint("CENTER")
                xText:SetTextColor(T.DANGER[1], T.DANGER[2], T.DANGER[3])
                xText:SetText("x")
                sw.removeBtn:SetScript("OnEnter", function() xText:SetTextColor(1, 0.3, 0.3) end)
                sw.removeBtn:SetScript("OnLeave", function() xText:SetTextColor(T.DANGER[1], T.DANGER[2], T.DANGER[3]) end)

                swatches[i] = sw
            end

            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            sw:ClearAllPoints()
            sw:SetPoint("TOPLEFT", swatchFrame, "TOPLEFT", col * (swSize + gap), -row * (swSize + gap))
            sw:SetBackdropColor(clr[1], clr[2], clr[3], 1)
            sw:SetBackdropBorderColor(NS.unpack(T.BORDER))
            sw.colorTex:SetColorTexture(clr[1], clr[2], clr[3], 1)

            -- Click to open color picker
            sw:SetScript("OnClick", function()
                if isBuiltin then return end
                local prevR, prevG, prevB = clr[1], clr[2], clr[3]
                local function Apply()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    editColors[i] = { r, g, b }
                    RefreshSwatches()
                    RefreshPreview()
                end
                local info = {
                    r = prevR, g = prevG, b = prevB, opacity = 1,
                    hasOpacity = false,
                    swatchFunc = Apply,
                    cancelFunc = function()
                        editColors[i] = { prevR, prevG, prevB }
                        RefreshSwatches()
                        RefreshPreview()
                    end,
                }
                if ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow(info)
                else
                    ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
                    ColorPickerFrame.hasOpacity = false
                    ColorPickerFrame.func = Apply
                    ColorPickerFrame.cancelFunc = info.cancelFunc
                    ColorPickerFrame:Show()
                end
            end)

            -- Remove button
            sw.removeBtn:SetScript("OnClick", function()
                if isBuiltin or #editColors <= MIN_PALETTE_COLORS then return end
                table.remove(editColors, i)
                RefreshSwatches()
                RefreshPreview()
            end)
            sw.removeBtn:SetShown(not isBuiltin and #editColors > MIN_PALETTE_COLORS)
            sw:Show()
        end

        -- Add button (+)
        if not isBuiltin and #editColors < MAX_PALETTE_COLORS then
            local addIdx = #editColors + 1
            local sw = swatches[addIdx]
            if not sw then
                sw = NS.CreateFrame("Button", nil, swatchFrame, "BackdropTemplate")
                sw:SetSize(swSize, swSize)
                sw:SetBackdrop(BACKDROP_PANEL)
                sw.colorTex = sw:CreateTexture(nil, "ARTWORK")
                sw.colorTex:SetPoint("TOPLEFT", 2, -2)
                sw.colorTex:SetPoint("BOTTOMRIGHT", -2, 2)
                sw.removeBtn = NS.CreateFrame("Frame", nil, sw)
                sw.removeBtn:Hide()
                swatches[addIdx] = sw
            end
            local row = math.floor((addIdx-1) / cols)
            local col = (addIdx-1) % cols
            sw:ClearAllPoints()
            sw:SetPoint("TOPLEFT", swatchFrame, "TOPLEFT", col * (swSize + gap), -row * (swSize + gap))
            sw:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
            sw:SetBackdropBorderColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.5)
            sw.colorTex:SetColorTexture(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.3)
            sw:SetScript("OnClick", function()
                editColors[#editColors + 1] = { 1, 1, 1 }
                RefreshSwatches()
                RefreshPreview()
            end)
            local addText = sw:CreateFontString(nil, "OVERLAY")
            addText:SetFont(NS.GetConfigFontPath(), 14, "OUTLINE")
            addText:SetPoint("CENTER")
            addText:SetTextColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3])
            addText:SetText("+")
            sw:Show()
        end

        RefreshPreview()
    end

    local function LoadPalette(name)
        currentPaletteName = name
        isBuiltin = NS:IsBuiltinPalette(name)
        listText:SetText(name .. (isBuiltin and " (built-in)" or ""))
        nameBox:SetText(isBuiltin and "" or name)
        nameBox:SetEnabled(not isBuiltin)

        local path = NS:GetPalettePath(name) or ""
        folderBox:SetText(path)
        folderBox:SetEnabled(not isBuiltin)
        folderPlaceholder:SetShown(path == "" and not folderBox:HasFocus())

        local palette = NS:GetPalette(name)
        editColors = {}
        if palette then
            for _, clr in NS.ipairs(palette) do
                editColors[#editColors + 1] = { clr[1], clr[2], clr[3] }
            end
        end
        if #editColors < MIN_PALETTE_COLORS then
            for _ = #editColors + 1, MIN_PALETTE_COLORS do
                editColors[#editColors + 1] = { 1, 1, 1 }
            end
        end

        RefreshSwatches()
    end

    -- Palette list dropdown popup
    local listDropdown = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
    listDropdown:SetWidth(W - 20)
    listDropdown:SetBackdrop(BACKDROP_PANEL)
    listDropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    listDropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    listDropdown:SetFrameStrata("FULLSCREEN_DIALOG")
    listDropdown:SetFrameLevel(210)
    listDropdown:SetPoint("TOPLEFT", listBtn, "BOTTOMLEFT", 0, -2)
    listDropdown:Hide()
    listDropdown:EnableMouse(true)

    listBtn:SetScript("OnClick", function()
        if listDropdown:IsShown() then
            listDropdown:Hide()
            return
        end
        -- Rebuild entries
        local children = { listDropdown:GetChildren() }
        for _, child in NS.ipairs(children) do child:Hide() end

        local palettes = NS:GetPaletteList()
        local ROW_H = 20
        listDropdown:SetHeight(#palettes * ROW_H + 4)

        for i, name in NS.ipairs(palettes) do
            local entry = NS.CreateFrame("Button", nil, listDropdown)
            entry:SetHeight(ROW_H)
            entry:SetPoint("TOPLEFT", 2, -(i-1) * ROW_H - 2)
            entry:SetPoint("RIGHT", listDropdown, "RIGHT", -2, 0)

            local hl = entry:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(T.BG_HOVER[1], T.BG_HOVER[2], T.BG_HOVER[3], 0.5)

            local entryText = entry:CreateFontString(nil, "OVERLAY")
            entryText:SetFont(NS.GetConfigFontPath(), 10, "")
            entryText:SetPoint("LEFT", 8, 0)
            entryText:SetJustifyH("LEFT")
            local displayName = name
            if NS:IsBuiltinPalette(name) then displayName = name .. " *" end
            entryText:SetText(displayName)
            if name == currentPaletteName then
                entryText:SetTextColor(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
            else
                entryText:SetTextColor(NS.unpack(T.TEXT))
            end

            entry:SetScript("OnClick", function()
                LoadPalette(name)
                listDropdown:Hide()
            end)
        end
        listDropdown:Show()
    end)

    f:HookScript("OnHide", function() listDropdown:Hide() end)

    -- Bottom buttons
    local btnY = -250
    local btnSpacing = 70

    local saveBtn = CreateTextButton(f, "SAVE", function()
        if isBuiltin then return end
        local name = nameBox:GetText():trim()
        if name == "" then return end
        -- Deep copy colors
        local colors = {}
        for _, clr in NS.ipairs(editColors) do
            colors[#colors + 1] = { clr[1], clr[2], clr[3] }
        end
        -- If name changed from current, delete old (unless it was a different palette)
        if currentPaletteName ~= name and not NS:IsBuiltinPalette(currentPaletteName) then
            NS:DeletePalette(currentPaletteName)
        end
        NS:SavePalette(name, colors)
        local folder = folderBox:GetText():trim()
        if folder ~= "" then
            NS:SetPalettePath(name, folder)
        else
            NS:SetPalettePath(name, nil)
        end
        NS.db[dbKey] = name
        currentPaletteName = name
        f:Hide()
        if onClose then onClose() end
    end)
    saveBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)

    local copyBtn = CreateTextButton(f, "COPY", function()
        local baseName = currentPaletteName
        local copyName = baseName .. " (Copy)"
        local n = 1
        while NS:GetPalette(copyName) do
            n = n + 1
            copyName = baseName .. " (Copy " .. n .. ")"
        end
        local colors = {}
        for _, clr in NS.ipairs(editColors) do
            colors[#colors + 1] = { clr[1], clr[2], clr[3] }
        end
        NS:SavePalette(copyName, colors)
        LoadPalette(copyName)
    end)
    copyBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)

    local deleteBtn = CreateTextButton(f, "DELETE", function()
        if isBuiltin then return end
        NS:DeletePalette(currentPaletteName)
        LoadPalette("Confetti")
    end)
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)

    local cancelBtn = CreateTextButton(f, "CANCEL", function()
        f:Hide()
        if onClose then onClose() end
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)

    -- Disable save/delete for built-in
    local function UpdateButtonStates()
        if isBuiltin then
            saveBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.3)
            deleteBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.3)
        else
            saveBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            deleteBtn._lbl:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
        end
    end

    -- Override LoadPalette to also update button states
    local origLoad = LoadPalette
    LoadPalette = function(name)
        origLoad(name)
        UpdateButtonStates()
        RefreshFavStar()
    end

    -- Initial load
    if createMode then
        -- Start with blank state for creation
        currentPaletteName = ""
        isBuiltin = false
        listText:SetText("(new palette)")
        nameBox:SetText("")
        nameBox:SetEnabled(true)
        nameBox:SetFocus()
        folderBox:SetText("")
        folderBox:SetEnabled(true)
        folderPlaceholder:Show()
        editColors = { { 1, 1, 1 }, { 1, 1, 1 } }
        RefreshSwatches()
        UpdateButtonStates()
        RefreshFavStar()
    else
        LoadPalette(currentPaletteName)
    end
    f:Show()

    paletteEditorFrame = f
    f:HookScript("OnHide", function()
        listDropdown:Hide()
        if onClose then onClose() end
        paletteEditorFrame = nil
    end)
end
