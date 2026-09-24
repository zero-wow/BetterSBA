local ADDON_NAME, NS = ...

local EMPTY = {}
local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local BIT_WIDTH_RANKS_PURCHASED = 6

local pairs = NS.pairs or pairs
local ipairs = NS.ipairs or ipairs
local type = NS.type or type
local tostring = NS.tostring or tostring
local GetTime = GetTime
local UnitName = UnitName
local UnitClass = UnitClass
local GetNumSpecializationsForClassID = GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local InCombatLockdown = InCombatLockdown
local SetSpecialization = SetSpecialization
local LoadoutSerializationVersion = C_Traits and C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 2
local MANAGED_LOADOUT_NAME = "BetterSBA"

local runtimeFrame
local runtimeInitialized = false
local pendingLoadRequest
local ProcessPendingApply
local MAX_PENDING_APPLY_RETRIES = 5
local IMPORT_CONFIRM_TIMEOUT = 10
local TALENT_BUILD_RUNTIME_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_LEVEL_UP",
    "PLAYER_ENTERING_WORLD",
    "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "TRAIT_CONFIG_CREATED",
    "TRAIT_CONFIG_UPDATED",
    "CONFIG_COMMIT_FAILED",
}

local function IsTalentBuildSystemEnabled()
    return NS.db and NS.db.talentBuildsEnabled ~= false
end

local function GetPlayerName()
    local name = UnitName("player")
    if name and name ~= "" then
        return name
    end
    return "Unknown"
end

local function EnsureRootStore(root)
    if not root then return end
    if not root.talentBuildEntries then
        root.talentBuildEntries = {}
    end
    if not root.talentBuildNextID then
        root.talentBuildNextID = 1
    end
    if not root.talentBuildCatalogVersion then
        root.talentBuildCatalogVersion = (NS.TALENT_BUILD_CATALOG and NS.TALENT_BUILD_CATALOG.version) or 1
    end
    if not root.talentBuildCharacters then
        root.talentBuildCharacters = {}
    end
end

local function EnsureProfileState(profile)
    if not profile then return end
    if profile.selectedTalentBuildIDs == nil then
        profile.selectedTalentBuildIDs = {}
    end
    if profile.talentBuildLastStatus == nil then
        profile.talentBuildLastStatus = {}
    end
    if profile.lastAppliedTalentBuildIDs == nil then
        profile.lastAppliedTalentBuildIDs = {}
    end
end

local function EnsureCharacterState()
    EnsureRootStore(NS.dbRoot)
    local charKey = NS.GetCharKey()
    local state = NS.dbRoot.talentBuildCharacters[charKey]
    if not state then
        state = {}
        NS.dbRoot.talentBuildCharacters[charKey] = state
    end
    if not state.managedConfigIDs then
        state.managedConfigIDs = {}
    end
    return state
end

local function NormalizeUserBuild(entry)
    local normalized = {}
    normalized.id = entry.id
    normalized.classToken = entry.classToken
    normalized.specID = entry.specID
    normalized.name = entry.name or "New Build"
    normalized.author = entry.author or GetPlayerName()
    normalized.rating = entry.rating or ""
    normalized.source = entry.source or "Custom"
    normalized.catalogSource = entry.catalogSource or normalized.source or "Custom"
    normalized.sourceURL = entry.sourceURL or ""
    normalized.patch = entry.patch or ""
    normalized.importString = entry.importString or ""
    normalized.notes = entry.notes or ""
    normalized.category = entry.category or ""
    normalized.buildType = NS.TALENT_BUILD_TYPE_USER
    return normalized
end

local function GetSpecInfo(specID)
    local classID = NS.GetTalentBuildClassID()
    if not classID or not specID then
        return nil
    end
    local count = GetNumSpecializationsForClassID(classID) or 0
    for index = 1, count do
        local currentSpecID, name = GetSpecializationInfoForClassID(classID, index)
        if currentSpecID == specID then
            return name, index
        end
    end
    return nil
end

local function IsManagedLoadoutName(name)
    -- A matching name is not ownership evidence.  Only the exact name emitted
    -- by this version is eligible to be associated with an in-flight request;
    -- durable ownership is the per-character managedConfigIDs mapping below.
    return name == MANAGED_LOADOUT_NAME
end

local function GetManagedLoadoutName(entry)
    return MANAGED_LOADOUT_NAME
end

local function GetManagedConfigKey(entry)
    if type(entry) == "table" then
        return entry.id and tostring(entry.id) or nil
    end
    if entry == nil then
        return nil
    end
    return tostring(entry)
end

local function GetPromptPending()
    return NS.db and NS.db.talentBuildPromptPending or nil
end

local function ClearPromptPending()
    if NS.db then
        NS.db.talentBuildPromptPending = nil
    end
end

local function SetPendingApply(buildID, specID, reason, forceSpecSwitch)
    EnsureProfileState(NS.db)
    if not NS.db then return end
    local pending = NS.db.talentBuildPendingApply
    if not pending then
        pending = {}
        NS.db.talentBuildPendingApply = pending
    end
    pending.buildID = buildID
    pending.specID = specID
    pending.reason = reason
    pending.forceSpecSwitch = forceSpecSwitch and true or false
    pending.queuedAt = GetTime()
    pending.retryCount = nil
    pending.retryScheduled = nil
