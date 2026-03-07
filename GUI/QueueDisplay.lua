local ADDON_NAME, NS = ...

local T = NS.THEME
local MAX_QUEUE_ICONS = 6
local queueIcons = {}

----------------------------------------------------------------
-- Create the queue display frame
----------------------------------------------------------------
function NS:CreateQueueDisplay()
    local f = NS.CreateFrame("Frame", "BetterSBA_QueueFrame", NS.UIParent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.7)
    f:SetBackdropBorderColor(NS.unpack(T.BORDER))
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(4)

    -- Label
    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    f.label:SetTextColor(NS.unpack(T.TEXT_DIM))
    f.label:SetText("ROTATION")

    -- Create icon slots
    for i = 1, MAX_QUEUE_ICONS do
        local icon = NS.CreateFrame("Frame", nil, f, "BackdropTemplate")
        icon:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        icon:SetBackdropColor(0, 0, 0, 0.6)
        icon:SetBackdropBorderColor(NS.unpack(T.BORDER))

        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetPoint("TOPLEFT", 1, -1)
        icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        icon.cd = NS.CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints(icon.tex)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetHideCountdownNumbers(true)

        icon.spellID = nil
        icon:Hide()
        queueIcons[i] = icon
    end

    self.queueFrame = f
    NS.LayoutQueue()
    return f
end

----------------------------------------------------------------
-- Layout icons based on position setting
----------------------------------------------------------------
function NS.LayoutQueue()
    local f = NS.queueFrame
    local btn = NS.mainButton
    if not f or not btn then return end

    local db = NS.db
    local iconSize = db.queueIconSize
    local spacing = db.queueSpacing
    local pos = db.queuePosition

    for i, icon in NS.ipairs(queueIcons) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
    end

    f:ClearAllPoints()
    f.label:ClearAllPoints()

    if pos == "RIGHT" then
        f:SetPoint("LEFT", btn, "RIGHT", 4, 0)
        f.label:SetPoint("BOTTOM", queueIcons[1], "TOP", 0, 2)
        for i, icon in NS.ipairs(queueIcons) do
            if i == 1 then
                icon:SetPoint("LEFT", f, "LEFT", 3, 0)
            else
                icon:SetPoint("LEFT", queueIcons[i - 1], "RIGHT", spacing, 0)
            end
        end
        local count = math.min(MAX_QUEUE_ICONS, #queueIcons)
        f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)
    elseif pos == "LEFT" then
        f:SetPoint("RIGHT", btn, "LEFT", -4, 0)
        f.label:SetPoint("BOTTOM", queueIcons[1], "TOP", 0, 2)
        for i, icon in NS.ipairs(queueIcons) do
            if i == 1 then
                icon:SetPoint("LEFT", f, "LEFT", 3, 0)
            else
                icon:SetPoint("LEFT", queueIcons[i - 1], "RIGHT", spacing, 0)
            end
        end
        local count = math.min(MAX_QUEUE_ICONS, #queueIcons)
        f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)
    elseif pos == "TOP" then
        f:SetPoint("BOTTOM", btn, "TOP", 0, 4)
        f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
        for i, icon in NS.ipairs(queueIcons) do
            if i == 1 then
                icon:SetPoint("LEFT", f, "LEFT", 3, 0)
            else
                icon:SetPoint("LEFT", queueIcons[i - 1], "RIGHT", spacing, 0)
            end
        end
        local count = math.min(MAX_QUEUE_ICONS, #queueIcons)
        f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)
    elseif pos == "BOTTOM" then
        f:SetPoint("TOP", btn, "BOTTOM", 0, -4)
        f.label:SetPoint("BOTTOM", f, "TOP", 0, 2)
        for i, icon in NS.ipairs(queueIcons) do
            if i == 1 then
                icon:SetPoint("LEFT", f, "LEFT", 3, 0)
            else
                icon:SetPoint("LEFT", queueIcons[i - 1], "RIGHT", spacing, 0)
            end
        end
        local count = math.min(MAX_QUEUE_ICONS, #queueIcons)
        f:SetSize(count * (iconSize + spacing) - spacing + 6, iconSize + 6)
    end
end

----------------------------------------------------------------
-- Update queue icons with rotation spells
----------------------------------------------------------------
function NS.UpdateQueueDisplay()
    local f = NS.queueFrame
    if not f then return end

    if not NS.db.showQueue then
        f:Hide()
        return
    end

    local nextSpell = NS.CollectNextSpell()
    local rotationSpells = NS.CollectRotationSpells()

    if not rotationSpells or #rotationSpells == 0 then
        f:Hide()
        return
    end

    f:Show()

    local visibleCount = 0
    for i = 1, MAX_QUEUE_ICONS do
        local icon = queueIcons[i]
        local spellID = rotationSpells[i]

        if spellID and spellID ~= 0 then
            icon.spellID = spellID
            visibleCount = visibleCount + 1

            local tex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(spellID)
            if tex then
                icon.tex:SetTexture(tex)
            end

            -- Highlight the current next-cast spell
            if spellID == nextSpell then
                icon:SetBackdropBorderColor(NS.unpack(T.ACCENT))
                icon.tex:SetDesaturated(false)
                icon.tex:SetVertexColor(1, 1, 1)
            else
                icon:SetBackdropBorderColor(NS.unpack(T.BORDER))
                icon.tex:SetDesaturated(false)
                icon.tex:SetVertexColor(0.7, 0.7, 0.7)
            end

            -- Cooldown
            if NS.C_Spell and NS.C_Spell.GetSpellCooldown then
                local cdInfo = NS.C_Spell.GetSpellCooldown(spellID)
                if cdInfo and cdInfo.startTime and cdInfo.duration and cdInfo.duration > 1.5 then
                    icon.cd:SetCooldown(cdInfo.startTime, cdInfo.duration)
                else
                    icon.cd:Clear()
                end
            end

            icon:Show()
        else
            icon:Hide()
        end
    end

    -- Tooltip on individual icons
    for i = 1, MAX_QUEUE_ICONS do
        local icon = queueIcons[i]
        if not icon._tooltipHooked then
            icon:EnableMouse(true)
            icon:SetScript("OnEnter", function(self)
                if self.spellID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(self.spellID)
                    GameTooltip:Show()
                end
            end)
            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            icon._tooltipHooked = true
        end
    end

    -- Resize frame to fit visible icons
    if visibleCount > 0 then
        local iconSize = NS.db.queueIconSize
        local spacing = NS.db.queueSpacing
        f:SetSize(visibleCount * (iconSize + spacing) - spacing + 6, iconSize + 6)
    end
end
