-- Regression coverage for the combat-assist macro builder.
-- Run from the addon root with: lua tests/test_combat_assist.lua

local combat = false
local classToken, specIndex = "WARRIOR", 3
local known = {}
local secureWrites, interceptWrites = 0, 0

C_Timer = { After = function() end }
InCombatLockdown = function() return combat end
UnitClass = function() return "Tester", classToken end
GetSpecialization = function() return specIndex end
IsPlayerSpell = function(id) return known[id] == true end
C_SpellBook = {
    IsSpellKnownOrInSpellBook = function(id) return known[id] == true end,
}
C_Spell = {
    GetSpellName = function(id)
        return ({
            [1229376] = "Single-Button Assistant",
            [203720] = "Demon Spikes",
            [391528] = "Convoke the Spirits",
            [192081] = "Ironfur",
            [2565] = "Shield Block",
            [190456] = "Ignore Pain",
            [53600] = "Shield of the Righteous",
            [194679] = "Rune Tap",
            [119582] = "Purifying Brew",
        })[id]
    end,
}

local NS
NS = {
    pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
    pcall = pcall, table_concat = table.concat, unpack = table.unpack,
    db = {}, InCombatLockdown = function() return combat end,
    GetTrinketStatus = function() return nil end,
    secureButton = {
        SetAttribute = function(_, key, value)
            assert(key == "macrotext")
            secureWrites = secureWrites + 1
            NS._secureMacro = value
        end,
    },
}
_G.BetterSBA = NS
local loadConstants = assert(loadfile("Core/Constants.lua"))
loadConstants("BetterSBA", NS)
for key, value in pairs(NS.defaults) do NS.db[key] = value end
NS.db.trinketMode = "Off"
NS.db.enableIgnorePain = true
NS.db.enableRuneTap = true
NS.db.enablePurifyingBrew = true
assert(NS.defaults.enableConvokeTheSpirits == false, "new profiles default Convoke off")
local loadSpells = assert(loadfile("Core/Functions/Spells.lua"))
loadSpells("BetterSBA", NS)

local function setKnown(...)
    known = {}
    for i = 1, select("#", ...) do known[select(i, ...)] = true end
end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end
local function actionText()
    local actions = NS.GetMacroActions()
    local lines = {}
    for i = 1, #actions do lines[i] = actions[i].text end
    return actions, table.concat(lines, "\n")
end

-- Every supported tank injects only for its matching class/spec, and Convoke
-- is present for all four Druid specs when learned.
local cases = {
    { "DEMONHUNTER", 2, NS.DEMON_SPIKES_SPELL_ID, "Demon Spikes" },
    { "WARRIOR", 3, NS.SHIELD_BLOCK_SPELL_ID, "Shield Block" },
    { "PALADIN", 2, NS.SHIELD_OF_RIGHTEOUS_ID, "Shield of the Righteous" },
    { "DEATHKNIGHT", 1, NS.RUNE_TAP_SPELL_ID, "Rune Tap" },
    { "MONK", 1, NS.PURIFYING_BREW_SPELL_ID, "Purifying Brew" },
}
for _, case in ipairs(cases) do
    classToken, specIndex = case[1], case[2]
    setKnown(case[3], NS.SBA_SPELL_ID)
    local _, macro = actionText()
    assert(has(macro, case[4]), "matching tank spell missing: " .. case[4])
    for _, other in ipairs(cases) do
        if other[1] ~= case[1] then
            assert(not has(macro, other[4]), "wrong class/spec spell emitted: " .. other[4])
        end
    end
end

classToken = "DRUID"
NS.db.enableConvokeTheSpirits = true -- explicit opt-in, despite the new default
for druidSpec = 1, 4 do
    specIndex = druidSpec
    setKnown(NS.CONVOKE_THE_SPIRITS_ID, NS.SBA_SPELL_ID)
    local _, macro = actionText()
    assert(has(macro, "Convoke the Spirits"), "Convoke missing for Druid spec " .. specIndex)
end

-- Older clients use IsPlayerSpell; when neither known-spell API exists,
-- optional actions are conservatively omitted.
C_SpellBook.IsSpellKnownOrInSpellBook = nil
classToken, specIndex = "DRUID", 1
setKnown(NS.CONVOKE_THE_SPIRITS_ID, NS.SBA_SPELL_ID)
local _, legacyConvokeMacro = actionText()
assert(has(legacyConvokeMacro, "Convoke the Spirits"), "legacy IsPlayerSpell fallback missing")
setKnown(NS.SBA_SPELL_ID)
local _, unavailableConvokeMacro = actionText()
assert(not has(unavailableConvokeMacro, "Convoke the Spirits"), "unknown spell API must fail closed")

