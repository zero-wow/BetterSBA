-- Focused regression mocks for TalentBuilds.lua. Run from the addon root with:
--   lua tests/test_talents.lua

local timers = {}
local deletedConfigs = 0
local importedLoadouts = 0
local streamMode = "invalid"
local encodedContent, encodedBits
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
    TraitNodeType = { Selection = 1, SubTreeSelection = 2, Tiered = 3 },
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
        if encodedContent then
            for _, value in ipairs(encodedContent) do values[#values + 1] = value end
        elseif streamMode == "valid" then
            values[#values + 1] = 1 -- selected
            values[#values + 1] = 1 -- purchased
            values[#values + 1] = 0 -- fully ranked
            values[#values + 1] = 0 -- non-choice
        end
        local bits = encodedBits and 152 + encodedBits or (streamMode == "header-only" and 152 or 156)
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
for _, prefix in ipairs({ "!GRIP1!", "!EMS1!" }) do
    local ok, message = NS.ValidateTalentBuildImportString(prefix .. "payload", 100)
    assert(not ok and message:find("separate Talent build string", 1, true),
        "LazyGrip rotation strings need a clear talent-only import instruction")
    local rows, reason = NS.DecodeTalentBuildTarget({ specID = 100, importString = prefix .. "payload" }, 42)
    assert(not rows and reason:find("GRIP-EMS rotation sequence", 1, true),
        "a GRIP/EMS sequence must never reach the WoW talent decoder")
end

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

-- Level-up/login events must never restore or reimport a complete loadout.
local importsBeforeEvents = importedLoadouts
NS.db.selectedTalentBuildIDs[100] = "BUILD-1"
runtimeFrame.onEvent(runtimeFrame, "PLAYER_LEVEL_UP", 25)
runtimeFrame.onEvent(runtimeFrame, "TRAIT_TREE_CURRENCY_INFO_UPDATED", 9001)
runtimeFrame.onEvent(runtimeFrame, "PLAYER_LOGIN")
assert(importedLoadouts == importsBeforeEvents, "legacy automatic loadout imports must stay retired")

-- Modern tiered nodes serialize one total rank count but import as multiple
-- entries. Starting with a later active entry must not misassign early ranks.
streamMode = "valid"
C_Traits.GetNodeInfo = function()
    return { type = Enum.TraitNodeType.Tiered, entryIDs = { 8001, 8002 }, maxRanks = 2, activeEntry = { entryID = 8002 } }
end
C_Traits.GetEntryInfo = function() return { maxRanks = 1 } end
local rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "tiered" }, 42))
assert(#rows == 2 and rows[1].selectionEntryID == 8001 and rows[2].selectionEntryID == 8002)
assert(rows[1].ranksPurchased == 1 and rows[2].ranksPurchased == 1)
encodedContent, encodedBits = { 1, 1, 1, 0, 0 }, 10
assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "zero-ranks" }, 42) == nil,
    "a selected purchased node cannot contain zero paid ranks")
encodedContent, encodedBits = { 1, 1, 1, 3, 0 }, 10
assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "excess-ranks" }, 42) == nil,
    "a purchased rank count cannot exceed node capacity")
encodedContent, encodedBits = { 1, 1, 1, 1, 0 }, 10
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "partial-tier" }, 42))
assert(#rows == 1 and rows[1].selectionEntryID == 8001 and rows[1].ranksPurchased == 1)

-- Blood's supplied San'layn export purchases the hero-tree selector. Current
-- talent data can omit maxRanks for SubTreeSelection; that is one paid choice,
-- not an invalid zero-rank node. Accept a full-rank partial encoding too,
-- matching Blizzard's permissive import behavior.
encodedContent, encodedBits = { 1, 1, 0, 1, 0 }, 6
C_Traits.GetNodeInfo = function()
    return { type = Enum.TraitNodeType.SubTreeSelection, entryIDs = { 8001, 8002 } }
end
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "hero-choice" }, 42))
assert(#rows == 1 and rows[1].ranksPurchased == 1 and rows[1].selectionEntryID == 8001,
    "a purchased hero-tree choice with omitted maxRanks must become one spendable rank")
-- A locked hero selector can report zero capacity through the current config
-- even though the max-level export contains a valid one-rank target.
C_Traits.GetNodeInfo = function()
    return { type = 0, entryIDs = { 8001, 8002 }, maxRanks = 0 }
end
C_Traits.GetEntryInfo = function(_, entryID)
    return { maxRanks = 1, subTreeID = entryID == 8001 and 555 or 556 }
end
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "locked-hero-choice" }, 42))
assert(#rows == 1 and rows[1].ranksPurchased == 1 and rows[1].selectionEntryID == 8001,
    "a level-locked hero selector must remain a future target instead of blocking leveling")
