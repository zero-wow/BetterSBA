-- Native-call counts and state transitions; this is not an in-game FPS benchmark.
unpack = unpack or table.unpack
local frames = {}
local methods = {}
local function count(self, name)
    self.calls[name] = (self.calls[name] or 0) + 1
end
local function object(parent)
    return setmetatable({parent=parent, calls={}, scripts={}, width=160, height=30,
        shown=true, alpha=1, frameLevel=5, scale=1, text=""}, {__index=methods})
end
for _, name in ipairs({"SetBackdropColor", "SetBackdropBorderColor", "SetShadowColor",
    "SetShadowOffset", "SetTextColor", "SetAllPoints", "SetBackdrop", "SetFrameStrata",
    "SetMovable", "SetClampedToScreen", "EnableMouse", "EnableMouseWheel",
    "RegisterForDrag", "SetPushedTexture", "SetNormalTexture", "SetHighlightTexture",
    "SetDrawEdge", "SetHideCountdownNumbers", "SetRotation", "SetOrigin", "Clear",
    "SetDesaturated", "SetSmoothing", "SetStartDelay", "SetDuration", "SetOffset",
    "SetFromAlpha", "SetToAlpha", "SetDegrees", "SetJustifyH", "SetJustifyV"}) do
    methods[name] = function(self) count(self, name) end
end
function methods:CreateTexture() return object(self) end
function methods:CreateFontString() return object(self) end
function methods:CreateAnimationGroup() return object(self) end
function methods:CreateAnimation() return object(self) end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetAlpha(alpha) self.alpha=alpha end
function methods:GetAlpha() return self.alpha end
function methods:GetParent() return self.parent end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return self.frameLevel end
function methods:SetFrameLevel(level) self.frameLevel=level end
function methods:GetScale() return self.scale end
function methods:SetScale(scale) self.scale=scale end
function methods:SetWidth(width) self.width=width end
function methods:SetHeight(height) self.height=height end
function methods:SetSize(width,height) count(self,"SetSize"); self.width,self.height=width,height end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text*7 end
function methods:SetFont() return true end
function methods:SetTexture(value) count(self,"SetTexture"); self.texture=value end
function methods:GetTexture() return self.texture end
function methods:SetTexCoord(...) count(self,"SetTexCoord"); self.coords={...} end
function methods:SetColorTexture(...) count(self,"SetColorTexture"); self.color={...} end
function methods:SetVertexColor(...) count(self,"SetVertexColor"); self.vertex={...} end
function methods:ClearAllPoints() count(self,"ClearAllPoints"); self.point=nil end
function methods:SetPoint(...) count(self,"SetPoint"); self.point={...} end
function methods:SetScript(event,callback) count(self,event); self.scripts[event]=callback end
function methods:HookScript(event,callback)
    local previous=self.scripts[event]
    self.scripts[event]=function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function methods:Stop() self.playing=false end
