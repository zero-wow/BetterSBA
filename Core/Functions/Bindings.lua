local ADDON_NAME, NS = ...

local sbaActionSlot = nil

function NS.FindSBAActionSlot()
    -- Use dedicated API if available (11.1.7+)
    if NS.C_ActionBar and NS.C_ActionBar.FindAssistedCombatActionButtons then
        local ok, slots = NS.pcall(NS.C_ActionBar.FindAssistedCombatActionButtons)
        if ok and slots and slots[1] then
            NS.DebugPrint("SBA slot via FindAssistedCombatActionButtons:", slots[1])
            sbaActionSlot = slots[1]
            return slots[1]
        end
    end
    -- Manual scan: match by spell ID
    local sbaName = NS.GetSBASpellName()
    for i = 1, 180 do
        local actionType, id = NS.GetActionInfo(i)
        if actionType == "spell" and id == NS.SBA_SPELL_ID then
            NS.DebugPrint("SBA slot via ID match:", i)
            sbaActionSlot = i
            return i
        end
        -- Also check by spell name (ID may differ between patches)
        if actionType == "spell" and id and NS.C_Spell and NS.C_Spell.GetSpellName then
            local name = NS.C_Spell.GetSpellName(id)
            if name and name == sbaName then
                NS.DebugPrint("SBA slot via name match:", i, "(ID:", id, ")")
                sbaActionSlot = i
                return i
            end
        end
    end
    -- Check if SBA might be stored as a different action type
    for i = 1, 180 do
        if HasAction(i) then
            local actionType, id = NS.GetActionInfo(i)
            if actionType and actionType ~= "spell" and id then
                local tex = GetActionTexture(i)
                local sbaIcon = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(NS.SBA_SPELL_ID)
                if tex and sbaIcon and tex == sbaIcon then
                    NS.DebugPrint("SBA slot via icon match:", i, "type:", actionType, "id:", id)
                    sbaActionSlot = i
                    return i
                end
            end
        end
    end
    NS.DebugPrint("|cFFFF4444SBA slot NOT FOUND|r on any action bar")
    sbaActionSlot = nil
    return nil
end

function NS.ClearSBASlotCache()
    sbaActionSlot = nil
end

function NS.GetCachedSBASlot()
    return sbaActionSlot
end


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

    -- ElvUI
    elseif _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        for bar = 1, 15 do
            for btn = 1, 12 do
                local elvBtn = _G["ElvUI_Bar" .. bar .. "Button" .. btn]
                if elvBtn then
                    local slot = elvBtn._state_action
                    if slot and type(slot) == "number" then
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

    -- Dominos
    elseif NS.C_AddOns.IsAddOnLoaded("Dominos") then
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

    -- Default Blizzard bars
    else
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

    -- ConsolePort (gamepad) keybind support: read bindings from ConsolePort's API
    if NS.C_AddOns.IsAddOnLoaded("ConsolePort") and _G["ConsolePort"] then
        local CP = _G["ConsolePort"]
        -- ConsolePort stores action bar bindings; scan them into our cache
        if CP.GetActionBinding then
            for i = 1, 180 do
                local actionType, id = NS.GetActionInfo(i)
                if actionType == "spell" and id and not keybindCache[id] then
                    local key = CP.GetActionBinding(i)
                    if key then
                        keybindCache[id] = NS.FormatKeybind(key)
                    end
                end
            end
        end
    end

    -- Class-specific bonus bar priority: certain specs use bonus/override bars
    -- (Druid forms, Rogue stealth, etc.). Scan the bonus bar (slots 73-84)
    -- with higher priority so form-specific keybinds are preferred.
    local bonusBarOffset = GetBonusBarOffset and GetBonusBarOffset() or 0
    if bonusBarOffset > 0 then
        local baseSlot = (bonusBarOffset + 5) * 12  -- bonus bars start at bar 7+
        for btnIdx = 1, 12 do
            local slot = baseSlot + btnIdx
            if slot <= 180 then
                local actionType, id = NS.GetActionInfo(slot)
                if actionType == "spell" and id then
                    -- Override with main bar keybind (bonus bar uses ACTIONBUTTON bindings)
                    local key = NS.GetBindingKey("ACTIONBUTTON" .. btnIdx)
                    if key then
                        keybindCache[id] = NS.FormatKeybind(key)
                    end
                end
            end
        end
    end

    -- ALWAYS update the SBA override â€” clear when mounted/vehicle,
    -- re-establish when on foot.  This must run regardless of which
    -- bar addon is active (the early-returns above were preventing it).
    NS.OverrideSBAKeybind()
    NS.UpdateClickIntercept()
end

function NS.GetKeybindForSpell(spellID)
    return keybindCache[spellID]
end

