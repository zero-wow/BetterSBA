local ADDON_NAME, NS = ...

local T = NS.THEME
NS.Config = {}

----------------------------------------------------------------
-- Create the config panel
----------------------------------------------------------------
function NS.Config:Create()
    local panelW, panelH = 300, 540
    local f = NS.CreatePanel("BetterSBA_ConfigPanel", NS.UIParent, panelW, panelH)
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
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(NS.unpack(T.BG_HEADER))
    titleBar:SetBackdropBorderColor(NS.unpack(T.BORDER))

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    title:SetPoint("LEFT", 10, 0)
    title:SetTextColor(NS.unpack(T.TEXT))
    title:SetText("|cFF66B8D9Better|r|cFFFFFFFFSBA|r")

    local ver = titleBar:CreateFontString(nil, "OVERLAY")
    ver:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    ver:SetPoint("LEFT", title, "RIGHT", 6, 0)
    ver:SetTextColor(NS.unpack(T.TEXT_MUTED))
    ver:SetText(NS.VERSION)

    NS.CreateCloseButton(f)

    -- Content area starts below title bar
    local y = -40

    -- COMBAT
    NS.CreateSectionHeader(f, "COMBAT", y)
    y = y - 22
    NS.CreateToggle(f, "Auto-Target Enemies", "enableTargeting", y, function() NS.RebuildMacroText() end)
    y = y - 24
    NS.CreateToggle(f, "Pet Attack", "enablePetAttack", y, function() NS.RebuildMacroText() end)
    y = y - 24
    NS.CreateToggle(f, "Channel Protection", "enableChannelProtection", y, function() NS.RebuildMacroText() end)
    y = y - 32

    -- DISPLAY
    NS.CreateSectionHeader(f, "DISPLAY", y)
    y = y - 22
    NS.CreateSlider(f, "Button Size", "buttonSize", 24, 80, 1, y, function()
        NS.ApplyButtonSettings()
        NS.LayoutQueue()
    end)
    y = y - 38
    NS.CreateToggle(f, "Show Keybind", "showKeybind", y)
    y = y - 24
    NS.CreateToggle(f, "Show Cooldown", "showCooldown", y)
    y = y - 24
    NS.CreateToggle(f, "Range Coloring", "rangeColoring", y)
    y = y - 32

    -- QUEUE DISPLAY
    NS.CreateSectionHeader(f, "QUEUE DISPLAY", y)
    y = y - 22
    NS.CreateToggle(f, "Show Ability Queue", "showQueue", y, function(on)
        if NS.queueFrame then
            if on then NS.queueFrame:Show() else NS.queueFrame:Hide() end
        end
    end)
    y = y - 24
    NS.CreateCycleButton(f, "Position", "queuePosition",
        { "RIGHT", "BOTTOM", "LEFT", "TOP" }, y, function()
            NS.LayoutQueue()
        end)
    y = y - 32

    -- VISIBILITY
    NS.CreateSectionHeader(f, "VISIBILITY", y)
    y = y - 22
    NS.CreateToggle(f, "Combat Only", "onlyInCombat", y)
    y = y - 24
    NS.CreateSlider(f, "Out-of-Combat Alpha", "alphaOOC", 0, 1, 0.1, y)
    y = y - 38
    NS.CreateToggle(f, "Hide In Vehicle", "hideInVehicle", y)
    y = y - 36

    -- LOCK
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(T.BORDER[1], T.BORDER[2], T.BORDER[3], 0.4)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    sep:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    y = y - 10

    NS.CreateToggle(f, "Lock Position", "locked", y)

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
