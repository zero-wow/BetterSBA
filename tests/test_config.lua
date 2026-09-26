-- Run from the addon root: lua tests/test_config.lua
local mock = assert(loadfile("tests/wow_ui_mock.lua"))()
local ui = mock.install()

local colors = {
    BG_DARK={.02,.03,.04,1}, BG_CARD={.04,.05,.06,1}, BG_HEADER={.06,.07,.08,1}, BG={.03,.04,.05,1}, BG_HOVER={.1,.12,.14,1},
    BORDER={.2,.25,.3,1}, BORDER_ACCENT={.2,.35,.45,1}, ACCENT={.2,.7,1,1}, ACCENT_DIM={.15,.45,.65,1}, ACCENT_BRIGHT={.4,.85,1,1},
    TEXT={.9,.9,.9,1}, TEXT_DIM={.6,.6,.6,1}, TEXT_MUTED={.4,.4,.4,1}, TOGGLE_ON={.2,.8,.5,1}, TOGGLE_OFF={.1,.1,.1,1}, DANGER={1,.2,.2,1},
}
local function color() return {.3,.6,.9,1} end
local defaults = {
    configPanelBaseHeight=480, configPanelHeight=620, configPanelScale=1, cfgAnimTransitions=false,
    sectionColorCombat=color(), sectionColorAppearance=color(), sectionColorActive=color(), sectionColorPriority=color(),
    sectionColorTalentBuilds=color(), sectionColorVisibility=color(), sectionColorImportance=color(), sectionColorAdvanced=color(), sectionColorProfiles=color(),
}
setmetatable(defaults, { __index = function() return false end })
local db = {}; for k, v in pairs(defaults) do db[k] = v end
-- A prior user-resized 413px panel exceeds the new 400px safety floor and
-- must be honored rather than reset to the default compact height.
db.configPanelBaseHeight, db.configPanelHeight = 413, 413
db.castFeedback, db.castAnimation, db.buttonStyle = "Motion", "Off", "Soft"
db.talentBuildShowBuiltIn, db.talentBuildShowUser, db.talentBuildUseDefaultSort = true, true, true
db.talentBuildSearchText, db.talentBuildSourceFilter = "", "All"
for _, key in ipairs({"buttonBgColor", "priorityBgColor", "priorityBorderColor", "importColorAutoAttack", "importColorFiller", "importColorLongCD", "importColorMajorCD", "importColorShortCD"}) do
    db[key] = color()
end
-- Opening a page fires every slider's real OnShow initializer. Supply values
-- for the full slider surface so lifecycle coverage does not accidentally
-- depend on a mock that suppresses those handlers.
for _, key in ipairs({
    "motionDuration", "motionIntensity", "gcdDuration", "keybindFontSize",
    "priorityKeybindFontSize", "priorityLabelFontSize", "pauseSymbolFontSize",
    "pauseReasonFontSize", "buttonSize", "scale", "keybindOffsetX", "keybindOffsetY",
    "animCloneKeybindOffsetX", "animCloneKeybindOffsetY", "animCloneKeybindFontSize",
    "priorityIconSize", "priorityScale", "prioritySpacing", "priorityOffsetX",
    "priorityOffsetY", "priorityKeybindOffsetX", "priorityKeybindOffsetY",
    "priorityLabelOffsetX", "priorityLabelOffsetY", "alphaOOC", "priorityAlphaOOC",
}) do
    db[key] = 1
end

local NS = {
    THEME=colors, defaults=defaults, db=db, dbRoot={profiles={}}, UIParent=ui.uiParent,
    CreateFrame=ui.createFrame, pairs=pairs, ipairs=ipairs, type=type, tostring=tostring, unpack=table.unpack,
    table_concat=table.concat, math_floor=math.floor, VERSION="test", NERD_FONT="Fonts\\FRIZQT__.TTF",
    TC={KEY="",UI="",VAL="",WARN="",NUM="",R=""},
    GLYPH_TRI_DOWN="v", GLYPH_TRI_RIGHT=">", GLYPH_CHEVRON_DOWN="v", GLYPH_CHEVRON_UP="^", GLYPH_DIAMOND="*", GLYPH_LOCK="L", GLYPH_UNLOCK="U", GLYPH_PLAY=">", GLYPH_STAR_EMPTY="o", GLYPH_STAR_FILLED="*",
    INTERCEPTION_TYPES={"Action Button", "Keybind"}, CAST_ANIMATIONS={"Off", "Pulse"}, FONT_OUTLINE_OPTIONS={"", "OUTLINE"},
    KEYBIND_ANCHORS={"TOPRIGHT"}, ANCHOR_POINTS={"CENTER"}, PARTICLE_STYLES={"Confetti"}, PARTICLE_TIMINGS={"On Cast"}, PARTICLE_STYLE_DEFAULTS={}, THEME_PRESET_ORDER={},
    PRIORITY_POSITIONS={"BOTTOM"},
    TALENT_BUILD_CUSTOM_ID="CUSTOM", TALENT_BUILD_TYPE_USER="user", TALENT_BUILD_TYPE_BUILTIN="builtin",
    TALENT_BUILD_FILTER_ALL="All", TALENT_BUILD_SOURCES={"All", "Very Long Source Alpha", "Very Long Source Bravo", "Very Long Source Charlie", "Very Long Source Delta", "Very Long Source Echo", "Very Long Source Foxtrot"},
    C_Timer_After=function() end, C_Timer_NewTicker=function() return {Cancel=function() end} end,
    GetConfigFontPath=function() return "Fonts\\FRIZQT__.TTF" end, GetConfigFontOutline=function() return "" end,
    GetFontList=function() return {} end, GetFontPath=function() return "Fonts\\FRIZQT__.TTF" end,
    AddTooltip=function() end, InCombatLockdown=function() return false end,
    IsClass=function() return false end, IsSpec=function() return false end, IsPetClass=function() return false end,
    GetMacroActions=function() return {} end, GetTrinketStatus=function() return {} end, GetActiveProfileName=function() return "Default" end,
    GetCharKey=function() return "Tester-Realm" end, GetCacheDiagnostics=function() return {} end,
    AnimKeyPrefix=function(animation) return "anim" .. tostring(animation) end,
    _restoreSection=false, _restoreScroll=false, _activeSection=1, _loadTime=0, _overrideKeys=false, _overrideSlot=false,
    masque=false, priorityFrame=false, mainButton=false, secureButton=false, _priorityIcons=false,
}
setmetatable(NS, { __index = function() return function() end end })
local entries = {}
for i, source in ipairs({"Very Long Source Alpha", "Very Long Source Bravo", "Very Long Source Charlie", "Very Long Source Delta", "Very Long Source Echo", "Very Long Source Foxtrot"}) do
    entries[i] = {id="BUILD-" .. i, name="Build " .. i, specID=(i % 2 == 0 and 101 or 100), author="Tester", source=source, catalogSource=source, rating="A", buildType="builtin", sourceURL="https://example.test/" .. i,
        verificationStatus=(i == 1 and "guide-adapted" or nil)}
