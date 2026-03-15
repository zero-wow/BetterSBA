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

----------------------------------------------------------------
-- Masque integration
----------------------------------------------------------------
-- Reapply our hotkey offsets after Masque repositions elements
local function PostMasqueSkinFix()
    local btn = NS.mainButton
    if btn and btn.hotkey then
        btn.hotkey:ClearAllPoints()
        btn.hotkey:SetPoint(NS.db.keybindAnchor or "TOPRIGHT", NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
    end
end

function NS.InitMasque()
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return end
    NS.masque = MSQ

    -- Masque callback fires when user changes skin — reapply our offsets after
    local function onSkinChanged() NS.C_Timer_After(0, PostMasqueSkinFix) end

    NS.masqueMainGroup = MSQ:Group("BetterSBA", "Main Button")
    NS.masqueMainGroup.SkinChanged = onSkinChanged
    NS.masquePriorityGroup = MSQ:Group("BetterSBA", "Rotation")
    NS.masqueAnimGroup = MSQ:Group("BetterSBA", "Animated Button")
end

-- No-op: Masque handles its own reskinning via callbacks.
-- Kept for any remaining call sites during transition.
function NS.MasqueReSkin() end

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
-- Class / spec helpers
----------------------------------------------------------------
-- Spec lookup: maps friendly name → { classToken, specIndex }
local SPEC_MAP = {
    -- Demon Hunter
    ["Havoc"]           = { "DEMONHUNTER", 1 },
    ["Vengeance"]       = { "DEMONHUNTER", 2 },
    -- Warrior
    ["Arms"]            = { "WARRIOR", 1 },
    ["Fury"]            = { "WARRIOR", 2 },
    ["Protection:W"]    = { "WARRIOR", 3 },
    -- Druid
    ["Balance"]         = { "DRUID", 1 },
    ["Feral"]           = { "DRUID", 2 },
    ["Guardian"]        = { "DRUID", 3 },
    ["Restoration:D"]   = { "DRUID", 4 },
    -- Paladin
    ["Holy:Pa"]         = { "PALADIN", 1 },
    ["Protection:Pa"]   = { "PALADIN", 2 },
    ["Retribution"]     = { "PALADIN", 3 },
    -- Death Knight
    ["Blood"]           = { "DEATHKNIGHT", 1 },
    ["Frost:DK"]        = { "DEATHKNIGHT", 2 },
    ["Unholy"]          = { "DEATHKNIGHT", 3 },
    -- Monk
    ["Brewmaster"]      = { "MONK", 1 },
    ["Mistweaver"]      = { "MONK", 2 },
    ["Windwalker"]      = { "MONK", 3 },
    -- Mage
    ["Arcane"]          = { "MAGE", 1 },
    ["Fire"]            = { "MAGE", 2 },
    ["Frost:M"]         = { "MAGE", 3 },
    -- Hunter
    ["Beast Mastery"]   = { "HUNTER", 1 },
    ["Marksmanship"]    = { "HUNTER", 2 },
    ["Survival"]        = { "HUNTER", 3 },
    -- Rogue
    ["Assassination"]   = { "ROGUE", 1 },
    ["Outlaw"]          = { "ROGUE", 2 },
    ["Subtlety"]        = { "ROGUE", 3 },
    -- Priest
    ["Discipline"]      = { "PRIEST", 1 },
    ["Holy:Pr"]         = { "PRIEST", 2 },
    ["Shadow"]          = { "PRIEST", 3 },
    -- Shaman
    ["Elemental"]       = { "SHAMAN", 1 },
    ["Enhancement"]     = { "SHAMAN", 2 },
    ["Restoration:S"]   = { "SHAMAN", 3 },
    -- Warlock
    ["Affliction"]      = { "WARLOCK", 1 },
    ["Demonology"]      = { "WARLOCK", 2 },
    ["Destruction"]     = { "WARLOCK", 3 },
    -- Evoker
    ["Devastation"]     = { "EVOKER", 1 },
    ["Preservation"]    = { "EVOKER", 2 },
    ["Augmentation"]    = { "EVOKER", 3 },
}

--- Check if the player is a specific spec.
--- @param specName string  Friendly spec name (e.g. "Vengeance", "Guardian", "Brewmaster")
--- @return boolean
function NS.IsSpec(specName)
    local entry = SPEC_MAP[specName]
    if not entry then return false end
    local _, classToken = UnitClass("player")
    return classToken == entry[1] and GetSpecialization() == entry[2]
end

-- Classes that have permanent or frequently-summoned combat pets.
-- /petattack is a no-op on other classes, so hide the option entirely.
local PET_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true }
function NS.IsPetClass()
    local _, classToken = UnitClass("player")
    return PET_CLASSES[classToken] or false
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
local resolveCache = {}         -- [originalSpellID] = resolvedID or CACHE_NIL

----------------------------------------------------------------
-- Persistent spell texture cache: GetSpellTexture returns a new
-- string on every call (~80 bytes).  With 7 calls per tick (main
-- + 6 priority icons), that's ~5.6 KB/sec of string garbage.
-- Textures never change during gameplay — cache permanently and
-- invalidate on spec/talent/spell change events.
----------------------------------------------------------------
local texCache = {}

function NS.GetSpellTextureCached(spellID)
    local cached = texCache[spellID]
    if cached then
        if cached == CACHE_NIL then return nil end
        return cached
    end
    local tex = NS.C_Spell and NS.C_Spell.GetSpellTexture
        and NS.C_Spell.GetSpellTexture(spellID)
    texCache[spellID] = tex or CACHE_NIL
    return tex
end

function NS.InvalidateTextureCache()
    wipe(texCache)
end

----------------------------------------------------------------
-- Event-driven cooldown cache: C_Spell.GetSpellCooldown returns
-- a NEW table (~200 bytes) every call — pure garbage.  We cache
-- results and ONLY re-query when SPELL_UPDATE_COOLDOWN fires
-- (which marks the cache dirty).  This is safe because WoW fires
-- that event on every GCD, cooldown start, cooldown end, charge
-- gain, haste change, and cooldown reset proc.  Zero API calls
-- between events = zero table garbage between events.
--
-- TAINT FIX: We capture GetSpellCooldown as a file-local at
-- load time.  Looking it up through NS.C_Spell taints the
-- function reference (NS becomes tainted once we touch secure
-- frames), which taints every return value, making comparisons
-- on duration/startTime throw "secret number" errors.  A clean
-- local captured at file load time is never tainted.
----------------------------------------------------------------
local cdCache = {}
local cdCacheDirty = true   -- start dirty so first tick queries
local cdRefreshGen = {}     -- tracks which updateGeneration refreshed each spell

-- Clean (untainted) references captured at file load time
local _GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local _IsPlayerSpell = IsPlayerSpell

-- Reusable table pool: instead of storing the API's new table
-- (which becomes garbage), we copy fields into a persistent table.
-- This means each spell has exactly ONE cached table that never
-- gets replaced, so zero table garbage from cooldown queries.
local function _copyCD(dst, src)
    dst.startTime = src.startTime
    dst.duration  = src.duration
    dst.isEnabled = src.isEnabled
    dst.modRate   = src.modRate
    return dst
end

