-- Focus Mode shares the real talent/settings actions without replacing Studio.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
UISpecialFrames = {}
local info = { enabled = false, settled = true, specID = 269, nextName = "Rising Sun Kick" }
local entries = {}
for index = 1, 6 do
    entries[index] = { id = "build-" .. index, specID = 269,
        name = "Windwalker Monk - Shado-Pan (Dungeons, Delves & Open World) " .. index,
        outdated = index == 1 }
end
entries[7] = { id = "other-spec", specID = 270, name = "Mistweaver" }
local studioHidden, classicHidden, advancedPage, updateCount, spendCount, selectedID = false, false, nil, 0, 0, nil
local talentReads, catalogReads = 0, 0
local NS = {
    UIParent = ui.uiParent, CreateFrame = ui.createFrame, unpack = table.unpack,
    db = { enabled = true, locked = false, showPriority = false },
    ConfigStudio = {
        UI = { SetTextIfChanged = function(label, value)
            if label:GetText() == value then return false end
            label:SetText(value)
            return true
        end },
        Hide = function() studioHidden = true end,
        SelectPage = function(_, page) advancedPage = page end,
    },
    Config = { Hide = function() classicHidden = true end },
    SwitchSettingsPanel = function(which) assert(which == "studio"); studioHidden = false end,
    ToggleSettingsPanel = function() studioHidden = not studioHidden end,
    GetTalentLevelingInfo = function() talentReads = talentReads + 1; return info end,
    GetTalentBuildCurrentSpecID = function() return 269 end,
    GetTalentBuildClassToken = function() return "MONK" end,
    GetTalentBuildEntriesForClass = function() catalogReads = catalogReads + 1; return entries end,
    FindTalentBuildByID = function(id)
        for _, entry in ipairs(entries) do if entry.id == id then return entry end end
    end,
    GetTalentBuildSourceInfo = function(entry)
        return { label = entry.outdated and "Outdated" or "Current Patch", outdated = entry.outdated,
            summary = "Source posted June 23, 2026. " .. string.rep("Source evidence. ", 100) }
    end,
    SetTalentLevelingTarget = function(id)
        selectedID = id
        info.buildID = id
        for _, entry in ipairs(entries) do if entry.id == id then info.targetName = entry.name end end
        return true
    end,
    SetTalentLevelingEnabled = function(value) info.enabled = value; return true end,
    SpendAllOrRespecTalentPoints = function() spendCount = spendCount + 1; return true, "Spending points." end,
    ApplyProfileVisuals = function(self) assert(self.db); updateCount = updateCount + 1 end,
    UpdatePriorityDisplay = function() updateCount = updateCount + 1 end,
}
local classOwner, classSpec
NS.ShowTalentClassInfo = function(owner, spec) classOwner, classSpec = owner, spec end
assert(loadfile("GUI/ConfigSimple.lua"))("BetterSBA", NS)
local simple = NS.ConfigSimple
assert(not simple.frame, "Focus Mode must remain opt-in and lazy")
NS.ConfigStudio:OpenFocusMode()
assert(simple.frame:IsShown() and studioHidden and classicHidden,
    "opening Focus Mode must hide other settings windows")
assert(UISpecialFrames[1] == "BetterSBA_ConfigSimple", "Escape must close the standalone window")
local function click(button) button:GetScript("OnClick")(button) end
local function inside(child, parent, name)
    local l, t, r, b = mock.rect(child)
    local pl, pt, pr, pb = mock.rect(parent)
    assert(l >= pl and r <= pr and t <= pt and b >= pb, name .. " escapes its parent")
end
assert(simple.views.main:IsShown() and not simple.views.details:IsShown(),
    "technical/source detail must stay hidden on entry")
click(simple.auto)
assert(simple.view == "picker" and not info.enabled, "automatic points without a build must open the picker")
local suggestedOwner, suggestedSpec
NS.ShowSBATalentSuggestions = function(owner, specID) suggestedOwner, suggestedSpec = owner, specID end
click(simple.suggestions)
assert(suggestedOwner == simple.views.picker and suggestedSpec == 269 and not selectedID,
    "Focus suggestions must open a preview without changing the selected route")
assert(simple.pickerRows[1]._label:GetText():find("Outdated", 1, true),
    "old builds must remain identifiable before selection")
click(simple.nextPage)
assert(simple.pickerRows[1].entry.id == "build-5" and not simple.pickerRows[3]:IsShown(),
    "the picker must filter the current spec and paginate remaining builds")
click(simple.previous)
click(simple.pickerRows[1])
assert(selectedID == "build-1" and simple.view == "main" and not info.enabled,
    "choosing a build must not force automatic spending on")
assert(simple.buildName:GetText() == info.targetName and simple.nextTalent:GetText():find("Outdated", 1, true),
    "the current build and its old-source warning must be visible")
assert(simple.buildName:GetStringHeight() <= simple.buildName:GetHeight(),
    "the selected build must have room for its second line")
click(simple.auto)
assert(info.enabled and simple.auto._label:GetText() == "On"
    and simple.message:GetText():find("New points", 1, true), "automatic spending must use the shared state")
info.canSpend = true
simple:Refresh()
click(simple.spend)
assert(spendCount == 1 and simple.message:GetText() == "Spending points.")
local stableWrites = 0
local function CountTextWrites(node)
    if rawget(node, "_kind") == "FontString" then
        local setText = node.SetText
        node.SetText = function(self, value) stableWrites = stableWrites + 1; setText(self, value) end
    end
    for _, child in ipairs(rawget(node, "_children") or {}) do CountTextWrites(child) end
