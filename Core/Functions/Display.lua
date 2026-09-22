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
    return cdInfo.duration > threshold
end
local function _durLE(cdInfo, threshold)
    return cdInfo.duration <= threshold
end
NS._durGT = _durGT

-- Secret cooldown values must remain opaque to Lua. These helpers only return
-- a result when Blizzard permits the comparison; nil means unknown, never 0.
function NS.IsCooldownLong(cdInfo, threshold)
    if not cdInfo then return nil end
    local ok, result = pcall(_durGT, cdInfo, threshold or 1.5)
    if not ok then return nil end
    return result
end

function NS.IsCooldownShortOrReady(cdInfo, threshold)
    if not cdInfo then return nil end
    local ok, result = pcall(_durLE, cdInfo, threshold or 1.5)
    if not ok then return nil end
    return result
end

-- CooldownFrame natively accepts the duration object returned by C_Spell.
-- Passing that object through preserves secret values without coercion.
function NS.SetSpellCooldownVisual(cooldown, spellID)
    if not cooldown then return false end
    local duration = spellID and NS.GetCooldownDurationCached and NS.GetCooldownDurationCached(spellID)
    if cooldown.SetCooldownFromDurationObject then
        if duration then
            local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
            if ok then return true end
        end
        cooldown:Clear()
        return false
    end
    -- Retail provides SetCooldownFromDurationObject. This fallback is for an
    -- older widget only and never feeds a SpellCooldownInfo into the native API.
    local cdInfo = spellID and NS.GetCooldownCached(spellID)
    if not cdInfo then cooldown:Clear(); return false end
    local ok = pcall(cooldown.SetCooldown, cooldown, cdInfo.startTime, cdInfo.duration)
    if ok then return true end
    cooldown:Clear()
    return false
end

----------------------------------------------------------------
-- Spell importance classification (base cooldown cache)
----------------------------------------------------------------
local baseCDCache = {}
local baseCDCacheCount = 0
local MAX_CD_CACHE = 200  -- cap to prevent unbounded growth

local function _baseCooldownSeconds(ms)
    if ms >= 0 then return ms / 1000 end
end

local function GetBaseCooldownSeconds(ms)
    local ok, seconds = pcall(_baseCooldownSeconds, ms)
    if ok then return seconds end
    return nil
end

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
            local sec = GetBaseCooldownSeconds(ms)
            if sec then
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
            local sec = GetBaseCooldownSeconds(baseCDms)
            if sec then
                baseCDCache[spellID] = sec
                baseCDCacheCount = baseCDCacheCount + 1
                return sec
            end
        end
    end

    -- No valid API result â€” retry next time. A valid zero is cached above.
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

    -- Blizzard's next-spell authority already accounts for charges, cooldown
    -- resets, and resource rules. Do not replace it with local prediction.
    return recommended
end
