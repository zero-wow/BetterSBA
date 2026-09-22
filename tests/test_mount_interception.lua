-- Run from the addon root: lua tests/test_mount_interception.lua
-- Verifies that the macro's Auto-Dismount setting controls only normal
-- grounded mounts; vehicle, skyriding, and flight-form guards remain active.

local mounted, flying, vehicle = false, false, false
IsMounted = function() return mounted end
IsFlying = function() return flying end
UnitInVehicle = function() return vehicle end
HasVehicleActionBar = function() return false end
HasOverrideActionBar = function() return false end
IsPossessBarVisible = function() return false end
HasBonusActionBar = function() return false end
GetNumShapeshiftForms = function() return 0 end

local NS = {
    db = { enableDismount = true },
    pairs = pairs,
    ipairs = ipairs,
    pcall = pcall,
    math_floor = math.floor,
    C_AddOns = { IsAddOnLoaded = function() return false end },
    IsFlightTravelFormActive = function() return false end,
    IsSkyridingActive = function() return false end,
}

assert(loadfile("Core/Functions/Bindings.lua"))("BetterSBA", NS)

mounted, flying, vehicle = true, false, false
assert(NS.IsInterceptBlocked() == false,
    "Auto-Dismount must keep normal ground-mount interception active")

NS.db.enableDismount = false
assert(NS.IsInterceptBlocked() == true,
    "ground mounts must remain paused when Auto-Dismount is disabled")

NS.db.enableDismount = true
flying = true
NS.IsSkyridingActive = function() return true end
assert(NS.IsInterceptBlocked() == true,
    "skyriding must stay blocked even when Auto-Dismount is enabled")

flying = false
NS.IsSkyridingActive = function() return false end
vehicle = true
assert(NS.IsInterceptBlocked() == true,
    "vehicle action bars must stay blocked")

print("mount interception regression: ok")