function NS.GetCooldownCached(spellID)
    if not _GetSpellCooldown then return nil end

    -- Virtual cooldown path: if seeded, use virtual data for rotation spells
    if virtualCDSeeded then
        local vcd = virtualCD[spellID]
        if vcd then
            local now = GetTime()
            if (vcd.startTime + vcd.duration) > now then
                -- Still on CD — return virtual data in the same shape as API
                local cached = cdCache[spellID]
                if cached and cached ~= CACHE_NIL then
                    cached.startTime = vcd.startTime
                    cached.duration = vcd.duration
                    cached.isEnabled = 1
                    cached.modRate = 1
                    return cached
                end
                -- Create a new entry
                local entry = { startTime = vcd.startTime, duration = vcd.duration, isEnabled = 1, modRate = 1 }
                cdCache[spellID] = entry
                return entry
            else
                -- Virtual entry expired — remove it
                virtualCD[spellID] = nil
            end
        end
    end

    local cached = cdCache[spellID]

    -- Fast path: cache is clean — return whatever we have
    if not cdCacheDirty and cached then
        if cached == CACHE_NIL then return nil end
        return cached
    end

    -- Dirty but already refreshed this spell THIS tick — dedup
    if cdCacheDirty and cached and cdRefreshGen[spellID] == updateGeneration then
        if cached == CACHE_NIL then return nil end
        return cached
    end

    -- Need fresh data: dirty or never cached
    local ok, cdInfo = pcall(_GetSpellCooldown, spellID)
    if ok and cdInfo then
        -- Reuse existing table if we have one, otherwise create once
        if cached and cached ~= CACHE_NIL then
            _copyCD(cached, cdInfo)
        else
            cached = _copyCD({}, cdInfo)
            cdCache[spellID] = cached
        end
        cdRefreshGen[spellID] = updateGeneration
        return cached
    end
    cdCache[spellID] = CACHE_NIL
    cdRefreshGen[spellID] = updateGeneration
    return nil
end

-- Called by SPELL_UPDATE_COOLDOWN event handler
function NS.InvalidateCooldownCache()
    cdCacheDirty = true
    -- Reconcile virtual state with API to catch cooldown reset procs
    if virtualCDSeeded then
        NS.ReconcileVirtualCooldowns()
    end
end

----------------------------------------------------------------
-- Virtual Cooldown System: tracks cooldowns via UNIT_SPELLCAST_SUCCEEDED
-- events instead of querying GetSpellCooldown every tick.  Seeded once
-- on login (out of combat), then maintained purely from cast events +
-- base cooldown data.  Zero API calls per tick, zero table garbage.
----------------------------------------------------------------
local virtualCD = {}            -- [spellID] = { startTime, duration }
local virtualCDSeeded = false
local virtualCDPending = false  -- true if loaded in combat, waiting for OOC

function NS.IsVirtualCDReady()
    return virtualCDSeeded
end

function NS.SeedVirtualCooldowns()
    if NS.InCombatLockdown() then
        virtualCDPending = true
        return
    end
    virtualCDPending = false

    local spells = NS.CollectRotationSpells()
    for i = 1, #spells do
        local sid = spells[i]
        if sid and sid ~= 0 and _GetSpellCooldown then
            -- Cache base cooldown (permanent)
            NS.GetSpellBaseCooldown(sid)
            -- Read current cooldown state
            local ok, cdInfo = pcall(_GetSpellCooldown, sid)
            if ok and cdInfo then
                local dur = tonumber(tostring(cdInfo.duration)) or 0
                if dur > 1.5 then
                    virtualCD[sid] = {
                        startTime = tonumber(tostring(cdInfo.startTime)) or 0,
                        duration = dur,
                    }
                else
                    virtualCD[sid] = nil
                end
            end
        end
    end
    virtualCDSeeded = true
end

function NS.OnSpellCastSucceeded(spellID)
    if not virtualCDSeeded or not spellID then return end
    local baseCD = NS.GetSpellBaseCooldown(spellID)
    if baseCD and baseCD > 1.5 then
        virtualCD[spellID] = {
            startTime = GetTime(),
            duration = baseCD,
        }
    end
end

-- Reconcile virtual state with API on SPELL_UPDATE_COOLDOWN.
-- Only queries spells that virtual tracking thinks are on CD,
-- catching cooldown reset procs that the virtual system would miss.
function NS.ReconcileVirtualCooldowns()
    if not virtualCDSeeded or not _GetSpellCooldown then return end
    local now = GetTime()
    for sid, entry in pairs(virtualCD) do
        -- Only reconcile entries that haven't expired yet
        if (entry.startTime + entry.duration) > now then
            local ok, cdInfo = pcall(_GetSpellCooldown, sid)
            if ok and cdInfo then
                local dur = tonumber(tostring(cdInfo.duration)) or 0
                if dur <= 1.5 then
                    -- API says it's ready but virtual says on CD → was reset by a proc
                    virtualCD[sid] = nil
                else
                    -- Update with API's values (may differ due to haste changes)
                    entry.startTime = tonumber(tostring(cdInfo.startTime)) or entry.startTime
                    entry.duration = dur
                end
            end
        else
            -- Expired — clear
            virtualCD[sid] = nil
        end
    end
end

function NS.ResetVirtualCooldowns()
    virtualCD = {}
    virtualCDSeeded = false
    virtualCDPending = false
end

-- Deferred seeding check (called from PLAYER_REGEN_ENABLED)
function NS.CheckPendingVirtualCD()
    if virtualCDPending then
        NS.SeedVirtualCooldowns()
    end
end

----------------------------------------------------------------
-- GC: tune Lua's built-in incremental collector via setpause/setstepmul.
-- This spreads GC work across allocations with zero spikes — no manual
-- "step" calls that freeze the VM.  Target MB controls aggressiveness:
-- lower target = tighter pause + faster stepmul.
----------------------------------------------------------------
local gcSavedPause, gcSavedStepMul
function NS.StartGCTicker()
    NS.StopGCTicker()
    if not NS.db or not NS.db.enableGC then return end
    local targetMB = NS.db.gcTargetMB or 0
    if targetMB <= 0 then
        gcSavedPause = collectgarbage("setpause", 150)
        gcSavedStepMul = collectgarbage("setstepmul", 200)
    else
        local pause = math.max(100, NS.math_floor(100 + targetMB * 10))
        local stepmul = math.max(200, NS.math_floor(600 / targetMB))
        gcSavedPause = collectgarbage("setpause", pause)
        gcSavedStepMul = collectgarbage("setstepmul", stepmul)
    end
end
function NS.StopGCTicker()
    if gcSavedPause then
        collectgarbage("setpause", gcSavedPause)
        gcSavedPause = nil
    end
    if gcSavedStepMul then
        collectgarbage("setstepmul", gcSavedStepMul)
        gcSavedStepMul = nil
    end
end

function NS.BeginUpdate()
    updateGeneration = updateGeneration + 1
    -- Cooldown cache is event-driven — no wipe needed.
    -- The dirty flag is cleared AFTER all queries in this tick
    -- have had a chance to refresh, so every GetCooldownCached
    -- call within this tick sees the dirty flag and re-queries.
end

-- Called at the END of UpdateNow, after all cooldown queries are done.
-- Clears the dirty flag so subsequent ticks reuse cached data until
-- the next SPELL_UPDATE_COOLDOWN event fires.
function NS.EndUpdate()
    cdCacheDirty = false
end

-- Call this from event handlers that change the rotation pool
function NS.InvalidateRotationCache()
    rotationDirty = true
    -- Rotation changed — virtual CD data may be stale, re-seed when possible
    if virtualCDSeeded then
        NS.ResetVirtualCooldowns()
        if not NS.InCombatLockdown() then
            NS.C_Timer_After(0.5, function()
                NS.SeedVirtualCooldowns()
            end)
        else
            virtualCDPending = true
        end
    end
end

-- Call this from event handlers that change spell overrides (spec/talent/spell changes)
function NS.InvalidateResolveCache()
    wipe(resolveCache)
end

----------------------------------------------------------------
-- Cache diagnostics (exposed for diagnostic report)
----------------------------------------------------------------
function NS.GetCacheDiagnostics()
    local countTable = function(t)
        local n = 0; for _ in pairs(t) do n = n + 1 end; return n
    end
    return {
        cooldownEntries = countTable(cdCache),
        cooldownDirty = cdCacheDirty,
        textureEntries = countTable(texCache),
        resolveEntries = countTable(resolveCache),
        gcCountKB = collectgarbage("count"),
    }
