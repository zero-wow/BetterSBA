local ADDON_NAME, NS = ...

----------------------------------------------------------------
-- Safe API wrapper
----------------------------------------------------------------
function NS.SafeCall(fn, ...)
    if not fn then return false end
    local ok, a, b, c = NS.pcall(fn, ...)
    if ok then return true, a, b, c end
    -- Retry without args (API signature may differ between patches)
    ok, a, b, c = NS.pcall(fn)
    if ok then return true, a, b, c end
    return false
end

----------------------------------------------------------------
-- SBA spell name (cached, handles localization)
----------------------------------------------------------------
function NS.GetSBASpellName()
    if NS._sbaName then return NS._sbaName end
    if NS.C_Spell and NS.C_Spell.GetSpellName then
        NS._sbaName = NS.C_Spell.GetSpellName(NS.SBA_SPELL_ID)
    end
    NS._sbaName = NS._sbaName or "Single-Button Assistant"
    return NS._sbaName
end

----------------------------------------------------------------
-- Spell collection (three-tier fallback)
----------------------------------------------------------------
function NS.CollectNextSpell()
    local ac = NS.C_AssistedCombat
    if not ac then return nil end

    local check = NS.db and NS.db.checkVisibleButton or false

    if ac.GetNextCastSpell then
        local ok, sid = NS.SafeCall(ac.GetNextCastSpell, check)
        if ok and sid and sid ~= 0 then return sid end
    end

    if ac.GetRotationSpells then
        local ok, spells = NS.SafeCall(ac.GetRotationSpells)
        if ok and spells and spells[1] and spells[1] ~= 0 then return spells[1] end
    end

    if ac.GetActionSpell then
        local ok, sid = NS.SafeCall(ac.GetActionSpell)
        if ok and sid and sid ~= 0 then return sid end
    end

    return nil
end

function NS.CollectRotationSpells()
    local ac = NS.C_AssistedCombat
    if not ac or not ac.GetRotationSpells then return {} end
    local ok, spells = NS.SafeCall(ac.GetRotationSpells)
    if ok and spells then return spells end
    return {}
end

----------------------------------------------------------------
-- Macro text builder
----------------------------------------------------------------
function NS.BuildMacroText()
    local lines = {}
    local db = NS.db

    if db.enableTargeting then
        NS.table_insert(lines, "/targetenemy [noharm][dead]")
    end

    if db.enablePetAttack then
        NS.table_insert(lines, "/petattack")
    end

    if db.enableChannelProtection then
        NS.table_insert(lines, "/stopmacro [channeling]")
    end

    NS.table_insert(lines, "/cast " .. NS.GetSBASpellName())

    return NS.table_concat(lines, "\n")
end

function NS.RebuildMacroText()
    if NS.InCombatLockdown() then
        NS._pendingMacroRebuild = true
        return
    end
    if NS.mainButton then
        NS.mainButton:SetAttribute("macrotext", NS.BuildMacroText())
    end
    NS._pendingMacroRebuild = false
end

----------------------------------------------------------------
-- Keybind scanning
----------------------------------------------------------------
local keybindCache = {}

function NS.FormatKeybind(key)
    if not key then return nil end
    for pattern, sub in NS.pairs(NS.KEYBIND_SUBS) do
        key = key:gsub(pattern, sub)
    end
    return key
end

local BINDING_BARS = {
    "ACTIONBUTTON",
    "MULTIACTIONBAR1BUTTON",
    "MULTIACTIONBAR2BUTTON",
    "MULTIACTIONBAR3BUTTON",
    "MULTIACTIONBAR4BUTTON",
    "MULTIACTIONBAR5BUTTON",
    "MULTIACTIONBAR6BUTTON",
    "MULTIACTIONBAR7BUTTON",
}

function NS.ScanKeybinds()
    keybindCache = {}

    -- Bartender4
    if _G["Bartender4"] then
        for i = 1, 180 do
            local actionType, id = NS.GetActionInfo(i)
            if actionType == "spell" and id then
                local key = NS.GetBindingKey("CLICK BT4Button" .. i .. ":Keybind")
                if key then
                    keybindCache[id] = NS.FormatKeybind(key)
                end
            end
        end
        return
    end

    -- ElvUI
    if _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        for bar = 1, 15 do
            for btn = 1, 12 do
                local elvBtn = _G["ElvUI_Bar" .. bar .. "Button" .. btn]
                if elvBtn then
                    local slot = elvBtn._state_action
                    if slot then
                        local actionType, id = NS.GetActionInfo(slot)
                        if actionType == "spell" and id then
                            local binding = elvBtn.bindstring or elvBtn.keyBoundTarget
                                or ("CLICK " .. elvBtn:GetName() .. ":LeftButton")
                            local key = NS.GetBindingKey(binding)
                            if key then
                                keybindCache[id] = NS.FormatKeybind(key)
                            end
                        end
                    end
                end
            end
        end
        return
    end

    -- Dominos
    if NS.C_AddOns.IsAddOnLoaded("Dominos") then
        for i = 1, 180 do
            local actionType, id = NS.GetActionInfo(i)
            if actionType == "spell" and id and not keybindCache[id] then
                local barIndex = NS.math_floor((i - 1) / 12)
                local btnIndex = ((i - 1) % 12) + 1
                if BINDING_BARS[barIndex + 1] then
                    local key = NS.GetBindingKey(BINDING_BARS[barIndex + 1] .. btnIndex)
                    if key then
                        keybindCache[id] = NS.FormatKeybind(key)
                    end
                end
            end
        end
        return
    end

    -- Default Blizzard bars
    for i = 1, 180 do
        local actionType, id = NS.GetActionInfo(i)
        if actionType == "spell" and id and not keybindCache[id] then
            local barIndex = NS.math_floor((i - 1) / 12)
            local btnIndex = ((i - 1) % 12) + 1
            if BINDING_BARS[barIndex + 1] then
                local key = NS.GetBindingKey(BINDING_BARS[barIndex + 1] .. btnIndex)
                if key then
                    keybindCache[id] = NS.FormatKeybind(key)
                end
            end
        end
    end
end

function NS.GetKeybindForSpell(spellID)
    return keybindCache[spellID]
end
