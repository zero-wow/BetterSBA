local ADDON_NAME, NS = ...

----------------------------------------------------------------
-- Taint-safe comparison helpers.  WoW's taint system makes
-- C_Spell cooldown fields "secret numbers" that throw errors on
-- Lua comparison operators (>, <, <=).  Wrapping in pcall lets
-- us safely compare — if tainted, pcall returns false and we
-- fall through to a safe default.  Pre-defined functions avoid
-- per-call closure garbage.
----------------------------------------------------------------
local function _durGT(cdInfo, threshold)
    return (cdInfo.duration or 0) > threshold
end
local function _durLE(cdInfo, threshold)
    return (cdInfo.duration or 0) <= threshold
end
NS._durGT = _durGT

----------------------------------------------------------------
-- Debug output
----------------------------------------------------------------
local DEBUG_PREFIX = "|cFF66B8D9[BetterSBA Debug]|r "
local debugVerbose = false  -- toggled on for periodic dumps

function NS.DebugPrint(...)
    if not NS.db or not NS.db.debug then return end
    -- Pipeline debug only prints during verbose windows
    if not debugVerbose then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = NS.tostring(select(i, ...))
    end
    print(DEBUG_PREFIX .. NS.table_concat(parts, " "))
end

-- Always print (for click events and important messages)
function NS.DebugPrintAlways(...)
    if not NS.db or not NS.db.debug then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = NS.tostring(select(i, ...))
    end
    print(DEBUG_PREFIX .. NS.table_concat(parts, " "))
end

-- Periodic debug dump: runs one verbose update every 3 seconds
local debugDumpTicker = nil
local debugDumpedAPI = false

