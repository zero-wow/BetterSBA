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
        text = "Idle",
        icon = NS.ICON_PATH,
        iconCoords = { 0.20, 0.80, 0.20, 0.80 },
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

            -- Intercept status
            tip:AddLine(" ")
            local keys = NS._overrideKeys
            local slot = NS._overrideSlot
            if keys and #keys > 0 then
                local keyStr = NS.table_concat(keys, ", ")
                local bar = NS.math_floor((slot - 1) / 12) + 1
                local btn = ((slot - 1) % 12) + 1
                tip:AddLine("Intercept: |cFF44FF44[" .. keyStr .. "]|r [BAR: " .. bar .. "] [SLOT: " .. btn .. "]")
            else
                local reason = NS.GetInterceptBlockReason()
                if reason then
                    tip:AddLine("Intercept: |cFFFF8800Paused \226\128\148 " .. reason .. "|r")
                else
                    tip:AddLine("Intercept: |cFFFF4444Inactive|r")
                end
            end

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
        NS.LDBI = LDBI
        LDBI:Register("BetterSBA", dataObj, NS.db.minimap)

        -- Style the minimap icon (delayed to run after LibDBIcon layout)
        local function StyleMinimapIcon()
            local mmButton = LDBI:GetMinimapButton("BetterSBA")
            if not mmButton then return end
            local icon = mmButton.icon or mmButton.Icon
            if not icon then return end
            icon:SetBlendMode("ADD")
            -- 256x256 TGA with black padding — crop 20% from each edge
            icon:SetTexCoord(0.20, 0.80, 0.20, 0.80)
            -- Size and center icon within button (calibration values from db)
            local sz = NS.db.minimapIconSize or 19
            icon:ClearAllPoints()
            icon:SetSize(sz, sz)
            icon:SetPoint("CENTER", mmButton, "CENTER", NS.db.minimapIconOffsetX or 2, NS.db.minimapIconOffsetY or -2)
        end
        NS.StyleMinimapIcon = StyleMinimapIcon

        NS.C_Timer_After(0, StyleMinimapIcon)

        -- Reapply after LibDBIcon may reset icon on show
        local mmButton = LDBI:GetMinimapButton("BetterSBA")
        if mmButton then
            mmButton:HookScript("OnShow", function()
                NS.C_Timer_After(0, StyleMinimapIcon)
            end)
        end
    end

    -- Initial text update
    NS.UpdateLDBText()
end

----------------------------------------------------------------
-- Intercept block reason (vehicle, mounted, skyriding, etc.)
----------------------------------------------------------------
function NS.GetInterceptBlockReason()
    if UnitInVehicle and UnitInVehicle("player") then
        return "Vehicle"
    end
    if HasVehicleActionBar and HasVehicleActionBar() then
        return "Vehicle"
    end
    if HasOverrideActionBar and HasOverrideActionBar() then
        return "Override Bar"
    end
    if HasBonusActionBar and HasBonusActionBar() then
        -- Dragonriding / Skyriding uses bonus action bar
        if IsMounted and IsMounted() then
            return "Skyriding"
        end
        return "Bonus Bar"
    end
    if IsPossessBarVisible and IsPossessBarVisible() then
        return "Possess Bar"
    end
    if IsMounted and IsMounted() then
        return "Mounted"
    end
    return nil
end

----------------------------------------------------------------
-- Update LDB text based on intercept state
----------------------------------------------------------------
-- Cached LDB text to avoid re-creating the same string every tick.
-- Only rebuilds when the underlying state actually changes.
local ldbCachedKeys = nil     -- last _overrideKeys reference
local ldbCachedSlot = nil     -- last _overrideSlot
local ldbCachedReason = nil   -- last pause reason (nil, "Skyriding", etc.)
local ldbCachedText = nil     -- last computed text

function NS.UpdateLDBText()
    local dataObj = NS.ldbDataObj
    if not dataObj then return end
    if not NS.db.ldbShowText then
        dataObj.text = ""
        return
    end

    local keys = NS._overrideKeys
    local slot = NS._overrideSlot
    local reason = NS.GetInterceptBlockReason()

    -- Skip rebuild if inputs haven't changed (avoids string garbage)
    if keys == ldbCachedKeys and slot == ldbCachedSlot
       and reason == ldbCachedReason and ldbCachedText then
        dataObj.text = ldbCachedText
        return
    end
    ldbCachedKeys = keys
    ldbCachedSlot = slot
    ldbCachedReason = reason

    if keys and #keys > 0 then
        local keyStr = NS.table_concat(keys, ", ")
        local bar = NS.math_floor((slot - 1) / 12) + 1
        local btn = ((slot - 1) % 12) + 1
        ldbCachedText = "Intercepting [" .. keyStr .. "] [BAR: " .. bar .. "] [SLOT: " .. btn .. "]"
    else
        if reason then
            ldbCachedText = "Paused: " .. reason
        else
            ldbCachedText = "Idle"
        end
    end
    dataObj.text = ldbCachedText
end

----------------------------------------------------------------
-- Minimap button show/hide toggle
----------------------------------------------------------------
function NS.SetMinimapVisible(show)
    local LDBI = NS.LDBI
    if not LDBI then return end
    if show then
        NS.db.minimap.hide = false
        LDBI:Show("BetterSBA")
        NS.C_Timer_After(0, function()
            if NS.StyleMinimapIcon then NS.StyleMinimapIcon() end
        end)
    else
        NS.db.minimap.hide = true
        LDBI:Hide("BetterSBA")
    end
end

