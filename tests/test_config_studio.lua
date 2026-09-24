-- Run from the addon root: lua tests/test_config_studio.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local db = {
    configExperience = "classic", configStudioWidth = 1120, configStudioHeight = 760,
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
    SetTalentLevelingTarget = function(id)
        info.buildID = id
        info.targetName = "Blood Death Knight - San'layn (Leveling / Delves / Dungeons)"
        return true
    end,
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
assert(talents._pickerCard:GetHeight() == 185,
    "the build picker must not reserve four empty rows for a single build")
talents._pickerRows[1]:GetScript("OnClick")(talents._pickerRows[1])
assert(info.buildID == "one" and not talents._picker:IsShown(),
    "choosing a build must save its leveling target")
assert(talents._routeName:GetText():gsub("\n", " ") == info.targetName
    and talents._change._label:GetText() == "Change Build",
    "the chosen build must replace the empty route label")
assert(talents._status:GetText() == info.status,
    "a successful build choice must clear the picker error")
talents._auto:GetScript("OnClick")(talents._auto)
assert(info.enabled, "Auto-Spend must enable after choosing a target")
assert(studio.notice:GetText() == "Auto-Spend is On for this route."
    and talents._auto._clicks[1] == "LeftButtonUp"
    and talents._auto._stateText:GetText() == "On",
    "the Auto-Spend row must be clickable and confirm its new state")
talents._autoRebuild:GetScript("OnClick")(talents._autoRebuild)
assert(info.autoRespecEnabled, "Auto-Rebuild switch must save its state")
NS.PreviewMotionFeedback = function() return true end
studio:SelectPage("Motion")
local motion = studio.pages.Motion
db.castFeedback = "Off"
motion._preset:GetScript("OnClick")(motion._preset)
assert(db.motionPreset == "Pulse" and db.castFeedback == "Motion"
    and studio.notice:GetText() == "Previewing Pulse.",
    "changing a motion preset must confirm and preview it")
db.motionReduced = true
motion.Refresh()
motion._previewMotion:GetScript("OnClick")(motion._previewMotion)
assert(studio.notice:GetText():find("stationary flash", 1, true)
    and motion._hint:GetText():find("stationary flash", 1, true),
    "Reduced Motion must explain why Orbit does not circle")
db.motionReduced = false
studio:SelectPage("Talents")

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
for _, size in ipairs({ {900, 740}, {1120, 760}, {1300, 900} }) do
    local frame = studio.frame
    frame:SetSize(size[1], size[2])
    frame:GetScript("OnSizeChanged")(frame, size[1], size[2])
    local talents = studio.pages.Talents
    inside(talents._route, studio.content, "route")
    inside(talents._left, studio.content, "left column")
    inside(talents._right, studio.content, "right column")
    inside(talents._browse, studio.content, "build library")
    inside(talents._spend, talents._route, "spend button")
    inside(talents._pickerCard, studio.content, "build picker dialog")
    assert(talents._routeName:GetStringWidth() <= talents._routeName:GetWidth(),
        "the selected build name must fit the route column at every size")
    local a, b = rect(talents._left), rect(talents._right)
    assert(b.left - a.right >= 11, "columns lack a gutter")
    for page, view in pairs(studio.pages) do
        if page ~= "Talents" then inside(view._quickBox, studio.content, page .. " controls") end
    end
end
local talents = studio.pages.Talents
talents._change:GetScript("OnClick")(talents._change)
assert(talents._picker:IsShown(), "build picker must open as a dialog")
studio:SelectPage("Overview")
assert(not talents._picker:IsShown(), "leaving Talents must close the build dialog")
if arg and arg[1] then
    local previewWidth, previewHeight = arg[2] == "default" and 1120 or 900,
        arg[2] == "default" and 760 or 740
    studio.frame:SetSize(previewWidth, previewHeight)
    studio.frame:GetScript("OnSizeChanged")(studio.frame, previewWidth, previewHeight)
    studio:SelectPage(arg[2] == "motion" and "Motion" or "Talents")
    if arg[2] == "picker" then talents._change:GetScript("OnClick")(talents._change) end
    mock.writeSVG(studio.frame, arg[1])
end
NS.SwitchSettingsPanel("classic")
assert(db.configExperience == "classic" and classicShown and not studio.frame:IsShown())
print("Config Studio: load, switching, and minimum/expanded bounds OK")
