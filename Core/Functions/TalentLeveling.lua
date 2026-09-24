local ADDON_NAME, NS = ...

-- Incremental leveling never resets talents. A separate deliberate respec action
-- stages and verifies a level-appropriate target before committing it once.
-- A max-level export supplies a destination, not an optimal spending order.
local pending, scheduled, lastWarning
local faults = {}
local chainCount = 0
local MAX_CHAIN = 200
local COMMIT_TIMEOUT = 10

local function Refresh()
    if NS.RefreshTalentBuildPanels then NS.RefreshTalentBuildPanels() end
    if NS.RefreshTalentTreeSpendAllButton then NS.RefreshTalentTreeSpendAllButton() end
end

local function ClientStamp()
    if not GetBuildInfo then return "unknown" end
    local version, build, _, interface = GetBuildInfo()
    return tostring(version) .. ":" .. tostring(build) .. ":" .. tostring(interface)
end

local function TreeStamp(treeID)
    local hash = C_Traits.GetTreeHash(treeID)
    return hash and table.concat(hash, ":") or nil
end

function NS.GetTalentLevelingState(specID)
    specID = specID or NS.GetTalentBuildCurrentSpecID()
    if not NS.dbRoot or not specID then return { buildID = NS.TALENT_BUILD_CUSTOM_ID, enabled = false, warnMismatch = false } end
    local root = NS.dbRoot
    root.talentBuildCharacters = root.talentBuildCharacters or {}
    local key = NS.GetCharKey()
    local character = root.talentBuildCharacters[key]
    if not character then character = {}; root.talentBuildCharacters[key] = character end
    character.leveling = character.leveling or {}
    if not character.leveling[specID] then
        character.leveling[specID] = { buildID = NS.TALENT_BUILD_CUSTOM_ID, enabled = false, warnMismatch = false }
    end
    return character.leveling[specID]
end

local function NodeName(configID, nodeID, entryID)
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    if entry and entry.subTreeID and C_Traits.GetSubTreeInfo then
        local tree = C_Traits.GetSubTreeInfo(configID, entry.subTreeID)
        if tree and tree.name then return tree.name end
    end
    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    if definition then
        local name = definition.overrideName
        if (not name or name == "") and definition.spellID and C_Spell and C_Spell.GetSpellName then
            name = C_Spell.GetSpellName(definition.spellID)
        end
        if name and name ~= "" then return name end
    end
    return "Talent " .. tostring(nodeID)
end

local function APIsReady()
    return C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.CanEditTalents
        and C_ClassTalents.GetTraitTreeForSpec and C_ClassTalents.CommitConfig
        and C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo
        and C_Traits.GetDefinitionInfo and C_Traits.GetTreeHash and C_Traits.GetNodeCost
        and C_Traits.GetTreeCurrencyInfo and C_Traits.CanPurchaseRank and C_Traits.PurchaseRank
        and C_Traits.SetSelection and C_Traits.ConfigHasStagedChanges
end

