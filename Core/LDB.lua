local ADDON_NAME, NS = ...

local T = NS.THEME

----------------------------------------------------------------
-- LDB data object (standalone protocol, no library required)
----------------------------------------------------------------
function NS.InitLDB()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    local dataObj = LDB:NewDataObject("BetterSBA", {
        type = "launcher",
        label = "BetterSBA",
        icon = NS.ICON_PATH,
        OnClick = function(_, button)
            if button == "LeftButton" then
                NS.Config:Toggle()
            elseif button == "RightButton" then
                NS.db.locked = not NS.db.locked
                print("|cFF66B8D9BetterSBA|r: Position " .. (NS.db.locked and "locked" or "unlocked"))
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine("|cFF66B8D9Better|r|cFFFFFFFFSBA|r  |cFF888888" .. NS.VERSION .. "|r")
            tip:AddLine(" ")

            local status = NS.db.enabled and "|cFF44FF44Enabled|r" or "|cFFFF4444Disabled|r"
            tip:AddLine("Status: " .. status)

            local lockText = NS.db.locked and "|cFF888888Locked|r" or "|cFF44FF44Unlocked|r"
            tip:AddLine("Position: " .. lockText)

            if NS.mainButton and NS.mainButton.spellID then
                local name = NS.C_Spell and NS.C_Spell.GetSpellName
                    and NS.C_Spell.GetSpellName(NS.mainButton.spellID)
                if name then
                    tip:AddLine(" ")
                    tip:AddLine("Next: |cFFFFFFFF" .. name .. "|r")
                end
            end

            tip:AddLine(" ")
            tip:AddLine("|cFFCCCCCCLeft-Click|r  Open settings", 0.6, 0.6, 0.6)
            tip:AddLine("|cFFCCCCCCRight-Click|r  Toggle lock", 0.6, 0.6, 0.6)
        end,
    })

    NS.ldbDataObj = dataObj

    -- LibDBIcon minimap button (uses ADD blend to remove black bg)
    local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBI then
        LDBI:Register("BetterSBA", dataObj, NS.db.minimap)

        -- Apply additive blend to remove black background from TGA icon
        local mmButton = LDBI:GetMinimapButton("BetterSBA")
        if mmButton then
            local icon = mmButton.icon or mmButton.Icon
            if icon then
                if icon.SetBlendMode then
                    icon:SetBlendMode("ADD")
                end
                -- 256x256 TGA with black padding (24bpp, no alpha) — crop to content
                icon:SetTexCoord(0.25, 0.75, 0.25, 0.75)
                local w, h = mmButton:GetSize()
                icon:SetSize(w, h)
                icon:ClearAllPoints()
                icon:SetPoint("CENTER")
            end
        end
    end
end
