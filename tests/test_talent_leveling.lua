-- Run from the addon root: lua tests/test_talent_leveling.lua
-- Exercises the real incremental-leveling module with a small trait API mock.

local function check(value, message)
    assert(value, message)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function makeHarness(options)
    options = options or {}
    local h = {
        specID = 100,
        classToken = "MAGE",
        configID = 1,
        treeBySpec = { [100] = 10, [101] = 11 },
        treeHash = { [10] = { "mage", "one" }, [11] = { "mage", "two" } },
        client = { "11.2.0", "12345", nil, "110200" },
        staged = false,
        timers = {},
        commits = 0,
        purchases = 0,
        selections = 0,
        imports = 0,
        resets = 0,
        rollbacks = 0,
        purchaseOrder = {},
        refreshes = 0,
        editable = true,
        currencies = {},
        nodes = {},
        entries = {},
    }

    h.entries.A = {
        id = "A", name = "Arcane SBA", specID = 100, classToken = "MAGE",
        importString = "arcane-export", patch = "11.2.0",
    }
    h.entries.B = {
        id = "B", name = "Fire SBA", specID = 101, classToken = "MAGE",
        importString = "fire-export", patch = "11.2.0",
    }
    h.rows = options.rows or {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 2, ranksPurchased = 1, selectionEntryID = 201 },
    }
    h.nodes[1] = { ranksPurchased = 0, canPurchaseRank = true, isAvailable = true, posY = 1, posX = 1, type = 1 }
    h.nodes[2] = { ranksPurchased = 0, canPurchaseRank = true, isAvailable = true, posY = 2, posX = 1, type = 1 }
    h.costs = { [1] = { { ID = 1, amount = 1 } }, [2] = { { ID = 1, amount = 1 } } }
    h.currencies[10] = { { traitCurrencyID = 1, quantity = 1 } }

    function h:runDue(delay, limit)
        local runs = 0
        for i = #self.timers, 1, -1 do
            if self.timers[i].delay == delay then
                local callback = table.remove(self.timers, i).callback
                callback()
                runs = runs + 1
                check(runs <= (limit or 10), "timer loop did not settle")
            end
        end
        return runs
    end

    function h:confirm()
        self.staged = false
        self.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", self.configID)
    end

    function h:selectTarget(id)
        local ok, message = self.NS.SetTalentLevelingTarget(id)
        check(ok, message or "target selection failed")
    end

    function h:info()
        return self.NS.GetTalentLevelingInfo()
    end

    _G.GetBuildInfo = function() return table.unpack(h.client) end
    _G.InCombatLockdown = function() return h.combat == true end
    _G.UnitIsDeadOrGhost = function() return h.dead == true end
    _G.Enum = { TraitNodeType = { Selection = 2, SubTreeSelection = 3 } }
    _G.C_Spell = { GetSpellName = function(spellID) return "Spell " .. tostring(spellID) end }
    _G.C_ClassTalents = {
        GetActiveConfigID = function() return h.configID end,
        CanEditTalents = function() return h.editable, h.editReason end,
        GetTraitTreeForSpec = function(specID) return h.treeBySpec[specID] end,
        CommitConfig = function()
            h.commits = h.commits + 1
            return h.commitSucceeds ~= false
        end,
    }
    _G.C_Traits = {
        GetTreeHash = function(treeID) return h.treeHash[treeID] end,
        GetTreeNodes = function(treeID) return treeID and h.treeNodes or nil end,
        GetNodeInfo = function(configID, nodeID) return configID == h.configID and h.nodes[nodeID] or nil end,
        GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
        GetDefinitionInfo = function(entryID) return { spellID = entryID } end,
        GetNodeCost = function(_, nodeID) return h.costs[nodeID] end,
        GetTreeCurrencyInfo = function(_, treeID) return h.currencies[treeID] end,
        CanPurchaseRank = function(_, nodeID, entryID)
            local node = h.nodes[nodeID]
            return node and node.canPurchaseRank and node.isAvailable ~= false and entryID ~= nil
        end,
        PurchaseRank = function(_, nodeID)
            local node = h.nodes[nodeID]
            if not h.staged then
                h.beforeStage = { nodes = copy(h.nodes), currencies = copy(h.currencies), staged = h.staged }
            end
            h.purchases = h.purchases + 1
            h.purchaseOrder[#h.purchaseOrder + 1] = nodeID
            node.ranksPurchased = node.ranksPurchased + 1
            if h.useBudgets then
                for _, cost in ipairs(h.costs[nodeID] or {}) do
                    for _, currency in ipairs(h.currencies[h.treeBySpec[h.specID]]) do
                        if currency.traitCurrencyID == cost.ID then currency.quantity = currency.quantity - cost.amount end
                    end
                end
            end
            h.staged = true
            if h.onPurchase then h.onPurchase(nodeID) end
            return h.failPurchaseAt ~= h.purchases
        end,
        SetSelection = function(_, nodeID, entryID)
            if not h.staged then
                h.beforeStage = { nodes = copy(h.nodes), currencies = copy(h.currencies), staged = h.staged }
            end
            h.selections = h.selections + 1
            h.nodes[nodeID].activeEntry = { entryID = entryID }
            h.staged = true
            return true
        end,
        ConfigHasStagedChanges = function(configID) return configID == h.configID and h.staged end,
        ResetTree = function(_, treeID)
            h.resets = h.resets + 1
            h.beforeReset = { nodes = copy(h.nodes), currencies = copy(h.currencies), staged = h.staged }
            for nodeID, node in pairs(h.nodes) do
                for _, cost in ipairs(h.costs[nodeID] or {}) do
                    for _, currency in ipairs(h.currencies[treeID]) do
                        if currency.traitCurrencyID == cost.ID then
                            currency.quantity = currency.quantity + cost.amount * node.ranksPurchased
                        end
                    end
                end
                node.ranksPurchased, node.activeEntry = 0, nil
            end
            h.staged = true
            if h.onReset then h.onReset() end
            return h.resetSucceeds ~= false
        end,
        RollbackConfig = function(configID)
            h.rollbacks = h.rollbacks + 1
            check(configID == 1, "rollback must target only the configuration owned by the request")
            if h.beforeReset then
                h.nodes, h.currencies, h.staged = copy(h.beforeReset.nodes), copy(h.beforeReset.currencies), h.beforeReset.staged
            elseif h.beforeStage then
                h.nodes, h.currencies, h.staged = copy(h.beforeStage.nodes), copy(h.beforeStage.currencies), h.beforeStage.staged
            end
            if h.onRollback then h.onRollback() end
            return h.rollbackSucceeds ~= false
        end,
        IsReadyForCommit = function() return h.readyForCommit ~= false end,
    }

    local NS = {
        dbRoot = {}, TALENT_BUILD_CUSTOM_ID = "CUSTOM",
        GetCharKey = function() return h.character or "Tester-Realm" end,
        GetTalentBuildCurrentSpecID = function() return h.specID end,
        GetTalentBuildSpecName = function(id) return id == 100 and "Arcane" or "Fire" end,
        GetTalentBuildClassToken = function() return h.classToken end,
        FindTalentBuildByID = function(id) return h.entries[id] end,
        DecodeTalentBuildTarget = function(entry)
            if h.decodeError then return nil, h.decodeError end
            return h.rows
        end,
        IsTalentBuildSystemEnabled = function() return h.systemEnabled ~= false end,
        IsTalentBuildImportPending = function() return h.importPending == true end,
        C_Timer_After = function(delay, callback) h.timers[#h.timers + 1] = { delay = delay, callback = callback } end,
        RefreshTalentBuildPanels = function() h.refreshes = h.refreshes + 1 end,
        ClearBaseCDCache = function() h.clearedCache = true end,
        InvalidateRotationCache = function() h.invalidated = true end,
        RebuildMacroText = function() h.rebuilt = true end,
        UpdateNow = function() h.updated = true end,
        RequestTalentBuildApply = function() h.imports = h.imports + 1 end,
        ResetConfig = function() h.resets = h.resets + 1 end,
    }
    h.treeNodes = options.treeNodes or { 1, 2 }
    h.NS = NS
    assert(loadfile("Core/Functions/TalentLeveling.lua"))("BetterSBA", NS)
    return h
end

-- The tree-window action buys every legal rank in the selected target across
-- separate class/spec/hero currencies, then sends exactly one commit.
do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 2, ranksPurchased = 1, selectionEntryID = 201 },
        { nodeID = 3, ranksPurchased = 1, selectionEntryID = 301 },
    }, treeNodes = { 1, 2, 3 } })
    h.nodes[3] = { ranksPurchased = 0, canPurchaseRank = true, isAvailable = true, posY = 3, posX = 1, type = 1 }
    h.costs[1] = { { ID = 1, amount = 1 } }
    h.costs[2] = { { ID = 2, amount = 1 } }
    h.costs[3] = { { ID = 3, amount = 1 } }
    h.currencies[10] = {
        { traitCurrencyID = 1, quantity = 1 },
        { traitCurrencyID = 2, quantity = 1 },
        { traitCurrencyID = 3, quantity = 1 },
    }
    h.useBudgets = true
    h:selectTarget("A")
    check(h.NS.GetTalentSpendAllInfo().canSpend, "spend-all should enable for a legal selected target")
    local ok, message = h.NS.SpendAllOrRespecTalentPoints()
    check(ok and message:find("3 talent ranks", 1, true), "spend-all must report the full batch")
    check(h.purchases == 3 and h.commits == 1 and h.resets == 0 and h.imports == 0,
        "spend-all must fill class/spec/hero targets with one commit and no reset or import")
    check(not h.NS.SpendAllTalentPoints() and h.purchases == 3,
        "a pending batch must block duplicate clicks")
    h:confirm()
    check(not h.NS.IsTalentLevelingBusy() and not h.NS.GetTalentSpendAllInfo().canSpend,
        "confirmed full batch must settle with no further eligible ranks")