function NS.StartDebugDump()
    if debugDumpTicker then return end
    debugDumpTicker = C_Timer.NewTicker(3, function()
        if not NS.db or not NS.db.debug then
            NS.StopDebugDump()
            return
        end
        -- One-time API availability dump
        if not debugDumpedAPI then
            debugDumpedAPI = true
            local ac = NS.C_AssistedCombat
            NS.DebugPrintAlways("--- |cFF44FF44API CHECK|r ---")
            NS.DebugPrintAlways("C_AssistedCombat:", ac and "EXISTS" or "|cFFFF4444NIL|r")
            if ac then
                NS.DebugPrintAlways("  .GetNextCastSpell:", ac.GetNextCastSpell and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("  .GetActionSpell:", ac.GetActionSpell and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("  .GetRotationSpells:", ac.GetRotationSpells and "yes" or "|cFFFF4444no|r")
                NS.DebugPrintAlways("  .IsAvailable:", ac.IsAvailable and "yes" or "|cFFFF4444no|r")
                if ac.IsAvailable then
                    local ok, avail = NS.pcall(ac.IsAvailable)
                    NS.DebugPrintAlways("  .IsAvailable():", ok and NS.tostring(avail) or "ERROR")
                end
            end
            NS.DebugPrintAlways("C_ActionBar.FindAssistedCombatActionButtons:",
                (NS.C_ActionBar and NS.C_ActionBar.FindAssistedCombatActionButtons) and "yes" or "|cFFFF4444no|r")
            NS.DebugPrintAlways("SBA Spell ID:", NS.SBA_SPELL_ID)
            NS.DebugPrintAlways("SBA Spell Name:", NS.GetSBASpellName())
        end
        -- Override keybind status (macro text is shown on actual clicks via PreClick)
        if NS._overrideKeys and #NS._overrideKeys > 0 then
            local keyStr = NS.table_concat(NS._overrideKeys, ", ")
            NS.DebugPrintAlways("Override: |cFF44FF44[" .. keyStr .. "]|r → BetterSBA_MainButton (slot " .. (NS._overrideSlot or "?") .. ")")
            -- Verify WoW actually has our binding active
            if GetBindingAction then
                local action = GetBindingAction(NS._overrideKeys[1])
                if action and action:find("BetterSBA") then
                    NS.DebugPrintAlways("  Binding verified: |cFF44FF44" .. action .. "|r")
                else
                    NS.DebugPrintAlways("  |cFFFF4444Binding LOST|r: [" .. NS._overrideKeys[1] .. "] → " .. (action or "nil"))
                end
            end
            -- Verify secure button is shown
            local sec = NS.secureButton
            if sec then
                NS.DebugPrintAlways("  SecureButton: " .. (sec:IsShown() and "|cFF44FF44shown|r" or "|cFFFF4444HIDDEN|r"))
            end
        else
            NS.DebugPrintAlways("Override: |cFFFF4444not active|r — keybind interception OFF")
        end

        -- Run one verbose update cycle
        NS.DebugPrintAlways("--- |cFF44FF44SPELL UPDATE|r ---")
        debugVerbose = true
        local spellID = NS.GetDisplaySpell()
        debugVerbose = false
        if spellID then
            local name = NS.C_Spell and NS.C_Spell.GetSpellName and NS.C_Spell.GetSpellName(spellID)
            NS.DebugPrintAlways("Display:", name or "?", "(ID:", spellID, ")")
        elseif NS._fallbackTexture then
            NS.DebugPrintAlways("Display: |cFFFFCC00fallback texture|r", NS._fallbackTexture)
        else
            NS.DebugPrintAlways("Display: |cFFFF4444nothing|r")
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

----------------------------------------------------------------
-- Masque integration
----------------------------------------------------------------
function NS.InitMasque()
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return end
    NS.masque = MSQ
    NS.masqueMainGroup = MSQ:Group("BetterSBA", "Main Button")
    NS.masqueQueueGroup = MSQ:Group("BetterSBA", "Rotation")
    NS.masqueAnimGroup = MSQ:Group("BetterSBA", "Animated Button")
end

function NS.MasqueReSkin()
    if NS.masqueMainGroup then NS.masqueMainGroup:ReSkin() end
    if NS.masqueQueueGroup then NS.masqueQueueGroup:ReSkin() end
    if NS.masqueAnimGroup then NS.masqueAnimGroup:ReSkin() end
end

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
-- SBA action bar slot scanning
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Caching: eliminates redundant API calls and garbage table creation.
--
-- CollectRotationSpells: EVENT-DRIVEN cache. The rotation pool only
-- changes on RotationSpellsUpdated / SPELLS_CHANGED / spec change.
-- Without this, GetRotationSpells() returns a NEW table every call
-- → 30-50 garbage tables/sec → 20+ MB/hour of GC pressure.
--
-- CollectNextSpell: PER-FRAME cache. Called 2-3× within a single
-- UpdateNow tick. Refreshes once per tick, cached within the tick.
----------------------------------------------------------------
local EMPTY_TABLE = {}          -- singleton empty table (never modify!)
local CACHE_NIL = {}            -- sentinel for "we cached nil"
local updateGeneration = 0      -- incremented once per UpdateNow call
local cachedNextSpell = nil
local cachedNextGen = -1
local cachedRotation = nil
local rotationDirty = true      -- event-driven: only refresh when dirty

----------------------------------------------------------------
-- Per-tick cooldown cache: C_Spell.GetSpellCooldown returns a
-- NEW table on every call (~200 bytes).  With 15-20 calls per
-- 0.1s tick that is 30-40 KB/sec of pure API garbage.  Caching
-- within a single tick eliminates redundant API calls (same
-- spell queried in GetDisplaySpell, UpdateButton, and
-- UpdateQueueDisplay).  The table is wiped in BeginUpdate().
--
-- TAINT FIX: We capture GetSpellCooldown as a file-local at
-- load time.  Looking it up through NS.C_Spell taints the
-- function reference (NS becomes tainted once we touch secure
-- frames), which taints every return value, making comparisons
-- on duration/startTime throw "secret number" errors.  A clean
-- local captured at file load time is never tainted.
----------------------------------------------------------------
local cdTickCache = {}

-- Clean (untainted) references captured at file load time
local _GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown

function NS.GetCooldownCached(spellID)
    local cached = cdTickCache[spellID]
    if cached then
        if cached == CACHE_NIL then return nil end
        return cached
    end
    if not _GetSpellCooldown then return nil end
    -- Call through clean local — return values are untainted
    local ok, cdInfo = pcall(_GetSpellCooldown, spellID)
    if ok and cdInfo then
        cdTickCache[spellID] = cdInfo
        return cdInfo
    end
    cdTickCache[spellID] = CACHE_NIL
    return nil
end

----------------------------------------------------------------
-- GC management: WoW's default Lua GC uses pause=200 (waits
-- until memory DOUBLES before starting a new cycle) and
-- stepmul=200.  For an addon generating ~30-40KB/sec of
-- unavoidable API garbage (C_Spell.GetSpellCooldown tables,
-- etc.), this lets memory climb to 10 MB+ before a single
-- massive collection stall.
--
-- Fix: tune the auto-collector to be far more aggressive so it
-- collects continuously in tiny bites instead of one big stall.
--   pause=110  → start a new GC cycle when memory grows just 10%
--   stepmul=400 → each auto-step does 2× more work than default
-- This keeps memory nearly flat with zero perceptible cost.
----------------------------------------------------------------
function NS.StartGCTicker()
    -- Tune the automatic collector to be more aggressive than default.
    collectgarbage("setpause", 110)
    collectgarbage("setstepmul", 400)
    -- GC work is spread across every BeginUpdate() tick (every 0.1s)
    -- via a tiny step(50) call — see BeginUpdate() below.  This
    -- distributes GC evenly with zero perceptible cost, unlike a
    -- periodic large step or full collect that causes frame stutters.
end

function NS.StopGCTicker()
    collectgarbage("setpause", 200)
    collectgarbage("setstepmul", 200)
end

function NS.BeginUpdate()
    updateGeneration = updateGeneration + 1
    -- Wipe per-tick cooldown cache (reuse the same table, zero garbage)
    wipe(cdTickCache)
    -- GC nudge every tick (0.1s).  With all per-frame animations removed,
    -- step(500) is safe — no visible stutter, keeps memory flat.
    collectgarbage("step", 500)
end

-- Call this from event handlers that change the rotation pool
function NS.InvalidateRotationCache()
    rotationDirty = true
end

----------------------------------------------------------------
-- Spell collection (three-tier fallback + action bar)
----------------------------------------------------------------
function NS.CollectNextSpell()
    -- Return cached result if called multiple times in the same frame
    if cachedNextGen == updateGeneration then
        if cachedNextSpell == CACHE_NIL then return nil end
        return cachedNextSpell
    end

    local ac = NS.C_AssistedCombat
    if not ac then
        NS.DebugPrint("|cFFFF4444C_AssistedCombat is nil|r")
        cachedNextSpell = CACHE_NIL
        cachedNextGen = updateGeneration
        return nil
    end

    -- GetNextCastSpell WITHOUT visible check first — our button isn't
    -- registered via SetActionUIButton so the visible check would fail
    if ac.GetNextCastSpell then
        local ok, sid = NS.pcall(ac.GetNextCastSpell, false)
        if ok and sid and sid ~= 0 then
            NS.DebugPrint("GetNextCastSpell(false) →", sid)
            cachedNextSpell = sid
            cachedNextGen = updateGeneration
            return sid
        end
        NS.DebugPrint("GetNextCastSpell(false):", ok and ("returned " .. NS.tostring(sid)) or "ERROR")
    else
        NS.DebugPrint("|cFFFF4444GetNextCastSpell does not exist|r")
    end

    -- GetActionSpell: the current "action spell" set by the system
    if ac.GetActionSpell then
        local ok, sid = NS.pcall(ac.GetActionSpell)
        if ok and sid and sid ~= 0 then
            NS.DebugPrint("GetActionSpell() →", sid)
            cachedNextSpell = sid
            cachedNextGen = updateGeneration
            return sid
        end
        NS.DebugPrint("GetActionSpell():", ok and ("returned " .. NS.tostring(sid)) or "ERROR")
    else
        NS.DebugPrint("|cFFFF4444GetActionSpell does not exist|r")
    end

    -- GetNextCastSpell WITH visible check — works if SBA is on a Blizzard bar
    if ac.GetNextCastSpell then
        local ok, sid = NS.pcall(ac.GetNextCastSpell, true)
        if ok and sid and sid ~= 0 then
            NS.DebugPrint("GetNextCastSpell(true) →", sid)
            cachedNextSpell = sid
            cachedNextGen = updateGeneration
            return sid
        end
        NS.DebugPrint("GetNextCastSpell(true):", ok and ("returned " .. NS.tostring(sid)) or "ERROR")
    end

    -- Last resort: first rotation spell (uses cached rotation if available)
    local spells = NS.CollectRotationSpells()
    if spells[1] and spells[1] ~= 0 then
        NS.DebugPrint("Rotation spell fallback →", spells[1])
        cachedNextSpell = spells[1]
        cachedNextGen = updateGeneration
        return spells[1]
    end

    cachedNextSpell = CACHE_NIL
    cachedNextGen = updateGeneration
    return nil
end

function NS.CollectRotationSpells()
    -- Event-driven cache: only call the API when rotation actually changed
    if not rotationDirty and cachedRotation then
        return cachedRotation
    end
    rotationDirty = false
    local ac = NS.C_AssistedCombat
    if not ac or not ac.GetRotationSpells then
        cachedRotation = EMPTY_TABLE
        return EMPTY_TABLE
    end
    local ok, spells = NS.pcall(ac.GetRotationSpells)
    if ok and spells then
        cachedRotation = spells
    else
        cachedRotation = EMPTY_TABLE
    end
    return cachedRotation
end

----------------------------------------------------------------
-- Macro text builder
----------------------------------------------------------------
function NS.BuildMacroText()
    local lines = {}
    local db = NS.db

    if db.enableDismount then
        NS.table_insert(lines, "/dismount [mounted]")
    end

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
    if NS.secureButton then
        NS.secureButton:SetAttribute("macrotext", NS.BuildMacroText())
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

    -- Override the SBA keybind to redirect through our button
    NS.OverrideSBAKeybind()
end

function NS.GetKeybindForSpell(spellID)
    return keybindCache[spellID]
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

    -- If on a special bar (skyriding, vehicle, override, possess), always
    -- clear our overrides so the bar's own keybinds work unimpeded.
    -- SBA is not usable on these bars, so there's nothing to intercept.
    -- This check MUST happen before FindSBAActionSlot, because the API
    -- can return SBA's underlying slot even when a bonus bar is active.
    local onSpecialBar = HasBonusActionBar and HasBonusActionBar()
        or HasOverrideActionBar and HasOverrideActionBar()
        or HasVehicleActionBar and HasVehicleActionBar()
        or IsPossessBarVisible and IsPossessBarVisible()
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
        -- Slot found but no keybind — keep existing overrides if any
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
            NS.DebugPrintAlways("|cFF44FF44Override verified|r: [" .. keys[1] .. "] → " .. action)
        else
            NS.DebugPrintAlways("|cFFFF4444Override FAILED|r: [" .. keys[1] .. "] → " .. (action or "nil") .. " (expected BetterSBA)")
        end
    end
end

-- Placeholder — Config.lua replaces this with the real updater
function NS.UpdateKeybindStatus()
    -- LDB text always updates even before Config panel is created
    if NS.UpdateLDBText then NS.UpdateLDBText() end
end

----------------------------------------------------------------
-- Font system (LibSharedMedia with fallback)
----------------------------------------------------------------
local DEFAULT_FONTS = {
    ["Friz Quadrata TT"]  = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"]      = "Fonts\\ARIALN.TTF",
    ["Morpheus"]          = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]            = "Fonts\\SKURRI.TTF",
    ["2002"]              = "Fonts\\2002.TTF",
    ["2002 Bold"]         = "Fonts\\2002B.TTF",
}
local DEFAULT_FONT_ORDER = { "Friz Quadrata TT", "Arial Narrow", "Morpheus", "Skurri", "2002", "2002 Bold" }

function NS.GetFontPath(fontName)
    fontName = fontName or (NS.db and NS.db.fontFace) or "Friz Quadrata TT"
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return DEFAULT_FONTS[fontName] or "Fonts\\FRIZQT__.TTF"
end

function NS.GetFontList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then return LSM:List("font") end
    return DEFAULT_FONT_ORDER
end

----------------------------------------------------------------
-- Font outline helper
----------------------------------------------------------------
-- Outline display names → WoW SetFont flags
NS.FONT_OUTLINE_OPTIONS = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "MONO OUTLINE", "MONO THICKOUTLINE" }

