local ADDON_NAME, NS = ...

local sbaActionSlot = nil

function NS.ClearSBASlotCache()
    sbaActionSlot = nil
end

function NS.GetCachedSBASlot()
    return sbaActionSlot
end


local keybindCache = {}
local missingKeybindScanQueued = false
local missingKeybindRequested = {}

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

local function GetBonusBarBaseSlot()
    local offset = GetBonusBarOffset and GetBonusBarOffset() or 0
    if offset <= 0 then return nil end
    return (offset + 5) * 12
end

local function GetTempShapeshiftBaseSlot()
    local index = GetTempShapeshiftBarIndex and GetTempShapeshiftBarIndex()
    if not index or index <= 0 then return nil end
    return (index - 1) * 12
end

local function HasActiveClassForm()
    if not GetNumShapeshiftForms or GetNumShapeshiftForms() <= 0 then
        return false
    end
    if GetShapeshiftForm and (GetShapeshiftForm() or 0) > 0 then
        return true
    end
    local formID = GetShapeshiftFormID and GetShapeshiftFormID()
    return formID ~= nil and formID > 0
end

function NS.IsFlightTravelFormActive()
    if not NS.IsClass or not NS.IsClass("DRUID") then
        return false
    end
    if not HasActiveClassForm() then
        return false
    end
    if not (IsFlying and IsFlying()) then
        return false
    end
    if NS.IsSkyridingActive then
        return NS.IsSkyridingActive()
    end
    return false
end

function NS.IsSkyridingActive()
    if not (IsFlying and IsFlying()) then
        return false
    end
    if GetBonusBarIndex and GetBonusBarOffset then
        local bonusBarIndex = GetBonusBarIndex()
        local bonusBarOffset = GetBonusBarOffset()
        if bonusBarIndex == 11 and bonusBarOffset == 5 then
            return true
        end
    end
    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
        if isGliding then
            return true
        end
        if canGlide and UnitPowerBarID and (UnitPowerBarID("player") or 0) ~= 0 then
            return true
        end
    end
    return false
end

function NS.GetFormActionBarBaseSlot()
    if UnitInVehicle and UnitInVehicle("player") then return nil end
    if HasVehicleActionBar and HasVehicleActionBar() then return nil end
    if HasOverrideActionBar and HasOverrideActionBar() then return nil end
    if IsPossessBarVisible and IsPossessBarVisible() then return nil end
    if NS.IsFlightTravelFormActive and NS.IsFlightTravelFormActive() then return nil end

    if HasBonusActionBar and HasBonusActionBar() and not (IsMounted and IsMounted()) then
        if HasActiveClassForm() then
            return GetBonusBarBaseSlot()
        end
    end

    if HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() then
        return GetTempShapeshiftBaseSlot()
    end

    return nil
end

function NS.IsInterceptBlocked()
    if UnitInVehicle and UnitInVehicle("player") then
        return true
    end
    if HasVehicleActionBar and HasVehicleActionBar() then
        return true
    end
    if HasOverrideActionBar and HasOverrideActionBar() then
        return true
    end
    if IsPossessBarVisible and IsPossessBarVisible() then
        return true
    end
    if NS.IsSkyridingActive and NS.IsSkyridingActive() then
        return true
    end
    if NS.IsFlightTravelFormActive and NS.IsFlightTravelFormActive() then
        return true
    end
    -- A normal ground mount can safely retain the SBA binding when the macro
    -- is configured to dismount first. Skyriding and replacement bars still
    -- use their own blocking checks.
    if IsMounted and IsMounted() and not (IsFlying and IsFlying())
        and not (NS.db and NS.db.enableDismount) then
        return true
    end
    if HasBonusActionBar and HasBonusActionBar() and not NS.GetFormActionBarBaseSlot() then
        return true
    end
    return false
end

local function IsSlotOnActiveFormBar(slot)
    local baseSlot = NS.GetFormActionBarBaseSlot and NS.GetFormActionBarBaseSlot()
    if not baseSlot or not slot then return false, nil, nil end

    local btnIndex = slot - baseSlot
    if btnIndex >= 1 and btnIndex <= 12 then
        return true, baseSlot, btnIndex
    end
    return false, baseSlot, nil
end

local function GetBindingKeysForSlot(slot)
    if not slot then return nil, nil end

    local onFormBar, _, btnIndex = IsSlotOnActiveFormBar(slot)
    if onFormBar then
        return NS.GetBindingKey("ACTIONBUTTON" .. btnIndex)
    end

    local barIndex = NS.math_floor((slot - 1) / 12)
    local bindingName = BINDING_BARS[barIndex + 1]
    if bindingName then
        local index = ((slot - 1) % 12) + 1
        return NS.GetBindingKey(bindingName .. index)
    end

    return nil, nil
