-- Integration of the real settings model with Focus navigation and dialogs.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
UISpecialFrames = {}
local function frame(kind, ...)
    local value = ui.createFrame(kind, ...)
    if kind == "EditBox" then
        function value:HasFocus() return self._focused == true end
        function value:SetFocus() self._focused = true end
        function value:ClearFocus() self._focused = false end
    end
    return value
end
local constantsFile = assert(io.open("Core/Constants.lua", "r"))
local constants = constantsFile:read("*a"); constantsFile:close()
local defaults = assert(load("return {" .. assert(constants:match("NS%.defaults%s*=%s*%{(.-)\n%}\n\n%-%- Theme")) .. "}"))()
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local db = copy(defaults)
local active, spec, bound, applied, resets, spends = "Default", 269, nil, 0, 0, 0
local info = {buildID="windwalker", targetName="Windwalker", enabled=false,
    canSpend=true, canRespec=true, warningEnabled=true, autoRespecEnabled=false, settled=true}
local entry = {id="windwalker", name="Windwalker", specID=269, importString="FIRST"}
local NS = {
    db=db, defaults=defaults, dbRoot={profiles={Default=db, Raid=copy(defaults)}},
    UIParent=ui.uiParent, CreateFrame=frame, unpack=table.unpack,
    Config={Show=function() end, Hide=function() end, Toggle=function() end},
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end,
    GetTalentLevelingInfo=function() return info end,
    GetTalentSpendAllInfo=function() return info end,
    SpendAllTalentPoints=function() spends=spends+1; return true end,
    GetTalentLevelingState=function() return {importString=entry.importString} end,
    FindTalentBuildByID=function() return entry end,
    GetTalentBuildClassToken=function() return "MONK" end,
    GetTalentBuildCurrentSpecID=function() return spec end,
    GetTalentBuildEntriesForClass=function() return {entry} end,
    GetTalentSBAUndoInfo=function() return {canUndo=true} end,
    GetActiveProfileName=function(self) assert(self); return active end,
    GetProfileList=function() return {"Default", "Raid"} end,
    HasCharProfile=function() return bound ~= nil end,
    SetCharProfile=function(_, name) bound=name end,
    ResetProfile=function() resets=resets+1; return true end,
    ApplyProfileVisuals=function() applied=applied+1 end,
    GetFontList=function() return {"Friz Quadrata TT", "Arial Narrow"} end,
    GetPaletteList=function() return {"Confetti", "Gold"} end,
    FONT_OUTLINE_OPTIONS={"NONE", "OUTLINE"},
    CAST_ANIMATIONS={"NONE", "DRIFT", "PULSE", "VORTEX", "ZOOM", "SLAM", "POP!", "BURST", "FADE", "FLIP", "RISE", "SCATTER"},
    PARTICLE_TIMINGS={"On Cast", "On Animation End", "Both"}, PARTICLE_STYLES={"None", "Confetti", "Sparks"},
    KEYBIND_ANCHORS={"TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT"},
    PRIORITY_POSITIONS={"RIGHT", "LEFT", "TOP", "BOTTOM"},
    INTERCEPTION_TYPES={"Keybind", "Click", "Both"},
    AnimKeyPrefix=function(value) return value:gsub("[^%a]", ""):lower() end,
    GetTrinketStatus=function() return {} end,
    SetTalentSBAWarningEnabled=function(value) info.warningEnabled=value; return true end,
    SetTalentAutoRespecEnabled=function(value) info.autoRespecEnabled=value; return true end,
    RequestTalentSBARespec=function() resets=resets+1; return true end,
    RequestTalentSBAUndo=function() resets=resets+1; return true end,
    ShowTalentClassInfo=function(owner)
        owner._talentBuildURLPopup=frame("Frame",nil,ui.uiParent)
        owner._talentBuildURLPopup:Show()
    end,
    HideTalentBuildDialogs=function(owner)
        if owner._talentBuildURLPopup then owner._talentBuildURLPopup:Hide() end
    end,
}
function NS:SwitchProfile(name) active=name; self.db=self.dbRoot.profiles[name]; return true end
assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioSettings.lua"))("BetterSBA", NS)
assert(loadfile("GUI/ConfigSimple.lua"))("BetterSBA", NS)
assert(loadfile("GUI/FocusSettings.lua"))("BetterSBA", NS)
local simple, model = NS.ConfigSimple, NS.StudioSettingsModel
local function click(button) button:GetScript("OnClick")(button) end
local function children(node, fn)
    for _, child in ipairs(rawget(node, "_children") or {}) do fn(child); children(child, fn) end
