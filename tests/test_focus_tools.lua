-- Focus tools dispatch real shared Config helpers without creating Classic UI.
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
UISpecialFrames = {}
local combat, applied, previews, bursts, samples = false, 0, 0, 0, 0
local currentSpec = "Windwalker"
local NS = {
    THEME = {}, UIParent = ui.uiParent, CreateFrame = ui.createFrame, unpack = table.unpack,
    db = { enabled = true, castFeedback = "Motion", castAnimation = "POP!", popParticleStyle = "Confetti",
        popParticlePalette = "Warm", motionDuration = .7, updateRate = .1, untouched = "keep" },
    defaults = { motionDuration = .3, motionPreset = "Pulse", castFeedback = "Motion", motionIntensity = .5,
        motionReduced = false, sectionColorCombat = {.1, .2, .3}, popParticleStyle = "Confetti" },
    CAST_ANIMATIONS = {"NONE", "POP!"},
    AnimKeyPrefix = function(value) return value:gsub("[^%a]", ""):lower() end,
    InCombatLockdown = function() return combat end,
    IsClass = function() return false end,
    IsSpec = function(value) return currentSpec == value end,
    ApplyProfileVisuals = function() applied = applied + 1 end,
    C_Timer_After = function() end,
    VERSION = "test", _loadTime = 0, _overrideKeys = {"TEST-BINDING"},
    GetCacheDiagnostics = function() return {cooldownEntries = 2, textureEntries = 3, resolveEntries = 4} end,
    GetActiveProfileName = function() error("Focus must not read profile identity") end,
    GetMacroActions = function() return {{text = "/targetenemy [noharm]", hint = "Find an enemy if needed."}} end,
    PreviewMotionFeedback = function() previews = previews + 1; return true end,
    PlayCastAnimation = function() previews = previews + 10 end,
    FireParticleBurst = function(button, style, palette)
        assert(button and style == "Confetti" and palette == "Warm"); bursts = bursts + 1
    end,
    ConfigStudio = { UI = { SetTextIfChanged = function(label, value)
        if label:GetText() ~= value then label:SetText(value) end
    end }, Hide = function() end },
    GetTalentLevelingInfo = function() return {} end,
    GetTalentBuildCurrentSpecID = function() return 269 end,
}
NS.mainButton = ui.createFrame("Frame", nil, ui.uiParent)
NS.mainButton.spellID = 42
UpdateAddOnMemoryUsage = function() samples = samples + 1 end
UnitFullName = function() error("Focus must not read character identity") end
UnitClass = function() return "Monk", "MONK" end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 269, "Windwalker" end
UnitLevel = function() return 90 end
GetBuildInfo = function() return "test", "", "", 120100 end
GetLocale = function() return "enUS" end
date = function() return "test date" end
assert(loadfile("GUI/Config.lua"))("BetterSBA", NS)
assert(not NS.Config.frame and samples == 0, "shared tools must not build Classic or sample while loading")
assert(loadfile("GUI/ConfigSimple.lua"))("BetterSBA", NS)
local simple = NS.ConfigSimple
local choice, confirmation, text, paletteCall
function simple:OpenChoices(title, values, current, callback)
    choice = {title = title, values = values, callback = callback}
end
function simple:Confirm(prompt, callback) confirmation = {prompt = prompt, callback = callback} end
function simple:ShowText(title, value) text = {title = title, value = value} end
NS.ShowPaletteEditor = function(owner, key, callback, create)
    paletteCall = {owner = owner, key = key, create = create}
end
assert(loadfile("GUI/FocusTools.lua"))("BetterSBA", NS)
simple:Show()
local function click(button) button:GetScript("OnClick")(button) end
simple:OpenTools("Motion")
local motion = simple.views["tools-motion"]
assert(motion and motion:IsShown() and not NS.Config.frame)
click(motion._actions.preview)
assert(previews == 1 and NS.db.castFeedback == "Motion", "preview must use current feedback without rewriting settings")
NS.db.castFeedback = "Classic"
click(motion._actions.preview)
assert(previews == 11)
click(motion._actions.particles)
assert(bursts == 1)
NS.db.popParticleStyle = "None"
click(motion._actions.particles)
assert(bursts == 1, "None must not play a particle burst")
NS.db.popParticleStyle = "Confetti"
NS.mainButton:Hide()
click(motion._actions.preview)
click(motion._actions.particles)
assert(previews == 11 and bursts == 1, "hidden button must not receive previews")
NS.mainButton:Show()
NS.db.castFeedback = "Off"
click(motion._actions.preview)
assert(previews == 11)
click(motion._actions.createPalette)
assert(paletteCall.owner == motion and paletteCall.key == "popParticlePalette" and paletteCall.create)
click(motion._actions.editPalette)
assert(not paletteCall.create)
click(motion._back)
assert(simple.view == "main")
simple:OpenTools("Advanced")
local advanced = simple.views["tools-advanced"]
click(advanced._actions.macro)
assert(text.value:find("Find an enemy", 1, true) and text.value:find("/targetenemy", 1, true))
assert(samples == 0)
click(advanced._actions.diagnostic)
assert(samples == 1 and text.value:find("Addon Memory:", 1, true)
    and text.value:find("Native (no forced collection)", 1, true)
    and text.value:find("identity omitted", 1, true))