local OUTLINE_MAP = {
    ["NONE"]               = "",
    ["OUTLINE"]            = "OUTLINE",
    ["THICKOUTLINE"]       = "THICKOUTLINE",
    ["MONOCHROME"]         = "MONOCHROME",
    ["MONO OUTLINE"]       = "MONOCHROME, OUTLINE",
    ["MONO THICKOUTLINE"]  = "MONOCHROME, THICKOUTLINE",
}

function NS.GetOutlineFlags(outlineSetting)
    outlineSetting = outlineSetting or "OUTLINE"
    return OUTLINE_MAP[outlineSetting] or outlineSetting
end

function NS.GetFontOutline()
    return NS.GetOutlineFlags(NS.db and NS.db.fontOutline or "OUTLINE")
end

function NS.GetConfigFontPath()
    local db = NS.db
    if db and db.configPanelFontOverride and db.configPanelFont then
        return NS.GetFontPath(db.configPanelFont)
    end
    return NS.GetFontPath(db and db.fontFace)
end

function NS.GetConfigFontOutline()
    local db = NS.db
    if db and db.configPanelFontOverride then
        return NS.GetOutlineFlags(db.configPanelOutline or "")
    end
    return NS.GetOutlineFlags(db and db.fontOutline or "OUTLINE")