end

local function GetPendingApply()
    return NS.db and NS.db.talentBuildPendingApply or nil
end

local function ClearPendingApply()
    if NS.db then
        NS.db.talentBuildPendingApply = nil
    end
end

local function SetStatus(specID, kind, text, buildID)
    NS.SetTalentBuildLastStatus(specID, {
        kind = kind,
        text = text,
        buildID = buildID,
        time = GetTime(),
    })
    if NS.ShowConfigStatusMessage then
        NS.ShowConfigStatusMessage(text, kind, 4)
    end
end

local function SetLastAppliedTalentBuildID(specID, buildID)
    if not specID or not NS.db then
        return
    end
    EnsureProfileState(NS.db)
    NS.db.lastAppliedTalentBuildIDs[specID] = buildID or NS.TALENT_BUILD_CUSTOM_ID
end

local function RefreshAfterTalentApply()
    if NS.ClearBaseCDCache then NS.ClearBaseCDCache() end
    if NS.ResetVirtualCooldowns then NS.ResetVirtualCooldowns() end
    if NS.InvalidateRotationCache then NS.InvalidateRotationCache() end
    if NS.InvalidateResolveCache then NS.InvalidateResolveCache() end
    if NS.InvalidateTextureCache then NS.InvalidateTextureCache() end
    if NS.InvalidateCooldownCache then NS.InvalidateCooldownCache() end
    if NS.RebuildMacroText then NS.RebuildMacroText() end
    if NS.UpdateNow then NS.UpdateNow() end
end

local function CanEditTalentsNow()
    if InCombatLockdown() then
        return false, "In combat"
    end
    if not C_ClassTalents or not C_ClassTalents.CanEditTalents then
        return false, "Talent API unavailable"
    end
    local canEdit, reason = C_ClassTalents.CanEditTalents()
    if not canEdit then
        return false, reason or "Talents cannot be edited right now"
    end
    return true, nil
end

local function ReadLoadoutHeader(importStream)
    local headerBitWidth = BIT_WIDTH_HEADER_VERSION + BIT_WIDTH_SPEC_ID + 128
    if importStream:GetNumberOfBits() < headerBitWidth then
        return false, 0, 0, 0
    end
    local serializationVersion = importStream:ExtractValue(BIT_WIDTH_HEADER_VERSION)
    local specID = importStream:ExtractValue(BIT_WIDTH_SPEC_ID)
    local treeHash = {}
    for i = 1, 16 do
        treeHash[i] = importStream:ExtractValue(8)
    end
    return true, serializationVersion, specID, treeHash
end

local function IsHashValid(treeHash, treeID)
    if not treeHash or #treeHash ~= 16 or not treeID then
        return false
    end
    local allZero = true
    for i = 1, 16 do
        if treeHash[i] ~= 0 then allZero = false; break end
    end
    if allZero then return true end
    local expectedHash = C_Traits.GetTreeHash(treeID)
    if not expectedHash then return false end
    for i = 1, 16 do
        if treeHash[i] ~= expectedHash[i] then return false end
    end
    return true
end

local function ReadLoadoutContent(importStream, treeID)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    local remaining = importStream:GetNumberOfBits() - BIT_WIDTH_HEADER_VERSION - BIT_WIDTH_SPEC_ID - 128
    local function ReadBits(count)
        if remaining < count then error("Truncated talent content") end
        remaining = remaining - count
        local value = importStream:ExtractValue(count)
        if value == nil then error("Missing talent content") end
        return value
    end
    for i = 1, #treeNodes do
        local nodeSelectedValue = ReadBits(1)
        local isNodeSelected = nodeSelectedValue == 1
        local isNodePurchased = false
        local isPartiallyRanked = false
        local partialRanksPurchased = 0
        local isChoiceNode = false
        local choiceNodeSelection = 0

        if isNodeSelected then
            local nodePurchasedValue = ReadBits(1)
            isNodePurchased = nodePurchasedValue == 1
            if isNodePurchased then
                local isPartiallyRankedValue = ReadBits(1)
                isPartiallyRanked = isPartiallyRankedValue == 1
                if isPartiallyRanked then
                    partialRanksPurchased = ReadBits(BIT_WIDTH_RANKS_PURCHASED)
                end
                local isChoiceNodeValue = ReadBits(1)
                isChoiceNode = isChoiceNodeValue == 1
                if isChoiceNode then
                    choiceNodeSelection = ReadBits(2)
                end
            end
        end

        results[i] = {
            isNodeSelected = isNodeSelected,
            isNodeGranted = isNodeSelected and not isNodePurchased,
            isPartiallyRanked = isPartiallyRanked,
            partialRanksPurchased = partialRanksPurchased,
            isChoiceNode = isChoiceNode,
            choiceNodeSelection = choiceNodeSelection + 1,
            nodeID = treeNodes[i],
        }
    end
    return results
