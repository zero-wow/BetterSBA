local made, scans, particles=0,0,{}
local function frame()
    local f={}
    setmetatable(f,{__index=function(_,key)
        if key:sub(1,1)=="_" then return nil end
        return function() end
    end})
    function f:CreateTexture() return frame() end
    function f:CreateAnimationGroup() return frame() end
    function f:CreateAnimation() return frame() end
    function f:SetScript(event,callback) self[event]=callback end
    return f
end
local ns={db={},ipairs=function(values) scans=scans+1; return ipairs(values) end,UIParent=frame(),
    CreateFrame=function() made=made+1; local f=frame(); particles[#particles+1]=f; return f end,
    GetPalette=function() return {{1,.5,.2}} end,
    BUILTIN_PALETTES={Confetti={{1,.5,.2}}},
}
assert(loadfile("Core/Functions/Particles.lua"))("BetterSBA",ns)
local source=frame()
for i=1,100 do ns.FireParticleBurst(source,"Confetti","Confetti",1) end
assert(made==96,"Rapid bursts cannot grow particle pool past 96")
assert(scans==0,"Particle acquisition must not scan the pool for every particle")
ns.ResetParticlePool()
ns.FireParticleBurst(source,"Confetti","Confetti",1)
assert(made==96,"Reset reuses existing particles")
assert(scans==1,"Only the explicit reset traverses the whole pool")
for _,particle in ipairs(particles) do
    if particle._inUse then particle._ag.OnFinished(); particle._ag.OnFinished() end
end
ns.ResetParticlePool()
ns.ResetParticlePool()
for i=1,4 do ns.FireParticleBurst(source,"Sparks","Confetti",1) end
local active=0
for _,particle in ipairs(particles) do if particle._inUse then active=active+1 end end
assert(active==96,"Repeated completion/reset must not insert duplicate free frames")
print("PASS: bounded Classic particle pool and reset/reuse")
