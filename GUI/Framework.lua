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
-- Slider
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
    track:SetHeight(4)
    track:SetPoint("TOPLEFT", 0, -16)
    track:SetPoint("TOPRIGHT", 0, -16)
    track:SetBackdrop(BACKDROP_PANEL)
    track:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    track:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local fillBar = track:CreateTexture(nil, "ARTWORK")
    fillBar:SetPoint("TOPLEFT", 1, -1)
    fillBar:SetHeight(2)
    fillBar:SetColorTexture(NS.unpack(T.ACCENT_DIM))

    local thumb = NS.CreateFrame("Frame", nil, track, "BackdropTemplate")
    thumb:SetSize(10, 12)
    thumb:SetBackdrop(BACKDROP_PANEL)
    thumb:SetBackdropColor(NS.unpack(T.ACCENT))
    thumb:SetBackdropBorderColor(NS.unpack(T.BORDER))

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
        local trackWidth = track:GetWidth() - 10
        if trackWidth > 0 then
            thumb:ClearAllPoints()
            thumb:SetPoint("CENTER", track, "LEFT", 5 + pct * trackWidth, 0)
            fillBar:SetWidth(math.max(1, pct * (track:GetWidth() - 2)))
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
-- Cycle button (click to cycle through options)
----------------------------------------------------------------
function NS.CreateCycleButton(parent, label, dbKey, options, yOffset, onChange)
    local row = NS.CreateFrame("Button", nil, parent)
    row:SetSize(parent:GetWidth() - 28, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset)

    local lbl = row:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    lbl:SetText(label)

    local valBtn = NS.CreateFrame("Button", nil, row, "BackdropTemplate")
    valBtn:SetSize(70, 18)
    valBtn:SetPoint("RIGHT", 0, 0)
    valBtn:SetBackdrop(BACKDROP_PANEL)
    valBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    valBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local valText = valBtn:CreateFontString(nil, "OVERLAY")
    valText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    valText:SetPoint("CENTER")
    valText:SetTextColor(NS.unpack(T.ACCENT))

    local function Refresh()
        valText:SetText(NS.db[dbKey])
    end

    valBtn:SetScript("OnClick", function()
        local current = NS.db[dbKey]
        for i, opt in NS.ipairs(options) do
            if opt == current then
                NS.db[dbKey] = options[(i % #options) + 1]
                Refresh()
                if onChange then onChange(NS.db[dbKey]) end
                return
            end
        end
        NS.db[dbKey] = options[1]
        Refresh()
    end)

    valBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM))
    end)
    valBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(NS.unpack(T.BORDER))
    end)

    Refresh()
    row.Refresh = Refresh
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
