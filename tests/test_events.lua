local timers, tickers, cancellations = {}, 0, 0
local eventHandler, registered = nil, {}
local ns={
    THEME={}, db={enabled=false}, ipairs=ipairs,
    C_Timer_After=function(_,fn) timers[#timers+1]=fn end,
    C_Timer_NewTicker=function() tickers=tickers+1;return {Cancel=function() cancellations=cancellations+1 end} end,
    CreateFrame=function() return {RegisterEvent=function(_,event) registered[event]=true end,
        SetScript=function(_,event,fn) if event=="OnEvent" then eventHandler=fn end end} end,
}
assert(loadfile("GUI/MainButton.lua"))("BetterSBA",ns)
local updates=0
ns.UpdateNow=function() updates=updates+1 end
ns.StartTicker();assert(tickers==0,"Disabled addon has no display ticker")
ns.db.enabled=true
ns.StartTicker();ns.StartTicker();assert(tickers==1,"Only one display ticker")
ns.StopTicker();assert(cancellations==1)
for i=1,100 do ns.QueueDisplayUpdate() end
assert(#timers==1,"Burst events coalesce to one callback")
table.remove(timers,1)();assert(updates==1)
ns.QueueDisplayUpdate();assert(#timers==1,"Next frame may update")
table.remove(timers,1)()
ns.db.enabled=false;ns.QueueDisplayUpdate();assert(#timers==0)
ns.db.enabled=true
local invalidations=0
ns.InvalidateCooldownCache=function() invalidations=invalidations+1 end
assert(loadfile("BetterSBA.lua"))("BetterSBA",ns)
assert(registered.SPELL_UPDATE_CHARGES,"Charge changes invalidate native duration cache")
for i=1,100 do eventHandler(nil,"UNIT_AURA","party1") end
assert(#timers==0,"Unrelated unit auras do no display work")
eventHandler(nil,"UNIT_AURA","player")
eventHandler(nil,"UNIT_AURA","target")
eventHandler(nil,"SPELL_UPDATE_CHARGES")
eventHandler(nil,"SPELL_UPDATE_COOLDOWN")
assert(#timers==1 and invalidations==2)

-- A spec can use a different SBA action-bar slot.  Cache invalidation must
-- happen before the scan that rebuilds secure interception for the new spec.
local specOrder = {}
ns.ClearSBASlotCache = function() specOrder[#specOrder + 1] = "slot" end
ns.ClearBaseCDCache = function() specOrder[#specOrder + 1] = "base" end
ns.ResetVirtualCooldowns = function() specOrder[#specOrder + 1] = "virtual" end
ns.InvalidateRotationCache = function() specOrder[#specOrder + 1] = "rotation" end
ns.InvalidateResolveCache = function() specOrder[#specOrder + 1] = "resolve" end
ns.InvalidateTextureCache = function() specOrder[#specOrder + 1] = "texture" end
ns.InvalidateCooldownCache = function() specOrder[#specOrder + 1] = "cooldown" end
ns.RebuildMacroText = function() specOrder[#specOrder + 1] = "macro" end
ns.ScanKeybinds = function() specOrder[#specOrder + 1] = "scan" end
ns.UpdateNow = function() specOrder[#specOrder + 1] = "update" end
eventHandler(nil, "PLAYER_SPECIALIZATION_CHANGED", "player")
assert(specOrder[1] == "slot" and specOrder[#specOrder - 1] == "scan" and specOrder[#specOrder] == "update",
    "spec swap must clear the cached SBA slot before rebuilding interception")

print("PASS: disabled ticker, event coalescing, aura filtering, charge invalidation, spec slot reset")