end

-- Being dead can make editing temporarily unavailable. Auto-Spend stays on
-- and resumes after the alive/ghost transition rather than needing a reload.
do
    local h = makeHarness()
    h.dead = true
    h:selectTarget("A")
    check(h.NS.SetTalentLevelingEnabled(true), "the route switch must save while editing is unavailable")
    h:runDue(.25)
    check(h.purchases == 0 and h.NS.GetTalentLevelingState().enabled
        and h:info().status:find("until you are alive", 1, true),
        "temporary edit restrictions must not switch Auto-Spend off")
    h.dead = false
    h.NS.OnTalentLevelingEvent("PLAYER_ALIVE")
    h:runDue(.25)
    check(h.purchases == 1 and h.commits == 1,
        "Auto-Spend must resume when the player is alive again")
end

-- A max-level target can contain hero ranks before the character unlocks
-- them. Spend the available class point and leave the locked hero rank alone.
do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 7, ranksPurchased = 1, selectionEntryID = 701 },
    }, treeNodes = { 1, 7 } })
    h.nodes[7] = { ranksPurchased = 0, canPurchaseRank = false, isAvailable = false,
        posY = 3, type = Enum.TraitNodeType.SubTreeSelection, entryIDs = { 701, 702 } }
    h.costs[7] = { { ID = 3, amount = 1 } }
    h.currencies[10] = { { traitCurrencyID = 1, quantity = 1 }, { traitCurrencyID = 3, quantity = 0 } }
    h:selectTarget("A")
    check(h:info().pick.nodeID == 1, "a locked hero choice must not block an available class talent")
    local ok = h.NS.SpendAllOrRespecTalentPoints()
    check(ok and h.purchases == 1 and h.purchaseOrder[1] == 1 and h.selections == 0,
        "spend-all must never select or purchase a level-locked hero node")
    h:confirm()
    check(not h:info().canSpend and h.nodes[7].ranksPurchased == 0,
        "the locked hero talent remains a future target after the class point commits")
end

