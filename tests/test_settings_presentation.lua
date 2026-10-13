-- Run from the addon root: lua tests/test_settings_presentation.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
local function CreateFrame(kind, ...)
    local frame = ui.createFrame(kind, ...)
    if kind == "EditBox" then
        -- The shared geometry mock does not model edit-box keyboard focus.
        function frame:HasFocus() return self._focused == true end
        function frame:SetFocus() self._focused = true end
        function frame:ClearFocus() self._focused = false end
    end
    return frame
end
local colors = {text={1,1,1,1}, bright={1,1,1,1}, dim={.6,.6,.6,1},
    rail={.1,.1,.1,1}, border={.2,.2,.2,1}, accent={.2,.6,1,1}}
local function Presentation(font)
    local adapter = { colors=colors, calls=0 }
    function adapter.Label(parent, text, size, color, width, point, relative, relativePoint, x, y)
        adapter.calls = adapter.calls + 1
        local label = parent:CreateFontString(nil, "OVERLAY")
        label:SetText(text); label:SetFont(font, size, ""); label:SetWidth(width)
        label:SetPoint(point, relative, relativePoint, x, y)
        return label
    end
    function adapter.Action(parent, text, x, y, width, height, callback)
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(width, height); button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button._label = adapter.Label(button, text, 11, colors.text, width - 16,
            "CENTER", button, "CENTER", 0, 0)
        button:SetScript("OnClick", callback)
        return button
    end
    function adapter.SetActionText(button, text) button._label:SetText(text) end
    function adapter.FitText(label, text, width)
        label:SetText(text)
        while label:GetStringWidth() > width and #text > 0 do
            text = text:sub(1, -2); label:SetText(text)
        end
    end
    return adapter
end
local fallback, plain = Presentation("studio-font"), Presentation("plain-font")
local visualCalls, refreshCalls, copyCalls, resetCalls = 0, 0, 0, 0
local fonts, activeProfile = {"First Font"}, "Default"
local charProfile
local NS = {
    CreateFrame=CreateFrame, unpack=table.unpack, ConfigStudio={UI=fallback},
    defaults={enabled=true, popParticleDelay=.1, popParticleTiming="On Cast", customText="saved", fontFace="First Font",
        customColor={.1,.2,.3,.4}, position={point="CENTER"}},
    db={enabled=true, popParticleDelay=.1, popParticleTiming="On Cast", customText="saved", fontFace="First Font",
        customColor={.1,.2,.3,.4}},
    GetConfigFontPath=function() return "studio-font" end,
    GetFontList=function() return fonts end,
    ApplyProfileVisuals=function() visualCalls = visualCalls + 1 end,
    GetActiveProfileName=function() return activeProfile end,
    GetProfileList=function() return {"Default", "Raid"} end,
    HasCharProfile=function() return charProfile ~= nil end,
    SetCharProfile=function(_, name) charProfile = name end,
    PARTICLE_TIMINGS={"On Cast", "On Animation End", "Both"}, CAST_ANIMATIONS={"POP!"},
    CopyFromProfile=function(_, name) assert(name == "Raid"); copyCalls=copyCalls+1; return true end,
    ResetProfile=function() resetCalls=resetCalls+1; return true end,
    RenameProfile=function(_, old, name) assert(old == activeProfile); activeProfile=name; return true end,
}
assert(loadfile("GUI/StudioSettings.lua"))("BetterSBA", NS)
local model = assert(NS.StudioSettingsModel)
local content = CreateFrame("Frame", nil, ui.uiParent); content:SetSize(600, 450)
local refreshers = {}
local host = {settingsUI=plain, settingsFontPath="plain-font", settingsRowHeight=52,
    settingsControlHeight=30, settingsFontSize=13,
    settingsLabelWidth=320, frame=content, content=content, pages={},
    notice=content:CreateFontString(nil, "OVERLAY")}
function host:Refresh()
    refreshCalls=refreshCalls+1
    for _, refresh in ipairs(refreshers) do refresh() end
    if self.pages.Profiles then self.pages.Profiles.Refresh() end
end
function host:OpenStudioChoices(title, choices, current, choose)
    self.choices, self.choose = choices, choose
end
function host:ConfirmStudioAction(prompt, confirm) self.confirm = confirm end
local function Click(control) control:GetScript("OnClick")(control) end
local function Enter(control) control:GetScript("OnEnterPressed")(control) end
local rows = {}
for i, key in ipairs({"enabled", "popParticleDelay", "customText", "fontFace", "customColor", "popParticleTiming"}) do
    rows[key] = assert(model.MakeSetting(host, content, key, -i*52, refreshers))
    assert(rows[key]:GetHeight() == 52 and rows[key]._label:GetWidth() == 320)
    local _, _, labelRight = mock.rect(rows[key]._label)
    local controlLeft = mock.rect(rows[key]._control)
    assert(labelRight + 12 <= controlLeft,
        "setting labels need a visible gutter before their controls")
