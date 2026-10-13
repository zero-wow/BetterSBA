local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()
UISpecialFrames = {}
UnitFactionGroup = function() return arg and arg[3] == "horde" and "Horde" or "Alliance" end
local spec, class = 269, "MONK"
local info = { enabled = false }
local entries = {
    a = { id = "a", name = "Windwalker - Shado-Pan", importString = "tested-a", classToken = "MONK", specID = 269 },
    b = { id = "b", name = "Windwalker - Conduit", importString = "tested-b", classToken = "MONK", specID = 269 },
}
local function choice(id)
    local entry = entries[id]
    return { buildID = id, name = entry.name, importString = entry.importString }
end
local results = {
    [1] = { state = "ready", reason = "Highest result among the tested builds for one target.",
        details = "Public example gear. Exact matching patch and build.\nThis is not your character's predicted damage.",
        scenario = 1, candidateCount = 2, choices = { choice("a") } },
    [5] = { state = "tie", reason = "The tested results are too close to name one winner.",
        details = "Both builds are within the comparison's uncertainty.",
        scenario = 5, candidateCount = 2, choices = { choice("a"), choice("b") } },
}
local selected, reads, validates, callbackCount = {}, 0, 0, 0
local validationError, applyError, classInfoSpec
local function createFrame(...)
    local frame = ui.createFrame(...)
    frame.SetEnabled = function(self, enabled) self._enabled = enabled == true end
    return frame
