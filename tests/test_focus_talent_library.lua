-- Exercise real Focus views and the existing editor/source/delete dialogs.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
UISpecialFrames = {}
UnitName = function() return "Fixture" end
local colors = {}
for _, key in ipairs({ "BG_DARK", "BORDER_ACCENT", "TEXT", "TEXT_DIM", "TEXT_MUTED", "ACCENT",
    "TOGGLE_OFF", "BORDER", "DANGER", "BG_HOVER" }) do colors[key] = { .4, .5, .6, 1 } end
local info = { enabled = false, settled = true, specID = 269, buildID = "CUSTOM" }
local specs = { {specID=269,name="Windwalker"}, {specID=270,name="Mistweaver"},
    {specID=268,name="Brewmaster"}, {specID=999,name="Long Fourth Specialization"} }
local entries = {}
for i = 1, 7 do entries[i] = { id="build-"..i, classToken="MONK", specID=269,
    name="Windwalker Route "..i, source="Guide", catalogSource="Guide", author="Fixture",
    buildType=i==7 and "user" or "builtin", importString="VALID", sourceURL="https://example.test/guide",
    rating="A", notes=string.rep("Source notes. ", 35), outdated=i==1 } end
entries[8] = { id="healer", name="Mistweaver Route", classToken="MONK", specID=270,
    source="Community", buildType="builtin", importString="VALID", rating="S" }
