local ADDON_NAME, NS = ...

local T = NS.THEME
NS.Config = {}

local function ApplyAll()
    NS.ApplyButtonSettings()
    NS.LayoutQueue()
    NS.UpdateNow()
end

local function ApplyFont()
    NS.ApplyButtonSettings()
    if NS.queueFrame and NS.queueFrame.label then
        NS.queueFrame.label:SetFont(NS.GetFontPath(), NS.db.queueLabelFontSize, NS.GetFontOutline())
    end
end

----------------------------------------------------------------
-- Create the config panel
----------------------------------------------------------------
function NS.Config:Create()
    local panelW = 300
    local maxH = NS.db.configPanelHeight or 600
    local titleH = 28

    local f = NS.CreatePanel("BetterSBA_ConfigPanel", NS.UIParent, panelW, maxH)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:EnableMouse(true)
    f:Hide()

    -- Title bar
    local titleBar = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(titleH)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(NS.unpack(T.BG_HEADER))
    titleBar:SetBackdropBorderColor(NS.unpack(T.BORDER))

    -- "Better" in obsidian blue-gray with standard font outline
    local titleBetter = titleBar:CreateFontString(nil, "OVERLAY")
    titleBetter:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    titleBetter:SetPoint("LEFT", 10, 0)
    titleBetter:SetTextColor(0.42, 0.49, 0.56, 1)  -- obsidian blue-gray

    -- "SBA" text: 3-layer effect — blue glow (outer) → black edge (middle) → white fill (top)
    -- Anchor FontString (also part of the blue glow layer)
    local titleSBAOutline = titleBar:CreateFontString(nil, "ARTWORK", nil, 1)
    titleSBAOutline:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    titleSBAOutline:SetPoint("LEFT", titleBetter, "RIGHT", 0, 0)
    titleSBAOutline:SetTextColor(0.10, 0.30, 1.00, 1)
    titleSBAOutline:SetText("SBA")

    -- Layer 1 (outer): blue glow — two rings for thick visible outline
    for _, off in NS.ipairs({
        -- Inner ring (~2px)
        {-2, 0}, {2, 0}, {0, -2}, {0, 2},
        {-1.4, -1.4}, {-1.4, 1.4}, {1.4, -1.4}, {1.4, 1.4},
        -- Outer ring (~3.5px)
        {-3.5, 0}, {3.5, 0}, {0, -3.5}, {0, 3.5},
        {-2.5, -2.5}, {-2.5, 2.5}, {2.5, -2.5}, {2.5, 2.5},
        {-3.5, -1.5}, {-3.5, 1.5}, {3.5, -1.5}, {3.5, 1.5},
        {-1.5, -3.5}, {-1.5, 3.5}, {1.5, -3.5}, {1.5, 3.5},
    }) do
        local o = titleBar:CreateFontString(nil, "ARTWORK", nil, 1)
        o:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        o:SetPoint("CENTER", titleSBAOutline, "CENTER", off[1], off[2])
        o:SetTextColor(0.10, 0.30, 1.00, 1)
        o:SetText("SBA")
    end

    -- Layer 2 (middle): black edge — 8 copies at ~1px offset
    for _, off in NS.ipairs({
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
        {-0.7, -0.7}, {-0.7, 0.7}, {0.7, -0.7}, {0.7, 0.7},
    }) do
        local o = titleBar:CreateFontString(nil, "ARTWORK", nil, 2)
        o:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        o:SetPoint("CENTER", titleSBAOutline, "CENTER", off[1], off[2])
        o:SetTextColor(0, 0, 0, 1)
        o:SetText("SBA")
    end

    -- Layer 3 (top): white fill
    local titleSBA = titleBar:CreateFontString(nil, "OVERLAY")
    titleSBA:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    titleSBA:SetPoint("CENTER", titleSBAOutline, "CENTER", 0, 0)
    titleSBA:SetTextColor(1, 1, 1, 1)

    titleBetter:SetText("Better")
    titleSBA:SetText("SBA")

    local ver = titleBar:CreateFontString(nil, "OVERLAY")
    ver:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    ver:SetPoint("LEFT", titleSBAOutline, "RIGHT", 6, 0)
    ver:SetTextColor(NS.unpack(T.TEXT_MUTED))
    ver:SetText(NS.VERSION)

    NS.CreateCloseButton(f)

    ----------------------------------------------------------------
    -- Status bar at the bottom (keybind intercept indicator)
    ----------------------------------------------------------------
    local statusH = 18
    local statusBar = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    statusBar:SetHeight(statusH)
    statusBar:SetPoint("BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", 0, 0)
    statusBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    statusBar:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.95)
    statusBar:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)
    statusBar:SetFrameLevel(f:GetFrameLevel() + 5)  -- above scroll content

    local statusIcon = statusBar:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(8, 8)
    statusIcon:SetPoint("LEFT", 8, 0)
    statusIcon:SetTexture("Interface\\Buttons\\WHITE8X8")

    local statusText = statusBar:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    statusText:SetPoint("LEFT", statusIcon, "RIGHT", 5, 0)
    statusText:SetPoint("RIGHT", -6, 0)
    statusText:SetJustifyH("LEFT")

    local function RefreshStatus()
        local keys = NS._overrideKeys
        local slot = NS._overrideSlot
        if keys and #keys > 0 then
            -- Active: show green dot + intercepted key(s)
            statusIcon:SetColorTexture(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 1)
            local keyStr = NS.table_concat(keys, ", ")
            statusText:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
            statusText:SetText("Intercepting [" .. keyStr .. "] (slot " .. slot .. ")")
        elseif slot then
            -- Slot found but no keybind
            statusIcon:SetColorTexture(T.DANGER[1], T.DANGER[2], T.DANGER[3], 0.8)
            statusText:SetTextColor(T.TEXT_DIM[1], T.TEXT_DIM[2], T.TEXT_DIM[3])
            statusText:SetText("SBA on slot " .. slot .. " — no keybind found")
        else
            -- SBA not on action bar
            statusIcon:SetColorTexture(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3], 0.6)
            statusText:SetTextColor(T.TEXT_MUTED[1], T.TEXT_MUTED[2], T.TEXT_MUTED[3])
            statusText:SetText("SBA not found on action bar")
        end
    end

    -- Wire up the live updater so OverrideSBAKeybind refreshes this
    NS.UpdateKeybindStatus = RefreshStatus

    -- Refresh on show
    f:HookScript("OnShow", RefreshStatus)

    ----------------------------------------------------------------
    -- Scroll frame
    ----------------------------------------------------------------
    local scrollBarW = 6
    local scrollFrame = NS.CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT", 0, -titleH)
    scrollFrame:SetPoint("BOTTOMRIGHT", -scrollBarW - 2, statusH)

    local scrollChild = NS.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(panelW - scrollBarW - 2)
    scrollFrame:SetScrollChild(scrollChild)

    -- Scrollbar track
    local scrollTrack = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollTrack:SetWidth(scrollBarW)
    scrollTrack:SetPoint("TOPRIGHT", 0, -titleH)
    scrollTrack:SetPoint("BOTTOMRIGHT", 0, statusH)
    scrollTrack:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    scrollTrack:SetBackdropColor(T.BG_DARK[1], T.BG_DARK[2], T.BG_DARK[3], 0.5)
    scrollTrack:Hide()

    -- Scrollbar thumb
    local scrollThumb = NS.CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(scrollBarW)
    scrollThumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    scrollThumb:SetBackdropColor(T.ACCENT_DIM[1], T.ACCENT_DIM[2], T.ACCENT_DIM[3], 0.8)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:EnableMouse(true)
    scrollThumb:SetMovable(true)

    -- Thumb dragging
    local thumbDragging = false
    local thumbDragStart = 0
    local thumbScrollStart = 0

    scrollThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            thumbDragging = true
            local _, cursorY = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            thumbDragStart = cursorY / scale
            thumbScrollStart = scrollFrame:GetVerticalScroll()
        end
    end)

    scrollThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            thumbDragging = false
        end
    end)

    scrollThumb:SetScript("OnUpdate", function(self)
        if not thumbDragging then return end
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        cursorY = cursorY / scale
        local delta = thumbDragStart - cursorY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local scrollRange = scrollChild:GetHeight() - scrollFrame:GetHeight()
        if scrollRange <= 0 or trackH <= thumbH then return end
        local scrollPerPixel = scrollRange / (trackH - thumbH)
        local newScroll = thumbScrollStart + delta * scrollPerPixel
        newScroll = math.max(0, math.min(scrollRange, newScroll))
        scrollFrame:SetVerticalScroll(newScroll)
    end)

    -- Update scrollbar position & visibility
    local function UpdateScrollbar()
        local contentH = scrollChild:GetHeight()
        local viewH = scrollFrame:GetHeight()
        if contentH <= viewH then
            scrollTrack:Hide()
            return
        end
        scrollTrack:Show()
        local trackH = scrollTrack:GetHeight()
        local ratio = viewH / contentH
        local thumbH = math.max(20, trackH * ratio)
        scrollThumb:SetHeight(thumbH)

        local scrollRange = contentH - viewH
        local scroll = scrollFrame:GetVerticalScroll()
        local pct = scroll / scrollRange
        local travel = trackH - thumbH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -pct * travel)
    end

    scrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateScrollbar()
    end)

    scrollFrame:SetScript("OnVerticalScroll", function()
        UpdateScrollbar()
    end)

    -- Mouse wheel on entire panel
    local function OnMouseWheel(_, delta)
        local scroll = scrollFrame:GetVerticalScroll()
        local step = 30
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scroll = math.max(0, math.min(maxScroll, scroll - delta * step))
        scrollFrame:SetVerticalScroll(scroll)
    end
    f:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    f:EnableMouseWheel(true)
    scrollFrame:EnableMouseWheel(true)

    ----------------------------------------------------------------
    -- Resize grip (bottom-right corner)
    ----------------------------------------------------------------
    f:SetResizable(true)
    f:SetResizeBounds(panelW, 250, panelW, 900)

    local grip = NS.CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    grip:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        NS.db.configPanelHeight = f:GetHeight()
        UpdateScrollbar()
    end)

    ----------------------------------------------------------------
    -- Content (all widgets parented to scrollChild)
    ----------------------------------------------------------------
    local c = scrollChild  -- alias for brevity
    local y = -12

    -- COMBAT
    NS.CreateSectionHeader(c, "COMBAT", y)
    y = y - 22
    NS.CreateToggle(c, "Auto-Target Enemies", "enableTargeting", y, function() NS.RebuildMacroText() end)
    y = y - 24
    NS.CreateToggle(c, "Pet Attack", "enablePetAttack", y, function() NS.RebuildMacroText() end)
    y = y - 24
    NS.CreateToggle(c, "Channel Protection", "enableChannelProtection", y, function() NS.RebuildMacroText() end)
    y = y - 30

    -- DISPLAY
    NS.CreateSectionHeader(c, "DISPLAY", y)
    y = y - 22
    NS.CreateSlider(c, "Button Size", "buttonSize", 24, 80, 1, y, function()
        NS.ApplyButtonSettings()
        NS.LayoutQueue()
    end)
    y = y - 38
    NS.CreateToggle(c, "Show Keybind", "showKeybind", y, function() NS.UpdateNow() end)
    y = y - 24
    NS.CreateToggle(c, "Show Cooldown", "showCooldown", y, function() NS.UpdateNow() end)
    y = y - 24
    NS.CreateToggle(c, "Range Coloring", "rangeColoring", y, function() NS.UpdateNow() end)
    y = y - 24
    local animDropW = panelW - 28 - 80 - 6 - scrollBarW
    local animRow = NS.CreateDropdown(c, "Cast Animation", "castAnimation", NS.CAST_ANIMATIONS, y, nil, animDropW)

    -- Animation Testing button
    local testBtn = NS.CreateFrame("Button", nil, c, "BackdropTemplate")
    testBtn:SetSize(80, 20)
    testBtn:SetPoint("TOPLEFT", animRow, "TOPRIGHT", 6, -16)
    testBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    testBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
    testBtn:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local testLbl = c:CreateFontString(nil, "OVERLAY")
    testLbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    testLbl:SetPoint("BOTTOMLEFT", testBtn, "TOPLEFT", 0, 2)
    testLbl:SetTextColor(NS.unpack(T.TEXT_DIM))
    testLbl:SetText("Preview")

    local testBtnText = testBtn:CreateFontString(nil, "OVERLAY")
    testBtnText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    testBtnText:SetPoint("CENTER")
    testBtnText:SetTextColor(NS.unpack(T.TEXT))
    testBtnText:SetText("Start")

    local testTicker = nil
    testBtn:SetScript("OnClick", function()
        if testTicker then
            testTicker:Cancel()
            testTicker = nil
            testBtnText:SetText("Start")
            testBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
        else
            NS.PlayCastAnimation(NS.SBA_SPELL_ID)
            testTicker = NS.C_Timer_NewTicker(1.2, function()
                NS.PlayCastAnimation(NS.SBA_SPELL_ID)
            end)
            testBtnText:SetText("Stop")
            testBtn:SetBackdropColor(T.TOGGLE_ON[1], T.TOGGLE_ON[2], T.TOGGLE_ON[3], 0.6)
        end
    end)
    testBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NS.unpack(T.ACCENT_DIM)) end)
    testBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NS.unpack(T.BORDER)) end)

    f:HookScript("OnHide", function()
        if testTicker then
            testTicker:Cancel()
            testTicker = nil
            testBtnText:SetText("Start")
            testBtn:SetBackdropColor(NS.unpack(T.TOGGLE_OFF))
        end
    end)
    y = y - 46

    NS.CreateDropdown(c, "Animation Style", "castAnimStyle", NS.CAST_ANIM_STYLES, y)
    y = y - 38

    -- APPEARANCE
    NS.CreateSectionHeader(c, "APPEARANCE", y)
    y = y - 22
    local fontW = 160
    local outlineW = panelW - 28 - fontW - 6 - scrollBarW
    local fontRow = NS.CreateFontDropdown(c, "Font", "fontFace", y, ApplyFont, fontW)
    local outlineRow = NS.CreateDropdown(c, "Outline", "fontOutline",
        NS.FONT_OUTLINE_OPTIONS, y, ApplyFont, outlineW)
    outlineRow:ClearAllPoints()
    outlineRow:SetPoint("TOPLEFT", fontRow, "TOPRIGHT", 6, 0)
    y = y - 46
    NS.CreateSlider(c, "Keybind Font Size", "keybindFontSize", 6, 24, 1, y, function()
        NS.ApplyButtonSettings()
    end)
    y = y - 38
    NS.CreateColorSwatch(c, "Button Background", "buttonBgColor", y, function(col)
        if NS.mainButton and not NS.masque then
            NS.mainButton:SetBackdropColor(NS.unpack(col))
        end
    end)
    y = y - 30
    NS.CreateToggle(c, "Importance Borders", "importanceBorders", y, function() NS.UpdateNow() end)
    y = y - 28

    NS.CreateColorSwatchWithTooltip(c, "Auto Attack", "importColorAutoAttack", y, function() NS.UpdateNow() end,
        "Auto Attack (White)",
        { "Basic auto-attack and melee swing abilities.",
          "These have no cooldown (0 seconds).",
          "Shown when no other ability is recommended." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Filler", "importColorFiller", y, function() NS.UpdateNow() end,
        "Filler (Green)",
        { "Low or no-cooldown rotational abilities.",
          "Cooldown: 10 seconds or less.",
          "Examples: Cobra Shot, Steady Shot, Shadow Bolt." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Short Cooldown", "importColorShortCD", y, function() NS.UpdateNow() end,
        "Short Cooldown (Blue)",
        { "Regular rotation abilities with moderate cooldowns.",
          "Cooldown: 10 to 30 seconds.",
          "Examples: Barbed Shot, Kill Command, Dire Beast." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Long Cooldown", "importColorLongCD", y, function() NS.UpdateNow() end,
        "Long Cooldown (Purple)",
        { "Significant cooldown abilities.",
          "Cooldown: 30 seconds to 2 minutes.",
          "Examples: Bestial Wrath, Aspect of the Wild." })
    y = y - 24
    NS.CreateColorSwatchWithTooltip(c, "Major Cooldown", "importColorMajorCD", y, function() NS.UpdateNow() end,
        "Major Cooldown (Orange)",
        { "Major offensive or defensive cooldowns.",
          "Cooldown: over 2 minutes.",
          "Examples: Bloodlust, major defensive abilities." })
    y = y - 28

    -- QUEUE DISPLAY
    NS.CreateSectionHeader(c, "QUEUE DISPLAY", y)
    y = y - 22
    NS.CreateToggle(c, "Show Ability Queue", "showQueue", y, function(on)
        if NS.queueFrame then
            if on then NS.queueFrame:Show() else NS.queueFrame:Hide() end
        end
    end)
    y = y - 28
    NS.CreateDropdown(c, "Position", "queuePosition",
        NS.QUEUE_POSITIONS, y, function()
            NS.LayoutQueue()
        end)
    y = y - 46
    NS.CreateSlider(c, "Queue X Offset", "queueOffsetX", -200, 200, 1, y, function()
        NS.LayoutQueue()
    end)
    y = y - 38
    NS.CreateSlider(c, "Queue Y Offset", "queueOffsetY", -200, 200, 1, y, function()
        NS.LayoutQueue()
    end)
    y = y - 38
    NS.CreateColorSwatch(c, "Queue Background", "queueBgColor", y, function(col)
        if NS.queueFrame then
            NS.queueFrame:SetBackdropColor(NS.unpack(col))
        end
    end)
    y = y - 28
    NS.CreateColorSwatch(c, "Queue Border", "queueBorderColor", y, function(col)
        if NS.queueFrame then
            NS.queueFrame:SetBackdropBorderColor(NS.unpack(col))
        end
    end)
    y = y - 28
    NS.CreateToggle(c, "Detach Queue", "queueDetached", y, function(on)
        if not on then
            NS.db.queueFreePosition = nil
            NS.LayoutQueue()
        end
        if NS.UpdateDetachOverlay then NS.UpdateDetachOverlay() end
    end)
    y = y - 28
    NS.CreateSlider(c, "Label Font Size", "queueLabelFontSize", 6, 18, 1, y, function()
        if NS.queueFrame and NS.queueFrame.label then
            NS.queueFrame.label:SetFont(NS.GetFontPath(), NS.db.queueLabelFontSize, NS.GetFontOutline())
        end
    end)
    y = y - 38
    NS.CreateSlider(c, "Label X Offset", "queueLabelOffsetX", -50, 50, 1, y, function()
        NS.LayoutQueue()
    end)
    y = y - 38
    NS.CreateSlider(c, "Label Y Offset", "queueLabelOffsetY", -50, 50, 1, y, function()
        NS.LayoutQueue()
    end)
    y = y - 38

    -- VISIBILITY
    NS.CreateSectionHeader(c, "VISIBILITY", y)
    y = y - 22
    NS.CreateToggle(c, "Combat Only", "onlyInCombat", y, function() NS.UpdateNow() end)
    y = y - 24
    NS.CreateSlider(c, "Button Out-of-Combat Alpha", "alphaOOC", 0, 1, 0.1, y, function()
        NS.UpdateNow()
    end)
    y = y - 38
    NS.CreateSlider(c, "Queue Out-of-Combat Alpha", "queueAlphaOOC", 0, 1, 0.1, y, function()
        NS.UpdateNow()
    end)
    y = y - 38
    NS.CreateToggle(c, "Hide In Vehicle", "hideInVehicle", y, function() NS.UpdateNow() end)
    y = y - 32

    -- ADVANCED
    local sep = c:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)
    sep:SetPoint("TOPLEFT", c, "TOPLEFT", 14, y)
    sep:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    y = y - 10

    NS.CreateToggle(c, "Lock Position", "locked", y)
    y = y - 24
    NS.CreateToggle(c, "Debug Mode", "debug", y, function(on)
        if on then NS.StartDebugDump() else NS.StopDebugDump() end
    end)
    y = y - 20

    -- Set scroll child height to total content
    scrollChild:SetHeight(math.abs(y))

    self.frame = f
    return f
end

----------------------------------------------------------------
-- Toggle config panel
----------------------------------------------------------------
function NS.Config:Toggle()
    if not self.frame then
        self:Create()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function NS.Config:Show()
    if not self.frame then self:Create() end
    self.frame:Show()
end

function NS.Config:Hide()
    if self.frame then self.frame:Hide() end
end
