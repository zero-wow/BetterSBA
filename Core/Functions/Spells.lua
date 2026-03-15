local ADDON_NAME, NS = ...

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
-- Spec lookup: maps friendly name â†’ { classToken, specIndex }
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
-- Textures never change during gameplay â€” cache permanently and
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
-- a NEW table (~200 bytes) every call â€” pure garbage.  We cache
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
                -- Still on CD â€” return virtual data in the same shape as API
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
                -- Virtual entry expired â€” remove it
                virtualCD[spellID] = nil
            end
        end
    end

    local cached = cdCache[spellID]

    -- Fast path: cache is clean â€” return whatever we have
    if not cdCacheDirty and cached then
        if cached == CACHE_NIL then return nil end
        return cached
    end

    -- Dirty but already refreshed this spell THIS tick â€” dedup
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
                    -- API says it's ready but virtual says on CD â†’ was reset by a proc
                    virtualCD[sid] = nil
                else
                    -- Update with API's values (may differ due to haste changes)
                    entry.startTime = tonumber(tostring(cdInfo.startTime)) or entry.startTime
                    entry.duration = dur
                end
            end
        else
            -- Expired â€” clear
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
-- This spreads GC work across allocations with zero spikes â€” no manual
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
    -- Cooldown cache is event-driven â€” no wipe needed.
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
    -- Rotation changed â€” virtual CD data may be stale, re-seed when possible
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
--   4. Return nil â†’ caller should filter this spell out
--
-- Results are cached in resolveCache, invalidated on spec/spell changes.
----------------------------------------------------------------
local SUBS_PREFIX = "|cFF66B8D9[BetterSBA Subs]|r "

local function SubsDebugPrint(...)
    if not NS.IsDebugChannelEnabled("spell") then return end
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
        -- Manual sub target is also bad â€” fall through to auto-resolution
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

    -- 4. Can't resolve â€” filter out
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = NS.pcall(C_Spell.GetSpellName, spellID)
        if ok then name = n end
    end
    SubsDebugPrint("FILTERED:", spellID, name and ("(" .. name .. ")") or "", "â€” no texture/override")
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

    -- GetNextCastSpell WITHOUT visible check first â€” our button isn't
    -- registered via SetActionUIButton so the visible check would fail
    if ac.GetNextCastSpell then
        local ok, sid = NS.pcall(ac.GetNextCastSpell, false)
        if ok and sid and sid ~= 0 then
            sid = NS.ResolveSpellID(sid) or sid
            NS.DebugPrint("GetNextCastSpell(false) â†’", sid)
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
            NS.DebugPrint("GetActionSpell() â†’", sid)
            cachedNextSpell = sid
            cachedNextGen = updateGeneration
            return sid
        end
        NS.DebugPrint("GetActionSpell():", ok and ("returned " .. NS.tostring(sid)) or "ERROR")
    else
        NS.DebugPrint("|cFFFF4444GetActionSpell does not exist|r")
    end

    -- GetNextCastSpell WITH visible check â€” works if SBA is on a Blizzard bar
    if ac.GetNextCastSpell then
        local ok, sid = NS.pcall(ac.GetNextCastSpell, true)
        if ok and sid and sid ~= 0 then
            sid = NS.ResolveSpellID(sid) or sid
            NS.DebugPrint("GetNextCastSpell(true) â†’", sid)
            cachedNextSpell = sid
            cachedNextGen = updateGeneration
            return sid
        end
        NS.DebugPrint("GetNextCastSpell(true):", ok and ("returned " .. NS.tostring(sid)) or "ERROR")
    end

    -- Last resort: first rotation spell (uses cached rotation if available)
    local spells = NS.CollectRotationSpells()
    if spells[1] and spells[1] ~= 0 then
        NS.DebugPrint("Rotation spell fallback â†’", spells[1])
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
-- Pure string return â€” no tables, no closures, no taint-sensitive values.
local function resolveSpellName(spellID, fallback)
    local name = NS.C_Spell and NS.C_Spell.GetSpellName
        and NS.C_Spell.GetSpellName(spellID) or fallback
    return name
end

function NS.BuildMacroText()
    local lines = {}
    local db = NS.db

    -- Channel protection FIRST â€” abort the entire macro while channeling
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
    -- These all fire because they are off the GCD â€” SBA consuming the
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