-- A selected build still has a complete encoded hero choice even when the
-- current level supplies no entry ID for it. Reset both sides only on the
-- deliberate rebuild action, then stop at the last legal rank for this level.
do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 7, ranksPurchased = 1, deferred = true, choiceIndex = 1 },
    }, treeNodes = { 1, 7, 99 } })
    h.useBudgets = true
    h.nodes[7] = { ranksPurchased = 0, canPurchaseRank = false, isAvailable = false,
        posY = 3, type = Enum.TraitNodeType.SubTreeSelection, entryIDs = {} }
    h.nodes[99] = { ranksPurchased = 1, canPurchaseRank = false, type = 1 }
    h.costs[7] = { { ID = 3, amount = 1 } }
    h.costs[99] = { { ID = 1, amount = 1 } }
    h.currencies[10] = { { traitCurrencyID = 1, quantity = 0 }, { traitCurrencyID = 3, quantity = 0 } }
    h:selectTarget("A")
    local assessment = h.NS.GetTalentSBAAssessment()
    check(assessment.hasMismatch and assessment.canRespec,
        "a locked hero choice must not prevent identifying an off-target class talent")
    local ok = h.NS.SpendAllOrRespecTalentPoints()
    check(ok and h.resets == 1 and h.purchases == 1 and h.purchaseOrder[1] == 1,
        "rebuild must reset the tree and spend only the currently legal class rank")
    check(h.nodes[7].ranksPurchased == 0 and h.nodes[99].ranksPurchased == 0,
        "locked hero and off-target ranks must stay unpurchased")
    h:confirm()
    check(h:info().status:find("More in this route unlock later", 1, true),
        "the retained hero choice must remain pending until its tree unlocks")
end

-- Some clients do not expose NodeInfo at all for a locked hero node. Saving,
-- verifying and undoing a low-level rebuild must still cover both sides.
do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 7, deferred = true, fullRank = true, choiceIndex = 1 },
    }, treeNodes = { 1, 7, 99 } })
    h.useBudgets = true
    h.nodes[99] = { ranksPurchased = 1, type = 1, canPurchaseRank = true,
        isAvailable = true, entryIDs = { 991 } }
    h.costs[99] = { { ID = 1, amount = 1 } }
    h.currencies[10][1].quantity = 0
    h:selectTarget("A")
    check(h.NS.GetTalentSBAAssessment().canRespec, "an absent locked node must allow a rebuild")
    check(h.NS.RequestTalentSBARespec(), "rebuild must accept an absent locked node")
    check(h.resets == 1 and h.purchases == 1 and h.nodes[1].ranksPurchased == 1,
        "the refunded class point must go only to an available target rank")
    h:confirm()
    local undoOK, undoMessage = h.NS.RequestTalentSBAUndo()
    check(undoOK, "undo must accept the absent locked node too: " .. tostring(undoMessage))
    h:confirm()
    check(h.nodes[99].ranksPurchased == 1 and h.nodes[1].ranksPurchased == 0,
        "undo must restore the prior class allocation")
end

-- A rejected rank must roll back the entire staged batch; an incompatible
-- current allocation must be rejected before the first purchase.
do
    local h = makeHarness()
    h.currencies[10][1].quantity = 2
    h.useBudgets = true
    h:selectTarget("A")
    h.failPurchaseAt = 2
    local ok = h.NS.SpendAllTalentPoints()
    check(not ok and h.purchases == 2 and h.commits == 0 and h.rollbacks == 1,
        "partial spend-all failure must roll back without committing")
    check(h.nodes[1].ranksPurchased == 0 and h.nodes[2].ranksPurchased == 0
        and h.currencies[10][1].quantity == 2 and not h.staged,
        "failed batch must restore the exact pre-click allocation and currencies")

    local changed = makeHarness()
    changed.currencies[10][1].quantity = 2
    changed.useBudgets = true
    changed:selectTarget("A")
    changed.onPurchase = function() changed.editable = false end
    check(not changed.NS.SpendAllTalentPoints() and changed.commits == 0 and changed.rollbacks == 1,
        "a mid-batch editability change must roll back instead of committing only part of the plan")

    local conflict = makeHarness()
    conflict.nodes[1].ranksPurchased = 1
    conflict.nodes[1].activeEntry = { entryID = 999 }
    conflict.nodes[1].type = Enum.TraitNodeType.Selection
    conflict:selectTarget("A")
    check(not conflict.NS.GetTalentSpendAllInfo().canSpend and not conflict.NS.SpendAllTalentPoints()
        and conflict.purchases == 0,
        "conflicting learned choices must block the bulk action without resetting")
end

-- Explicit target selection and enabled auto-spend stage one rank and commit
-- it directly. There is no confirmation/prompt path and no full import/reset.
do
    local h = makeHarness()
    h:selectTarget("A")
    local ok, message = h.NS.SetTalentLevelingEnabled(true)
    check(ok, message)
    h:runDue(.25)
    check(h.purchases == 1 and h.commits == 1, "auto-spend must purchase and commit one rank without a prompt")
    check(h.imports == 0 and h.resets == 0, "leveling must never import or reset a build")
    check(h.NS.IsTalentLevelingBusy(), "a sent commit must prevent a second purchase until confirmed")
    h.NS.ScheduleTalentLevelingCheck(); h:runDue(.25)
    check(h.purchases == 1, "pending commit must prevent double-spend")
    h.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", h.configID)
    check(h.NS.IsTalentLevelingBusy(), "an early trait event must not allow a second spend while changes are still staged")
    h:confirm()
    check(not h.NS.IsTalentLevelingBusy(), "trait confirmation must clear the pending commit")
end

-- Currency order is irrelevant: all costs must be covered, then the legal
-- prerequisite-first candidate can be spent. A staged user edit blocks it.
do
    local h = makeHarness({ rows = { { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 } } })
    h.costs[1] = { { ID = 9, amount = 2 }, { ID = 3, amount = 1 } }
    h.currencies[10] = { { traitCurrencyID = 3, quantity = 1 }, { traitCurrencyID = 9, quantity = 2 } }
    h:selectTarget("A")
    check(h:info().canSpend, "multiple currencies in a different order must still be affordable")
    h.staged = true
    check(not h:info().canSpend and h:info().status:find("pending talent edits", 1, true), "user staged edits must block spending")
    h.staged = false
    check(h.NS.SpendNextTalentPoint(), "manual SPEND NEXT must work when auto-spend is off")
    check(h.commits == 1 and h.purchases == 1, "manual spend must commit exactly one point")
end