end
local NS = {
    UIParent = ui.uiParent, CreateFrame = createFrame, unpack = table.unpack, db = {},
    GetConfigFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
    GetTalentBuildCurrentSpecID = function() return spec end,
    GetTalentBuildClassToken = function() return class end,
    GetTalentLevelingInfo = function() return info end,
    GetBestTestedSBABuild = function(_, targets) reads = reads + 1; return results[targets] end,
    FindTalentBuildByID = function(id) return entries[id] end,
    ValidateTalentBuildImportString = function(importString, specID)
        validates = validates + 1
        assert(specID == spec and (importString == "tested-a" or importString == "tested-b"))
        return not validationError, validationError
    end,
    SetTalentLevelingTarget = function(id)
        if applyError then return false, applyError end
        selected[#selected + 1] = id
        return true
    end,
    SetTalentLevelingEnabled = function() error("suggestions must never change Automatic Points") end,
    ShowTalentClassInfo = function(_, specID) classInfoSpec = specID end,
}
assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComicLettering.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComic.lua"))("BetterSBA", NS)
NS.ConfigStudio.Comic.ApplyPalette(NS.ConfigStudio.UI.colors)
assert(loadfile("GUI/SBATalentSuggestions.lua"))("BetterSBA", NS)
assert(not NS.SBATalentSuggestions, "suggestions must be lazy and opt-in")
local owner = ui.createFrame("Frame", nil, ui.uiParent)
owner:SetSize(900, 600)
owner:SetPoint("CENTER")
local function open()
    NS.ShowSBATalentSuggestions(owner, spec, function(entry, enabled)
        callbackCount = callbackCount + 1
        assert(entry == entries[selected[#selected]] and enabled == info.enabled)
    end)
    return NS.SBATalentSuggestions
end
local function click(button) button:GetScript("OnClick")(button) end
local function inside(child, parent, label, gutter)
    local l, t, r, b = mock.rect(child)
    local pl, pt, pr, pb = mock.rect(parent)
    gutter = gutter or 0
    assert(l >= pl + gutter and r <= pr - gutter and t <= pt - gutter and b >= pb + gutter,
        label .. " escapes its visible bounds")
end
local function checkBounds(p)
    assert(p.frame:GetWidth() <= 560 and p.frame:GetHeight() <= 400)
    for _, control in ipairs({ p.close, p.scenarios[1], p.scenarios[5], p.status, p.scroll,
        p.consent, p.detailsButton, p.classInfo, p.choose }) do
        inside(control, p.frame, "suggestion control", 12)
        if control._label then
            assert(control._label:GetStringWidth() <= control._label:GetWidth(), "fixed button label does not fit")
        end
    end
    assert(p.consent:GetStringHeight() <= p.consent:GetHeight(), "automatic-points disclosure is clipped")
    local _, _, _, bodyBottom = mock.rect(p.scroll)
    local _, consentTop, _, consentBottom = mock.rect(p.consent)
    local _, actionTop = mock.rect(p.choose)
    assert(bodyBottom - consentTop >= 20 and consentBottom - actionTop >= 12,
        "scroll content and final controls need separate visible gutters")
    for _, row in ipairs(p.rows) do
        if row:IsShown() then
            inside(row, p.content, "suggested build row")
            inside(row._label, row, "wrapped build name", 7)
            assert(row._label:GetStringHeight() <= row._label:GetHeight(), "long names must not be clipped")
        end
    end
end
local p = open()
assert(p.frame:IsShown() and p.selected.buildID == "a" and #selected == 0 and not info.enabled,
    "opening a ready preview must not choose a route or enable automatic points")
assert(UISpecialFrames[#UISpecialFrames] == "BetterSBA_SBATalentSuggestions", "Escape must close the preview")
checkBounds(p)
click(p.scenarios[5])
assert(not p.selected and p.choose._enabled == false and #selected == 0, "ties require an explicit row choice")
assert(p.content:GetHeight() <= p.scroll:GetHeight(), "two ordinary tied build names must fit without a cut-off row")
click(p.choose)
assert(#selected == 0, "a disabled final action must not choose a tied build")
click(p.rows[2])
assert(p.selected.buildID == "b" and #selected == 0, "previewing a tied build must not apply it")
local readsBefore = reads
click(p.choose)
assert(selected[1] == "b" and reads == readsBefore + 1 and validates == 1 and callbackCount == 1,
    "final choice must requery evidence, validate the import, and use the existing target setter")
assert(not p.frame:IsShown() and not info.enabled, "choosing must preserve Automatic Points Off")

for _, state in ipairs({ "stale", "unavailable", "single-candidate" }) do
    results[1].state = state
    p = open()
    assert(not p.selected and p.choose._enabled == false, "non-comparative results must not recommend a build")
    checkBounds(p)
    click(p.choose)
    assert(#selected == 1)
end
results[1].state = "ready"
p = open()
results[1].state = "stale"
click(p.choose)
assert(#selected == 1 and p.choose._enabled == false, "results becoming stale after preview must block selection")
results[1].state = "ready"
p = open()
entries.a.importString = "edited-after-test"
click(p.choose)
assert(#selected == 1 and p.choose._enabled == false, "a catalog edit must not reuse the tested build identity")
entries.a.importString = "tested-a"
p = open()
spec = 270
click(p.choose)
assert(#selected == 1 and p.choose._enabled == false, "a specialization change must block the old preview")
spec = 269
p = open()
class = "MAGE"
click(p.choose)
assert(#selected == 1 and p.choose._enabled == false, "a class mismatch must block the old preview")
class = "MONK"
p = open()
validationError = "Talent tree does not match."
click(p.choose)
assert(#selected == 1 and p.body:GetText() == validationError, "import validation failures must be visible")
validationError = nil
applyError = "Wait for the current talent change to finish."
click(p.choose)
assert(#selected == 1 and p.body:GetText() == applyError, "existing runtime rejection must remain visible")
applyError = nil
info.enabled = true
click(p.choose)
assert(#selected == 1 and p.consent:GetText():find("immediately", 1, true),
    "Automatic Points changed after preview: refresh its disclosure before accepting the click")
click(p.choose)
assert(#selected == 2 and info.enabled and callbackCount == 2, "explicit confirmation must preserve Automatic Points On")

results[1].choices[1].name = string.rep("A Long Build Name ", 25)
results[1].details = string.rep("Full comparison evidence, conditions and limitations.\n", 30)
p = open()
checkBounds(p)
assert(p.scrollHint:IsShown(), "long build names must expose scrolling")
p.scroll:GetScript("OnMouseWheel")(p.scroll, -100)
assert(p.scroll:GetVerticalScroll() == p.content:GetHeight() - p.scroll:GetHeight(), "scrolling must clamp to its content")
click(p.detailsButton)
checkBounds(p)
assert(p.body:GetText():find("Full comparison evidence", 1, true) and p.scrollHint:IsShown(),
    "all evidence must remain readable in the scrollable Details view")
click(p.detailsButton)
assert(p.scroll:GetVerticalScroll() == 0, "returning from Details starts at the first choice")
for _, size in ipairs({ {900, 600}, {640, 480}, {480, 320} }) do
    ui.uiParent:SetSize(size[1], size[2])
    p = open()
    assert(p.frame:GetWidth() * p.frame:GetScale() <= size[1] - 32
        and p.frame:GetHeight() * p.frame:GetScale() <= size[2] - 32, "popup must fit small screens")
    checkBounds(p)
end
click(p.classInfo)
assert(classInfoSpec == 269 and not p.frame:IsShown(), "Class Info must remain explicitly accessible")
p = open()
owner:Hide()
assert(not p.frame:IsShown(), "closing the owning picker must close its preview")
owner:Show()
if arg and arg[1] then
    ui.uiParent:SetSize(1280, 900)
    results[1].choices[1].name = entries.a.name
    results[1].details = "Example gear at max level.\nMatching patch and build.\nCompared using the same fight length and SBA mode."
    p = open()
    if arg[2] == "tie" then click(p.scenarios[5])
    elseif arg[2] == "details" then click(p.detailsButton)
    elseif arg[2] == "stale" then
        results[1].state, results[1].reason = "stale", "Tests do not match your current patch and build."
        p = open()
    end
    -- The SVG mock cannot resolve nested lettering assets. Show their native
    -- measurement labels in this diagnostic preview only.
    local function previewLabels(node, parentAlpha)
        if rawget(node, "_comicLettering") and rawget(node, "_kind") == "FontString" then
            node._comicLettering:Hide(); node:SetAlpha(1); node:Show()
        end
        local alpha = node:GetAlpha() * (parentAlpha or 1)
        node:SetAlpha(alpha)
        for _, child in ipairs(rawget(node, "_children") or {}) do previewLabels(child, alpha) end
    end
    previewLabels(p.frame)
    mock.writeSVG(p.frame, arg[1])
end
print("SBA suggestions: explicit choice, ties, stale evidence, exact imports, Auto-Spend consent, errors and compact bounds OK")