end

-- Update all config panel fonts in-place (no rebuild needed)
function NS.UpdateAllConfigFonts()
    local f = NS.Config and NS.Config.frame
    if not f then return end
    local path = NS.GetConfigFontPath()
    local outline = NS.GetConfigFontOutline()
    local function WalkFrame(frame)
        -- FontStrings are regions, not children
        local regions = { frame:GetRegions() }
        for _, region in NS.ipairs(regions) do
            if region.IsObjectType and region:IsObjectType("FontString") then
                local curPath, size = region:GetFont()
                if size and curPath then
                    region:SetFont(path, size, outline)
                end
            end
        end
        -- Recurse into child frames
        local children = { frame:GetChildren() }
        for _, child in NS.ipairs(children) do
            WalkFrame(child)
        end
    end
    WalkFrame(f)
end

-- Resolve font path: context-specific if override enabled, else global fallback
function NS.ResolveFontPath(contextFontKey)
    local db = NS.db
    if not db then return NS.GetFontPath() end
    if db[contextFontKey .. "Override"] then
        return NS.GetFontPath(db[contextFontKey])
    end
    return NS.GetFontPath(db.fontFace)
end

-- Resolve font outline: context-specific if override enabled, else global fallback
function NS.ResolveFontOutline(contextFontKey, contextOutlineKey)
    local db = NS.db
    if not db then return NS.GetFontOutline() end
    if db[contextFontKey .. "Override"] then
        return NS.GetOutlineFlags(db[contextOutlineKey])
    end
    return NS.GetOutlineFlags(db.fontOutline)
