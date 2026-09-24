local ADDON_NAME, NS = ...

-- The Blizzard talent window loads on demand. Attach a separate, unprotected
-- control to its existing bottom action row without replacing Blizzard scripts.
local button
local refreshScheduled
local eventFrame = CreateFrame("Frame")

local function SpendInfo()
    local talents = button and button:GetParent()
    if talents and talents.IsInspecting and talents:IsInspecting() then
        return { canSpend = false, status = "Spend All is available only on your own talent tree." }
    end
    if talents and talents.GetConfigID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local displayed, active = talents:GetConfigID(), C_ClassTalents.GetActiveConfigID()
        if not displayed or displayed ~= active then
            return { canSpend = false, status = "Activate the displayed talent loadout before spending points." }
        end
    end
    if not NS.GetTalentSpendAllInfo then
        return { canSpend = false, status = "Talent assistance is still loading." }
    end
    return NS.GetTalentSpendAllInfo()
end

local function RefreshButton()
    if not button or not button:IsShown() then return end
    local info = SpendInfo()
    button:SetAlpha(info.canSpend and 1 or 0.55)
    button._status = info.status or "Choose an SBA target in /bs > Talents."
    button._target = info.targetName
end
NS.RefreshTalentTreeSpendAllButton = RefreshButton

local function ScheduleRefresh()
    if refreshScheduled then return end
    refreshScheduled = true
    NS.C_Timer_After(0.1, function()
        refreshScheduled = nil
        RefreshButton()
    end)
end

local function AttachButton()
    if button then return true end
    if InCombatLockdown and InCombatLockdown() then return false end
    local frame = _G.PlayerSpellsFrame
    local talents = frame and frame.TalentsFrame
    local apply = talents and talents.ApplyButton
    if not apply then return false end

    button = CreateFrame("Button", "BetterSBA_SpendAllTalentsButton", talents, "UIPanelButtonTemplate")
    button:SetSize(144, 22)
    -- The retail tree reserves the center of the bottom bar for Apply and the
    -- left side for loadout/search. This puts us in the gutter between them.
    button:SetPoint("RIGHT", apply, "LEFT", -16, 0)
    button:SetFrameLevel(math.max(talents:GetFrameLevel() + 1, apply:GetFrameLevel() + 1))
    button:SetText("SBA: SPEND ALL")
    button:SetScript("OnClick", function()
        local info = SpendInfo()
        local message
        if info.canSpend then
            local _
            _, message = NS.SpendAllTalentPoints()
        else
            message = info.status
        end
        if message then print("|cFF66B8D9BetterSBA|r: " .. message) end
        ScheduleRefresh()
    end)
    button:SetScript("OnEnter", function(self)
        RefreshButton()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Spend all points toward the selected SBA build")
        if self._target then GameTooltip:AddLine(self._target, 1, 1, 1, true) end
        GameTooltip:AddLine("Fills every currently legal class, specialization, and hero rank in one commit. Existing talents are not reset.",
            0.75, 0.85, 0.95, true)
        GameTooltip:AddLine(self._status or "", 1, 0.75, 0.45, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    talents:HookScript("OnShow", RefreshButton)
    eventFrame:UnregisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    RefreshButton()
    return true
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if not button and (event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED"
        or (event == "ADDON_LOADED" and addon == "Blizzard_PlayerSpells")) then
        AttachButton()
    elseif button then
        ScheduleRefresh()
    end
end)

-- Some UI replacements eagerly load Blizzard_PlayerSpells before BetterSBA.
AttachButton()