end
CountTextWrites(simple.frame)
stableWrites, talentReads, catalogReads = 0, 0, 0
for _ = 1, 20 do simple:Refresh() end
print(("Stable Focus refresh x20: %d talent reads, %d catalog scans, %d text writes")
    :format(talentReads, catalogReads, stableWrites))
assert(talentReads == 20 and catalogReads == 0 and stableWrites == 0,
    "unchanged Focus refresh must retain fresh state without rewriting text or filtering the catalog")
entries[1].outdated = false
simple:Refresh()
assert(simple.nextTalent:GetText() == "Next: Rising Sun Kick", "changed source status must appear immediately")
entries[1].outdated = true
simple:Refresh()
click(simple.choose)
stableWrites, talentReads, catalogReads = 0, 0, 0
for _ = 1, 20 do simple:Refresh() end
print(("Stable Focus picker x20: %d talent reads, %d catalog scans, %d text writes")
    :format(talentReads, catalogReads, stableWrites))
assert(talentReads == 0 and catalogReads == 20 and stableWrites == 0,
    "the picker must refresh catalog data without inspecting talents or rewriting identical labels")
local firstName = entries[1].name
entries[1].name = "Renamed Build"
simple:Refresh()
assert(simple.pickerRows[1]._label:GetText():find("Renamed Build", 1, true),
    "the reused picker list must still notice renamed catalog entries")
entries[1].name = firstName
local currentSpec = NS.GetTalentBuildCurrentSpecID
NS.GetTalentBuildCurrentSpecID = function() return 270 end
simple:Refresh()
assert(simple.pickerRows[1].entry.id == "other-spec" and not simple.pickerRows[2]:IsShown(),
    "reusing picker storage must remove entries that no longer match the specialization")
NS.GetTalentBuildCurrentSpecID = currentSpec
simple:Refresh()
click(simple.pickerBack)
click(simple.settings.locked)
click(simple.settings.showPriority)
assert(NS.db.locked and NS.db.showPriority and updateCount == 3,
    "basic controls must update shared saved settings and visuals")
click(simple.classInfo)
assert(classOwner == simple.frame and classSpec == 269,
    "Class Info must target the active specialization and the simple window")
click(simple.detailsButton)
assert(simple.view == "details" and not simple.views.main:IsShown()
    and simple.detailText:GetText():find("Source posted June 23", 1, true),
    "source evidence must be available only after opening Details")
assert(simple.scrollHint:IsShown(), "long details must expose a scroll cue")
stableWrites = 0
for _ = 1, 20 do simple:Refresh() end
assert(stableWrites == 0, "unchanged details must preserve their rendered text")
info.status = "Updated talent state"
simple:Refresh()
assert(simple.detailText:GetText():find(info.status, 1, true), "details must update when the talent state changes")
simple.detailScroll:GetScript("OnMouseWheel")(simple.detailScroll, -100)
assert(simple.detailScroll:GetVerticalScroll() == simple.detailChild:GetHeight() - simple.detailScroll:GetHeight(),
    "detail scrolling must stop at the end of its content")
inside(simple.detailScroll, simple.views.details, "details viewport")
click(simple.detailsBack)
for _, state in ipairs({ {hasMismatch=true}, {hasPoints=true}, {settled=false}, {settled=true} }) do
    info.hasMismatch, info.hasPoints, info.canSpend, info.settled = false, false, false, true
    for key, value in pairs(state) do info[key] = value end
    simple:Refresh()
    inside(simple.status, simple.views.main, "talent status")
    assert(simple.status:GetStringHeight() <= simple.status:GetHeight(),
        "talent status must retain both readable lines")
end
for _, button in ipairs({ simple.close, simple.choose, simple.auto, simple.spend, simple.detailsButton,
    simple.classInfo, simple.advanced, simple.previous, simple.nextPage, simple.pickerBack,
    simple.detailsBack, simple.talentOptions, simple.suggestions }) do
    inside(button, simple.frame, "focus action")
    assert(button._label:GetStringWidth() <= button._label:GetWidth(), "action labels must fit")
end
for _, row in ipairs(simple.pickerRows) do inside(row, simple.views.picker, "build row") end
for _, button in pairs(simple.settings) do inside(button, simple.views.main, "setting toggle") end
inside(simple.message, simple.frame, "feedback message")
ui.uiParent:SetSize(640, 480)
simple:Show()
assert(simple.frame:GetScale() < 1, "Focus Mode must fit small screens")
click(simple.advanced)
assert(not simple.frame:IsShown() and not studioHidden and advancedPage == "Overview",
    "Advanced Settings must return to the existing interface")
simple:Show()
click(simple.detailsButton)
assert(simple.detailScroll:GetVerticalScroll() == 0,
    "reopening Details must start at the readable first line")
click(simple.talentOptions)
assert(advancedPage == "Talents", "deeper talent controls must remain reachable")
simple:Show()
NS.ToggleSettingsPanel()
assert(not simple.frame:IsShown() and studioHidden,
    "the main config shortcut must close Focus Mode without opening a second window")
if arg and arg[1] then
    ui.uiParent:SetSize(1280, 900)
    simple:Show()
    if arg[2] == "picker" then click(simple.choose)
    elseif arg[2] == "details" then click(simple.detailsButton) end
    mock.writeSVG(simple.frame, arg[1])
end
print("Focus Mode: optional entry, shared actions, details, pagination and compact bounds OK")