-- Learned-spell filtering applies to every optional class action.
classToken, specIndex = "WARRIOR", 3
setKnown(NS.SBA_SPELL_ID)
local _, missingMacro = actionText()
assert(not has(missingMacro, "Shield Block"), "unlearned class spell must be omitted")
NS.db.enableShieldBlock = false
setKnown(NS.SBA_SPELL_ID, NS.SHIELD_BLOCK_SPELL_ID)
local _, disabledMacro = actionText()
assert(not has(disabledMacro, "Shield Block"), "disabled class option must be omitted")
NS.db.enableShieldBlock = true
-- The learned check is applied uniformly to every class-specific action.
for _, optional in ipairs(cases) do
    classToken, specIndex = optional[1], optional[2]
    setKnown(NS.SBA_SPELL_ID)
    local _, omittedMacro = actionText()
    assert(not has(omittedMacro, optional[4]), "unlearned optional spell emitted: " .. optional[4])
end
classToken, specIndex = "DRUID", 3
setKnown(NS.SBA_SPELL_ID)
local _, missingIronfurMacro = actionText()
assert(not has(missingIronfurMacro, "Ironfur"), "unlearned Ironfur emitted")

classToken, specIndex = "DRUID", 1
NS.db.enableConvokeTheSpirits = false
setKnown(NS.SBA_SPELL_ID, NS.CONVOKE_THE_SPIRITS_ID)
local _, convokeDisabledMacro = actionText()
assert(not has(convokeDisabledMacro, "Convoke the Spirits"), "disabled Convoke option must be omitted")
NS.db.enableConvokeTheSpirits = true

-- Approved trinkets follow the same channel gate while retaining combat and
-- target safety conditions.
NS.db.trinketMode = "Approved"
NS.GetTrinketStatus = function() return { eligible = true, name = "Test Trinket" } end
NS.db.enableChannelProtection = true
local _, trinketOnMacro = actionText()
assert(has(trinketOnMacro, "/use [combat,harm,nodead,nochanneling] 13"))
NS.db.enableChannelProtection = false
local _, trinketOffMacro = actionText()
assert(has(trinketOffMacro, "/use [combat,harm,nodead] 13"))
assert(not has(trinketOffMacro, "nochanneling"))
NS.db.trinketMode = "Off"

-- Channel protection owns both the stopmacro guard and cast-line conditions.
setKnown(NS.SBA_SPELL_ID, NS.SHIELD_BLOCK_SPELL_ID)
NS.db.enableChannelProtection = true
local actionsOn, macroOn = actionText()
assert(actionsOn[1].text == "/stopmacro [channeling]")
assert(has(macroOn, "[nochanneling]"), "protected macro should gate casts")
NS.db.enableChannelProtection = false
local actionsOff, macroOff = actionText()
assert(actionsOff[1].text ~= "/stopmacro [channeling]")
assert(not has(macroOff, "nochanneling"), "disabled channel protection must remove cast gates")

-- Pet attack is constrained to a valid hostile living target.
classToken, specIndex = "HUNTER", 1
NS.db.enableChannelProtection = true
setKnown(NS.SBA_SPELL_ID)
local _, petMacro = actionText()
assert(has(petMacro, "/petattack [pet,harm,nodead]"), "petattack needs target/pet safety conditions")

-- Preview and secure macro consume the same ordered action text. Rebuilds in
-- combat defer the protected write and do not touch either secure button.
local _, previewMacro = actionText()
assert(NS.BuildMacroText() == previewMacro, "preview and macro text diverged")
local intercept = { IsShown = function() return true end, SetAttribute = function(_, key, value)
    assert(key == "macrotext")
    interceptWrites = interceptWrites + 1
    NS._interceptMacro = value
end }
_G["BetterSBA_ClickIntercept"] = intercept
combat = true
NS.RebuildMacroText()
assert(NS._pendingMacroRebuild == true and secureWrites == 0 and interceptWrites == 0,
    "combat rebuild must defer protected writes")
combat = false
NS.RebuildMacroText()
assert(secureWrites == 1 and interceptWrites == 1)
assert(NS._secureMacro == NS._interceptMacro and NS._secureMacro == NS.BuildMacroText(),
    "secure and intercept macro identities must match")

print("combat assist regression mocks: ok")
