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
    header:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
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
-- Toggle (square checkbox)
----------------------------------------------------------------
function NS.CreateToggle(parent, label, dbKey, yOffset, onChange)
    local size = 14
    local row = NS.CreateFrame("Button", nil, parent)
    row:SetSize(parent:GetWidth() - 28, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local box = NS.CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(size, size)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(BACKDROP_PANEL)

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT))
    lbl:SetText(label)

    local function Refresh()
        local on = NS.db[dbKey]
        if on then
            box:SetBackdropColor(NS.unpack(T.TOGGLE_ON))
            box:SetBackdropBorderColor(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 0.6)
            fill:SetColorTexture(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 0.9)
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
        lbl:SetTextColor(NS.unpack(T.ACCENT_BRIGHT))
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
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth() - 28, 32)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    local valText = row:CreateFontString(nil, "OVERLAY")
    valText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
    fillBar:SetColorTexture(T.ACCENT[1], T.ACCENT[2], T.ACCENT[3], 0.8)

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
    local W = width or (parent:GetWidth() - 28)
    local ROW_H = 20

    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(NS.unpack(T.ACCENT))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText("v")

    -- Dropdown panel
    local dropdown = NS.CreateFrame("Frame", nil, btn, "BackdropTemplate")
    dropdown:SetWidth(W)
    dropdown:SetHeight(#options * ROW_H + 4)
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
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
        entry.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
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
        for i, entry in NS.ipairs(entries) do
            if options[i] == NS.db[dbKey] then
                entry.text:SetTextColor(NS.unpack(T.ACCENT))
            else
                entry.text:SetTextColor(NS.unpack(T.TEXT))
            end
        end
    end

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            Refresh()
            dropdown:Show()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    parent:HookScript("OnHide", function() dropdown:Hide() end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
    return row
end

----------------------------------------------------------------
-- Color swatch (opens WoW ColorPickerFrame)
----------------------------------------------------------------
function NS.CreateColorSwatch(parent, label, dbKey, yOffset, onChange)
    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth() - 28, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
        self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM))
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
    local W = width or (parent:GetWidth() - 28)

    local row = NS.CreateFrame("Frame", nil, parent)
    row:SetSize(W, 38)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
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
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(NS.unpack(T.TEXT_DIM))
    arrow:SetText("v")

    -- Dropdown panel (floating)
    local dropdown = NS.CreateFrame("Frame", nil, btn, "BackdropTemplate")
    dropdown:SetWidth(W)
    dropdown:SetHeight(VISIBLE * ROW_H + 32)
    dropdown:SetBackdrop(BACKDROP_PANEL)
    dropdown:SetBackdropColor(NS.unpack(T.BG_DARK))
    dropdown:SetBackdropBorderColor(NS.unpack(T.BORDER))
    dropdown:SetFrameStrata("TOOLTIP")
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
    search:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    search:SetTextColor(NS.unpack(T.TEXT))
    search:SetTextInsets(6, 6, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(50)

    local placeholder = search:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
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
                if fontName == NS.db[dbKey] then
                    entry.text:SetTextColor(NS.unpack(T.ACCENT))
                else
                    entry.text:SetTextColor(NS.unpack(T.TEXT))
                end
                entry:Show()
            else
                entry:Hide()
            end
        end
    end

    Refresh = function()
        local fontName = NS.db[dbKey]
        local fontPath = NS.GetFontPath(fontName)
        if not btnText:SetFont(fontPath, 11, "") then
            btnText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        end
        btnText:SetText(fontName)
        btnText:SetTextColor(NS.unpack(T.TEXT))
    end

    search:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
        scrollOffset = 0
        PopulateEntries()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dropdown:Hide()
    end)

    dropdown:SetScript("OnMouseWheel", function(_, delta)
        scrollOffset = scrollOffset - delta
        scrollOffset = math.max(0, math.min(scrollOffset, math.max(0, #filteredList - VISIBLE)))
        PopulateEntries()
    end)

    btn:SetScript("OnClick", function()
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            search:SetText("")
            -- Auto-scroll to center the currently selected font
            local currentFont = NS.db[dbKey]
            local fontList = NS.GetFontList()
            scrollOffset = 0
            for i, name in NS.ipairs(fontList) do
                if name == currentFont then
                    scrollOffset = math.max(0, i - math.ceil(VISIBLE / 2))
                    break
                end
            end
            PopulateEntries()
            dropdown:Show()
            search:SetFocus()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    parent:HookScript("OnHide", function() dropdown:Hide() end)

    Refresh()
    row.Refresh = Refresh
    row.btn = btn
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
            GameTooltip:SetText(tooltipTitle, T.ACCENT[1], T.ACCENT[2], T.ACCENT[3])
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
-- Close button
----------------------------------------------------------------
function NS.CreateCloseButton(parent)
    local btn = NS.CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)

    local txt = btn:CreateFontString(nil, "OVERLAY")
    txt:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetTextColor(NS.unpack(T.TEXT_DIM))
    txt:SetText("x")

    btn:SetScript("OnEnter", function() txt:SetTextColor(NS.unpack(T.DANGER)) end)
    btn:SetScript("OnLeave", function() txt:SetTextColor(NS.unpack(T.TEXT_DIM)) end)
    btn:SetScript("OnClick", function() parent:Hide() end)

    return btn
end
