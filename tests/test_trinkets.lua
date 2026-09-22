local combat, requests, rebuilds = false, 0, 0
local equipment = { [13] = 101, [14] = 102 }
local data = {
    [101] = { name = "Instant", spell = 201, cast = 0, cached = true },
    [102] = { name = "Passive", cached = true },
    [103] = { name = "Cast time", spell = 203, cast = 1500, cached = true },
    [104] = { name = "Loading", spell = 204, cast = 0, cached = false },
}
GetInventoryItemID = function(_, slot) return equipment[slot] end
C_Item = {
    GetItemNameByID = function(id) return data[id].name end,
    IsItemDataCachedByID = function(id) return data[id].cached end,
    RequestLoadItemDataByID = function() requests = requests + 1 end,
    GetItemSpell = function(id) return data[id].name, data[id].spell end,
}
C_Spell = {
    GetSpellInfo = function(id)
        for _, item in pairs(data) do if item.spell == id then return {castTime=item.cast} end end
    end,
    GetSpellName = function(id) return "Spell" .. tostring(id) end,
}
IsPlayerSpell = function() return true end
UnitClass = function() return "Druid", "DRUID" end
GetSpecialization = function() return 3 end
local ns = {
    db={trinketMode="Off", trinketApproved={}}, C_Spell=C_Spell,
    InCombatLockdown=function() return combat end,
    RebuildMacroText=function() rebuilds=rebuilds+1 end,
    pcall=pcall, table_concat=table.concat, SBA_SPELL_ID=999,
    CONVOKE_THE_SPIRITS_ID=1001, IRONFUR_SPELL_ID=1002,
}
assert(loadfile("Core/Functions/Trinkets.lua"))("BetterSBA", ns)
ns.RefreshTrinkets()
assert(ns.GetTrinketStatus(13).status == "Manual")
assert(ns.GetTrinketStatus(14).status == "Passive")
assert(ns.SetTrinketApproved(13, true))
assert(not ns.GetTrinketStatus(13).eligible, "Off mode stays off")
ns.db.trinketMode = "Approved"
ns.RefreshTrinkets()
assert(ns.GetTrinketStatus(13).eligible)
equipment[13] = 103
ns.RefreshTrinkets()
assert(not ns.GetTrinketStatus(13).canApprove, "Cast-time items rejected")
assert(not ns.SetTrinketApproved(13, true))
equipment[13] = 104
ns.RefreshTrinkets(); ns.RefreshTrinkets()
assert(requests == 1, "Missing item data requested only once")
assert(ns.GetTrinketStatus(13).status == "Loading")
data[104].cached = true
ns.RefreshTrinkets()
assert(not ns.GetTrinketStatus(13).eligible, "Approval cannot follow a slot swap")
equipment[13] = 101
combat=true
local previous=rebuilds
ns.RefreshTrinkets()
assert(ns._pendingTrinketRefresh and rebuilds==previous, "No secure rebuild in combat")
combat=false
ns.RefreshTrinkets()
assert(ns.GetTrinketStatus(13).eligible)
data[101].spell=205
ns.RefreshTrinkets()
assert(not ns.GetTrinketStatus(13).eligible, "Changed spell needs new approval")
ns.SetTrinketApproved(13,true)

assert(loadfile("Core/Functions/Spells.lua"))("BetterSBA", ns)
ns.db.enableConvokeTheSpirits=true
ns.db.enableIronfur=true
ns.db.enableChannelProtection=true
local macro = ns.BuildMacroText()
assert(macro:find("/cast [nochanneling] Spell999", 1, true), "SBA can open combat")
assert(macro:find("/cast [combat,nochanneling] Spell1001", 1, true))
assert(not macro:find("[combat][nochanneling]", 1, true))
local trinketAt=assert(macro:find("/use [combat,harm,nodead,nochanneling] 13",1,true))
assert(trinketAt > macro:find("Spell999",1,true), "SBA precedes trinket")
local preview={}
for i, action in ipairs(ns.GetMacroActions()) do preview[i]=action.text end
assert(table.concat(preview,"\n")==macro, "Preview and secure macro agree")
print("PASS: trinket detection, approval identity, loading, deferral, and macro ordering")