end

----------------------------------------------------------------
-- Spell ID resolution: fixes bad/obsolete IDs from the SBA API.
--
-- Strategy (in order):
--   1. Manual substitution table (NS.SPELL_SUBSTITUTIONS)
--   2. If spell already has a texture, return as-is
--   3. FindSpellOverrideByID / C_Spell.GetOverrideSpell (talent replacements)
--   4. Return nil → caller should filter this spell out
--
-- Results are cached in resolveCache, invalidated on spec/spell changes.
----------------------------------------------------------------
local SUBS_PREFIX = "|cFF66B8D9[BetterSBA Subs]|r "

local function SubsDebugPrint(...)
    if not DebugChannelEnabled("spell") then return end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = NS.tostring(select(i, ...))
    end
    print(SUBS_PREFIX .. NS.table_concat(parts, " "))
end

function NS.ResolveSpellID(spellID)
    if not spellID or spellID == 0 then return nil end

    local cached = resolveCache[spellID]
    if cached then
        if cached == CACHE_NIL then return nil end
        return cached
    end

    local C_Spell = NS.C_Spell

    -- 1. Manual substitution table (always wins)
    local sub = NS.SPELL_SUBSTITUTIONS and NS.SPELL_SUBSTITUTIONS[spellID]
    if sub then
        -- Verify the substitution target actually has a texture
        local subTex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sub)
        if subTex then
            SubsDebugPrint(spellID, "->", sub, "(manual)")
            resolveCache[spellID] = sub
            return sub
        end
        -- Manual sub target is also bad — fall through to auto-resolution
    end

    -- 2. Already has a texture? No fix needed
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            resolveCache[spellID] = spellID
            return spellID
        end
    end

    -- 3. Try spell override APIs (talent/aura replacements)
    local overrideID
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, result = NS.pcall(C_Spell.GetOverrideSpell, spellID)
        if ok and result and result ~= spellID and result ~= 0 then
            overrideID = result
        end
    end
    if not overrideID and FindSpellOverrideByID then
        local ok, result = NS.pcall(FindSpellOverrideByID, spellID)
        if ok and result and result ~= spellID and result ~= 0 then
            overrideID = result
        end
    end

    if overrideID then
        local overrideTex = C_Spell and C_Spell.GetSpellTexture
            and C_Spell.GetSpellTexture(overrideID)
        if overrideTex then
            SubsDebugPrint(spellID, "->", overrideID, "(override)")
            resolveCache[spellID] = overrideID
            return overrideID
        end
    end

    -- 4. Can't resolve — filter out
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = NS.pcall(C_Spell.GetSpellName, spellID)
        if ok then name = n end
    end
    SubsDebugPrint("FILTERED:", spellID, name and ("(" .. name .. ")") or "", "— no texture/override")
    resolveCache[spellID] = CACHE_NIL
    return nil
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
            sid = NS.ResolveSpellID(sid) or sid
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
            sid = NS.ResolveSpellID(sid) or sid
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
            sid = NS.ResolveSpellID(sid) or sid
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
        -- Resolve bad spell IDs, filter non-existent and unlearned spells
        local resolved = {}
        for i = 1, #spells do
            local sid = spells[i]
            if sid and sid ~= 0 then
                local fixedID = NS.ResolveSpellID(sid)
                if fixedID then
                    -- Filter spells the player doesn't actually have (e.g. unlearned talents)
                    if _IsPlayerSpell then
                        local pok, known = NS.pcall(_IsPlayerSpell, fixedID)
                        if pok and known == false then
                            fixedID = nil  -- skip unlearned spell
                        end
                    end
                    if fixedID then
                        resolved[#resolved + 1] = fixedID
                    end
                end
            end
        end
        cachedRotation = #resolved > 0 and resolved or EMPTY_TABLE
    else
        cachedRotation = EMPTY_TABLE
    end
    return cachedRotation
end

----------------------------------------------------------------
-- Macro text builder
----------------------------------------------------------------
-- Resolve localized spell name, falling back to English hardcoded name.
-- Pure string return — no tables, no closures, no taint-sensitive values.
local function resolveSpellName(spellID, fallback)
    local name = NS.C_Spell and NS.C_Spell.GetSpellName
        and NS.C_Spell.GetSpellName(spellID) or fallback
    return name
end

function NS.BuildMacroText()
    local lines = {}
    local db = NS.db

    -- Channel protection FIRST — abort the entire macro while channeling
    if db.enableChannelProtection then
        NS.table_insert(lines, "/stopmacro [channeling]")
    end

    if db.enableDismount then
        NS.table_insert(lines, "/dismount [mounted]")
    end

    if db.enableTargeting then
        NS.table_insert(lines, "/targetenemy [noharm][dead]")
    end

    if db.enablePetAttack and NS.IsPetClass() then
        NS.table_insert(lines, "/petattack")
    end

    NS.table_insert(lines, "/cast " .. NS.GetSBASpellName())

    -- Class-specific off-GCD abilities (appended after /cast SBA).
    -- These all fire because they are off the GCD — SBA consuming the
    -- GCD does not block them.  Each silently fails if on cooldown,
    -- insufficient resource, or not learned.

    -- Vengeance DH: Demon Spikes (off-GCD, charges, mitigation)
    if db.enableDemonSpikes and NS.IsSpec("Vengeance") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.DEMON_SPIKES_SPELL_ID, "Demon Spikes"))
    end
    -- Protection Warrior: Shield Block (off-GCD, 2 charges, costs Rage)
    if db.enableShieldBlock and NS.IsSpec("Protection:W") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.SHIELD_BLOCK_SPELL_ID, "Shield Block"))
    end
    -- Protection Warrior: Ignore Pain (off-GCD, Rage dump absorb)
    if db.enableIgnorePain and NS.IsSpec("Protection:W") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.IGNORE_PAIN_SPELL_ID, "Ignore Pain"))
    end
    -- Guardian Druid: Ironfur (off-GCD, stacking armor, costs Rage)
    if db.enableIronfur and NS.IsSpec("Guardian") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.IRONFUR_SPELL_ID, "Ironfur"))
    end
    -- Protection Paladin: Shield of the Righteous (off-GCD for Prot, costs 3 HP)
    if db.enableShieldOfRighteous and NS.IsSpec("Protection:Pa") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.SHIELD_OF_RIGHTEOUS_ID, "Shield of the Righteous"))
    end
    -- Blood DK: Rune Tap (off-GCD, 2 charges, talent-gated)
    if db.enableRuneTap and NS.IsSpec("Blood") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.RUNE_TAP_SPELL_ID, "Rune Tap"))
    end
    -- Brewmaster Monk: Purifying Brew (off-GCD, 2 charges, clears Stagger)
    if db.enablePurifyingBrew and NS.IsSpec("Brewmaster") then
        NS.table_insert(lines, "/cast " .. resolveSpellName(NS.PURIFYING_BREW_SPELL_ID, "Purifying Brew"))
    end

    return NS.table_concat(lines, "\n")
end

function NS.RebuildMacroText()
    if NS.InCombatLockdown() then
        NS._pendingMacroRebuild = true
        return
    end
    local macro = NS.BuildMacroText()
    if NS.secureButton then
        NS.secureButton:SetAttribute("macrotext", macro)
    end
    if _G["BetterSBA_ClickIntercept"] and _G["BetterSBA_ClickIntercept"]:IsShown() then
        _G["BetterSBA_ClickIntercept"]:SetAttribute("macrotext", macro)
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

    -- ALWAYS update the SBA override — clear when mounted/vehicle,
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
            local spellTex = NS.GetSpellTextureCached(sid)
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
-- Particle burst system — style-aware, palette-driven
----------------------------------------------------------------
local PARTICLE_POOL = {}          -- recycled frame pool

