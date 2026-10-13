-- Exercise the real popup and catalog in the existing UI mock.
local env = assert(loadfile("tests/test_config.lua"))()
local NS, ui = env.NS, env.ui
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
assert(loadfile("Core/TalentBuildProvenance.lua"))("BetterSBA", NS)
assert(loadfile("Core/TalentAnalysisData.lua"))("BetterSBA", NS)
assert(loadfile("Core/TalentBuildData.lua"))("BetterSBA", NS)
assert(loadfile("Core/SBATalentSearchData.lua"))("BetterSBA", NS)
NS.FindTalentBuildByID = function(id)
    for _, entry in ipairs(NS.TALENT_BUILD_CATALOG.entries) do if entry.id == id then return entry end end
end
GetBuildInfo = function() return "12.1.0", "69933" end
local owner = ui.createFrame("Frame", nil, ui.uiParent)
owner:SetSize(972, 900); owner:SetPoint("CENTER", ui.uiParent, "CENTER", 0, 0)
NS.ShowTalentClassInfo(owner, 269)
local popup = assert(owner._talentBuildURLPopup)
assert(popup:IsShown() and not popup._editBox:IsShown() and not popup._hint:IsShown())
assert(popup._provenance:GetText():find("160,212 DPS", 1, true))
assert(popup._provenance:GetText():find("Separate SBA Talent Search", 1, true)
    and popup._provenance:GetText():find("167804 +/- 371 DPS", 1, true), "Class Info must expose the separate candidate evidence")
assert(popup._sourceScroll:GetHeight() == 224)
assert(popup._sourceContent:GetHeight() > popup._sourceScroll:GetHeight(), "long reports must scroll")
local pl, pt, pr, pb = mock.rect(popup)
local sl, st, sr, sb = mock.rect(popup._sourceScroll)
assert(sl >= pl + 12 and sr <= pr - 12 and st <= pt - 30 and sb >= pb + 20,
    "report viewport needs visible gutters and must leave the close control clear")
popup._sourceScroll:GetScript("OnMouseWheel")(popup._sourceScroll, -1000)
assert(popup._sourceScroll:GetVerticalScroll() <= popup._sourceContent:GetHeight() - 224)

-- Reuse the same dialog for source provenance after displaying Class Info.
local state = NS.BuildTalentBuildsConfigSection(owner)
state.selectedRow = {id="HISTORY", name="Archived Route", specID=100, patch="12.0.5",
    sourcePublishedAt="2026-06-23", sourceURL="https://example.test/build", notes="Fixture"}
state:UpdateDetails()
state.sourceBtn:GetScript("OnClick")(state.sourceBtn)
assert(popup._editBox:IsShown() and popup._hint:IsShown(), "source URL control must be restored")
assert(popup._sourceScroll:GetHeight() == 164)
assert(popup._sourceScroll:GetVerticalScroll() == 0)
assert(popup._provenance:GetText():find("Outdated", 1, true))
assert(popup._provenance:GetText():find("Posted During: 12.0.7", 1, true))
NS.ShowTalentClassInfo(owner, 250)
assert(popup._provenance:GetText():find("Not Tested", 1, true))

-- Both disclosures share a UIParent-owned frame. Refit on every open after
-- screen or owner scaling changes, without changing the owner's preference.
local savedWidth, savedHeight, savedScale = ui.uiParent:GetWidth(), ui.uiParent:GetHeight(), ui.uiParent:GetScale()
local configScale = NS.db.configPanelScale
for _, size in ipairs({ {480, 320, .75, 1.25}, {972, 900, .8, 1.25}, {1920, 1080, 1, 1} }) do
    ui.uiParent:SetSize(size[1], size[2])
    ui.uiParent:SetScale(size[3])
    owner:SetScale(size[4])
    local expected = math.min(size[4], (size[1] - 32) / 560, (size[2] - 32) / 300)
    local function fitted()
        local relativeScale = popup:GetEffectiveScale() / ui.uiParent:GetEffectiveScale()
        assert(math.abs(relativeScale - expected) < .0001, "popup must follow owner scale and fit the current viewport")
        assert(popup:GetWidth() * relativeScale <= size[1] - 32 + .001
            and popup:GetHeight() * relativeScale <= size[2] - 32 + .001, "popup needs a gutter on both sides")
        assert(owner:GetScale() == size[4] and NS.db.configPanelScale == configScale,
            "popup fitting must not alter the owner or saved panel scale")
    end
    NS.ShowTalentClassInfo(owner, 269)
    fitted()
    assert(not popup._editBox:IsShown() and popup._sourceScroll:GetHeight() == 224)
    state.sourceBtn:GetScript("OnClick")(state.sourceBtn)
    fitted()
    assert(popup._editBox:IsShown() and popup._hint:IsShown() and popup._sourceScroll:GetHeight() == 164,
        "fitting must preserve source-dialog controls and viewport")
end
ui.uiParent:SetSize(savedWidth, savedHeight)
ui.uiParent:SetScale(savedScale)
owner:SetScale(1)
print("talent info UI: scroll, scaled-screen bounds, source-dialog reuse and untested states passed")