assert(text.value:find("Active (1 bindings", 1, true) and not text.value:find("TEST-BINDING", 1, true),
    "safe reports must show active input without including key names")
for _ = 1, 20 do simple:Refresh() end
assert(samples == 1, "opening tools and refreshing must not poll memory")
click(advanced._actions.reset)
assert(#choice.values == 18 and applied == 0)
choice.callback("Motion Feedback")
assert(confirmation.prompt:find("Motion Feedback", 1, true) and applied == 0,
    "choosing a group must not reset before confirmation")
combat = true
confirmation.callback()
assert(NS.db.motionDuration == .7 and applied == 0, "reset must recheck combat at confirmation")
combat = false
confirmation.callback()
assert(NS.db.motionDuration == .3 and NS.db.untouched == "keep" and applied == 1)
assert(not NS.ResetConfigGroup("untouched"), "caller must not reset arbitrary SavedVariables keys")
assert(NS.ResetConfigGroup("Section Colors"))
assert(NS.db.sectionColorCombat ~= NS.defaults.sectionColorCombat, "color defaults must not alias live settings")
NS.db.sectionColorCombat[1] = .9
assert(NS.defaults.sectionColorCombat[1] == .1)
assert(#NS.GetConfigResetKeys("Particles") == 4)
currentSpec = "Blood"
NS.defaults.enableRuneTap, NS.db.enableRuneTap, NS.db.enableIronfur = false, true, true
click(advanced._actions.reset)
assert(#choice.values == 19 and table.concat(choice.values, "|"):find("Class Abilities", 1, true))
choice.callback("Class Abilities")
currentSpec = "Guardian"
confirmation.callback()
assert(NS.db.enableRuneTap and NS.db.enableIronfur, "changing spec must invalidate the old class reset confirmation")
currentSpec = "Blood"
choice.callback("Class Abilities")
confirmation.callback()
assert(not NS.db.enableRuneTap and NS.db.enableIronfur, "class reset must touch only current-spec ability keys")
currentSpec = "Windwalker"
assert(not NS.GetConfigResetKeys("Class Abilities") and #NS.GetConfigResetGroups() == 18)
local function Bounds(node, parent)
    local l,t,r,b = mock.rect(node)
    local pl,pt,pr,pb = mock.rect(parent)
    assert(l >= pl-.01 and r <= pr+.01 and t <= pt+.01 and b >= pb-.01,
        tostring(node._label and node._label:GetText() or node:GetText() or "control") .. " escapes tools view")
end
for _, size in ipairs({{1920,1080}, {480,320}}) do
    ui.uiParent:SetSize(size[1], size[2])
    simple:Show()
    for _, topic in ipairs({"Motion", "Advanced"}) do
        simple:OpenTools(topic)
        local view = simple.views[simple.view]
        local scale = simple.frame:GetEffectiveScale() / ui.uiParent:GetEffectiveScale()
        assert(simple.frame:GetWidth() * scale <= size[1] - 32 + .01
            and simple.frame:GetHeight() * scale <= size[2] - 32 + .01, "tools must preserve the screen gutter")
        Bounds(view, simple.frame)
        for _, child in ipairs(rawget(view, "_children") or {}) do
            if child:IsShown() then
                Bounds(child, view)
                if child._label then
                    assert(child._label:GetStringWidth() <= child._label:GetWidth(), "tool action label is clipped")
                end
            end
        end
    end
end
assert(not NS.Config.frame, "Focus tools must never create Classic to use its handlers")

-- The shared hotkey popup cannot write into a switched profile or survive its owner.
setmetatable(NS.THEME, {__index = function() return {.2, .3, .4, 1} end})
NS.GetConfigFontPath = function() return "Fonts\\FRIZQT__.TTF" end
NS.BuildBindingChord = function(key) return "CTRL-" .. key end
local bindingApplies, bindingCallbacks = 0, 0
NS.ApplyAnimCloneDebugBinding = function() bindingApplies = bindingApplies + 1 end
simple:SelectView("tools-motion")
local profile = NS.db
local capture = NS.OpenAnimCloneReapplyKeyCapture(function() bindingCallbacks = bindingCallbacks + 1 end, motion)
NS.db = {animCloneReapplyKey = "Keep"}
capture:GetScript("OnKeyDown")(capture, "A")
assert(NS.db.animCloneReapplyKey == "Keep" and bindingApplies == 0 and bindingCallbacks == 0 and not capture:IsShown())
NS.db = profile
capture = NS.OpenAnimCloneReapplyKeyCapture(function() bindingCallbacks = bindingCallbacks + 1 end, simple.frame, motion)
assert(capture:GetParent() == simple.frame, "hotkey ownership must not force its popup inside scrolling content")
simple:SelectView("main")
assert(not capture:IsShown(), "hiding the owner must close key capture")
capture:GetScript("OnKeyDown")(capture, "A")
assert(bindingApplies == 0)
simple:SelectView("tools-motion")
capture = NS.OpenAnimCloneReapplyKeyCapture(function() bindingCallbacks = bindingCallbacks + 1 end, motion)
capture:GetScript("OnKeyDown")(capture, "A")
assert(NS.db.animCloneReapplyKey == "CTRL-A" and bindingApplies == 1 and bindingCallbacks == 1)

-- Exercise the actual palette editor with isolated palette storage.
NS.ipairs, NS.pairs, NS.type, NS.tostring = ipairs, pairs, type, tostring
NS.NERD_FONT = "Fonts\\FRIZQT__.TTF"
NS.GetConfigFontOutline = function() return "" end
string.trim = function(value) return value:match("^%s*(.-)%s*$") end
local paletteWrites, paletteCallbacks = 0, 0
local palettes = { Warm = {{1, .5, .2}, {.2, .3, 1}}, Confetti = {{1, 1, 1}, {0, 0, 0}} }
NS.GetPalette = function(_, name) return palettes[name] end
NS.GetPaletteList = function() return {"Warm", "Confetti"} end
NS.GetPalettePath = function() return "" end
NS.IsBuiltinPalette = function(_, name) return name == "Confetti" end
NS.IsPaletteFavorite = function() return false end
NS.SetPaletteFavorite = function() paletteWrites = paletteWrites + 1 end
NS.SetPalettePath = function() paletteWrites = paletteWrites + 1 end
NS.SavePalette = function() paletteWrites = paletteWrites + 1 end
NS.DeletePalette = function() paletteWrites = paletteWrites + 1 end
assert(loadfile("GUI/Framework.lua"))("BetterSBA", NS)
local function PaletteButton(editor, text)
    for _, child in ipairs(rawget(editor, "_children") or {}) do
        if child._lbl and child._lbl:GetText() == text then return child end
    end
    error("Missing palette button " .. text)
end
local function OpenPalette()
    return NS.ShowPaletteEditor(motion, "popParticlePalette", function() paletteCallbacks = paletteCallbacks + 1 end, false)
end
for _, action in ipairs({"SAVE", "COPY", "DELETE"}) do
    local editor = OpenPalette()
    NS.db = {popParticlePalette = "Keep"}
    click(PaletteButton(editor, action))
    assert(paletteWrites == 0 and NS.db.popParticlePalette == "Keep" and paletteCallbacks == 0,
        "stale palette " .. action .. " must not affect another profile")
    assert(not editor:IsShown())
    NS.db = profile
end
local favoriteEditor = OpenPalette()
local favorite
for _, child in ipairs(rawget(favoriteEditor, "_children") or {}) do
    if rawget(child, "_kind") == "Button" and child:GetWidth() == 20 and child:GetHeight() == 20 then
        favorite = child; break
    end
end
assert(favorite, "palette favorite button missing")
NS.db = {popParticlePalette = "Keep"}
click(favorite)
assert(paletteWrites == 0 and not favoriteEditor:IsShown(), "stale favorite clicks must not change another profile")
NS.db = profile
local editor = OpenPalette()
simple:SelectView("main")
assert(not editor:IsShown() and paletteCallbacks == 0, "hidden palette owner must close without refreshing stale UI")
click(PaletteButton(editor, "COPY"))
assert(paletteWrites == 0)
simple:SelectView("tools-motion")
editor = OpenPalette()
local scale = editor:GetEffectiveScale() / ui.uiParent:GetEffectiveScale()
assert(editor:GetWidth() * scale <= 480 - 32 + .01 and editor:GetHeight() * scale <= 320 - 32 + .01,
    "palette editor must screen-fit when launched from Focus")
click(PaletteButton(editor, "SAVE"))
assert(paletteWrites > 0 and paletteCallbacks == 1 and not editor:IsShown(), "valid palette save must refresh exactly once")
local manyPalettes = {}
for index = 1, 75 do manyPalettes[index] = "Palette " .. index end
manyPalettes[1] = string.rep("Long Palette Name ", 8)
NS.GetPaletteList = function() return manyPalettes end
for _, size in ipairs({{1920,1080}, {480,320}}) do
    ui.uiParent:SetSize(size[1], size[2])
    simple:Show()
    simple:SelectView("tools-motion")
    editor = OpenPalette()
    click(editor._paletteListButton)
    local dropdown = editor._paletteList
    local scroll, child = dropdown._scroll, dropdown._child
    assert(dropdown:GetParent() == editor, "palette list must inherit the editor's fitted scale")
    Bounds(dropdown, editor)
    Bounds(scroll, dropdown)
    assert(dropdown:GetHeight() <= 222 and scroll:GetHeight() == 200 and child:GetHeight() == 1500,
        "long palette lists need a fixed viewport with scrollable content")
    Bounds(dropdown._entries[1]._text, dropdown._entries[1])
    local scrollWheel = scroll:GetScript("OnMouseWheel")
    scrollWheel(scroll, -1000)
    assert(scroll:GetVerticalScroll() == 1300, "scrolling must reach the last palette without overshooting")
    for index = 66, 75 do Bounds(dropdown._entries[index], scroll) end
    local savedChoice, writes = NS.db.popParticlePalette, paletteWrites
    click(dropdown._entries[75])
    assert(not dropdown:IsShown() and NS.db.popParticlePalette == savedChoice and paletteWrites == writes,
        "selecting an editor palette must load a draft without changing the saved choice")
    local frameCount = #ui.frames
    click(editor._paletteListButton)
    assert(#ui.frames == frameCount and scroll:GetVerticalScroll() == 0, "reopening must reuse rows and start at the top")
    manyPalettes = {"Warm", "Confetti"}
    click(editor._paletteListButton)
    click(editor._paletteListButton)
    assert(dropdown:GetHeight() == 44 and not dropdown._entries[3]:IsShown(), "short lists must release excess layout space")
    editor:Hide()
    manyPalettes = {}
    for index = 1, 75 do manyPalettes[index] = "Palette " .. index end
    manyPalettes[1] = string.rep("Long Palette Name ", 8)
end
local function FindSwatch(parent)
    for _, child in ipairs(rawget(parent, "_children") or {}) do
        if rawget(child, "colorTex") and rawget(child, "_kind") == "Button" then return child end
        local found = FindSwatch(child)
        if found then return found end
    end
end
local picker = ui.createFrame("Frame", nil, ui.uiParent)
ColorPickerFrame = picker
picker.GetColorRGB = function() return .3, .4, .5 end
picker.SetupColorPickerAndShow = function(self, info)
    self.cancelFunc, self.swatchFunc = info.cancelFunc, info.swatchFunc
    self:Show()
end
NS.GetPaletteList = function() return {"Warm", "Confetti"} end
editor = OpenPalette()
click(assert(FindSwatch(editor)))
assert(picker:IsShown())
local oldPaint, oldCancel = picker.swatchFunc, picker.cancelFunc
click(assert(FindSwatch(editor)))
local newCancel = picker.cancelFunc
oldPaint(); oldCancel()
assert(picker:IsShown() and picker.cancelFunc == newCancel, "old callbacks must not close a newer swatch session")
click(editor._paletteListButton)
click(editor._paletteList._entries[2])
assert(not picker:IsShown(), "changing palette must close its color picker")
oldPaint(); oldCancel()
editor:Hide()
editor = OpenPalette()
click(assert(FindSwatch(editor)))
simple:SelectView("main")
assert(not editor:IsShown() and not picker:IsShown(), "hiding editor owner must close its picker session")
simple:SelectView("tools-motion")
editor = OpenPalette()
click(assert(FindSwatch(editor)))
oldPaint, oldCancel = picker.swatchFunc, picker.cancelFunc
picker.cancelFunc = function() end -- Another control now owns this shared picker.
editor:Hide()
oldPaint(); oldCancel()
assert(picker:IsShown(), "closing an old editor must not hide a replacement color picker")
print("Focus tools tests passed: shared actions, confirmation, safe snapshot, no polling, normal/tiny bounds")
