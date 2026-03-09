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
    arrow:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    arrow:SetPoint("LEFT", 10, 0)
    arrow:SetTextColor(NS.unpack(T.ACCENT_DIM))
    arrow:SetText("\226\150\190")  -- ▾

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
            arrow:SetText("\226\150\190")  -- ▾
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
            arrow:SetText("\226\150\184")  -- ▸
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
    arrow:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText("v")

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
        else
            -- Auto-size popup to fit widest entry
            local popupW = W
            for _, entry in NS.ipairs(entries) do
                local tw = entry.text:GetStringWidth()
                if tw then popupW = math.max(popupW, tw + 20) end
            end
            dropdown:SetWidth(popupW)
            Refresh()
            dropdown:Show()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    parent:HookScript("OnHide", function() dropdown:Hide() end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
    row.lbl = lbl
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
    arrow:SetFont(NS.GetConfigFontPath(), 10, NS.GetConfigFontOutline())
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText("v")

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
                if not entry.text:SetFont(fontPath, 11, "") then
                    entry.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
        if not btnText:SetFont(fontPath, 11, "") then
            btnText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
        end
    end)
    btn:SetScript("OnEnter", function(self)
        local sc = parent._sectionColorDim or T.ACCENT_DIM
        self:SetBackdropBorderColor(NS.unpack(sc))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

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
-- Add tooltip to any row frame (hooks OnEnter/OnLeave)
----------------------------------------------------------------
function NS.AddTooltip(row, title, lines, parent)
    if not row or not title then return end
    row:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local sc = (parent and parent._sectionColor) or T.ACCENT
        GameTooltip:SetText(title, sc[1], sc[2], sc[3])
        if lines then
            for _, line in NS.ipairs(lines) do
                if line == " " then
                    GameTooltip:AddLine(" ")
                else
                    GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
                end
            end
        end
        GameTooltip:Show()
    end)
    row:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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
