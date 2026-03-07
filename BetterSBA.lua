local ADDON_NAME, NS = ...

local eventFrame = NS.CreateFrame("Frame")
local registeredEvents = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "UPDATE_BINDINGS",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "UNIT_AURA",
    "SPELL_UPDATE_COOLDOWN",
    "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_SUCCEEDED",
}

for _, event in NS.ipairs(registeredEvents) do
    eventFrame:RegisterEvent(event)
end

-- Register ASSISTED_COMBAT_ACTION_SPELL_CAST if it exists
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("ASSISTED_COMBAT_ACTION_SPELL_CAST") then
    eventFrame:RegisterEvent("ASSISTED_COMBAT_ACTION_SPELL_CAST")
end

----------------------------------------------------------------
-- Event handler
----------------------------------------------------------------
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then return end

        NS:InitializeDatabase()
        NS.InitMasque()
        NS.InitLDB()
        NS:CreateMainButton()
        NS:CreateQueueDisplay()
        NS.ScanKeybinds()
        NS:RegisterSlashCommands()
        NS:RegisterAssistedCombatCallbacks()

        -- Initial visibility
        NS.UpdateNow()
        NS.StartTicker()

        print("|cFF66B8D9Better|r|cFFFFFFFFSBA|r |cFF888888v" .. NS.VERSION .. "|r |cFF66B8D9loaded|r - /bs")

    elseif event == "PLAYER_LOGIN" then
        NS.ScanKeybinds()
        NS.C_Timer_After(1, NS.ScanKeybinds)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: apply pending changes
        if NS._pendingMacroRebuild then
            NS.RebuildMacroText()
        end
        if NS._pendingKeybindOverride then
            NS._pendingKeybindOverride = nil
            NS.OverrideSBAKeybind()
        end
        NS.UpdateNow()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat
        NS.UpdateNow()

    elseif event == "SPELLS_CHANGED" or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "UPDATE_BINDINGS" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            NS.ClearBaseCDCache()
        end
        if event == "ACTIONBAR_SLOT_CHANGED" then
            NS.ClearSBASlotCache()
        end
        NS.ScanKeybinds()
        NS.UpdateNow()

    elseif event == "PLAYER_TARGET_CHANGED" or event == "SPELL_UPDATE_COOLDOWN"
        or event == "UNIT_AURA" or event == "ASSISTED_COMBAT_ACTION_SPELL_CAST" then
        NS.UpdateNow()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            local rotationSpells = NS.CollectRotationSpells()
            for _, sid in NS.ipairs(rotationSpells) do
                if sid == spellID then
                    NS.PlayCastAnimation(spellID)
                    break
                end
            end
            -- Immediately refresh display so cooldowns show right after cast
            NS.UpdateNow()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.C_Timer_After(0.5, function()
            NS.ScanKeybinds()
            NS.UpdateNow()
        end)
    end
end)

----------------------------------------------------------------
-- EventRegistry callbacks for AssistedCombatManager
----------------------------------------------------------------
function NS:RegisterAssistedCombatCallbacks()
    if not EventRegistry or not EventRegistry.RegisterCallback then return end

    local function OnUpdate()
        NS.UpdateNow()
    end

    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", OnUpdate, self)
    EventRegistry:RegisterCallback("AssistedCombatManager.RotationSpellsUpdated", OnUpdate, self)
    EventRegistry:RegisterCallback("AssistedCombatManager.OnSetActionSpell", OnUpdate, self)
end

----------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------
function NS:RegisterSlashCommands()
    SLASH_BETTERSBA1 = "/bsba"
    SLASH_BETTERSBA2 = "/bettersba"
    SLASH_BETTERSBA3 = "/bs"

    SlashCmdList["BETTERSBA"] = function(msg)
        msg = (msg or ""):lower():trim()

        if msg == "lock" then
            NS.db.locked = true
            print("|cFF66B8D9BetterSBA|r: Position locked")
        elseif msg == "unlock" then
            NS.db.locked = false
            print("|cFF66B8D9BetterSBA|r: Position unlocked - drag to move")
        elseif msg == "toggle" then
            NS.db.enabled = not NS.db.enabled
            NS.UpdateNow()
            print("|cFF66B8D9BetterSBA|r: " .. (NS.db.enabled and "Enabled" or "Disabled"))
        elseif msg == "debug" then
            NS.db.debug = not NS.db.debug
            if NS.db.debug then
                NS.StartDebugDump()
            else
                NS.StopDebugDump()
            end
            print("|cFF66B8D9BetterSBA|r: Debug mode " .. (NS.db.debug and "|cFF44FF44ON|r (check chat for API diagnostics)" or "|cFFFF4444OFF|r"))
        elseif msg == "reset" then
            NS.db.position = nil
            if NS.mainButton then
                NS.mainButton:ClearAllPoints()
                NS.mainButton:SetPoint("CENTER", NS.UIParent, "CENTER", 0, -100)
            end
            print("|cFF66B8D9BetterSBA|r: Position reset")
        elseif msg == "macro" then
            local macro = NS.secureButton and NS.secureButton:GetAttribute("macrotext") or "NOT SET"
            print("|cFF66B8D9BetterSBA|r: Current macrotext:")
            for line in macro:gmatch("[^\n]+") do
                print("  |cFFFFCC00>|r " .. line)
            end
            -- Show override keybind status
            local slot = NS.FindSBAActionSlot and NS.FindSBAActionSlot()
            if slot then
                print("  SBA on action bar slot: |cFF44FF44" .. slot .. "|r")
            else
                print("  SBA: |cFFFF4444not found on action bar|r")
            end
        else
            NS.Config:Toggle()
        end
    end
end