end
assert(fallback.calls == 0 and plain.calls > 0, "host controls must not call the Studio art adapter")
assert(not model.MakeSetting(host, content, "position", -210, refreshers),
    "internal state tables must remain excluded")
assert(model.CompileGroups().Overview[1][2][1] == "enabled")
assert(model.Title("customText") == "Custom Text" and model.ChoiceLabel("TOPRIGHT") == "Top Right")
assert(model.Title("popParticleDelay") == "Pop Particle Delay (seconds)")
local particleKeys
for _, group in ipairs(model.CompileGroups().Motion) do
    if group[1] == "Pop! Particles" then particleKeys=group[2] end
end
assert(particleKeys and particleKeys[1] == "popParticleTiming" and particleKeys[2] == "popParticleDelay",
    "Specific timing and its existing delay setting must share the animation group")
host:Refresh(); host:Refresh()
assert(visualCalls == 0, "opening and refreshing settings must not apply settings")
Click(rows.enabled._control)
assert(NS.db.enabled == false and visualCalls == 1)

local number = rows.popParticleDelay._control
assert(number._font.path == "plain-font" and number._font.size == 13 and number:GetHeight() == 30)
local numericWrites, setNumericText = 0, number.SetText
function number:SetText(value) numericWrites=numericWrites+1; setNumericText(self, value) end
host:Refresh(); host:Refresh()
assert(numericWrites == 0, "unchanged refresh must not rewrite an input")
number:SetFocus(); number:SetText("0.14"); rows.popParticleDelay.Refresh()
assert(number:GetText() == "0.14" and NS.db.popParticleDelay == .1,
    "refresh must preserve an uncommitted numeric edit")
Enter(number)
assert(NS.db.popParticleDelay == .15 and number:GetText() == "0.15" and not number:HasFocus())
number:SetFocus(); number:SetText("1.9")
number:GetScript("OnEscapePressed")(number)
assert(NS.db.popParticleDelay == .15 and number:GetText() == "0.15")
local text = rows.customText._control
assert(text._font.path == "plain-font" and text._font.size == 13 and text:GetHeight() == 30)
text:SetFocus(); text:SetText("draft"); host:Refresh()
assert(text:GetText() == "draft" and NS.db.customText == "saved")
Enter(text); assert(NS.db.customText == "draft" and not text:HasFocus())

fonts = {"First Font", "New Font"}
Click(rows.fontFace._control)
assert(host.choices == fonts, "dynamic choices must be read when opened")
host.choose("New Font"); assert(NS.db.fontFace == "New Font")
Click(rows.popParticleTiming._control)
assert(#NS.PARTICLE_TIMINGS == 3 and #host.choices == 4 and host.choices[4] == "Specific",
    "Specific timing must be offered without mutating the shared presets")
host.choose("Specific")
number:SetFocus(); number:SetText("0.45"); Enter(number)
assert(NS.db.popParticleTiming == "Specific" and NS.db.popParticleDelay == .45,
    "Specific must save the existing timing key and paired delay in seconds")
_G.ColorPickerFrame = {
    SetupColorPickerAndShow=function(self, info)
        self.info, self.cancelFunc, self.shown = info, info.cancelFunc, true
        info.swatchFunc() -- Native setup can dispatch the initial color.
    end,
    Hide=function(self) self.shown=false end,
    IsShown=function(self) return self.shown == true end,
    GetColorRGB=function() return .9,.8,.7 end,
    GetColorAlpha=function() return .6 end,
}
local beforeColorOpen = visualCalls
Click(rows.customColor._control)
assert(visualCalls == beforeColorOpen, "opening the picker must not apply its initial color")
ColorPickerFrame.info.swatchFunc(); assert(NS.db.customColor[4] == .6)
ColorPickerFrame.info.cancelFunc()
assert(NS.db.customColor[1] == .1 and NS.db.customColor[4] == .4,
    "color cancellation must restore the full original RGBA value")
Click(rows.customColor._control)
local hiddenColor = ColorPickerFrame.info
rows.customColor:Hide()
assert(not ColorPickerFrame.shown, "hiding the owning row must close its picker")
hiddenColor.swatchFunc(); hiddenColor.cancelFunc()
assert(NS.db.customColor[1] == .1 and NS.db.customColor[4] == .4,
    "callbacks from a hidden row must not write settings")
rows.customColor:Show()
Click(rows.customColor._control)
local replacedColor = ColorPickerFrame.info
ColorPickerFrame.cancelFunc = function() end -- Another addon has taken the picker.
rows.customColor:Hide()
assert(ColorPickerFrame.shown, "owner cleanup must not hide another addon's picker")
replacedColor.swatchFunc(); replacedColor.cancelFunc()
assert(NS.db.customColor[1] == .1)
rows.customColor:Show()