-- Choice and hero-subtree choices select their required entry first, whereas
-- multi-rank non-choice nodes use PurchaseRank and never selection/reset APIs.
do
    local h = makeHarness({
        rows = {
            { nodeID = 7, ranksPurchased = 1, selectionEntryID = 701 },
            { nodeID = 8, ranksPurchased = 1, selectionEntryID = 801 },
            { nodeID = 8, ranksPurchased = 1, selectionEntryID = 802 },
        },
        treeNodes = { 7, 8 },
    })
    h.nodes = {
        [7] = { ranksPurchased = 0, canPurchaseRank = true, isAvailable = true, posY = 1, posX = 1, type = Enum.TraitNodeType.SubTreeSelection },
        [8] = { ranksPurchased = 0, canPurchaseRank = true, isAvailable = true, posY = 2, posX = 1, type = 1 },
    }
    h.costs = { [7] = { { ID = 1, amount = 1 } }, [8] = { { ID = 1, amount = 1 } } }
    h:selectTarget("A")
    check(h.NS.SpendNextTalentPoint(), "hero subtree choice should be spendable")
    check(h.selections == 1 and h.nodes[7].activeEntry.entryID == 701, "hero subtree must select the target entry")
    h:confirm()
    h.currencies[10][1].quantity = 1
    check(h.NS.SpendNextTalentPoint(), "first rank of a multi-rank node should be spendable")
    check(h.selections == 1, "non-choice multiple-rank nodes must not call SetSelection")
    check(h.imports == 0 and h.resets == 0, "choice handling must remain incremental")

    local conflict = makeHarness({ rows = { { nodeID = 7, ranksPurchased = 1, selectionEntryID = 701 } }, treeNodes = { 7 } })
    conflict.nodes = {
        [7] = {
            ranksPurchased = 1, canPurchaseRank = true, isAvailable = true, posY = 1, posX = 1,
            type = Enum.TraitNodeType.Selection, activeEntry = { entryID = 799 },
        },
    }
    conflict.costs = { [7] = { { ID = 1, amount = 1 } } }
    conflict:selectTarget("A")
    local conflictInfo = conflict:info()
    check(not conflictInfo.canSpend and conflictInfo.status:find("learned talents differ", 1, true),
        "a manually chosen conflicting node must remain under user ownership")
    check(not conflict.NS.SpendNextTalentPoint() and conflict.selections == 0 and conflict.purchases == 0,
        "leveling must never replace an existing conflicting choice")
end

-- Combat and invalid active context pause the process; changing specs/config
-- while a commit is pending fails it rather than applying into another target.
do
    local h = makeHarness()
    h:selectTarget("A")
    h.combat = true
    check(not h:info().canSpend and h:info().status:find("combat", 1, true), "combat must pause leveling")
    h.combat = false
    h.NS.OnTalentLevelingEvent("PLAYER_REGEN_ENABLED")
    h:runDue(.25)
    check(h.purchases == 0, "combat-end event must not spend while auto-spend is off")
    check(h.NS.SpendNextTalentPoint(), "manual spending should start after combat")
    h.specID, h.configID = 101, 2
    h.NS.OnTalentLevelingEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    check(not h.NS.IsTalentLevelingBusy(), "spec switch must cancel the old pending request")
    check(h:info().buildID == "CUSTOM", "the other spec must retain its independent default target")

    local configSwitch = makeHarness()
    configSwitch:selectTarget("A")
    check(configSwitch.NS.SpendNextTalentPoint(), "config switch fixture must begin a commit")
    configSwitch.configID = 2
    configSwitch.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", 1)
    check(not configSwitch.NS.IsTalentLevelingBusy(), "active configuration switch must fail the old pending request")
end

-- Saving targets is character-local. Client/build changes pause a target until
-- reselected, and opting out before confirmation prevents continuation.
do
    local h = makeHarness()
    h:selectTarget("A")
    h.character = "Alt-Realm"
    check(h.NS.GetTalentLevelingState().buildID == "CUSTOM", "leveling settings must be isolated per character")
    h.character = "Tester-Realm"
    h.client[2] = "99999"
    check(h:info().status:find("changed", 1, true), "client changes must pause an existing target")
    h.client[2] = "12345"
    h.entries.A.importString = "changed-export"
    check(h:info().status:find("changed", 1, true), "target build changes must pause an existing target")
    h.entries.A.importString = "arcane-export"
    check(h.NS.SetTalentLevelingEnabled(true))
    h:runDue(.25)
    check(h.purchases == 1, "auto-spend must begin from an explicitly enabled target")
    check(h.NS.SetTalentLevelingEnabled(false), "user opt-out must be accepted while a commit is pending")
    h:confirm(); h:runDue(.25)
    check(h.purchases == 1, "opting out must stop automatic continuation after confirmation")
end

-- A rejected commit or confirmation timeout creates a fault and does not spin
-- retries from later trait/currency events.
do
    local h = makeHarness()
    h.useBudgets = true
    h:selectTarget("A")
    h.commitSucceeds = false
    check(not h.NS.SpendNextTalentPoint(), "failed CommitConfig must report failure")
    check(h.purchases == 1 and not h.NS.IsTalentLevelingBusy(), "failed commit must clear pending state once")
    h.NS.OnTalentLevelingEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", 10); h:runDue(.25)
    check(h.purchases == 1, "faulted target must not retry in an event loop")
    check(h.NS.GetTalentSBAAssessment().canRespec,
        "a clean failed commit must leave the manual rebuild button available")
    h.commitSucceeds = true
    check(h.NS.RequestTalentSBARespec(),
        "manual rebuild must be possible after a failed commit without a talent mismatch")
    h:confirm()

    local timeout = makeHarness()
    timeout:selectTarget("A")
    check(timeout.NS.SpendNextTalentPoint(), "timeout fixture must stage and send a commit")
    timeout:runDue(10)
    check(not timeout.NS.IsTalentLevelingBusy() and timeout:info().status:find("Timed out", 1, true), "commit timeout must fault and stop")
    timeout.NS.OnTalentLevelingEvent("PLAYER_LEVEL_UP"); timeout:runDue(.25)
    check(timeout.purchases == 1, "timed-out request must not auto-retry")

    -- A TRAIT_CONFIG_UPDATED signal can arrive before WoW has cleared the
    -- staged-change flag. The deferred .25 check must confirm it once after a
    -- later currency update, then continue one automatic rank at a time.
    local reordered = makeHarness()
    reordered:selectTarget("A")
    check(reordered.NS.SetTalentLevelingEnabled(true), "reordered-event fixture must enable auto-spend")
    reordered:runDue(.25)
    check(reordered.purchases == 1 and reordered.commits == 1 and reordered.NS.IsTalentLevelingBusy(),
        "initial automatic rank must be staged exactly once")
    reordered.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", reordered.configID)
    check(reordered.NS.IsTalentLevelingBusy(), "early staged config event must leave the request pending")
    reordered.staged = false
    reordered.NS.OnTalentLevelingEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", 10)
    reordered:runDue(.25)
    check(reordered.purchases == 1 and not reordered.NS.IsTalentLevelingBusy(),
        "the deferred confirmation check must finish the first rank once without a duplicate purchase")
    reordered:runDue(.25)
    check(reordered.purchases == 2 and reordered.commits == 2 and reordered.NS.IsTalentLevelingBusy(),
        "confirmed auto-spend must continue with exactly one next rank")
    reordered:confirm(); reordered:runDue(.25)
    check(reordered.purchases == 2 and not reordered.NS.IsTalentLevelingBusy(),
        "the completed two-rank sequence must not spend again")
    if reordered.NS.IsTalentLevelingBusy() then
        reordered:runDue(10)
    end
