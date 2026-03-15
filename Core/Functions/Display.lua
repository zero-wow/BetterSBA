local ADDON_NAME, NS = ...

----------------------------------------------------------------
-- Taint-safe comparison helpers.  WoW's taint system makes
-- C_Spell cooldown fields "secret numbers" that throw errors on
-- Lua comparison operators (>, <, <=).  Wrapping in pcall lets
-- us safely compare â€” if tainted, pcall returns false and we
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

    -- Don't cache zero â€” retry next time
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

-- Map importance key â†’ db color key
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
    local slot = NS.GetCachedSBASlot() or NS.FindSBAActionSlot()
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

    NS.DebugPrint("ActionBar texture matched |cFFFF4444no rotation spell|r â€” using raw texture")
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
        NS.DebugPrint("API returned nothing â€” trying action bar fallback")
        local abSpell, abTex = NS.GetDisplaySpellFromActionBar()
        if abSpell then
            recommended = abSpell
        elseif abTex then
            -- Have action bar texture but couldn't match spell ID
            NS._fallbackTexture = abTex
            return nil
        end
    end

    -- Nothing recommended â†’ auto-attack
    if not recommended or recommended == 0 then
        NS._fallbackTexture = nil
        NS.DebugPrint("Final result: |cFFFF4444auto-attack fallback|r")
        return NS.AUTO_ATTACK_SPELL_ID
    end

    NS._fallbackTexture = nil

    -- Check if recommended is on a real cooldown (uses per-tick cache
    -- to avoid creating a new API table on every call).
    -- pcall guards all comparisons â€” cdInfo fields may be tainted
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
            -- Nothing ready â†’ auto-attack
            return NS.AUTO_ATTACK_SPELL_ID
        end
    end

    return recommended
end
