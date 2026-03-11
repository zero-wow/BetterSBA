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
            if button == "LeftButton" and (IsShiftKeyDown() or IsControlKeyDown()) then
                ReloadUI()
                return
            elseif button == "LeftButton" then
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
                tip:AddLine("Keybind Intercept:")
                tip:AddDoubleLine("  Keybind", "|cFF44FF44" .. keyStr .. "|r")
                tip:AddDoubleLine("  Action Bar", "|cFFFFFFFF" .. bar .. "|r")
                tip:AddDoubleLine("  Slot", "|cFFFFFFFF" .. btn .. "|r")
            else
                local reason = NS.GetInterceptBlockReason()
                if reason then
                    tip:AddLine("Intercept: |cFFFF8800Paused \226\128\148 " .. reason .. "|r")
                else
                    tip:AddLine("Intercept: |cFFFF4444Inactive|r")
                end
            end

            -- "Next Up" line — track which line index it occupies for live updates
            tip:AddLine(" ")
            local nextName = NS._GetNextSpellName()
            tip:AddLine("Next: |cFFFFFFFF" .. (nextName or "---") .. "|r")
            NS._ldbTooltip = tip
            NS._ldbTooltipNextLine = tip:NumLines()
            NS._ldbTooltipLastSpell = nextName

            tip:AddLine(" ")
            tip:AddLine("|cFFCCCCCCLeft-Click|r  Open settings", 0.6, 0.6, 0.6)
            tip:AddLine("|cFFCCCCCCShift/Ctrl-Click|r  Reload UI", 0.6, 0.6, 0.6)
            tip:AddLine("|cFFCCCCCCRight-Click|r  Toggle lock", 0.6, 0.6, 0.6)

            -- Hook OnHide once to clean up live-update state
            if not tip._bsbaHideHooked then
                tip:HookScript("OnHide", function()
                    NS._ldbTooltip = nil
                    NS._ldbTooltipNextLine = nil
                    NS._ldbTooltipLastSpell = nil
                end)
                tip._bsbaHideHooked = true
            end
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
-- Helper: current next-spell name (nil if none)
----------------------------------------------------------------
function NS._GetNextSpellName()
    if NS.mainButton and NS.mainButton.spellID then
        local getName = NS.C_Spell and NS.C_Spell.GetSpellName
        if getName then return getName(NS.mainButton.spellID) end
    end
    return nil
end

----------------------------------------------------------------
-- Live-update the "Next Up" line while tooltip is open.
-- Called from UpdateNow() — only does work when tooltip is
-- visible AND the spell has actually changed.
----------------------------------------------------------------
function NS.RefreshLDBTooltipNextSpell()
    local tip = NS._ldbTooltip
    if not tip or not tip:IsShown() then return end

    local line = NS._ldbTooltipNextLine
    if not line then return end

    local name = NS._GetNextSpellName()
    if name == NS._ldbTooltipLastSpell then return end
    NS._ldbTooltipLastSpell = name

    local fs = _G[tip:GetName() .. "TextLeft" .. line]
    if fs then
        fs:SetText("Next: |cFFFFFFFF" .. (name or "---") .. "|r")
        tip:Show()  -- recalculate tooltip width
    end
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
        ldbCachedText = "Intercepting [KB: " .. keyStr .. "] [BAR: " .. bar .. "] [SLOT: " .. btn .. "]"
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