function methods:Play() self.playing=true end
local function createFrame(_,_,parent)
    local frame=object(parent); frames[#frames+1]=frame; return frame
end
local function event(frame,name,...)
    assert(frame.scripts[name], "Missing handler: "..name)(frame,...)
end
local function settle(frame)
    for _=1,120 do
        if not frame.scripts.OnUpdate then return end
        event(frame,"OnUpdate",1/60)
    end
end
local function sameColor(actual,expected)
    for i=1,#expected do assert(actual[i]==expected[i],"Color channel "..i) end
end
local ns={db={}, ConfigStudio={}, unpack=unpack, ipairs=ipairs, pairs=pairs,
    CreateFrame=createFrame, UIParent=object(), mainButton=object(),
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end}
UnitFactionGroup=function() return "Alliance" end
InCombatLockdown=function() return false end
ns.InCombatLockdown=InCombatLockdown
assert(loadfile("GUI/StudioComic.lua"))("BetterSBA",ns)
local comic=ns.ConfigStudio.Comic
comic.ApplyPalette({})
local entry={file="Example",u=.5,v=.5,width=80,height=20}
ns.StudioLettering={button={On=entry},heading={On=entry}}
local label=object(object()); label.text="On"
for _=1,100 do assert(comic.SetLettering(label,"button")) end
local art=label._comicLettering
assert(art.calls.SetTexture==1 and art.calls.SetTexCoord==1 and art.calls.SetPoint==1
    and art.calls.SetSize==1, "Stable lettering must not re-upload or re-anchor")
assert(not label.shown and label.alpha==0 and art.shown,"Only illustrated text is visible")
label.parent.height=18
comic.SetLettering(label,"button")
assert(art.height==12 and art.calls.SetSize==2,"Resize still preserves lettering aspect")
comic.SetLettering(label,"heading",nil,22)
assert(art.point[1]=="LEFT" and art.calls.SetPoint==2,"Changed kind reanchors")
label.text="Dynamic text"
assert(not comic.SetLettering(label,"button") and label.shown and not art.shown,
    "Unknown text must return to native text")
label.text="On"; comic.SetLettering(label,"button")
assert(art.shown and not label.shown,"Returning to known text restores art")

local nav=object(); nav._bg=object(nav)
comic.StyleNav(nav); comic.SetNavActive(nav,true); settle(nav)
assert(nav.scripts.OnUpdate,"Active nav shimmer remains animated")
ns.db.motionReduced=true; settle(nav)
assert(not nav.scripts.OnUpdate,"Reduced Motion must stop active nav work")
ns.db.motionReduced=false; comic.SetNavActive(nav,true)
assert(nav.scripts.OnUpdate,"Selecting nav restarts ordinary motion")
local action=object(); comic.StyleAction(action)
event(action,"OnEnter"); settle(action)
assert(action.scripts.OnUpdate,"Hovered action glint remains animated")
ns.db.motionReduced=true; settle(action)
assert(not action.scripts.OnUpdate and action._comic.glint.alpha==0,
    "Switching Reduced Motion on must stop existing hover work")
ns.db.motionReduced=false
local mini=object(); mini.width=70; mini.height=22
comic.StyleToggle(mini); comic.SetMiniState(mini,false)
local pip=mini._comicMiniPip
local before=pip.calls.SetPoint
event(mini,"OnEnter"); settle(mini)
assert(pip.calls.SetPoint==before,"Hover-only fade must not reposition a stationary pip")
comic.SetMiniState(mini,true); settle(mini)
assert(pip.calls.SetPoint>before and pip.point[4]==56,"State change still slides pip")
mini.width=80; event(mini,"OnSizeChanged")
assert(pip.point[4]==66,"Resize repositions the pip without a perpetual update")

ns.THEME={TEXT_DIM={.5,.5,.5},BG_DARK={0,0,0},NEON_NEXT={0,1,.5,1},BORDER={.1,.2,.3,1}}
ns.ICON_TEXCOORD={.07,.93,.07,.93}
ns.db={priorityBorderColor={.2,.3,.4,.5},priorityBgColor={0,0,0,.6},
    priorityIconSize=36,prioritySpacing=3,showPriority=true,showActiveGlow=true,
    importanceBorders=true,showPriorityKeybinds=true}
ns.ResolveFontPath=function() return "Fonts\\FRIZQT__.TTF" end
ns.ResolveFontOutline=function() return "OUTLINE" end
ns.ApplyButtonStyle=function() end
local nextSpell,rotation,ready=3,{1,2,3,4,5,6},true
ns.CollectNextSpell=function() return nextSpell end
ns.CollectRotationSpells=function() return rotation end
ns.GetSpellBaseCooldown=function(id) return id*10 end
ns.GetSpellTextureCached=function(id) return id*100 end
ns.GetSpellImportanceKey=function() return "MAJOR_CD" end
ns.GetCooldownCached=function() return {} end
ns.IsCooldownShortOrReady=function() return ready end
ns.GetSpellBorderColor=function(id) return {id/10,.2,.3,.8} end
ns.GetSpellBorderColorBright=function(id) return {id/10,.7,.9,1} end
ns.GetKeybindForSpell=function(id) return tostring(id) end
GameTooltip=object()
function GameTooltip:SetOwner(owner) self.owner=owner end
function GameTooltip:SetSpellByID(id) self.spellID=id end
assert(loadfile("GUI/PriorityDisplay.lua"))("BetterSBA",ns)
ns:CreatePriorityDisplay()
for _,icon in ipairs(ns._priorityIcons) do icon.borderTex.calls.SetColorTexture=0 end
for _=1,100 do ns.UpdatePriorityDisplay() end
for i,icon in ipairs(ns._priorityIcons) do
    assert(icon.borderTex.calls.SetColorTexture==100,"Each priority icon needs one final border write")
    assert(icon.calls.OnEnter==1 and icon.calls.OnLeave==1,"Tooltip scripts installed once")
    assert(icon.scripts.OnEnter==ns._priorityIcons[1].scripts.OnEnter,"Share tooltip callback")
    sameColor(icon.borderTex.color,i==1 and ns.THEME.NEON_NEXT or ns.GetSpellBorderColorBright(icon.spellID))
end
assert(ns._priorityIcons[1].spellID==3 and ns._priorityIcons[2].spellID==6,
    "Next spell first, then longest base cooldown")
event(ns._priorityIcons[1],"OnEnter")
assert(GameTooltip.spellID==3 and GameTooltip.owner==ns._priorityIcons[1])
ns.db.showActiveGlow=false; ns.UpdatePriorityDisplay()
for _,icon in ipairs(ns._priorityIcons) do sameColor(icon.borderTex.color,ns.GetSpellBorderColor(icon.spellID)) end
ns.db.importanceBorders=false; ns.UpdatePriorityDisplay()
sameColor(ns._priorityIcons[1].borderTex.color,ns.THEME.NEON_NEXT)
sameColor(ns._priorityIcons[2].borderTex.color,ns.db.priorityBorderColor)
-- Masque border receives identical final policy, including hide-on-default.
for _,icon in ipairs(ns._priorityIcons) do icon.Border=object(icon) end
ns.UpdatePriorityDisplay()
assert(ns._priorityIcons[1].Border.shown and not ns._priorityIcons[2].Border.shown)
ns.db.showActiveGlow=true; ready=nil; ns.UpdatePriorityDisplay()
assert(not ns._priorityIcons[2]._wantGlow,"Unknown readiness cannot imply ready")
ready=true; ns.UpdatePriorityDisplay()
sameColor(ns._priorityIcons[2].Border.vertex,ns.GetSpellBorderColorBright(ns._priorityIcons[2].spellID))
rotation={}; ns.UpdatePriorityDisplay()
assert(not ns.priorityFrame.shown,"Empty queue hides the frame")

-- The same shared appearance code must preserve incoming/outgoing policy.
local timers={}
ns.db={enabled=true,castFeedback="Classic",castAnimation="DRIFT",animateIncoming=true,
    buttonBgColor={.2,.3,.4,.6},importanceBorders=true,showKeybind=true,alphaOOC=.65}
ns.GetFontPath=ns.ResolveFontPath
ns.GetOutlineFlags=function(value) return value end
ns.IsDebugChannelEnabled=function() return false end
ns.AnimKeyPrefix=function(value) return value end
ns.C_Timer_After=function(_,callback) timers[#timers+1]=callback end
ns.UpdateNow=function() ns.mainButton.spellID=2 end
ns.mainButton.icon=object(ns.mainButton); ns.mainButton.icon.texture=100
assert(loadfile("Core/Functions/Animations.lua"))("BetterSBA",ns)
local function checkClones(masque)
    local start=#frames
    ns.masque=masque
    local skins=0
    ns.masqueAnimGroup=masque and {AddButton=function() end, ReSkin=function() skins=skins+1 end} or nil
    ns.PlayCastAnimation(1)
    assert(ns.mainButton.alpha==0 and ns._recreateFading)
    table.remove(timers,1)()
    local outgoing,incoming
    for i=start+1,#frames do
        if frames[i]._sourceBtn then
            if frames[i]._isIncoming then incoming=frames[i] else outgoing=frames[i] end
        end
    end
    assert(outgoing and incoming and outgoing.hotkey.text=="1" and incoming.hotkey.text=="2")
    for _,pair in ipairs({{outgoing,1},{incoming,2}}) do
        local clone,id=pair[1],pair[2]
        sameColor(masque and clone.Border.vertex or clone.borderTex.color,ns.GetSpellBorderColor(id))
        if not masque then sameColor(clone.bg.color,ns.db.buttonBgColor) end
    end
    event(outgoing.ag,"OnFinished")
    assert(ns.mainButton.alpha==0,"Outgoing peer cannot reveal the real button early")
    event(incoming.ag,"OnFinished")
    assert(ns.mainButton.alpha==.65 and not ns._recreateFading,"Incoming reveals configured alpha")
    if masque then assert(skins==2,"Both Masque clones retain their reskin") end
end
checkClones(false)
checkClones(true)
print("PASS: lettering reuse, reduced-motion idle, pip geometry, priority border counts, clone appearance parity")
