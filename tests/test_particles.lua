local made=0
local function frame()
    local f={}
    setmetatable(f,{__index=function(_,key)
        if key:sub(1,1)=="_" then return nil end
        return function() end
    end})
    function f:CreateTexture() return frame() end
    function f:CreateAnimationGroup() return frame() end
    function f:CreateAnimation() return frame() end
    return f
end
local ns={db={},ipairs=ipairs,UIParent=frame(),
    CreateFrame=function() made=made+1; return frame() end,
    GetPalette=function() return {{1,.5,.2}} end,
    BUILTIN_PALETTES={Confetti={{1,.5,.2}}},
}
assert(loadfile("Core/Functions/Particles.lua"))("BetterSBA",ns)
local source=frame()
for i=1,100 do ns.FireParticleBurst(source,"Confetti","Confetti",1) end
assert(made==96,"Rapid bursts cannot grow particle pool past 96")
ns.ResetParticlePool()
ns.FireParticleBurst(source,"Confetti","Confetti",1)
assert(made==96,"Reset reuses existing particles")
print("PASS: bounded Classic particle pool and reset/reuse")
