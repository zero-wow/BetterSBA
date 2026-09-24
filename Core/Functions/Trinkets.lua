local ADDON_NAME, NS = ...

-- Equipment is inspected only after equipment/data/profile events, out of combat.
-- An item use-spell alone does not prove that it is off the GCD or non-channeling.
-- Approval records both IDs; a different item or changed effect stays manual.
local slots, requested = {}, {}
local MAX_LOAD_ATTEMPTS, LOAD_RETRY_DELAY = 3, 0.5

local function IsEquipped(itemID)
    return GetInventoryItemID and (GetInventoryItemID("player", 13) == itemID or GetInventoryItemID("player", 14) == itemID)
end

local function RetryFailedLoad(itemID, request)
    request.pending = false
    if request.attempts >= MAX_LOAD_ATTEMPTS or not NS.C_Timer_After then
        request.failed = true
        return
    end
    request.retryScheduled = true
    NS.C_Timer_After(LOAD_RETRY_DELAY * request.attempts, function()
        if requested[itemID] ~= request or not IsEquipped(itemID) then return end
        request.retryScheduled = false
        -- RefreshTrinkets defers both a new request and secure macro changes
        -- until combat ends. This timer is a bounded retry, not polling.
        NS.RefreshTrinkets()
    end)
end

local function InspectSlot(slot)
    local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
    local info = { slot = slot, itemID = itemID, name = "Empty slot", status = "Empty", eligible = false }
    if not itemID then
        info.reason = "Equip a trinket to inspect its use effect."
        return info
    end
    local api = C_Item
    info.name = (api and api.GetItemNameByID and api.GetItemNameByID(itemID)) or ("Item " .. itemID)
    if not api or not api.GetItemSpell then
        info.status, info.reason = "Manual", "Item use information is unavailable."
        return info
    end
    if api.IsItemDataCachedByID and not api.IsItemDataCachedByID(itemID) then
        info.status, info.reason = "Loading", "Waiting for item information; excluded from the macro."
        local request = requested[itemID]
        if not request then request = { attempts = 0 }; requested[itemID] = request end
        if not request.pending and not request.retryScheduled and not request.failed then
            if api.RequestLoadItemDataByID then
                request.attempts, request.pending = request.attempts + 1, true
                local ok = pcall(api.RequestLoadItemDataByID, itemID)
                if not ok then RetryFailedLoad(itemID, request) end
            else
                request.failed = true
            end
        end
        if request.failed then
            info.status = "Manual"
            info.reason = "Item information could not be loaded; excluded from the macro. Re-equip the item or reload to retry."
        end
        return info
    end
    requested[itemID] = nil -- Cached data also cancels any stale retry timer.
    local spellName, spellID = api.GetItemSpell(itemID)
    info.spellID = spellID
    if not spellID then
        info.status, info.reason = "Passive", "No on-use effect detected."
        return info
    end
    local spellInfo = NS.C_Spell and NS.C_Spell.GetSpellInfo and NS.C_Spell.GetSpellInfo(spellID)
    if not spellInfo or not spellInfo.castTime then
        info.status, info.reason = "Manual", "Use-effect details are unavailable; excluded from the macro."
        return info
    end
    if spellInfo.castTime > 0 then
        info.status, info.reason = "Manual", "This use effect has a cast time and is excluded from the SBA macro."
        return info
    end
    info.canApprove = true
    local approved = NS.db and NS.db.trinketApproved
    info.approved = approved and approved[itemID] == spellID or false
    info.eligible = info.approved and NS.db.trinketMode == "Approved"
    if info.eligible then
        info.status, info.reason = "Allowed", "Approved by you; attempts " .. (spellName or "its use effect") .. " after SBA in combat."
    elseif info.approved then
        info.status, info.reason = "Off", "Approval saved for this item; enable Approved mode to include it."
    else
        info.status, info.reason = "Manual", "Confirm this item is off the GCD and does not channel before allowing it."
    end
    return info
end

function NS.GetTrinketStatus(slot)
    return slots[slot]
end

function NS.IsTrinketApproved(slot)
    local info = slots[slot]
    return info and info.approved or false
end

function NS.SetTrinketApproved(slot, enabled)
    local info = slots[slot]
    if not NS.db or not info or not info.canApprove then return false end
    NS.db.trinketApproved = NS.db.trinketApproved or {}
    NS.db.trinketApproved[info.itemID] = enabled and info.spellID or nil
    NS.RefreshTrinkets()
    return true
end

function NS.RefreshTrinkets()
    if NS.InCombatLockdown() then
        NS._pendingTrinketRefresh = true
        return
    end
    for itemID in pairs(requested) do
        if not IsEquipped(itemID) then requested[itemID] = nil end
    end
    slots[13], slots[14] = InspectSlot(13), InspectSlot(14)
    NS._pendingTrinketRefresh = false
    if NS.RebuildMacroText then NS.RebuildMacroText() end
    if NS.RefreshTrinketConfig then NS.RefreshTrinketConfig() end
end

function NS.OnTrinketItemDataLoadResult(itemID, success)
    if not IsEquipped(itemID) then
        requested[itemID] = nil
        return false
    end
    if success == true then
        requested[itemID] = nil
    else
        local request = requested[itemID]
        -- Ignore duplicate/unrelated failures; each outstanding request gets
        -- one completion and at most one subsequent retry.
        if not request or not request.pending then return false end
        RetryFailedLoad(itemID, request)
    end
    NS.RefreshTrinkets()
    return true
end
