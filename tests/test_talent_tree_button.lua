-- Run from the addon root: lua tests/test_talent_tree_button.lua
-- Blizzard_PlayerSpells is load-on-demand; verify the bridge attaches once and
-- reserves a visible gap between Blizzard's search and Apply controls.
local frames, timers = {}, {}
local inCombat, canSpend, clicks = false, true, 0
local function frame()
    local object = { events = {}, scripts = {}, hooks = {}, level = 100 }
    function object:RegisterEvent(event) self.events[event] = true end
    function object:UnregisterEvent(event) self.events[event] = nil end
    function object:SetScript(event, callback) self.scripts[event] = callback end
    function object:HookScript(event, callback) self.hooks[event] = callback end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:SetPoint(...) self.point = { ... } end
    function object:SetFrameLevel(level) self.level = level end
    function object:GetFrameLevel() return self.level end
    function object:SetText(value) self.text = value end
    function object:SetAlpha(value) self.alpha = value end
    function object:IsShown() return true end
    function object:GetParent() return self.parent end
    return object
end

_G.CreateFrame = function(kind, name, parent)
    local object = frame()
    object.kind, object.name, object.parent = kind, name, parent
    frames[#frames + 1] = object
    return object
end
_G.InCombatLockdown = function() return inCombat end
_G.GameTooltip = nil
_G.C_ClassTalents = { GetActiveConfigID = function() return 1 end }
local NS = {
    C_Timer_After = function(_, callback) timers[#timers + 1] = callback end,
    GetTalentSpendAllInfo = function()
        return { canSpend = canSpend, targetName = "Current SBA target", status = canSpend and "Ready" or "No points" }
    end,
    SpendAllTalentPoints = function() clicks = clicks + 1; return true, "Applied" end,
}
assert(loadfile("GUI/TalentTreeButton.lua"))("BetterSBA", NS)
local eventFrame = frames[1]
assert(eventFrame and eventFrame.events.ADDON_LOADED and #frames == 1,
    "the tree button must wait for Blizzard_PlayerSpells instead of forcing its load")

local talents, apply = frame(), frame()
talents.ApplyButton = apply
talents.GetConfigID = function() return 1 end
talents.IsInspecting = function() return false end
apply.level = 101
_G.PlayerSpellsFrame = { TalentsFrame = talents }
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "Blizzard_PlayerSpells")
local button = frames[2]
assert(button and button.name == "BetterSBA_SpendAllTalentsButton" and button.parent == talents,
    "the control must appear on the active Blizzard talent tab")
assert(button.text == "SBA: SPEND ALL" and button.width == 144 and button.height == 22,
    "the action needs an explicit readable hit target")
assert(button.point[1] == "RIGHT" and button.point[2] == apply
    and button.point[3] == "LEFT" and button.point[4] == -16,
    "the action must sit to the left of Apply with a visible gutter")
-- Blizzard's maximized talent frame places Search near x=452 and Apply's
-- left edge at x=724 in a 1612px bar. The new 144px button spans 564..708.
local searchRight, applyLeft = 452, 724
local actionRight = applyLeft + button.point[4]
local actionLeft = actionRight - button.width
assert(actionLeft - searchRight >= 12 and applyLeft - actionRight >= 12,
    "the action must not overlap Search or Apply at the talent window's supported size")
assert(not eventFrame.events.ADDON_LOADED, "attach once after Blizzard's window loads")
button.scripts.OnClick(button)
assert(clicks == 1 and #timers == 1, "the button must invoke one explicit batch action")
timers[1]()
canSpend = false
talents.hooks.OnShow()
assert(button.alpha == 0.55 and button._status == "No points",
    "the button must show when no target points are spendable")
canSpend = true
talents.GetConfigID = function() return 2 end
button.scripts.OnClick(button)
timers[#timers]()
assert(clicks == 1 and button.alpha == 0.55
    and button._status:find("Activate the displayed talent loadout", 1, true),
    "viewing an inactive loadout must not spend points in an unseen active configuration")

print("talent tree button: lazy attach, action routing, and bottom-bar bounds passed")