end

-- Class guidance changes which legal target rank comes next. Weights map to
-- definition spell IDs, never translated names; they cannot add outside nodes.
do
    local h = makeHarness()
    h.NS.TALENT_SBA_PRIORITIES = {
        [100] = { patch = "11.2", spells = {
            [201] = { priority = 90, name = "Core engine", reason = "Improves the SBA resource engine.", sourceURL = "https://example.test/guide" },
            [999] = { priority = 1000, name = "Outside target", reason = "Must never enter the plan." },
        } },
    }
    h:selectTarget("A")
    local info = h:info()
    check(info.pick.nodeID == 2 and info.reason:find("resource engine", 1, true),
        "a sourced core talent must outrank a legal top-row side talent")
    h.client[1] = "12.1.0"
    h:selectTarget("A")
    check(h:info().pick.nodeID == 1, "source weights from a previous patch must not leak into a new patch")
end

-- An unavailable high-priority talent can promote its actual connector,
-- without following visual-only or mutually-exclusive edges outside the path.
do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 2, ranksPurchased = 1, selectionEntryID = 201 },
        { nodeID = 3, ranksPurchased = 1, selectionEntryID = 301 },
    }, treeNodes = { 1, 2, 3 } })
    Enum.TraitEdgeType = { VisualOnly = 0, SufficientForAvailability = 2, RequiredForAvailability = 3, MutuallyExclusive = 4 }
    h.nodes[3] = { ranksPurchased = 0, canPurchaseRank = false, isAvailable = false, posY = 3, type = 1 }
    h.nodes[1].visibleEdges = { { targetNode = 3, type = 0 } }
    h.nodes[2].visibleEdges = { { targetNode = 3, type = 3 } }
    h.NS.TALENT_SBA_PRIORITIES = { [100] = { patch = "11.2", spells = {
        [301] = { priority = 90, name = "Core engine", reason = "Core synergy." },
    } } }
    h:selectTarget("A")
    check(h:info().pick.nodeID == 2 and h:info().reason:find("path toward Core engine", 1, true),
        "a required connector must inherit destination priority")
    h.entries.A.levelingOrder = { { nodeID = 1, rank = 1 }, { nodeID = 2, rank = 1 } }
    check(h:info().pick.nodeID == 1, "an authored rank order must take precedence over heuristic source weights")
end

local function makeRespecHarness(points)
    local h = makeHarness({ treeNodes = { 1, 2, 99 } })
    h.useBudgets = true
    h.currencies[10][1].quantity = points or 0
    h.nodes[99] = { ranksPurchased = 1, type = 1, canPurchaseRank = false }
    h.costs[99] = { { ID = 1, amount = 1 } }
    h:selectTarget("A")
    return h
end

-- The rebuild switch is independent of the warning. A chosen route can stay
-- enabled without resetting anything until this separate option is turned on.
do
    local h = makeRespecHarness()
    check(h.NS.SetTalentLevelingEnabled(true), "automatic spending must accept a selected route")
    h:runDue(.25)
    check(h.resets == 0 and h.nodes[99].ranksPurchased == 1,
        "automatic spending alone must not reset a mismatched tree")
    check(h.NS.SetTalentAutoRespecEnabled(true), "automatic rebuild switch must save")
    h:runDue(.25)
    check(h.resets == 1 and h.commits == 1 and h.purchases == 1
        and h.nodes[99].ranksPurchased == 0,
        "opted-in automatic rebuild must reset and spend only current-level legal ranks")
    h:confirm(); h:runDue(.25)
    check(h.resets == 1 and not h.NS.GetTalentSBAAssessment().hasMismatch,
        "successful automatic rebuild must not repeat after confirmation")
end

-- Warnings assess the selected target with auto-spend off, are opt-in per
-- character/spec, and never cause a reset or repeatedly alert on trait events.
do
    local h = makeRespecHarness()
    local alerts, hides = 0, 0
    h.NS.CheckTalentSBAWarning = function(assessment)
        if assessment.warningEnabled and assessment.settled and assessment.hasMismatch then
            alerts = alerts + 1
        else
            hides = hides + 1
        end
    end
    local assessment = h.NS.GetTalentSBAAssessment()
    check(assessment.hasMismatch and assessment.canRespec and not assessment.warningEnabled,
        "mismatch assessment must work with auto-spend and warnings off")
    check(assessment.signature and assessment.message:find("chosen SBA build", 1, true), "warning must identify a target difference")
    check(assessment.mismatchDetails and assessment.mismatchDetails:find("Talent 99 is learned", 1, true),
        "warning must name the off-target talent and explain the mismatch")
    h:runDue(.25)
    check(alerts == 0, "warning must default off")
    h.NS.SetTalentSBAWarningEnabled(true)
    check(alerts == 1 and h.resets == 0 and h.purchases == 0, "enabling warnings must only alert")
    h.NS.OnTalentLevelingEvent("PLAYER_LEVEL_UP"); h:runDue(.25)
    h.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", h.configID); h:runDue(.25)
    check(alerts == 1, "unchanged mismatch must not repeatedly alert")
    h.combat = true
    h.NS.ScheduleTalentLevelingCheck(); h:runDue(.25)
    check(hides == 1, "unsettled combat state must hide an existing alert")
    h.combat = false
    h.NS.OnTalentLevelingEvent("PLAYER_REGEN_ENABLED"); h:runDue(.25)
    check(alerts == 2, "settled state must notify the UI again so an undismissed warning can return")
    h.NS.SetTalentSBAWarningEnabled(false)
    check(hides == 2 and not h.NS.GetTalentLevelingState().warnMismatch, "disabling warnings must silence and persist")
    h.NS.SetTalentSBAWarningEnabled(true)
    h.NS.SetTalentLevelingTarget("CUSTOM"); h:runDue(.25)
    check(hides == 3, "clearing the target must hide its old warning")
    h.character = "Other-Realm"
    check(not h.NS.GetTalentSBAAssessment().warningEnabled, "warning opt-in must not leak across characters")
