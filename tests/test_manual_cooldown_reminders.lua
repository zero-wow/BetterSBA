-- Run from the addon root: lua tests/test_manual_cooldown_reminders.lua
-- Covers catalog-target matching, native cooldown display state, and compact
-- frame bounds without performing any cast operation.

local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local theme = {
    BG_DARK = {.02, .03, .04, 1}, ACCENT_DIM = {.2, .45, .65, 1},
    TEXT = {.9, .9, .9, 1}, TEXT_DIM = {.6, .6, .6, 1}, TEXT_MUTED = {.4, .4, .4, 1},
    TOGGLE_ON = {.2, .8, .5, 1},
}
local readyState = true
local known = true
local cooldownCalls = {}
local mainButton = ui.createFrame("Button", "BetterSBA_TestMain", ui.uiParent)
mainButton:SetSize(24, 24)
mainButton:SetPoint("CENTER", ui.uiParent, "CENTER", 0, 0)

local NS = {
    THEME = theme, UIParent = ui.uiParent, CreateFrame = ui.createFrame,
    db = { manualCooldownReminders = true },
    ipairs = ipairs, pairs = pairs, pcall = pcall, unpack = table.unpack,
    ICON_TEXCOORD = {0.08, 0.92, 0.08, 0.92},
    TALENT_BUILD_CUSTOM_ID = "CUSTOM", mainButton = mainButton,
    InCombatLockdown = function() return false end,
    GetConfigFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
    C_Spell = {
        GetSpellName = function(id) return ({[190319] = "Localized Combustion", [10060] = "Localized Power Infusion", [191427] = "Localized Metamorphosis"})[id] end,
        GetSpellTexture = function(id) return "spell:" .. tostring(id) end,
    },
    GetSpellTextureCached = function(id) return "cached:" .. tostring(id) end,
    IsCombatAssistSpellKnown = function() return known end,
    GetTalentBuildCurrentSpecID = function() return 63 end,
    GetTalentBuildSpecName = function() return "Fire" end,
    GetTalentLevelingState = function() return {buildID = "BSBA-WH-SBA-COMPATIBLE-63-TARGETED-20260924"} end,
    FindTalentBuildByID = function() return {name = "Fire SBA Starter"} end,
    GetCooldownCached = function() return { duration = readyState == nil and "secret" or (readyState and 0 or 120) } end,
    IsCooldownShortOrReady = function(_, threshold)
        assert(threshold == 0, "manual reminder may say READY only at zero cooldown")
        return readyState
    end,
    SetSpellCooldownVisual = function(_, spellID) cooldownCalls[#cooldownCalls + 1] = spellID; return true end,
}

assert(loadfile("Core/ManualCooldownData.lua"))("BetterSBA", NS)
assert(loadfile("GUI/ManualCooldownReminders.lua"))("BetterSBA", NS)
assert(NS.GetManualCooldownReminderForTarget(258, "WH-SBA-COMPATIBLE-258-20260812").spellID == 10060
    and NS.GetManualCooldownReminderForTarget(577, "ICY-577-sba-fel-scarred-raid").spellID == 191427
    and NS.GetManualCooldownReminderForTarget(1480, "ICY-1480-sba-annihilator-single-target") == nil,
    "only reviewed targets with a native manual cooldown may expose a reminder")

NS.UpdateManualCooldownReminder()
local frame = assert(NS.manualCooldownReminderFrame, "eligible selected catalog target must create its reminder")
assert(frame:IsShown() and frame._clamped and rawget(frame._spellName, "_text") == "Localized Combustion",
    "eligible target must show a localized manual cooldown reminder")
assert(rawget(frame._context, "_text"):find("Fire", 1, true)
    and rawget(frame._context, "_text"):find("Fire SBA Starter", 1, true)
    and rawget(frame._status, "_text") == "READY — PRESS MANUALLY"
    and cooldownCalls[#cooldownCalls] == 190319,
    "ready reminder must retain target context and use a native cooldown visual")

readyState = false
NS.UpdateManualCooldownReminder()
assert(rawget(frame._status, "_text") == "ON COOLDOWN — PRESS MANUALLY",
    "known non-ready cooldown must not be shown as ready")
readyState = nil
NS.UpdateManualCooldownReminder()
assert(rawget(frame._status, "_text") == "COOLDOWN UNKNOWN",
    "unavailable or secret cooldown state must never be presented as ready")

known = false
NS.UpdateManualCooldownReminder()
assert(not frame:IsShown(), "unlearned manual cooldown must not show a reminder")
known = true
NS.GetTalentLevelingState = function() return {buildID = "CUSTOM"} end
NS.UpdateManualCooldownReminder()
assert(not frame:IsShown(), "custom or unselected targets must not show a catalog reminder")
NS.db.manualCooldownReminders = false
NS.UpdateManualCooldownReminder()
assert(not frame:IsShown(), "opt-out must hide the reminder immediately")
NS.db.manualCooldownReminders, NS.db.enabled = true, false
NS.UpdateManualCooldownReminder()
assert(not frame:IsShown(), "disabling BetterSBA must hide its manual reminder")

local fl, ft, fr, fb = mock.rect(frame)
for _, child in ipairs({frame._icon, frame._cooldown, frame._spellName, frame._context, frame._status}) do
    local l, t, r, b = mock.rect(child)
    assert(l >= fl and r <= fr and t <= ft and b >= fb,
        "manual reminder must keep all compact-layout elements inside its frame")
end

print("manual cooldown reminder regression: catalog gating, cooldown safety, and bounds passed")