local function IsChoice(node, configID, entryID)
    if node.type == Enum.TraitNodeType.Selection or node.type == Enum.TraitNodeType.SubTreeSelection then
        return true
    end
    entryID = entryID or (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    return entry and entry.subTreeID ~= nil or false
end

local function GetGuidance(specID, buildID)
    local guidance = NS.TALENT_SBA_PRIORITIES and NS.TALENT_SBA_PRIORITIES[specID]
    local version = GetBuildInfo and GetBuildInfo()
    -- Source-derived weights are patch-specific. Never silently reuse them on
    -- a different major/minor patch just because talent IDs still exist.
    if guidance and version and version:match("^%d+%.%d+") == guidance.patch
        and (not guidance.buildIDs or guidance.buildIDs[buildID]) then return guidance end
end

local function AssignGuidance(ordered, map, configID, guidance)
    if not guidance then return end
    for _, target in ipairs(ordered) do
        target.score = 0
        for _, desired in ipairs(target.entries) do
            if desired.throughRank > target.node.ranksPurchased then
                local entry = C_Traits.GetEntryInfo(configID, desired.entryID)
                local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                local rule = definition and (guidance.spells[definition.spellID] or guidance.spells[definition.overriddenSpellID])
                if rule and rule.priority > target.score then
                    target.score, target.rule = rule.priority, rule
                    target.reason = rule.reason
                end
                -- Only rank the next tier, never a later effect as if already
                -- available. Its prerequisite route is covered by node edges.
                break
            end
        end
    end
    local edgeTypes = Enum.TraitEdgeType
    if not edgeTypes then return end
    -- Carry the value of an unlearned destination back along actual selected
    -- prerequisite paths. This makes a needed connector outrank a side branch.
    -- Positive, diminishing scores and a bounded pass count also handle cycles.
    for _ = 1, #ordered do
        local changed = false
        for _, parent in ipairs(ordered) do
            if parent.node.ranksPurchased < parent.ranks then
                for _, edge in ipairs(parent.node.visibleEdges or {}) do
                    if edge.type == edgeTypes.RequiredForAvailability or edge.type == edgeTypes.SufficientForAvailability then
                        local child = map[edge.targetNode]
                        if child and child.node.ranksPurchased < child.ranks and (child.score or 0) - 1 > parent.score then
                            parent.score, parent.rule = child.score - 1, child.rule
                            parent.reason = "Builds a path toward " .. (child.rule and child.rule.name or "a priority talent") .. "."
                            changed = true
                        end
                    end
                end
            end
        end
        if not changed then break end
    end
end

-- Collapse tiered import rows into total paid ranks. Tiered nodes advance their
-- entry automatically; SetSelection is exclusively for real choice nodes.
local function Targets(entry, configID)
    local rows, err = NS.DecodeTalentBuildTarget(entry, configID)
    if not rows then return nil, err end
    local map, ordered, deferred = {}, {}, 0
    for _, row in ipairs(rows) do
        if row.deferred then
            deferred = deferred + 1
        else
            local target = map[row.nodeID]
            if not target then
                target = { nodeID = row.nodeID, ranks = 0, entries = {} }
                map[row.nodeID] = target
                ordered[#ordered + 1] = target
            end
            target.ranks = target.ranks + row.ranksPurchased
            target.entries[#target.entries + 1] = { entryID = row.selectionEntryID, throughRank = target.ranks }
        end
    end
    if #ordered == 0 and deferred == 0 then return nil, "The target build contains no talents." end
    -- Authored priorities are optional and must refer to nodes in this target.
    -- Otherwise use a stable, top-to-bottom prerequisite traversal like ZugZug.
    local priority, occurrences = {}, {}
    for index, pick in ipairs(entry.levelingOrder or {}) do
        local target = map[pick.nodeID]
        if target then
            occurrences[pick.nodeID] = (occurrences[pick.nodeID] or 0) + 1
            local rank = pick.rank or occurrences[pick.nodeID]
            priority[pick.nodeID] = priority[pick.nodeID] or {}
            priority[pick.nodeID][rank] = index
        end
    end
    for _, target in ipairs(ordered) do
        local node = C_Traits.GetNodeInfo(configID, target.nodeID)
        if not node or type(node.ranksPurchased) ~= "number" then return nil, "Talent data is not ready." end
        target.node = node
    end
    AssignGuidance(ordered, map, configID, GetGuidance(entry.specID, entry.id))
    table.sort(ordered, function(a, b)
        local pa = priority[a.nodeID] and priority[a.nodeID][a.node.ranksPurchased + 1] or math.huge
        local pb = priority[b.nodeID] and priority[b.nodeID][b.node.ranksPurchased + 1] or math.huge
        if pa ~= pb then return pa < pb end
        local sa, sb = a.score or 0, b.score or 0
        if sa ~= sb then return sa > sb end
        local ay, by = a.node.posY or 0, b.node.posY or 0
        if ay ~= by then return ay < by end
        local ax, bx = a.node.posX or 0, b.node.posX or 0
        if ax ~= bx then return ax < bx end
        return a.nodeID < b.nodeID
    end)
    return map, ordered, deferred
end

local function NextEntry(target, rank)
    for _, entry in ipairs(target.entries) do
        if entry.throughRank > rank then return entry.entryID end
    end
end

local function CanAfford(configID, nodeID, currencies)
    local costs = C_Traits.GetNodeCost(configID, nodeID)
    if not costs then return false end
    for _, cost in ipairs(costs) do
        if type(cost.amount) ~= "number" or (currencies[cost.ID] or 0) < cost.amount then return false end
    end
    return true
end

local function Inspect(options)
    options = options or {}
    local specID = NS.GetTalentBuildCurrentSpecID()
    local state = NS.GetTalentLevelingState(specID)
    local info = {
        specID = specID, specName = NS.GetTalentBuildSpecName(specID) or "Unknown",
        buildID = state.buildID, enabled = state.enabled == true,
        autoRespecEnabled = state.autoRespec == true, canSpend = false,
        warningEnabled = state.warnMismatch == true and NS.IsTalentBuildSystemEnabled(),
        hasMismatch = false, canRespec = false, settled = false,
        targetName = "No Build Selected", nextName = "—",
        status = "Choose a build for your current specialization to begin.",
        detail = "Auto-spend is saved for this character and specialization.",
    }
    local entry = NS.FindTalentBuildByID(state.buildID)
    if not entry then
        if state.buildID and state.buildID ~= NS.TALENT_BUILD_CUSTOM_ID then
            info.status = "The selected build is unavailable. Choose a build again."
        end
        return info
    end
    info.targetName = entry.name
    local evidence = entry.verificationStatus == "source-sba" and "Assist-specific source build. "
        or (entry.verificationStatus == "source-talent" and "Source-published talent export; SBA suitability is unverified. ")
        or (entry.verificationStatus == "source-compatible" and "Source-recommended SBA-compatible build. ")
        or (entry.verificationStatus == "guide-adapted" and "Guide-adapted SBA build. ")
        or (entry.verificationStatus == "guide-inferred" and "Guide-discussed SBA spec; this exact import is not SBA-verified. ")
        or (entry.verificationStatus == "user-provided" and "Player-supplied SBA target; not independently performance-verified. ")
        or "SBA suitability unverified. "
    info.detail = evidence .. (entry.patch and entry.patch ~= "" and ("Source patch: " .. entry.patch) or "Source patch unverified")
        .. ". " .. (entry.levelingOrder and "Source priority; legal prerequisites first." or "Follows the build in prerequisite order; not an SBA-tested leveling order.")
    local function Block(text) info.status = text; return info end
    if not NS.IsTalentBuildSystemEnabled() then return Block("Talent assistance is disabled.") end
    if entry.specID ~= specID or entry.classToken ~= NS.GetTalentBuildClassToken() then
        return Block("Choose a build for your current specialization.")
    end
    if not APIsReady() then return Block("Talent APIs are not ready.") end
    local configID = C_ClassTalents.GetActiveConfigID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not configID or not treeID then return Block("Waiting for the active talent tree.") end
    info.configID, info.treeID = configID, treeID
    if state.clientStamp ~= ClientStamp() or state.treeStamp ~= TreeStamp(treeID) or state.importString ~= entry.importString then
        return Block("The game or target build changed. Reselect the leveling target to review it.")
    end
    if faults[specID] and not options.assessment and not options.request then return Block(faults[specID]) end
    if pending and pending ~= options.request then return Block("Waiting for the talent change to finish applying.") end
    if NS.IsTalentBuildImportPending() then return Block("Waiting for the whole-build import to finish.") end
    if InCombatLockdown() then return Block("Waiting for combat to end.") end
    if C_Traits.ConfigHasStagedChanges(configID) and not (options.request and options.request.ownsChanges) then
        return Block("Apply or discard your pending talent edits first.")
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return Block("Waiting until you are alive to spend talent points.")
    end
    local editable, editReason = C_ClassTalents.CanEditTalents()
    if not editable then return Block(editReason or "Talents cannot be edited right now.") end
    local map, ordered, deferred = Targets(entry, configID)
    if not map then return Block(ordered or "The build is not compatible with this talent tree.") end
    local guidance = GetGuidance(specID, entry.id)
    if guidance and not entry.levelingOrder then
        info.detail = evidence .. "Patch " .. guidance.patch .. ". Guide-informed priorities, with legal prerequisites; not simulation-ranked."
    end
    local nodes = C_Traits.GetTreeNodes(treeID)
    if not nodes then return Block("Waiting for talent nodes.") end
    info.settled = true
    local differences, mismatchDetails = {}, {}
    -- Missing future ranks are normal while leveling. Only allocations outside
    -- the selected target (including conflicting choices) are mismatches.
    for _, nodeID in ipairs(nodes) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        if node and (node.ranksPurchased or 0) > 0 then
            local target = map[nodeID]
            if not target or node.ranksPurchased > target.ranks or
                (IsChoice(node, configID) and (not node.activeEntry or node.activeEntry.entryID ~= target.entries[1].entryID)) then
                differences[#differences + 1] = tostring(nodeID) .. ":" .. tostring(node.ranksPurchased)
                    .. ":" .. tostring(node.activeEntry and node.activeEntry.entryID or 0)
                local currentEntry = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
                local currentName = NodeName(configID, nodeID, currentEntry)
                if not target then
                    mismatchDetails[#mismatchDetails + 1] = currentName .. " is learned but is outside the selected SBA target."
                elseif node.ranksPurchased > target.ranks then
                    mismatchDetails[#mismatchDetails + 1] = currentName .. " has " .. node.ranksPurchased
                        .. " ranks; the selected SBA target uses " .. target.ranks .. "."
                else
                    mismatchDetails[#mismatchDetails + 1] = currentName .. " is selected; the SBA target uses "
                        .. NodeName(configID, nodeID, target.entries[1].entryID) .. "."
                end
            end
        end
    end
    if #differences > 0 then
        table.sort(differences)
        info.hasMismatch = true
        info.mismatches = mismatchDetails
        info.mismatchSummary = mismatchDetails[1]
        info.mismatchDetails = table.concat(mismatchDetails, "\n")
        info.signature = NS.GetCharKey() .. ":" .. tostring(specID) .. ":" .. tostring(state.buildID)
            .. ":" .. entry.importString .. ":" .. table.concat(differences, ",")
        info.canRespec = C_Traits.ResetTree ~= nil and C_Traits.RollbackConfig ~= nil
            and C_Traits.IsReadyForCommit ~= nil
        info.nextAction = "Respec to the chosen SBA build at your current level."
        return Block(info.enabled and info.autoRespecEnabled
            and "Auto-Rebuild is On. Conflicting talents will be rebuilt when editing is available."
            or "Your learned talents differ from this route. Use Reset & Rebuild to align them.")
    end
    local currencies, hasPoints = {}, false
    for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
        currencies[currency.traitCurrencyID] = currency.quantity or 0
        if (currency.quantity or 0) > 0 then hasPoints = true end
    end
    info.hasPoints = hasPoints
    local missing = false
    for _, target in ipairs(ordered) do
        local node = target.node
        if node.ranksPurchased < target.ranks then
            missing = true
            local entryID = NextEntry(target, node.ranksPurchased)
            if Enum.TraitNodeType.Tiered and node.type == Enum.TraitNodeType.Tiered and node.nextEntry then
                entryID = node.nextEntry.entryID
            end
            local name = NodeName(configID, target.nodeID, entryID)
            if info.nextName == "—" then info.nextName = name end
            if hasPoints and node.canPurchaseRank and node.isAvailable ~= false
                and C_Traits.CanPurchaseRank(configID, target.nodeID, entryID)
                and CanAfford(configID, target.nodeID, currencies) then
                info.nextName, info.canSpend = name, true
                info.pick = { nodeID = target.nodeID, entryID = entryID, before = node.ranksPurchased,
                    choice = IsChoice(node, configID, entryID) }
                info.status = info.enabled and "An available point is ready to spend automatically."
                    or "An available point is ready. Turn on Auto-Spend or click Spend Available Points."
                info.reason = target.reason or "Fills a legal prerequisite or remaining rank in your chosen build."
                info.status = info.status .. " " .. info.reason
                info.prioritySourceURL = target.rule and target.rule.sourceURL
                return info
            end
        end
    end
    if not missing then
        return Block(deferred > 0 and "Current-level talents are filled. More in this route unlock later."
            or "Every talent in this route is learned.")
    end
    if hasPoints then return Block("Unspent points are waiting for a level or prerequisite unlock.") end
    return Block(info.enabled and "No unspent points now. Auto-Spend will use your next point."
        or "No unspent points now. Turn on Auto-Spend to use future points.")
end

function NS.GetTalentLevelingInfo()
    local ok, info = pcall(Inspect)
    if ok then return info end
    local state = NS.GetTalentLevelingState()
    return { enabled = state.enabled, autoRespecEnabled = state.autoRespec == true,
        buildID = state.buildID, canSpend = false,
        warningEnabled = state.warnMismatch == true and NS.IsTalentBuildSystemEnabled(),
        hasMismatch = false, canRespec = false, settled = false,
        targetName = "Talent data unavailable", nextName = "—", status = "Unable to read the talent tree. No points were spent.",
        detail = "Open Blizzard's talent window and try again." }
end

function NS.GetTalentSpendAllInfo()
    -- An explicit click may retry after a previous automatic pass failed;
    -- all other compatibility, conflict, combat and staged-edit gates remain.
    local ok, info = pcall(Inspect, { assessment = true })
    if not ok then return { canSpend = false, status = "Talent data is unavailable; try again when the tree settles." } end
    if not C_Traits or not C_Traits.RollbackConfig or not C_Traits.IsReadyForCommit then
        info.canSpend = false
        info.status = "Safe batch talent commits are unavailable on this client."
    end
    return info
end

function NS.GetTalentSBAAssessment()
    local ok, info = pcall(Inspect, { assessment = true })
    if not ok then info = NS.GetTalentLevelingInfo() end
    info.message = info.hasMismatch and "Your talents differ from the chosen SBA build." or info.status
    info.failure = info.specID and faults[info.specID]
    if info.failure then info.detail = (info.detail or "") .. " " .. info.failure end
    return info
end

local function NotifyWarning(assessment, force)
    if not NS.CheckTalentSBAWarning then return end
    if not assessment.warningEnabled then
        if force or lastWarning then NS.CheckTalentSBAWarning(assessment) end
        lastWarning = nil
        return
    end
    if not assessment.settled then
        if force or lastWarning then NS.CheckTalentSBAWarning(assessment) end
        -- The UI preserves an explicit dismissal while hidden. Re-notify when
        -- the tree settles so an undismissed warning can become visible again.
        lastWarning = nil
        return
    end
    local signature = assessment.hasMismatch and assessment.signature or "clear"
    if force or lastWarning ~= signature then
        lastWarning = signature
        NS.CheckTalentSBAWarning(assessment)
    end
end

function NS.SetTalentSBAWarningEnabled(enabled)
    NS.GetTalentLevelingState().warnMismatch = enabled == true
    NotifyWarning(NS.GetTalentSBAAssessment(), true)
    Refresh()
    return true
end

function NS.SetTalentAutoRespecEnabled(enabled)
    NS.GetTalentLevelingState().autoRespec = enabled == true
    if enabled then NS.ScheduleTalentLevelingCheck() end
    Refresh()
    return true
end

function NS.IsTalentLevelingBusy() return pending ~= nil end

function NS.SetTalentLevelingTarget(buildID)
    if pending or NS.IsTalentBuildImportPending() then return false, "Wait for the current talent change to finish." end
    local specID = NS.GetTalentBuildCurrentSpecID()
    if not specID then return false, "Specialization unavailable." end
    local state = NS.GetTalentLevelingState(specID)
    if buildID == NS.TALENT_BUILD_CUSTOM_ID then
        state.buildID, state.enabled = buildID, false
        faults[specID] = nil
        NS.ScheduleTalentLevelingCheck()
        Refresh()
        return true
    end
    local entry = NS.FindTalentBuildByID(buildID)
    if not entry or entry.specID ~= specID or entry.classToken ~= NS.GetTalentBuildClassToken() then
        return false, "Choose a build for your current specialization."
    end
    if not APIsReady() then return false, "Talent APIs are not ready." end
    local configID = C_ClassTalents.GetActiveConfigID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not configID or not treeID then return false, "Open Blizzard's talent window first." end
    local ok, targets, err = pcall(Targets, entry, configID)
    if not ok or not targets then return false, ok and err or "Unable to read this build." end
    local stamp = TreeStamp(treeID)
    if not stamp then return false, "Talent tree hash unavailable." end
    state.buildID, state.importString = buildID, entry.importString
    state.clientStamp, state.treeStamp = ClientStamp(), stamp
    faults[specID] = nil
    chainCount = 0
    NS.ScheduleTalentLevelingCheck()
    Refresh()
    return true
end

function NS.SetTalentLevelingEnabled(enabled)
    local state = NS.GetTalentLevelingState()
    if enabled and not NS.FindTalentBuildByID(state.buildID) then return false, "Choose a leveling target first." end
    state.enabled = enabled == true
    faults[NS.GetTalentBuildCurrentSpecID()] = nil
    chainCount = 0
    if state.enabled then NS.ScheduleTalentLevelingCheck() end
    Refresh()
    return true
end

local function RequestMatches(request)
    local state = NS.GetTalentLevelingState(request.specID)
    local entry = NS.FindTalentBuildByID(request.buildID)
    return pending == request and C_ClassTalents.GetActiveConfigID() == request.configID
        and NS.GetTalentBuildCurrentSpecID() == request.specID
        and NS.GetCharKey() == request.character
        and state.buildID == request.buildID and entry and entry.importString == request.importString
        and state.importString == request.importString and ClientStamp() == request.clientStamp
        and C_ClassTalents.GetTraitTreeForSpec(request.specID) == request.treeID
        and TreeStamp(request.treeID) == request.treeStamp
end

local function NewRequest(info)
    local state = NS.GetTalentLevelingState(info.specID)
    return { specID = info.specID, configID = info.configID, treeID = info.treeID,
        buildID = info.buildID, character = NS.GetCharKey(), importString = state.importString,
        clientStamp = state.clientStamp, treeStamp = state.treeStamp }
end

local function ReadAllocation(configID, treeID)
    local nodes = C_Traits.GetTreeNodes(treeID)
    if not nodes then return nil end
    local allocation = {}
    for _, nodeID in ipairs(nodes) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        -- A level-locked node can be listed in the tree before this config
        -- exposes NodeInfo. It has no purchased rank to save or restore yet.
        if node and type(node.ranksPurchased) ~= "number" then return nil end
        local ranks = node and node.ranksPurchased or 0
        allocation[nodeID] = { ranks = ranks,
            entryID = ranks > 0 and IsChoice(node, configID) and node.activeEntry and node.activeEntry.entryID or nil }
    end
    return allocation
end

local function AllocationMatches(request)
    local current = ReadAllocation(request.configID, request.treeID)
    if not current then return false end
    for nodeID, expected in pairs(request.expected) do
        local actual = current[nodeID]
        if not actual or actual.ranks ~= expected.ranks or actual.entryID ~= expected.entryID then return false end
        current[nodeID] = nil
    end
    return next(current) == nil
end

local function SavedAllocationMatches(configID, treeID, expected)
    if type(expected) ~= "table" then return false end
    return AllocationMatches({ configID = configID, treeID = treeID, expected = expected })
end

local function InspectUndo()
    local specID = NS.GetTalentBuildCurrentSpecID()
    if not specID then return { canUndo = false, status = "Specialization unavailable." } end
    local state = NS.GetTalentLevelingState(specID)
    local undo = state.respecUndo
    if not undo then return { canUndo = false, status = "No previous respec to undo." } end
    if pending or NS.IsTalentBuildImportPending() then
        return { canUndo = false, status = "Wait for the current talent change to finish." }
    end
    if not APIsReady() or not C_Traits.ResetTree or not C_Traits.RollbackConfig or not C_Traits.IsReadyForCommit then
        return { canUndo = false, status = "Talent APIs are not ready." }
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not configID or not treeID then return { canUndo = false, status = "Waiting for the active talent tree." } end
    local okStamp, treeStamp = pcall(TreeStamp, treeID)
    if not okStamp then return { canUndo = false, status = "Waiting for talent tree data." } end
    if undo.character ~= NS.GetCharKey() or undo.specID ~= specID or undo.configID ~= configID
        or undo.treeID ~= treeID or undo.buildID ~= state.buildID
        or undo.importString ~= state.importString or undo.clientStamp ~= ClientStamp()
        or undo.treeStamp ~= treeStamp then
        return { canUndo = false, status = "The spec, build, or talent tree changed since the respec." }
    end
    local okAllocation, matches = pcall(SavedAllocationMatches, configID, treeID, undo.after)
    if not okAllocation or not matches then
        return { canUndo = false, status = "Talents changed since the respec; undo cannot safely replace them." }
    end
    if InCombatLockdown() then return { canUndo = false, status = "Wait for combat to end." } end
    if C_Traits.ConfigHasStagedChanges(configID) then
        return { canUndo = false, status = "Apply or discard your pending talent edits first." }
    end
    local editable, reason = C_ClassTalents.CanEditTalents()
    if not editable then return { canUndo = false, status = reason or "Talents cannot be edited right now." } end
    return { canUndo = true, status = "Restore the talents you had before the SBA respec.", targetName = undo.targetName }
end

function NS.GetTalentSBAUndoInfo()
    local ok, info = pcall(InspectUndo)
    if ok then return info end
    return { canUndo = false, status = "Talent data is unavailable; try again when the tree settles." }
end

local function Fail(request, text)
    if pending ~= request then return faults[request.specID] end
    pending = nil
    if request.ownsChanges and not request.commitAccepted then
        local ok, restored = pcall(C_Traits.RollbackConfig, request.configID)
        if not ok or not restored then text = text .. " WoW could not roll back staged talents; review pending talents." end
    end
    faults[request.specID] = text .. (request.restore and " Review pending talents, then retry undo."
        or request.respec and " Review pending talents, then retry the respec."
        or request.bulk and " Review pending talents, then retry Spend All."
        or " Review pending talents, then toggle auto-spend off/on to retry.")
    if request.respec or request.restore then NotifyWarning(NS.GetTalentSBAAssessment(), true) end
    Refresh()
    return faults[request.specID]
end

local function Finish(request)
    if pending ~= request or not request.commitSent then return false end
    if not RequestMatches(request) then
        Fail(request, "The active talent configuration changed.")
        return false
    end
    if C_Traits.ConfigHasStagedChanges(request.configID) then return false end
    local confirmed
    if request.respec or request.restore or request.bulk then
        confirmed = AllocationMatches(request)
    else
        local node = C_Traits.GetNodeInfo(request.configID, request.pick.nodeID)
        confirmed = node and node.ranksPurchased == request.pick.before + 1
            and (not request.pick.choice or (node.activeEntry and node.activeEntry.entryID == request.pick.entryID))
    end
    if not confirmed then
        Fail(request, "The talent change could not be confirmed.")
        return false
    end
    pending = nil
    faults[request.specID] = nil
    local state = NS.GetTalentLevelingState(request.specID)
    if request.respec then
        state.respecUndo = { before = request.before, after = request.expected,
            character = request.character, specID = request.specID, configID = request.configID,
            treeID = request.treeID, buildID = request.buildID, importString = request.importString,
            clientStamp = request.clientStamp, treeStamp = request.treeStamp, targetName = request.targetName }
    elseif request.restore then
        state.respecUndo = nil
        state.enabled = false -- Do not immediately auto-spend into the just-restored allocation.
    end
    if NS.ClearBaseCDCache then NS.ClearBaseCDCache() end
    if NS.InvalidateRotationCache then NS.InvalidateRotationCache() end
    if NS.RebuildMacroText then NS.RebuildMacroText() end
    if NS.UpdateNow then NS.UpdateNow() end
    if request.automatic or request.respec then NS.ScheduleTalentLevelingCheck() end
    Refresh()
    return true
end

function NS.SpendAllTalentPoints()
    local info = NS.GetTalentSpendAllInfo()
    if not info.canSpend then return false, info.status end
    local request = NewRequest(info)
    request.bulk = true
    faults[request.specID] = nil
    pending = request -- Own only ranks staged by this click; block other spenders.
    local ok, result = pcall(function()
        assert(RequestMatches(request), "The active talent configuration changed.")
        assert(not C_Traits.ConfigHasStagedChanges(request.configID), "Apply or discard your pending talent edits first.")
        local purchased = 0
        for _ = 1, MAX_CHAIN do
            assert(RequestMatches(request), "The active talent configuration changed.")
            local nextInfo = Inspect({ request = request })
            if not nextInfo.canSpend then
                assert(nextInfo.settled and not nextInfo.hasMismatch, nextInfo.status or "Talent data changed.")
                break
            end
            local pick = nextInfo.pick
            local node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            assert(node and node.ranksPurchased == pick.before, "The staged allocation changed unexpectedly.")
            request.ownsChanges = true
            if pick.choice and (not node.activeEntry or node.activeEntry.entryID ~= pick.entryID) then
                assert(C_Traits.SetSelection(request.configID, pick.nodeID, pick.entryID) ~= false,
                    "Unable to select a target talent.")
            end
            assert(C_Traits.PurchaseRank(request.configID, pick.nodeID) ~= false,
                "Unable to buy a target talent.")
            node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            assert(node and node.ranksPurchased == pick.before + 1
                and (not pick.choice or (node.activeEntry and node.activeEntry.entryID == pick.entryID)),
                "Unable to verify a staged talent rank.")
            purchased = purchased + 1
        end
        assert(purchased > 0, "No eligible talent ranks can be allocated to this target.")
        local finalInfo = Inspect({ request = request })
        assert(finalInfo.settled and not finalInfo.hasMismatch, finalInfo.status or "Talent data changed.")
        assert(not finalInfo.canSpend, "Talent pass limit reached before all available points were staged.")
        request.expected = ReadAllocation(request.configID, request.treeID)
        assert(request.expected and AllocationMatches(request), "Unable to verify the staged talent plan.")
        assert(C_Traits.IsReadyForCommit(request.configID), "WoW did not accept the staged talent plan.")
        return purchased
    end)
    if not ok then
        local message = tostring(result):gsub("^.-:%d+: ", "")
        return false, Fail(request, message)
    end
    request.commitSent = true
    local called, success = pcall(C_ClassTalents.CommitConfig)
    if not called or not success then return false, Fail(request, "WoW could not apply the staged talents.") end
    request.commitAccepted = true
    if pending == request then
        NS.C_Timer_After(COMMIT_TIMEOUT, function()
            if pending == request and not Finish(request) then
                Fail(request, "Timed out waiting for WoW to confirm the talent plan.")
            end
        end)
        NS.ScheduleTalentLevelingCheck()
    end
    Refresh()
    return true, "Applying " .. tostring(result) .. (result == 1 and " talent rank" or " talent ranks")
        .. " to " .. info.targetName .. "."
end

function NS.SpendNextTalentPoint(automatic)
    local info = NS.GetTalentLevelingInfo()
    if not info.canSpend or (automatic and not info.enabled) then return false, info.status end
    if chainCount >= MAX_CHAIN then return false, "Leveling pass limit reached. Toggle auto-spend to resume." end
    chainCount = chainCount + 1
    local request = NewRequest(info)
    request.pick, request.automatic = info.pick, automatic == true
    pending = request -- Set before mutation: staging itself emits trait events.
    local ok, staged = pcall(function()
        local pick = request.pick
        local node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
        if pick.choice and (not node.activeEntry or node.activeEntry.entryID ~= pick.entryID) then
            C_Traits.SetSelection(request.configID, pick.nodeID, pick.entryID)
        end
        node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
        if node and node.ranksPurchased == pick.before then
            C_Traits.PurchaseRank(request.configID, pick.nodeID)
        end
        node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
        return node and node.ranksPurchased == pick.before + 1
            and (not pick.choice or (node.activeEntry and node.activeEntry.entryID == pick.entryID))
            and C_Traits.ConfigHasStagedChanges(request.configID)
    end)
    if not ok or not staged then
        Fail(request, "Unable to stage the next talent.")
        return false
    end
    -- nil commits the active staged talents without supplying an unrelated
    -- saved-loadout ID. Active config IDs are not saved-loadout IDs.
    request.commitSent = true
    local called, success = pcall(C_ClassTalents.CommitConfig)
    if not called or not success then
        Fail(request, "WoW could not apply the talent point.")
        return false
    end
    if pending == request then
        NS.C_Timer_After(COMMIT_TIMEOUT, function()
            if pending == request and not Finish(request) then
                Fail(request, "Timed out waiting for WoW to confirm the talent point.")
            end
        end)
        NS.ScheduleTalentLevelingCheck()
    end
    Refresh()
    return true
end

function NS.RequestTalentSBARespec()
    local info = NS.GetTalentSBAAssessment()
    if not info.canRespec or not info.hasMismatch then return false, info.message end
    local request = NewRequest(info)
    request.respec = true
    request.targetName = info.targetName
    faults[request.specID] = nil
    pending = request -- Block normal spending and imports before reset emits events.
    local ok, result = pcall(function()
        assert(RequestMatches(request), "The active talent configuration changed.")
        assert(not C_Traits.ConfigHasStagedChanges(request.configID), "Apply or discard your pending talent edits first.")
        assert(not InCombatLockdown() and C_ClassTalents.CanEditTalents(), "Talents cannot be edited right now.")
        local originalCurrencies = {}
        for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false) or {}) do
            assert(type(currency.quantity) == "number", "Talent currency data is not ready.")
            originalCurrencies[currency.traitCurrencyID] = currency.quantity
        end
        assert(next(originalCurrencies), "Talent currency data is not ready.")
        request.before = ReadAllocation(request.configID, request.treeID)
        assert(request.before, "Unable to save the original talent allocation.")
        request.ownsChanges = true
        assert(C_Traits.ResetTree(request.configID, request.treeID), "WoW could not reset the talent tree.")
        request.expected = ReadAllocation(request.configID, request.treeID)
        assert(request.expected, "Unable to read the reset talent tree.")
        for _, allocation in pairs(request.expected) do
            assert(allocation.ranks == 0, "The talent reset left paid ranks behind.")
        end
        local resetCurrencies = {}
        for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false) or {}) do
            local before = originalCurrencies[currency.traitCurrencyID]
            assert(type(currency.quantity) == "number" and before ~= nil and currency.quantity >= before,
                "The talent reset did not preserve the available point budget.")
            resetCurrencies[currency.traitCurrencyID] = currency.quantity
        end
        for currencyID in pairs(originalCurrencies) do
            assert(resetCurrencies[currencyID] ~= nil, "Talent currency data changed during the reset.")
        end
        local purchased = 0
        for _ = 1, MAX_CHAIN do
            assert(RequestMatches(request), "The active talent configuration changed.")
            local nextInfo = Inspect({ request = request })
            assert(nextInfo.settled and not nextInfo.hasMismatch, nextInfo.status)
            if not nextInfo.canSpend then break end
            local pick = nextInfo.pick
            local expected = request.expected[pick.nodeID]
            assert(expected and expected.ranks == pick.before, "The staged allocation changed unexpectedly.")
            local node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            if pick.choice and (not node.activeEntry or node.activeEntry.entryID ~= pick.entryID) then
                assert(C_Traits.SetSelection(request.configID, pick.nodeID, pick.entryID) ~= false, "Unable to select a target talent.")
            end
            node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            if node and node.ranksPurchased == pick.before then
                assert(C_Traits.PurchaseRank(request.configID, pick.nodeID) ~= false, "Unable to buy a target talent.")
            end
            node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            assert(node and node.ranksPurchased == pick.before + 1
                and (not pick.choice or (node.activeEntry and node.activeEntry.entryID == pick.entryID)),
                "Unable to verify a staged talent rank.")
            expected.ranks, expected.entryID = pick.before + 1, pick.choice and pick.entryID or nil
            purchased = purchased + 1
        end
        assert(RequestMatches(request), "The active talent configuration changed.")
        local finalInfo = Inspect({ request = request })
        assert(finalInfo.settled and not finalInfo.hasMismatch and not finalInfo.canSpend,
            "The level-appropriate allocation did not finish.")
        assert(AllocationMatches(request), "The staged allocation differs from the verified plan.")
        local remainingCurrencies = C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false)
        assert(remainingCurrencies, "Talent currency data is not ready.")
        for _, currency in ipairs(remainingCurrencies) do
            assert(type(currency.quantity) == "number" and currency.quantity >= 0
                and resetCurrencies[currency.traitCurrencyID] ~= nil
                and currency.quantity <= resetCurrencies[currency.traitCurrencyID],
                "The staged talent plan exceeded the available point budget.")
            resetCurrencies[currency.traitCurrencyID] = nil
        end
        assert(not next(resetCurrencies), "Talent currency data changed during the respec.")
        assert(C_Traits.ConfigHasStagedChanges(request.configID) and C_Traits.IsReadyForCommit(),
            "WoW did not accept the staged talent plan.")
        return purchased
    end)
    if not ok or pending ~= request then
        local message = ok and "The active talent configuration changed." or tostring(result):gsub("^.-:%d+: ", "")
        local failure = Fail(request, message)
        return false, failure or message
    end
    request.commitSent = true
    local called, success = pcall(C_ClassTalents.CommitConfig)
    if not called or not success then
        local failure = Fail(request, "WoW could not apply the staged respec.")
        return false, failure
    end
    request.commitAccepted = true
    if pending == request then
        NS.C_Timer_After(COMMIT_TIMEOUT, function()
            if pending == request and not Finish(request) then
                Fail(request, "Timed out waiting for WoW to confirm the respec.")
            end
        end)
        NS.ScheduleTalentLevelingCheck()
    end
    Refresh()
    if result == 0 then
        return true, "Resetting conflicting talents. The target has no ranks available at this level yet."
    end
    return true, "Applying " .. tostring(result) .. " talent ranks to " .. info.targetName .. "."
end

function NS.SpendAllOrRespecTalentPoints()
    local info = NS.GetTalentSpendAllInfo()
    if info.hasMismatch and info.canRespec then
        -- A full import can contain more points than this character has.
        -- Rebuild through the live tree so each class, spec, and hero purchase
        -- respects the current level and the confirmed allocation can be undone.
        return NS.RequestTalentSBARespec()
    end
    return NS.SpendAllTalentPoints()
end

function NS.RequestTalentSBAUndo()
    local availability = NS.GetTalentSBAUndoInfo()
    if not availability.canUndo then return false, availability.status end
    local specID = NS.GetTalentBuildCurrentSpecID()
    local undo = NS.GetTalentLevelingState(specID).respecUndo
    local request = { specID = specID, configID = undo.configID, treeID = undo.treeID,
        buildID = undo.buildID, character = undo.character, importString = undo.importString,
        clientStamp = undo.clientStamp, treeStamp = undo.treeStamp, expected = undo.before,
        restore = true }
    pending = request -- Own only changes staged from this point forward.
    local ok, result = pcall(function()
        assert(RequestMatches(request) and SavedAllocationMatches(request.configID, request.treeID, undo.after),
            "The talent allocation changed before undo started.")
        local originalCurrencies = {}
        for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false) or {}) do
            assert(type(currency.quantity) == "number", "Talent currency data is not ready.")
            originalCurrencies[currency.traitCurrencyID] = currency.quantity
        end
        assert(next(originalCurrencies), "Talent currency data is not ready.")
        request.ownsChanges = true
        assert(C_Traits.ResetTree(request.configID, request.treeID), "WoW could not reset the talent tree for undo.")
        local blank = ReadAllocation(request.configID, request.treeID)
        assert(blank, "Unable to read the reset talent tree.")
        for _, allocation in pairs(blank) do
            assert(allocation.ranks == 0, "The talent reset left paid ranks behind.")
        end
        local purchased = 0
        for _ = 1, MAX_CHAIN do
            assert(RequestMatches(request), "The active talent configuration changed.")
            local currencies = {}
            for _, currency in ipairs(C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false) or {}) do
                currencies[currency.traitCurrencyID] = currency.quantity or 0
            end
            local candidates = {}
            for nodeID, desired in pairs(request.expected) do
                local node = C_Traits.GetNodeInfo(request.configID, nodeID)
                assert(desired.ranks == 0 or (node and type(node.ranksPurchased) == "number"),
                    "The talent tree changed during undo.")
                assert(not node or node.ranksPurchased <= desired.ranks, "A staged talent exceeds the original allocation.")
                if node and node.ranksPurchased < desired.ranks then
                    local choice = IsChoice(node, request.configID)
                    local entryID = choice and desired.entryID
                        or (node.nextEntry and node.nextEntry.entryID)
                        or (node.entryIDs and node.entryIDs[1])
                    if entryID and node.canPurchaseRank and node.isAvailable ~= false
                        and C_Traits.CanPurchaseRank(request.configID, nodeID, entryID)
                        and CanAfford(request.configID, nodeID, currencies) then
                        candidates[#candidates + 1] = { nodeID = nodeID, node = node,
                            entryID = entryID, choice = choice }
                    end
                end
            end
            if #candidates == 0 then break end
            table.sort(candidates, function(a, b)
                local ay, by = a.node.posY or 0, b.node.posY or 0
                if ay ~= by then return ay < by end
                local ax, bx = a.node.posX or 0, b.node.posX or 0
                if ax ~= bx then return ax < bx end
                return a.nodeID < b.nodeID
            end)
            local pick = candidates[1]
            local before = pick.node.ranksPurchased
            if pick.choice and (not pick.node.activeEntry or pick.node.activeEntry.entryID ~= pick.entryID) then
                assert(C_Traits.SetSelection(request.configID, pick.nodeID, pick.entryID) ~= false,
                    "Unable to restore an original talent choice.")
            end
            local node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            if node and node.ranksPurchased == before then
                assert(C_Traits.PurchaseRank(request.configID, pick.nodeID) ~= false,
                    "Unable to restore an original talent rank.")
            end
            node = C_Traits.GetNodeInfo(request.configID, pick.nodeID)
            assert(node and node.ranksPurchased == before + 1
                and (not pick.choice or (node.activeEntry and node.activeEntry.entryID == pick.entryID)),
                "Unable to verify a restored talent rank.")
            purchased = purchased + 1
        end
        assert(SavedAllocationMatches(request.configID, request.treeID, request.expected),
            "The original allocation cannot be reconstructed at this level.")
        local remaining = C_Traits.GetTreeCurrencyInfo(request.configID, request.treeID, false)
        assert(remaining, "Talent currency data is not ready.")
        for _, currency in ipairs(remaining) do
            assert(type(currency.quantity) == "number" and currency.quantity >= 0
                and currency.quantity <= (originalCurrencies[currency.traitCurrencyID] or 0),
                "Undo cannot reuse the existing talent points.")
            originalCurrencies[currency.traitCurrencyID] = nil
        end
        assert(not next(originalCurrencies), "Talent currency data changed during undo.")
        assert(C_Traits.ConfigHasStagedChanges(request.configID) and C_Traits.IsReadyForCommit(),
            "WoW did not accept the restored talent plan.")
        return purchased
    end)
    if not ok or pending ~= request then
        local message = ok and "The active talent configuration changed." or tostring(result):gsub("^.-:%d+: ", "")
        local failure = Fail(request, message)
        return false, failure or message
    end
    request.commitSent = true
    local called, success = pcall(C_ClassTalents.CommitConfig)
    if not called or not success then
        return false, Fail(request, "WoW could not apply the restored talent plan.")
    end
    request.commitAccepted = true
    if pending == request then
        NS.C_Timer_After(COMMIT_TIMEOUT, function()
            if pending == request and not Finish(request) then
                Fail(request, "Timed out waiting for WoW to confirm undo.")
            end
        end)
        NS.ScheduleTalentLevelingCheck()
    end
    Refresh()
    return true, "Restoring " .. tostring(result) .. " talent ranks from before the SBA respec."