function NS.BuildBindingChord(key)
    if not key then return nil end
    key = key:upper()
    if key == "UNKNOWN"
        or key == "LSHIFT" or key == "RSHIFT"
        or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" then
        return nil
    end
    local binding = key
    if IsShiftKeyDown() then
        binding = "SHIFT-" .. binding
    end
    if IsControlKeyDown() then
        binding = "CTRL-" .. binding
    end
    if IsAltKeyDown() then
        binding = "ALT-" .. binding
    end
    return binding
end

----------------------------------------------------------------
-- SBA keybind override: redirect existing SBA keybind to our
-- secure button so targeting/petattack/channel protection work
-- even when the user presses their normal action bar keybind.
----------------------------------------------------------------
function NS.OverrideSBAKeybind()
    if NS.InCombatLockdown() then
        NS._pendingKeybindOverride = true
        return
    end

    local secure = NS.secureButton
    if not secure then return end

    local iType = NS.db and NS.db.interceptionType or "Keybind"
    if iType == "Click" then
        if NS._overrideKeys then
            ClearOverrideBindings(secure)
        end
        NS._overrideKeys = nil
        NS._overrideSlot = nil
        NS.UpdateKeybindStatus()
        return
    end

    -- If on a special bar, mounted, or in a vehicle, always clear our
    -- overrides so the bar's own keybinds work unimpeded.
    -- SBA is not usable on these bars / while mounted, so nothing to intercept.
    -- IsMounted() catches both regular mounts and skyriding transitions
    -- where HasBonusActionBar() may flicker.
    -- This check MUST happen before FindSBAActionSlot, because the API
    -- can return SBA's underlying slot even when a bonus bar is active.
    local onSpecialBar = (HasBonusActionBar and HasBonusActionBar())
        or (HasOverrideActionBar and HasOverrideActionBar())
        or (HasVehicleActionBar and HasVehicleActionBar())
        or (IsPossessBarVisible and IsPossessBarVisible())
        or (IsMounted and IsMounted())
    if onSpecialBar then
        if NS._overrideKeys then
            ClearOverrideBindings(secure)
        end
        NS._overrideKeys = nil
        NS._overrideSlot = nil
        NS.UpdateKeybindStatus()
        return
    end

    -- Find the SBA slot (only on normal action bars)
    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then
        NS.UpdateKeybindStatus()
        return
    end

    -- Collect keybinds for the slot
    local keys = {}

    -- Bartender4
    if _G["Bartender4"] then
        local key1, key2 = NS.GetBindingKey("CLICK BT4Button" .. slot .. ":Keybind")
        if key1 then keys[#keys + 1] = key1 end
        if key2 then keys[#keys + 1] = key2 end

    -- ElvUI
    elseif _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        for bar = 1, 15 do
            for btn = 1, 12 do
                local elvBtn = _G["ElvUI_Bar" .. bar .. "Button" .. btn]
                if elvBtn and elvBtn._state_action == slot then
                    local binding = elvBtn.bindstring or elvBtn.keyBoundTarget
                        or ("CLICK " .. elvBtn:GetName() .. ":LeftButton")
                    local key1, key2 = NS.GetBindingKey(binding)
                    if key1 then keys[#keys + 1] = key1 end
                    if key2 then keys[#keys + 1] = key2 end
                end
            end
        end

    -- Dominos / Default Blizzard bars
    else
        local barIndex = NS.math_floor((slot - 1) / 12)
        local btnIndex = ((slot - 1) % 12) + 1
        local bindingName = BINDING_BARS[barIndex + 1]
        if bindingName then
            bindingName = bindingName .. btnIndex
            local key1, key2 = NS.GetBindingKey(bindingName)
            if key1 then keys[#keys + 1] = key1 end
            if key2 then keys[#keys + 1] = key2 end
        end
    end

    if #keys == 0 then
        -- Slot found but no keybind â€” keep existing overrides if any
        if NS._overrideKeys and #NS._overrideKeys > 0 then
            return
        end
        NS.UpdateKeybindStatus()
        return
    end

    -- SUCCESS: we have slot + keys. NOW clear old overrides and set new ones.
    ClearOverrideBindings(secure)

    -- isPriority = true so we take precedence over Blizzard's action bar bindings
    for _, key in NS.ipairs(keys) do
        SetOverrideBindingClick(secure, true, key, "BetterSBA_MainButton", "LeftButton")
    end

    NS._overrideKeys = keys
    NS._overrideSlot = slot
    NS.UpdateKeybindStatus()

    -- Verify: check that WoW actually registered our override
    if GetBindingAction then
        local action = GetBindingAction(keys[1])
        if action and action:find("BetterSBA") then
            NS.DebugPrintAlways("|cFF44FF44Override verified|r: [" .. keys[1] .. "] â†’ " .. action)
        else
            NS.DebugPrintAlways("|cFFFF4444Override FAILED|r: [" .. keys[1] .. "] â†’ " .. (action or "nil") .. " (expected BetterSBA)")
        end
    end
end

-- Placeholder â€” Config.lua replaces this with the real updater
function NS.UpdateKeybindStatus()
    -- LDB text always updates even before Config panel is created
    if NS.UpdateLDBText then NS.UpdateLDBText() end
end

----------------------------------------------------------------
-- Click interception: overlay the SBA action bar button so
-- clicking it fires our macrotext instead of the raw spell.
----------------------------------------------------------------
local BAR_BUTTON_PREFIX = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

local function FindSBABarButton(slot)
    if not slot then return nil end

    if _G["Bartender4"] then
        return _G["BT4Button" .. slot]
    end

    if _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        for bar = 1, 15 do
            for btn = 1, 12 do
                local elvBtn = _G["ElvUI_Bar" .. bar .. "Button" .. btn]
                if elvBtn and elvBtn._state_action == slot then
                    return elvBtn
                end
            end
        end
        return nil
    end

    local barIndex = NS.math_floor((slot - 1) / 12)
    local btnIndex = ((slot - 1) % 12) + 1
    local prefix = BAR_BUTTON_PREFIX[barIndex + 1]
    if prefix then
        return _G[prefix .. btnIndex]
    end
    return nil
end

local clickOverlay = nil
local clickBorder = nil

local function ShowClickBorder(barBtn)
    if not clickBorder then
        clickBorder = NS.CreateFrame("Frame", nil, NS.UIParent, "BackdropTemplate")
        clickBorder:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        local sc = NS.db.sectionColorCombat or NS.defaults.sectionColorCombat
        clickBorder:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.8)
    end
    clickBorder:ClearAllPoints()
    clickBorder:SetPoint("TOPLEFT", barBtn, "TOPLEFT", -1, 1)
    clickBorder:SetPoint("BOTTOMRIGHT", barBtn, "BOTTOMRIGHT", 1, -1)
    clickBorder:SetFrameStrata(barBtn:GetFrameStrata())
    clickBorder:SetFrameLevel(barBtn:GetFrameLevel() + 4)
    clickBorder:Show()
end

local function HideClickBorder()
    if clickBorder then clickBorder:Hide() end
end

function NS.UpdateClickIntercept()
    if NS.InCombatLockdown() then
        NS._pendingClickIntercept = true
        return
    end

    local db = NS.db
    local iType = db and db.interceptionType or "Keybind"
    if not db or (iType ~= "Click" and iType ~= "Both") then
        if clickOverlay then
            clickOverlay:Hide()
            clickOverlay:ClearAllPoints()
        end
        HideClickBorder()
        return
    end

    local onSpecialBar = (HasBonusActionBar and HasBonusActionBar())
        or (HasOverrideActionBar and HasOverrideActionBar())
        or (HasVehicleActionBar and HasVehicleActionBar())
        or (IsPossessBarVisible and IsPossessBarVisible())
        or (IsMounted and IsMounted())
    if onSpecialBar then
        if clickOverlay then clickOverlay:Hide() end
        HideClickBorder()
        return
    end

    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then
        if clickOverlay then clickOverlay:Hide() end
        HideClickBorder()
        return
    end

    local barBtn = FindSBABarButton(slot)
    if not barBtn then
        if clickOverlay then clickOverlay:Hide() end
        HideClickBorder()
        return
    end

    if not clickOverlay then
        local ov = NS.CreateFrame("Button", "BetterSBA_ClickIntercept", NS.UIParent,
            "SecureActionButtonTemplate")
        ov:SetAttribute("type", "macro")
        ov:RegisterForClicks("AnyDown", "AnyUp")

        local ovName = ov:GetName()
        for _, suffix in NS.ipairs({"Icon", "Flash", "Count", "Border", "Name", "NewActionTexture", "HotKey"}) do
            local region = _G[ovName .. suffix]
            if region then
                if region.SetTexture then region:SetTexture(nil) end
                if region.SetText then region:SetText("") end
                region:Hide()
            end
        end
        local pushed = ov:GetPushedTexture()
        if pushed then pushed:SetAlpha(0) end
        local highlight = ov:GetHighlightTexture()
        if highlight then highlight:SetAlpha(0) end
        local normal = ov:GetNormalTexture()
        if normal then normal:SetAlpha(0) end

        ov:SetScript("OnEnter", function(self)
            local target = self._barBtn
            if target then
                local fn = target:GetScript("OnEnter")
                if fn then fn(target) end
            end
        end)
        ov:SetScript("OnLeave", function(self)
            local target = self._barBtn
            if target then
                local fn = target:GetScript("OnLeave")
                if fn then fn(target) end
            end
        end)

        clickOverlay = ov
    end

    clickOverlay:SetAttribute("macrotext", NS.BuildMacroText())
    clickOverlay._barBtn = barBtn
    clickOverlay:ClearAllPoints()
    clickOverlay:SetAllPoints(barBtn)
    clickOverlay:SetFrameStrata(barBtn:GetFrameStrata())
    clickOverlay:SetFrameLevel(barBtn:GetFrameLevel() + 5)
    clickOverlay:Show()
    ShowClickBorder(barBtn)
end