end

----------------------------------------------------------------
-- Spell importance classification (base cooldown cache)
----------------------------------------------------------------
local baseCDCache = {}
local baseCDCacheCount = 0
local MAX_CD_CACHE = 200  -- cap to prevent unbounded growth

function NS.ClearBaseCDCache()
    baseCDCache = {}
    baseCDCacheCount = 0
end

function NS.GetSpellBaseCooldown(spellID)
    if not spellID or spellID == 0 then return 0 end
    if baseCDCache[spellID] then return baseCDCache[spellID] end

    -- Evict cache if it's grown too large (shouldn't happen normally)
    if baseCDCacheCount >= MAX_CD_CACHE then
        baseCDCache = {}
        baseCDCacheCount = 0
    end

    -- Try C_Spell.GetSpellBaseCooldown (11.0+ namespaced API, returns ms)
    if NS.C_Spell and NS.C_Spell.GetSpellBaseCooldown then
        local ok, ms = NS.pcall(NS.C_Spell.GetSpellBaseCooldown, spellID)
        if ok and ms then
            ms = tonumber(ms) or 0
            if ms > 0 then
                local sec = ms / 1000
                baseCDCache[spellID] = sec
                baseCDCacheCount = baseCDCacheCount + 1
                return sec
            end
        end
    end

    -- Try global GetSpellBaseCooldown (older API, returns baseCooldownMS, gcdMS)
    if GetSpellBaseCooldown then
        local ok, baseCDms = NS.pcall(GetSpellBaseCooldown, spellID)
        if ok and baseCDms then
            baseCDms = tonumber(baseCDms) or 0
            if baseCDms > 0 then
                local sec = baseCDms / 1000
                baseCDCache[spellID] = sec
                baseCDCacheCount = baseCDCacheCount + 1
                return sec
            end
        end
    end

    -- Fallback: observe current cooldown duration
    if NS.C_Spell and NS.C_Spell.GetSpellCooldown then
        local cdInfo = NS.GetCooldownCached(spellID)
        if cdInfo then
            -- pcall guards against tainted "secret number" comparisons
            local ok, isLong = pcall(_durGT, cdInfo, 1.5)
            if ok and isLong then
                local dur = tonumber(cdInfo.duration) or 0
                baseCDCache[spellID] = dur
                baseCDCacheCount = baseCDCacheCount + 1
                return dur
            end
        end
    end

    -- Don't cache zero — retry next time
    return 0
end

function NS.GetSpellImportanceKey(spellID)
    if not spellID or spellID == 0 then return "FILLER" end
    if spellID == NS.AUTO_ATTACK_SPELL_ID then return "AUTO_ATTACK" end

    local cd = NS.GetSpellBaseCooldown(spellID)
    if cd <= 10 then return "FILLER" end
    if cd <= 30 then return "SHORT_CD" end
    if cd <= 120 then return "LONG_CD" end
    return "MAJOR_CD"
end

-- Map importance key → db color key
local IMPORT_DB_KEYS = {
    AUTO_ATTACK = "importColorAutoAttack",
    FILLER      = "importColorFiller",
    SHORT_CD    = "importColorShortCD",
    LONG_CD     = "importColorLongCD",
    MAJOR_CD    = "importColorMajorCD",
}

function NS.GetSpellBorderColor(spellID)
    local key = NS.GetSpellImportanceKey(spellID)
    -- Read from user-configurable DB, fallback to hardcoded
    local dbKey = IMPORT_DB_KEYS[key]
    if dbKey and NS.db and NS.db[dbKey] then
        return NS.db[dbKey]
    end
    return NS.SPELL_IMPORTANCE[key]
end