end

function NS.ScheduleTalentLevelingCheck()
    if scheduled then return end
    scheduled = true
    NS.C_Timer_After(0.25, function()
        scheduled = nil
        if not NS.IsTalentBuildSystemEnabled() then return end
        if pending then
            if pending.commitSent then Finish(pending) end
            return
        end
        local info = NS.GetTalentLevelingInfo()
        if info.enabled and info.autoRespecEnabled and info.hasMismatch and info.canRespec then
            local ok = NS.RequestTalentSBARespec()
            if not ok then NotifyWarning(NS.GetTalentSBAAssessment()); Refresh() end
        elseif info.enabled and info.canSpend then
            NS.SpendNextTalentPoint(true)
        else
            chainCount = 0
            NotifyWarning(NS.GetTalentSBAAssessment())
            Refresh()
        end
    end)
end

function NS.OnTalentLevelingEvent(event, ...)
    if event == "CONFIG_COMMIT_FAILED" then
        if pending and (...) == pending.configID then Fail(pending, "WoW rejected the talent change.") end
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit and unit ~= "player" then return end
        if pending then Fail(pending, "The specialization changed before the talent was confirmed.") end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if pending and (...) == pending.configID then
            if not pending.commitSent then return end
            Finish(pending)
        end
    elseif event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        local treeID = ...
        local specID = NS.GetTalentBuildCurrentSpecID()
        if not specID or treeID ~= C_ClassTalents.GetTraitTreeForSpec(specID) then return end
    elseif event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ALIVE"
        and event ~= "PLAYER_UNGHOST" and event ~= "PLAYER_ENTERING_WORLD"
        and event ~= "PLAYER_LEVEL_UP" and event ~= "PLAYER_REGEN_ENABLED" then
        return
    end
    NS.ScheduleTalentLevelingCheck()
end
