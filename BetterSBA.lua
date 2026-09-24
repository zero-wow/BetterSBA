local ADDON_NAME, NS = ...

local eventFrame = NS.CreateFrame("Frame")
local registeredEvents = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BINDINGS",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "UNIT_AURA",
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_SHAPESHIFT_FORMS",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "ITEM_DATA_LOAD_RESULT",
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

        NS._loadTime = GetTime()
        NS:InitializeDatabase()
        -- Apply saved theme preset before any UI creation
        if NS.db.themePreset and NS.db.themePreset ~= "Default" then
            NS.ApplyThemePreset(NS.db.themePreset)
        end
        NS.InitMasque()
        NS.InitLDB()
        NS:CreateMainButton()
        NS:CreatePriorityDisplay()
        NS.ScanKeybinds()
        if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
        NS.ApplyAnimCloneDebugBinding()
        NS:RegisterSlashCommands()
        NS:RegisterAssistedCombatCallbacks()

        -- Initial visibility
        NS.UpdateNow()
        NS.StartTicker()
        NS.StartGCTicker()

        print("|cFF66B8D9Better|r|cFFFFFFFFSBA|r |cFF888888v" .. NS.VERSION .. "|r |cFF66B8D9loaded|r - /bs")
        if NS.IsDebugChannelEnabled and NS.IsDebugChannelEnabled("other") then
            print("|cFF66B8D9BetterSBA|r: DB.locked = " .. NS.tostring(NS.db.locked))
        end

    elseif event == "PLAYER_LOGIN" then
        NS.ScanKeybinds()
        if NS.RefreshTrinkets then NS.RefreshTrinkets() end
        if NS.InitializeMotionFeedback then NS.InitializeMotionFeedback() end
        NS.C_Timer_After(1, NS.ScanKeybinds)
        -- Seed virtual cooldown system (must be out of combat)
        NS.C_Timer_After(1.5, function()
            NS.SeedVirtualCooldowns()
        end)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: apply pending changes
        if NS._pendingKeybindScan then
            NS._pendingKeybindScan = nil
            NS.ScanKeybinds()
        end
        if NS._pendingTrinketRefresh then
            NS._pendingTrinketRefresh = nil
            if NS.RefreshTrinkets then NS.RefreshTrinkets() end
        end
        if NS._pendingMacroRebuild then
            NS.RebuildMacroText()
        end
        if NS._pendingKeybindOverride then
            NS._pendingKeybindOverride = nil
            NS.OverrideSBAKeybind()
        end
        if NS._pendingClickIntercept then
            NS._pendingClickIntercept = nil
            NS.UpdateClickIntercept()
        end
        if NS._pendingButtonSettings then
            NS._pendingButtonSettings = nil
            NS.ApplyButtonSettings()
        end
        if NS._pendingAnimCloneDebugBinding then
            NS._pendingAnimCloneDebugBinding = nil
            NS.ApplyAnimCloneDebugBinding()
        end
        if NS._pendingMissingKeybindScan and NS.ScanMissingKeybinds then
            NS._pendingMissingKeybindScan = nil
            NS.ScanMissingKeybinds()
        end
        -- Seed virtual cooldowns if deferred from combat load
        NS.CheckPendingVirtualCD()
        NS.UpdateNow()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat
        NS.UpdateNow()

    elseif event == "SPELLS_CHANGED" or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BINDINGS" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_OVERRIDE_ACTIONBAR"
        or event == "UPDATE_VEHICLE_ACTIONBAR" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_SHAPESHIFT_FORMS" then
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            -- Specializations may put SBA on different action-bar slots.  Do
            -- not let the next binding/overlay refresh reuse the prior spec.
            NS.ClearSBASlotCache()
            NS.ClearBaseCDCache()
            NS.ResetVirtualCooldowns()
            NS.InvalidateRotationCache()
            NS.InvalidateResolveCache()
            NS.InvalidateTextureCache()
            NS.InvalidateCooldownCache()
            NS.RebuildMacroText()  -- class-specific off-GCD lines may change on spec swap
        end
        if event == "SPELLS_CHANGED" then
            NS.InvalidateRotationCache()
            NS.InvalidateResolveCache()
            NS.InvalidateTextureCache()
            NS.InvalidateCooldownCache()
            NS.RebuildMacroText()
        end
        if event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED"
            or event == "UPDATE_BONUS_ACTIONBAR"
            or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "UPDATE_VEHICLE_ACTIONBAR"
            or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
            NS.ClearSBASlotCache()
        end
        NS.ScanKeybinds()
        NS.UpdateNow()
        -- Delayed re-scan for bar transitions (API state may lag behind events).
        -- Includes action-bar page and slot changes for bar transition recovery.
        -- Debounced so rapid-fire events don't spawn dozens of timers.
        if event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_OVERRIDE_ACTIONBAR"
            or event == "UPDATE_VEHICLE_ACTIONBAR" or event == "ACTIONBAR_SLOT_CHANGED"
            or event == "ACTIONBAR_PAGE_CHANGED"
            or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
            if not NS._pendingDelayedRescan then
                NS._pendingDelayedRescan = true
                NS.C_Timer_After(0.5, function()
                    NS._pendingDelayedRescan = nil
                    NS.ClearSBASlotCache()
                    NS.ScanKeybinds()
                    NS.UpdateNow()
                end)
            end
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "ITEM_DATA_LOAD_RESULT" then
        local id = ...
        if event == "PLAYER_EQUIPMENT_CHANGED" and id ~= 13 and id ~= 14 then return end
        if event == "ITEM_DATA_LOAD_RESULT" then
            local top = NS.GetTrinketStatus and NS.GetTrinketStatus(13)
            local bottom = NS.GetTrinketStatus and NS.GetTrinketStatus(14)
            if not ((top and top.itemID == id) or (bottom and bottom.itemID == id)) then return end
            if NS.OnTrinketItemDataLoadResult then
                NS.OnTrinketItemDataLoadResult(id, select(2, ...))
                return
            end
        end
        if NS.InCombatLockdown() then
            NS._pendingTrinketRefresh = true
        elseif NS.RefreshTrinkets then
            NS.RefreshTrinkets()
        end

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        -- Mount/dismount: immediate scan + delayed retries to catch API lag.
        NS.ScanKeybinds()
        NS.UpdateNow()
        NS.C_Timer_After(0.3, function()
            NS.ClearSBASlotCache()
            NS.ScanKeybinds()
            NS.UpdateNow()
        end)
        NS.C_Timer_After(0.8, function()
            NS.ClearSBASlotCache()
            NS.ScanKeybinds()
            NS.UpdateNow()
        end)
        NS.C_Timer_After(1.5, function()
            NS.ClearSBASlotCache()
            NS.ScanKeybinds()
            NS.UpdateNow()
        end)

    elseif event == "PLAYER_TARGET_CHANGED" or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "UNIT_AURA" or event == "ASSISTED_COMBAT_ACTION_SPELL_CAST" then
        if event == "UNIT_AURA" then
            local unit = ...
            if unit ~= "player" and unit ~= "target" then return end
        end
        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
            NS.InvalidateCooldownCache()
        end
        NS.QueueDisplayUpdate()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            -- Update virtual cooldown tracker
            NS.OnSpellCastSucceeded(spellID)
            local rotationSpells = NS.CollectRotationSpells()
            for idx = 1, #rotationSpells do
                if rotationSpells[idx] == spellID then
                    NS.PlayCastAnimation(spellID)
                    break
                end
            end
            -- Refresh display after animation starts (outgoing already
            -- captured the cast spell; incoming defers its own UpdateNow)
            NS.UpdateNow()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.C_Timer_After(0.5, function()
            NS.ScanKeybinds()
            NS.ApplyButtonSettings()  -- reapply fonts/size after full load
            NS.LayoutPriority()
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

    local function OnRotationChanged()
        NS.InvalidateRotationCache()
        NS.UpdateNow()
    end

    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", OnUpdate, self)
    EventRegistry:RegisterCallback("AssistedCombatManager.RotationSpellsUpdated", OnRotationChanged, self)
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
            if NS.db.enabled then NS.StartTicker() else NS.StopTicker() end
            if not NS.db.enabled then
                if NS.ResetMotionFeedback then NS.ResetMotionFeedback() end
                if NS.ResetAnimClonePool then NS.ResetAnimClonePool() end
            end
            if NS.RefreshSBAInterception then
                NS.RefreshSBAInterception()
            else
                NS.ScanKeybinds()
            end
            NS.UpdateNow()
            if NS.UpdateLDBText then NS.UpdateLDBText() end
            local state = NS.db.enabled and "Enabled" or "Disabled"
            if NS.InCombatLockdown() then state = state .. " (input change pending until combat ends)" end
            print("|cFF66B8D9BetterSBA|r: " .. state)
        elseif msg == "debug" then
            NS.db.debug = not NS.db.debug
            if NS.ApplyDebugSettings then NS.ApplyDebugSettings() end
            print("|cFF66B8D9BetterSBA|r: Debug mode " .. (NS.db.debug and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
        elseif msg == "reset" then
            NS.db.position = nil
            if NS.mainButton then
                NS.mainButton:ClearAllPoints()
                NS.mainButton:SetPoint("CENTER", NS.UIParent, "CENTER", 0, -100)
            end
            print("|cFF66B8D9BetterSBA|r: Position reset")
        elseif msg == "preview" then
            NS.StartPreviewMode()
        elseif msg == "stop" then
            NS.StopPreviewMode()
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
        elseif msg == "new" then
            NS.SwitchSettingsPanel("studio")
        elseif msg == "classic" then
            NS.SwitchSettingsPanel("classic")
        else
            NS.ToggleSettingsPanel()
        end
    end
end