end

local function FindSBAActionSlotInRange(startSlot, endSlot, sbaName, sbaIcon)
    for i = startSlot, endSlot do
        local actionType, id = NS.GetActionInfo(i)
        if actionType == "spell" and id == NS.SBA_SPELL_ID then
            NS.DebugPrint("SBA slot via ID match:", i)
            return i
        end
        if actionType == "spell" and id and sbaName and NS.C_Spell and NS.C_Spell.GetSpellName then
            local name = NS.C_Spell.GetSpellName(id)
            if name and name == sbaName then
                NS.DebugPrint("SBA slot via name match:", i, "(ID:", id, ")")
                return i
            end
        end
    end

    if sbaIcon then
        for i = startSlot, endSlot do
            if HasAction(i) then
                local actionType, id = NS.GetActionInfo(i)
                if actionType and actionType ~= "spell" and id then
                    local tex = GetActionTexture(i)
                    if tex == sbaIcon then
                        NS.DebugPrint("SBA slot via icon match:", i, "type:", actionType, "id:", id)
                        return i
                    end
                end
            end
        end
    end

    return nil
end

local function FindBT4ButtonForSlot(slot)
    if not slot then return nil end

    local direct = _G["BT4Button" .. slot]
    if direct then
        local action = direct.GetAttribute and direct:GetAttribute("action")
        if action == nil or action == slot or direct.action == slot or direct._state_action == slot then
            return direct
        end
    end

    for i = 1, 180 do
        local btn = _G["BT4Button" .. i]
        if btn then
            local action = btn.GetAttribute and btn:GetAttribute("action")
            if action == slot or btn.action == slot or btn._state_action == slot then
                return btn
            end
        end
    end

    return nil
end

local function FindElvUIButtonForSlot(slot)
    if not (_G["ElvUI"] and _G["ElvUI_Bar1Button1"]) then return nil end

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

local function IsEllesmereActionBarsActive()
    -- EllesmereUIActionBars creates EABButton frames instead of using Blizzard's
    -- ActionButton frames, which it keeps hidden beneath the custom bars.
    return _G["EABBar_MainBar"] ~= nil or _G["EABButton1"] ~= nil
end

local function FindEllesmereUIButtonForSlot(slot)
    if not slot or not IsEllesmereActionBarsActive() then return nil end
    -- EAB changes this secure attribute while paging. Do not inspect it in combat.
    if NS.InCombatLockdown() then return nil end

    local fallback
    for i = 1, 180 do
        local btn = _G["EABButton" .. i]
        if btn and btn.GetAttribute and btn:GetAttribute("action") == slot then
            if btn:IsVisible() and btn:IsMouseEnabled() then
                return btn
            end
            fallback = fallback or btn
        end
    end

    return fallback
end

local function ResetMissingKeybindRequests()
    missingKeybindRequested = {}
    missingKeybindScanQueued = false
end

local function ResolveFormattedKeybindForSlot(slot)
    if not slot then return nil end

    local key

    if IsEllesmereActionBarsActive() then
        local eabBtn = FindEllesmereUIButtonForSlot(slot)
        if eabBtn and eabBtn.commandName then
            key = NS.GetBindingKey(eabBtn.commandName)
        end
    elseif _G["Bartender4"] then
        local btBtn = FindBT4ButtonForSlot(slot)
        if btBtn then
            key = NS.GetBindingKey("CLICK " .. btBtn:GetName() .. ":Keybind")
        end
    elseif _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        local elvBtn = FindElvUIButtonForSlot(slot)
        if elvBtn then
            local binding = elvBtn.bindstring or elvBtn.keyBoundTarget
                or ("CLICK " .. elvBtn:GetName() .. ":LeftButton")
            key = NS.GetBindingKey(binding)
        end
    else
        key = GetBindingKeysForSlot(slot)
    end

    if not key and NS.C_AddOns.IsAddOnLoaded("ConsolePort") and _G["ConsolePort"] then
        local CP = _G["ConsolePort"]
        if CP.GetActionBinding then
            key = CP.GetActionBinding(slot)
        end
    end

    if key then
        return NS.FormatKeybind(key)
    end

    return nil
end

