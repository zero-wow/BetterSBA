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

-- Exercise the real priority update: unknown/restricted cooldowns must not be
-- converted into a ready glow. Blizzard's explicit next-cast remains distinct.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
mock.install()
local restricted = setmetatable({}, { __index = function() error("secret cooldown") end })
local cooldowns = { [502] = restricted, [503] = { duration = 120 }, [504] = { duration = 0 }, [505] = { duration = 1 } }
ns.THEME.NEON_NEXT, ns.THEME.TEXT_DIM, ns.THEME.BG_DARK = { .2, .8, 1 }, { .5, .5, .5 }, { 0, 0, 0 }
ns.db = { showPriority = true, showActiveGlow = true, priorityIconSize = 30, prioritySpacing = 4,
    priorityBorderColor = { .1, .1, .1 }, priorityBgColor = { 0, 0, 0 }, priorityLabelFontSize = 10, priorityKeybindFontSize = 10 }
ns.CreateFrame, ns.UIParent, ns.unpack, ns.ipairs = CreateFrame, UIParent, table.unpack, ipairs
ns.ICON_TEXCOORD = { 0, 1, 0, 1 }
ns.ResolveFontPath = function() return "font" end
ns.ResolveFontOutline = function() return "OUTLINE" end
ns.ApplyButtonStyle = function() end
ns.CollectNextSpell = function() return 506 end
ns.CollectRotationSpells = function() return { 501, 502, 503, 504, 505, 506 } end
ns.GetSpellBaseCooldown = function() return 120 end
ns.GetSpellImportanceKey = function() return "MAJOR_CD" end
ns.GetSpellBorderColorBright = function() return { 1, .5, 0 } end
ns.GetCooldownCached = function(id) return cooldowns[id] end
ns.GetSpellTextureCached = function() return "texture" end
assert(loadfile("GUI/PriorityDisplay.lua"))("BetterSBA", ns)
ns:CreatePriorityDisplay()
for _, icon in ipairs(ns._priorityIcons) do icon.Border = false end -- No Masque regions in this fixture.
ns.UpdatePriorityDisplay()
local icons = {}
for _, icon in ipairs(ns._priorityIcons) do icons[icon.spellID] = icon end
assert(not icons[501]._wantGlow and not icons[502]._wantGlow, "missing and secret cooldowns must never glow as ready")
assert(not icons[503]._wantGlow, "a known active long cooldown must not glow")
assert(icons[504]._wantGlow and icons[505]._wantGlow, "known ready/GCD-only cooldowns retain their glow")
assert(icons[506]._wantGlow, "Blizzard's next-cast recommendation retains its explicit highlight")
ns.IsCooldownShortOrReady = nil
ns.UpdatePriorityDisplay()
assert(not icons[504]._wantGlow and icons[506]._wantGlow, "missing readiness helper must fail closed without suppressing next-cast")

print("PASS: native cooldown visuals/cache and real priority glows fail closed for unknown or secret cooldowns")