end

-- Undo restores the saved ranks and exact prior choice after a confirmed
-- respec. It becomes unavailable if another talent edit changes the result.
do
    local function fixture()
        local h = makeHarness({ rows = {
            { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
            { nodeID = 7, ranksPurchased = 1, selectionEntryID = 701 },
        }, treeNodes = { 1, 7, 99 } })
        h.useBudgets = true
        h.nodes[7] = { ranksPurchased = 1, type = Enum.TraitNodeType.SubTreeSelection,
            activeEntry = { entryID = 702 }, entryIDs = { 701, 702 },
            canPurchaseRank = true, isAvailable = true, posY = 2 }
        h.nodes[99] = { ranksPurchased = 1, type = 1, entryIDs = { 991 },
            canPurchaseRank = true, isAvailable = true, posY = 1 }
        h.costs[7], h.costs[99] = { { ID = 1, amount = 1 } }, { { ID = 1, amount = 1 } }
        h.currencies[10][1].quantity = 0
        h:selectTarget("A")
        return h
    end

    local h = fixture()
    local assessment = h.NS.GetTalentSBAAssessment()
    check(assessment.hasMismatch and assessment.mismatchDetails:find("Spell 702 is selected", 1, true)
        and assessment.mismatchDetails:find("Spell 701", 1, true),
        "choice warning must name both the learned and target entries")
    h.NS.SetTalentLevelingEnabled(true)
    check(h.NS.RequestTalentSBARespec(), "fixture respec must start")
    h:confirm()
    check(h.NS.GetTalentSBAUndoInfo().canUndo, "confirmed respec must expose undo")
    check(h.NS.RequestTalentSBAUndo(), "unchanged respec allocation must be restorable")
    check(h.resets == 2 and h.commits == 2 and h.nodes[99].ranksPurchased == 1
        and h.nodes[7].activeEntry and h.nodes[7].activeEntry.entryID == 702
        and h.nodes[1].ranksPurchased == 0,
        "undo must stage the original off-target rank and exact hero choice in one commit")
    h:confirm(); h:runDue(.25)
    check(not h.NS.IsTalentLevelingBusy() and not h.NS.GetTalentSBAUndoInfo().canUndo
        and not h.NS.GetTalentLevelingState().enabled,
        "confirmed undo must clear its snapshot and pause automatic reapplication")

    local changed = fixture()
    check(changed.NS.RequestTalentSBARespec(), "second respec fixture must start")
    changed:confirm()
    changed.nodes[99].ranksPurchased = 1
    check(not changed.NS.GetTalentSBAUndoInfo().canUndo and not changed.NS.RequestTalentSBAUndo()
        and changed.resets == 1, "intervening talent edits must block undo before a reset")

    local otherCharacter = fixture()
    check(otherCharacter.NS.RequestTalentSBARespec(), "character-isolation fixture respec must start")
    otherCharacter:confirm()
    otherCharacter.character = "Other-Realm"
    check(not otherCharacter.NS.GetTalentSBAUndoInfo().canUndo and not otherCharacter.NS.RequestTalentSBAUndo(),
        "the saved prior allocation must remain on the character that made the respec")

    local rejected = fixture()
    check(rejected.NS.RequestTalentSBARespec(), "failure fixture respec must start")
    rejected:confirm()
    rejected.readyForCommit = false
    check(not rejected.NS.RequestTalentSBAUndo() and rejected.rollbacks == 1
        and rejected.nodes[99].ranksPurchased == 0 and rejected.NS.GetTalentSBAUndoInfo().canUndo,
        "failed undo must roll back to the SBA allocation and preserve its undo snapshot")
end

-- A deliberate respec uses the same guide priorities and live point budget,
-- sends one commit, and blocks both ordinary auto-spend and repeated actions.
do
    local h = makeRespecHarness()
    h.NS.TALENT_SBA_PRIORITIES = { [100] = { patch = "11.2", spells = {
        [201] = { priority = 90, name = "Core", reason = "Core priority." },
    } } }
    h.NS.SetTalentLevelingEnabled(true)
    local ok, message = h.NS.SpendAllOrRespecTalentPoints()
    check(ok, message)
    check(h.resets == 1 and h.commits == 1 and h.purchases == 1 and h.purchaseOrder[1] == 2,
        "spend-all fallback must reset conflicts, spend only the refunded point using guide priorities, and commit once")
    check(h.nodes[99].ranksPurchased == 0 and h.nodes[1].ranksPurchased == 0 and h.currencies[10][1].quantity == 0,
        "respec must remove conflicting allocation without overspending the current level")
    check(not h.NS.RequestTalentSBARespec() and not h.NS.SpendNextTalentPoint(), "pending respec must prevent overlapping mutations")
    h:runDue(.25)
    check(h.commits == 1 and h.purchases == 1, "scheduled auto-spend must not race the respec")
    h:confirm(); h:runDue(.25)
    check(not h.NS.IsTalentLevelingBusy() and h.commits == 1 and not h.NS.GetTalentSBAAssessment().hasMismatch,
        "confirmation must verify the whole staged plan and finish without another spend")
end

-- Preconditions must reject before reset and must never discard user edits.
do
    for _, block in ipairs({ "combat", "staged", "importPending", "disabled", "stamp", "decode", "readonly" }) do
        local h = makeRespecHarness()
        if block == "disabled" then h.systemEnabled = false
        elseif block == "stamp" then h.entries.A.importString = "changed"
        elseif block == "decode" then h.decodeError = "incompatible target"
        elseif block == "readonly" then h.editable = false
        else h[block] = true end
        check(not h.NS.RequestTalentSBARespec(), "blocked respec must reject: " .. block)
        check(h.resets == 0 and h.commits == 0 and h.rollbacks == 0 and h.nodes[99].ranksPurchased == 1,
            "preflight must not mutate or roll back preexisting changes: " .. block)
    end
end

-- Every failure before successful commit restores the original allocation,
-- including APIs which return failure after partially mutating staged state.
do
    for _, failure in ipairs({ "reset", "purchase", "validation", "commit", "unexpected" }) do
        local h = makeRespecHarness(1)
        if failure == "reset" then h.resetSucceeds = false
        elseif failure == "purchase" then h.failPurchaseAt = 2
        elseif failure == "validation" then h.readyForCommit = false
        elseif failure == "commit" then h.commitSucceeds = false
        elseif failure == "unexpected" then h.onPurchase = function() h.nodes[99].ranksPurchased = 1 end end
        local beforeRank, beforeCurrency = h.nodes[99].ranksPurchased, h.currencies[10][1].quantity
        local ok = h.NS.RequestTalentSBARespec()
        check(not ok and h.rollbacks == 1 and not h.NS.IsTalentLevelingBusy(), "failed respec must roll back: " .. failure)
        check(h.nodes[99].ranksPurchased == beforeRank and h.nodes[1].ranksPurchased == 0
            and h.nodes[2].ranksPurchased == 0 and h.currencies[10][1].quantity == beforeCurrency and not h.staged,
            "failure must preserve original ranks and points: " .. failure)
        check(h.commits == (failure == "commit" and 1 or 0), "an invalid plan must never be committed: " .. failure)
    end
end

-- A target may have no purchasable rank yet, or fewer current-level ranks
-- than refunded points. Rebuild leaves those points unspent for later levels.
do
    local empty = makeRespecHarness(1)
    empty.nodes[1].canPurchaseRank, empty.nodes[2].canPurchaseRank = false, false
    local ok, message = empty.NS.RequestTalentSBARespec()
    check(ok and message:find("no ranks available", 1, true) and empty.commits == 1
        and empty.purchases == 0 and empty.nodes[99].ranksPurchased == 0
        and empty.currencies[10][1].quantity == 2,
        "rebuild must permit a clean zero-rank allocation while the target is locked")
    empty:confirm()
    local partial = makeRespecHarness()
    partial.nodes[99].ranksPurchased = 2
    partial.nodes[2].canPurchaseRank = false
    local partialOK = partial.NS.RequestTalentSBARespec()
    check(partialOK and partial.commits == 1 and partial.purchases == 1
        and partial.currencies[10][1].quantity == 1,
        "rebuild must leave a refunded point unspent when no target rank is legal")
end

-- Class, spec and hero currencies are independent; the selected hero choice
-- and all three budgets must survive one reset/rebuild transaction.
do
    local h = makeRespecHarness()
    h.readyForCommit = false
    check(not h.NS.RequestTalentSBARespec(), "invalid plan must fail before retry")
    check(h.NS.GetTalentSBAAssessment().failure, "failed plan must explain the failure")
    h.readyForCommit = true
    check(h.NS.RequestTalentSBARespec(), "a corrected explicit respec retry must start")
    h:confirm()
    check(not h.NS.GetTalentSBAAssessment().failure, "successful retry must clear stale faults so auto-spend can resume")
end

do
    local failedRollback = makeRespecHarness()
    failedRollback.resetSucceeds, failedRollback.rollbackSucceeds = false, false
    local ok, message = failedRollback.NS.RequestTalentSBARespec()
    check(not ok and message:find("could not roll back", 1, true) and not message:find("were restored", 1, true),
        "a failed rollback must be reported without claiming the original talents were restored")
end

do
    local h = makeHarness({ rows = {
        { nodeID = 1, ranksPurchased = 1, selectionEntryID = 101 },
        { nodeID = 2, ranksPurchased = 1, selectionEntryID = 201 },
        { nodeID = 7, ranksPurchased = 1, selectionEntryID = 701 },
    }, treeNodes = { 1, 2, 7, 97, 98, 99 } })
    h.useBudgets = true
    h.nodes[7] = { ranksPurchased = 0, type = Enum.TraitNodeType.SubTreeSelection, canPurchaseRank = true, isAvailable = true }
    h.costs[2], h.costs[7] = { { ID = 2, amount = 1 } }, { { ID = 3, amount = 1 } }
    h.currencies[10] = { { traitCurrencyID = 1, quantity = 0 }, { traitCurrencyID = 2, quantity = 0 }, { traitCurrencyID = 3, quantity = 0 } }
    for index, nodeID in ipairs({ 97, 98, 99 }) do
        h.nodes[nodeID] = { ranksPurchased = 1, type = 1 }
        h.costs[nodeID] = { { ID = index, amount = 1 } }
    end
    h:selectTarget("A")
    local ok, message = h.NS.RequestTalentSBARespec()
    check(ok, message)
    check(h.commits == 1 and h.purchases == 3 and h.nodes[7].activeEntry.entryID == 701,
        "respec must allocate class/spec/hero points and the exact chosen hero entry")
    for _, currency in ipairs(h.currencies[10]) do check(currency.quantity == 0, "each refunded currency must be spent independently") end
    h:confirm()
    check(not h.NS.IsTalentLevelingBusy(), "all-tree allocation must be confirmed")
end

-- Once a commit is accepted, asynchronous failure/timeout must not roll back
-- a possibly applied server change, but must notify the warning UI of failure.
do
    for _, failure in ipairs({ "event", "timeout", "identity" }) do
        local h = makeRespecHarness()
        local reported
        h.NS.CheckTalentSBAWarning = function(assessment) if assessment.failure then reported = assessment.failure end end
        h.NS.SetTalentSBAWarningEnabled(true)
        check(h.NS.RequestTalentSBARespec(), "async failure fixture must start")
        if failure == "event" then h.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", h.configID)
        elseif failure == "timeout" then h:runDue(10)
        else h.entries.A.importString = "changed"; h:confirm() end
        check(not h.NS.IsTalentLevelingBusy() and h.rollbacks == 0 and reported,
            "accepted commit failure must stop, retain ownership boundaries, and refresh the UI: " .. failure)
    end
end

-- A rejected automatic point is explicitly uncommitted. Discard only the
-- verified staged rank, retry once, then rebuild the current-level target
-- even when proactive mismatch rebuilding is off. A rejected rebuild stops.
do
    local h = makeHarness()
    h.useBudgets = true
    h:selectTarget("A")
    check(h.NS.SetTalentLevelingEnabled(true))
    h:runDue(.25)
    check(h.commits == 1 and h.purchases == 1 and h.staged,
        "automatic recovery fixture must start with one staged point")
    h.onRollback = function()
        h.NS.OnTalentLevelingEvent("TRAIT_CONFIG_UPDATED", h.configID)
    end
    h.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", h.configID + 1)
    check(h.rollbacks == 0 and h.NS.IsTalentLevelingBusy(),
        "a failure for another config must not touch the pending talent change")
    h.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", h.configID)
    check(h.rollbacks == 1 and h.nodes[1].ranksPurchased == 0 and not h.staged
        and not h.NS.IsTalentLevelingBusy() and not h.NS.GetTalentSBAAssessment().failure,
        "the first rejected point must roll back its own rank without alerting or resetting")
    h:runDue(.5); h:runDue(.25)
    check(h.commits == 2 and h.purchases == 2 and h.resets == 0,
        "Auto-Spend must retry the rejected point without user toggling")
    h.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", h.configID)
    check(h.rollbacks == 2 and not h.staged,
        "a second rejection must safely discard its staged rank")
    h.combat = true
    h:runDue(.5); h:runDue(.25)
    check(h.resets == 0 and h.commits == 2,
        "automatic rebuild must wait for combat to end")
    h.combat = false
    h.NS.OnTalentLevelingEvent("PLAYER_REGEN_ENABLED")
    h:runDue(.25)
    check(h.resets == 1 and h.commits == 3 and h.purchases == 3,
        "Auto-Spend must rebuild once after a rejected retry, even with Auto-Rebuild Off")
    h:confirm()
    check(not h.NS.IsTalentLevelingBusy() and h.nodes[1].ranksPurchased == 1
        and not h.NS.GetTalentSBAAssessment().failure,
        "a confirmed rebuild must clear recovery and preserve the target allocation")

    local blocked = makeHarness()
    blocked:selectTarget("A")
    check(blocked.NS.SetTalentLevelingEnabled(true))
    blocked:runDue(.25)
    blocked.nodes[2].ranksPurchased = 1 -- another actor changed the pending plan
    blocked.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", blocked.configID)
    blocked:runDue(.5); blocked:runDue(.25)
    check(blocked.rollbacks == 0 and blocked.resets == 0 and blocked.commits == 1
        and blocked.NS.GetTalentSBAAssessment().failure,
        ("recovery must stop rather than replace staged talents it does not own (rollbacks=%s resets=%s commits=%s failure=%s)")
            :format(tostring(blocked.rollbacks), tostring(blocked.resets), tostring(blocked.commits),
                tostring(blocked.NS.GetTalentSBAAssessment().failure)))

    local failed = makeHarness()
    failed:selectTarget("A")
    check(failed.NS.SetTalentLevelingEnabled(true))
    failed:runDue(.25)
    failed.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", failed.configID)
    failed:runDue(.5); failed:runDue(.25)
    failed.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", failed.configID)
    failed:runDue(.5); failed:runDue(.25)
    failed.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", failed.configID)
    failed.NS.OnTalentLevelingEvent("PLAYER_LEVEL_UP")
    failed:runDue(.25); failed:runDue(.5)
    check(failed.commits == 3 and failed.resets == 1 and failed.NS.GetTalentSBAAssessment().failure,
        "a rejected rebuild must stop without an unlimited recovery loop")

    local cancelled = makeHarness()
    cancelled:selectTarget("A")
    check(cancelled.NS.SetTalentLevelingEnabled(true))
    cancelled:runDue(.25)
    cancelled.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", cancelled.configID)
    cancelled:runDue(.5); cancelled:runDue(.25)
    cancelled.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", cancelled.configID)
    check(cancelled.NS.SetTalentLevelingEnabled(false))
    cancelled:runDue(.5); cancelled:runDue(.25)
    check(cancelled.resets == 0 and cancelled.commits == 2,
        "turning Auto-Spend off must cancel a queued automatic rebuild")

    local optedOut = makeHarness()
    optedOut:selectTarget("A")
    check(optedOut.NS.SetTalentLevelingEnabled(true))
    optedOut:runDue(.25)
    check(optedOut.NS.SetTalentLevelingEnabled(false))
    optedOut.NS.OnTalentLevelingEvent("CONFIG_COMMIT_FAILED", optedOut.configID)
    optedOut:runDue(.5); optedOut:runDue(.25)
    check(optedOut.rollbacks == 1 and optedOut.commits == 1 and not optedOut.staged,
        "opting out during a rejected commit must discard its owned stage without retrying")

    local immediate = makeHarness()
    immediate:selectTarget("A")
    immediate.commitSucceeds = false
    check(immediate.NS.SetTalentLevelingEnabled(true))
    immediate:runDue(.25)
    check(immediate.rollbacks == 1 and not immediate.staged
        and not immediate.NS.GetTalentSBAAssessment().failure,
        "an immediately refused automatic commit must roll back and enter recovery")
    immediate.commitSucceeds = true
    immediate:runDue(.5); immediate:runDue(.25)
    immediate:confirm()
    check(immediate.commits == 2 and immediate.nodes[1].ranksPurchased == 1,
        "an immediately refused commit must recover without a switch toggle")
end

print("talent leveling mock: guided spending, warning deduplication, transactional respec, budget/rollback and commit safety passed")