function NS.FindSBAActionSlot()
    local sbaName = NS.GetSBASpellName()
    local sbaIcon = NS.C_Spell and NS.C_Spell.GetSpellTexture
        and NS.C_Spell.GetSpellTexture(NS.SBA_SPELL_ID)

    local formBaseSlot = NS.GetFormActionBarBaseSlot and NS.GetFormActionBarBaseSlot()
    if formBaseSlot then
        local slot = FindSBAActionSlotInRange(formBaseSlot + 1, formBaseSlot + 12, sbaName, sbaIcon)
        if slot then
            sbaActionSlot = slot
            return slot
        end
        NS.DebugPrint("|cFFFF4444SBA slot NOT FOUND|r on active form bar")
        sbaActionSlot = nil
        return nil
    end

    -- Use dedicated API if available (11.1.7+)
    if NS.C_ActionBar and NS.C_ActionBar.FindAssistedCombatActionButtons then
        local ok, slots = NS.pcall(NS.C_ActionBar.FindAssistedCombatActionButtons)
        if ok and slots and slots[1] then
            NS.DebugPrint("SBA slot via FindAssistedCombatActionButtons:", slots[1])
            sbaActionSlot = slots[1]
            return slots[1]
        end
    end

    local slot = FindSBAActionSlotInRange(1, 180, sbaName, sbaIcon)
    if slot then
        sbaActionSlot = slot
        return slot
    end

    NS.DebugPrint("|cFFFF4444SBA slot NOT FOUND|r on any action bar")
    sbaActionSlot = nil
    return nil
end

function NS.ScanKeybinds()
    -- EAB's live action attributes are secure. Delay the entire scan until the
    -- first out-of-combat edge rather than reading them during combat.
    if IsEllesmereActionBarsActive() and NS.InCombatLockdown() then
        NS._pendingKeybindScan = true
        return
    end

    ResetMissingKeybindRequests()
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

    -- EllesmereUI Action Bars
    elseif IsEllesmereActionBarsActive() then
        for i = 1, 180 do
            local eabBtn = _G["EABButton" .. i]
            local slot = eabBtn and eabBtn:GetAttribute("action")
            local binding = eabBtn and eabBtn.commandName
            if slot and binding then
                local actionType, id = NS.GetActionInfo(slot)
                if actionType == "spell" and id and not keybindCache[id] then
                    local key = NS.GetBindingKey(binding)
                    if key then
                        keybindCache[id] = NS.FormatKeybind(key)
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

    -- Class-form action pages (druid forms, rogue stealth, temporary
    -- shapeshift pages, etc.) still use ACTIONBUTTON1-12 bindings.
    local baseSlot = NS.GetFormActionBarBaseSlot and NS.GetFormActionBarBaseSlot()
    if baseSlot then
        for btnIdx = 1, 12 do
            local slot = baseSlot + btnIdx
            if slot <= 180 then
                local actionType, id = NS.GetActionInfo(slot)
                if actionType == "spell" and id then
                    local key
                    if IsEllesmereActionBarsActive() then
                        local eabBtn = FindEllesmereUIButtonForSlot(slot)
                        if eabBtn and eabBtn.commandName then
                            key = NS.GetBindingKey(eabBtn.commandName)
                        end
                    elseif _G["Bartender4"] then
                        local btBtn = FindBT4ButtonForSlot(slot)
                        if btBtn then
                            key = NS.GetBindingKey("CLICK " .. btBtn:GetName() .. ":Keybind")
                        end
                    else
                        -- The currently paged main bar always uses ACTIONBUTTON bindings.
                        key = NS.GetBindingKey("ACTIONBUTTON" .. btnIdx)
                    end
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
    local key = keybindCache[spellID]
    if not key and spellID then
        NS.QueueMissingKeybindScan(spellID)
    end
    return key
end

function NS.ScanMissingKeybinds()
    if NS.InCombatLockdown() then
        NS._pendingMissingKeybindScan = true
        return false
    end

    if not next(missingKeybindRequested) then
        return false
    end

    local changed = false

    for slot = 1, 180 do
        local actionType, id = NS.GetActionInfo(slot)
        if actionType == "spell" and id and missingKeybindRequested[id] and not keybindCache[id] then
            local key = ResolveFormattedKeybindForSlot(slot)
            if key then
                keybindCache[id] = key
                missingKeybindRequested[id] = nil
                changed = true
            end
        end
    end

    if changed then
        if NS.UpdateNow then
            NS.UpdateNow()
        end
        if NS.UpdatePriorityDisplay then
            NS.UpdatePriorityDisplay()
        end
    end

    return changed
end