function NS.GetSpellBorderColorBright(spellID)
    local key = NS.GetSpellImportanceKey(spellID)
    return NS.SPELL_IMPORTANCE_BRIGHT[key]
end

----------------------------------------------------------------
-- Action bar texture fallback: read what Blizzard is showing
----------------------------------------------------------------
function NS.GetDisplaySpellFromActionBar()
    local slot = sbaActionSlot or NS.FindSBAActionSlot()
    if not slot then
        NS.DebugPrint("ActionBar fallback: |cFFFF4444no SBA slot|r")
        return nil, nil
    end

    local tex = GetActionTexture(slot)
    if not tex then
        NS.DebugPrint("ActionBar fallback: slot", slot, "has |cFFFF4444no texture|r")
        return nil, nil
    end

    NS.DebugPrint("ActionBar slot", slot, "texture:", tex)

    -- Match texture against rotation spells to find the spell ID
    local rotationSpells = NS.CollectRotationSpells()
    for idx = 1, #rotationSpells do
        local sid = rotationSpells[idx]
        if sid and sid ~= 0 then
            local spellTex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(sid)
            if spellTex and spellTex == tex then
                NS.DebugPrint("ActionBar texture matched spell", sid)
                return sid, tex
            end
        end
    end

    NS.DebugPrint("ActionBar texture matched |cFFFF4444no rotation spell|r — using raw texture")
    -- No spell ID match, return just the texture
    return nil, tex
end

----------------------------------------------------------------
-- Display spell (auto-attack fallback when recommended is on CD)
----------------------------------------------------------------
function NS.GetDisplaySpell()
    local recommended = NS.CollectNextSpell()

    -- Fallback: try reading the action bar directly
    if not recommended or recommended == 0 then
        NS.DebugPrint("API returned nothing — trying action bar fallback")
        local abSpell, abTex = NS.GetDisplaySpellFromActionBar()
        if abSpell then
            recommended = abSpell
        elseif abTex then
            -- Have action bar texture but couldn't match spell ID
            NS._fallbackTexture = abTex
            return nil
        end
    end

    -- Nothing recommended → auto-attack
    if not recommended or recommended == 0 then
        NS._fallbackTexture = nil
        NS.DebugPrint("Final result: |cFFFF4444auto-attack fallback|r")
        return NS.AUTO_ATTACK_SPELL_ID
    end

    NS._fallbackTexture = nil

    -- Check if recommended is on a real cooldown (uses per-tick cache
    -- to avoid creating a new API table on every call).
    -- pcall guards all comparisons — cdInfo fields may be tainted
    -- "secret numbers" in WoW's secure execution context.
    local cdInfo = NS.GetCooldownCached(recommended)
    if cdInfo then
        local ok, isLongCD = pcall(_durGT, cdInfo, 1.5)
        if ok and isLongCD then
            -- Recommended is on CD, look for a ready rotation spell
            local rotationSpells = NS.CollectRotationSpells()
            for idx = 1, #rotationSpells do
                local sid = rotationSpells[idx]
                if sid and sid ~= 0 and sid ~= recommended then
                    local cdInfo2 = NS.GetCooldownCached(sid)
                    if cdInfo2 then
                        local ok2, isReady = pcall(_durLE, cdInfo2, 1.5)
                        if ok2 and isReady then
                            return sid
                        end
                    end
                end
            end
            -- Nothing ready → auto-attack
            return NS.AUTO_ATTACK_SPELL_ID
        end
    end

    return recommended
end

----------------------------------------------------------------
-- Cast animation system (multiple animation types)
----------------------------------------------------------------
local animPool = {}

local ANIM_CONFIGS = {
    DRIFT = function(ag)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.3, 0.3); s:SetDuration(0.8); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(-80, -15); t:SetDuration(0.8); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(0.8); a:SetSmoothing("IN"); a:SetStartDelay(0.05)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    PULSE = function(ag)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(2.0, 2.0); s:SetDuration(0.45); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(0.45); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SPIN = function(ag)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.15, 0.15); s:SetDuration(0.7); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(0.7); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(360); r:SetDuration(0.7); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
    ZOOM = function(ag)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(3.5, 3.5); s:SetDuration(0.55); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 25); t:SetDuration(0.55); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(0.55); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SLAM = function(ag)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1.6, 1.6); s:SetDuration(0.12); s:SetSmoothing("IN_OUT"); s:SetStartDelay(0)
        t:SetOffset(0, -40); t:SetDuration(0.5); t:SetSmoothing("IN"); t:SetStartDelay(0.12)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(0.5); a:SetSmoothing("IN"); a:SetStartDelay(0.12)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
}

----------------------------------------------------------------
-- Hidden reference button for Masque "Animated Button" group
----------------------------------------------------------------
local animRefButton

