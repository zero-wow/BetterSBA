-- Regression checks for click-only interception status reporting.
-- Run from the addon root with: lua tests/test_interception_status.lua

local obj
local NS = {
    THEME = {}, VERSION = "test", ICON_PATH = "icon", Config = { Toggle = function() end },
    db = { enabled = true, locked = true, ldbShowText = true },
    table_concat = table.concat, math_floor = math.floor,
    InCombatLockdown = function() return false end,
    GetInterceptBlockReason = function() return nil end,
    _GetNextSpellName = function() return nil end,
    C_Timer_After = function(_, fn) fn() end,
    GetClickInterceptSlot = function() return nil end,
}
_G.BetterSBA = NS
LibStub = function()
    local dbIcon = {
        Register = function() end,
        GetMinimapButton = function() return nil end,
    }
    local broker = {
        NewDataObject = function(_, _, value)
            obj = value
            function value:Register() end
            return value
        end,
    }
    return {
        NewDataObject = broker.NewDataObject,
        Register = dbIcon.Register,
        GetMinimapButton = dbIcon.GetMinimapButton,
    }
end
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
ReloadUI = function() end
print = function() end

assert(loadfile("Core/LDB.lua"))("BetterSBA", NS)
NS.InitLDB()

NS._overrideKeys, NS._overrideSlot = nil, nil
NS.GetClickInterceptSlot = function() return 25 end
NS.UpdateLDBText()
assert(obj.text == "Click routing [BAR: 3] [SLOT: 1]", "click-only status missing")

NS.GetClickInterceptSlot = function() return nil end
NS.UpdateLDBText()
assert(obj.text == "Idle", "hidden click overlay should report idle")

NS._overrideKeys, NS._overrideSlot = { "2" }, 25
NS.UpdateLDBText()
assert(obj.text == "Intercepting [KB: 2] [BAR: 3] [SLOT: 1]", "keybind status changed")

NS.db.enabled = false
NS.UpdateLDBText()
assert(obj.text == "Disabled", "disabled status changed")

print("interception status regression mocks: ok")