local function AcquireParticle()
    for _, p in NS.ipairs(PARTICLE_POOL) do
        if not p._inUse then
            p._inUse = true
            return p
        end
    end

    local f = NS.CreateFrame("Frame", nil, NS.UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(300)
    f:Hide()

    -- Dark outline layer (1px black border for visibility)
    f.outline = f:CreateTexture(nil, "ARTWORK")
    f.outline:SetPoint("TOPLEFT", -1, 1)
    f.outline:SetPoint("BOTTOMRIGHT", 1, -1)
    f.outline:SetColorTexture(0, 0, 0, 0.9)

    -- Colored particle layer on top
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetColorTexture(1, 1, 1, 1)

    f._inUse = true
    PARTICLE_POOL[#PARTICLE_POOL + 1] = f
    return f
end

-- Style configs: count, duration, distance, per-particle setup
local PARTICLE_STYLE_CONFIGS = {
    Confetti = {
        count = 20, duration = 1.8, distance = 100,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(4, 10)
            p:SetSize(sz, sz * (0.4 + 0.6 * math.random()))
            local shade = 0.8 + 0.4 * math.random()
            p.tex:SetColorTexture(math.min(1, clr[1]*shade), math.min(1, clr[2]*shade), math.min(1, clr[3]*shade), 1)
            local stagger = math.random() * 0.20
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.4); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.5)
            ag._scale:SetScale(0.3, 0.3); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("IN"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.random(0, 360)); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Lasers = {
        count = 16, duration = 1.2, distance = 140,
        setup = function(p, angle, dist, dur, clr)
            p:SetSize(2, 16)
            p.tex:SetColorTexture(math.min(1, clr[1]*1.2), math.min(1, clr[2]*1.2), math.min(1, clr[3]*1.2), 1)
            local stagger = math.random() * 0.15
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("NONE"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.3); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.6)
            ag._scale:SetScale(1.5, 0.5); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("OUT"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.deg(angle) - 90); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Sparks = {
        count = 28, duration = 1.4, distance = 80,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(3, 7)
            p:SetSize(sz, sz * (0.3 + 0.4 * math.random()))
            p.tex:SetColorTexture(clr[1], clr[2], clr[3], 1)
            local stagger = math.random() * 0.20
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist, math.sin(angle)*dist)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.4); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.4)
            ag._scale:SetScale(0.4, 0.4); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("IN"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(math.random(0, 360)); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
    Squares = {
        count = 16, duration = 2.0, distance = 85,
        setup = function(p, angle, dist, dur, clr)
            local sz = math.random(6, 11)
            p:SetSize(sz, sz)
            local shade = 0.9 + 0.2 * math.random()
            p.tex:SetColorTexture(math.min(1, clr[1]*shade), math.min(1, clr[2]*shade), math.min(1, clr[3]*shade), 1)
            local stagger = math.random() * 0.25
            local ag = p._ag
            ag._trans:SetOffset(math.cos(angle)*dist*0.7, math.sin(angle)*dist*0.7)
            ag._trans:SetDuration(dur); ag._trans:SetSmoothing("OUT"); ag._trans:SetStartDelay(stagger)
            ag._alpha:SetFromAlpha(1); ag._alpha:SetToAlpha(0)
            ag._alpha:SetDuration(dur*0.3); ag._alpha:SetSmoothing("IN"); ag._alpha:SetStartDelay(stagger + dur*0.6)
            ag._scale:SetScale(0.5, 0.5); ag._scale:SetDuration(dur); ag._scale:SetSmoothing("OUT"); ag._scale:SetStartDelay(stagger)
            ag._rot:SetDegrees(45); ag._rot:SetDuration(0.001); ag._rot:SetSmoothing("NONE"); ag._rot:SetStartDelay(0)
        end,
    },
}

-- Fire a burst of particles from the center of `btn`
local RANDOM_STYLE_KEYS = { "Confetti", "Lasers", "Sparks", "Squares" }

