local calls = { charge = {}, cooldown = {}, base = {} }
local chargeDuration = { kind = "charge" }
local normalDurationA = { kind = "normal-a" }
local normalDurationB = { kind = "normal-b" }
local normalRevision = 1

C_Spell = {
    GetSpellCooldown = function() return nil end,
    GetSpellChargeDuration = function(spellID)
        calls.charge[spellID] = (calls.charge[spellID] or 0) + 1
        if spellID == 101 then return chargeDuration end
        if spellID == 303 then error("restricted") end
        return nil
    end,
    GetSpellCooldownDuration = function(spellID, ignoreGCD)
        assert(ignoreGCD == true, "visual cooldowns must ignore the GCD")
        calls.cooldown[spellID] = (calls.cooldown[spellID] or 0) + 1
        if spellID == 202 then
            return normalRevision == 1 and normalDurationA or normalDurationB
        end
        if spellID == 303 then error("restricted") end
        return nil
    end,
    GetSpellBaseCooldown = function(spellID)
        calls.base[spellID] = (calls.base[spellID] or 0) + 1
        if spellID == 400 then return 0 end
        return nil
    end,
}

local ns = { C_Spell = C_Spell, pcall = pcall, THEME = {} }
assert(loadfile("Core/Functions/Spells.lua"))("BetterSBA", ns)
assert(loadfile("Core/Functions/Display.lua"))("BetterSBA", ns)

ns.BeginUpdate()
assert(ns.GetCooldownDurationCached(101) == chargeDuration, "charge recharge must win")
assert(ns.GetCooldownDurationCached(202) == normalDurationA, "normal cooldown object expected")
assert(calls.charge[101] == 1 and calls.cooldown[101] == nil)
assert(calls.charge[202] == 1 and calls.cooldown[202] == 1)
ns.EndUpdate()
assert(ns.GetCooldownDurationCached(101) == chargeDuration)
assert(ns.GetCooldownDurationCached(202) == normalDurationA)
assert(calls.charge[101] == 1 and calls.cooldown[202] == 1, "objects cache between invalidations")

local handedOff, cleared = nil, 0
local widget = {
    SetCooldownFromDurationObject = function(_, duration) handedOff = duration end,
    Clear = function() cleared = cleared + 1 end,
}
assert(ns.SetSpellCooldownVisual(widget, 101))
assert(handedOff == chargeDuration, "widget receives native charge duration object identity")
assert(ns.SetSpellCooldownVisual(widget, 202))
assert(handedOff == normalDurationA, "widget receives native cooldown duration object identity")

ns.BeginUpdate()
assert(ns.GetCooldownDurationCached(303) == nil, "restricted timing stays unknown")
assert(ns.GetCooldownDurationCached(303) == nil, "unknown result is cached for this update")
ns.EndUpdate()
local failedCalls = (calls.charge[303] or 0) + (calls.cooldown[303] or 0)
assert(ns.GetCooldownDurationCached(303) == nil)
assert((calls.charge[303] or 0) + (calls.cooldown[303] or 0) == failedCalls, "no repeated failure between invalidations")
assert(not ns.SetSpellCooldownVisual(widget, 303) and cleared == 1, "unknown visual clears safely")

assert(ns.GetSpellBaseCooldown(400) == 0, "valid zero base cooldown is preserved")
assert(ns.GetSpellBaseCooldown(400) == 0)
assert(calls.base[400] == 1, "valid zero base cooldown is cached")

ns.InvalidateCooldownCache()
ns.BeginUpdate()
normalRevision = 2
assert(ns.GetCooldownDurationCached(202) == normalDurationB, "invalidation replaces native duration object")
ns.EndUpdate()
assert(calls.charge[202] == 2 and calls.cooldown[202] == 2, "invalidation refreshes duration cache")

print("PASS: native cooldown duration objects, charge recharge, secret unknowns, and zero base cooldown caching")