local function EnsureAnimRefButton()
    if animRefButton or not NS.masqueAnimGroup then return end

    local ref = NS.CreateFrame("Button", nil, NS.UIParent)
    ref:SetSize(36, 36)
    ref:SetPoint("CENTER")
    ref:Hide()

    ref.icon = ref:CreateTexture(nil, "ARTWORK")
    ref.icon:SetAllPoints()

    local normalTex = ref:CreateTexture()
    normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    normalTex:SetSize(36 * 1.7, 36 * 1.7)
    normalTex:SetPoint("CENTER")
    ref:SetNormalTexture(normalTex)

    local pushedTex = ref:CreateTexture()
    pushedTex:SetColorTexture(0, 0, 0, 0.5)
    pushedTex:SetAllPoints(ref.icon)
    ref:SetPushedTexture(pushedTex)

    local hlTex = ref:CreateTexture()
    hlTex:SetColorTexture(1, 1, 1, 0.15)
    hlTex:SetAllPoints(ref.icon)
    ref:SetHighlightTexture(hlTex)

    local flashTex = ref:CreateTexture(nil, "OVERLAY")
    flashTex:SetColorTexture(1, 0, 0, 0.3)
    flashTex:SetAllPoints(ref.icon)
    flashTex:Hide()
    ref.Flash = flashTex

    local borderTex = ref:CreateTexture(nil, "OVERLAY")
    borderTex:SetAllPoints(ref.icon)
    borderTex:Hide()
    ref.Border = borderTex

    NS.masqueAnimGroup:AddButton(ref, {
        Icon = ref.icon,
        Normal = normalTex,
        Pushed = pushedTex,
        Highlight = hlTex,
        Flash = flashTex,
        Border = borderTex,
    })

    animRefButton = ref
end

local MAX_ANIM_POOL = 10  -- cap to prevent unbounded frame creation