end
NS.GetTalentBuildSpecsForCurrentClass = function() return {{specID=100, index=1}, {specID=101, index=2}} end
NS.GetTalentBuildCurrentSpecID = function() return 100 end
NS.GetTalentBuildSpecName = function(id) return id == 100 and "Arcane" or "Fire" end
NS.GetTalentBuildClassToken = function() return "MAGE" end
NS.GetTalentBuildEntriesForClass = function() return entries end
NS.GetTalentBuildCustomEntry = function(id, name) return {id="CUSTOM", name="Custom", specID=id, specName=name, buildType="custom", source=""} end
NS.GetSelectedTalentBuildID = function() return "CUSTOM" end
NS.GetTalentBuildLastStatus = function() return nil end
local applyCalls = 0
NS.RequestTalentBuildApply = function() applyCalls = applyCalls + 1; return true end
local leveling = {buildID="CUSTOM", enabled=false, targetName=nil, specName="Arcane", nextName=nil, status="Choose a build for leveling.", detail="Catalog freshness is unverified; prerequisite order will be used.", canSpend=false}
NS.GetTalentLevelingState = function() return leveling end
NS.GetTalentLevelingInfo = function() return leveling end
NS.SetTalentLevelingTarget = function(buildID)
    leveling.buildID = buildID
    leveling.targetName = buildID == "CUSTOM" and nil or ("Build " .. tostring(buildID):gsub("BUILD%-", ""))
    leveling.nextName = buildID == "CUSTOM" and nil or "Arcane Surge"
    leveling.status = buildID == "CUSTOM" and "Leveling target cleared." or "Ready for the next available talent point."
    leveling.canSpend = buildID ~= "CUSTOM"
    return true, leveling.status
end
NS.SetTalentLevelingEnabled = function(enabled)
    leveling.enabled = enabled and true or false
    return true, leveling.enabled and "Auto-spend enabled." or "Auto-spend disabled."
end
NS.SpendNextTalentPoint = function()
    if not leveling.canSpend then return false end
    leveling.status = "Spent Arcane Surge."
    return true
end
local sbaAssessment = {
    warningEnabled=false, hasMismatch=false, settled=true, specID=100, buildID="BUILD-1",
    signature="mage-arcane-build-1-mismatch-one", targetName="Arcane SBA",
    message="Your learned talents differ from the selected SBA target.", detail="The selected target can be reset and applied at your current level.",
    canRespec=true,
}
local warningSetCalls, respecCalls, undoCalls = 0, 0, 0
local undoAvailable = false
NS.GetTalentSBAAssessment = function() return sbaAssessment end
NS.GetTalentSBAUndoInfo = function() return { canUndo = undoAvailable } end
NS.SetTalentSBAWarningEnabled = function(enabled)
    warningSetCalls = warningSetCalls + 1
    sbaAssessment.warningEnabled = enabled and true or false
    return true, sbaAssessment.warningEnabled and "SBA warning enabled." or "SBA warning disabled."
end
NS.RequestTalentSBARespec = function()
    respecCalls = respecCalls + 1
    if not sbaAssessment.canRespec then return false, "Cannot respec while the talent tree is changing." end
    return true, "SBA respec requested."
end
NS.RequestTalentSBAUndo = function()
    undoCalls = undoCalls + 1
    if not undoAvailable then return false, "Talent allocation changed since the respec." end
    return true, "Restoring prior talents."
end
NS.GetInterceptBlockReason = function() return nil end
UnitClass = function() return "Mage", "MAGE", 8 end

assert(loadfile("GUI/Framework.lua"))("BetterSBA", NS)
assert(loadfile("GUI/TalentBuildsPanel.lua"))("BetterSBA", NS)
assert(loadfile("GUI/Config.lua"))("BetterSBA", NS)