-- Some low-level configs omit hero entry IDs altogether. Preserve the full
-- encoded choice for leveling, but never pass an unresolved entry to ImportLoadout.
C_Traits.GetTreeNodes = function() return { 7001, 99822 } end
encodedContent, encodedBits = { 1, 1, 0, 0, 1, 1, 0, 1, 0 }, 10
local heroUnlocked = false
C_Traits.GetNodeInfo = function(_, nodeID)
    if nodeID == 7001 then return { type = 0, entryIDs = { 8001 }, maxRanks = 1 } end
    if heroUnlocked then
        return { type = Enum.TraitNodeType.SubTreeSelection, entryIDs = { 8101, 8102 }, maxRanks = 1 }
    end
    return { type = Enum.TraitNodeType.SubTreeSelection, entryIDs = {}, maxRanks = 0,
        isAvailable = false, canPurchaseRank = false }
end
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "low-level-blood" }, 42))
assert(#rows == 2 and rows[1].selectionEntryID == 8001 and rows[2].deferred
    and rows[2].nodeID == 99822 and rows[2].choiceIndex == 1 and rows[2].fullRank,
    "the decoder must retain locked hero choice bits while exposing class talents")
-- A locked non-choice node may have no node info or zero live capacity. Both
-- still carry the full-rank intent for later decoding when the level unlocks it.
C_Traits.GetNodeInfo = function(_, nodeID)
    if nodeID == 7001 then return { type = 0, entryIDs = { 8001 }, maxRanks = 1 } end
    return nil
end
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "missing-hero-node" }, 42))
assert(#rows == 2 and rows[2].deferred and rows[2].fullRank,
    "a node with no live info must not prevent choosing the leveling route")
C_Traits.GetNodeInfo = function(_, nodeID)
    if nodeID == 7001 then return { type = 0, entryIDs = { 8001 }, maxRanks = 1 } end
    return { type = 0, entryIDs = { 8101 }, maxRanks = 0 }
end
encodedContent, encodedBits = { 1, 1, 0, 0, 1, 1, 0, 0 }, 8
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "zero-capacity-hero" }, 42))
assert(#rows == 2 and rows[2].deferred and rows[2].fullRank,
    "zero live rank capacity must defer the target rather than reject it")
heroUnlocked = true
encodedContent, encodedBits = { 1, 1, 0, 0, 1, 1, 0, 1, 0 }, 10
C_Traits.GetNodeInfo = function(_, nodeID)
    if nodeID == 7001 then return { type = 0, entryIDs = { 8001 }, maxRanks = 1 } end
    return { type = Enum.TraitNodeType.SubTreeSelection, entryIDs = { 8101, 8102 }, maxRanks = 1 }
end
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "unlocked-blood" }, 42))
assert(#rows == 2 and not rows[2].deferred and rows[2].selectionEntryID == 8101,
    "the preserved hero choice must resolve when its entries unlock")
C_Traits.GetTreeNodes = function() return { 7001 } end
encodedContent, encodedBits = { 1, 1, 1, 1, 1, 0 }, 12
rows = assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "full-partial" }, 42))
assert(#rows == 1 and rows[1].ranksPurchased == 1,
    "a valid explicit full rank must not be rejected only for using partial-rank encoding")

encodedContent, encodedBits = nil, nil
C_Traits.GetNodeInfo = function() return { type = Enum.TraitNodeType.Selection, entryIDs = { 8001, 8002 }, maxRanks = 1 } end
assert(NS.DecodeTalentBuildTarget({ specID = 100, importString = "changed-node-type" }, 42) == nil,
    "an outdated zero-hash export with a changed node type must fail closed")

-- An upgrade must not resume the retired full-reset leveling behavior from
-- SavedVariables. Disabling the feature also withdraws an outstanding alert.
NS.db.talentBuildPendingApply = { buildID = "BUILD-1", specID = 100, reason = "level-up" }
NS.db.talentBuildPromptPending = { buildID = "BUILD-1" }
NS.InitializeTalentBuildStorage()
assert(NS.GetTalentBuildPendingApply() == nil and NS.GetTalentBuildPromptPending() == nil,
    "obsolete automatic whole-build work must be removed during initialization")
local warningWithdrawn = false
NS.CheckTalentSBAWarning = function(assessment) warningWithdrawn = assessment.warningEnabled == false end
NS.db.talentBuildsEnabled = false
NS.RefreshTalentBuildRuntimeState()
assert(warningWithdrawn and next(runtimeFrame.events) == nil, "disabled talent assistance must withdraw warnings and events")

print("talent regression mocks: ok")
