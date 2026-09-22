local ADDON_NAME, NS = ...

local ART = "Interface\\AddOns\\BetterSBA\\IMG\\Button\\"

function NS.UsesSoftButtonStyle()
    return NS.db and NS.db.buttonStyle ~= "Classic"
end

local function MaskRegion(region, mask, enabled)
    if not region or not region.AddMaskTexture then return end
    if enabled and not region._bsbaSoftMask then
        region:AddMaskTexture(mask)
        region._bsbaSoftMask = mask
    elseif not enabled and region._bsbaSoftMask then
        region:RemoveMaskTexture(region._bsbaSoftMask)
        region._bsbaSoftMask = nil
    end
end

local function CreateChrome(button, icon)
    local chrome = {}
    button._softChrome = chrome
    chrome.outerMask = button:CreateMaskTexture()
    chrome.outerMask:SetTexture(ART .. "RoundedMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    chrome.outerMask:SetAllPoints(button)
    chrome.innerMask = button:CreateMaskTexture()
    chrome.innerMask:SetTexture(ART .. "RoundedMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    chrome.innerMask:SetAllPoints(icon)

    chrome.shadow = button:CreateTexture(nil, "BACKGROUND", nil, -3)
    chrome.shadow:SetTexture(ART .. "Glow")
    chrome.shadow:SetPoint("TOPLEFT", -3, 2)
    chrome.shadow:SetPoint("BOTTOMRIGHT", 3, -4)
    chrome.shadow:SetVertexColor(0, 0, 0, 0.7)

    chrome.glint = button:CreateTexture(nil, "ARTWORK", nil, 2)
    chrome.glint:SetTexture(ART .. "RoundedRing")
    chrome.glint:SetAllPoints(icon)
    chrome.glint:SetVertexColor(0.85, 0.94, 1, 0.16)

    chrome.hover = button:CreateTexture(nil, "ARTWORK", nil, 3)
    chrome.hover:SetTexture(ART .. "RoundedRing")
    chrome.hover:SetAllPoints(button)
    chrome.hover:SetVertexColor(0.6, 0.85, 1, 0.7)
    chrome.hover:Hide()

    if button.hotkey then
        chrome.keycap = button:CreateTexture(nil, "ARTWORK", nil, 4)
        chrome.keycap:SetTexture(ART .. "Keycap")
        chrome.keycap:SetPoint("TOPLEFT", button.hotkey, "TOPLEFT", -3, 2)
        chrome.keycap:SetPoint("BOTTOMRIGHT", button.hotkey, "BOTTOMRIGHT", 3, -2)
        chrome.keycap:SetVertexColor(0.015, 0.025, 0.04, 0.82)
        chrome.keycap:Hide()
    end
    return chrome
end

-- Geometry and Masque ownership change only when settings are applied out of combat.
-- The secure action overlay and its binding attributes are never modified here.
function NS.ApplyButtonStyle(button, isPriority)
    if not button then return end
    if NS.InCombatLockdown() then
        NS._pendingButtonSettings = true
        return
    end
    local icon = button.icon or button.tex
    if not icon then return end
    local soft = NS.UsesSoftButtonStyle()
    local group = isPriority and NS.masquePriorityGroup or NS.masqueMainGroup
    local regions = button._masqueRegions
    if soft and button._masqueRegistered and group then
        group:RemoveButton(button)
        button._masqueRegistered = false
    end
    local chrome = button._softChrome or CreateChrome(button, icon)
    local cooldown = button.cooldown or button.cd

    MaskRegion(button.borderTex, chrome.outerMask, soft)
    MaskRegion(button.bg, chrome.innerMask, soft)
    MaskRegion(icon, chrome.innerMask, soft)
    MaskRegion(button.pushedTex, chrome.innerMask, soft)
    if button.pauseOverlay then
        MaskRegion(button.pauseOverlay.background, chrome.outerMask, soft)
    end

    if soft then
        -- Masque's registered regions are retained for switching back to Classic.
        if regions then
            button.Border = nil
            for _, key in ipairs({ "Normal", "Highlight", "Flash", "Border" }) do
                if regions[key] then regions[key]:Hide() end
            end
        end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1.5, -1.5)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1.5, 1.5)
        icon:SetTexCoord(unpack(NS.ICON_TEXCOORD))
        button.bg:ClearAllPoints()
        button.bg:SetAllPoints(icon)
        button.bg:Show()
        button.borderTex:Show()
        local bg = NS.db[isPriority and "priorityBgColor" or "buttonBgColor"] or {0.02, 0.03, 0.05, 0.8}
        button.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 0.8)
        if cooldown then
            cooldown:ClearAllPoints()
            cooldown:SetAllPoints(icon)
            cooldown:SetSwipeTexture(ART .. "RoundedMask")
            cooldown:SetSwipeColor(0.015, 0.02, 0.03, 0.72)
            cooldown:SetDrawEdge(false)
            cooldown:SetDrawBling(false)
        end
        chrome.shadow:Show()
        chrome.glint:Show()
        if button.hotkey then
            button.hotkey:SetTextColor(0.96, 0.98, 1, 1)
            button.hotkey:SetShadowColor(0, 0, 0, 0.9)
            button.hotkey:SetShadowOffset(0, -1)
        end
    else
        chrome.shadow:Hide()
        chrome.glint:Hide()
        chrome.hover:Hide()
        if chrome.keycap then chrome.keycap:Hide() end
        if regions and group then
            button.Border = regions.Border
            if not button._masqueRegistered then
                group:AddButton(button, regions)
                button._masqueRegistered = true
            else
                group:ReSkin(button)
            end
            button.borderTex:Hide()
            button.bg:Hide()
        else
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            button.bg:ClearAllPoints()
            button.bg:SetAllPoints(icon)
            button.bg:Show()
            button.borderTex:Show()
            if cooldown then
                cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
                cooldown:SetSwipeColor(0, 0, 0, 0.8)
            end
        end
    end
    NS.UpdateButtonChrome(button)
end

function NS.UpdateButtonChrome(button)
    local chrome = button and button._softChrome
    if not chrome then return end
    if chrome.keycap then
        local hotkey = button.hotkey
        local text = hotkey and hotkey:GetText()
        chrome.keycap:SetShown(NS.UsesSoftButtonStyle() and hotkey:IsShown() and text ~= nil and text ~= "")
    end
end

function NS.SetButtonHover(button, hovering)
    local chrome = button and button._softChrome
    if chrome then chrome.hover:SetShown(hovering and NS.UsesSoftButtonStyle()) end
end

function NS.ApplyAllButtonStyles()
    NS.ApplyButtonStyle(NS.mainButton)
    for _, icon in ipairs(NS._priorityIcons or {}) do
        NS.ApplyButtonStyle(icon, true)
    end
end
