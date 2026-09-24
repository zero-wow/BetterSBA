-- Run from the addon root: lua tests/test_config_studio.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local db = {
    configExperience = "classic", configStudioWidth = 1120, configStudioHeight = 790,
    configPanelScale = 1, castFeedback = "Motion", enabled = true,
    showPriority = true, enableTargeting = true,
}
local info = {
    enabled = false, warningEnabled = true, autoRespecEnabled = false,
    targetName = "Blood Death Knight - San'layn",
    specName = "Blood", status = "Waiting for an eligible talent.", nextName = "Rune Tap",
    canSpend = true, canRespec = false,
}
local classicShown = false
local NS = {
    UIParent = ui.uiParent, db = db, unpack = table.unpack,
    CreateFrame = ui.createFrame,
    GetConfigFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
    CreatePanel = function(name, parent, w, h)
        local frame = ui.createFrame("Frame", name, parent)
        frame:SetSize(w, h)
        return frame
    end,
    Config = {
        Show = function() classicShown = true end,
        Hide = function() classicShown = false end,
        Toggle = function() classicShown = not classicShown end,
        SelectSection = function() end,
    },
    GetTalentLevelingInfo = function() return info end,
    GetTalentSBAUndoInfo = function() return { canUndo = false } end,
    GetTalentBuildEntriesForClass = function()
        return { { id = "one", name = "Blood Leveling", specID = 250 } }
    end,
    GetTalentBuildClassToken = function() return "DEATHKNIGHT" end,
    GetTalentBuildCurrentSpecID = function() return 250 end,
    SetTalentLevelingTarget = function(id) info.targetName = id; return true end,
    SetTalentLevelingEnabled = function(value) info.enabled = value; return true end,
    SetTalentSBAWarningEnabled = function(value) info.warningEnabled = value; return true end,
    SetTalentAutoRespecEnabled = function(value) info.autoRespecEnabled = value; return true end,
    SpendAllOrRespecTalentPoints = function() return true, "Spending talents." end,
    RequestTalentSBARespec = function() return true end,
    RequestTalentSBAUndo = function() return false end,
}
assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
NS.SwitchSettingsPanel("studio")
assert(db.configExperience == "studio" and NS.ConfigStudio.frame:IsShown())
local studio = NS.ConfigStudio
studio:SelectPage("Talents")
local talents = studio.pages.Talents
talents._change:GetScript("OnClick")(talents._change)
assert(talents._picker:IsShown() and talents._pickerRows[1]:IsShown(),
    "changing the build must expose current-spec targets")
talents._pickerRows[1]:GetScript("OnClick")(talents._pickerRows[1])
assert(info.targetName == "one" and not talents._picker:IsShown(),
    "choosing a build must save its leveling target")
assert(talents._status:GetText() == info.status,
    "a successful build choice must clear the picker error")
talents._auto:GetScript("OnClick")(talents._auto)
assert(info.enabled, "Auto-Spend must enable after choosing a target")
talents._autoRebuild:GetScript("OnClick")(talents._autoRebuild)
assert(info.autoRespecEnabled, "Auto-Rebuild switch must save its state")

local function rect(frame)
    local left, top, right, bottom = mock.rect(frame)
    return { left = left, top = top, right = right, bottom = bottom }
end
local function inside(child, parent, name)
    local a, b = rect(child), rect(parent)
    assert(a.left >= b.left - .1 and a.right <= b.right + .1
        and a.top <= b.top + .1 and a.bottom >= b.bottom - .1,
        name .. " escapes its parent")
end
for _, size in ipairs({ {900, 760}, {1120, 790}, {1300, 900} }) do
    local frame = studio.frame
    frame:SetSize(size[1], size[2])
    frame:GetScript("OnSizeChanged")(frame, size[1], size[2])
    local talents = studio.pages.Talents
    inside(talents._route, studio.content, "route")
    inside(talents._left, studio.content, "left column")
    inside(talents._right, studio.content, "right column")
    inside(talents._browse, studio.content, "build library")
    inside(talents._spend, talents._route, "spend button")
    local a, b = rect(talents._left), rect(talents._right)
    assert(b.left - a.right >= 11, "columns lack a gutter")
    for page, view in pairs(studio.pages) do
        if page ~= "Talents" then inside(view._quickBox, studio.content, page .. " controls") end
    end
end
if arg and arg[1] then
    studio.frame:SetSize(900, 760)
    studio.frame:GetScript("OnSizeChanged")(studio.frame, 900, 760)
    studio:SelectPage("Talents")
    mock.writeSVG(studio.frame, arg[1])
end
NS.SwitchSettingsPanel("classic")
assert(db.configExperience == "classic" and classicShown and not studio.frame:IsShown())
print("Config Studio: load, switching, and minimum/expanded bounds OK")