function NS.FireParticleBurst(btn, styleName, paletteName, gcdScale)
    if not btn then return end
    if styleName == "None" then return end

    if styleName == "Random" then
        styleName = RANDOM_STYLE_KEYS[math.random(#RANDOM_STYLE_KEYS)]
    end

    local styleConfig = PARTICLE_STYLE_CONFIGS[styleName or "Confetti"]
    if not styleConfig then styleConfig = PARTICLE_STYLE_CONFIGS.Confetti end

    local colors = NS:GetPalette(paletteName or "Confetti")
    if not colors or #colors == 0 then
        colors = NS.BUILTIN_PALETTES.Confetti
    end

    local g = gcdScale or ((NS.db.gcdDuration or 1.9) / 1.9)
    local count = styleConfig.count
    local dur = styleConfig.duration * g
    local maxDist = styleConfig.distance

    for i = 1, count do
        local p = AcquireParticle()

        local angle = math.random() * 2 * math.pi
        local dist = maxDist * (0.5 + 0.5 * math.random())
        local clr = colors[math.random(#colors)]

        p:ClearAllPoints()
        p:SetPoint("CENTER", btn, "CENTER")
        p:SetAlpha(1)
        p:SetScale(1)
        p:Show()

        -- Ensure animation group exists
        local ag = p._ag
        if not ag then
            ag = p:CreateAnimationGroup()
            ag._trans = ag:CreateAnimation("Translation")
            ag._alpha = ag:CreateAnimation("Alpha")
            ag._scale = ag:CreateAnimation("Scale")
            ag._rot = ag:CreateAnimation("Rotation")
            ag._rot:SetOrigin("CENTER", 0, 0)
            ag:SetScript("OnFinished", function()
                p:Hide()
                p:ClearAllPoints()
                p:SetScale(1)
                p._inUse = false
            end)
            p._ag = ag
        end

        styleConfig.setup(p, angle, dist, dur, clr)

        ag:Stop()
        ag:Play()
    end
end

-- Legacy wrapper for any remaining call sites
local function FirePopBurst(btn)
    NS.FireParticleBurst(btn, "Confetti", "Confetti")
end

----------------------------------------------------------------
-- Cast animation system (multiple animation types)
----------------------------------------------------------------
local animPool = {}

local BASE_GCD = 1.9
local ANIM_CONFIGS = {
    DRIFT = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.3, 0.3); s:SetDuration(1.2*g); s:SetSmoothing("IN_OUT"); s:SetStartDelay(0)
        t:SetOffset(-80, -15); t:SetDuration(1.0*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0.05*g)
        r:SetDegrees(180); r:SetDuration(1.2*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
    PULSE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(2.0, 2.0); s:SetDuration(0.45*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    VORTEX = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.15, 0.15); s:SetDuration(0.7*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(360); r:SetDuration(0.7*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
    ZOOM = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(3.5, 3.5); s:SetDuration(0.55*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 25); t:SetDuration(0.55*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SLAM = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, -28); t:SetDuration(0.70*g); t:SetSmoothing("IN"); t:SetStartDelay(0)
        a:SetFromAlpha(1.0); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    ["POP!"] = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1.25, 1.25); s:SetDuration(0.12*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0.10*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    BURST = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1.5, 1.5); s:SetDuration(0.45*g); s:SetSmoothing("IN_OUT"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.4*g); a:SetSmoothing("IN"); a:SetStartDelay(0.15*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    FADE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.5*g); a:SetSmoothing("IN_OUT"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    FLIP = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.01, 1); s:SetDuration(0.50*g); s:SetSmoothing("IN"); s:SetStartDelay(0)
        t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0.10*g)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    RISE = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(0)
        t:SetOffset(0, 35); t:SetDuration(0.80*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.3*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(0)
    end,
    SCATTER = function(ag, g)
        local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
        s:SetScale(0.4, 0.4); s:SetDuration(0.70*g); s:SetSmoothing("OUT"); s:SetStartDelay(0)
        t:SetOffset(65, 40); t:SetDuration(0.70*g); t:SetSmoothing("OUT"); t:SetStartDelay(0)
        a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(1.2*g); a:SetSmoothing("IN"); a:SetStartDelay(0)
        r:SetDegrees(270); r:SetDuration(0.80*g); r:SetSmoothing("OUT"); r:SetStartDelay(0)
    end,
}

-- Reverse (incoming) animation configs — overlapping with outgoing.
--
-- Both outgoing and incoming clones are launched simultaneously.
-- The incoming clone uses SetStartDelay on each sub-animation so it
-- begins partway through the outgoing, creating a seamless cross-fade
-- where the old icon leaves and the new icon arrives as one motion.
--
--   offset    – where the clone starts (opposite side from forward's travel)
--   preScale  – frame's actual scale before animation (matches forward's
--               end scale).  Scale animation compensates to arrive at 1.0.
--   delay     – seconds to wait before the incoming animations begin
--               (overlap point into the outgoing animation)
--   setup(ag, d) – configures the AnimationGroup with start delay d
local REVERSE_ANIM_CONFIGS = {
    DRIFT = {
        offset = { 80, 15 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(-80, -15); t:SetDuration(0.55*g); t:SetSmoothing("IN"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.45*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    PULSE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    VORTEX = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    ZOOM = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    ["POP!"] = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    BURST = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    SLAM = {
        offset = { 0, 28 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, -28); t:SetDuration(0.50*g); t:SetSmoothing("OUT"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    FADE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.20,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    FLIP = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    RISE = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.40*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
    SCATTER = {
        offset = { 0, 0 },
        preScale = 1,
        delay = 1.10,
        setup = function(ag, d, g)
            d = d or 0; g = g or 1
            local s, t, a, r = ag._scale, ag._trans, ag._alpha, ag._rot
            s:SetScale(1, 1); s:SetDuration(0.001); s:SetSmoothing("NONE"); s:SetStartDelay(d)
            t:SetOffset(0, 0); t:SetDuration(0.001); t:SetSmoothing("NONE"); t:SetStartDelay(d)
            a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.35*g); a:SetSmoothing("OUT"); a:SetStartDelay(d)
            r:SetDegrees(0); r:SetDuration(0.001); r:SetSmoothing("NONE"); r:SetStartDelay(d)
        end,
    },
}

----------------------------------------------------------------
-- SLAM landing bounce — damped cosine wobble ("superhero landing")
-- Must be declared before AcquireAnimFrame so the OnFinished
-- closure can capture these upvalues.
----------------------------------------------------------------
local slamBounceTarget = nil
local slamBounceElapsed = 0
local SLAM_BOUNCE_DUR = 0.30
local slamBounceDurScaled = SLAM_BOUNCE_DUR
local SLAM_BOUNCE_AMP = 0.10   -- 10% scale oscillation
local SLAM_BOUNCE_FREQ = 2.5   -- ~2.5 wobble cycles

local slamBounceDriver = NS.CreateFrame("Frame")
slamBounceDriver:Hide()
slamBounceDriver:SetScript("OnUpdate", function(self, elapsed)
    if not slamBounceTarget then self:Hide() return end
    slamBounceElapsed = slamBounceElapsed + elapsed
    if slamBounceElapsed >= slamBounceDurScaled then
        -- Bounce done — reveal real button and clean up
        local srcBtn = slamBounceTarget._sourceBtn
        if srcBtn then
            local targetAlpha = InCombatLockdown()
                and (NS.db.alphaCombat or 1)
                or  (NS.db.alphaOOC or 1)
            srcBtn:SetAlpha(targetAlpha)
            NS._recreateFading = false
        end
        slamBounceTarget:SetScale(1)
        slamBounceTarget:Hide()
        slamBounceTarget:ClearAllPoints()
        slamBounceTarget._sourceBtn = nil
        slamBounceTarget._animType = nil
        slamBounceTarget._isIncoming = nil
        slamBounceTarget._hasIncomingPeer = nil
        slamBounceTarget._inUse = false
        slamBounceTarget = nil
        self:Hide()
        return
    end
    -- Damped cosine: wobbles ±AMP, decaying to zero over BOUNCE_DUR
    local decay = 1 - (slamBounceElapsed / slamBounceDurScaled)
    local wobble = 1 + SLAM_BOUNCE_AMP * decay * math.cos(
        SLAM_BOUNCE_FREQ * 2 * math.pi * slamBounceElapsed / slamBounceDurScaled)
    local baseScale = slamBounceTarget._btnScale or NS.db.scale or 1
    slamBounceTarget:SetScale(wobble * baseScale)
end)

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

local function UseMasqueAnimClone()
    return NS.masqueAnimGroup and NS.db.animCloneMasque ~= false
end

local function PositionKeybindHotkey(hk)
    if not hk then return end
    local parent = hk:GetParent()
    local anchor = NS.db.keybindAnchor or "TOPRIGHT"
    hk:ClearAllPoints()
    hk:SetPoint(anchor, parent, anchor, NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5)
end

local function PositionAnimCloneHotkey(hk)
    if not hk then return end
    local parent = hk:GetParent()
    local anchor = NS.db.keybindAnchor or "TOPRIGHT"
    hk:ClearAllPoints()
    hk:SetPoint(anchor, parent, anchor, NS.db.animCloneKeybindOffsetX or -5, NS.db.animCloneKeybindOffsetY or -5)
end

local function DebugAnimClone(phase, anim, spellID, sourceBtn)
    if not DebugChannelEnabled("anim") or not anim then return end

    local hk = anim.hotkey
    local point, relPoint, ox, oy = "nil", "nil", "nil", "nil"
    if hk then
        local ok, a, _, c, d, e = NS.pcall(hk.GetPoint, hk, 1)
        if ok then
            point = a or "nil"
            relPoint = c or "nil"
            ox = d or 0
            oy = e or 0
        end
    end

    local hkParent = hk and hk:GetParent()
    local hkParentName = hkParent and hkParent.GetName and hkParent:GetName()
    local hkParentType = hkParent and hkParent.GetObjectType and hkParent:GetObjectType() or "nil"
    local group = NS.masqueAnimGroup
    local gdb = group and group.db

    NS.DebugPrintAlways("anim",
        "ANIM CLONE", phase,
        "| acquire:", anim._acquireKind or "unknown",
        "| spellID:", spellID or "nil",
        "| masque:", anim._usesMasque and "on" or "off",
        "| skin:", (gdb and gdb.SkinID) or "nil",
        "| groupScale:", (gdb and gdb.Scale) or "nil",
        "| groupUseScale:", (gdb and gdb.UseScale) and "true" or "false",
        "| sourceSize:", sourceBtn and math.floor(sourceBtn:GetWidth() + 0.5) or "nil",
        "x", sourceBtn and math.floor(sourceBtn:GetHeight() + 0.5) or "nil",
        "| sourceScale:", sourceBtn and sourceBtn:GetScale() or "nil",
        "| frameSize:", math.floor(anim:GetWidth() + 0.5), "x", math.floor(anim:GetHeight() + 0.5),
        "| frameScale:", anim:GetScale(),
        "| effectiveScale:", anim:GetEffectiveScale(),
        "| iconSize:", anim.icon and math.floor(anim.icon:GetWidth() + 0.5) or "nil",
        "x", anim.icon and math.floor(anim.icon:GetHeight() + 0.5) or "nil",
        "| hotkeySize:", hk and math.floor(hk:GetWidth() + 0.5) or "nil",
        "x", hk and math.floor(hk:GetHeight() + 0.5) or "nil",
        "| hotkeyJustify:", hk and hk:GetJustifyH() or "nil", "/", hk and hk:GetJustifyV() or "nil",
        "| hotkeyPoint:", point, relPoint, ox, oy,
        "| hotkeyParent:", hkParentType, hkParentName or "nil",
        "| dbAnchor:", NS.db.keybindAnchor or "TOPRIGHT",
        "| dbOffset:", NS.db.keybindOffsetX or -5, NS.db.keybindOffsetY or -5,
        "| cloneDbOffset:", NS.db.animCloneKeybindOffsetX or -5, NS.db.animCloneKeybindOffsetY or -5)
end

local function ApplyAnimHotkey(anim, spellID)
    local hk = anim and anim.hotkey
    if not hk then return end
    anim._spellID = spellID
    hk:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
        NS.ResolveFontOutline("keybindFont", "keybindOutline"))
    PositionAnimCloneHotkey(hk)
    if NS.db.showKeybind then
        local keyText = spellID and keybindCache[spellID]
        if not keyText or keyText == "" then keyText = "#" end
        hk:SetText(keyText)
        hk:Show()
    else
        hk:SetText("")
        hk:Hide()
    end
end

function NS.RefreshAnimHotkeys()
    for _, f in NS.ipairs(animPool) do
        if f.hotkey then
            f.hotkey:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
                NS.ResolveFontOutline("keybindFont", "keybindOutline"))
            PositionAnimCloneHotkey(f.hotkey)
            if not NS.db.showKeybind then
                f.hotkey:SetText("")
                f.hotkey:Hide()
            end
        end
    end
end

function NS.ReapplyAnimCloneHotkeysNow()
    local count = 0
    for _, f in NS.ipairs(animPool) do
        if f._inUse and f:IsShown() and f.hotkey then
            count = count + 1
            DebugAnimClone("MANUAL-BEFORE", f, f._spellID, f._sourceBtn)
            ApplyAnimHotkey(f, f._spellID)
            DebugAnimClone("MANUAL-AFTER", f, f._spellID, f._sourceBtn)
        end
    end
    if count == 0 then
        print("|cFF66B8D9BetterSBA|r: No active animation clone")
    elseif DebugChannelEnabled("anim") then
        NS.DebugPrintAlways("anim", "ANIM CLONE", "MANUAL", "| reapplied:", count)
    end
end

function NS.ApplyAnimCloneDebugBinding()
    if NS.InCombatLockdown() then
        NS._pendingAnimCloneDebugBinding = true
        return
    end
    local btn = _G["BetterSBA_AnimCloneReapplyButton"]
    if not btn then
        btn = NS.CreateFrame("Button", "BetterSBA_AnimCloneReapplyButton", NS.UIParent)
        btn:SetSize(1, 1)
        btn:SetPoint("TOPLEFT", NS.UIParent, "BOTTOMLEFT", -100, 100)
        btn:SetAlpha(0)
        btn:RegisterForClicks("AnyDown", "AnyUp")
        btn:SetScript("OnClick", NS.ReapplyAnimCloneHotkeysNow)
    end
    ClearOverrideBindings(btn)
    local key = NS.db and NS.db.animCloneReapplyKey
    if key and key ~= "" then
        SetOverrideBindingClick(btn, true, key, btn:GetName(), "LeftButton")
    end
    NS._pendingAnimCloneDebugBinding = nil
end

function NS.ResetAnimClonePool()
    slamBounceTarget = nil
    slamBounceElapsed = 0
    slamBounceDriver:Hide()
    for _, f in NS.ipairs(animPool) do
        if f.ag then f.ag:Stop() end
        f:Hide()
        f:ClearAllPoints()
        f:SetScale(1)
        f:SetAlpha(0)
        f._sourceBtn = nil
        f._animType = nil
        f._isIncoming = nil
        f._hasIncomingPeer = nil
        f._fireParticlesOnEnd = nil
        f._particleStyle = nil
        f._particlePalette = nil
        f._particleGcdScale = nil
        f._gcdScale = nil
        f._spellID = nil
        f._inUse = false
        if f.hotkey then
            f.hotkey:SetText("")
            f.hotkey:Hide()
        end
        if NS.masqueAnimGroup and f._usesMasque and NS.masqueAnimGroup.RemoveButton then
            NS.masqueAnimGroup:RemoveButton(f)
        end
    end
    for i = 1, #animPool do
        animPool[i] = nil
    end
end

local function AcquireAnimFrame()
    local useMasque = UseMasqueAnimClone()
    for _, f in NS.ipairs(animPool) do
        if not f._inUse and f._usesMasque == useMasque then
            f._inUse = true
            f._acquireKind = "reuse"
            if f.ag then f.ag:Stop() end
            f:SetScale(1)
            f:SetAlpha(0)
            f._spellID = nil
            return f
        end
    end

    -- Pool full — recycle the oldest frame
    if #animPool >= MAX_ANIM_POOL then
        for _, oldest in NS.ipairs(animPool) do
            if oldest._usesMasque == useMasque then
                if oldest.ag then oldest.ag:Stop() end
                oldest:Hide()
                oldest:ClearAllPoints()
                oldest:SetScale(1)
                oldest:SetAlpha(0)
                oldest._spellID = nil
                oldest._inUse = true
                oldest._acquireKind = "recycle"
                return oldest
            end
        end
    end

    -- NO BackdropTemplate — WHITE8X8 can flash white during WoW rendering
    -- hiccups.  Use SetColorTexture instead (creates color in GPU memory
    -- with no white base texture that can leak through).
    local f = NS.CreateFrame("Button", nil, NS.UIParent)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f:EnableMouse(false)  -- don't intercept clicks during animation
    f._usesMasque = useMasque

    -- Register with Masque animated button group
    if useMasque then
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints()

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
    else
        -- Border layer (fills entire frame, shows as 1px edge around the icon)
        f.borderTex = f:CreateTexture(nil, "BACKGROUND")
        f.borderTex:SetAllPoints()
        f.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)

        -- Background layer (1px inset, sits on top of border)
        f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.bg:SetPoint("TOPLEFT", 1, -1)
        f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        f.bg:SetColorTexture(0, 0, 0, 0.6)

        -- Icon (1px inset, matches main button's border gap)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("TOPLEFT", 1, -1)
        f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        f.icon:SetTexCoord(NS.unpack(NS.ICON_TEXCOORD))
    end

    -- Keybind — on a child frame so Masque can't hook the FontString
    local hkFrame = NS.CreateFrame("Frame", nil, f)
    hkFrame:SetAllPoints()
    hkFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    f.hotkey = hkFrame:CreateFontString(nil, "OVERLAY")
    f.hotkey:SetFont(NS.ResolveFontPath("keybindFont"), NS.db.keybindFontSize or 12,
        NS.ResolveFontOutline("keybindFont", "keybindOutline"))
    f.hotkey:SetTextColor(0.9, 0.9, 0.9, 1)
    PositionAnimCloneHotkey(f.hotkey)
    f.hotkey:SetText("")
    f.hotkey:Hide()
    f._hkFrame = hkFrame

    local ag = f:CreateAnimationGroup()
    ag._scale = ag:CreateAnimation("Scale")
    ag._scale:SetOrigin("CENTER", 0, 0)
    ag._trans = ag:CreateAnimation("Translation")
    ag._alpha = ag:CreateAnimation("Alpha")
    ag._rot = ag:CreateAnimation("Rotation")
    ag._rot:SetOrigin("CENTER", 0, 0)

    ag:SetScript("OnFinished", function()
        -- SLAM incoming: chain into landing bounce instead of cleanup
        if f._isIncoming and f._animType == "SLAM" and f._sourceBtn then
            f:SetScale(f._btnScale or NS.db.scale or 1)
            f:ClearAllPoints()
            f:SetPoint("CENTER", f._sourceBtn, "CENTER")
            slamBounceTarget = f
            slamBounceElapsed = 0
            slamBounceDurScaled = SLAM_BOUNCE_DUR * (f._gcdScale or 1)
            slamBounceDriver:Show()
            return  -- bounce driver handles cleanup + reveal
        end

        -- Fire particles on animation end (if configured)
        if f._fireParticlesOnEnd and f._sourceBtn and not f._isIncoming then
            NS.FireParticleBurst(f._sourceBtn, f._particleStyle, f._particlePalette, f._particleGcdScale)
        end

        f:Hide()
        f:ClearAllPoints()
        f:SetScale(1)  -- reset preScale from reverse animations

        local srcBtn = f._sourceBtn
        local isIncoming = f._isIncoming
        local hasPeer = f._hasIncomingPeer
        f._sourceBtn = nil
        f._animType = nil
        f._isIncoming = nil
        f._hasIncomingPeer = nil
        f._fireParticlesOnEnd = nil
        f._particleStyle = nil
        f._particlePalette = nil
        f._particleGcdScale = nil
        f._gcdScale = nil
        f._spellID = nil
        f._inUse = false

        if srcBtn then
            if isIncoming then
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                srcBtn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                elseif not hasPeer then
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                srcBtn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                end
        end
    end)

    f.ag = ag
    f._inUse = true
    f._acquireKind = "new"
    animPool[#animPool + 1] = f
    return f
end

-- Tracks active animation cycle (prevents ticker from overriding alpha)
NS._recreateFading = false

----------------------------------------------------------------
-- Play a cast animation — simultaneous outgoing + incoming clones
--
-- 1. Clone the button (icon, border, keybind text, size)
-- 2. Place the outgoing clone on top of the real button
-- 3. If incoming enabled, place incoming clone at offset position
-- 4. Hide the real button instantly (alpha 0)
-- 5. Start both animations simultaneously — incoming uses start
--    delays so it begins partway through the outgoing, creating
--    a seamless cross-fade where old and new spells overlap
-- 6. Outgoing OnFinished just cleans up (incoming handles reveal)
-- 7. Incoming OnFinished reveals the real button
----------------------------------------------------------------
function NS.PlayCastAnimation(spellID)
    local btn = NS.mainButton
    if not btn or not btn:IsShown() then return end

    local animType = NS.db and NS.db.castAnimation or "NONE"
    if animType == "NONE" then return end

    local config = ANIM_CONFIGS[animType]
    if not config then return end

    -- Cancel any in-progress landing bounce
    if slamBounceTarget then
        slamBounceTarget:SetScale(1)
        slamBounceTarget:Hide()
        slamBounceTarget:ClearAllPoints()
        slamBounceTarget._sourceBtn = nil
        slamBounceTarget._animType = nil
        slamBounceTarget._isIncoming = nil
        slamBounceTarget._spellID = nil
        slamBounceTarget._inUse = false
        slamBounceTarget = nil
        slamBounceDriver:Hide()
    end

    -- If a previous animation is still running, revoke its source reference
    -- so only the newest clone triggers the incoming animation
    if NS._recreateFading and NS.db.animHideButton ~= false then
        btn:SetAlpha(0)
    end
    -- Clear source reference on any in-flight animation frames
    for _, af in NS.ipairs(animPool) do
        if af._inUse and af._sourceBtn then
            af._sourceBtn = nil
        end
    end

    -- Always use the CAST spell's own texture.  Earlier events
    -- (SPELL_UPDATE_COOLDOWN, ASSISTED_COMBAT_ACTION_SPELL_CAST) fire
    -- before UNIT_SPELLCAST_SUCCEEDED, so by the time we get here
    -- btn.icon has already been updated to the NEXT recommendation.
    local tex
    if spellID then
        tex = NS.GetSpellTextureCached(spellID)
    end
    if not tex and btn.icon then
        tex = btn.icon:GetTexture()
    end
    if not tex then return end

    local anim = AcquireAnimFrame()
    -- Read actual button dimensions (not DB) so clone matches exactly,
    -- even if ApplyButtonSettings hasn't run yet or was deferred by combat.
    local size = btn:GetWidth()
    local btnScale = btn:GetScale()

    anim:SetSize(size, size)
    anim:SetScale(btnScale * 1.2)
    anim:ClearAllPoints()
    anim:SetPoint("CENTER", btn, "CENTER")

    -- 2. Icon texture
    anim.icon:SetTexture(tex)

    -- 3. Importance border color + backdrop (ColorTexture API — no BackdropTemplate)
    if not NS.masque and anim.bg then
        local bgColor = NS.db.buttonBgColor
        anim.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
    end
    if NS.db.importanceBorders and spellID then
        local borderColor = NS.GetSpellBorderColor(spellID)
        if borderColor then
            if anim.Border then
                anim.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                anim.Border:Show()
            elseif anim.borderTex then
                anim.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            end
        else
            if not NS.masque and anim.borderTex then
                anim.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
            end
        end
    else
        if not NS.masque and anim.borderTex then
            anim.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
        end
    end

    -- 5. ReSkin Masque at current size
    if anim._usesMasque then
        NS.masqueAnimGroup:ReSkin()
    end

    -- 6. Keybind text
    ApplyAnimHotkey(anim, spellID)
    DebugAnimClone("OUT", anim, spellID, btn)

    -- 7. Store references for OnFinished
    anim._sourceBtn = btn
    anim._animType = animType
    anim._isIncoming = false

    -- 7. Hide the real button instantly (unless user disabled hiding)
    if NS.db.animHideButton ~= false then
        btn:SetAlpha(0)
    end
    NS._recreateFading = true

    -- 8. Start outgoing animation immediately
    --    Show at alpha 0 first, then play — the animation's SetFromAlpha(1)
    --    sets opacity on the first rendered frame, preventing a flash where
    --    both the clone and button are visible at full size.
    local g = (NS.db.gcdDuration or 1.9) / BASE_GCD
    anim:SetAlpha(0)
    anim:Show()
    anim.ag:Stop()
    config(anim.ag, g)
    anim.ag:Play()

    -- 8b. Particle burst — fires based on per-animation particle config
    local animKey = NS.AnimKeyPrefix(animType)
    local particlesOn = NS.db[animKey .. "Particles"]
    local particleStyle = NS.db[animKey .. "ParticleStyle"] or "Confetti"
    local particlePalette = NS.db[animKey .. "ParticlePalette"] or "Confetti"
    local particleTiming = NS.db[animKey .. "ParticleTiming"] or "On Cast"

    if particlesOn and particleStyle ~= "None" then
        if particleTiming == "Specific" then
            local delay = NS.db[animKey .. "ParticleDelay"] or 0.3
            NS.C_Timer_After(delay, function()
                NS.FireParticleBurst(btn, particleStyle, particlePalette, g)
            end)
        else
            if particleTiming == "On Cast" or particleTiming == "Both" then
                NS.FireParticleBurst(btn, particleStyle, particlePalette, g)
            end
            if particleTiming == "On Animation End" or particleTiming == "Both" then
                anim._fireParticlesOnEnd = true
                anim._particleStyle = particleStyle
                anim._particlePalette = particlePalette
                anim._particleGcdScale = g
            end
        end
    end

    -- 9. Defer incoming clone creation — the SBA API needs a frame to
    --    update its recommendation after UNIT_SPELLCAST_SUCCEEDED.
    --    The incoming animation has built-in start delays (0.30–0.40s)
    --    anyway, so a 0.05s API delay is invisible.
    local reverseConfig = REVERSE_ANIM_CONFIGS[animType]
    if NS.db.animateIncoming and reverseConfig then
        -- Mark that we expect an incoming peer (prevents outgoing's
        -- OnFinished from revealing the button if it finishes first)
        anim._hasIncomingPeer = true

        NS.C_Timer_After(0.05, function()
            -- Bail if the outgoing was cancelled (new animation started)
            if not anim._sourceBtn then
                -- Outgoing was orphaned — no peer expected anymore
                return
            end

            -- Re-query: btn.spellID should now reflect the NEXT recommendation
            NS.UpdateNow()
            local nextSpellID = btn.spellID
            local nextTex
            if nextSpellID then nextTex = NS.GetSpellTextureCached(nextSpellID) end
            if not nextTex and btn.icon then nextTex = btn.icon:GetTexture() end

            if not nextTex then
                -- Can't get next spell — reveal button now
                anim._hasIncomingPeer = false
                local targetAlpha = InCombatLockdown()
                    and (NS.db.alphaCombat or 1)
                    or  (NS.db.alphaOOC or 1)
                btn:SetAlpha(targetAlpha)
                NS._recreateFading = false
                return
            end

            local incoming = AcquireAnimFrame()
            local ox, oy = reverseConfig.offset[1], reverseConfig.offset[2]

            incoming:SetSize(size, size)
            incoming:SetScale((reverseConfig.preScale or 1) * btnScale)
            incoming._btnScale = btnScale
            incoming:ClearAllPoints()
            incoming:SetPoint("CENTER", btn, "CENTER", ox, oy)
            incoming.icon:SetTexture(nextTex)

            -- Background + importance border
            if not NS.masque and incoming.bg then
                local bgColor = NS.db.buttonBgColor
                incoming.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
            end
            if NS.db.importanceBorders and nextSpellID then
                local borderColor = NS.GetSpellBorderColor(nextSpellID)
                if borderColor then
                    if incoming.Border then
                        incoming.Border:SetVertexColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                        incoming.Border:Show()
                    elseif incoming.borderTex then
                        incoming.borderTex:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
                    end
                else
                    if not NS.masque and incoming.borderTex then
                        incoming.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
                    end
                end
            else
                if not NS.masque and incoming.borderTex then
                    incoming.borderTex:SetColorTexture(NS.THEME.BORDER[1], NS.THEME.BORDER[2], NS.THEME.BORDER[3], 1)
                end
            end

            if incoming._usesMasque then NS.masqueAnimGroup:ReSkin() end

            ApplyAnimHotkey(incoming, nextSpellID)
            DebugAnimClone("IN", incoming, nextSpellID, btn)

            incoming._sourceBtn = btn
            incoming._animType = animType
            incoming._isIncoming = true
            incoming._gcdScale = g

            -- Ensure incoming renders ON TOP of outgoing during overlap
            incoming:SetFrameLevel(anim:GetFrameLevel() + 5)
            incoming:Show()
            incoming:SetAlpha(0)  -- invisible during start delay period
            incoming.ag:Stop()
            local adjustedDelay = math.max(0, reverseConfig.delay * g - 0.05)
            reverseConfig.setup(incoming.ag, adjustedDelay, g)
            incoming.ag:Play()
        end)
    end
end

----------------------------------------------------------------
-- Preview mode (/bs preview — showcases all visual effects)
----------------------------------------------------------------
do
    local previewTicker = nil
    local previewGlowTicker = nil
    local previewStep = 0

    -- Importance tiers to cycle through on priority icons
    local IMPORTANCE_KEYS = { "AUTO_ATTACK", "FILLER", "SHORT_CD", "LONG_CD", "MAJOR_CD" }

    -- Demo spell textures (generic class-neutral icons)
    local DEMO_TEXTURES = {
        136048,   -- Spell_Nature_StarFall
        135753,   -- Spell_Fire_FlameBolt
        136197,   -- Spell_Nature_Lightning
        132369,   -- Spell_Shadow_DemonBreath
        134400,   -- Spell_Frost_FrostBolt02
        135963,   -- Spell_Shadow_ShadowBolt
    }

    function NS.StartPreviewMode()
        if previewTicker then
            print("|cFF66B8D9BetterSBA|r: Preview already running — |cFFFFCC00/bs stop|r to end")
            return
        end

        local btn = NS.mainButton
        if not btn then
            print("|cFF66B8D9BetterSBA|r: Main button not ready")
            return
        end

        -- Show button + priority display unconditionally
        btn:Show()
        btn:SetAlpha(1)
        if NS.priorityFrame then
            NS.priorityFrame:Show()
            NS.priorityFrame:SetAlpha(1)
        end

        -- Set up demo textures on priority icons
        local icons = NS._priorityIcons
        if icons then
            for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                icons[i].tex:SetTexture(DEMO_TEXTURES[i])
                icons[i].tex:SetDesaturated(false)
                icons[i].tex:SetVertexColor(1, 1, 1)
                icons[i]:Show()
            end
            NS.LayoutPriority()
        end

        print("|cFF66B8D9BetterSBA|r: |cFF44FF44Preview mode ON|r — type |cFFFFCC00/bs stop|r to end")

        previewStep = 0

        local previewG = (NS.db.gcdDuration or 1.9) / BASE_GCD
        previewTicker = NS.C_Timer_NewTicker(2.5 * previewG, function()
            previewStep = previewStep + 1

            -- Play cast animation
            NS.PlayCastAnimation(NS.SBA_SPELL_ID)

            -- Cycle importance border colors on priority icons
            if icons and NS.db.importanceBorders then
                for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                    local icon = icons[i]
                    if icon:IsShown() then
                        local impIdx = ((previewStep + i - 1) % #IMPORTANCE_KEYS) + 1
                        local impKey = IMPORTANCE_KEYS[impIdx]
                        local color = NS.SPELL_IMPORTANCE[impKey]
                        if icon.Border then
                            icon.Border:SetVertexColor(color[1], color[2], color[3], 1)
                            icon.Border:Show()
                        elseif icon.borderTex then
                            icon.borderTex:SetColorTexture(color[1], color[2], color[3], 1)
                        end
                    end
                end
            end
        end)

        -- Border color cycling ticker (cycles importance colors on borders at 1.5s)
        previewGlowTicker = NS.C_Timer_NewTicker(1.5, function()
            if not icons then return end
            previewStep = previewStep + 1

            for i = 1, math.min(#icons, #DEMO_TEXTURES) do
                local icon = icons[i]
                if icon:IsShown() then
                    local impIdx = ((previewStep + i) % #IMPORTANCE_KEYS) + 1
                    local impKey = IMPORTANCE_KEYS[impIdx]
                    local brightColor = NS.SPELL_IMPORTANCE_BRIGHT[impKey]

                    if icon.Border then
                        icon.Border:SetVertexColor(brightColor[1], brightColor[2], brightColor[3], 1)
                        icon.Border:Show()
                    elseif icon.borderTex then
                        icon.borderTex:SetColorTexture(brightColor[1], brightColor[2], brightColor[3], 1)
                    end
                end
            end
        end)

        -- Fire initial burst immediately
        NS.PlayCastAnimation(NS.SBA_SPELL_ID)
    end

    function NS.StopPreviewMode()
        if not previewTicker and not previewGlowTicker then
            print("|cFF66B8D9BetterSBA|r: No preview running")
            return
        end

        if previewTicker then
            previewTicker:Cancel()
            previewTicker = nil
        end
        if previewGlowTicker then
            previewGlowTicker:Cancel()
            previewGlowTicker = nil
        end

        -- Reset priority icon borders
        local icons = NS._priorityIcons
        if icons then
            for i = 1, #icons do
                icons[i]._wantGlow = false
            end
        end

        -- Restore normal display state
        NS.UpdateNow()
        print("|cFF66B8D9BetterSBA|r: |cFFFF4444Preview mode OFF|r")
    end
end