local paletteOwner, hotkeyOwner
NS.ShowPaletteEditor = function(owner) paletteOwner=owner end
NS.OpenAnimCloneReapplyKeyCapture = function(_, parent, owner)
    assert(parent == host.frame, "hotkey dialog must retain its window parent")
    hotkeyOwner=owner
end
local paletteRow = model.MakeSetting(host, content, "createPalette", 0, {})
local hotkeyRow = model.MakeSetting(host, content, "animCloneReapplyKey", 0, {})
Click(paletteRow._control); Click(hotkeyRow._control)
assert(paletteOwner == paletteRow and hotkeyOwner == hotkeyRow,
    "shared external editors must belong to their actual setting row")

local profiles = model.BuildProfiles(host)
profiles.Refresh()
assert(fallback.calls == 0, "profile controls must use the host adapter too")
Click(profiles._profileActions[3]); assert(charProfile == "Default")
Click(profiles._profileActions[3]); assert(charProfile == nil,
    "Unbind must pass nil to SetCharProfile rather than rebinding the active profile")
local renameInput
for _, child in ipairs(profiles._children) do
    if child._kind == "EditBox" then renameInput = child end
end
assert(renameInput and renameInput._font.path == "plain-font")
assert(renameInput._font.size == 13 and renameInput:GetHeight() == 30)
renameInput:SetFocus(); renameInput:SetText("Renamed"); host:Refresh()
assert(renameInput:GetText() == "Renamed", "profile refresh must preserve the rename draft")
Click(profiles._profileActions[7])
assert(activeProfile == "Renamed" and not renameInput:HasFocus())

-- A profile switch is an edit boundary, even before the next periodic refresh.
number:SetFocus(); number:SetText("1.8")
text:SetFocus(); text:SetText("old profile draft")
renameInput:SetFocus(); renameInput:SetText("wrong profile rename")
Click(rows.customColor._control)
local oldColor, oldProfile = ColorPickerFrame.info, NS.db
NS.db = {enabled=true, popParticleDelay=.25, popParticleTiming="On Cast", customText="new value",
    fontFace="First Font", customColor={.2,.3,.4,.5}}
activeProfile = "Other"
local beforeStale = visualCalls
Enter(number); Enter(text); Click(profiles._profileActions[7])
oldColor.swatchFunc(); oldColor.cancelFunc()
assert(visualCalls == beforeStale and NS.db.popParticleDelay == .25 and NS.db.customText == "new value")
assert(activeProfile == "Other" and renameInput:GetText() == "Other" and not renameInput:HasFocus())
assert(NS.db.customColor[1] == .2 and NS.db.customColor[4] == .5 and not ColorPickerFrame.shown)
assert(oldProfile.customColor[1] == .1, "stale callbacks must not mutate either profile")
number:SetFocus(); number:SetText(".9"); text:SetFocus(); text:SetText("another old draft")
renameInput:SetFocus(); renameInput:SetText("discard on refresh")
NS.db = {enabled=true, popParticleDelay=.35, popParticleTiming="On Cast", customText="third value",
    fontFace="First Font", customColor={.3,.4,.5,.6}}
host:Refresh()
assert(number:GetText() == "0.35" and text:GetText() == "third value"
    and not number:HasFocus() and not text:HasFocus() and renameInput:GetText() == "Other"
    and not renameInput:HasFocus(), "refresh must discard drafts after profile identity changes")
Click(profiles._profileActions[4]); host.choose("Raid")
assert(copyCalls == 0, "copying profile settings must still wait for confirmation")
host.confirm(); assert(copyCalls == 1)
Click(profiles._profileActions[5]); assert(resetCalls == 0)
host.confirm(); assert(resetCalls == 1)
activeProfile = string.rep("Long profile name ", 8)
profiles.Refresh()
for _, child in ipairs(profiles._children) do
    if child._kind == "FontString" and child:GetText():find("^Active Profile:") then
        assert(child:GetStringWidth() <= child:GetWidth(), "long profile names must stay inside their label")
    end
end

-- Existing Studio callers continue to use the original presentation defaults.
host.settingsUI, host.settingsRowHeight, host.settingsLabelWidth = nil, nil, nil
host.settingsControlHeight, host.settingsFontSize, host.settingsFontPath = nil, nil, nil
local legacy = model.MakeSetting(host, content, "enabled", 0, {})
assert(fallback.calls > 0 and legacy:GetHeight() == 28 and legacy._label:GetWidth() == 280)
local legacyNumber = model.MakeSetting(host, content, "popParticleDelay", 0, {})._control
assert(legacyNumber:GetHeight() == 21 and legacyNumber._font.path == "studio-font"
    and legacyNumber._font.size == 11)
assert(refreshCalls > 0)
print("Shared settings presentation tests passed")
