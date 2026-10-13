-- Shared pause-state snapshots and hidden-display update lifecycle.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
mock.install()
local reason, checks, labelWrites, scans, reminders = nil, 0, 0, 0, 0
local ns = {
    THEME = {}, C_Spell = {}, pcall = pcall,
    db = { enabled = true, interceptionType = "Click", ldbShowText = true,
        alphaOOC = 0, alphaCombat = 1 },
    ldbDataObj = {}, InCombatLockdown = function() return false end,
    UpdateButtonChrome = function() end,
    ScanKeybinds = function() scans = scans + 1 end,
    ClearSBASlotCache = function() end,
    C_Timer_After = function() end,
    GetDisplaySpell = function() return nil end,
    UpdateManualCooldownReminder = function() reminders = reminders + 1 end,
}
C_Spell = ns.C_Spell
assert(loadfile("Core/Functions/Spells.lua"))("BetterSBA", ns)
assert(loadfile("Core/LDB.lua"))("BetterSBA", ns)
assert(loadfile("GUI/MainButton.lua"))("BetterSBA", ns)
ns.GetInterceptBlockReason = function() checks = checks + 1; return reason end
local btn = CreateFrame("Button", nil, UIParent)
btn:SetSize(48, 48)
btn.icon = btn:CreateTexture()
btn.hotkey = btn:CreateFontString()
btn.cooldown = CreateFrame("Cooldown", nil, btn)
btn.pauseOverlay = CreateFrame("Frame", nil, btn)
local pauseMethods = getmetatable(btn.pauseOverlay).__index
setmetatable(btn.pauseOverlay, { __index = function(self, key)
    if key == "currentReason" then return nil end
    return pauseMethods(self, key)
end })
btn.pauseOverlay.bars = {}
btn.pauseOverlay.symbolText = btn.pauseOverlay:CreateFontString()
btn.pauseOverlay.reasonText = { SetText = function() labelWrites = labelWrites + 1 end }
ns.mainButton = btn
for i = 1, 20 do ns.UpdateNow() end
assert(checks == 20, "hidden ticks should check pause state once, shared with LDB")
assert(labelWrites == 0, "unchanged unpaused ticks must not rewrite the empty label")
assert(reminders == 0, "hidden parent must not render child reminder")
assert(ns.ldbDataObj.text == "Idle")
assert(not ns.GetCacheDiagnostics().cooldownDirty, "hidden early return must finish update diagnostics")
reason = "Vehicle"
ns.UpdateNow()
assert(checks == 21 and labelWrites == 1 and scans == 1)
assert(ns.ldbDataObj.text == "Paused: Vehicle")
ns.UpdateNow()
assert(checks == 22 and labelWrites == 1 and scans == 1, "stable paused state must not rescan/rewrite")
reason = nil
ns.UpdateNow()
assert(checks == 23 and labelWrites == 2 and scans == 2)
assert(ns.ldbDataObj.text == "Idle", "explicit unblocked snapshot must clear cached pause state")
reason = "Mounted"
ns.UpdateLDBText()
assert(checks == 24 and ns.ldbDataObj.text == "Paused: Mounted", "direct callers still get a fresh check")
ns.db.alphaOOC = 1
ns.UpdateNow()
assert(reminders == 1, "visible update must still render child reminder")
print("PASS: 20 steady ticks use 20 pause checks, zero label rewrites; pause transitions and hidden lifecycle preserved")
