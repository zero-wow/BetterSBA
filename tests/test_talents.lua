-- Focused regression mocks for TalentBuilds.lua. Run from the addon root with:
--   lua tests/test_talents.lua

local timers = {}
local deletedConfigs = 0
local importedLoadouts = 0
local streamMode = "invalid"
local now = 100
local runtimeFrame

GetTime = function() return now end
UnitName = function() return "Tester" end
UnitClass = function() return "Tester", "MAGE", 8 end
GetNumSpecializationsForClassID = function() return 1 end
GetSpecializationInfoForClassID = function() return 100, "Arcane" end
InCombatLockdown = function() return false end
SetSpecialization = function() end
PlayerUtil = { GetCurrentSpecID = function() return 100 end }
Enum = {
    TraitConfigType = { Combat = 1 },
    TraitNodeType = { Selection = 1, SubTreeSelection = 2 },
}
C_Traits = {
    GetLoadoutSerializationVersion = function() return 2 end,
    GetConfigInfo = function(id)
        return { ID = id, type = Enum.TraitConfigType.Combat, name = id == 99 and "BetterSBA" or "BetterSBA" }
    end,
    GetTreeNodes = function() return { 7001 } end,
    GetTreeHash = function() return { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } end,
    GetNodeInfo = function() return { type = 0, entryIDs = { 8001 }, maxRanks = 1 } end,
    ConfigHasStagedChanges = function() return false end,
}
C_ClassTalents = {
    CanEditTalents = function() return true end,
    GetTraitTreeForSpec = function() return 9001 end,
    GetActiveConfigID = function() return 42 end,
    GetConfigIDsBySpecID = function() return { 42, 77, 99 } end,
    DeleteConfig = function()
        deletedConfigs = deletedConfigs + 1
        return true
    end,
    ImportLoadout = function()
        importedLoadouts = importedLoadouts + 1
        return true
    end,
    UpdateLastSelectedSavedConfigID = function() end,
}
ExportUtil = {
    MakeImportDataStream = function()
        if streamMode == "invalid" then return nil end
        local values = { 2, 100 }
        local hash = streamMode == "hash-mismatch" and 1 or 0
        values[#values + 1] = hash
        for i = 2, 16 do values[#values + 1] = 0 end
        if streamMode == "valid" then
            values[#values + 1] = 1 -- selected
            values[#values + 1] = 1 -- purchased
            values[#values + 1] = 0 -- fully ranked
            values[#values + 1] = 0 -- non-choice
        end
        local bits = streamMode == "header-only" and 152 or 156
        local index = 0
        return {
            GetNumberOfBits = function() return bits end,
            ExtractValue = function(_, width)
                index = index + 1
                return values[index]
            end,
        }
    end,
}

local NS = {
    pairs = pairs,
    ipairs = ipairs,
    type = type,
    tostring = tostring,
    pcall = pcall,
    TALENT_BUILD_CUSTOM_ID = "CUSTOM",
    TALENT_BUILD_TYPE_USER = "user",
    db = {
        talentBuildsEnabled = true,
        talentBuildRetryAfterCombat = true,
        selectedTalentBuildIDs = {},
        talentBuildLastStatus = {},
        lastAppliedTalentBuildIDs = {},
    },
    dbRoot = {
        talentBuildEntries = {
            { id = "BUILD-1", classToken = "MAGE", specID = 100, name = "Safe build", importString = "bad" },
        },
        talentBuildCharacters = {},
    },
    GetCharKey = function() return "Tester-Realm" end,
    C_Timer_After = function(_, callback)
        timers[#timers + 1] = callback
    end,
    CreateFrame = function()
        local frame = { events = {} }
        function frame:SetScript(_, callback) self.onEvent = callback end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterAllEvents() self.events = {} end
        runtimeFrame = frame
        return frame
    end,
}

local chunk = assert(loadfile("Core/Functions/TalentBuilds.lua"))
chunk("BetterSBA", NS)

-- A legacy/prefix-matching config is never adopted without the saved ownership
-- mapping, so it cannot later be deleted or selected as ours.
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == nil)

-- Full import parsing happens before mutation. Invalid content must retain all
-- existing configs and must not call the import API.
assert(NS.RequestTalentBuildApply("BUILD-1", { specID = 100 }) == false)
assert(deletedConfigs == 0, "invalid imports must not delete saved configs")
assert(importedLoadouts == 0, "invalid imports must not call ImportLoadout")

-- A header-only stream must be rejected by the bounded content reader.
streamMode = "header-only"
assert(NS.ValidateTalentBuildImportString("short", 100) == false)
assert(importedLoadouts == 0, "truncated imports must not call ImportLoadout")

-- A non-zero hash with a leading byte mismatch is rejected; an all-zero hash
-- remains the compatibility form accepted by the parser.
streamMode = "hash-mismatch"
assert(NS.ValidateTalentBuildImportString("hash", 100) == false)
streamMode = "valid"
assert(NS.ValidateTalentBuildImportString("zero-hash", 100) == true)

-- Exercise the real pending-import event path. A staged update must not be
-- treated as a commit; only a subsequent clean update completes ownership.
NS.InitializeTalentBuildStorage()
for i = #timers, 1, -1 do timers[i] = nil end
NS.dbRoot.talentBuildCharacters["Tester-Realm"] = { managedConfigIDs = { ["BUILD-1"] = 99 } }
assert(NS.RequestTalentBuildApply("BUILD-1", { specID = 100 }) == true)
assert(importedLoadouts == 1, "valid import should call ImportLoadout")
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == 99, "ownership must wait for commit")
runtimeFrame.onEvent(runtimeFrame, "TRAIT_CONFIG_CREATED", { ID = 77, type = Enum.TraitConfigType.Combat, name = "BetterSBA" })
C_Traits.ConfigHasStagedChanges = function() return true end
runtimeFrame.onEvent(runtimeFrame, "TRAIT_CONFIG_UPDATED", 42)
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == 99, "staged update must not complete import")
C_Traits.ConfigHasStagedChanges = function() return false end
runtimeFrame.onEvent(runtimeFrame, "TRAIT_CONFIG_UPDATED", 42)
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == 77, "clean update should record new ownership")
assert(deletedConfigs == 1, "previous owned config should retire after confirmed replacement")

-- A failed commit leaves the prior ownership intact, and an unconfirmed
-- request times out at the configured ten-second boundary.
NS.dbRoot.talentBuildCharacters["Tester-Realm"].managedConfigIDs["BUILD-1"] = 99
assert(NS.RequestTalentBuildApply("BUILD-1", { specID = 100 }) == true)
runtimeFrame.onEvent(runtimeFrame, "CONFIG_COMMIT_FAILED", 42)
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == 99, "failed commit must retain prior ownership")
assert(NS.RequestTalentBuildApply("BUILD-1", { specID = 100 }) == true)
now = 111
local timeout = table.remove(timers, #timers)
assert(timeout, "pending import should schedule timeout")
timeout()
assert(NS.GetTalentBuildManagedConfigID("BUILD-1") == 99, "timed out import must retain prior ownership")

-- Retries use the forward-declared function and stop after a bounded number of
-- attempts instead of perpetually rescheduling the original reason.
for i = #timers, 1, -1 do timers[i] = nil end
C_ClassTalents.CanEditTalents = function() return false, "Talents are busy" end
assert(NS.RequestTalentBuildApply("BUILD-1", { specID = 100 }) == true)
local executed = 0
while #timers > 0 do
    local callback = table.remove(timers, 1)
    callback()
    executed = executed + 1
    assert(executed <= 5, "retry loop must be bounded")
end
assert(NS.GetTalentBuildPendingApply() == nil, "exhausted retry must clear pending state")

print("talent regression mocks: ok")
