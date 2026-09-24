-- Run from the addon root: lua tests/test_click_intercept_cleanup.lua
-- Ensures an inactive click overlay cannot donate its old action-bar button
-- to the main-button press visual after SBA has moved or disappeared.

local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local activeSlot = 1
local NS = {
    UIParent = ui.uiParent,
    CreateFrame = ui.createFrame,
    db = { enabled = true, interceptionType = "Click", sectionColorCombat = { .2, .6, 1, 1 } },
    defaults = { sectionColorCombat = { .2, .6, 1, 1 } },
    ipairs = ipairs, pairs = pairs, pcall = pcall, math_floor = math.floor,
    C_AddOns = { IsAddOnLoaded = function() return false end },
    InCombatLockdown = function() return false end,
    IsInterceptBlocked = function() return false end,
    BuildMacroText = function() return "/cast Assisted Combat" end,
    UpdateKeybindStatus = function() end,
}

local barButton = ui.createFrame("Button", "ActionButton1", ui.uiParent)
barButton:SetSize(36, 36)
_G.ActionButton1 = barButton

assert(loadfile("Core/Functions/Bindings.lua"))("BetterSBA", NS)
NS.FindSBAActionSlot = function() return activeSlot end

NS.UpdateClickIntercept()
local clickOverlay
for _, frame in ipairs(ui.frames) do
    if frame:GetName() == "BetterSBA_ClickIntercept" then clickOverlay = frame; break end
end
assert(clickOverlay and clickOverlay:IsShown() and clickOverlay._barBtn == barButton,
    "click routing must own the currently resolved SBA bar button")

NS.db.interceptionType = "Keybind"
NS.UpdateClickIntercept()
assert(not clickOverlay:IsShown() and clickOverlay._barBtn == nil,
    "stopping click routing must discard the old SBA bar button")

activeSlot = nil
NS.StartInterceptBarPressVisual(true)
for _, frame in ipairs(ui.frames) do
    assert(not (rawget(frame, "tex") and frame:IsShown()),
        "main-button press must not show a stale action-bar visual after click routing stops")
end

print("click interception cleanup regression: ok")
