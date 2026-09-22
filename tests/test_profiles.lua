-- Standalone regression checks for Core/Database.lua (no WoW client required).
local NS = {
    defaults = {
        priorityIconSize = 16,
        prioritySpacing = 4,
        showMinimapButton = true,
        trinketMode = "Off",
        configPanelScale = 1,
    },
    pairs = pairs,
    ipairs = ipairs,
    type = type,
    table_insert = table.insert,
}

function CopyTable(value)
    local out = {}
    for k, v in pairs(value) do
        out[k] = type(v) == "table" and CopyTable(v) or v
    end
    return out
end

function UnitFullName() return "Tester", "Realm" end
function GetRealmName() return "Realm" end

_G.BetterSBA = NS
NS.InitializeTalentBuildStorage = function() end
NS.ApplyProfileVisuals = function() end

assert(loadfile("Core/Database.lua"))("BetterSBA", NS)

local function eq(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Legacy keys must migrate before defaults fill the replacement keys.
BetterSBA_DB = {
    queueIconSize = 22,
    trinketMode = "Verified",
    minimap = { hide = false, x = 10 },
}
NS:InitializeDatabase()
eq(NS.db.priorityIconSize, 22, "legacy queue key migrates")
eq(NS.db.queueIconSize, nil, "legacy queue key is removed")
eq(NS.db.trinketMode, "Approved", "legacy trinket mode migrates")
eq(NS.db.minimap, BetterSBA_DB.minimap, "minimap aliases root after initialize")

-- A newer value wins over an older duplicate during migration.
BetterSBA_DB = {
    _version = 1,
    activeProfile = "Default",
    profiles = { Default = { queueIconSize = 22, priorityIconSize = 44 } },
    charProfiles = {},
    minimap = { hide = false },
}
NS:InitializeDatabase()
eq(NS.db.priorityIconSize, 44, "new priority value is preserved")
eq(NS.db.queueIconSize, nil, "duplicate legacy value is removed")

-- Copying an unmapped legacy profile migrates its values and preserves globals.
BetterSBA_DB.profiles.Source = { queueSpacing = 9 }
NS:CopyFromProfile("Source")
eq(NS.db.prioritySpacing, 9, "legacy source value migrates before copy")
eq(NS.db.queueSpacing, nil, "legacy source key is removed after copy")
eq(NS.db.minimap, BetterSBA_DB.minimap, "minimap aliases root after copy")

-- Switching and resetting must keep the same root minimap table.
BetterSBA_DB.profiles.Other = { prioritySpacing = 12, minimap = { hide = true } }
NS:SwitchProfile("Other")
eq(NS.db.minimap, BetterSBA_DB.minimap, "minimap aliases root after switch")
NS:ResetProfile()
eq(NS.db.minimap, BetterSBA_DB.minimap, "minimap aliases root after reset")

-- The compact config adopts neutral zoom once for existing profiles. A later
-- manual zoom is intentional and must survive normal initialization.
BetterSBA_DB = {
    _version = 1,
    activeProfile = "Default",
    profiles = { Default = { configPanelScale = 1.5 } },
    charProfiles = {},
    minimap = { hide = false },
}
NS:InitializeDatabase()
eq(NS.db.configPanelLayoutVersion, 1, "compact config migration is recorded")
eq(NS.db.configPanelScale, 1, "first compact-layout migration resets legacy panel zoom")
NS.db.configPanelScale = 1.35
NS:InitializeDatabase()
eq(NS.db.configPanelLayoutVersion, 1, "migration marker is stable on reload")
eq(NS.db.configPanelScale, 1.35, "manual panel zoom survives later initialization")

print("test_profiles.lua: ok")
