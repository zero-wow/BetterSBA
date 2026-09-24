unpack = unpack or table.unpack
local made, all, combat = 0, {}, false
local function object(parent, kind)
    local o={parent=parent, kind=kind, alpha=1, scripts={}, shown=true, children={}}
    if parent then parent.children[#parent.children+1]=o end
    setmetatable(o,{__index=function(_, k)
        if k=="CreateTexture" or k=="CreateMaskTexture" or k=="CreateAnimationGroup" or k=="CreateAnimation" then
            return function(self) return object(self,k) end
        end
        return function() end
    end})
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsVisible() return self.shown end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha=a end
    function o:SetScale(x,y) self.scaleX,self.scaleY=x,y end
    function o:GetWidth() return 48 end
    function o:GetFrameLevel() return rawget(self,"frameLevel") or 5 end
    function o:GetFrameStrata() return "MEDIUM" end
    function o:SetFrameLevel(level) self.frameLevel=level end
    function o:SetTexture(texture) self.texture=texture end
    function o:SetSize(width,height) self.width,self.height=width,height end
    function o:SetPoint(...) self.point={...} end
    function o:SetRotation(angle) self.rotation=angle end
    function o:SetOffset(x,y) self.offsetX,self.offsetY=x,y end
    function o:SetDuration(value) self.duration=value end
    function o:SetDegrees(value) self.degrees=value end
    function o:SetOrigin(...) self.origin={...} end
    function o:SetScript(k,v) self.scripts[k]=v end
    function o:Play() self.playing=true end
    function o:Stop() self.playing=false end
    function o:GetTexture() return 123 end
    function o:GetTexCoord() return 0.07,0.93,0.07,0.93 end
    return o
end
local ns={
    db={enabled=true,buttonStyle="Soft",motionPreset="Pulse"},
    mainButton=object(), UIParent=object(), unpack=unpack,
    UsesSoftButtonStyle=function() return true end,
    CreateFrame=function(_,_,p) made=made+1; local f=object(p,"Frame"); all[#all+1]=f; return f end,
}
ns.mainButton.icon=object()
InCombatLockdown=function() return combat end
assert(loadfile("Core/Functions/Motion.lua"))("BetterSBA",ns)
combat=true
assert(not ns.PlayMotionFeedback(1), "First combat call cannot initialize geometry")
assert(made==0)
combat=false
assert(ns.InitializeMotionFeedback())
assert(made==4, "One host and three pooled layers")
for _, preset in ipairs({"Pulse","Echo","Sweep","Sheen","Snap","Orbit"}) do
    ns.db.motionPreset=preset
    for i=1,100 do assert(ns.PlayMotionFeedback(1)) end
end
assert(made==4, "Repeated casts never allocate more frames")
local host, sweep = all[1], all[2]
assert(sweep.orbitAG.playing and sweep.orbitRotation.degrees == 320
    and sweep.orbitRotation.origin[3] == 48 / 2 - 2,
    "Orbit needs a rotating rim glint around the button center")
ns.db.motionPreset="Sheen"
assert(ns.PlayMotionFeedback(1) and sweep.edge.rotation == math.pi / 9
    and sweep.edge.height == 48 * 1.30
    and sweep.ag._translate.offsetX == 48 * 1.16,
    "Sheen needs a diagonal glint that crosses the button")
ns.db.motionPreset="Snap"
assert(ns.PlayMotionFeedback(1)
    and sweep.ag._scale.scaleX == 0.88
    and all[3].ag._scale.scaleX == 1.12
    and not sweep.orbitAG.playing,
    "Snap must compress and release without leaving Orbit playing")
ns.db.motionPreset="Sweep"
assert(ns.PlayMotionFeedback(1))
assert(host:GetFrameLevel() < ns.mainButton:GetFrameLevel()
    and sweep:GetFrameLevel() > ns.mainButton:GetFrameLevel()
    and all[3]:GetFrameLevel() < ns.mainButton:GetFrameLevel(),
    "only Sweep's traveling edge should cross above the button")
assert(sweep.edge.texture == "Interface\\Buttons\\WHITE8X8"
    and sweep.edge.width == 48 * 0.28 and sweep.edge.height == 4
    and sweep.edge.rotation == 0,
    "Sweep needs a solid narrow streak, not the hollow glow compressed into a line")
assert(sweep.ag._translate.offsetX == 48 * 0.72,
    "Sweep glint must travel across the full button width")
local startCenter = sweep.edge.point[4]
local finishCenter = startCenter + sweep.ag._translate.offsetX
assert(startCenter - sweep.edge.width / 2 <= -24
    and finishCenter + sweep.edge.width / 2 >= 24,
    "Sweep must enter at the left edge and clear the right edge")
ns.db.motionPreset="Pulse"
assert(ns.PlayMotionFeedback(1) and host:GetFrameLevel() < ns.mainButton:GetFrameLevel()
    and sweep:GetFrameLevel() < ns.mainButton:GetFrameLevel(),
    "Pulse must restore the quiet behind-button layer order after Sweep")
ns.db.motionPreset="Orbit"
assert(ns.PlayMotionFeedback(1) and sweep.orbitAG.playing)
ns.db.motionReduced=true
ns.PlayMotionFeedback(1)
assert(not sweep.orbitAG.playing, "Reduced motion must stop the orbiting glint")
local playing=0
for _, f in ipairs(all) do if type(f.ag)=="table" and f.ag.playing then playing=playing+1 end end
assert(playing==1, "Reduced motion uses one layer")
ns.ResetMotionFeedback()
for _, f in ipairs(all) do if type(f.ag)=="table" then assert(not f.ag.playing and not f.shown) end end
ns.db.enabled=false
assert(not ns.PlayMotionFeedback(1))
ns.db.enabled=true
ns.mainButton.alpha=0
assert(not ns.PlayMotionFeedback(1))
print("PASS: bounded motion pool, preset reuse, reduced motion, cancellation, visibility")