-- The config root has several OnShow/OnHide hooks. Verify the widget harness
-- preserves primary scripts plus every hook and honours ancestor visibility.
local lifecycleParent = ui.createFrame("Frame", nil, ui.uiParent)
lifecycleParent:Hide()
local lifecycleChild = ui.createFrame("Frame", nil, lifecycleParent)
local lifecycleOrder = {}
lifecycleChild:SetScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "script" end)
lifecycleChild:HookScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "hook-one" end)
lifecycleChild:HookScript("OnShow", function() lifecycleOrder[#lifecycleOrder + 1] = "hook-two" end)
assert(lifecycleChild:IsShown() and not lifecycleChild:IsVisible(),
    "a shown child of a hidden frame must not be treated as visible")
lifecycleParent:Show()
assert(table.concat(lifecycleOrder, ",") == "script,hook-one,hook-two",
    "Show must preserve the primary script and every HookScript callback")
lifecycleParent:Hide()
assert(lifecycleChild:IsShown() and not lifecycleChild:IsVisible(),
    "hiding an ancestor must make descendants non-visible without clearing local state")

local function newestSection(index)
    for i = #ui.frames, 1, -1 do
        if ui.frames[i]._kind == "Frame" and rawget(ui.frames[i], "_sectionIndex") == index then return ui.frames[i] end
    end
end

local function findTextWidget(frame, wanted)
    if rawget(frame, "_text") == wanted then return frame end
    for _, child in ipairs(frame._children) do
        local found = findTextWidget(child, wanted)
        if found then return found end
    end
end

local function findHeaderWidget(frame, wanted)
    if rawget(frame, "_text") == wanted and rawget(frame, "_line") then return frame end
    for _, child in ipairs(frame._children) do
        local found = findHeaderWidget(child, wanted)
        if found then return found end
    end
end

local tabLabels = {
    "Combat", "Style", "Button", "Priority", "Talents",
    "Visibility", "Colors", "Advanced", "Profiles",
}

local function assertTopTabs(panel)
    local tabBar = assert(NS.Config.tabBar, "top tab bar must be exposed")
    local buttons = assert(NS.Config.sectionButtons, "section tabs must be exposed")
    assert(#buttons == 9, "exactly nine top-level section tabs are required")
    assert(tabBar:GetHeight() == 34, "top navigation strip must retain a 34px hit target")

    local pl, pt, pr = mock.rect(panel)
    local bl, bt, br, bb = mock.rect(tabBar)
    assert(math.abs(bl - pl) < .1 and math.abs(br - pr) < .1,
        "tab bar must span the panel width")
    assert(math.abs(bt - (pt - 40)) < .1 and math.abs(bb - (bt - 34)) < .1,
        "tab bar must sit directly below the 40px toolbar")

    local tabW = (panel:GetWidth() - 24) / 9
    local previousRight
    for i, button in ipairs(buttons) do
        assert(rawget(button, "_parent") == tabBar, "all tabs must share the horizontal tab bar")
        local l, t, r, b = mock.rect(button)
        local expectedLeft = pl + 12 + (i - 1) * tabW
        assert(math.abs(l - expectedLeft) < .1 and math.abs((r - l) - tabW) < .1,
            ("tab %d must use an equal horizontal slot"):format(i))
        assert(math.abs(t - bt) < .1 and math.abs(b - bb) < .1,
            "tab must remain within the 34px navigation strip")
        if previousRight then
            assert(l >= previousRight - .1, "adjacent tabs must not overlap")
        end
        previousRight = r
        local label = assert(rawget(button, "_lbl"), "tab requires a visible label")
        local ll, _, lr = mock.rect(label)
        assert(rawget(label, "_text") == tabLabels[i], "tab label changed unexpectedly")
        assert(ll >= l + 4 and lr <= r - 4, "tab label must retain horizontal gutters")
    end
end

local function assertActiveSectionInScrollRegion(index)
    local cf = assert(newestSection(index), "active content frame missing")
    local scrollChild = rawget(cf, "_parent")
    local scrollFrame = scrollChild and rawget(scrollChild, "_parent")
    assert(scrollFrame and rawget(scrollFrame, "_scrollChild") == scrollChild,
        "each disclosure section must remain parented to the scroll child")
    assert(scrollChild:GetHeight() == cf._contentH,
        "active disclosure height must be reserved by the scroll child")
    local expectedWidth = index == 5 and 972 or 632
    assert(cf:GetWidth() == expectedWidth and scrollChild:GetWidth() == expectedWidth,
        "section must use the active scroll-content width")
    local cl, ct, cr, cb = mock.rect(cf)
    for _, child in ipairs(cf._children) do
        local l, t, r, b = mock.rect(child)
        assert(l >= cl - .1 and r <= cr + .1, "direct disclosure control exceeds content width")
        assert(t <= ct + .1 and b >= cb - .1, "direct disclosure control escapes scroll content height")
    end
end

local function assertJumpMenuBounds(panel)
    local jump, menu = assert(NS.Config.sectionJump), assert(NS.Config.sectionMenu)
    if not jump:IsShown() then
        assert(not menu:IsShown(), "hidden Jump-to control must not leave its menu open")
        return
    end
    local pl, pt, pr, pb = mock.rect(panel)
    local jl, jt, jr, jb = mock.rect(jump)
    assert(jl >= pl and jr <= pr and jt <= pt and jb >= pb, "Jump-to button must fit the panel")
    local click = assert(jump:GetScript("OnClick"), "Jump-to button needs a click handler")
    click(jump)
    assert(menu:IsShown(), "Jump-to menu must open")
    local ml, mt, mr, mb = mock.rect(menu)
    assert(ml >= pl and mr <= pr and mt <= pt and mb >= pb, "Jump-to popover must fit the panel")
    local menuScroll = menu._children[1]
    local menuContent = menuScroll and rawget(menuScroll, "_scrollChild")
    assert(menuContent, "Jump-to popover requires a scroll-content frame")
    local cl, ct, cr, cb = mock.rect(menuContent)
    for _, child in ipairs(menuContent._children) do
        if child:IsShown() then
            local l, t, r, b = mock.rect(child)
            assert(child:GetHeight() == 28 and l >= cl and r <= cr and t <= ct and b >= cb,
                "Jump-to row must fit its scroll content")
        end
    end
    click(jump)
    assert(not menu:IsShown(), "Jump-to menu must close")
end

local panel = assert(NS.Config:Create())
assert(panel:GetWidth() == 640 and panel:GetHeight() == 413, "saved 413px normal height must be honored above the 400px minimum")
-- Config construction happens while its root is hidden. Show it for real so
-- lifecycle hooks, effective child visibility, and the first selected page
-- are exercised instead of treating local IsShown state as rendered content.
local firstSection = assert(newestSection(1), "initial Combat Assist content missing")
assert(not panel:IsVisible() and firstSection:IsShown() and not firstSection:IsVisible(),
    "hidden config must retain its selected section without rendering it")
NS.Config:Show()
assert(panel:IsVisible() and firstSection:IsVisible() and firstSection:GetAlpha() == 1,
    "opening config must make the selected content immediately visible and opaque")

-- Multiple HookScript registrations must all survive, and pixels refreshes
-- must preserve each manually anchored section-header ruler.
local title = assert(findTextWidget(panel, "Combat Assist"), "page title missing")
assert(rawget(title, "_points")[1][2] == panel,
    "page title must anchor directly to the sized config frame")
assert(rawget(NS.Config.scrollFrame, "_points")[1][2] == panel,
    "scroll region must anchor directly to the sized config frame")
local macroHeader = assert(findHeaderWidget(panel, "TRINKETS"), "trinket header missing")
local macroLine = assert(rawget(macroHeader, "_line"), "trinket header ruler missing")
local headerAnchorCount = #rawget(macroLine, "_points")
local headerAnchorTarget = rawget(macroLine, "_points")[1][2]
NS.Config:ApplyScale()
assert(#rawget(macroLine, "_points") == headerAnchorCount and rawget(macroLine, "_points")[1][2] == headerAnchorTarget,
    "pixel refresh must preserve section-header ruler anchors")

NS.Config:Hide()
assert(not panel:IsVisible() and firstSection:IsShown() and not firstSection:IsVisible(),
    "hiding config must not discard the selected page's local shown state")
NS.Config:Show()
assert(panel:IsVisible() and firstSection:IsVisible() and firstSection:GetAlpha() == 1,
    "reopening config must restore visible opaque page content")
-- A roomy parent preserves a user's deliberate 150% panel preference; a
-- smaller parent applies only a transient fit cap and leaves that preference.
db.configPanelScale = 1.5
NS.Config:ApplyScale()
assert(math.abs(panel:GetScale() - 1.5) < .001, "roomy UI must retain 150% panel scale")
ui.uiParent:SetSize(800, 500)
NS.Config:ApplyScale()
local cappedScale = math.min(1.5, (800 - 48) / 640, (500 - 48) / 413)
assert(math.abs(panel:GetScale() - cappedScale) < .001, "small UI must apply a transient screen-fit cap")
assert(db.configPanelScale == 1.5, "screen-fit cap must not overwrite the saved panel preference")
ui.uiParent:SetSize(1920, 1080)
NS.Config:ApplyScale()
assertJumpMenuBounds(panel)
for i = 1, 9 do
    NS.Config.SelectSection(i)
    if i == 5 then
        assert(panel:GetWidth() == 980 and panel:GetHeight() == 413, "Talent Builds must retain the saved 413px height")
    else
        assert(panel:GetWidth() == 640 and panel:GetHeight() == 413, "non-talent sections must retain the saved 413px height")
    end
    assertTopTabs(panel)
    assertActiveSectionInScrollRegion(i)
    assertJumpMenuBounds(panel)
end

local function walk(frame)
    assert(frame._width >= 0 and frame._height >= 0, "widget has negative size")
    for _, child in ipairs(frame._children) do walk(child) end
end
walk(panel)

-- Searching from the wider Talent page must reflow the navigation as well as
-- the content. The old tab positions would otherwise escape the 640px panel.
NS.Config.SelectSection(5)
local searchPlaceholder = assert(findTextWidget(panel, "Find a setting..."))
local searchBox = rawget(searchPlaceholder, "_parent")
local searchChanged = assert(searchBox:GetScript("OnTextChanged"))
searchBox:SetText("Font"); searchChanged(searchBox)
assert(panel:GetWidth() == 640, "search uses the normal window width")
assertTopTabs(panel)
searchBox:SetText(""); searchChanged(searchBox)
assert(panel:GetWidth() == 980, "clearing search restores the active Talent page")
assertTopTabs(panel)
local motionAppearance = assert(newestSection(2))
local motionAppearanceH = motionAppearance:GetHeight()

-- The macro-preview hint disclosure is created before later sections. Its
-- callback must retain the Combat Assist frame rather than changing Profiles.
local profilesH = assert(newestSection(9)):GetHeight()
local hintsLabel = assert(findTextWidget(panel, "SHOW HINTS"), "macro hint control was not constructed")
local hintsButton = rawget(hintsLabel, "_parent")
local hintsClick = hintsButton:GetScript("OnClick")
assert(type(hintsClick) == "function", "macro hint control needs an OnClick handler")
hintsClick(hintsButton)
assert(newestSection(9):GetHeight() == profilesH, "macro hint disclosure must not alter Profiles height")

-- The mock gives un-sized FontStrings an estimated line box, so this guards
-- actual vertical/horizontal relationships in the trinket status row instead
-- of treating every label as a zero-height point.
local trinketName = assert(findTextWidget(panel, "Trinket 1"), "Trinket name text was not built")
local trinketRow = rawget(trinketName, "_parent")
local trinketReason = assert(findTextWidget(trinketRow, "No trinket information available."), "Trinket reason text was not built")
local trinketState = assert(findTextWidget(trinketRow, "Unavailable"), "Trinket state text was not built")
local nl, nt, nr, nb = mock.rect(trinketName)
local rl, rt = mock.rect(trinketReason)
local sl, st, sr, sb = mock.rect(trinketState)
assert(rt <= nb - .5, "trinket reason must start beneath the name line")
assert(sl >= nr + 4 or sb <= nb or st >= nt, "trinket state must not overlap the name")

-- Exercise all cast-feedback disclosure states through real Config construction.
local appearanceHeights = { Motion = motionAppearanceH }
for _, feedback in ipairs({"Classic", "Off"}) do
    db.castFeedback = feedback
    db.castAnimation = feedback == "Classic" and "Pulse" or "Off"
    NS.Config.frame = nil
    NS._restoreSection = false
    local rebuilt = assert(NS.Config:Create())
    NS.Config.SelectSection(2)
    assert(rebuilt:GetWidth() == 640 and rebuilt:GetHeight() == 413, feedback .. " appearance layout must retain 413px height")
    appearanceHeights[feedback] = assert(newestSection(2)):GetHeight()
end
assert(appearanceHeights.Classic > appearanceHeights.Off, ("Classic disclosure must reserve its particle/font controls (Classic %.0f, Off %.0f)"):format(appearanceHeights.Classic, appearanceHeights.Off))

-- Direct real Talent panel pass exposes its state for measured source-chip bounds.
local talentParent = ui.createFrame("Frame", nil, ui.uiParent)
talentParent:SetSize(972, 560)
talentParent._contentWidth, talentParent._sectionColor, talentParent._subsections = 972, color(), {}
talentParent._sectionColorDim, talentParent._sectionColorBright = color(), color()
local talentState = assert(NS.BuildTalentBuildsConfigSection(talentParent))
assert(rawget(talentState.levelingTarget, "_text") == "Target: No leveling target selected",
    "leveling assist must expose the current-spec target before the catalog")
assert(rawget(talentState.levelingStatus, "_text"):find("prerequisite order", 1, true),
    "leveling assist must explain the fallback order qualification")
assert(talentState.parent._contentH >= 732, "leveling assist must reserve real catalog height")
local selectedCatalogRow
for _, row in ipairs(talentState.rowButtons) do
    if rawget(row, "_data") and row._data.id == "BUILD-1" then selectedCatalogRow = row; break end
end
assert(selectedCatalogRow, "active-spec catalog row required for leveling interaction")
assert(selectedCatalogRow:GetScript("OnClick"), "catalog row requires an inspect handler")
selectedCatalogRow:GetScript("OnClick")(selectedCatalogRow)
assert(applyCalls == 0, "browsing a catalog row must never import or apply it")
assert(talentState.selectedRow.id == "BUILD-1", "catalog click must only select the build for inspection")
assert(talentState.autoSpendBtn._enabled, "AUTO-SPEND must be available when a valid build is selected but no target is saved")
local autoSpend = assert(talentState.autoSpendBtn:GetScript("OnClick"), "AUTO-SPEND needs a handler")
local selectTarget = NS.SetTalentLevelingTarget
NS.SetTalentLevelingTarget = function() return false, "Invalid purchased rank count" end
autoSpend(talentState.autoSpendBtn)
assert(leveling.buildID == "CUSTOM" and not leveling.enabled
    and rawget(talentState.levelingStatus, "_text") == "Invalid purchased rank count",
    "a failed target decode must leave AUTO-SPEND off and show the error")
NS.SetTalentLevelingTarget = selectTarget
autoSpend(talentState.autoSpendBtn)
assert(leveling.buildID == "BUILD-1" and leveling.enabled and applyCalls == 0,
    "enabling AUTO-SPEND must set the selected build as target without importing a full loadout")
autoSpend(talentState.autoSpendBtn)
assert(not leveling.enabled, "AUTO-SPEND must toggle off after its one-click setup")
local useForLeveling = assert(talentState.useForLevelingBtn:GetScript("OnClick"), "USE FOR LEVELING needs a handler")
useForLeveling(talentState.useForLevelingBtn)
assert(leveling.buildID == "BUILD-1" and rawget(talentState.levelingNext, "_text") == "Next recommended talent: Arcane Surge",
    "USE FOR LEVELING must set the selected active-spec build without importing it")
assert(applyCalls == 0, "setting a leveling target must not import a full build")
autoSpend(talentState.autoSpendBtn)
assert(leveling.enabled and rawget(talentState.autoSpendBtn._text, "_text") == "Auto-Spend: On",
    "AUTO-SPEND must be an explicit per-spec option")
autoSpend(talentState.autoSpendBtn)
assert(not leveling.enabled, "AUTO-SPEND must toggle back off")
local spendNext = assert(talentState.spendNextBtn:GetScript("OnClick"), "SPEND NEXT needs a handler")
spendNext(talentState.spendNextBtn)
assert(leveling.status == "Spent Arcane Surge.", "SPEND NEXT must use the manual backend path when auto-spend is off")
local warningToggle = assert(talentState.sbaWarningBtn:GetScript("OnClick"), "SBA ALERT needs an opt-in handler")
warningToggle(talentState.sbaWarningBtn)
assert(warningSetCalls == 1 and sbaAssessment.warningEnabled
    and rawget(talentState.sbaWarningBtn._text, "_text") == "SBA Alert: On",
    "SBA alert must remain an explicit per-spec opt-in")
assert(not talentState.respecSBABtn._enabled, "RESPEC TO SBA must stay unavailable without a mismatch")
assert(not talentState.undoRespecBtn._enabled, "UNDO RESPEC must stay unavailable without a saved prior allocation")
undoAvailable = true
talentState:Refresh()
assert(talentState.undoRespecBtn._enabled, "confirmed unchanged respec must expose UNDO RESPEC")
talentState.undoRespecBtn:GetScript("OnClick")(talentState.undoRespecBtn)
assert(undoCalls == 1, "UNDO RESPEC must invoke the explicit backend action")
undoAvailable = false
talentState:Refresh()
sbaAssessment.hasMismatch = true
talentState:Refresh()
assert(talentState.respecSBABtn._enabled, "RESPEC TO SBA must become available for a settled actionable mismatch")
local panelRespec = assert(talentState.respecSBABtn:GetScript("OnClick"), "RESPEC TO SBA needs an explicit-action handler")
panelRespec(talentState.respecSBABtn)
assert(respecCalls == 1, "panel RESPEC TO SBA must request a deliberate SBA reset once")

-- Scheduled checks can run before this panel exists. The callback owns a
-- lazy alert, suppresses its dismissed mismatch signature, and rechecks the
-- backend action instead of retaining a stale result.
NS.CheckTalentSBAWarning(sbaAssessment)
local warningTitle = assert(findTextWidget(ui.uiParent, "SBA Talent Mismatch"), "settled opted-in mismatch must show a warning alert")
local warningPopup = warningTitle:GetParent()
assert(warningPopup:IsShown() and rawget(warningPopup._target, "_text"):find("Arcane SBA", 1, true),
    "warning alert must identify the selected SBA target")
assert(warningPopup._target:GetHeight() == 14 and not rawget(warningPopup._target, "_wordWrap")
    and warningPopup._bodyScroll and warningPopup._bodyContent
    and rawget(warningPopup._body, "_text"):find("resets your class, specialization, and hero talent points", 1, true),
    "warning alert must reserve a bounded target line and explain the explicit SBA reset")
local wl, wt, wr, wb = mock.rect(warningPopup)
local bl, bt, br, bb = mock.rect(warningPopup._bodyScroll)
local _, respecTop = mock.rect(warningPopup._respec)
assert(bl >= wl + 12 and br <= wr - 12 and bt <= wt - 45 and bb >= respecTop + 12,
    "scrolling warning details must stay inside the popup and above its actions")
sbaAssessment.targetName = string.rep("Very Long Custom SBA Target ", 12)
NS.CheckTalentSBAWarning(sbaAssessment)
assert(rawget(warningPopup._target, "_text"):find("Very Long Custom SBA Target", 1, true)
    and warningPopup._target:GetHeight() == 14,
    "long SBA target names must stay in the reserved single-line alert target slot")
sbaAssessment.targetName = "Arcane SBA"
sbaAssessment.mismatchDetails = "Spell 999 is learned but outside the selected SBA target."
NS.CheckTalentSBAWarning(sbaAssessment)
assert(rawget(warningPopup._body, "_text"):find("Spell 999", 1, true),
    "warning popup must show the specific learned talent mismatch")
local dismissWarning = assert(warningPopup._dismiss:GetScript("OnClick"), "warning alert needs dismissal")
dismissWarning(warningPopup._dismiss)
assert(not warningPopup:IsShown(), "dismiss must hide the current SBA mismatch alert")
NS.CheckTalentSBAWarning(sbaAssessment)
assert(not warningPopup:IsShown(), "dismissed mismatch signature must not spam repeated alerts")
sbaAssessment.settled, sbaAssessment.hasMismatch = false, false
NS.CheckTalentSBAWarning(sbaAssessment)
sbaAssessment.settled, sbaAssessment.hasMismatch = true, true
NS.CheckTalentSBAWarning(sbaAssessment)
assert(not warningPopup:IsShown(), "a transient unavailable assessment must preserve the user's dismissal")
sbaAssessment.signature = "mage-arcane-build-1-mismatch-two"
NS.CheckTalentSBAWarning(sbaAssessment)
assert(warningPopup:IsShown(), "a changed mismatch signature must be shown again")
sbaAssessment.settled = false
NS.CheckTalentSBAWarning(sbaAssessment)
assert(not warningPopup:IsShown(), "unsettled talent changes must not leave an actionable SBA alert visible")
sbaAssessment.settled = true
NS.CheckTalentSBAWarning(sbaAssessment)
assert(warningPopup:IsShown(), "settled mismatch must restore its actionable SBA alert")
sbaAssessment.canRespec = false
local alertRespec = assert(warningPopup._respec:GetScript("OnClick"), "alert RESPEC TO SBA needs an explicit-action handler")
alertRespec(warningPopup._respec)
assert(respecCalls == 2 and rawget(warningPopup._body, "_text"):find("Cannot respec", 1, true),
    "alert action must recheck and visibly report an unavailable SBA reset")
sbaAssessment.failure = "WoW rejected the respec. Review pending talents."
sbaAssessment.settled, sbaAssessment.hasMismatch = false, false
NS.CheckTalentSBAWarning(sbaAssessment)
assert(warningPopup:IsShown() and not warningPopup._respec._enabled
    and rawget(warningPopup._body, "_text"):find("WoW rejected", 1, true),
    "asynchronous respec failure must remain visible even while staged data is unsettled")
sbaAssessment.failure, sbaAssessment.settled = nil, true
sbaAssessment.canRespec, sbaAssessment.hasMismatch = true, false
NS.CheckTalentSBAWarning(sbaAssessment)
assert(not warningPopup:IsShown(), "resolved SBA mismatch must hide its alert")
sbaAssessment.warningEnabled, sbaAssessment.hasMismatch = false, true
NS.CheckTalentSBAWarning(sbaAssessment)
assert(not warningPopup:IsShown(), "disabled SBA warning must hide its alert")
talentState:Refresh()
assert(talentState.respecSBABtn._enabled, "turning off popup alerts must not disable an explicit respec action")
local sourceChips = {}
for _, child in ipairs(talentParent._children) do
    if rawget(child, "_source") then sourceChips[#sourceChips + 1] = child end
end
assert(#sourceChips == 6, "all dynamic source chips must be created")
local rows = {}
for _, chip in ipairs(sourceChips) do
    local l, t, r = mock.rect(chip)
    local pl, _, pr = mock.rect(talentParent)
    assert(l >= pl + 14 and r <= pr - 14, "source chip must stay within talent content bounds")
    rows[math.floor(t)] = true
end
local rowCount = 0; for _ in pairs(rows) do rowCount = rowCount + 1 end
assert(rowCount >= 1, "source chips must be laid out in measured catalog rows")

-- Wrapped filters must push the footer as well as the table/actions. Status
-- messages and assist controls must have real interior bounds, not clipping.
local assistPanel = talentState.useForLevelingBtn:GetParent()
assert(assistPanel:GetHeight() <= 120, "leveling assist must remain compact instead of reserving a mostly empty block")
local apl, apt, apr, apb = mock.rect(assistPanel)
for _, control in ipairs({talentState.levelingTarget, talentState.levelingNext, talentState.levelingStatus,
    talentState.useForLevelingBtn, talentState.autoSpendBtn, talentState.spendNextBtn,
    talentState.sbaWarningBtn, talentState.respecSBABtn, talentState.undoRespecBtn, talentState.levelingHint}) do
    local l, t, r, b = mock.rect(control)
    assert(l >= apl + 8 and r <= apr - 8 and t <= apt - 8 and b >= apb + 8,
        ("leveling labels and controls must stay inside an explicit gutter (%s: %.0f %.0f %.0f %.0f within %.0f %.0f %.0f %.0f)")
            :format(rawget(control, "_text") or "control", l, t, r, b, apl, apt, apr, apb))
end
local assistActions = {
    talentState.useForLevelingBtn, talentState.autoSpendBtn, talentState.spendNextBtn,
    talentState.sbaWarningBtn, talentState.respecSBABtn, talentState.undoRespecBtn,
}
for i = 1, #assistActions do
    local al, at, ar, ab = mock.rect(assistActions[i])
    for j = i + 1, #assistActions do
        local bl, bt, br, bb = mock.rect(assistActions[j])
        assert(ar <= bl or br <= al or ab >= bt or bb >= at,
            "leveling assist action controls must not overlap")
    end
end
local _, typeTop, _, typeBottom = mock.rect(talentState.typeButtons.all)
local _, _, _, searchBottom = mock.rect(talentState.searchBox)
assert(typeTop <= searchBottom - 8,
    "type filters must start below the search field instead of sharing its label row")
local _, firstSourceTop, _, firstSourceBottom = mock.rect(sourceChips[1])
assert(firstSourceTop <= typeBottom - 8 and firstSourceBottom < typeTop,
    ("source chips must use a dedicated row below the type filters (source %.0f %.0f, type %.0f %.0f)")
        :format(firstSourceTop, firstSourceBottom, typeTop, typeBottom))
local _, tableTopAfterSources = mock.rect(talentState.tablePanel)
local lowestSourceBottom = firstSourceBottom
for _, chip in ipairs(sourceChips) do
    local _, _, _, chipBottom = mock.rect(chip)
    lowestSourceBottom = math.min(lowestSourceBottom, chipBottom)
end
assert(tableTopAfterSources <= lowestSourceBottom - 12,
    "the table must start below every revealed source-chip row with a visible gutter")

local customCatalogRow, offSpecCatalogRow
for _, row in ipairs(talentState.rowButtons) do
    local data = rawget(row, "_data")
    if data and data.id == "CUSTOM" then customCatalogRow = row end
    if data and data.specID ~= 100 then offSpecCatalogRow = row end
end
assert(customCatalogRow and offSpecCatalogRow, "catalog needs Custom and off-spec rows for action gating")
customCatalogRow:GetScript("OnClick")(customCatalogRow)
assert(not talentState.useForLevelingBtn._enabled
    and rawget(talentState.levelingStatus, "_text"):find("Select a current%-spec"),
    "Custom must not be usable as a leveling target")
local priorTarget = leveling.buildID
leveling.buildID = "CUSTOM"
talentState:Refresh()
assert(talentState.autoSpendBtn._enabled, "AUTO-SPEND must remain clickable to explain a missing target")
autoSpend(talentState.autoSpendBtn)
assert(not leveling.enabled and rawget(talentState.levelingStatus, "_text")
    == "Select a current-spec build before enabling Auto-Spend.",
    "a missing target must produce feedback instead of an inert AUTO-SPEND button")
leveling.buildID = priorTarget
talentState:Refresh()
offSpecCatalogRow:GetScript("OnClick")(offSpecCatalogRow)
assert(not talentState.useForLevelingBtn._enabled
    and rawget(talentState.behaviorText, "_text"):find("OFF%-SPEC BUILD")
    and rawget(talentState.levelingStatus, "_text"):find("off%-spec"),
    "off-spec catalog rows must be plainly identified and unavailable for current-spec leveling")
selectedCatalogRow:GetScript("OnClick")(selectedCatalogRow)
local footer = assert(findTextWidget(talentParent,
    "Click a row to inspect it. APPLY BUILD imports the selected full build. LOAD ANYWAY remains for an off-spec selection."))
local _, tableTop, _, tableBottom = mock.rect(talentState.tablePanel)
local _, footerTop, _, footerBottom = mock.rect(footer)
local _, _, _, contentBottom = mock.rect(talentParent)
assert(footerTop < tableBottom - 30 and footerBottom > contentBottom + 10,
    "footer must move below wrapped-source table without leaving the content bounds")

-- Source provenance can contain long author notes; it scrolls inside the
-- dialog, leaving the URL/copy and close controls reachable.
talentState.selectedRow.notes = string.rep("Manual cooldowns and source limitations. ", 70)
talentState.sourceBtn:GetScript("OnClick")(talentState.sourceBtn)
local sourcePopup = assert(talentParent._talentBuildURLPopup)
assert(rawget(sourcePopup._provenance, "_text"):find("Guide-adapted", 1, true)
    and rawget(sourcePopup._provenance, "_text"):find("not an optimality claim", 1, true),
    "source popup must identify guide-adapted choices and qualify guide-informed priorities")
assert(sourcePopup._sourceContent:GetHeight() > sourcePopup._sourceScroll:GetHeight(),
    "long source notes must reserve scrollable height")
sourcePopup._sourceScroll:GetScript("OnMouseWheel")(sourcePopup._sourceScroll, -1)
assert(sourcePopup._sourceScroll:GetVerticalScroll() > 0, "source notes must be scrollable")
local spl, spt, spr, spb = mock.rect(sourcePopup)
local sl, st, sr, sb = mock.rect(sourcePopup._sourceScroll)
assert(sl >= spl + 12 and sr <= spr - 12 and st < spt - 80 and sb >= spb + 30,
    "source viewport must leave room for the dialog controls")
sourcePopup:Hide()
talentState.selectedRow.verificationStatus = "user-provided"
local savedSourceURL = talentState.selectedRow.sourceURL
talentState.selectedRow.sourceURL = ""
talentState:UpdateDetails()
assert(rawget(talentState.behaviorText, "_text"):find("user%-provided import", 1),
    "selected user-provided imports must state their unverified SBA provenance")
assert(talentState.sourceBtn:IsShown() and rawget(talentState.sourceBtn._text, "_text") == "Build Notes",
    "user-provided imports without source URLs must expose their build notes")
talentState.sourceBtn:GetScript("OnClick")(talentState.sourceBtn)
assert(rawget(sourcePopup._provenance, "_text"):find("User%-provided import", 1),
    "source popup must distinguish user-provided imports from source-verified catalog builds")
assert(rawget(sourcePopup._title, "_text"):find("Build Notes", 1, true)
    and rawget(sourcePopup._editBox, "_text") == "No source URL supplied",
    "build notes must not imply that an unverified source URL exists")
sourcePopup:Hide()
talentState.selectedRow.sourceURL = savedSourceURL
talentState.selectedRow.verificationStatus = "guide-adapted"
talentState:UpdateDetails()

-- Fixed-size rows and direct disclosure controls must remain inside their
-- scroll-content parent. This includes the two 66px trinket rows.
local trinketRows = 0
for _, frame in ipairs(ui.frames) do
    if rawget(frame, "_trinketSlot") then
        assert(frame._width == 295 and frame._height == 66, "equipment slots share the full-width page")
        local l, _, r = mock.rect(frame)
        local pl, _, pr = mock.rect(frame._parent)
        assert(l >= pl and r <= pr, "trinket row must fit its content width")
        trinketRows = trinketRows + 1
    end
end
assert(trinketRows >= 2, "expected both trinket rows")

-- Heights below the compact safety floor are raised only to that floor; the
-- earlier 413px assertion proves higher saved values remain untouched.
db.configPanelBaseHeight, db.configPanelHeight = 399, 399
NS.Config.frame = nil
NS._restoreSection = false
local minHeightPanel = assert(NS.Config:Create())
assert(minHeightPanel:GetWidth() == 640 and minHeightPanel:GetHeight() == 400,
    "compact config must enforce its 400px minimum height")
NS.Config.SelectSection(5)
assertActiveSectionInScrollRegion(5)
local compactTalent = assert(newestSection(5), "compact Talent Builds content missing")
local compactTalentState = assert(NS.BuildTalentBuildsConfigSection(compactTalent))
local compactAssistTitle = assert(findTextWidget(compactTalent, "Leveling Target"), "compact panel must keep leveling assist visible")
local compactCatalogTitle = assert(findTextWidget(compactTalent, "Talent Builds"), "compact panel must keep catalog title visible")
local _, _, _, assistBottom = mock.rect(rawget(compactAssistTitle, "_parent"))
local _, catalogTop = mock.rect(compactCatalogTitle)
assert(catalogTop <= assistBottom - 20, "compact panel must reserve a gutter between leveling assist and catalog")
local compactAlert = assert(findTextWidget(compactTalent, "SBA Alert: Off"), "compact panel must reserve the SBA alert option")
local compactRespec = assert(findTextWidget(compactTalent, "Respec to SBA"), "compact panel must reserve the SBA respec action")
for _, control in ipairs({compactAlert:GetParent(), compactRespec:GetParent()}) do
    local l, t, r, b = mock.rect(control)
    local pl, pt, pr, pb = mock.rect(rawget(compactAssistTitle, "_parent"))
    assert(l >= pl + 8 and r <= pr - 8 and t <= pt - 8 and b >= pb + 8,
        "compact SBA warning controls must remain inside the reserved assist block")
end
-- The production Talent tab intentionally widens its scroll region. Exercise
-- the panel's real narrow branch separately so a future host with the minimum
-- content width keeps catalog chips, details, and actions apart.
local narrowTalent = ui.createFrame("Frame", nil, ui.uiParent)
narrowTalent:SetSize(640, 1200)
narrowTalent._contentWidth, narrowTalent._sectionColor, narrowTalent._subsections = 640, color(), {}
narrowTalent._sectionColorDim, narrowTalent._sectionColorBright = color(), color()
local narrowTalentState = assert(NS.BuildTalentBuildsConfigSection(narrowTalent))
assert(narrowTalentState.compactCatalog, "minimum-width Talent Builds must stack the details panel below the catalog table")
local compactSources, compactRows = {}, {}
for _, chip in ipairs(narrowTalentState.sourceButtons) do
    if chip:IsShown() then
        compactSources[#compactSources + 1] = chip
        local _, top = mock.rect(chip)
        compactRows[math.floor(top)] = true
    end
end
local compactRowCount = 0; for _ in pairs(compactRows) do compactRowCount = compactRowCount + 1 end
assert(#compactSources == 6 and compactRowCount >= 2,
    ("long source chips must wrap at the minimum config width (%d chips, %d rows)"):format(#compactSources, compactRowCount))
local lowestCompactChipBottom
for _, chip in ipairs(compactSources) do
    local _, _, _, bottom = mock.rect(chip)
    lowestCompactChipBottom = lowestCompactChipBottom and math.min(lowestCompactChipBottom, bottom) or bottom
end
local _, compactTableTop, _, compactTableBottom = mock.rect(narrowTalentState.tablePanel)
local _, compactDetailsTop = mock.rect(narrowTalentState.detailsPanel)
assert(compactTableTop <= lowestCompactChipBottom - 12,
    "wrapped compact source rows must reserve a gutter before the table header")
assert(compactDetailsTop <= compactTableBottom - 8,
    "compact details panel must start below the table instead of compressing its columns")
local _, compactSourceBottom = mock.rect(narrowTalentState.sourceBtn)
local _, compactActionsTop = mock.rect(narrowTalentState.actionsRule)
assert(compactActionsTop <= compactSourceBottom - 8,
    "compact catalog actions must follow the details/source area without overlap")
local savedStatus, savedDetail = leveling.status, leveling.detail
leveling.status = string.rep("A long current-level talent status that must stay bounded in the compact assistant. ", 4)
leveling.detail = string.rep("Unverified source and prerequisite ordering details remain available from the assistant tooltip. ", 4)
narrowTalentState:UpdateLevelingAssist()
local narrowStatusText = rawget(narrowTalentState.levelingStatus, "_text")
assert(not narrowStatusText:find("\n", 1, true) and #narrowStatusText <= 100
    and table.concat(narrowTalentState.levelingTooltip, " "):find("Unverified source", 1, true),
    "compact assistant must summarize long provenance in its bounded status line and retain full details in its tooltip")
local nl, nt, nr, nb = mock.rect(narrowTalentState.levelingStatus)
local npl, npt, npr, npb = mock.rect(narrowTalentState.useForLevelingBtn:GetParent())
assert(nl >= npl + 8 and nr <= npr - 8 and nt <= npt - 8 and nb >= npb + 8,
    "long compact assistant status must remain inside its allocated bounds")
leveling.status, leveling.detail = savedStatus, savedDetail
narrowTalentState:UpdateLevelingAssist()

-- A page must never be left transparent when the user closes/reopens while
-- transition settings are enabled. The shell no longer fades whole content.
db.cfgAnimTransitions = true
NS.Config.frame = nil
NS._restoreSection = false
local transitionPanel = assert(NS.Config:Create())
local transitionSection = assert(newestSection(1), "transition test section missing")
NS.Config:Show()
assert(transitionSection:IsVisible() and transitionSection:GetAlpha() == 1,
    "animated settings must open with opaque content")
NS.Config:Hide()
NS.Config:Show()
assert(transitionSection:IsVisible() and transitionSection:GetAlpha() == 1,
    "hide/reopen during transitions must not strand page content at alpha zero")
db.cfgAnimTransitions = false

print("config mock: actual Framework/Config/TalentBuildsPanel passed all sections, feedback states, and wrapped-source bounds")
if arg and arg[1] and arg[1] ~= "" then
    -- The artifact is a readable inspection view, independent of the
    -- preceding DPI-fit assertions. Populate representative approved trinket
    -- and macro data only for this one-process export.
    db.configPanelScale = 1
    db.trinketMode = "Approved"
    NS.GetTrinketStatus = function(slot)
        return {
            name = slot == 13 and "Astral Talisman" or "Stormbound Compass",
            status = "Approved",
            reason = "Instant use is available for BetterSBA.",
            canApprove = true,
            eligible = true,
        }
    end
    NS.GetMacroActions = function()
        return {
            { text = "/cast [nochanneling] Sequence Break", hint = "Primary spell" },
            { text = "/use [combat] 13", hint = "Approved trinket" },
        }
    end
    -- Rebuild only for the export so local preview rows consume the
    -- representative data above; ordinary assertions retain their own state.
    NS.Config.frame = nil
    NS._restoreSection = false
    local exportFrame = assert(NS.Config:Create())
    exportFrame:Show()
    NS.Config.SelectSection(tonumber(arg[2]) or 1)
    if NS.RefreshTrinketConfig then NS.RefreshTrinketConfig() end
    NS.Config:ApplyScale()
    mock.writeSVG(NS.Config.frame, arg[1])
    print("config mock: wrote estimated-bounds SVG to " .. arg[1])
end
local studioFaction = arg and arg[4] == "horde" and "Horde" or "Alliance"
_G.UnitFactionGroup = function() return studioFaction end
assert(loadfile("GUI/ConfigStudio.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComicLettering.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioComic.lua"))("BetterSBA", NS)
assert(loadfile("GUI/StudioSettings.lua"))("BetterSBA", NS)
NS.SwitchSettingsPanel("studio")
local studio = NS.ConfigStudio
assert(studio.Comic.faction == studioFaction, "Studio art must match the character's faction")
studio:SelectPage("Build Library")
assert(studio.pages["Build Library"]._catalog,
    "Studio must show the real build manager inside the new panel")
if arg and arg[1] and arg[3] == "studio" then
    studio.frame:SetSize(900, 600)
    studio.frame:GetScript("OnSizeChanged")(studio.frame, 900, 600)
    mock.writeSVG(studio.frame, arg[1])
end
studio:SelectPage("Combat")
assert(studio.pages.Combat._controls.trinketMode,
    "Studio must expose the original combat settings")
studio:Hide()
return { NS = NS, ui = ui, panel = panel }