local function AcquireAnimFrame()
    for _, f in NS.ipairs(animPool) do
        if not f._inUse then
            f._inUse = true
            return f
        end
    end

    -- Pool full — recycle the oldest frame
    if #animPool >= MAX_ANIM_POOL then
        local oldest = animPool[1]
        if oldest.ag then oldest.ag:Stop() end
        oldest:Hide()
        oldest:ClearAllPoints()
        oldest._inUse = true
        return oldest
    end

    local f = NS.CreateFrame("Button", nil, NS.UIParent, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:Hide()
    f:EnableMouse(false)  -- don't intercept clicks during animation

    f.icon = f:CreateTexture(nil, "ARTWORK")
    if NS.masque then
        f.icon:SetAllPoints()
    else
        f.icon:SetAllPoints()
        f.icon:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))
    end

    -- Register with Masque animated button group
    if NS.masqueAnimGroup then
        local size = NS.db.buttonSize or 48

        local normalTex = f:CreateTexture()
        normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normalTex:SetSize(size * 1.7, size * 1.7)
        normalTex:SetPoint("CENTER")
        f:SetNormalTexture(normalTex)

        local pushedTex = f:CreateTexture()
        pushedTex:SetColorTexture(0, 0, 0, 0.5)
        pushedTex:SetAllPoints(f.icon)
        f:SetPushedTexture(pushedTex)

        local hlTex = f:CreateTexture()
        hlTex:SetColorTexture(1, 1, 1, 0.15)
        hlTex:SetAllPoints(f.icon)
        f:SetHighlightTexture(hlTex)

        local flashTex = f:CreateTexture(nil, "OVERLAY")
        flashTex:SetColorTexture(1, 0, 0, 0.3)
        flashTex:SetAllPoints(f.icon)
        flashTex:Hide()
        f.Flash = flashTex

        local borderTex = f:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(f.icon)
        borderTex:Hide()
        f.Border = borderTex

        NS.masqueAnimGroup:AddButton(f, {
            Icon = f.icon,
            Normal = normalTex,
            Pushed = pushedTex,
            Highlight = hlTex,
            Flash = flashTex,
            Border = borderTex,
        })

        f:SetBackdrop(nil)
    else
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        f:SetBackdropColor(0, 0, 0, 0.6)
        f:SetBackdropBorderColor(NS.unpack(NS.THEME.BORDER))
    end

    local ag = f:CreateAnimationGroup()
    ag._scale = ag:CreateAnimation("Scale")
    ag._trans = ag:CreateAnimation("Translation")
    ag._alpha = ag:CreateAnimation("Alpha")
    ag._rot = ag:CreateAnimation("Rotation")
    ag._rot:SetOrigin("CENTER", 0, 0)

    ag:SetScript("OnFinished", function()
        f:Hide()
        f:ClearAllPoints()
        f._inUse = false
    end)

    f.ag = ag
    f._inUse = true
    animPool[#animPool + 1] = f
    return f
end

-- Tracks active RECREATE fade-in (prevents ticker from overriding alpha)
NS._recreateFading = false
NS._recreateFadeStart = 0

function NS.PlayCastAnimation(spellID)
    local btn = NS.mainButton
    if not btn or not btn:IsShown() then return end

    local animType = NS.db and NS.db.castAnimation or "NONE"
    if animType == "NONE" then return end

    local config = ANIM_CONFIGS[animType]
    if not config then return end

    local style = NS.db and NS.db.castAnimStyle or "RECREATE"

    -- Always use the CAST spell's own texture.  Earlier events
    -- (SPELL_UPDATE_COOLDOWN, ASSISTED_COMBAT_ACTION_SPELL_CAST) fire
    -- before UNIT_SPELLCAST_SUCCEEDED, so by the time we get here
    -- btn.icon has already been updated to the NEXT recommendation.
    -- Using GetSpellTexture(spellID) ensures we animate the spell
    -- the player actually cast, not whatever the button shows now.
    local tex
    if spellID then
        tex = NS.C_Spell and NS.C_Spell.GetSpellTexture and NS.C_Spell.GetSpellTexture(spellID)
    end
    if not tex and btn.icon then
        tex = btn.icon:GetTexture()
    end
    if not tex then return end

    local anim = AcquireAnimFrame()

    -- 1. Size and position
    if style == "RECREATE" then
        local size = NS.db.buttonSize or 48
        anim:SetSize(size, size)
    else
        local size = (NS.db.buttonSize or 48) * 0.7
        anim:SetSize(size, size)
    end
    anim:ClearAllPoints()
    anim:SetPoint("CENTER", btn, "CENTER")

    -- 2. Set the icon texture
    anim.icon:SetTexture(tex)

    -- 3. Set importance border color on animated frame
    if NS.db.importanceBorders and spellID then
        local borderColor = NS.GetSpellBorderColor(spellID)
        if borderColor then
            if anim.Border then
                anim.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                anim.Border:Show()
            elseif anim.SetBackdropBorderColor then
                anim:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            end
        end
    end

    -- 4. ReSkin Masque at current size
    if NS.masqueAnimGroup then
        NS.masqueAnimGroup:ReSkin()
    end

    -- 5. RECREATE: hide ALL button visuals — animation frame IS the button now
    if style == "RECREATE" then
        btn.icon:SetAlpha(0)
        btn.cooldown:SetAlpha(0)
        if btn.hotkey then btn.hotkey:SetAlpha(0) end
        if not NS.masque then
            btn:SetBackdropColor(0, 0, 0, 0)
            btn:SetBackdropBorderColor(0, 0, 0, 0)
        end
        NS._recreateFading = true
        NS._recreateFadeStart = GetTime() + 0.25
    end

    -- 6. Show and play
    anim:Show()
    anim:SetAlpha(1)
    anim.ag:Stop()
    config(anim.ag)
    anim.ag:Play()

    -- 7. RECREATE: fade the new button in via OnUpdate (avoids animation alpha flicker)
    if style == "RECREATE" then
        local fadeDuration = 0.35
        local fadeFrame = NS._fadeFrame
        if not fadeFrame then
            fadeFrame = NS.CreateFrame("Frame")
            NS._fadeFrame = fadeFrame
        end
        fadeFrame:SetScript("OnUpdate", function(self, elapsed)
            local now = GetTime()
            if now < NS._recreateFadeStart then return end  -- still in delay
            local t = now - NS._recreateFadeStart
            local pct = t / fadeDuration
            if pct >= 1 then
                -- Fully restore all button visuals
                btn.icon:SetAlpha(1)
                btn.cooldown:SetAlpha(1)
                if btn.hotkey then btn.hotkey:SetAlpha(1) end
                if not NS.masque then
                    btn:SetBackdropColor(NS.unpack(NS.db.buttonBgColor))
                    -- Border color restored by next UpdateButton tick
                    btn:SetBackdropBorderColor(NS.unpack(NS.THEME.BORDER))
                end
                NS._recreateFading = false
                self:SetScript("OnUpdate", nil)
            else
                btn.icon:SetAlpha(pct)
                btn.cooldown:SetAlpha(pct)
                if btn.hotkey then btn.hotkey:SetAlpha(pct) end
                if not NS.masque then
                    local r, g, b, a = NS.unpack(NS.db.buttonBgColor)
                    btn:SetBackdropColor(r, g, b, a * pct)
                end
            end
        end)
    end
end
