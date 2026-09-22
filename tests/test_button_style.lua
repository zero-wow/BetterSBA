unpack=unpack or table.unpack
local combat, created, adds, removes = false, 0, 0, 0
local function region()
    local r={shown=true,masks={},text="1"}
    setmetatable(r,{__index=function() return function() end end})
    function r:AddMaskTexture(m) assert(not self.masks[m]); self.masks[m]=true end
    function r:RemoveMaskTexture(m) assert(self.masks[m]); self.masks[m]=nil end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetShown(s) self.shown=s end
    function r:IsShown() return self.shown end
    function r:GetText() return self.text end
    function r:CreateTexture() created=created+1; return region() end
    function r:CreateMaskTexture() created=created+1; return region() end
    return r
end
local button=region()
button.icon=region();button.bg=region();button.borderTex=region();button.pushedTex=region()
button.hotkey=region();button.cooldown=region()
button._masqueRegions={Normal=region(),Border=region(),Highlight=region(),Flash=region()}
button._masqueRegistered=true
local ns={db={buttonStyle="Soft"},ICON_TEXCOORD={.07,.93,.07,.93},InCombatLockdown=function() return combat end,
    masqueMainGroup={AddButton=function() adds=adds+1 end,RemoveButton=function() removes=removes+1 end,ReSkin=function() end}}
-- Unlike Frame userdata, test objects must return nil for missing data members.
getmetatable(button).__index=function(_,k)
    if k:sub(1,1)=="_" or k=="pauseOverlay" then return nil end
    return function() end
end
for _,r in ipairs({button.icon,button.bg,button.borderTex,button.pushedTex}) do
    getmetatable(r).__index=function(_,k) if k=="_bsbaSoftMask" then return nil end; return function() end end
end
assert(loadfile("Core/Functions/ButtonStyle.lua"))("BetterSBA",ns)
ns.ApplyButtonStyle(button)
local pool=created
assert(removes==1 and not button._masqueRegistered)
assert(button._softChrome.keycap.shown)
for i=1,30 do ns.ApplyButtonStyle(button) end
assert(created==pool and removes==1, "Soft style reuses chrome and masks")
ns.db.buttonStyle="Classic";ns.ApplyButtonStyle(button)
assert(adds==1 and button._masqueRegistered)
assert(not next(button.icon.masks), "Classic removes our icon mask")
assert(not button._softChrome.keycap.shown)
ns.db.buttonStyle="Soft";ns.ApplyButtonStyle(button)
assert(removes==2)
button.hotkey.text="";ns.UpdateButtonChrome(button)
assert(not button._softChrome.keycap.shown, "No empty keycap")
combat=true;local before=created;ns.db.buttonStyle="Classic";ns.ApplyButtonStyle(button)
assert(ns._pendingButtonSettings and created==before and not button._masqueRegistered)
print("PASS: Soft/Classic masks, Masque ownership, bounded chrome pool, keycaps, combat deferral")