end

local function ConvertToImportLoadoutEntryInfo(configID, treeID, loadoutContent, includeDeferred)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    if not treeNodes then return nil, "Talent tree unavailable" end
    for i = 1, #treeNodes do
        local encoded = loadoutContent[i]
        if encoded and encoded.isNodeSelected and not encoded.isNodeGranted then
            local nodeID = treeNodes[i]
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            local entries = node and node.entryIDs
            -- At low levels the live config omits entries for locked hero
            -- talents, although the max-level export still selects them. The
            -- leveling plan retains the encoded rank and choice index until
            -- the live entries unlock; full imports omit deferred rows.
            local deferredNoEntries = not entries or #entries == 0
            local deferredNoRanks = node and not encoded.isChoiceNode
                and (type(node.maxRanks) ~= "number" or node.maxRanks < 1)
            -- No entry ID means this node cannot be purchased in this live
            -- config, regardless of how its availability flags are reported.
            if (deferredNoEntries or deferredNoRanks) and includeDeferred then
                if encoded.isPartiallyRanked and (type(encoded.partialRanksPurchased) ~= "number"
                    or encoded.partialRanksPurchased < 1 or encoded.partialRanksPurchased % 1 ~= 0) then
                    return nil, "Invalid deferred talent rank for node " .. tostring(nodeID)
                end
                results[#results + 1] = { nodeID = nodeID, deferred = true,
                    ranksPurchased = encoded.isPartiallyRanked and encoded.partialRanksPurchased or nil,
                    fullRank = not encoded.isPartiallyRanked,
                    choiceIndex = encoded.isChoiceNode and encoded.choiceNodeSelection or nil }
            elseif not deferredNoEntries and not deferredNoRanks then
                local selectedEntryID = encoded.isChoiceNode and entries[encoded.choiceNodeSelection] or entries[1]
                if encoded.isChoiceNode and not selectedEntryID then return nil, "Invalid choice-node selection" end
                local entryInfo = selectedEntryID and C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, selectedEntryID)
                -- The live hero selector may report no spendable maxRanks while an
                -- inactive subtree is displayed. Its entry's subTreeID identifies
                -- the one-rank selection even if the node type is not yet stable.
                local isSubTreeChoice = node.type == Enum.TraitNodeType.SubTreeSelection
                    or (encoded.isChoiceNode and entryInfo and entryInfo.subTreeID ~= nil)
                local maxRanks = isSubTreeChoice and 1 or node.maxRanks
                local missingChoiceRanks = encoded.isChoiceNode
                    and (type(maxRanks) ~= "number" or maxRanks < 1)
                if missingChoiceRanks then maxRanks = 1 end
                local ranks = encoded.isPartiallyRanked and encoded.partialRanksPurchased or maxRanks
                if type(maxRanks) ~= "number" or maxRanks < 1 or type(ranks) ~= "number"
                    or ranks % 1 ~= 0 or ranks < 1 or ranks > maxRanks then
                    return nil, "Invalid purchased rank count for talent node " .. tostring(nodeID)
                        .. " (import " .. tostring(ranks) .. ", capacity " .. tostring(maxRanks) .. ")"
                end
                local choice = node.type == Enum.TraitNodeType.Selection or isSubTreeChoice or missingChoiceRanks
                if encoded.isChoiceNode ~= choice then return nil, "Build node type does not match this talent tree" end
                if Enum.TraitNodeType.Tiered and node.type == Enum.TraitNodeType.Tiered then
                    if not C_Traits.GetEntryInfo then return nil, "Tiered talent API unavailable" end
                    local remaining = ranks
                    for j = 1, #entries do
                        if remaining == 0 then break end
                        local entryID = entries[j]
                        local info = C_Traits.GetEntryInfo(configID, entryID)
                        local capacity = info and info.maxRanks
                        if type(capacity) ~= "number" or capacity < 1 or capacity % 1 ~= 0 then
                            return nil, "Unable to read tiered talent ranks"
                        end
                        local purchased = math.min(remaining, capacity)
                        results[#results + 1] = { nodeID = nodeID, ranksGranted = 0, ranksPurchased = purchased, selectionEntryID = entryID }
                        remaining = remaining - purchased
                    end
                    if remaining ~= 0 then return nil, "Tiered talent rank count exceeds its entries" end
                else
                    results[#results + 1] = { nodeID = nodeID, ranksGranted = 0, ranksPurchased = ranks, selectionEntryID = selectedEntryID }
                end
            end
        end
    end
    return results
end

local function BuildImportEntryInfo(importString, specID, configID, includeDeferred)
    if not importString or importString == "" then
        return nil, "Build string missing"
    end
    if importString:match("^!GRIP%d+!") or importString:match("^!EMS%d+!") then
        return nil, "This is a GRIP-EMS rotation sequence. Copy the separate Talent build string from its LazyGrip page."
    end
    if not ExportUtil or not ExportUtil.MakeImportDataStream then
        return nil, "Import stream unavailable"
    end
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then
        return nil, "Talent tree unavailable"
    end
    local okImport, importStream = (NS.pcall or pcall)(ExportUtil.MakeImportDataStream, importString)
    if not okImport or not importStream then
        return nil, "Invalid build string"
    end
    local okHeader, headerValid, serializationVersion, stringSpecID, treeHash = (NS.pcall or pcall)(ReadLoadoutHeader, importStream)
    if not okHeader then
        return nil, "Invalid build string"
    end
    if not headerValid then
        return nil, "Invalid build string"
    end
    if serializationVersion ~= LoadoutSerializationVersion then
        return nil, "Build string version mismatch"
    end
    if stringSpecID ~= specID then
        return nil, "Build is for a different specialization"
    end
    if not IsHashValid(treeHash, treeID) then
        return nil, "Build string tree hash does not match"
    end
    local okContent, loadoutContent = pcall(ReadLoadoutContent, importStream, treeID)
    if not okContent then return nil, "Invalid or incomplete build content" end
    local okEntries, entries, errorText = pcall(ConvertToImportLoadoutEntryInfo,
        configID, treeID, loadoutContent, includeDeferred)
    if not okEntries then return nil, "Unable to read build nodes" end
    return entries, errorText
end

function NS.ValidateTalentBuildImportString(importString, specID)
    if not importString or importString == "" then
        return false, "Build string missing"
    end
    if importString:match("^!GRIP%d+!") or importString:match("^!EMS%d+!") then
        return false, "This is a GRIP-EMS rotation sequence. Copy the separate Talent build string from its LazyGrip page."
    end
    if not specID then
        return false, "Specialization unavailable"
    end
    if not ExportUtil or not ExportUtil.MakeImportDataStream then
        return false, "Import stream unavailable"
    end
    if not C_ClassTalents or not C_ClassTalents.GetTraitTreeForSpec then
        return false, "Talent API unavailable"
    end

    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then
        return false, "Talent tree unavailable"
    end

    local okImport, importStream = (NS.pcall or pcall)(ExportUtil.MakeImportDataStream, importString)
    if not okImport or not importStream then
        return false, "Invalid build string"
    end

    local okHeader, headerValid, serializationVersion, stringSpecID, treeHash = (NS.pcall or pcall)(ReadLoadoutHeader, importStream)
    if not okHeader or not headerValid then
        return false, "Invalid build string"
    end
    if serializationVersion ~= LoadoutSerializationVersion then
        return false, "Build string version mismatch"
    end
    if stringSpecID ~= specID then
        return false, "Build is for a different specialization"
    end
    if not IsHashValid(treeHash, treeID) then
        return false, "Build string tree hash does not match"
    end
    local okContent = pcall(ReadLoadoutContent, importStream, treeID)
    if not okContent then return false, "Invalid or incomplete build content" end
    return true, nil
end

-- Shared decoder: a leveling target describes purchased ranks, never a reset.
function NS.DecodeTalentBuildTarget(entry, configID)
    return BuildImportEntryInfo(entry.importString, entry.specID, configID, true)
end

function NS.IsTalentBuildImportPending()
    return pendingLoadRequest ~= nil or GetPendingApply() ~= nil
end

local function IsManagedConfigValid(specID, configID)
    if not specID or not configID or not C_ClassTalents or not C_ClassTalents.GetConfigIDsBySpecID then
        return false
    end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or configInfo.type ~= Enum.TraitConfigType.Combat then
        return false
    end
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or EMPTY
    for i = 1, #configIDs do
        if configIDs[i] == configID then
            return true
        end
    end
    return false
end

local function GetManagedConfigID(entry)
    if not entry or entry.id == NS.TALENT_BUILD_CUSTOM_ID or not entry.specID then
        return nil
    end
    local state = EnsureCharacterState()
    local key = GetManagedConfigKey(entry)
    local configID = key and state.managedConfigIDs[key] or nil
    local targetName = GetManagedLoadoutName(entry)
    if configID and IsManagedConfigValid(entry.specID, configID) then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and configInfo.type == Enum.TraitConfigType.Combat and configInfo.name == targetName then
            return configID
        end
    end
    if key then
        state.managedConfigIDs[key] = nil
    end
    -- Never infer ownership by scanning similarly named saved loadouts.  The
    -- player or another addon may own those entries, even when their name uses
    -- our historical prefix.
    return nil
end

local function SetManagedConfigID(entry, configID)
    local key = GetManagedConfigKey(entry)
    if not key then
        return
    end
    local state = EnsureCharacterState()
    state.managedConfigIDs[key] = configID
end

local function CompletePendingImport(request, fallbackLookup)
    if not request or pendingLoadRequest ~= request then
        return false
    end
    if not request.commitConfirmed then
        return false
    end
    if not IsTalentBuildSystemEnabled() then
        ClearPromptPending()
        ClearPendingApply()
        pendingLoadRequest = nil
        return false
    end
    local entry = NS.FindTalentBuildByID(request.buildID)
    local savedConfigID = request.savedConfigID
    if entry and not savedConfigID and fallbackLookup then
        savedConfigID = GetManagedConfigID(entry)
    end
    if entry and savedConfigID then
        SetManagedConfigID(entry, savedConfigID)
        C_ClassTalents.UpdateLastSelectedSavedConfigID(request.specID, savedConfigID)
        -- Only retire the previously recorded config after its replacement
        -- committed. Never delete a config inferred from a name or prefix.
        local previous = request.previousConfigID
        if previous and previous ~= savedConfigID and previous ~= request.configID
            and not InCombatLockdown() and IsManagedConfigValid(request.specID, previous)
            and C_ClassTalents.DeleteConfig then
            local oldInfo = C_Traits.GetConfigInfo(previous)
            if oldInfo and oldInfo.name == GetManagedLoadoutName(entry) then
                pcall(C_ClassTalents.DeleteConfig, previous)
            end
        end
    end
    SetStatus(request.specID, "success", "Applied " .. ((entry and entry.name) or "selected build"), request.buildID)
    SetLastAppliedTalentBuildID(request.specID, request.buildID)
    ClearPromptPending()
    ClearPendingApply()
    pendingLoadRequest = nil
    RefreshAfterTalentApply()
    return true
end

local function ImportAndLoadManagedConfig(entry, configID, loadoutEntryInfo, reason)
    if not configID then
        SetStatus(entry.specID, "error", "Active talent config unavailable", entry.id)
        ClearPendingApply()
        return "failed"
    end
    if not loadoutEntryInfo then
        SetStatus(entry.specID, "error", "Failed to parse build string", entry.id)
        ClearPendingApply()
        return "failed"
    end
    pendingLoadRequest = {
        buildID = entry.id,
        specID = entry.specID,
        configID = configID,
        reason = reason,
        mode = "import",
        previousConfigID = GetManagedConfigID(entry),
        startedAt = GetTime(),
    }
    local request = pendingLoadRequest
    local ok, success, importError = pcall(C_ClassTalents.ImportLoadout, configID, loadoutEntryInfo, GetManagedLoadoutName(entry), entry.importString)
    if not ok then success, importError = false, "Talent import API failed" end
    if not success then
        pendingLoadRequest = nil
        SetStatus(entry.specID, "error", importError or "Failed to import build", entry.id)
        ClearPendingApply()
        return "failed"
    end
    if pendingLoadRequest ~= request then return "done" end
    SetStatus(entry.specID, "applying", "Applying " .. entry.name, entry.id)
    NS.C_Timer_After(IMPORT_CONFIRM_TIMEOUT, function()
        if pendingLoadRequest ~= request or request.commitConfirmed then
            return
        end
        SetStatus(request.specID, "error", "Timed out waiting for " .. ((NS.FindTalentBuildByID(request.buildID) or EMPTY).name or "selected build") .. " to commit", request.buildID)
        ClearPendingApply()
        pendingLoadRequest = nil
    end)
    return "pending"
end

local function SchedulePendingApplyRetry(entry, reasonText)
    local pending = GetPendingApply()
    if not pending or pending.buildID ~= entry.id then
        return false
    end
    if pending.retryScheduled then
        return true
    end
    pending.retryCount = pending.retryCount or 0
    if pending.retryCount >= MAX_PENDING_APPLY_RETRIES then
        SetStatus(entry.specID, "error", reasonText or "Talents did not become editable", entry.id)
        ClearPendingApply()
        return false
    end
    pending.retryCount = pending.retryCount + 1
    pending.retryScheduled = true
    NS.C_Timer_After(0.2, function()
        if GetPendingApply() ~= pending then
            return
        end
        pending.retryScheduled = nil
        ProcessPendingApply("delayed-retry")
    end)
    return true
end

local function ApplyTalentBuildEntry(entry, reason)
    if not entry or not entry.specID then
        return "failed"
    end
    if not IsTalentBuildSystemEnabled() then
        ClearPendingApply()
        ClearPromptPending()
        pendingLoadRequest = nil
        return "failed"
    end
    if entry.id == NS.TALENT_BUILD_CUSTOM_ID then
        ClearPendingApply()
        ClearPromptPending()
        SetLastAppliedTalentBuildID(entry.specID, entry.id)
        SetStatus(entry.specID, "custom", "Using Custom talents", entry.id)
        return "done"
    end
    local canEdit, reasonText = CanEditTalentsNow()
    if not canEdit then
        if InCombatLockdown() and NS.db and NS.db.talentBuildRetryAfterCombat then
            SetPendingApply(entry.id, entry.specID, reason, false)
            SetStatus(entry.specID, "queued", "Queued " .. entry.name .. " until combat ends", entry.id)
            return "queued"
        end
        if SchedulePendingApplyRetry(entry, reasonText) then
            SetStatus(entry.specID, "waiting", reasonText or "Waiting for talents to become editable", entry.id)
            return "pending"
        end
        SetStatus(entry.specID, "error", reasonText or "Talents cannot be edited right now", entry.id)
        return "failed"
    end
    local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil
    local loadoutEntryInfo, errorText = BuildImportEntryInfo(entry.importString, entry.specID, activeConfigID)
    if not loadoutEntryInfo then
        SetStatus(entry.specID, "error", errorText or "Failed to parse build string", entry.id)
        ClearPendingApply()
        return "failed"
    end
    return ImportAndLoadManagedConfig(entry, activeConfigID, loadoutEntryInfo, reason)
end

ProcessPendingApply = function(reason)
    local pending = GetPendingApply()
    if not pending or not pending.buildID then
        return false
    end
    if not IsTalentBuildSystemEnabled() then
        ClearPendingApply()
        ClearPromptPending()
        pendingLoadRequest = nil
        return false
    end
    local currentSpecID = NS.GetTalentBuildCurrentSpecID()
    if pending.specID and currentSpecID ~= pending.specID then
        if not pending.forceSpecSwitch or InCombatLockdown() then
            return false
        end
        local _, specIndex = GetSpecInfo(pending.specID)
        if not specIndex or not SetSpecialization then
            SetStatus(pending.specID, "error", "Failed to switch specialization", pending.buildID)
            ClearPendingApply()
            return false
        end
        SetSpecialization(specIndex)
        return true
    end
    local entry = NS.FindTalentBuildByID(pending.buildID)
    if not entry then
        SetStatus(pending.specID, "error", "Selected build could not be found", pending.buildID)
        ClearPendingApply()
        return false
    end
    local result = ApplyTalentBuildEntry(entry, reason or pending.reason or "pending")
    if result == "done" or result == "failed" then
        ClearPendingApply()
    end
    return result ~= "failed"
end

local function OnTalentBuildEvent(_, event, ...)
    if not IsTalentBuildSystemEnabled() then
        return
    end
    if NS.OnTalentLevelingEvent then NS.OnTalentLevelingEvent(event, ...) end
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        ProcessPendingApply(event)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        NS.C_Timer_After(0.1, function() ProcessPendingApply("spec-switch") end)
    elseif event == "TRAIT_CONFIG_CREATED" then
        local configInfo = ...
        if not pendingLoadRequest or pendingLoadRequest.mode ~= "import" or not configInfo or configInfo.type ~= Enum.TraitConfigType.Combat then
            return
        end
        local entry = NS.FindTalentBuildByID(pendingLoadRequest.buildID)
        if entry and configInfo.ID and IsManagedLoadoutName(configInfo.name) then
            pendingLoadRequest.savedConfigID = configInfo.ID
        end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        local configID = ...
        if not pendingLoadRequest or pendingLoadRequest.configID ~= configID then
            return
        end
        if C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(configID) then return end
        pendingLoadRequest.commitConfirmed = true
        CompletePendingImport(pendingLoadRequest, true)
    elseif event == "CONFIG_COMMIT_FAILED" then
        local configID = ...
        if not pendingLoadRequest or pendingLoadRequest.configID ~= configID then
            return
        end
        SetStatus(pendingLoadRequest.specID, "error", "Failed to commit " .. ((NS.FindTalentBuildByID(pendingLoadRequest.buildID) or EMPTY).name or "selected build"), pendingLoadRequest.buildID)
        ClearPendingApply()
        pendingLoadRequest = nil
    end
end

function NS.InitializeTalentBuildStorage()
    EnsureRootStore(NS.dbRoot)
    EnsureProfileState(NS.db)
    -- Drop queued work from the retired full-loadout level/login automation.
    local pending = GetPendingApply()
    if pending and pending.reason ~= "manual" and pending.reason ~= "load-anyway"
        and pending.reason ~= "config-apply" and pending.reason ~= "config-load-anyway" then
        ClearPendingApply()
    end
    ClearPromptPending()
    NS.InitializeTalentBuildRuntime()
end

function NS.InitializeTalentBuildRuntime()
    if runtimeInitialized then
        return
    end
    runtimeInitialized = true
    runtimeFrame = NS.CreateFrame("Frame")
    runtimeFrame:SetScript("OnEvent", OnTalentBuildEvent)
    if NS.RefreshTalentBuildRuntimeState then
        NS.RefreshTalentBuildRuntimeState()
    end
end

function NS.IsTalentBuildSystemEnabled()
    return IsTalentBuildSystemEnabled()
end

function NS.RefreshTalentBuildRuntimeState()
    if not runtimeInitialized then
        return
    end

    runtimeFrame:UnregisterAllEvents()

    if IsTalentBuildSystemEnabled() then
        for i = 1, #TALENT_BUILD_RUNTIME_EVENTS do
            runtimeFrame:RegisterEvent(TALENT_BUILD_RUNTIME_EVENTS[i])
        end
        NS.C_Timer_After(0.2, function()
            if not IsTalentBuildSystemEnabled() then
                return
            end
            if NS.ScheduleTalentLevelingCheck then NS.ScheduleTalentLevelingCheck() end
        end)
    else
        ClearPendingApply()
        ClearPromptPending()
        pendingLoadRequest = nil
        if NS.CheckTalentSBAWarning then NS.CheckTalentSBAWarning({ warningEnabled = false }) end
    end

    if NS.RefreshTalentBuildPanels then
        NS.RefreshTalentBuildPanels()
    end
    if NS.RefreshTalentBuildAttachedPanel then
        NS.RefreshTalentBuildAttachedPanel()
    end
end

function NS.GetTalentBuildClassToken()
    local _, classToken = UnitClass("player")
    return classToken
end

function NS.GetTalentBuildClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

function NS.GetTalentBuildCurrentSpecID()
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        return PlayerUtil.GetCurrentSpecID()
    end
    return nil
end

function NS.GetTalentBuildSpecsForCurrentClass()
    local classID = NS.GetTalentBuildClassID()
    if not classID or not GetNumSpecializationsForClassID or not GetSpecializationInfoForClassID then
        return EMPTY
    end
    local count = GetNumSpecializationsForClassID(classID) or 0
    local specs = {}
    for index = 1, count do
        local specID, name = GetSpecializationInfoForClassID(classID, index)
        if specID then
            specs[#specs + 1] = {
                specID = specID,
                name = name,
                index = index,
            }
        end
    end
    return specs
end

function NS.GetTalentBuildSpecName(specID)
    local name = GetSpecInfo(specID)
    return name
end

function NS.GetTalentBuildSpecIndex(specID)
    local _, index = GetSpecInfo(specID)
    return index
end

function NS.GetTalentBuildCustomEntry(specID, specName)
    return {
        id = NS.TALENT_BUILD_CUSTOM_ID,
        classToken = NS.GetTalentBuildClassToken(),
        specID = specID,
        name = "Custom",
        author = "",
        rating = "",
        source = "Custom",
        catalogSource = "Custom",
        sourceURL = "",
        patch = "",
        importString = "",
        notes = "",
        category = "",
        buildType = NS.TALENT_BUILD_TYPE_CUSTOM,
        specName = specName,
    }
end

function NS.GetTalentBuildUserEntries()
    local root = NS.dbRoot
    if not root or not root.talentBuildEntries then
        return EMPTY
    end
    local entries = root.talentBuildEntries
    for i = 1, #entries do
        local entry = entries[i]
        if entry and not entry.catalogSource then
            entry.catalogSource = entry.source or "Custom"
        end
    end
    return entries
end

function NS.GetTalentBuildBuiltInEntries()
    local catalog = NS.TALENT_BUILD_CATALOG
    if not catalog or not catalog.entries then
        return EMPTY
    end
    local entries = catalog.entries
    for i = 1, #entries do
        local entry = entries[i]
        if entry and not entry.catalogSource then
            entry.catalogSource = entry.source or ""
        end
    end
    return entries
end

function NS.GetTalentBuildEntriesForClass(classToken)
    classToken = classToken or NS.GetTalentBuildClassToken()
    local entries = {}
    local builtIn = NS.GetTalentBuildBuiltInEntries()
    for i = 1, #builtIn do
        local entry = builtIn[i]
        if entry.classToken == classToken then
            entries[#entries + 1] = entry
        end
    end
    local userEntries = NS.GetTalentBuildUserEntries()
    for i = 1, #userEntries do
        local entry = userEntries[i]
        if entry.classToken == classToken then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

function NS.FindTalentBuildByID(buildID)
    if not buildID or buildID == NS.TALENT_BUILD_CUSTOM_ID then
        return nil
    end
    local builtIn = NS.GetTalentBuildBuiltInEntries()
    for i = 1, #builtIn do
        local entry = builtIn[i]
        if entry.id == buildID then
            return entry
        end
    end
    local userEntries = NS.GetTalentBuildUserEntries()
    for i = 1, #userEntries do
        local entry = userEntries[i]
        if entry.id == buildID then
            return entry
        end
    end
    return nil
end

function NS.GetSelectedTalentBuildID(specID)
    local map = NS.db and NS.db.selectedTalentBuildIDs
    if not specID or not map then
        return NS.TALENT_BUILD_CUSTOM_ID
    end
    return map[specID] or NS.TALENT_BUILD_CUSTOM_ID
end

function NS.SetSelectedTalentBuildID(specID, buildID)
    if not specID or not NS.db then return end
    EnsureProfileState(NS.db)
    NS.db.selectedTalentBuildIDs[specID] = buildID or NS.TALENT_BUILD_CUSTOM_ID
    local promptPending = GetPromptPending()
    if promptPending and promptPending.specID == specID and promptPending.buildID ~= buildID then
        ClearPromptPending()
    end
end

function NS.GetTalentBuildEntryForSpec(specID)
    local buildID = NS.GetSelectedTalentBuildID(specID)
    if buildID == NS.TALENT_BUILD_CUSTOM_ID then
        return NS.GetTalentBuildCustomEntry(specID, NS.GetTalentBuildSpecName(specID))
    end
    return NS.FindTalentBuildByID(buildID)
end

function NS.GetTalentBuildLastStatus(specID)
    local map = NS.db and NS.db.talentBuildLastStatus
    if not specID or not map then return nil end
    return map[specID]
end

function NS.SetTalentBuildLastStatus(specID, status)
    if not specID or not NS.db then return end
    EnsureProfileState(NS.db)
    NS.db.talentBuildLastStatus[specID] = status
end

function NS.GetNextTalentBuildUserID()
    local root = NS.dbRoot
    EnsureRootStore(root)
    local id = "USER-" .. root.talentBuildNextID
    root.talentBuildNextID = root.talentBuildNextID + 1
    return id
end

function NS.SaveUserTalentBuild(entry)
    local root = NS.dbRoot
    EnsureRootStore(root)
    if not entry then
        return nil
    end
    local buildID = entry.id
    if not buildID or buildID == "" or buildID == NS.TALENT_BUILD_CUSTOM_ID then
        buildID = NS.GetNextTalentBuildUserID()
    end
    local normalized = NormalizeUserBuild(entry)
    normalized.id = buildID
    local list = root.talentBuildEntries
    for i = 1, #list do
        if list[i].id == buildID then
            list[i] = normalized
            return buildID
        end
    end
    list[#list + 1] = normalized
    return buildID
end

function NS.DeleteUserTalentBuild(buildID)
    if not buildID or buildID == NS.TALENT_BUILD_CUSTOM_ID or not NS.dbRoot then
        return false
    end
    local list = NS.dbRoot.talentBuildEntries
    if not list then
        return false
    end
    for i = 1, #list do
        if list[i].id == buildID then
            for j = i, #list - 1 do
                list[j] = list[j + 1]
            end
            list[#list] = nil
            local profiles = NS.dbRoot.profiles or EMPTY
            for _, profile in pairs(profiles) do
                local selected = profile.selectedTalentBuildIDs
                if selected then
                    for specID, selectedID in pairs(selected) do
                        if selectedID == buildID then
                            selected[specID] = NS.TALENT_BUILD_CUSTOM_ID
                        end
                    end
                end
            end
            return true
        end
    end
    return false
end

function NS.GetTalentBuildPendingApply()
    return GetPendingApply()
end

function NS.ClearTalentBuildPendingApply()
    ClearPendingApply()
end

function NS.GetTalentBuildPromptPending()
    return GetPromptPending()
end

function NS.GetTalentBuildManagedConfigID(specID)
    if type(specID) == "string" then
        return GetManagedConfigID(NS.FindTalentBuildByID(specID))
    end
    local buildID = specID and NS.GetSelectedTalentBuildID(specID) or nil
    return GetManagedConfigID(NS.FindTalentBuildByID(buildID))
end

function NS.RequestTalentBuildApply(buildID, opts)
    opts = opts or EMPTY
    if not IsTalentBuildSystemEnabled() then
        return false
    end
    -- Do not let a second click replace the identity of an in-flight import.
    if pendingLoadRequest or (NS.IsTalentLevelingBusy and NS.IsTalentLevelingBusy()) then return false end
    if not buildID or buildID == NS.TALENT_BUILD_CUSTOM_ID then
        local specID = opts.specID or NS.GetTalentBuildCurrentSpecID()
        NS.SetSelectedTalentBuildID(specID, NS.TALENT_BUILD_CUSTOM_ID)
        SetLastAppliedTalentBuildID(specID, NS.TALENT_BUILD_CUSTOM_ID)
        ClearPendingApply()
        ClearPromptPending()
        SetStatus(specID, "custom", "Using Custom talents", NS.TALENT_BUILD_CUSTOM_ID)
        return true
    end
    local entry = NS.FindTalentBuildByID(buildID)
    if not entry then
        return false
    end
    NS.SetSelectedTalentBuildID(entry.specID, buildID)
    local currentSpecID = NS.GetTalentBuildCurrentSpecID()
    if currentSpecID ~= entry.specID then
        if not opts.loadAnyway then
            SetStatus(entry.specID, "selected", "Selected " .. entry.name .. " for " .. (NS.GetTalentBuildSpecName(entry.specID) or "that specialization"), entry.id)
            return true
        end
        SetPendingApply(entry.id, entry.specID, opts.reason or "load-anyway", true)
        if InCombatLockdown() then
            SetStatus(entry.specID, "queued", "Queued " .. entry.name .. " until combat ends", entry.id)
            return true
        end
        return ProcessPendingApply("load-anyway")
    end
    SetPendingApply(entry.id, entry.specID, opts.reason or "manual", false)
    local result = ApplyTalentBuildEntry(entry, opts.reason or "manual")
    if result == "done" or result == "failed" then
        ClearPendingApply()
    end
    return result ~= "failed"
end

function NS.ApplySelectedTalentBuild(specID, reason)
    if not IsTalentBuildSystemEnabled() then
        return false
    end
    specID = specID or NS.GetTalentBuildCurrentSpecID()
    if not specID then
        return false
    end
    return NS.RequestTalentBuildApply(NS.GetSelectedTalentBuildID(specID), {
        specID = specID,
        reason = reason or "manual",
        loadAnyway = specID ~= NS.GetTalentBuildCurrentSpecID(),
    })
end

function NS.ProcessPendingTalentBuildApply(reason)
    if not IsTalentBuildSystemEnabled() then
        return false
    end
    return ProcessPendingApply(reason)
end