end
local function inside(child, parent, description)
    local l,t,r,b=mock.rect(child); local pl,pt,pr,pb=mock.rect(parent)
    assert(l>=pl-.01 and r<=pr+.01 and t<=pt+.01 and b>=pb-.01,
        description .. " outside bounds: " .. table.concat({l,t,r,b}, ","))
end
local function checkPage()
    local view = simple.views[simple.view]
    inside(view, simple.frame, simple.view)
    children(view, function(child)
        local kind=rawget(child,"_kind")
        -- Report content is intentionally taller than its clipped viewport.
        if child:IsVisible() and child~=view._edit and (kind=="Button" or kind=="EditBox" or kind=="ScrollFrame") then
            inside(child, view, simple.view .. " control " .. (child._label and child._label:GetText() or "input"))
        end
    end)
end
NS.SwitchSettingsPanel("focus")
assert(simple.frame:IsShown() and db.configExperience=="focus")
NS.ToggleSettingsPanel(); assert(not simple.frame:IsShown())
NS.ToggleSettingsPanel(); assert(simple.frame:IsShown(), "middle-click toggle must reopen the chosen experience")
click(simple.classInfo)
local mainPopup=simple.views.main._talentBuildURLPopup
assert(mainPopup and mainPopup:IsShown())
click(simple.allSettings)
assert(not mainPopup:IsShown(), "Home Class Info must close on navigation")
assert(simple.view=="settingsMenu" and #simple._menuItems==8)
simple:OpenSettingsTopic("Talents")
simple._menuItems[3].open()
local topicPopup=simple.views.settingsMenu._talentBuildURLPopup
assert(topicPopup and topicPopup:IsShown())
simple:Hide(); assert(not topicPopup:IsShown(), "topic Class Info must close with Focus")
simple:Show()
local groups = model.CompileGroups()
local seen, count, pages = {}, 0, 0
for _, topic in ipairs({"Talents","Combat","Button & Queue","Motion","Visibility","Colors & Fonts","Advanced"}) do
    simple:OpenSettingsTopic(topic)
    checkPage()
    local items = {}; for i,item in ipairs(simple._menuItems) do items[i]=item end
    for _, item in ipairs(items) do
        local isGroup=false
        for _, group in ipairs(groups[topic] or {}) do if group[1]==item.title then isGroup=true end end
        if isGroup then
            item.open()
            local view = simple.views[simple.view]
            for _, row in ipairs(view._rows) do
                seen[row._key]=true
                count=count+1
            end
            local total=math.max(1,math.ceil(#view._rows/5))
            for page=1,total do
                view._page=page; simple:Refresh(); pages=pages+1
                local visible=0
                for _, row in ipairs(view._rows) do if row:IsShown() then visible=visible+1 end end
                assert(visible<=5, "Focus must limit controls per page")
                checkPage()
            end
        end
    end
end
assert(applied==0 and resets==0, "browsing settings must not mutate or apply them")
assert(count>150 and pages>35, "full real defaults must be represented")
local otherClass={enableDemonSpikes=true,enableConvokeTheSpirits=true,enableShieldBlock=true,enableIgnorePain=true,
    enableIronfur=true,enableShieldOfRighteous=true,enableRuneTap=true}
for topic, lists in pairs(groups) do
    if topic~="Overview" then for _, group in ipairs(lists) do for _, key in ipairs(group[2]) do
        assert(otherClass[key] or simple.settingsCoverage[key], "missing Focus control: "..key)
    end end end
end
assert(simple.settingsCoverage.enablePurifyingBrew and not simple.settingsCoverage.enableRuneTap,
    "only relevant class helpers should be displayed")

simple:FindSetting()
local find=simple.views.findSetting
find._edit:SetText("button size"); find._edit:GetScript("OnEnterPressed")()
assert(simple._focusDialog.overlay:IsShown() and #simple._focusDialog.choices>0)
click(simple._focusDialog.rows[1]); assert(simple.view:find("settings:",1,true))
checkPage()
local visibleRow
for _, row in ipairs(simple.views[simple.view]._rows) do if row._key=="buttonSize" then visibleRow=row end end
assert(visibleRow and visibleRow:IsShown(), "search must navigate to the page containing the result")

local calls=0
simple:OpenChoices("Many Choices", {1,2,3,4,5,6,7,8}, 7, function(value) calls=value end)
click(simple._focusDialog.next); click(simple._focusDialog.rows[2]); assert(calls==8)
simple:Confirm("Reset?", function() calls=calls+1 end)
NS:SwitchProfile("Raid")
click(simple._focusDialog.confirm)
assert(calls==8 and simple.message:GetText():find("changed",1,true), "stale profile confirmation must not run")
for _, change in ipairs({function() spec=268 end, function() entry.importString="EDITED" end,
    function() info.enabled=not info.enabled end}) do
    simple:Confirm("Change talents?", function() calls=calls+1 end)
    change(); click(simple._focusDialog.confirm)
    assert(calls==8, "stale talent context must not run")
end
simple:Confirm("Cancel on navigation", function() calls=calls+1 end)
simple:OpenSettings(); assert(not simple._focusDialog.overlay:IsShown() and not simple._focusDialog.callback)

simple:OpenProfiles(); checkPage()
local profileView=simple.views.profiles._profileView
click(profileView._profileActions[3]); assert(bound=="Raid")
click(profileView._profileActions[3]); assert(bound==nil, "unbind must really remove the binding")
click(profileView._profileActions[5]); assert(resets==0)
click(simple._focusDialog.confirm); assert(resets==1)
NS.dbRoot.profiles.Default.configPanelScale=.8
NS:SwitchProfile("Default"); simple:Refresh()
assert(simple.frame:GetScale()==.8, "external profile switches must apply their scale immediately")

simple:OpenTalentActions(); checkPage()
click(simple.views.talentActions._all); assert(spends==1 and resets==1)
info.hasMismatch=true
click(simple.views.talentActions._all); assert(spends==1 and resets==1)
click(simple._focusDialog.cancel); assert(resets==1, "canceling a spend-triggered rebuild must leave talents alone")
info.hasMismatch=false
click(simple.views.talentActions._reset); assert(resets==1)
click(simple._focusDialog.confirm); assert(resets==2)
simple:ShowText("Report", string.rep("A long selectable report line\n",100)); checkPage()
assert(simple.views.text._edit:GetHeight()>266)
simple.views.text._scroll:GetScript("OnMouseWheel")(simple.views.text._scroll,-1)
assert(simple.views.text._scroll:GetVerticalScroll()>0)

for _, size in ipairs({{1920,1080},{480,320}}) do
    ui.uiParent:SetSize(size[1],size[2]); simple:ApplyScale()
    assert(simple.frame:GetWidth()*simple.frame:GetScale()<=size[1]-32+.01)
    assert(simple.frame:GetHeight()*simple.frame:GetScale()<=size[2]-32+.01)
    for name in pairs(simple.views) do simple:SelectView(name); checkPage() end
    simple:OpenChoices("Choices", {1,2,3,4,5,6}, nil, function() end)
    inside(simple._focusDialog.card, simple.frame, "choice dialog")
    for _, row in ipairs(simple._focusDialog.rows) do inside(row,simple._focusDialog.card,"choice") end
    simple:Confirm("Reset these settings?", function() end)
    inside(simple._focusDialog.confirm,simple._focusDialog.card,"confirm")
    inside(simple._focusDialog.cancel,simple._focusDialog.card,"cancel")
    simple:CloseDialog()
end
ui.uiParent:SetSize(1920,1080); NS.db.configPanelScale=1; simple:ApplyScale()
if arg and arg[1] then
    simple:OpenSettings(); mock.writeSVG(simple.frame,arg[1].."-menu.svg")
    simple:OpenProfiles(); mock.writeSVG(simple.frame,arg[1].."-profiles.svg")
    simple:OpenTalentActions(); mock.writeSVG(simple.frame,arg[1].."-talents.svg")
    simple:OpenSettingsGroup("Combat", {"Combat Helpers", {"enabled","enableTargeting","enablePetAttack","trinketMode"}})
    mock.writeSVG(simple.frame,arg[1].."-controls.svg")
end
local toc=assert(io.open("BetterSBA.toc","r")); local manifest=toc:read("*a"); toc:close()
for _, path in ipairs({"GUI\\FocusSettings.lua","GUI\\FocusTalentLibrary.lua","GUI\\FocusTools.lua"}) do
    assert(manifest:find(path,1,true), "Focus module missing from manifest: "..path)
end
local source=assert(io.open("BetterSBA.lua","r")); local main=source:read("*a"); source:close()
assert(main:find('msg == "focus" or msg == "simple"',1,true) and main:find('NS.SwitchSettingsPanel("focus")',1,true))
print("PASS Focus settings integration: "..count.." controls, "..pages.." pages; navigation, context, profiles and fitted bounds")