function NS.QueueMissingKeybindScan(spellID)
    if not spellID or keybindCache[spellID] or missingKeybindRequested[spellID] then
        return
    end

    missingKeybindRequested[spellID] = true

    if NS.InCombatLockdown() then
        NS._pendingMissingKeybindScan = true
        return
    end

    if missingKeybindScanQueued then
        return
    end

    missingKeybindScanQueued = true
    NS.C_Timer_After(0.05, function()
        missingKeybindScanQueued = false
        NS.ScanMissingKeybinds()
    end)
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
local function ClearSBAOverride(secure)
    if secure then
        ClearOverrideBindings(secure)
    end
    NS._overrideKeys = nil
    NS._overrideSlot = nil
    NS.UpdateKeybindStatus()
end

function NS.OverrideSBAKeybind()
    if NS.InCombatLockdown() then
        NS._pendingKeybindOverride = true
        return
    end

    local secure = NS.secureButton
    if not secure then return end

    local db = NS.db
    if not db or not db.enabled then
        ClearSBAOverride(secure)
        return
    end

    local iType = db.interceptionType or "Keybind"
    if iType == "Click" then
        ClearSBAOverride(secure)
        return
    end

    -- Pause only for true replacement bars (vehicle, possess, override,
    -- mount/skyriding, etc.). Class form pages remain interceptable.
    if NS.IsInterceptBlocked and NS.IsInterceptBlocked() then
        ClearSBAOverride(secure)
        return
    end

    -- Find the SBA slot on the active action page / form bar.
    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then
        -- The old hotkey may now belong to another action.  Never leave an
        -- override active after a stable no-slot result.
        ClearSBAOverride(secure)
        return
    end

    -- Collect keybinds for the slot
    local keys = {}

    -- EllesmereUI Action Bars
    if IsEllesmereActionBarsActive() then
        local eabBtn = FindEllesmereUIButtonForSlot(slot)
        if eabBtn and eabBtn.commandName then
            local key1, key2 = NS.GetBindingKey(eabBtn.commandName)
            if key1 then keys[#keys + 1] = key1 end
            if key2 then keys[#keys + 1] = key2 end
        end

    -- Bartender4
    elseif _G["Bartender4"] then
        local btBtn = FindBT4ButtonForSlot(slot)
        if btBtn then
            local binding = "CLICK " .. btBtn:GetName() .. ":Keybind"
            local key1, key2 = NS.GetBindingKey(binding)
            if key1 then keys[#keys + 1] = key1 end
            if key2 then keys[#keys + 1] = key2 end
        end

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
        local key1, key2 = GetBindingKeysForSlot(slot)
        if key1 then keys[#keys + 1] = key1 end
        if key2 then keys[#keys + 1] = key2 end
    end

    if #keys == 0 then
        -- UPDATE_BINDINGS may have removed or reassigned the old key.  Keeping
        -- our prior override here would hijack that newly assigned action.
        ClearSBAOverride(secure)
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

    if IsEllesmereActionBarsActive() then
        return FindEllesmereUIButtonForSlot(slot)
    end

    if _G["Bartender4"] then
        return FindBT4ButtonForSlot(slot)
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

    local onFormBar, _, btnIndex = IsSlotOnActiveFormBar(slot)
    if onFormBar then
        return _G["ActionButton" .. btnIndex]
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
local clickPressOverlay = nil
local CLICK_PRESS_DURATION = 0.09

function NS.GetClickInterceptSlot()
    if clickOverlay and clickOverlay:IsShown() then
        return clickOverlay._slot
    end
    return nil
end

local function HideClickInterceptOverlay(clearPoints)
    if not clickOverlay then return end
    local wasActive = clickOverlay:IsShown() or clickOverlay._slot ~= nil
    clickOverlay._slot = nil
    clickOverlay:Hide()
    if clearPoints then clickOverlay:ClearAllPoints() end
    if wasActive then NS.UpdateKeybindStatus() end
end

local function EnsureClickPressOverlay()
    if clickPressOverlay then return clickPressOverlay end
    local overlay = NS.CreateFrame("Frame", nil, NS.UIParent)
    overlay.tex = overlay:CreateTexture(nil, "ARTWORK")
    overlay.tex:SetColorTexture(0, 0, 0, 0.35)
    overlay.tex:SetAllPoints()
    overlay:Hide()
    clickPressOverlay = overlay
    return overlay
end

local function ClearClickPressVisual()
    if not clickPressOverlay then return end
    clickPressOverlay._pressUntil = nil
    clickPressOverlay._pressHeld = nil
    clickPressOverlay._pressStartedAt = nil
    clickPressOverlay:SetScript("OnUpdate", nil)
    clickPressOverlay:Hide()
end

local function ClickPressOnUpdate(self)
    if self._pressHeld then return end
    local untilTime = self._pressUntil
    if not untilTime or GetTime() >= untilTime then
        ClearClickPressVisual()
    end
end

-- Refresh both interception paths as one operation.  A combat-time refresh
-- records every required protected action so PLAYER_REGEN_ENABLED can apply a
-- coherent disabled or enabled state without touching secure frames in combat.
function NS.RefreshSBAInterception()
    if NS.InCombatLockdown() then
        NS._pendingKeybindScan = true
        NS._pendingKeybindOverride = true
        NS._pendingClickIntercept = true
        return false
    end
    NS.ScanKeybinds()
    return true
end

local function ResolveSBABarButton()
    if clickOverlay and clickOverlay._barBtn then
        return clickOverlay._barBtn
    end
    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then return nil end
    return FindSBABarButton(slot)
end

local function StartClickPressVisual(held)
    local barBtn = ResolveSBABarButton()
    if not barBtn then return end
    local overlay = EnsureClickPressOverlay()
    overlay:ClearAllPoints()
    overlay:SetAllPoints(barBtn)
    overlay:SetFrameStrata(barBtn:GetFrameStrata())
    overlay:SetFrameLevel(barBtn:GetFrameLevel() + 6)
    if held then
        overlay._pressHeld = true
        overlay._pressStartedAt = GetTime()
        overlay._pressUntil = nil
        overlay:SetScript("OnUpdate", nil)
    else
        overlay._pressHeld = nil
        overlay._pressStartedAt = nil
        overlay._pressUntil = GetTime() + CLICK_PRESS_DURATION
        overlay:SetScript("OnUpdate", ClickPressOnUpdate)
    end
    overlay:Show()
end

local function ReleaseClickPressVisual()
    if not clickPressOverlay or not clickPressOverlay._pressHeld then
        ClearClickPressVisual()
        return
    end
    local startedAt = clickPressOverlay._pressStartedAt or GetTime()
    local elapsed = GetTime() - startedAt
    local remaining = CLICK_PRESS_DURATION - elapsed
    clickPressOverlay._pressHeld = nil
    clickPressOverlay._pressStartedAt = nil
    if remaining > 0 then
        clickPressOverlay._pressUntil = GetTime() + remaining
        clickPressOverlay:SetScript("OnUpdate", ClickPressOnUpdate)
        clickPressOverlay:Show()
    else
        ClearClickPressVisual()
    end
end

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

function NS.StartInterceptBarPressVisual(held)
    StartClickPressVisual(held)
end

function NS.ReleaseInterceptBarPressVisual()
    ReleaseClickPressVisual()
end

function NS.ClearInterceptBarPressVisual()
    ClearClickPressVisual()
end

function NS.UpdateClickIntercept()
    if NS.InCombatLockdown() then
        NS._pendingClickIntercept = true
        return
    end

    local db = NS.db
    local iType = db and db.interceptionType or "Keybind"
    if not db or not db.enabled or (iType ~= "Click" and iType ~= "Both") then
        HideClickInterceptOverlay(true)
        HideClickBorder()
        ClearClickPressVisual()
        return
    end

    if NS.IsInterceptBlocked and NS.IsInterceptBlocked() then
        HideClickInterceptOverlay()
        HideClickBorder()
        ClearClickPressVisual()
        return
    end

    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then
        HideClickInterceptOverlay()
        HideClickBorder()
        ClearClickPressVisual()
        return
    end

    local barBtn = FindSBABarButton(slot)
    if not barBtn then
        HideClickInterceptOverlay()
        HideClickBorder()
        ClearClickPressVisual()
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
        ov:SetScript("OnMouseDown", function()
            StartClickPressVisual(true)
        end)
        ov:SetScript("OnMouseUp", function()
            ReleaseClickPressVisual()
        end)

        clickOverlay = ov
    end

    local slotChanged = clickOverlay._slot ~= slot
    clickOverlay:SetAttribute("macrotext", NS.BuildMacroText())
    clickOverlay._barBtn = barBtn
    clickOverlay._slot = slot
    clickOverlay:ClearAllPoints()
    clickOverlay:SetAllPoints(barBtn)
    clickOverlay:SetFrameStrata(barBtn:GetFrameStrata())
    clickOverlay:SetFrameLevel(barBtn:GetFrameLevel() + 5)
    clickOverlay:Show()
    ShowClickBorder(barBtn)
    if slotChanged then NS.UpdateKeybindStatus() end
end
