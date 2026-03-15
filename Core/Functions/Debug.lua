local ADDON_NAME, NS = ...

-- Debug output
----------------------------------------------------------------
local DEBUG_PREFIX = "|cFF66B8D9[BetterSBA Debug]|r "
local debugVerbose = false  -- toggled on for periodic dumps

local function DebugChannelEnabled(channel)
    if not NS.db or not NS.db.debug then return false end
    if channel == "spell" then
        return NS.db.debugSpellUpdates ~= false
    end
    if channel == "anim" then
        return NS.db.debugAnimClone ~= false
    end
    return NS.db.debugOther ~= false
end

function NS.IsDebugChannelEnabled(channel)
    return DebugChannelEnabled(channel)
end

local function DebugPrintImpl(channel, ...)
    if not DebugChannelEnabled(channel) then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = NS.tostring(select(i, ...))
    end
    print(DEBUG_PREFIX .. NS.table_concat(parts, " "))
end

function NS.DebugPrint(...)
    if not debugVerbose then return end
    local channel = select(1, ...)
    if channel == "spell" or channel == "anim" or channel == "other" then
        DebugPrintImpl(channel, select(2, ...))
        return
    end
    DebugPrintImpl("spell", ...)
end

-- Always print (for click events and important messages)
function NS.DebugPrintAlways(channel, ...)
    if channel == "spell" or channel == "anim" or channel == "other" then
        DebugPrintImpl(channel, ...)
        return
    end
    DebugPrintImpl("other", channel, ...)
end

function NS.ApplyDebugSettings()
    if NS.db and NS.db.debug and ((NS.db.debugSpellUpdates ~= false) or (NS.db.debugOther ~= false)) then
        NS.StartDebugDump()
    else
        NS.StopDebugDump()
    end
end

-- Periodic debug dump: runs one verbose update every 3 seconds
local debugDumpTicker = nil
local debugDumpedAPI = false

function NS.StartDebugDump()
    if debugDumpTicker then return end
    debugDumpTicker = C_Timer.NewTicker(3, function()
        if not NS.db or not NS.db.debug or ((NS.db.debugSpellUpdates == false) and (NS.db.debugOther == false)) then
            NS.StopDebugDump()
            return
        end
        -- One-time API availability dump
        if not debugDumpedAPI then
            debugDumpedAPI = true
            local ac = NS.C_AssistedCombat
            NS.DebugPrintAlways("other", "--- |cFF44FF44API CHECK|r ---")
            NS.DebugPrintAlways("other", "C_AssistedCombat:", ac and "EXISTS" or "|cFFFF4444NIL|r")
            if ac then
                NS.DebugPrintAlways("other", "  .GetNextCastSpell:", ac.GetNextCastSpell and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("other", "  .GetActionSpell:", ac.GetActionSpell and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("other", "  .GetRotationSpells:", ac.GetRotationSpells and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("other", "  .IsAvailable:", ac.IsAvailable and "yes" or "|cFFFF4444no|r")
                if ac.IsAvailable then
                    local ok, avail = NS.pcall(ac.IsAvailable)
                    NS.DebugPrintAlways("other", "  .IsAvailable():", ok and NS.tostring(avail) or "ERROR")
                end
            end
            NS.DebugPrintAlways("other", "C_ActionBar.FindAssistedCombatActionButtons:",
                (NS.C_ActionBar and NS.C_ActionBar.FindAssistedCombatActionButtons) and "yes" or "|cFFFF4444no|r")
            NS.DebugPrintAlways("other", "SBA Spell ID:", NS.SBA_SPELL_ID)
            NS.DebugPrintAlways("other", "SBA Spell Name:", NS.GetSBASpellName())
        end
        -- Override keybind status (macro text is shown on actual clicks via PreClick)
        if NS._overrideKeys and #NS._overrideKeys > 0 then
            local keyStr = NS.table_concat(NS._overrideKeys, ", ")
            NS.DebugPrintAlways("Override: |cFF44FF44[" .. keyStr .. "]|r â†’ BetterSBA_MainButton (slot " .. (NS._overrideSlot or "?") .. ")")
            -- Verify WoW actually has our binding active
            if GetBindingAction then
                local action = GetBindingAction(NS._overrideKeys[1])
                if action and action:find("BetterSBA") then
                    NS.DebugPrintAlways("  Binding verified: |cFF44FF44" .. action .. "|r")
                else
                    NS.DebugPrintAlways("  |cFFFF4444Binding LOST|r: [" .. NS._overrideKeys[1] .. "] â†’ " .. (action or "nil"))
                end
            end
            -- Verify secure button is shown
            local sec = NS.secureButton
            if sec then
                NS.DebugPrintAlways("  SecureButton: " .. (sec:IsShown() and "|cFF44FF44shown|r" or "|cFFFF4444HIDDEN|r"))
            end
        else
            NS.DebugPrintAlways("Override: |cFFFF4444not active|r â€” keybind interception OFF")
        end

        if DebugChannelEnabled("spell") then
            NS.DebugPrintAlways("spell", "--- |cFF44FF44SPELL UPDATE|r ---")
            debugVerbose = true
            local spellID = NS.GetDisplaySpell()
            debugVerbose = false
            if spellID then
                local name = NS.C_Spell and NS.C_Spell.GetSpellName and NS.C_Spell.GetSpellName(spellID)
                NS.DebugPrintAlways("spell", "Display:", name or "?", "(ID:", spellID, ")")
            elseif NS._fallbackTexture then
                NS.DebugPrintAlways("spell", "Display: |cFFFFCC00fallback texture|r", NS._fallbackTexture)
            else
                NS.DebugPrintAlways("spell", "Display: |cFFFF4444nothing|r")
            end
        end
    end)
end

function NS.StopDebugDump()
    if debugDumpTicker then
        debugDumpTicker:Cancel()
        debugDumpTicker = nil
    end
    debugDumpedAPI = false
    debugVerbose = false
end