local applies, targets, saves, deletes, current = {}, {}, {}, {}, 269
local NS = {
    THEME=colors, UIParent=ui.uiParent, CreateFrame=ui.createFrame, unpack=table.unpack,
    db={enabled=true}, dbRoot={}, TALENT_BUILD_CUSTOM_ID="CUSTOM",
    TALENT_BUILD_TYPE_USER="user", TALENT_BUILD_TYPE_BUILTIN="builtin", TALENT_BUILD_FILTER_ALL="All",
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end,
    ConfigStudio={Hide=function() end, UI={SetTextIfChanged=function(label, text)
        if label:GetText()==text then return false end; label:SetText(text); return true
    end}},
    GetTalentLevelingInfo=function() return info end,
    GetTalentBuildCurrentSpecID=function() return current end,
    GetTalentBuildClassToken=function() return "MONK" end,
    GetTalentBuildEntriesForClass=function() return entries end,
    GetTalentBuildSpecsForCurrentClass=function() return specs end,
    GetTalentBuildSpecName=function(id) for _, s in ipairs(specs) do if s.specID==id then return s.name end end end,
    GetTalentBuildCustomEntry=function(id) return {id="CUSTOM",specID=id,name="Custom",source="Custom",buildType="custom"} end,
    FindTalentBuildByID=function(id) for _, e in ipairs(entries) do if e.id==id then return e end end end,
    GetTalentBuildSourceInfo=function(entry)
        return {label=entry.outdated and "Outdated" or "Current Patch", summary=entry.outdated
            and "Outdated · Posted June 23, 2026 · Guide Patch 12.0.5" or "Current Patch · Guide Patch 12.1.0"}
    end,
    SetTalentLevelingTarget=function(id)
        targets[#targets+1]=id; info.buildID=id
        if id=="CUSTOM" then info.enabled=false end
        return true
    end,
    RequestTalentBuildApply=function(id, opts) applies[#applies+1]={id=id,opts=opts}; return true end,
    GetTalentBuildLastStatus=function() return nil end,
    ValidateTalentBuildImportString=function(value) return value=="VALID", "Invalid fixture export" end,
    SaveUserTalentBuild=function(entry)
        saves[#saves+1]=entry
        entry.id=entry.id or "personal-"..#saves; entry.buildType="user"
        for i, existing in ipairs(entries) do if existing.id==entry.id then entries[i]=entry; return entry.id end end
        entries[#entries+1]=entry; return entry.id
    end,
    SetSelectedTalentBuildID=function() end,
    DeleteUserTalentBuild=function(id)
        deletes[#deletes+1]=id
        for i, entry in ipairs(entries) do if entry.id==id then table.remove(entries,i); return true end end
        return false
    end,
}
assert(loadfile("GUI/TalentBuildsPanel.lua"))("BetterSBA",NS)
assert(loadfile("GUI/ConfigSimple.lua"))("BetterSBA",NS)
assert(loadfile("GUI/FocusTalentLibrary.lua"))("BetterSBA",NS)
local simple=NS.ConfigSimple
local function click(button)
    assert(button._simpleEnabled~=false, "test attempted disabled action")
    button:GetScript("OnClick")(button)
end
local function search(text)
    local box=simple.talentLibrary.searchBox
    box:SetText(text); box:GetScript("OnTextChanged")(box)
end
local function inside(child,parent,name)
    local l,t,r,b=mock.rect(child); local pl,pt,pr,pb=mock.rect(parent)
    assert(l>=pl-.001 and r<=pr+.001 and t<=pt+.001 and b>=pb-.001, name.." escapes its parent")
end
assert(not simple.talentLibrary and not simple.frame, "library creation must remain lazy")
simple:OpenTalentLibrary()
local state=simple.talentLibrary
assert(simple.frame:IsShown() and simple.view=="library" and #state.matches==8 and state.pages==2)
assert(#targets==0 and #applies==0, "browsing must not choose or apply talents")
click(state.next); assert(state.page==2 and state.rows[4]:IsShown())
click(state.previous); assert(state.page==1)
search("route 1"); assert(#state.matches==1 and state.rows[1].entry.outdated)
assert(state.rows[1].meta:GetText():find("Outdated",1,true))
click(state.rows[1])
assert(simple.view=="libraryDetail" and #targets==0 and #applies==0,
    "row selection must only open details")
assert(state.body:GetText():find("Outdated",1,true) and state.body:GetText():find("does not verify",1,true))
assert(state.consent:GetText():find("leaves it off",1,true))
click(state.leveling)
assert(targets[1]=="build-1" and not info.enabled and #applies==0,
    "leveling selection must preserve Auto-Spend consent and never apply the full build")
info.enabled=true; simple:Refresh()
assert(state.consent:GetText():find("may spend available points",1,true))
local selectConfirmation, selectPrompt
simple.Confirm=function(_,prompt,callback) selectPrompt,selectConfirmation=prompt,callback end
simple.CloseDialog=function() selectConfirmation=nil end
click(state.leveling)
assert(selectConfirmation and #targets==1 and selectPrompt:find("may spend available points",1,true),
    "active library selection must wait for the shared Automatic Points confirmation")
simple:CloseDialog()
assert(#targets==1 and info.enabled, "cancelling library selection must preserve the target and automation")
click(state.leveling)
local choose=selectConfirmation; selectConfirmation=nil; choose()
assert(#targets==2 and info.enabled and #applies==0,
    "confirmed library selection must use the shared target API without applying a full build")
click(state.apply); assert(#applies==1 and applies[1].opts.loadAnyway==false)
assert(not state.edit._simpleEnabled and not state.delete._simpleEnabled,
    "catalog entries must be immutable")
click(state.sourceDetails)
assert(state.detail._talentBuildURLPopup:IsShown())
click(state.detailBack)
assert(not state.detail._talentBuildURLPopup:IsShown(), "switching views must close owner dialogs")

search(""); click(state.spec)
assert(state.specFilter=="all" and #state.matches==9, "all-spec browsing must include the other spec")
search("mistweaver"); click(state.rows[1])
assert(not state.leveling._simpleEnabled and state.apply._label:GetText()=="Switch Spec & Apply")
assert(state.consent:GetText():find("changes specialization",1,true))
click(state.apply)
assert(applies[2].id=="healer" and applies[2].opts.specID==270 and applies[2].opts.loadAnyway,
    "off-spec application must use the shared explicit switch path")
click(state.detailBack); search(""); click(state.kind); click(state.kind)
assert(state.typeFilter=="personal" and #state.matches==2, "personal filter retains the manual Custom option")
click(state.kind); click(state.source)
assert(state.sourceFilter=="Community" and #state.matches==1)
click(state.source); assert(state.sourceFilter=="Guide" and #state.matches==7)
click(state.source); assert(state.sourceFilter==nil)
search("route 7"); click(state.rows[1]); click(state.edit)
local editor=state.detail._talentBuildEditorPopup
assert(editor:IsShown() and editor._mode=="edit" and editor._seedEntry.id=="build-7")
assert(#saves==0, "opening editor must not save")
editor._nameBox:SetText("Renamed Personal Route")
click(editor._saveBtn)
assert(#saves==1 and saves[1].id=="build-7" and #applies==2 and #targets==2)
assert(simple.view=="libraryDetail" and state.title:GetText()=="Renamed Personal Route")
click(state.copy)
assert(editor._mode=="copy" and editor._nameBox:GetText()=="Renamed Personal Route Copy")
click(editor._saveBtn)
assert(#saves==2 and saves[2].id~="build-7" and #applies==2, "copy must save through existing editor only")
click(state.delete)
local confirmation=state.detail._talentBuildDeletePopup
assert(confirmation:IsShown() and #deletes==0, "delete must require the shared confirmation")
click(state.detailBack)
assert(not confirmation:IsShown() and #deletes==0, "navigation cancels pending delete")
search("renamed personal route copy"); click(state.rows[1]); click(state.delete)
click(confirmation._confirm)
assert(#deletes==1 and deletes[1]==saves[2].id and simple.view=="library")

click(state.create)
local create=state.browse._talentBuildEditorPopup
assert(create._mode=="create" and create._nameBox:GetText()=="")
create._nameBox:SetText("New Route"); create._importBox:SetText("BAD")
click(create._saveBtn); assert(#saves==2 and create:IsShown(), "invalid imports must use the existing validation")
create._importBox:SetText("VALID"); click(create._saveBtn)
assert(#saves==3 and #applies==2 and simple.view=="libraryDetail")
click(state.copy); assert(editor:IsShown()); simple:Hide()
assert(not editor:IsShown(), "hiding Focus Mode must close UIParent-owned editor")

simple:Show(); simple:OpenTalentLibrary(); search(""); state.typeFilter="all"; state.sourceFilter=nil
state.specFilter="current"; simple:Refresh()
current=270; simple:Refresh()
assert(#state.matches==2 and state.matches[1].name=="Custom", "current filter must follow specialization changes")
current=269; simple:Refresh()
search("no match anywhere"); assert(state.empty:IsShown() and state.pages==1 and not state.rows[1]:IsShown())
search("custom"); click(state.rows[1]); click(state.leveling)
assert(not info.enabled and targets[#targets]=="CUSTOM", "Custom must stop automatic spending through the shared API")

-- Disclosure controls and editor's four-spec layout stay inside their views.
simple:OpenTalentLibrary(); search("")
for _, control in ipairs({state.create,state.spec,state.kind,state.source,state.searchBox,state.sortButton,
    state.previous,state.next,state.back,state.pageLabel}) do inside(control,state.browse,"library control") end
for _, row in ipairs(state.rows) do inside(row,state.browse,"library row"); inside(row.meta,row,"row metadata") end
for _, control in ipairs({state.detailBack,state.title,state.bodyScroll,state.scrollHint,state.leveling,state.apply,
    state.sourceDetails,state.consent,state.edit,state.copy,state.delete,state.classInfo}) do inside(control,state.detail,"detail control") end
for _, size in ipairs({{640,480},{480,320},{1280,720}}) do
    ui.uiParent:SetSize(size[1],size[2]); simple:Show(); simple:OpenTalentLibrary(); click(state.create)
    local relative=create:GetEffectiveScale()/ui.uiParent:GetEffectiveScale()
    assert(create:GetWidth()*relative<=size[1]-32+.001 and create:GetHeight()*relative<=size[2]-32+.001,
        "editor must fit the scaled screen with a gutter")
    for _, button in ipairs(create._specButtons) do inside(button,create,"specialization choice") end
    local _,_,_,lastBottom=mock.rect(create._specButtons[4]); local _,urlTop=mock.rect(create._urlBox)
    assert(lastBottom>urlTop+8, "specialization choices must leave a visible gutter before source fields")
    simple:SelectView("main"); assert(not create:IsShown())
    simple:OpenTalentLibrary(); search("renamed personal route"); click(state.rows[1])
    local row=NS.FindTalentBuildByID(state.selectedID)
    local original=row.name; row.name=string.rep("Very Long Build Name ",80)
    click(state.delete)
    relative=confirmation:GetEffectiveScale()/ui.uiParent:GetEffectiveScale()
    assert(confirmation:GetWidth()*relative<=size[1]-32+.001
        and confirmation:GetHeight()*relative<=size[2]-32+.001, "delete confirmation must fit small screens")
    assert(confirmation._body:GetText():find("cannot be undone",1,true),
        "a long build name must not displace the deletion warning")
    inside(confirmation._target,confirmation,"delete target")
    inside(confirmation._body,confirmation,"delete warning")
    local _,_,_,warningBottom=mock.rect(confirmation._body)
    local _,confirmTop=mock.rect(confirmation._confirm)
    assert(warningBottom>=confirmTop+8, "confirmation controls need a visible gutter below the warning")
    row.name=original; simple:SelectView("main"); assert(not confirmation:IsShown())
end
if arg and arg[1] then
    ui.uiParent:SetSize(1280,900); simple:Show(); simple:OpenTalentLibrary(); search("")
    if arg[2]=="detail" then search("route 1"); click(state.rows[1]) end
    mock.writeSVG(simple.frame,arg[1])
end
print("Focus library: browse/filter/search, inspect vs apply, consent, shared CRUD confirmation, owned dialogs and bounds passed")
